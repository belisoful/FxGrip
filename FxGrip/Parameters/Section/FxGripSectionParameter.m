/*!
	@file       FxGripSectionParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripSectionParameter
	@abstract   Implements the section header view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view builds the header font from the declared
	            name, weight, and width, applies the letter-case transform to the title, and
	            lays out a full-width label between the top and bottom margins. The parameter
	            creates the value and falls back to the parameter name when no title is declared.
*/

#import "FxGripSectionParameter.h"
#import "FxGripSection.h"
#import "FxGripSectionData.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The styled title header backing a section parameter.
	@discussion	Introduced in FxGrip 0.1.0. The read-only header spans the inspector width and
				sizes its height to the label plus the two margins.
*/
@implementation FxGripSectionView
{
	NSTextField *_label;
	int _marginTop;
	int _marginBottom;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_marginTop = kFxGripSectionDefaultMarginTop;
		_marginBottom = kFxGripSectionDefaultMarginBot;
		_label = [NSTextField labelWithString:@""];
		_label.font = [NSFont boldSystemFontOfSize:kFxGripSectionDefaultSize];
		_label.lineBreakMode = NSLineBreakByTruncatingTail;
		[self addSubview:_label];
		[self layoutContents];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

/*! The label spans the width; the row height is the label height plus the two margins. */
- (void)layoutContents
{
	CGFloat width = self.bounds.size.width;
	CGFloat labelHeight = ceil(_label.intrinsicContentSize.height);
	_label.frame = NSMakeRect(0, _marginTop, width, labelHeight);

	CGFloat totalHeight = _marginTop + labelHeight + _marginBottom;
	if (fabs(self.frame.size.height - totalHeight) > 0.5) {
		NSRect frame = self.frame;
		frame.size.height = totalHeight;
		self.frame = frame;
	}
	[self invalidateIntrinsicContentSize];
}

- (NSSize)intrinsicContentSize
{
	CGFloat labelHeight = ceil(_label.intrinsicContentSize.height);
	return NSMakeSize(NSViewNoIntrinsicMetric, _marginTop + labelHeight + _marginBottom);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[super resizeSubviewsWithOldSize:oldSize];
	[self layoutContents];
}

/*! Builds the header font. A declared font name is honored; otherwise the system font is
	used at the declared weight, defaulting to bold. A non-zero width applies the font's
	width trait. */
- (NSFont *)sectionFontWithName:(nullable NSString *)name
						   size:(CGFloat)size
						 weight:(CGFloat)weight
					  hasWeight:(BOOL)hasWeight
						  width:(CGFloat)width
					   hasWidth:(BOOL)hasWidth
{
	NSFont *font = name.length ? [NSFont fontWithName:name size:size] : nil;
	if (font == nil) {
		font = hasWeight ? [NSFont systemFontOfSize:size weight:weight]
						 : [NSFont boldSystemFontOfSize:size];
	}
	if (hasWidth && width != 0.0) {
		NSFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{
			NSFontTraitsAttribute: @{ NSFontWidthTrait: @(width) }
		}];
		NSFont *widened = [NSFont fontWithDescriptor:descriptor size:size];
		if (widened != nil) {
			font = widened;
		}
	}
	return font;
}

- (NSString *)transform:(NSString *)text with:(FxGripSectionTransform)transform
{
	switch (transform) {
		case FxGripSectionTransformUppercase:	return text.uppercaseString;
		case FxGripSectionTransformLowercase:	return text.lowercaseString;
		case FxGripSectionTransformCapitalize:	return text.capitalizedString;
		case FxGripSectionTransformNone:
		default:								return text;
	}
}

