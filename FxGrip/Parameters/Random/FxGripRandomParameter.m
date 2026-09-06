/*!
	@file       FxGripRandomParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRandomParameter
	@abstract   Implements the random integer view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view lays out an integer field, a stepper, and a
	            reload button, clamps every value to the configured range, and writes changes back
	            through an out-of-band access context. Reload draws a uniform integer in the range.
	            The parameter stores the value, range, and step in an FxGripDictionary and seeds the
	            view from the declared configuration.
*/

#import "FxGripRandomParameter.h"
#import "FxGripRandom.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGrip_ARC.h"

// Layout, in view points.
static const CGFloat kFxGripRandomFieldWidth = 60.0;
static const CGFloat kFxGripRandomStepperWidth = 19.0;
static const CGFloat kFxGripRandomButtonWidth = 28.0;
static const CGFloat kFxGripRandomGap = 4.0;
static const CGFloat kFxGripRandomHeight = 22.0;

/*!
	@abstract	The integer field, stepper, and reload button backing a random parameter.
	@discussion	Introduced in FxGrip 0.1.0. The view clamps values to the configured range and writes
				each change back through an out-of-band access context. Reload draws a uniform integer
				in the range. */
@implementation FxGripRandomView
{
	NSTextField *_field;
	NSStepper *_stepper;
	NSButton *_reload;
	int _value;
	int _min;
	int _max;
	int _step;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_value = kFxGripRandomDefaultValue;
		_min = kFxGripRandomDefaultMin;
		_max = kFxGripRandomDefaultMax;
		_step = kFxGripRandomDefaultStep;

		CGFloat x = 0.0;
		_field = [NSTextField.alloc initWithFrame:NSMakeRect(x, 0, kFxGripRandomFieldWidth, kFxGripRandomHeight)];
		_field.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		_field.alignment = NSTextAlignmentRight;
		_field.target = self;
		_field.action = @selector(fieldChanged:);
		NSNumberFormatter *formatter = [NSNumberFormatter.alloc init];
		formatter.numberStyle = NSNumberFormatterNoStyle;
		formatter.allowsFloats = NO;
		_field.formatter = formatter;
		[self addSubview:_field];

		x += kFxGripRandomFieldWidth + kFxGripRandomGap;
		_stepper = [NSStepper.alloc initWithFrame:NSMakeRect(x, 0, kFxGripRandomStepperWidth, kFxGripRandomHeight)];
		_stepper.valueWraps = NO;
		_stepper.autorepeat = YES;
		_stepper.target = self;
		_stepper.action = @selector(stepperChanged:);
		[self addSubview:_stepper];

		x += kFxGripRandomStepperWidth + kFxGripRandomGap;
		_reload = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameRefreshTemplate]
									 target:self
									 action:@selector(reloadClicked:)];
		_reload.frame = NSMakeRect(x, 0, kFxGripRandomButtonWidth, kFxGripRandomHeight);
		_reload.bezelStyle = NSBezelStyleTexturedRounded;
		_reload.toolTip = @"Randomize";
		[self addSubview:_reload];

		[self applyRange];
		[self displayValue:_value];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSSize)intrinsicContentSize
{
	CGFloat width = kFxGripRandomFieldWidth + kFxGripRandomStepperWidth + kFxGripRandomButtonWidth
		+ 2.0 * kFxGripRandomGap;
	return NSMakeSize(width, kFxGripRandomHeight);
}

#pragma mark Range and value

- (void)applyRange
{
	int lo = MIN(_min, _max);
	int hi = MAX(_min, _max);
	_stepper.minValue = lo;
	_stepper.maxValue = hi;
	_stepper.increment = MAX(1, _step);
}

- (int)clampValue:(int)value
{
	int lo = MIN(_min, _max);
	int hi = MAX(_min, _max);
	return MAX(lo, MIN(hi, value));
}

/*! Updates the field and stepper to show a value without writing it back. */
- (void)displayValue:(int)value
{
	_value = value;
	_field.integerValue = value;
	_stepper.integerValue = value;
}

/*! Draws a uniform integer in the closed range from min to max. */
- (int)randomValue
{
	int lo = MIN(_min, _max);
	int hi = MAX(_min, _max);
	uint32_t span = (uint32_t)((int64_t)hi - (int64_t)lo);
	uint32_t draw = span == UINT32_MAX ? arc4random() : arc4random_uniform(span + 1);
	return (int)((int64_t)lo + (int64_t)draw);
}

#pragma mark Actions

- (void)fieldChanged:(nullable id)sender
{
	int value = [self clampValue:(int)_field.integerValue];
	[self displayValue:value];
	[self writeBackValue:value];
}

