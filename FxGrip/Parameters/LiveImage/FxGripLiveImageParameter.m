/*!
	@file       FxGripLiveImageParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripLiveImageParameter
	@abstract   Implements the live image slot strip, its parameter, and the async texture readback.
	@discussion Introduced in FxGrip 0.1.0. The view draws one slot per label, aspect-fitting each
	            frame over a checkerboard with a caption. The parameter stores the latest frame per
	            slot under a lock and coalesces redraws onto the main thread. A published texture is
	            blitted into a reused staging texture, downscaled through its mipmap chain, and read
	            back when the command buffer completes. Publishing is suppressed while no parameter
	            view is on screen.
*/

#import "FxGripLiveImageParameter.h"
#import "FxGripLiveImage.h"
#import "FxGripImageBuffer.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxTileImage+FxGrip.h"
#import "FxGrip_ARC.h"

// Layout, in view points.
static const CGFloat kFxGripLiveImageSlotGap = 6.0;
static const CGFloat kFxGripLiveImageCornerRadius = 3.0;
static const CGFloat kFxGripLiveImageCheckerSize = 8.0;
static const CGFloat kFxGripLiveImageCaptionGap = 2.0;

/*! The slot count a configuration declares: the label count, else the slots key, else 1. */
static NSUInteger FxGripLiveImageSlotCountForConfiguration(NSDictionary *configuration)
{
	NSArray *labels = configuration[kFxGripLiveImageKey_Labels];
	if ([labels isKindOfClass:NSArray.class] && labels.count > 0) {
		return labels.count;
	}
	NSNumber *slots = configuration[kFxGripLiveImageKey_Slots];
	if ([slots isKindOfClass:NSNumber.class] && slots.integerValue > 0) {
		return (NSUInteger)slots.integerValue;
	}
	return 1;
}

static NSArray<NSString *> *FxGripLiveImageLabelsForConfiguration(NSDictionary *configuration)
{
	NSArray *labels = configuration[kFxGripLiveImageKey_Labels];
	if (![labels isKindOfClass:NSArray.class]) {
		return @[];
	}
	NSMutableArray *strings = [NSMutableArray arrayWithCapacity:labels.count];
	for (id label in labels) {
		[strings addObject:[label isKindOfClass:NSString.class] ? label : @""];
	}
	return strings;
}


@class FxGripLiveImageParameter;

@interface FxGripLiveImageView ()
/*! The parameter that vended this view; nil until registered. Main thread. */
@property (nonatomic, weak) FxGripLiveImageParameter *liveImageParameter;
@end

@interface FxGripLiveImageParameter ()
/*! Recounts the on-screen views after one enters or leaves a window. Main thread. */
- (void)liveImageViewVisibilityDidChange;
@end


#pragma mark - View

/*!
	@abstract	The slot strip backing a live image parameter.
	@discussion	Introduced in FxGrip 0.1.0. The view draws one slot per configured label, each showing
				its latest frame aspect-fit over a checkerboard with a caption. It reports its window
				visibility to the parameter so publishing can gate on an on-screen view. */
@implementation FxGripLiveImageView
{
	NSMutableArray *_frames;
	NSArray<NSString *> *_labels;
	NSUInteger _slotCount;
	CGFloat _height;
	BOOL _showInfo;
	BOOL _checkerboard;
	BOOL _flipped;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_frames = [NSMutableArray arrayWithObject:NSNull.null];
		_labels = @[];
		_slotCount = 1;
		_height = kFxGripLiveImageDefaultHeight;
		_showInfo = YES;
		_checkerboard = YES;
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)isOpaque
{
	return NO;
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	[self.liveImageParameter liveImageViewVisibilityDidChange];
}

- (NSSize)intrinsicContentSize
{
	return NSMakeSize(NSViewNoIntrinsicMetric, _height);
}

- (NSUInteger)slotCount
{
	return _slotCount;
}

- (void)setSlotCount:(NSUInteger)slotCount
{
	slotCount = MAX(slotCount, (NSUInteger)1);
	while (_frames.count < slotCount) {
		[_frames addObject:NSNull.null];
	}
	while (_frames.count > slotCount) {
		[_frames removeLastObject];
	}
	_slotCount = slotCount;
}

#pragma mark Data

