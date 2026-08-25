//
//  FxGripBannerParameter.m
//  FxGrip
//

#import "FxGripBannerParameter.h"
#import "FxGripBanner.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"

// Layout, in view points.
static const CGFloat kFxGripBannerPaddingX = 8.0;
static const CGFloat kFxGripBannerPaddingY = 6.0;
static const CGFloat kFxGripBannerTitleGap = 2.0;

@implementation FxGripBannerView
{
	NSTextField *_title;
	NSTextField *_subtitle;
	NSColor *_fillColor;
	CGFloat _cornerRadius;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_fillColor = NSColor.controlAccentColor;
		_cornerRadius = kFxGripBannerSquareCorners;

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

		[self layoutContents];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (CGFloat)contentHeight
{
	CGFloat height = ceil(_title.intrinsicContentSize.height);
	if (!_subtitle.isHidden) {
		height += kFxGripBannerTitleGap + ceil(_subtitle.intrinsicContentSize.height);
	}
	return height;
}

- (void)layoutContents
{
	CGFloat width = self.bounds.size.width;
	CGFloat innerWidth = MAX(0, width - 2.0 * kFxGripBannerPaddingX);

	CGFloat titleHeight = ceil(_title.intrinsicContentSize.height);
	_title.frame = NSMakeRect(kFxGripBannerPaddingX, kFxGripBannerPaddingY, innerWidth, titleHeight);
	if (!_subtitle.isHidden) {
		CGFloat subHeight = ceil(_subtitle.intrinsicContentSize.height);
		_subtitle.frame = NSMakeRect(kFxGripBannerPaddingX,
									 kFxGripBannerPaddingY + titleHeight + kFxGripBannerTitleGap,
									 innerWidth, subHeight);
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
	NSString *subtitle = nil;
	if ([data getStringParameterValue:&subtitle forKey:kFxGripBannerKey_Subtitle]) {
		_subtitle.stringValue = subtitle ?: @"";
		_subtitle.hidden = subtitle.length == 0;
	}

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

	// A configuration without an explicit title falls back to the parameter name.
	NSString *title = nil;
	if (![defaultValue getStringParameterValue:&title forKey:kFxGripBannerKey_Title]) {
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
