//
//  FxGripOnScreenControl.m
//  FxGrip
//

#import "FxGripOnScreenControl.h"
#import "FxGripOSCPart.h"
#import "FxGripEventModifiers.h"
#import "FxGripMTLDeviceCache.h"
#import "FxTileImage+FxGrip.h"
#import "FxGripTextImage.h"
#import "FxGrip_ARC.h"

CGPoint FxGripOSCMetalPointFromCanvasPoint(CGPoint canvasPoint, CGSize canvasSize)
{
	// The flip matches the OSC surface's row order; centering matches the vertex
	// shader's half-viewport normalization.
	return CGPointMake(canvasPoint.x - canvasSize.width / 2.0,
					   (canvasSize.height - canvasPoint.y) - canvasSize.height / 2.0);
}

const simd_float4 kFxGripOSCUnselectedFillColor	= { 0.25, 0.25, 0.25, 0.25 };
const simd_float4 kFxGripOSCSelectedFillColor	= { 0.5, 0.5, 0.5, 0.5 };
const simd_float4 kFxGripOSCOutlineColor		= { 1.0, 1.0, 1.0, 1.0 };
const simd_float4 kFxGripOSCShadowColor			= { 0.25, 0.25, 0.25, 1.0 };

// Option fine-drag moves a part at this fraction of the mouse travel, matching the curve editor.
static const CGFloat kFxGripOSCFineDragScale = 0.1;

// A second click on the same part within this canvas-pixel radius and the system double-click
// interval is delivered to the part as a double-click; FxPlug carries no click count.
static const CGFloat kFxGripOSCDoubleClickSlop = 4.0;

@interface FxGripOnScreenControl ()
{
	FxGripAPIAccessing *_apiManager;
	NSMutableArray<FxGripOSCPart *> *_parts;
	NSLock *_lastPositionLock;
	CGPoint _lastObjectPosition;			// the last effective (post-scale, post-constrain) position
	CGPoint _dragStartObjectPosition;		// the click position, for Shift-constrained drags
	CGPoint _dragVirtualObjectPosition;		// accumulates scaled movement, for Option fine-drag
	CGPoint _lastRawObjectPosition;			// the last raw mouse position, to measure per-event travel

	// Double-click synthesis, touched only on the host's serial event thread.
	NSTimeInterval _lastMouseDownWallTime;	// wall-clock time of the last recorded mouse-down
	CGPoint _lastMouseDownCanvasPoint;		// its canvas position, to bound a double-click's travel
	NSInteger _lastMouseDownPart;			// its active part, so a double-click stays on one part

	// Transient render context, valid only for the span of one drawOSCWithWidth: pass.
	// The textured draw kit reaches these to swap pipelines mid-pass; a part draws only
	// while the host is inside that pass, so no cross-pass access occurs.
	FxGripMTLDeviceCacheItem *_activeDeviceCacheItem;
	id<MTLLibrary> _activeLibrary;
	id<MTLRenderPipelineState> _activeFlatPipelineState;
}
@end

@implementation FxGripOnScreenControl

- (nullable instancetype)initWithAPIManager:(nonnull id<PROAPIAccessing>)apiManager
{
	self = [super init];
	if (self != nil) {
		// An OSC is its own plugin entry: there is no effect instance to bind.
		_apiManager = [[FxGripAPIAccessing alloc] initWithAPIManager:apiManager
															  effect:(id _Nonnull)nil];
		_pluginUUID = NARC_RETAIN(_apiManager.pluginUUID);
		_parts = NARC_RETAIN([NSMutableArray array]);
		_lastPositionLock = [[NSLock alloc] init];
		_lastObjectPosition = CGPointMake(-1.0, -1.0);
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_apiManager);
	NARC_RELEASE(_pluginUUID);
	NARC_RELEASE(_parts);
	NARC_RELEASE(_lastPositionLock);
	SUPER_DEALLOC();
}

- (nonnull id<FxGripAPIAccessing>)apiManager
{
	return (id<FxGripAPIAccessing>)_apiManager;
}