/*!
	@method		updateFromCustomData:
	@abstract	Applies the slot labels, height, and display flags from the configuration.
	@param		value	The parameter value; ignored when it is not a dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The label count sets the slot count. The height, info,
				checkerboard, and flip flags style the strip. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:NSDictionary.class]) {
		return;
	}
	NSDictionary *configuration = (NSDictionary *)value;
	_labels = FxGripLiveImageLabelsForConfiguration(configuration);
	[self setSlotCount:FxGripLiveImageSlotCountForConfiguration(configuration)];

	NSNumber *height = configuration[kFxGripLiveImageKey_Height];
	if ([height isKindOfClass:NSNumber.class] && height.doubleValue > 0.0) {
		_height = height.doubleValue;
		[self invalidateIntrinsicContentSize];
	}
	NSNumber *flag = configuration[kFxGripLiveImageKey_ShowInfo];
	if ([flag isKindOfClass:NSNumber.class]) {
		_showInfo = flag.boolValue;
	}
	flag = configuration[kFxGripLiveImageKey_Checkerboard];
	if ([flag isKindOfClass:NSNumber.class]) {
		_checkerboard = flag.boolValue;
	}
	flag = configuration[kFxGripLiveImageKey_Flip];
	if ([flag isKindOfClass:NSNumber.class]) {
		_flipped = flag.boolValue;
	}
	self.needsDisplay = YES;
}

/*! Replaces the frame shown in a slot and redraws it; nil empties the slot. Main thread. */
- (void)showFrame:(nullable FxGripLiveFrame *)frame inSlot:(NSUInteger)slot
{
	if (slot >= _slotCount) {
		return;
	}
	_frames[slot] = frame ?: (id)NSNull.null;
	[self setNeedsDisplayInRect:[self rectForSlot:slot]];
}

- (nullable FxGripLiveFrame *)frameInSlot:(NSUInteger)slot
{
	if (slot >= _slotCount) {
		return nil;
	}
	id frame = _frames[slot];
	return frame == NSNull.null ? nil : frame;
}

- (nullable NSString *)labelInSlot:(NSUInteger)slot
{
	if (slot >= _labels.count) {
		return nil;
	}
	NSString *label = _labels[slot];
	return label.length > 0 ? label : nil;
}

#pragma mark Layout

- (NSDictionary<NSAttributedStringKey, id> *)captionAttributes
{
	NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
	style.alignment = NSTextAlignmentCenter;
	style.lineBreakMode = NSLineBreakByTruncatingMiddle;
	return @{
		NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
		NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
		NSParagraphStyleAttributeName: style,
	};
}

- (CGFloat)captionHeight
{
	return ceil([NSFont systemFontOfSize:NSFont.smallSystemFontSize].boundingRectForFont.size.height);
}

- (NSRect)rectForSlot:(NSUInteger)slot
{
	NSRect bounds = self.bounds;
	CGFloat width = (bounds.size.width - kFxGripLiveImageSlotGap * (_slotCount - 1)) / _slotCount;
	if (width < 1.0) {
		width = 1.0;
	}
	return NSMakeRect(NSMinX(bounds) + slot * (width + kFxGripLiveImageSlotGap), NSMinY(bounds),
					  floor(width), bounds.size.height);
}

/*! The image area above the caption row; the caption row is dropped when it cannot fit. */
- (NSRect)imageRectForSlotRect:(NSRect)slotRect
{
	CGFloat caption = [self captionHeight] + kFxGripLiveImageCaptionGap;
	if (slotRect.size.height <= caption * 2.0) {
		return slotRect;
	}
	return NSMakeRect(NSMinX(slotRect), NSMinY(slotRect), slotRect.size.width, slotRect.size.height - caption);
}

/*! The label and info together when they fit the width, else the label alone, else the info. */
- (NSString *)captionForSlot:(NSUInteger)slot frame:(nullable FxGripLiveFrame *)frame
					   width:(CGFloat)width
				  attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
	NSString *label = [self labelInSlot:slot];
	NSString *info = (_showInfo && frame != nil) ? frame.sizeDescription : nil;
	if (label != nil && info != nil) {
		NSString *combined = [NSString stringWithFormat:@"%@ · %@", label, info];
		if ([combined sizeWithAttributes:attributes].width <= width) {
			return combined;
		}
	}
	return label ?: info ?: @"";
}