/*!
	@method		updateFromCustomData:
	@abstract	Applies the section configuration to the header label.
	@discussion	Introduced in FxGrip 0.1.0. The value is an FxGripSectionData or a plain
				dictionary of the same shape. Weight and width arrive as trait values scaled by
				1000. Opacity multiplies the resolved color's alpha, and dims the inherited label
				color when no color is declared. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	FxGripSectionData *data = nil;
	if ([value isKindOfClass:FxGripSectionData.class]) {
		data = (FxGripSectionData*)value;
	} else if ([value isKindOfClass:NSDictionary.class]) {
		data = [FxGripSectionData.alloc initWithDictionary:(NSDictionary*)value];
	} else {
		return;
	}

	CGFloat size = kFxGripSectionDefaultSize;
	double sizeValue = 0.0;
	if ([data getFloatValue:&sizeValue forKey:kFxGripSectionKey_Size] && sizeValue > 0.0) {
		size = sizeValue;
	}

	int weightRaw = 0;
	BOOL hasWeight = [data getIntValue:&weightRaw forKey:kFxGripSectionKey_Weight];
	int widthRaw = 0;
	BOOL hasWidth = [data getIntValue:&widthRaw forKey:kFxGripSectionKey_Width];
	NSString *fontName = nil;
	[data getStringParameterValue:&fontName forKey:kFxGripSectionKey_FontName];

	// Weight and width arrive as trait values scaled by 1000 so they survive the integer
	// keys (NSFontWeight/NSFontWidthTrait span -1.0…1.0).
	_label.font = [self sectionFontWithName:fontName
									   size:size
									 weight:hasWeight ? weightRaw / 1000.0 : 0.0
								  hasWeight:hasWeight
									  width:hasWidth ? widthRaw / 1000.0 : 0.0
								   hasWidth:hasWidth];

	int alignment = NSTextAlignmentLeft;
	if ([data getIntValue:&alignment forKey:kFxGripSectionKey_Alignment]) {
		_label.alignment = (NSTextAlignment)alignment;
	}

	int transform = FxGripSectionTransformNone;
	[data getIntValue:&transform forKey:kFxGripSectionKey_Transform];
	NSString *title = nil;
	if ([data getStringParameterValue:&title forKey:kFxGripSectionKey_Title]) {
		_label.stringValue = [self transform:(title ?: @"") with:(FxGripSectionTransform)transform];
	}

	double opacity = kFxGripSectionDefaultOpacity;
	double opacityValue = 0.0;
	BOOL hasOpacity = [data getFloatValue:&opacityValue forKey:kFxGripSectionKey_Opacity];
	if (hasOpacity) {
		opacity = MIN(1.0, MAX(0.0, opacityValue));
	}

	double red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0;
	if ([data getRedValue:&red greenValue:&green blueValue:&blue alphaValue:&alpha forKey:kFxGripSectionKey_Color]) {
		_label.textColor = [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha * opacity];
	} else if (hasOpacity) {
		// No color override; dim the inherited default label color to the requested opacity.
		_label.textColor = [NSColor.labelColor colorWithAlphaComponent:opacity];
	}

	int margin = 0;
	if ([data getIntValue:&margin forKey:kFxGripSectionKey_MarginTop]) {
		_marginTop = MAX(0, margin);
	}
	if ([data getIntValue:&margin forKey:kFxGripSectionKey_MarginBottom]) {
		_marginBottom = MAX(0, margin);
	}

	[self layoutContents];
}

@end


/*!
	@abstract	The custom parameter that hosts a styled section title header.
	@discussion	Introduced in FxGrip 0.1.0. The value is an FxGripSectionData. Creation sets the
				custom-UI, not-animatable, full-view-width, and no-state flags.
*/
@implementation FxGripSectionParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Section;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Section;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	return [NSSet setWithObject:FxGripSectionData.class];
}

/*!
	@method		addParameter:toEffect:
	@abstract	Adds the section header as a custom parameter to the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. A declared value without a title falls back to the
				parameter name. Creation sets the custom-UI, not-animatable, full-view-width, and
				no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	id declared = parameter.parameterDefaultValue;
	NSDictionary *config = [declared isKindOfClass:NSDictionary.class] ? declared : @{};
	FxGripSectionData *data = [FxGripSectionData.alloc initWithDictionary:config];

	// A configuration without an explicit title falls back to the parameter name.
	NSString *title = nil;
	if (![data getStringParameterValue:&title forKey:kFxGripSectionKey_Title]) {
		[data setStringParameterValue:parameter.parameterName ?: @"" forKey:kFxGripSectionKey_Title];
	}

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: @""
					   parameterID: parameter.parameterID
					  defaultValue: data
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI
									| kFxParameterFlag_NOT_ANIMATABLE
									| kFxParameterFlag_USE_FULL_VIEW_WIDTH
									| kFxParameterFlag_NOSTATE];
}

- (NSView *_Nullable)newParameterView
{
	FxGripSectionView *view = [FxGripSectionView.alloc initWithFrame:NSMakeRect(0, 0, 200, 22)];
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripSectionData.alloc initWithDictionary:declared]];
	}
	return view;
}

@end