- (nonnull NSArray<FxGripOSCPart *> *)parts
{
	return [_parts copy];
}

- (void)addPart:(nonnull FxGripOSCPart *)part
{
	if (part == nil) {
		return;
	}
	part.control = self;
	[_parts addObject:part];
}

- (void)addParts:(nonnull NSArray<FxGripOSCPart *> *)parts
{
	for (FxGripOSCPart *part in parts) {
		[self addPart:part];
	}
}


#pragma mark Coordinate conversion

- (CGPoint)objectPointFromCanvasPoint:(CGPoint)canvasPoint
{
	id<FxOnScreenControlAPI_v4> oscAPI = self.apiManager.onScreenControlAPIv4;
	if (oscAPI == nil) {
		return canvasPoint;
	}
	CGPoint objectPoint = CGPointZero;
	[oscAPI convertPointFromSpace:kFxDrawingCoordinates_CANVAS
							fromX:canvasPoint.x
							fromY:canvasPoint.y
						  toSpace:kFxDrawingCoordinates_OBJECT
							  toX:&objectPoint.x
							  toY:&objectPoint.y];
	return objectPoint;
}

- (CGPoint)canvasPointFromObjectPoint:(CGPoint)objectPoint
{
	id<FxOnScreenControlAPI_v4> oscAPI = self.apiManager.onScreenControlAPIv4;
	if (oscAPI == nil) {
		return objectPoint;
	}
	CGPoint canvasPoint = CGPointZero;
	[oscAPI convertPointFromSpace:kFxDrawingCoordinates_OBJECT
							fromX:objectPoint.x
							fromY:objectPoint.y
						  toSpace:kFxDrawingCoordinates_CANVAS
							  toX:&canvasPoint.x
							  toY:&canvasPoint.y];
	return canvasPoint;
}


#pragma mark Parameter access

- (BOOL)getObjectPoint:(nonnull CGPoint *)objectPoint fromParameter:(FxParameterId)parameterID atTime:(CMTime)time
{
	id<FxParameterRetrievalAPI_v6> paramAPI = self.apiManager.paramGetAPIv6;
	if (paramAPI == nil) {
		return NO;
	}
	return [paramAPI getXValue:&objectPoint->x
						YValue:&objectPoint->y
				 fromParameter:parameterID
						atTime:time];
}

- (BOOL)setObjectPoint:(CGPoint)objectPoint toParameter:(FxParameterId)parameterID atTime:(CMTime)time
{
	id<FxParameterSettingAPI_v5> paramAPI = self.apiManager.paramSetAPIv5;
	if (paramAPI == nil) {
		return NO;
	}
	return [paramAPI setXValue:objectPoint.x
						YValue:objectPoint.y
				   toParameter:parameterID
						atTime:time];
}

- (BOOL)getFloatValue:(nonnull double *)value fromParameter:(FxParameterId)parameterID atTime:(CMTime)time
{
	id<FxParameterRetrievalAPI_v6> paramAPI = self.apiManager.paramGetAPIv6;
	if (paramAPI == nil) {
		return NO;
	}
	return [paramAPI getFloatValue:value fromParameter:parameterID atTime:time];
}

- (BOOL)setFloatValue:(double)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time
{
	id<FxParameterSettingAPI_v5> paramAPI = self.apiManager.paramSetAPIv5;
	if (paramAPI == nil) {
		return NO;
	}
	return [paramAPI setFloatValue:value toParameter:parameterID atTime:time];
}

- (nullable NSObject<NSSecureCoding, NSCopying> *)getCustomValueFromParameter:(FxParameterId)parameterID
																	   atTime:(CMTime)time
{
	id<FxParameterRetrievalAPI_v6> paramAPI = self.apiManager.paramGetAPIv6;
	if (paramAPI == nil) {
		return nil;
	}
	NSObject<NSSecureCoding, NSCopying> *value = nil;
	if (![paramAPI getCustomParameterValue:&value fromParameter:parameterID atTime:time]) {
		return nil;
	}
	return value;
}

