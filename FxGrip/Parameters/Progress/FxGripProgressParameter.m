//
//  FxGripProgressParameter.m
//  FxGrip
//

#import "FxGripProgressParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"
#import <BEFoundation/BEDotView.h>

// Layout, in view points.
static const CGFloat kFxGripProgressDotSize = 12.0;
static const CGFloat kFxGripProgressGap = 6.0;
static const CGFloat kFxGripProgressBarHeight = 8.0;

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