- (void)stepperChanged:(nullable id)sender
{
	int value = [self clampValue:(int)_stepper.integerValue];
	[self displayValue:value];
	[self writeBackValue:value];
}

/*! Randomizes the value in the configured range and writes it back. */
- (void)reloadClicked:(nullable id)sender
{
	int value = [self randomValue];
	[self displayValue:value];
	[self writeBackValue:value];
}

/*! The action runs outside a host call, so the write goes through an out-of-band access
	context. */
- (void)writeBackValue:(int)newValue
{
	FxGripTileableEffect *effect = (FxGripTileableEffect*)self.parameterEffect;
	if (effect == nil) {
		return;
	}
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:effect];
	CMTime time = access.currentTime;

	NSObject<NSSecureCoding, NSCopying> *stored = nil;
	[effect.apiManager.paramGetAPIv6 getCustomParameterValue:&stored
											   fromParameter:self.parameterID
													  atTime:time];
	FxGripDictionary *dictionary = [stored isKindOfClass:FxGripDictionary.class]
		? (FxGripDictionary*)stored
		: [FxGripDictionary dictionaryWithDictionary:@{}];
	dictionary.locked = NO;
	[dictionary setIntValue:newValue];
	[effect.apiManager.paramSetAPIv5 setCustomParameterValue:dictionary
												 toParameter:self.parameterID
													  atTime:time];
}

#pragma mark Data

/*!
	@method		updateFromCustomData:
	@abstract	Applies the range, step, and value from the parameter's FxGripDictionary value.
	@param		value	The parameter value; ignored when it is not an FxGripDictionary.
	@discussion	Introduced in FxGrip 0.1.0. A changed min, max, or step reconfigures the stepper. The
				value is clamped to the range before display. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *data = (FxGripDictionary*)value;

	BOOL rangeChanged = NO;
	int bound = 0;
	if ([data getIntValue:&bound forKey:kFxGripRandomKey_Min]) {
		_min = bound;
		rangeChanged = YES;
	}
	if ([data getIntValue:&bound forKey:kFxGripRandomKey_Max]) {
		_max = bound;
		rangeChanged = YES;
	}
	if ([data getIntValue:&bound forKey:kFxGripRandomKey_Step]) {
		_step = bound;
		rangeChanged = YES;
	}
	if (rangeChanged) {
		[self applyRange];
	}

	int current = _value;
	if ([data getIntValue:&current forKey:kFxGripRandomKey_Value]) {
		[self displayValue:[self clampValue:current]];
	}
}

@end


/*!
	@abstract	The integer custom parameter with a reload button that randomizes it.
	@discussion	Introduced in FxGrip 0.1.0. Creation stores the value, range, and step in an
				FxGripDictionary and adds the custom-UI and no-state flags. */
@implementation FxGripRandomParameter

/*! @abstract The registry type string for the random parameter. */
+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Random;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Random;
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
	@abstract	Creates the random custom parameter on the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The declared default may set the value, min, max, and step.
				Creation adds the custom-UI and no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	NSNumber *value = @(kFxGripRandomDefaultValue);
	NSNumber *minimum = @(kFxGripRandomDefaultMin);
	NSNumber *maximum = @(kFxGripRandomDefaultMax);
	NSNumber *step = @(kFxGripRandomDefaultStep);
	NSDictionary *declared = parameter.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		if ([declared[kFxGripRandomKey_Value] isKindOfClass:NSNumber.class]) {
			value = declared[kFxGripRandomKey_Value];
		}
		if ([declared[kFxGripRandomKey_Min] isKindOfClass:NSNumber.class]) {
			minimum = declared[kFxGripRandomKey_Min];
		}
		if ([declared[kFxGripRandomKey_Max] isKindOfClass:NSNumber.class]) {
			maximum = declared[kFxGripRandomKey_Max];
		}
		if ([declared[kFxGripRandomKey_Step] isKindOfClass:NSNumber.class]) {
			step = declared[kFxGripRandomKey_Step];
		}
	}

	FxGripDictionary *defaultValue = [FxGripDictionary dictionaryWithDictionary:@{
		kFxGripRandomKey_Value: value,
		kFxGripRandomKey_Min: minimum,
		kFxGripRandomKey_Max: maximum,
		kFxGripRandomKey_Step: step,
	}];

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE];
}

/*!
	@method		newParameterView
	@abstract	Creates the random view wired to this parameter and seeds it from the declared configuration.
	@return		A new FxGripRandomView.
	@discussion	Introduced in FxGrip 0.1.0. */
- (NSView *_Nullable)newParameterView
{
	FxGripRandomView *view = [FxGripRandomView.alloc initWithFrame:NSMakeRect(0, 0, 120, 22)];
	view.parameterEffect = self.effect;
	view.parameterID = self.parameterID;
	id declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