- (BOOL)setCustomValue:(nonnull NSObject<NSSecureCoding, NSCopying> *)value
		   toParameter:(FxParameterId)parameterID
				atTime:(CMTime)time
{
	id<FxParameterSettingAPI_v5> paramAPI = self.apiManager.paramSetAPIv5;
	if (paramAPI == nil) {
		return NO;
	}
	return [paramAPI setCustomParameterValue:value toParameter:parameterID atTime:time];
}


#pragma mark Subclass hooks

- (NSInteger)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time
{
	for (FxGripOSCPart *part in _parts.reverseObjectEnumerator) {
		if ([part hitTestObjectPoint:objectPoint canvasPoint:canvasPoint atTime:time]) {
			return part.partID;
		}
	}
	return 0;
}

- (BOOL)dragActivePart:(NSInteger)activePart
		 toObjectPoint:(CGPoint)objectPoint
		   objectDelta:(CGPoint)objectDelta
			 modifiers:(FxModifierKeys)modifiers
				atTime:(CMTime)time
{
	for (FxGripOSCPart *part in _parts) {
		if (part.partID == activePart) {
			return [part dragToObjectPoint:objectPoint
							   objectDelta:objectDelta
								 modifiers:modifiers
									atTime:time];
		}
	}
	return NO;
}

- (void)drawOSC:(nonnull FxImageTile *)destinationImage
 commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
	 canvasSize:(CGSize)canvasSize
	 activePart:(NSInteger)activePart
		 atTime:(CMTime)time
{
	for (FxGripOSCPart *part in _parts) {
		[part drawSelected:(part.partID == activePart)
				canvasSize:canvasSize
			commandEncoder:commandEncoder
					atTime:time];
	}
}


#pragma mark FxOnScreenControl_v4 drawing

- (FxDrawingCoordinates)drawingCoordinates
{
	return kFxDrawingCoordinates_CANVAS;
}

/*! The FxGrip framework's shader library for the tile's device, cached per device. */
- (nullable id<MTLLibrary>)fxOSCLibraryForDevice:(nullable id<MTLDevice>)device
{
	if (device == nil) {
		return nil;
	}
	static NSMutableDictionary<NSNumber *, id<MTLLibrary>> *libraries = nil;
	static NSLock *librariesLock = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		libraries = NARC_RETAIN(NSMutableDictionary.new);
		librariesLock = [[NSLock alloc] init];
	});

	NSNumber *key = @(device.registryID);
	[librariesLock lock];
	id<MTLLibrary> library = libraries[key];
	[librariesLock unlock];
	if (library != nil) {
		return library;
	}

	NSError *error = nil;
	library = [device newDefaultLibraryWithBundle:[NSBundle bundleForClass:FxGripOnScreenControl.class]
											error:&error];
	if (library == nil) {
		NSLog(@"%s Error: unable to load the FxGrip shader library: %@", __func__, error);
		return nil;
	}
	[librariesLock lock];
	libraries[key] = library;
	[librariesLock unlock];
	return NARC_AUTORELEASE(library);
}

