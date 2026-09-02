//
//  FxGripBannerParameter.m
//  FxGrip
//

#import "FxGripBannerParameter.h"
#import "FxGripBanner.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"

// Layout, in view points.
static const CGFloat kFxGripBannerPaddingX = 8.0;
static const CGFloat kFxGripBannerPaddingY = 6.0;
static const CGFloat kFxGripBannerTitleGap = 2.0;

// The companion action button is a small square in the top-right corner.
static const CGFloat kFxGripBannerButtonSize = 18.0;

@implementation FxGripBannerView
{
	NSImageView *_imageView;
	NSTextField *_title;
	NSTextField *_subtitle;
	NSButton *_actionButton;
	NSColor *_fillColor;
	CGFloat _cornerRadius;
	NSSize _imageDisplaySize;
	NSURL *_linkURL;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_fillColor = NSColor.controlAccentColor;
		_cornerRadius = kFxGripBannerSquareCorners;
		_imageDisplaySize = NSZeroSize;

		_imageView = [NSImageView.alloc initWithFrame:NSZeroRect];
		_imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
		_imageView.imageAlignment = NSImageAlignLeft;
		_imageView.hidden = YES;
		[self addSubview:_imageView];

		_title = [NSTextField labelWithString:@""];
		_title.font = [NSFont boldSystemFontOfSize:kFxGripBannerDefaultFontSize];
		_title.textColor = NSColor.whiteColor;
		_title.lineBreakMode = NSLineBreakByTruncatingTail;
		[self addSubview:_title];

		_subtitle = [NSTextField labelWithString:@""];
		_subtitle.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		_subtitle.textColor = NSColor.whiteColor;
		_subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
		_subtitle.hidden = YES;
		[self addSubview:_subtitle];

		_actionButton = [NSButton.alloc initWithFrame:NSZeroRect];
		_actionButton.bezelStyle = NSBezelStyleHelpButton;
		_actionButton.title = @"";
		_actionButton.target = self;
		_actionButton.action = @selector(openLink:);
		_actionButton.hidden = YES;
		[self addSubview:_actionButton];

		[self layoutContents];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)hasImage
{
	return !_imageView.isHidden && _imageDisplaySize.height > 0.0;
}

- (BOOL)hasTitle
{
	return _title.stringValue.length > 0;
}

- (CGFloat)contentHeight
{
	CGFloat height = 0.0;
	if ([self hasImage]) {
		height += _imageDisplaySize.height;
	}
	if ([self hasTitle]) {
		if (height > 0.0) {
			height += kFxGripBannerTitleGap;
		}
		height += ceil(_title.intrinsicContentSize.height);
	}
	if (!_subtitle.isHidden) {
		if (height > 0.0) {
			height += kFxGripBannerTitleGap;
		}
		height += ceil(_subtitle.intrinsicContentSize.height);
	}
	return height;
}

- (void)layoutContents
{
	CGFloat width = self.bounds.size.width;
	CGFloat innerWidth = MAX(0, width - 2.0 * kFxGripBannerPaddingX);
	CGFloat y = kFxGripBannerPaddingY;

	if ([self hasImage]) {
		_imageView.frame = NSMakeRect(kFxGripBannerPaddingX, y,
									  MIN(_imageDisplaySize.width, innerWidth), _imageDisplaySize.height);
		y += _imageDisplaySize.height;
	}
	if ([self hasTitle]) {
		if (y > kFxGripBannerPaddingY) {
			y += kFxGripBannerTitleGap;
		}
		CGFloat titleHeight = ceil(_title.intrinsicContentSize.height);
		_title.frame = NSMakeRect(kFxGripBannerPaddingX, y, innerWidth, titleHeight);
		y += titleHeight;
	} else {
		_title.frame = NSMakeRect(kFxGripBannerPaddingX, y, innerWidth, 0);
	}
	if (!_subtitle.isHidden) {
		if (y > kFxGripBannerPaddingY) {
			y += kFxGripBannerTitleGap;
		}
		CGFloat subHeight = ceil(_subtitle.intrinsicContentSize.height);
		_subtitle.frame = NSMakeRect(kFxGripBannerPaddingX, y, innerWidth, subHeight);
	}

	if (!_actionButton.isHidden) {
		_actionButton.frame = NSMakeRect(width - kFxGripBannerPaddingX - kFxGripBannerButtonSize,
										 kFxGripBannerPaddingY, kFxGripBannerButtonSize, kFxGripBannerButtonSize);
	}

	CGFloat totalHeight = [self contentHeight] + 2.0 * kFxGripBannerPaddingY;
	if (fabs(self.frame.size.height - totalHeight) > 0.5) {
		NSRect frame = self.frame;
		frame.size.height = totalHeight;
		self.frame = frame;
	}
	[self invalidateIntrinsicContentSize];
	[self setNeedsDisplay:YES];
}

- (NSSize)intrinsicContentSize
{
	return NSMakeSize(NSViewNoIntrinsicMetric, [self contentHeight] + 2.0 * kFxGripBannerPaddingY);
}

/*! Opens the banner's link. Wired to the companion button and to a click on the banner. */
- (void)openLink:(id)sender
{
	if (_linkURL != nil) {
		[NSWorkspace.sharedWorkspace openURL:_linkURL];
	}
}

- (void)mouseDown:(NSEvent *)event
{
	if (_linkURL != nil) {
		[self openLink:self];
	} else {
		[super mouseDown:event];
	}
}