#pragma mark Drawing

- (void)drawCheckerboardInRect:(NSRect)rect
{
	[[NSColor colorWithWhite:0.32 alpha:1.0] setFill];
	NSRectFill(rect);
	[[NSColor colorWithWhite:0.40 alpha:1.0] setFill];
	NSUInteger columns = (NSUInteger)ceil(rect.size.width / kFxGripLiveImageCheckerSize);
	NSUInteger rows = (NSUInteger)ceil(rect.size.height / kFxGripLiveImageCheckerSize);
	for (NSUInteger row = 0; row < rows; row++) {
		for (NSUInteger column = (row & 1); column < columns; column += 2) {
			NSRect square = NSMakeRect(NSMinX(rect) + column * kFxGripLiveImageCheckerSize,
									   NSMinY(rect) + row * kFxGripLiveImageCheckerSize,
									   kFxGripLiveImageCheckerSize, kFxGripLiveImageCheckerSize);
			NSRectFill(NSIntersectionRect(square, rect));
		}
	}
}

- (NSRect)fitRectForFrame:(FxGripLiveFrame *)frame inRect:(NSRect)rect
{
	CGFloat scale = MIN(rect.size.width / frame.width, rect.size.height / frame.height);
	NSSize size = NSMakeSize(floor(frame.width * scale), floor(frame.height * scale));
	if (size.width < 1.0 || size.height < 1.0) {
		size = NSMakeSize(MAX(size.width, 1.0), MAX(size.height, 1.0));
	}
	return NSMakeRect(NSMinX(rect) + floor((rect.size.width - size.width) / 2.0),
					  NSMinY(rect) + floor((rect.size.height - size.height) / 2.0),
					  size.width, size.height);
}

- (void)drawFrame:(FxGripLiveFrame *)frame inRect:(NSRect)rect
{
	CGImageRef image = frame.CGImage;
	if (image == NULL) {
		return;
	}
	NSRect fit = [self fitRectForFrame:frame inRect:rect];
	CGContextRef context = NSGraphicsContext.currentContext.CGContext;
	CGContextSaveGState(context);
	CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
	// Row 0 of the pixels is the top row. The view is flipped, so the image draws
	// through a flipped CTM; the configured flip cancels it for bottom-up sources.
	if (!_flipped) {
		CGContextTranslateCTM(context, 0, NSMaxY(fit) + NSMinY(fit));
		CGContextScaleCTM(context, 1.0, -1.0);
	}
	CGContextDrawImage(context, fit, image);
	CGContextRestoreGState(context);
}

/*!
	@method		drawRect:
	@abstract	Draws each slot: the checkerboard or fill, the aspect-fit frame, and the caption.
	@discussion	Introduced in FxGrip 0.1.0. The image area is clipped to a rounded rect. The caption
				row is drawn below the image when it fits. */
- (void)drawRect:(NSRect)dirtyRect
{
	NSDictionary *attributes = [self captionAttributes];
	for (NSUInteger slot = 0; slot < _slotCount; slot++) {
		NSRect slotRect = [self rectForSlot:slot];
		if (!NSIntersectsRect(slotRect, dirtyRect)) {
			continue;
		}
		FxGripLiveFrame *frame = [self frameInSlot:slot];
		NSRect imageRect = [self imageRectForSlotRect:slotRect];

		NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:imageRect
															 xRadius:kFxGripLiveImageCornerRadius
															 yRadius:kFxGripLiveImageCornerRadius];
		[NSGraphicsContext saveGraphicsState];
		[clip addClip];
		if (_checkerboard) {
			[self drawCheckerboardInRect:imageRect];
		} else {
			[[NSColor colorWithWhite:0.18 alpha:1.0] setFill];
			NSRectFill(imageRect);
		}
		if (frame != nil) {
			[self drawFrame:frame inRect:imageRect];
		}
		[NSGraphicsContext restoreGraphicsState];

		if (imageRect.size.height < slotRect.size.height) {
			NSString *caption = [self captionForSlot:slot frame:frame width:slotRect.size.width attributes:attributes];
			NSRect captionRect = NSMakeRect(NSMinX(slotRect), NSMaxY(imageRect) + kFxGripLiveImageCaptionGap,
											slotRect.size.width, [self captionHeight]);
			[caption drawInRect:captionRect withAttributes:attributes];
		}
	}
}