- (void)drawOSCWithWidth:(NSInteger)width
				  height:(NSInteger)height
			  activePart:(NSInteger)activePart
		destinationImage:(FxImageTile *)destinationImage
				  atTime:(CMTime)time
{
	FxGripMTLDeviceCache *deviceCache = FxGripMTLDeviceCache.deviceCache;
	id<MTLCommandQueue> commandQueue = [FxGripMTLDeviceCache commandQueueForImageTile:destinationImage
																			 pluginID:self.pluginUUID];
	if (commandQueue == nil) {
		NSLog(@"%s Error: no command queue for the destination image", __func__);
		return;
	}

	id<MTLDevice> device = destinationImage.device;
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	commandBuffer.label = @"FxGrip OSC Command Buffer";
	[commandBuffer enqueue];

	id<MTLTexture> outputTexture = [destinationImage metalTextureForDevice:device];
	MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
	renderPassDescriptor.colorAttachments[0].texture = outputTexture;
	renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
	renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

	id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

	FxRect pixelBounds = destinationImage.imagePixelBounds;
	CGSize canvasSize = CGSizeMake(pixelBounds.right - pixelBounds.left,
								   pixelBounds.top - pixelBounds.bottom);

	FxGripMTLDeviceCacheItem *deviceCacheItem = [deviceCache deviceWithRegistryID:destinationImage.deviceRegistryID
																	  pixelFormat:destinationImage.metalPixelFormat
																	  andPluginID:self.pluginUUID];
	id<MTLLibrary> library = [self fxOSCLibraryForDevice:device];
	id<MTLRenderPipelineState> pipelineState =
		[deviceCacheItem pipelineStateWithLibrary:library
									 vertexShader:@"fxGripOSCVertexShader"
								   fragmentShader:@"fxGripOSCFragmentShader"
								   constantValues:nil];
	if (pipelineState == nil) {
		NSLog(@"%s Error: no OSC pipeline state", __func__);
		[commandEncoder endEncoding];
		[commandBuffer commit];
		[deviceCache returnCommandQueueToCache:commandQueue];
		return;
	}
	[commandEncoder setRenderPipelineState:pipelineState];

	// Metal is y-down: the viewport starts at the top of the surface.
	CGFloat ioSurfaceHeight = [destinationImage.ioSurface height];
	MTLViewport viewport = {
		0, ioSurfaceHeight - canvasSize.height, canvasSize.width, canvasSize.height, -1.0, 1.0
	};
	[commandEncoder setViewport:viewport];

	_activeDeviceCacheItem = deviceCacheItem;
	_activeLibrary = library;
	_activeFlatPipelineState = pipelineState;
	[self drawOSC:destinationImage
	commandEncoder:commandEncoder
		canvasSize:canvasSize
		activePart:activePart
			atTime:time];
	_activeDeviceCacheItem = nil;
	_activeLibrary = nil;
	_activeFlatPipelineState = nil;

	[commandEncoder endEncoding];
	[commandBuffer commit];
	[commandBuffer waitUntilScheduled];
	[deviceCache returnCommandQueueToCache:commandQueue];
}


#pragma mark Draw kit

- (void)encodeVertices:(nonnull const FxGripOSCVertex *)vertices
				 count:(NSUInteger)count
			 primitive:(MTLPrimitiveType)primitive
				 color:(simd_float4)color
			canvasSize:(CGSize)canvasSize
		commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
{
	if (count == 0) {
		return;
	}
	simd_uint2 viewportSize = { (unsigned int)canvasSize.width, (unsigned int)canvasSize.height };
	[commandEncoder setVertexBytes:vertices
							length:count * sizeof(FxGripOSCVertex)
						   atIndex:FxGripOSCVertexInputIndexVertices];
	[commandEncoder setVertexBytes:&viewportSize
							length:sizeof(viewportSize)
						   atIndex:FxGripOSCVertexInputIndexViewportSize];
	[commandEncoder setFragmentBytes:&color
							  length:sizeof(color)
							 atIndex:FxGripOSCFragmentInputIndexColor];
	[commandEncoder drawPrimitives:primitive vertexStart:0 vertexCount:count];
}

