/*!
	@file       FxGripProgressParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripProgressParameter
	@abstract   Implements the progress display view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view drives an NSProgressIndicator, a
	            BEFoundation dot, and a label from the value dictionary. A negative fraction
	            spins an indeterminate bar. The parameter seeds the display from the declared
	            default and is updated by setting the value.
*/

#import "FxGripProgressParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"
#import <BEFoundation/BEDotView.h>

// Layout, in view points.
static const CGFloat kFxGripProgressDotSize = 12.0;
static const CGFloat kFxGripProgressGap = 6.0;
static const CGFloat kFxGripProgressBarHeight = 8.0;

/*!
	@abstract	The progress display backing a progress parameter.
	@discussion	Introduced in FxGrip 0.1.0. The bar, dot, and label are read-only and driven from
				the pushed value.
*/
@implementation FxGripProgressView
{
	BEDotView *_dot;
	NSTextField *_label;
	NSProgressIndicator *_bar;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_dot = [BEDotView.alloc initWithFrame:NSMakeRect(0, 0, kFxGripProgressDotSize, kFxGripProgressDotSize)];
		[_dot setState:BEDotStateOff];
		[self addSubview:_dot];

		_label = [NSTextField labelWithString:@""];
		_label.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		_label.lineBreakMode = NSLineBreakByTruncatingTail;
		[self addSubview:_label];

		_bar = [NSProgressIndicator.alloc initWithFrame:NSZeroRect];
		_bar.style = NSProgressIndicatorStyleBar;
		_bar.indeterminate = NO;
		_bar.minValue = 0.0;
		_bar.maxValue = 1.0;
		_bar.controlSize = NSControlSizeSmall;
		[self addSubview:_bar];

		[self layoutContents];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

/*! The dot and label share the top row; the bar spans the width beneath them. */
- (void)layoutContents
{
	CGFloat width = self.bounds.size.width;
	CGFloat labelHeight = ceil(_label.intrinsicContentSize.height);

	_dot.frame = NSMakeRect(0, (labelHeight - kFxGripProgressDotSize) / 2.0,
							kFxGripProgressDotSize, kFxGripProgressDotSize);
	CGFloat labelX = kFxGripProgressDotSize + kFxGripProgressGap;
	_label.frame = NSMakeRect(labelX, 0, MAX(0, width - labelX), labelHeight);

	CGFloat barY = labelHeight + kFxGripProgressGap;
	_bar.frame = NSMakeRect(0, barY, width, kFxGripProgressBarHeight);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[super resizeSubviewsWithOldSize:oldSize];
	[self layoutContents];
}

/*!
	@method		updateFromCustomData:
	@abstract	Drives the bar, dot, and label from the pushed value.
	@discussion	Introduced in FxGrip 0.1.0. A value that is not an FxGripDictionary is ignored. A
				fraction below zero spins an indeterminate bar; a fraction from zero to one sets
				the determinate bar. The integer sets the dot state and the string sets the label. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *dictionary = (FxGripDictionary*)value;

	double fraction = 0.0;
	if ([dictionary getFloatValue:&fraction]) {
		if (fraction < 0.0) {
			// A negative fraction means the length is unknown: spin an indeterminate bar.
			if (!_bar.isIndeterminate) {
				_bar.indeterminate = YES;
				[_bar startAnimation:nil];
			}
		} else {
			if (_bar.isIndeterminate) {
				[_bar stopAnimation:nil];
				_bar.indeterminate = NO;
			}
			_bar.doubleValue = fraction > 1.0 ? 1.0 : fraction;
		}
	}
	int state = BEDotStateOff;
	if ([dictionary getIntValue:&state]) {
		[_dot setState:(BEDotState)state];
	}
	NSString *text = nil;
	if ([dictionary getStringParameterValue:&text]) {
		_label.stringValue = text ?: @"";
	}
}

@end


/*!
	@abstract	The custom parameter that hosts the read-only progress display.
	@discussion	Introduced in FxGrip 0.1.0. The value is an FxGripDictionary. Creation sets the
				custom-UI and no-state flags.
*/
@implementation FxGripProgressParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Progress;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Progress;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Adds the progress display as a custom parameter to the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The declared default seeds the initial fraction, dot
				state, and label. Creation sets the custom-UI and no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The declared default may set the initial fraction (float), dot state (int), and label (string).
	NSNumber *fraction = @(0.0);
	NSNumber *state = @(BEDotStateOff);
	NSString *text = @"";
	NSDictionary *declared = parameter.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		if ([declared[kCustomAPI_FloatKey] isKindOfClass:NSNumber.class]) {
			fraction = declared[kCustomAPI_FloatKey];
		}
		if ([declared[kCustomAPI_IntKey] isKindOfClass:NSNumber.class]) {
			state = declared[kCustomAPI_IntKey];
		}
		if ([declared[kCustomAPI_StringKey] isKindOfClass:NSString.class]) {
			text = declared[kCustomAPI_StringKey];
		}
	}

	FxGripDictionary *defaultValue = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_FloatKey: fraction,
		kCustomAPI_IntKey: state,
		kCustomAPI_StringKey: text,
	}];

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE];
}

- (NSView *_Nullable)newParameterView
{
	FxGripProgressView *view = [FxGripProgressView.alloc initWithFrame:NSMakeRect(0, 0, 200, 34)];
	NSDictionary *declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		// The host pushes the live value after attaching; seed from the declared default.
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
