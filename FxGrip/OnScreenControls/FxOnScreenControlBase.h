//
//  FxOnScreenControlBase.h
//  FxGrip
//

#ifndef FxOnScreenControlBase_h
#define FxOnScreenControlBase_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <Metal/Metal.h>
#import "FxGripAPIAccessing.h"
#import "FxGripOSCShaderTypes.h"

@class FxGripOSCPart;

/*! Converts a canvas point (y up, origin lower-left) to the OSC pipeline's
	viewport-centered Metal coordinates (y up, origin at the canvas center). */
FOUNDATION_EXPORT CGPoint FxGripOSCMetalPointFromCanvasPoint(CGPoint canvasPoint, CGSize canvasSize);

/*! The standard control colors: translucent gray fills, white outline, dark shadow. */
FOUNDATION_EXPORT const simd_float4 kFxGripOSCUnselectedFillColor;
FOUNDATION_EXPORT const simd_float4 kFxGripOSCSelectedFillColor;
FOUNDATION_EXPORT const simd_float4 kFxGripOSCOutlineColor;
FOUNDATION_EXPORT const simd_float4 kFxGripOSCShadowColor;

/*!
	@class      FxOnScreenControlBase
	@abstract   The base class for FxPlug on-screen controls.
	@discussion Introduced in FxGrip 1.0. An on-screen control registers as its own
				plugin entry (protocol `FxOnScreenControl`, with the effect's UUID in
				`supportedPlugins`); an effect's registration dictionary lists its OSC
				UUIDs under the `"osc"` key and the registrar wires `supportedPlugins`.

				The base implements the whole FxOnScreenControl_v4 surface:
				- `drawOSCWithWidth:...` runs the Metal scaffold (command queue, render
				  pass, the FxGrip OSC pipeline from the framework's shader library)
				  and calls `drawOSC:commandEncoder:canvasSize:activePart:atTime:`.
				- `hitTestOSCAtMousePositionX:...` converts the mouse to object space
				  and calls `hitTestObjectPoint:canvasPoint:atTime:`.
				- The mouse methods track the last object-space position and route a
				  drag's object-space delta to
				  `dragActivePart:toObjectPoint:objectDelta:modifiers:atTime:`,
				  repeating the final delta on mouse-up.
				- Key and mouse-moved events default to unhandled no-ops.

				A subclass either overrides those hooks directly, or adds
				FxGripOSCPart instances (`addPart:`): the default hooks hit-test the
				parts (topmost first), draw them (selected when the active part
				matches), and route drags to the active part.

				Parameter writes go through the wrapped setting APIs without
				startAction/endAction bracketing; the host expects parameter changes
				from an on-screen control.
*/
@interface FxOnScreenControlBase : NSObject <FxOnScreenControl_v4>

@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;
@property (readonly, nullable, retain) NSString *pluginUUID;

/*! The control's parts, in the order added; drawn first-to-last, hit-tested last-to-first. */
@property (readonly, nonnull) NSArray<FxGripOSCPart *> *parts;

- (nullable instancetype)initWithAPIManager:(nonnull id<PROAPIAccessing>)apiManager;

/*! Appends a part and points its `control` back at the receiver. */
- (void)addPart:(nonnull FxGripOSCPart *)part;

/*! Appends parts in order; used with the part classes' composite constructors. */
- (void)addParts:(nonnull NSArray<FxGripOSCPart *> *)parts;

#pragma mark Coordinate conversion

/*! Converts through the host's OSC API; identity when the API is unavailable. */
- (CGPoint)objectPointFromCanvasPoint:(CGPoint)canvasPoint;
- (CGPoint)canvasPointFromObjectPoint:(CGPoint)objectPoint;

#pragma mark Parameter access

- (BOOL)getObjectPoint:(nonnull CGPoint *)objectPoint fromParameter:(FxParameterId)parameterID atTime:(CMTime)time;
- (BOOL)setObjectPoint:(CGPoint)objectPoint toParameter:(FxParameterId)parameterID atTime:(CMTime)time;
- (BOOL)getFloatValue:(nonnull double *)value fromParameter:(FxParameterId)parameterID atTime:(CMTime)time;
- (BOOL)setFloatValue:(double)value toParameter:(FxParameterId)parameterID atTime:(CMTime)time;

/*! Reads the custom-data object stored in a parameter, or nil when none is set. */
- (nullable NSObject<NSSecureCoding, NSCopying> *)getCustomValueFromParameter:(FxParameterId)parameterID
																	   atTime:(CMTime)time;

/*! Writes a custom-data object into a parameter; returns YES on success. */
- (BOOL)setCustomValue:(nonnull NSObject<NSSecureCoding, NSCopying> *)value
		   toParameter:(FxParameterId)parameterID
				atTime:(CMTime)time;

#pragma mark Subclass hooks