- (void)strokeCanvasPoints:(nonnull const CGPoint *)canvasPoints
					 count:(NSUInteger)count
					closed:(BOOL)closed
					 color:(simd_float4)color
				withShadow:(BOOL)withShadow
				canvasSize:(CGSize)canvasSize
			commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
{
	if (count < 2) {
		return;
	}
	NSUInteger vertexCount = count + (closed ? 1 : 0);
	FxGripOSCVertex *vertices = malloc(vertexCount * sizeof(FxGripOSCVertex));
	if (vertices == NULL) {
		return;
	}
	for (NSUInteger index = 0; index < count; index++) {
		CGPoint metalPoint = FxGripOSCMetalPointFromCanvasPoint(canvasPoints[index], canvasSize);
		vertices[index].position = (vector_float2){ (float)metalPoint.x, (float)metalPoint.y };
	}
	if (closed) {
		vertices[count] = vertices[0];
	}

	if (withShadow) {
		FxGripOSCVertex *shadow = malloc(vertexCount * sizeof(FxGripOSCVertex));
		if (shadow != NULL) {
			for (NSUInteger index = 0; index < vertexCount; index++) {
				shadow[index].position = vertices[index].position + (vector_float2){ 1.0, 1.0 };
			}
			[self encodeVertices:shadow
						   count:vertexCount
					   primitive:MTLPrimitiveTypeLineStrip
						   color:kFxGripOSCShadowColor
					  canvasSize:canvasSize
				  commandEncoder:commandEncoder];
			free(shadow);
		}
	}

	[self encodeVertices:vertices
				   count:vertexCount
			   primitive:MTLPrimitiveTypeLineStrip
				   color:color
			  canvasSize:canvasSize
		  commandEncoder:commandEncoder];
	free(vertices);
}

- (void)fillCanvasQuadLL:(CGPoint)lowerLeft
					  lr:(CGPoint)lowerRight
					  ur:(CGPoint)upperRight
					  ul:(CGPoint)upperLeft
				   color:(simd_float4)color
			  canvasSize:(CGSize)canvasSize
		  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
{
	CGPoint corners[4] = { lowerRight, lowerLeft, upperRight, upperLeft };
	FxGripOSCVertex vertices[4];
	for (NSUInteger index = 0; index < 4; index++) {
		CGPoint metalPoint = FxGripOSCMetalPointFromCanvasPoint(corners[index], canvasSize);
		vertices[index].position = (vector_float2){ (float)metalPoint.x, (float)metalPoint.y };
	}
	[self encodeVertices:vertices
				   count:4
			   primitive:MTLPrimitiveTypeTriangleStrip
				   color:color
			  canvasSize:canvasSize
		  commandEncoder:commandEncoder];
}

- (void)fillCanvasFanAroundCenter:(CGPoint)center
						rimPoints:(nonnull const CGPoint *)rimPoints
							count:(NSUInteger)count
							color:(simd_float4)color
					   canvasSize:(CGSize)canvasSize
				   commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
{
	if (count < 2) {
		return;
	}
	FxGripOSCVertex *vertices = malloc(3 * count * sizeof(FxGripOSCVertex));
	if (vertices == NULL) {
		return;
	}
	CGPoint metalCenter = FxGripOSCMetalPointFromCanvasPoint(center, canvasSize);
	for (NSUInteger index = 0; index < count; index++) {
		CGPoint rim = FxGripOSCMetalPointFromCanvasPoint(rimPoints[index], canvasSize);
		CGPoint next = FxGripOSCMetalPointFromCanvasPoint(rimPoints[(index + 1) % count], canvasSize);
		vertices[index * 3 + 0].position = (vector_float2){ (float)metalCenter.x, (float)metalCenter.y };
		vertices[index * 3 + 1].position = (vector_float2){ (float)rim.x, (float)rim.y };
		vertices[index * 3 + 2].position = (vector_float2){ (float)next.x, (float)next.y };
	}
	[self encodeVertices:vertices
				   count:3 * count
			   primitive:MTLPrimitiveTypeTriangle
				   color:color
			  canvasSize:canvasSize
		  commandEncoder:commandEncoder];
	free(vertices);
}