@end


#pragma mark - Parameter

/*! One encoded copy, resolved to a frame when its command buffer completes. */
@interface FxGripLiveImageReadback : NSObject
@property (nonatomic, assign) NSUInteger slot;
@property (nonatomic, strong, nonnull) id<MTLTexture> staging;
@property (nonatomic, assign) NSUInteger level;
@end

@implementation FxGripLiveImageReadback
@end


/*!
	@abstract	The read-only strip of live images fed from the render pass.
	@discussion	Introduced in FxGrip 0.1.0. The parameter stores the latest frame per slot under a
				lock, coalesces redraws onto the main thread, and gates publishing on an on-screen
				view. A published texture is blitted, downscaled, and read back asynchronously. */
@implementation FxGripLiveImageParameter
{
	NSLock *_lock;
	NSMutableArray *_frames;					// per slot: FxGripLiveFrame or NSNull
	NSMutableIndexSet *_dirtySlots;
	BOOL _flushScheduled;
	NSMutableDictionary<NSNumber *, id<MTLTexture>> *_stagingTextures;
	NSMutableIndexSet *_inFlightSlots;
	id<MTLCommandQueue> _commandQueue;
	NSHashTable<FxGripLiveImageView *> *_views;	// main thread only
	NSUInteger _onscreenViewCount;				// views currently in a window
	NSUInteger _slotCount;
	NSUInteger _snapshotSize;
}

#pragma mark Class

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_LiveImage;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_LiveImage;
}

/*! @abstract The value classes the custom parameter decodes: FxGripDictionary and its element classes. */
+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the live image custom parameter on the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The configuration seeds the slot labels and count in the
				value. Creation adds the custom-UI, not-animatable, full-view-width, and no-state
				flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id declared = parameter.parameterDefaultValue;
	NSDictionary *config = [declared isKindOfClass:NSDictionary.class] ? declared : @{};
	FxGripDictionary *defaultValue = [FxGripDictionary dictionaryWithDictionary:config];
	[defaultValue setObject:FxGripLiveImageLabelsForConfiguration(config) forKey:kFxGripLiveImageKey_Labels];
	[defaultValue setObject:@(FxGripLiveImageSlotCountForConfiguration(config)) forKey:kFxGripLiveImageKey_Slots];

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: @""
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI
									| kFxParameterFlag_NOT_ANIMATABLE
									| kFxParameterFlag_USE_FULL_VIEW_WIDTH
									| kFxParameterFlag_NOSTATE];
}

#pragma mark Instance

/*!
	@method		initWithDictionary:effect:
	@abstract	Reads the slot count and snapshot size from the configuration and builds the frame store.
	@discussion	Introduced in FxGrip 0.1.0. */
- (instancetype _Nullable)initWithDictionary:(NSDictionary*_Nonnull)dictionary effect:(id<FxGripEffectHost>_Nonnull)effect
{
	self = [super initWithDictionary:dictionary effect:effect];
	if (self != nil) {
		id declared = _data.parameterDefaultValue;
		NSDictionary *config = [declared isKindOfClass:NSDictionary.class] ? declared : @{};
		_slotCount = FxGripLiveImageSlotCountForConfiguration(config);
		_snapshotSize = kFxGripLiveImageDefaultSnapshotSize;
		NSNumber *snapshotSize = config[kFxGripLiveImageKey_SnapshotSize];
		if ([snapshotSize isKindOfClass:NSNumber.class] && snapshotSize.integerValue >= 0) {
			_snapshotSize = (NSUInteger)snapshotSize.integerValue;
		}
		_lock = [NSLock new];
		_frames = [NSMutableArray arrayWithCapacity:_slotCount];
		for (NSUInteger slot = 0; slot < _slotCount; slot++) {
			[_frames addObject:NSNull.null];
		}
		_dirtySlots = [NSMutableIndexSet indexSet];
		_inFlightSlots = [NSMutableIndexSet indexSet];
		_stagingTextures = [NSMutableDictionary dictionary];
		_views = [NSHashTable weakObjectsHashTable];
	}
	return self;
}

- (NSUInteger)slotCount
{
	return _slotCount;
}

