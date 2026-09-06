/*!
	@file       FxGripCapsuleParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCapsuleParameter
	@abstract   Implements the pill badge view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view draws a rounded-rectangle fill behind a
	            centered label and sizes itself to the text plus padding. A corner radius below
	            zero draws a full pill. The parameter seeds the badge from the declared default.
*/

#import "FxGripCapsuleParameter.h"
#import "FxGripCapsule.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"

// Layout, in view points.
static const CGFloat kFxGripCapsulePaddingX = 10.0;
static const CGFloat kFxGripCapsulePaddingY = 3.0;

/*!
	@abstract	The pill-shaped badge backing a capsule parameter.
	@discussion	Introduced in FxGrip 0.1.0. The read-only badge draws a rounded fill behind a
				centered label.
*/
@implementation FxGripCapsuleView
{
	NSTextField *_label;
	NSColor *_fillColor;
	CGFloat _cornerRadius;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_fillColor = NSColor.systemGrayColor;
		_cornerRadius = kFxGripCapsulePillRadius;
		_label = [NSTextField labelWithString:@""];
		_label.font = [NSFont systemFontOfSize:kFxGripCapsuleDefaultFontSize];
		_label.textColor = NSColor.whiteColor;
		_label.alignment = NSTextAlignmentCenter;
		_label.lineBreakMode = NSLineBreakByTruncatingTail;
		[self addSubview:_label];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSSize)intrinsicContentSize
{
	NSSize text = _label.intrinsicContentSize;
	return NSMakeSize(ceil(text.width) + 2.0 * kFxGripCapsulePaddingX,
					  ceil(text.height) + 2.0 * kFxGripCapsulePaddingY);
}

- (void)layoutContents
{
	NSSize size = self.intrinsicContentSize;
	NSRect frame = self.frame;
	if (fabs(frame.size.width - size.width) > 0.5 || fabs(frame.size.height - size.height) > 0.5) {
		frame.size = size;
		self.frame = frame;
	}
	_label.frame = NSMakeRect(kFxGripCapsulePaddingX, kFxGripCapsulePaddingY,
							  self.bounds.size.width - 2.0 * kFxGripCapsulePaddingX,
							  self.bounds.size.height - 2.0 * kFxGripCapsulePaddingY);
	[self invalidateIntrinsicContentSize];
	[self setNeedsDisplay:YES];
}

/*!
	@method		drawRect:
	@abstract	Fills the badge as a rounded rectangle.
	@discussion	Introduced in FxGrip 0.1.0. A negative corner radius draws a full pill by using
				half the height as the radius. */
- (void)drawRect:(NSRect)dirtyRect
{
	CGFloat radius = _cornerRadius >= 0.0 ? _cornerRadius : self.bounds.size.height / 2.0;
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

/*!
	@method		updateFromCustomData:
	@abstract	Applies the text, size, colors, and radius from the pushed value.
	@discussion	Introduced in FxGrip 0.1.0. A value that is not an FxGripDictionary is ignored.
				The badge relays out after applying the value. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *data = (FxGripDictionary*)value;

	double size = 0.0;
	if ([data getFloatValue:&size forKey:kFxGripCapsuleKey_FontSize] && size > 0.0) {
		_label.font = [NSFont systemFontOfSize:size];
	}
	NSColor *fill = [self colorFromData:data forKey:kFxGripCapsuleKey_FillColor];
	if (fill != nil) {
		_fillColor = fill;
	}
	NSColor *textColor = [self colorFromData:data forKey:kFxGripCapsuleKey_TextColor];
	if (textColor != nil) {
		_label.textColor = textColor;
	}
	double radius = 0.0;
	if ([data getFloatValue:&radius forKey:kFxGripCapsuleKey_CornerRadius]) {
		_cornerRadius = radius;
	}
	NSString *title = nil;
	if ([data getStringParameterValue:&title forKey:kFxGripCapsuleKey_Title]) {
		_label.stringValue = title ?: @"";
	}

	[self layoutContents];
}

@end


/*!
	@abstract	The custom parameter that hosts the read-only pill badge.
	@discussion	Introduced in FxGrip 0.1.0. The value is an FxGripDictionary. Creation sets the
				custom-UI, not-animatable, and no-state flags.
*/
@implementation FxGripCapsuleParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Capsule;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Capsule;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Adds the pill badge as a custom parameter to the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. Creation sets the custom-UI, not-animatable, and
				no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id declared = parameter.parameterDefaultValue;
	FxGripDictionary *defaultValue = [declared isKindOfClass:NSDictionary.class]
		? [FxGripDictionary dictionaryWithDictionary:declared]
		: [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_StringKey: @""}];

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI
									| kFxParameterFlag_NOT_ANIMATABLE
									| kFxParameterFlag_NOSTATE];
}

- (NSView *_Nullable)newParameterView
{
	FxGripCapsuleView *view = [FxGripCapsuleView.alloc initWithFrame:NSMakeRect(0, 0, 80, 18)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