- (void)encodeTexturedQuadLL:(CGPoint)lowerLeft
						  lr:(CGPoint)lowerRight
						  ur:(CGPoint)upperRight
						  ul:(CGPoint)upperLeft
					 texture:(nonnull id<MTLTexture>)texture
					   color:(simd_float4)color
				  canvasSize:(CGSize)canvasSize
			  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
{
	if (texture == nil) {
		return;
	}
	id<MTLRenderPipelineState> texturedPipeline =
		[_activeDeviceCacheItem pipelineStateWithLibrary:_activeLibrary
										   vertexShader:@"fxGripOSCTexturedVertexShader"
										 fragmentShader:@"fxGripOSCTexturedFragmentShader"
										 constantValues:nil];
	if (texturedPipeline == nil) {
		return;
	}

	// Triangle-strip order LR, LL, UR, UL, matching fillCanvasQuadLL:. The texture's
	// top-left (v = 0) maps to the upper corners.
	CGPoint corners[4]			= { lowerRight, lowerLeft, upperRight, upperLeft };
	vector_float2 texCoords[4]	= { { 1.0, 1.0 }, { 0.0, 1.0 }, { 1.0, 0.0 }, { 0.0, 0.0 } };
	FxGripOSCTexturedVertex vertices[4];
	for (NSUInteger index = 0; index < 4; index++) {
		CGPoint metalPoint = FxGripOSCMetalPointFromCanvasPoint(corners[index], canvasSize);
		vertices[index].position = (vector_float2){ (float)metalPoint.x, (float)metalPoint.y };
		vertices[index].texCoord = texCoords[index];
	}

	simd_uint2 viewportSize = { (unsigned int)canvasSize.width, (unsigned int)canvasSize.height };
	[commandEncoder setRenderPipelineState:texturedPipeline];
	[commandEncoder setVertexBytes:vertices
							length:sizeof(vertices)
						   atIndex:FxGripOSCVertexInputIndexVertices];
	[commandEncoder setVertexBytes:&viewportSize
							length:sizeof(viewportSize)
						   atIndex:FxGripOSCVertexInputIndexViewportSize];
	[commandEncoder setFragmentTexture:texture atIndex:FxGripOSCFragmentTextureIndexColor];
	[commandEncoder setFragmentBytes:&color
							  length:sizeof(color)
							 atIndex:FxGripOSCFragmentInputIndexColor];
	[commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];

	// Restore the flat pipeline so later parts (and later draws by this part) keep working.
	if (_activeFlatPipelineState != nil) {
		[commandEncoder setRenderPipelineState:_activeFlatPipelineState];
	}
}

- (nullable id<MTLTexture>)textureForText:(nonnull NSString *)text
								 fontSize:(CGFloat)fontSize
									color:(simd_float4)color
								   device:(nonnull id<MTLDevice>)device
{
	return [FxGripTextImage textureForText:text fontSize:fontSize color:color device:device];
}


#pragma mark FxOnScreenControl_v4 events

- (void)hitTestOSCAtMousePositionX:(double)mousePositionX
					mousePositionY:(double)mousePositionY
						activePart:(NSInteger *)activePart
							atTime:(CMTime)time
{
	CGPoint canvasPoint = CGPointMake(mousePositionX, mousePositionY);
	*activePart = [self hitTestObjectPoint:[self objectPointFromCanvasPoint:canvasPoint]
							   canvasPoint:canvasPoint
									atTime:time];
}