- (NSUInteger)snapshotSize
{
	[_lock lock];
	NSUInteger size = _snapshotSize;
	[_lock unlock];
	return size;
}

- (void)setSnapshotSize:(NSUInteger)snapshotSize
{
	[_lock lock];
	_snapshotSize = snapshotSize;
	[_lock unlock];
}

#pragma mark Views

/*!
	@method		newParameterView
	@abstract	Creates the slot strip view, seeds it from the configuration, and registers it.
	@return		A new FxGripLiveImageView.
	@discussion	Introduced in FxGrip 0.1.0. */
- (NSView *_Nullable)newParameterView
{
	FxGripLiveImageView *view = [FxGripLiveImageView.alloc initWithFrame:NSMakeRect(0, 0, 200, kFxGripLiveImageDefaultHeight)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	[self registerView:view];
	return view;
}

- (void)attachCustomView:(NSView *_Nullable)view
{
	[super attachCustomView:view];
	if ([view isKindOfClass:FxGripLiveImageView.class]) {
		[self registerView:(FxGripLiveImageView *)view];
	}
}

/*! Adds a view to the push list and seeds it with every stored frame. Main thread. */
- (void)registerView:(FxGripLiveImageView *)view
{
	if ([_views containsObject:view]) {
		return;
	}
	[_views addObject:view];
	view.liveImageParameter = self;
	for (NSUInteger slot = 0; slot < _slotCount; slot++) {
		[view showFrame:[self frameInSlot:slot] inSlot:slot];
	}
	[self liveImageViewVisibilityDidChange];
}

/*! Recounts the views currently in a window; the publish paths read the result. Main thread. */
- (void)liveImageViewVisibilityDidChange
{
	NSUInteger onscreen = 0;
	for (FxGripLiveImageView *view in _views) {
		if (view.window != nil) {
			onscreen++;
		}
	}
	[_lock lock];
	_onscreenViewCount = onscreen;
	[_lock unlock];
}

/*! YES while at least one parameter view is on screen. A no-UI render (a batch export
	or a background render) never puts a view on screen, so publishing is suppressed. */
- (BOOL)hasOnscreenView
{
	[_lock lock];
	BOOL onscreen = _onscreenViewCount > 0;
	[_lock unlock];
	return onscreen;
}

#pragma mark Frame store

- (nullable FxGripLiveFrame *)frameInSlot:(NSUInteger)slot
{
	if (slot >= _slotCount) {
		return nil;
	}
	[_lock lock];
	id frame = _frames[slot];
	[_lock unlock];
	return frame == NSNull.null ? nil : frame;
}

/*! Stores the slot's frame and schedules one main-thread flush for every dirty slot. */
- (void)storeFrame:(nullable FxGripLiveFrame *)frame inSlot:(NSUInteger)slot
{
	[_lock lock];
	_frames[slot] = frame ?: (id)NSNull.null;
	[_dirtySlots addIndex:slot];
	BOOL schedule = !_flushScheduled;
	_flushScheduled = YES;
	[_lock unlock];

	if (schedule) {
		__weak typeof(self) weakSelf = self;
		dispatch_async(dispatch_get_main_queue(), ^{
			[weakSelf flushToViews];
		});
	}
}

- (void)flushToViews
{
	[_lock lock];
	NSIndexSet *dirty = [_dirtySlots copy];
	[_dirtySlots removeAllIndexes];
	_flushScheduled = NO;
	NSArray *frames = [_frames copy];
	[_lock unlock];

	for (FxGripLiveImageView *view in _views) {
		[dirty enumerateIndexesUsingBlock:^(NSUInteger slot, BOOL *stop) {
			id frame = frames[slot];
			[view showFrame:(frame == NSNull.null ? nil : frame) inSlot:slot];
		}];
	}
}

/*!
	@method		publishFrame:inSlot:
	@abstract	Stores a ready frame in a slot.
	@return		NO with no view on screen, for an out-of-range slot, or for a nil frame; else YES. */
- (BOOL)publishFrame:(FxGripLiveFrame *)frame inSlot:(NSUInteger)slot
{
	if (frame == nil || slot >= _slotCount || ![self hasOnscreenView]) {
		return NO;
	}
	[self storeFrame:frame inSlot:slot];
	return YES;
}

/*! Draws the image into an RGBA8 frame and stores it. */
- (BOOL)publishCGImage:(CGImageRef)image inSlot:(NSUInteger)slot
{
	return [self publishFrame:[FxGripLiveFrame frameWithCGImage:image] inSlot:slot];
}

/*! Wraps the buffer's pixels in a frame and stores it. */
- (BOOL)publishImageBuffer:(FxGripImageBuffer *)buffer inSlot:(NSUInteger)slot
{
	return [self publishFrame:[FxGripLiveFrame frameWithImageBuffer:buffer] inSlot:slot];
}

- (void)clearSlot:(NSUInteger)slot
{
	if (slot < _slotCount) {
		[self storeFrame:nil inSlot:slot];
	}
}

- (void)clearAllSlots
{
	for (NSUInteger slot = 0; slot < _slotCount; slot++) {
		[self storeFrame:nil inSlot:slot];
	}
}

#pragma mark Metal

/*! Publishes the tile's Metal texture through publishTexture:inSlot:. */
- (BOOL)publishImageTile:(FxImageTile *)tile inSlot:(NSUInteger)slot
{
	id<MTLTexture> texture = tile.metalTexture;
	if (texture == nil) {
		return NO;
	}
	return [self publishTexture:texture inSlot:slot];
}

/*!
	@method		publishTexture:inSlot:
	@abstract	Copies a texture into a slot's snapshot asynchronously.
	@return		NO with no view on screen, for an out-of-range slot, or when nothing is encoded; else YES.
	@discussion	Introduced in FxGrip 0.1.0. The texture is encoded into a single-slot publish batch. */
- (BOOL)publishTexture:(id<MTLTexture>)texture inSlot:(NSUInteger)slot
{
	if (texture == nil || slot >= _slotCount) {
		return NO;
	}
	NSMutableArray *textures = [NSMutableArray arrayWithCapacity:slot + 1];
	for (NSUInteger index = 0; index < slot; index++) {
		[textures addObject:NSNull.null];
	}
	[textures addObject:texture];
	return [self publishTextures:textures];
}

- (BOOL)canEncodeTexture:(id)texture
{
	if (![texture conformsToProtocol:@protocol(MTLTexture)]) {
		return NO;
	}
	id<MTLTexture> metalTexture = texture;
	return metalTexture.textureType == MTLTextureType2D
		&& metalTexture.width > 0 && metalTexture.height > 0
		&& [FxGripLiveFrame supportsPixelFormat:metalTexture.pixelFormat];
}

/*! The command queue for the device, replaced when the device changes. Call locked. */
- (id<MTLCommandQueue>)commandQueueForDevice:(id<MTLDevice>)device
{
	if (_commandQueue == nil || _commandQueue.device.registryID != device.registryID) {
		_commandQueue = [device newCommandQueue];
		_commandQueue.label = @"FxGripLiveImage";
		[_stagingTextures removeAllObjects];
	}
	return _commandQueue;
}

/*! The mipmap level whose longest side is the smallest still at or above the snapshot size. */
- (NSUInteger)mipLevelForWidth:(NSUInteger)width height:(NSUInteger)height snapshotSize:(NSUInteger)snapshotSize
{
	if (snapshotSize == 0) {
		return 0;
	}
	NSUInteger level = 0;
	NSUInteger longest = MAX(width, height);
	while ((longest >> (level + 1)) >= snapshotSize) {
		level++;
	}
	return level;
}

/*! A CPU-readable staging texture matching the source; reused across publishes. Call locked. */
- (id<MTLTexture>)stagingTextureForSlot:(NSUInteger)slot source:(id<MTLTexture>)source mipmapped:(BOOL)mipmapped
{
	id<MTLTexture> staging = _stagingTextures[@(slot)];
	if (staging != nil && staging.pixelFormat == source.pixelFormat
		&& staging.width == source.width && staging.height == source.height
		&& (staging.mipmapLevelCount > 1) == mipmapped) {
		return staging;
	}
	MTLTextureDescriptor *descriptor =
		[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:source.pixelFormat
														   width:source.width
														  height:source.height
													   mipmapped:mipmapped];
	descriptor.storageMode = source.device.hasUnifiedMemory ? MTLStorageModeShared : MTLStorageModeManaged;
	descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
	staging = [source.device newTextureWithDescriptor:descriptor];
	staging.label = [NSString stringWithFormat:@"FxGripLiveImage slot %lu", (unsigned long)slot];
	if (staging != nil) {
		_stagingTextures[@(slot)] = staging;
	}
	return staging;
}

/*!
	@method		publishTextures:
	@abstract	Copies several textures in one command buffer, array index to slot index.
	@param		textures	The per-slot source textures; an NSNull entry skips its slot.
	@return		NO with no view on screen or when nothing is encoded; else YES.
	@discussion	Introduced in FxGrip 0.1.0. Every texture must belong to the same device. A slot still
				reading back its previous texture is skipped. Each source is blitted into a staging
				texture, downscaled to the snapshot size through its mipmap chain, and read back when
				the command buffer completes. */
- (BOOL)publishTextures:(NSArray *)textures
{
	if (![self hasOnscreenView]) {
		return NO;
	}
	id<MTLDevice> device = nil;
	for (id texture in textures) {
		if ([self canEncodeTexture:texture]) {
			device = [(id<MTLTexture>)texture device];
			break;
		}
	}
	if (device == nil) {
		return NO;
	}

	[_lock lock];
	NSUInteger snapshotSize = _snapshotSize;
	id<MTLCommandQueue> queue = [self commandQueueForDevice:device];
	id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
	id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
	NSMutableArray<FxGripLiveImageReadback *> *readbacks = [NSMutableArray array];

	NSUInteger count = MIN(textures.count, _slotCount);
	for (NSUInteger slot = 0; slot < count; slot++) {
		id<MTLTexture> source = textures[slot];
		if (![self canEncodeTexture:source] || source.device.registryID != device.registryID
			|| [_inFlightSlots containsIndex:slot]) {
			continue;
		}
		NSUInteger level = [self mipLevelForWidth:source.width height:source.height snapshotSize:snapshotSize];
		id<MTLTexture> staging = [self stagingTextureForSlot:slot source:source mipmapped:level > 0];
		if (staging == nil) {
			continue;
		}
		if (level >= staging.mipmapLevelCount) {
			level = staging.mipmapLevelCount - 1;
		}
		[blit copyFromTexture:source sourceSlice:0 sourceLevel:0
				 sourceOrigin:MTLOriginMake(0, 0, 0)
				   sourceSize:MTLSizeMake(source.width, source.height, 1)
					toTexture:staging destinationSlice:0 destinationLevel:0
			destinationOrigin:MTLOriginMake(0, 0, 0)];
		if (level > 0) {
			[blit generateMipmapsForTexture:staging];
		}
		if (staging.storageMode == MTLStorageModeManaged) {
			[blit synchronizeResource:staging];
		}
		FxGripLiveImageReadback *readback = [FxGripLiveImageReadback new];
		readback.slot = slot;
		readback.staging = staging;
		readback.level = level;
		[readbacks addObject:readback];
		[_inFlightSlots addIndex:slot];
	}
	[blit endEncoding];
	[_lock unlock];

	if (readbacks.count == 0) {
		return NO;
	}

	__weak typeof(self) weakSelf = self;
	[commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed) {
		[weakSelf completeReadbacks:readbacks error:completed.error];
	}];
	[commandBuffer commit];
	return YES;
}

/*! Reads each finished staging texture into a frame; runs on Metal's completion thread. */
- (void)completeReadbacks:(NSArray<FxGripLiveImageReadback *> *)readbacks error:(nullable NSError *)error
{
	for (FxGripLiveImageReadback *readback in readbacks) {
		FxGripLiveFrame *frame = nil;
		if (error == nil) {
			id<MTLTexture> level = readback.staging;
			if (readback.level > 0) {
				level = [readback.staging newTextureViewWithPixelFormat:readback.staging.pixelFormat
															textureType:MTLTextureType2D
																 levels:NSMakeRange(readback.level, 1)
																 slices:NSMakeRange(0, 1)];
			}
			frame = [FxGripLiveFrame frameWithTexture:level];
		}
		[_lock lock];
		[_inFlightSlots removeIndex:readback.slot];
		[_lock unlock];
		if (frame != nil) {
			[self storeFrame:frame inSlot:readback.slot];
		}
	}
}

@end