- (void)resetCursorRects
{
	if (_linkURL != nil) {
		[self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
	}
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[super resizeSubviewsWithOldSize:oldSize];
	[self layoutContents];
}

- (void)drawRect:(NSRect)dirtyRect
{
	CGFloat radius = MAX(0.0, _cornerRadius);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:radius yRadius:radius];
	[_fillColor setFill];
	[path fill];
}

- (nullable NSColor *)colorFromData:(FxGripDictionary *)data forKey:(id<NSCopying>)key
{
	double red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
	if ([data getRedValue:&red greenValue:&green blueValue:&blue alphaValue:&alpha forKey:key]) {
		return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
	}
	return nil;
}

/*! Resolves a banner image name. A named AppKit image is tried first, then a file at the
	path; the plugin bundle registers its named assets, so the name lookup finds them. */
- (nullable NSImage *)imageForName:(NSString *)name
{
	if (name.length == 0) {
		return nil;
	}
	NSImage *image = [NSImage imageNamed:name];
	if (image == nil && [NSFileManager.defaultManager fileExistsAtPath:name]) {
		image = [NSImage.alloc initWithContentsOfFile:name];
	}
	return image;
}

/*! Sizes the image for display within the width and the FxFactory max-width constraint. */
- (NSSize)displaySizeForImage:(NSImage *)image
{
	NSSize size = image.size;
	if (size.width <= 0.0 || size.height <= 0.0) {
		return NSZeroSize;
	}
	CGFloat innerWidth = MAX(0, self.bounds.size.width - 2.0 * kFxGripBannerPaddingX);
	CGFloat maxWidth = MIN(kFxGripBannerMaxImageWidth, innerWidth > 0 ? innerWidth : kFxGripBannerMaxImageWidth);
	CGFloat displayWidth = MIN(size.width, maxWidth);
	CGFloat scale = displayWidth / size.width;
	return NSMakeSize(displayWidth, ceil(size.height * scale));
}

- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *data = (FxGripDictionary*)value;

	double size = 0.0;
	if ([data getFloatValue:&size forKey:kFxGripBannerKey_FontSize] && size > 0.0) {
		_title.font = [NSFont boldSystemFontOfSize:size];
	}
	NSColor *fill = [self colorFromData:data forKey:kFxGripBannerKey_FillColor];
	if (fill != nil) {
		_fillColor = fill;
	}
	NSColor *textColor = [self colorFromData:data forKey:kFxGripBannerKey_TextColor];
	if (textColor != nil) {
		_title.textColor = textColor;
		_subtitle.textColor = textColor;
	}
	double radius = 0.0;
	if ([data getFloatValue:&radius forKey:kFxGripBannerKey_CornerRadius]) {
		_cornerRadius = radius;
	}
	NSString *title = nil;
	if ([data getStringParameterValue:&title forKey:kFxGripBannerKey_Title]) {
		_title.stringValue = title ?: @"";
	}
	_title.hidden = _title.stringValue.length == 0;
	NSString *subtitle = nil;
	if ([data getStringParameterValue:&subtitle forKey:kFxGripBannerKey_Subtitle]) {
		_subtitle.stringValue = subtitle ?: @"";
		_subtitle.hidden = subtitle.length == 0;
	}

	NSString *imageName = nil;
	if ([data getStringParameterValue:&imageName forKey:kFxGripBannerKey_ImageName]) {
		NSImage *image = [self imageForName:imageName];
		BOOL isTemplate = NO;
		[data getBoolValue:&isTemplate forKey:kFxGripBannerKey_TemplateImage];
		image.template = isTemplate;
		_imageView.image = image;
		// A template image draws tinted by the text color so a black graphic reads on any UI.
		_imageView.contentTintColor = isTemplate ? _title.textColor : nil;
		_imageDisplaySize = image != nil ? [self displaySizeForImage:image] : NSZeroSize;
		_imageView.hidden = image == nil;
	}

	NSString *link = nil;
	if ([data getStringParameterValue:&link forKey:kFxGripBannerKey_LinkURL]) {
		_linkURL = link.length ? [NSURL URLWithString:link] : nil;
	}
	BOOL showActionButton = NO;
	if ([data getBoolValue:&showActionButton forKey:kFxGripBannerKey_ActionButton]) {
		_actionButton.hidden = !(showActionButton && _linkURL != nil);
	}
	[self.window invalidateCursorRectsForView:self];

	[self layoutContents];
}

@end


@implementation FxGripBannerParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Banner;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Banner;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id declared = parameter.parameterDefaultValue;
	NSDictionary *config = [declared isKindOfClass:NSDictionary.class] ? declared : @{};
	FxGripDictionary *defaultValue = [FxGripDictionary dictionaryWithDictionary:config];

	// A text banner without an explicit title falls back to the parameter name. An image
	// banner takes no title fallback, so a graphic can stand alone.
	NSString *title = nil;
	NSString *imageName = nil;
	BOOL hasImage = [defaultValue getStringParameterValue:&imageName forKey:kFxGripBannerKey_ImageName]
		&& imageName.length > 0;
	if (![defaultValue getStringParameterValue:&title forKey:kFxGripBannerKey_Title] && !hasImage) {
		[defaultValue setStringParameterValue:parameter.parameterName ?: @"" forKey:kFxGripBannerKey_Title];
	}

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: @""
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI
									| kFxParameterFlag_NOT_ANIMATABLE
									| kFxParameterFlag_USE_FULL_VIEW_WIDTH
									| kFxParameterFlag_NOSTATE];
}

- (NSView *_Nullable)newParameterView
{
	FxGripBannerView *view = [FxGripBannerView.alloc initWithFrame:NSMakeRect(0, 0, 200, 28)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