- (void)mouseDownAtPositionX:(double)mousePositionX
				   positionY:(double)mousePositionY
				  activePart:(NSInteger)activePart
				   modifiers:(FxModifierKeys)modifiers
				 forceUpdate:(BOOL *)forceUpdate
					  atTime:(CMTime)time
{
	CGPoint canvasPoint = CGPointMake(mousePositionX, mousePositionY);
	CGPoint objectPoint = [self objectPointFromCanvasPoint:canvasPoint];
	[_lastPositionLock lock];
	_lastObjectPosition = objectPoint;
	_dragStartObjectPosition = objectPoint;
	_dragVirtualObjectPosition = objectPoint;
	_lastRawObjectPosition = objectPoint;
	[_lastPositionLock unlock];
	*forceUpdate = NO;

	if (activePart == 0) {
		_lastMouseDownPart = 0;
		return;
	}
	FxGripOSCPart *hitPart = nil;
	for (FxGripOSCPart *part in _parts) {
		if (part.partID == activePart) {
			hitPart = part;
			break;
		}
	}
	if (hitPart == nil) {
		_lastMouseDownPart = 0;
		return;
	}

	NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate;
	BOOL isDoubleClick = activePart == _lastMouseDownPart
		&& (now - _lastMouseDownWallTime) <= NSEvent.doubleClickInterval
		&& hypot(canvasPoint.x - _lastMouseDownCanvasPoint.x,
				 canvasPoint.y - _lastMouseDownCanvasPoint.y) <= kFxGripOSCDoubleClickSlop;
	if (isDoubleClick && [hitPart mouseDoubleClickAtObjectPoint:objectPoint
													canvasPoint:canvasPoint
													  modifiers:modifiers
														 atTime:time]) {
		*forceUpdate = YES;
		// Consume the click so a third click does not read as another double-click.
		_lastMouseDownWallTime = 0.0;
		_lastMouseDownPart = 0;
		return;
	}

	*forceUpdate = [hitPart mouseDownAtObjectPoint:objectPoint
									   canvasPoint:canvasPoint
										 modifiers:modifiers
											atTime:time];
	_lastMouseDownWallTime = now;
	_lastMouseDownCanvasPoint = canvasPoint;
	_lastMouseDownPart = activePart;
}

- (void)mouseDraggedAtPositionX:(double)mousePositionX
					  positionY:(double)mousePositionY
					 activePart:(NSInteger)activePart
					  modifiers:(FxModifierKeys)modifiers
					forceUpdate:(BOOL *)forceUpdate
						 atTime:(CMTime)time
{
	CGPoint rawPoint = [self objectPointFromCanvasPoint:CGPointMake(mousePositionX, mousePositionY)];

	// Option is a fine (slow) drag, unless the active part claims Option for its own gesture.
	CGFloat scale = 1.0;
	if ([FxGripEventModifiers isFineDragForFxModifiers:modifiers]
		&& ![self activePartHandlesOptionDrag:activePart]) {
		scale = kFxGripOSCFineDragScale;
	}

	[_lastPositionLock lock];
	// Accumulate the scaled per-event travel, so toggling Option mid-drag never jumps the point.
	_dragVirtualObjectPosition.x += (rawPoint.x - _lastRawObjectPosition.x) * scale;
	_dragVirtualObjectPosition.y += (rawPoint.y - _lastRawObjectPosition.y) * scale;
	_lastRawObjectPosition = rawPoint;
	CGPoint effectivePoint = _dragVirtualObjectPosition;

	// Shift constrains the drag to horizontal or vertical from the click, whichever moved farther,
	// unless the active part claims Shift for its own gesture. Both constrain and fine-drag are
	// applied here in the base, so every part inherits them.
	if ([FxGripEventModifiers isConstrainForFxModifiers:modifiers]
		&& ![self activePartHandlesConstrainDrag:activePart]) {
		if (fabs(effectivePoint.x - _dragStartObjectPosition.x) >= fabs(effectivePoint.y - _dragStartObjectPosition.y)) {
			effectivePoint.y = _dragStartObjectPosition.y;
		} else {
			effectivePoint.x = _dragStartObjectPosition.x;
		}
	}
	CGPoint delta = CGPointMake(effectivePoint.x - _lastObjectPosition.x,
								effectivePoint.y - _lastObjectPosition.y);
	_lastObjectPosition = effectivePoint;
	[_lastPositionLock unlock];

	*forceUpdate = [self dragActivePart:activePart
						  toObjectPoint:effectivePoint
							objectDelta:delta
							  modifiers:modifiers
								 atTime:time];
}

/*! YES when the active part reads Option itself while dragging, so the base leaves Option to it. */
- (BOOL)activePartHandlesOptionDrag:(NSInteger)activePart
{
	if (activePart == 0) {
		return NO;
	}
	for (FxGripOSCPart *part in _parts) {
		if (part.partID == activePart) {
			return [part handlesOptionDrag];
		}
	}
	return NO;
}