/*!
	@method     hitTestObjectPoint:canvasPoint:atTime:
	@abstract   Returns the part number under the point, or 0 for none.
	@discussion The default asks each part, last-added first, so the part drawn on
				top wins the hit.
*/
- (NSInteger)hitTestObjectPoint:(CGPoint)objectPoint canvasPoint:(CGPoint)canvasPoint atTime:(CMTime)time;

/*!
	@method     dragActivePart:toObjectPoint:objectDelta:modifiers:atTime:
	@abstract   Applies a drag; returns YES when the effect must re-render.
	@discussion The default routes to the part whose partID equals activePart.
*/
- (BOOL)dragActivePart:(NSInteger)activePart
		 toObjectPoint:(CGPoint)objectPoint
		   objectDelta:(CGPoint)objectDelta
			 modifiers:(FxModifierKeys)modifiers
				atTime:(CMTime)time;

/*!
	@method     drawOSC:commandEncoder:canvasSize:activePart:atTime:
	@abstract   Encoder-level drawing; the scaffold, pipeline, and viewport are set.
	@discussion The default draws the parts in order, selected when partID equals
				activePart.
*/
- (void)drawOSC:(nonnull FxImageTile *)destinationImage
 commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder
	 canvasSize:(CGSize)canvasSize
	 activePart:(NSInteger)activePart
		 atTime:(CMTime)time;

#pragma mark Draw kit

/*!
	@method     encodeVertices:count:primitive:color:canvasSize:commandEncoder:
	@abstract   Encodes one flat-color draw of viewport-centered vertices.
*/
- (void)encodeVertices:(nonnull const FxGripOSCVertex *)vertices
				 count:(NSUInteger)count
			 primitive:(MTLPrimitiveType)primitive
				 color:(simd_float4)color
			canvasSize:(CGSize)canvasSize
		commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;

/*!
	@method     strokeCanvasPoints:count:closed:color:withShadow:canvasSize:commandEncoder:
	@abstract   Strokes a polyline of canvas points, optionally closed, with an
				optional one-pixel drop shadow beneath it.
*/
- (void)strokeCanvasPoints:(nonnull const CGPoint *)canvasPoints
					 count:(NSUInteger)count
					closed:(BOOL)closed
					 color:(simd_float4)color
				withShadow:(BOOL)withShadow
				canvasSize:(CGSize)canvasSize
			commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;

/*!
	@method     fillCanvasQuadLL:lr:ur:ul:color:canvasSize:commandEncoder:
	@abstract   Fills the quad spanned by four canvas corners.
*/
- (void)fillCanvasQuadLL:(CGPoint)lowerLeft
					  lr:(CGPoint)lowerRight
					  ur:(CGPoint)upperRight
					  ul:(CGPoint)upperLeft
				   color:(simd_float4)color
			  canvasSize:(CGSize)canvasSize
		  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;

/*!
	@method     fillCanvasFanAroundCenter:rimPoints:count:color:canvasSize:commandEncoder:
	@abstract   Fills the polygon around a center from a closed rim of canvas points.
*/
- (void)fillCanvasFanAroundCenter:(CGPoint)center
						rimPoints:(nonnull const CGPoint *)rimPoints
							count:(NSUInteger)count
							color:(simd_float4)color
					   canvasSize:(CGSize)canvasSize
				   commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;

/*!
	@method     encodeTexturedQuadLL:lr:ur:ul:texture:color:canvasSize:commandEncoder:
	@abstract   Draws texture across the quad spanned by four canvas corners, tinted by color.
	@discussion Introduced in FxGrip 1.0. Binds the FxGrip OSC textured pipeline for the
				draw and restores the flat-color pipeline afterward, so a part may mix
				textured and flat draws in one drawSelected: pass. The texture's top-left
				maps to the upper-left corner. Callable only from within a part's
				drawSelected:, while the base's render pass is active.
*/
- (void)encodeTexturedQuadLL:(CGPoint)lowerLeft
						  lr:(CGPoint)lowerRight
						  ur:(CGPoint)upperRight
						  ul:(CGPoint)upperLeft
					 texture:(nonnull id<MTLTexture>)texture
					   color:(simd_float4)color
				  canvasSize:(CGSize)canvasSize
			  commandEncoder:(nonnull id<MTLRenderCommandEncoder>)commandEncoder;

/*!
	@method     textureForText:fontSize:color:device:
	@abstract   Renders text to a new premultiplied RGBA texture sized to fit it.
	@discussion Introduced in FxGrip 1.0. Returns nil when text is empty or the texture
				cannot be created. The pixel size is available from the returned texture's
				width and height; a HUD part sizes its quad from them to keep the readout a
				fixed pixel size at every zoom.
*/
- (nullable id<MTLTexture>)textureForText:(nonnull NSString *)text
								 fontSize:(CGFloat)fontSize
									color:(simd_float4)color
								   device:(nonnull id<MTLDevice>)device;

@end

#endif /* FxOnScreenControlBase_h */
