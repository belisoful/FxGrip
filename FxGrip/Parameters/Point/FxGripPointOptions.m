//
//  FxGripPointOptions.m
//  FxGrip
//

#import "FxGripPointOptions.h"
#import "FxGripTypes.h"

@implementation FxGripPointOptions

- (nonnull instancetype)initWithConfiguration:(nullable NSDictionary *)configuration
{
	self = [super init];
	if (self != nil) {
		NSDictionary *config = [configuration isKindOfClass:NSDictionary.class] ? configuration : @{};

		_defaultX = [self doubleFrom:config key:kFxParameterProperty_X fallback:kFxGripPointDefaultPosition];
		_defaultY = [self doubleFrom:config key:kFxParameterProperty_Y fallback:kFxGripPointDefaultPosition];
		_rangeMinX = [self doubleFrom:config key:kFxGripPointKey_RangeMinX fallback:0.0];
		_rangeMaxX = [self doubleFrom:config key:kFxGripPointKey_RangeMaxX fallback:1.0];
		_rangeMinY = [self doubleFrom:config key:kFxGripPointKey_RangeMinY fallback:0.0];
		_rangeMaxY = [self doubleFrom:config key:kFxGripPointKey_RangeMaxY fallback:1.0];

		_coordinateMapping = [self doubleFrom:config key:kFxGripPointKey_CoordinateMapping fallback:0.0] == FxGripPointCoordinateQuartzComposer
			? FxGripPointCoordinateQuartzComposer : FxGripPointCoordinatePixel;
		_compensateFrameMargin = [self boolFrom:config key:kFxGripPointKey_CompensateFrameMargin fallback:NO];

		_controlSize = MAX(0.0, [self doubleFrom:config key:kFxGripPointKey_ControlSize fallback:kFxGripPointDefaultControlSize]);
		_controlColor = [self colorFrom:config key:kFxGripPointKey_ControlColor];

		_pinDistance = [self doubleFrom:config key:kFxGripPointKey_PinDistance fallback:0.0];
		_pinAngle = [self doubleFrom:config key:kFxGripPointKey_PinAngle fallback:0.0];

		_displayName = [self boolFrom:config key:kFxGripPointKey_DisplayName fallback:NO];
		_nameOnlyWhenAbove = [self boolFrom:config key:kFxGripPointKey_NameOnlyWhenAbove fallback:YES];

		_mouseSpeed = [self doubleFrom:config key:kFxGripPointKey_MouseSpeed fallback:kFxGripPointDefaultMouseSpeed];
		if (_mouseSpeed <= 0.0) {
			_mouseSpeed = kFxGripPointDefaultMouseSpeed;
		}
		_mouseSpeedShiftOnly = [self boolFrom:config key:kFxGripPointKey_MouseSpeedShiftOnly fallback:NO];

		NSString *image = config[kFxGripPointKey_BackgroundImage];
		_backgroundImageName = [image isKindOfClass:NSString.class] && image.length ? [image copy] : nil;
		_backgroundImageSize = [self doubleFrom:config key:kFxGripPointKey_BackgroundImageSize fallback:kFxGripPointDefaultBackgroundSize];
		_backgroundImageX = [self doubleFrom:config key:kFxGripPointKey_BackgroundImageX fallback:kFxGripPointDefaultPosition];
		_backgroundImageY = [self doubleFrom:config key:kFxGripPointKey_BackgroundImageY fallback:kFxGripPointDefaultPosition];

		_constraint = [self constraintFrom:[self doubleFrom:config key:kFxGripPointKey_Constraint fallback:0.0]];
		_divider = [self dividerFrom:[self doubleFrom:config key:kFxGripPointKey_Divider fallback:0.0]];

		_distanceFromX = [self doubleFrom:config key:kFxGripPointKey_DistanceFromX fallback:kFxGripPointDefaultPosition];
		_distanceFromY = [self doubleFrom:config key:kFxGripPointKey_DistanceFromY fallback:kFxGripPointDefaultPosition];
		_maxDistance = [self doubleFrom:config key:kFxGripPointKey_MaxDistance fallback:kFxGripPointDefaultMaxDistance];
		_distanceShiftOneAxis = [self boolFrom:config key:kFxGripPointKey_DistanceShiftOneAxis fallback:NO];
	}
	return self;
}

- (BOOL)displayAsPin
{
	return _pinDistance != 0.0;
}

#pragma mark Parsing

- (double)doubleFrom:(NSDictionary *)config key:(NSString *)key fallback:(double)fallback
{
	id value = config[key];
	return [value isKindOfClass:NSNumber.class] ? ((NSNumber *)value).doubleValue : fallback;
}

- (BOOL)boolFrom:(NSDictionary *)config key:(NSString *)key fallback:(BOOL)fallback
{
	id value = config[key];
	return [value isKindOfClass:NSNumber.class] ? ((NSNumber *)value).boolValue : fallback;
}

/*! Reads an RGB or RGBA array (missing alpha defaults to opaque); nil for any other shape. */
- (nullable NSColor *)colorFrom:(NSDictionary *)config key:(NSString *)key
{
	id value = config[key];
	if (![value isKindOfClass:NSArray.class]) {
		return nil;
	}
	NSArray *components = value;
	if (components.count < 3) {
		return nil;
	}
	double red = [components[0] doubleValue];
	double green = [components[1] doubleValue];
	double blue = [components[2] doubleValue];
	double alpha = components.count >= 4 ? [components[3] doubleValue] : 1.0;
	return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
}

- (FxGripPointConstraint)constraintFrom:(double)raw
{
	NSInteger value = (NSInteger)raw;
	if (value == FxGripPointConstraintHorizontal || value == FxGripPointConstraintVertical
		|| value == FxGripPointConstraintDistance) {
		return (FxGripPointConstraint)value;
	}
	return FxGripPointConstraintAnyDirection;
}

- (FxGripPointDivider)dividerFrom:(double)raw
{
	NSInteger value = (NSInteger)raw;
	if (value == FxGripPointDividerThinWithControl || value == FxGripPointDividerThickWithoutControl) {
		return (FxGripPointDivider)value;
	}
	return FxGripPointDividerNone;
}

@end