/*! YES when the active part reads Shift itself while dragging, so the base leaves Shift to it. */
- (BOOL)activePartHandlesConstrainDrag:(NSInteger)activePart
{
	if (activePart == 0) {
		return NO;
	}
	for (FxGripOSCPart *part in _parts) {
		if (part.partID == activePart) {
			return [part handlesConstrainDrag];
		}
	}
	return NO;
}

- (void)mouseUpAtPositionX:(double)mousePositionX
				 positionY:(double)mousePositionY
				activePart:(NSInteger)activePart
				 modifiers:(FxModifierKeys)modifiers
			   forceUpdate:(BOOL *)forceUpdate
					atTime:(CMTime)time
{
	[self mouseDraggedAtPositionX:mousePositionX
						positionY:mousePositionY
					   activePart:activePart
						modifiers:modifiers
					  forceUpdate:forceUpdate
						   atTime:time];
	[_lastPositionLock lock];
	_lastObjectPosition = CGPointMake(-1.0, -1.0);
	[_lastPositionLock unlock];
}

- (void)keyDownAtPositionX:(double)mousePositionX
				 positionY:(double)mousePositionY
				keyPressed:(unsigned short)asciiKey
				 modifiers:(FxModifierKeys)modifiers
			   forceUpdate:(BOOL *)forceUpdate
				 didHandle:(BOOL *)didHandle
					atTime:(CMTime)time
{
	// The active part is not passed with a key event; a part acts on the vertex it selected
	// on the last click, so the key routes to every part.
	BOOL handled = NO;
	for (FxGripOSCPart *part in _parts) {
		handled |= [part keyDownWithKey:asciiKey modifiers:modifiers atTime:time];
	}
	*didHandle = handled;
	*forceUpdate = handled;
}

- (void)keyUpAtPositionX:(double)mousePositionX
			   positionY:(double)mousePositionY
			  keyPressed:(unsigned short)asciiKey
			   modifiers:(FxModifierKeys)modifiers
			 forceUpdate:(BOOL *)forceUpdate
			   didHandle:(BOOL *)didHandle
				  atTime:(CMTime)time
{
	*didHandle = NO;
}

#pragma mark Cursor

// Applies the hovered part's cursor through the host OSC API, or the arrow when no part (or
// a part with no cursor) is under the pointer.
- (void)applyCursorForActivePart:(NSInteger)activePart
{
	id<FxOnScreenControlAPI_v4> oscAPI = self.apiManager.onScreenControlAPIv4;
	if (oscAPI == nil) {
		return;
	}
	NSCursor *cursor = nil;
	if (activePart != 0) {
		for (FxGripOSCPart *part in self.parts) {
			if (part.partID == activePart) {
				cursor = part.cursor;
				break;
			}
		}
	}
	[oscAPI setCursor:cursor ?: NSCursor.arrowCursor];
}

- (void)mouseMovedAtPositionX:(double)mousePositionX
					positionY:(double)mousePositionY
				   activePart:(NSInteger)activePart
					modifiers:(FxModifierKeys)modifiers
				  forceUpdate:(BOOL *)forceUpdate
					   atTime:(CMTime)time
{
	[self applyCursorForActivePart:activePart];
	*forceUpdate = NO;
}

- (void)mouseEnteredAtPositionX:(double)mousePositionX
					  positionY:(double)mousePositionY
					  modifiers:(FxModifierKeys)modifiers
					forceUpdate:(BOOL *)forceUpdate
						 atTime:(CMTime)time
{
	*forceUpdate = NO;
}

- (void)mouseExitedAtPositionX:(double)mousePositionX
					 positionY:(double)mousePositionY
					 modifiers:(FxModifierKeys)modifiers
				   forceUpdate:(BOOL *)forceUpdate
						atTime:(CMTime)time
{
	// Leaving the control restores the arrow.
	[self applyCursorForActivePart:0];
	*forceUpdate = NO;
}

@end
