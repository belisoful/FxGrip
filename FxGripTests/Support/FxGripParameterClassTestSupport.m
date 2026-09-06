/*!
	@file       FxGripParameterClassTestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterClassTestSupport
	@abstract   Shared stubs for the parameter-class creation, retrieval, setting, timing, and dynamic API tests.
	@discussion Introduced in FxGrip 0.1.0. The creation, retrieval, setting, and timing stubs record their calls and vend configured values, the stub effect mirrors the effect base's policy and group notification observers, and the stub API manager binds the versioned APIs together. Free functions build a parameter config dictionary and CMTimes for the tests.
*/

#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripTileableEffect+Notifications.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/NSDictionary+FxGripTileableEffect.h>

NSNotificationCenter *FxGripParamClassTestMakePriorityCenter(void)
{
	Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
	return [[cls alloc] init];
}

#pragma mark - Creation API

/*!
	@abstract A stub host creation API that records each add-parameter call and can refuse chosen methods.
	@discussion Introduced in FxGrip 0.1.0. Every creation method appends its arguments to the calls array under a short method key, and returns the configured success flag unless the method is in the refused set.
*/
@implementation FxGripParamClassTestCreationAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_calls = NSMutableArray.new;
		_succeeds = YES;
		_refusedMethods = NSMutableSet.new;
	}
	return self;
}

/*! @abstract Returns the most recently recorded creation call. */
- (NSDictionary *)lastCall
{
	return self.calls.lastObject;
}

/*! @abstract Records a creation call and returns success unless the method is refused. */
- (BOOL)record:(NSString *)method arguments:(NSDictionary *)arguments
{
	NSMutableDictionary *call = arguments.mutableCopy;
	call[@"method"] = method;
	[self.calls addObject:call.copy];
	return self.succeeds && ![self.refusedMethods containsObject:method];
}

- (BOOL)addAngleSliderWithName:(NSString *)name
				   parameterID:(UInt32)parameterID
				defaultDegrees:(double)defaultDegrees
		   parameterMinDegrees:(double)minDegrees
		   parameterMaxDegrees:(double)maxDegrees
				parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"angle" arguments:@{@"name": name ?: NSNull.null,
											 @"id": @(parameterID),
											 @"default": @(defaultDegrees),
											 @"min": @(minDegrees),
											 @"max": @(maxDegrees),
											 @"flags": @(flags)}];
}

- (BOOL)addColorParameterWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
					 defaultAlpha:(double)alpha
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"rgba" arguments:@{@"name": name ?: NSNull.null,
											@"id": @(parameterID),
											@"red": @(red),
											@"green": @(green),
											@"blue": @(blue),
											@"alpha": @(alpha),
											@"flags": @(flags)}];
}

- (BOOL)addColorParameterWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
					   defaultRed:(double)red
					 defaultGreen:(double)green
					  defaultBlue:(double)blue
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"rgb" arguments:@{@"name": name ?: NSNull.null,
										   @"id": @(parameterID),
										   @"red": @(red),
										   @"green": @(green),
										   @"blue": @(blue),
										   @"flags": @(flags)}];
}

- (BOOL)addCustomParameterWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(NSObject<NSSecureCoding, NSCopying> *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"custom" arguments:@{@"name": name ?: NSNull.null,
											  @"id": @(parameterID),
											  @"default": defaultValue ?: NSNull.null,
											  @"flags": @(flags)}];
}

- (BOOL)addFloatSliderWithName:(NSString *)name
				   parameterID:(UInt32)parameterID
				  defaultValue:(double)defaultValue
				  parameterMin:(double)min
				  parameterMax:(double)max
					 sliderMin:(double)sliderMin
					 sliderMax:(double)sliderMax
						 delta:(double)sliderDelta
				parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"float" arguments:@{@"name": name ?: NSNull.null,
											 @"id": @(parameterID),
											 @"default": @(defaultValue),
											 @"min": @(min),
											 @"max": @(max),
											 @"slidermin": @(sliderMin),
											 @"slidermax": @(sliderMax),
											 @"delta": @(sliderDelta),
											 @"flags": @(flags)}];
}

- (BOOL)addFontMenuWithName:(NSString *)name
				parameterID:(UInt32)parameterID
				   fontName:(NSString *)fontName
			 parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"font" arguments:@{@"name": name ?: NSNull.null,
											@"id": @(parameterID),
											@"default": fontName ?: NSNull.null,
											@"flags": @(flags)}];
}

- (BOOL)addGradientWithName:(NSString *)name
				parameterID:(UInt32)parameterID
			 parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"gradient" arguments:@{@"name": name ?: NSNull.null,
												@"id": @(parameterID),
												@"flags": @(flags)}];
}

- (BOOL)addHelpButtonWithName:(NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(SEL)selector
			   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"help" arguments:@{@"name": name ?: NSNull.null,
											@"id": @(parameterID),
											@"selector": selector ? NSStringFromSelector(selector) : NSNull.null,
											@"flags": @(flags)}];
}

- (BOOL)addHistogramWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
			  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"histogram" arguments:@{@"name": name ?: NSNull.null,
												 @"id": @(parameterID),
												 @"flags": @(flags)}];
}

- (BOOL)addImageReferenceWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"imageref" arguments:@{@"name": name ?: NSNull.null,
												@"id": @(parameterID),
												@"flags": @(flags)}];
}

- (BOOL)addIntSliderWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(int)defaultValue
				parameterMin:(int)min
				parameterMax:(int)max
				   sliderMin:(int)sliderMin
				   sliderMax:(int)sliderMax
					   delta:(int)sliderDelta
			  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"int" arguments:@{@"name": name ?: NSNull.null,
										   @"id": @(parameterID),
										   @"default": @(defaultValue),
										   @"min": @(min),
										   @"max": @(max),
										   @"slidermin": @(sliderMin),
										   @"slidermax": @(sliderMax),
										   @"delta": @(sliderDelta),
										   @"flags": @(flags)}];
}

- (BOOL)addPathPickerWithName:(NSString *)name
				  parameterID:(UInt32)parameterID
			   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"path" arguments:@{@"name": name ?: NSNull.null,
											@"id": @(parameterID),
											@"flags": @(flags)}];
}

- (BOOL)addPercentSliderWithName:(NSString *)name
					 parameterID:(UInt32)parameterID
					defaultValue:(double)defaultValue
					parameterMin:(double)min
					parameterMax:(double)max
					   sliderMin:(double)sliderMin
					   sliderMax:(double)sliderMax
						   delta:(double)sliderDelta
				  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"percent" arguments:@{@"name": name ?: NSNull.null,
											   @"id": @(parameterID),
											   @"default": @(defaultValue),
											   @"min": @(min),
											   @"max": @(max),
											   @"slidermin": @(sliderMin),
											   @"slidermax": @(sliderMax),
											   @"delta": @(sliderDelta),
											   @"flags": @(flags)}];
}

- (BOOL)addPointParameterWithName:(NSString *)name
					  parameterID:(UInt32)parameterID
						 defaultX:(double)defaultX
						 defaultY:(double)defaultY
				   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"point" arguments:@{@"name": name ?: NSNull.null,
											 @"id": @(parameterID),
											 @"x": @(defaultX),
											 @"y": @(defaultY),
											 @"flags": @(flags)}];
}

- (BOOL)addPopupMenuWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
				defaultValue:(UInt32)defaultValue
				 menuEntries:(NSArray *)entries
			  parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"menu" arguments:@{@"name": name ?: NSNull.null,
											@"id": @(parameterID),
											@"default": @(defaultValue),
											@"items": entries ?: NSNull.null,
											@"flags": @(flags)}];
}

- (BOOL)addPushButtonWithName:(NSString *)name
				  parameterID:(UInt32)parameterID
					 selector:(SEL)selector
			   parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"button" arguments:@{@"name": name ?: NSNull.null,
											  @"id": @(parameterID),
											  @"selector": selector ? NSStringFromSelector(selector) : NSNull.null,
											  @"flags": @(flags)}];
}

- (BOOL)addStringParameterWithName:(NSString *)name
					   parameterID:(UInt32)parameterID
					  defaultValue:(NSString *)defaultValue
					parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"string" arguments:@{@"name": name ?: NSNull.null,
											  @"id": @(parameterID),
											  @"default": defaultValue ?: NSNull.null,
											  @"flags": @(flags)}];
}

- (BOOL)addToggleButtonWithName:(NSString *)name
					parameterID:(UInt32)parameterID
				   defaultValue:(BOOL)defaultValue
				 parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"toggle" arguments:@{@"name": name ?: NSNull.null,
											  @"id": @(parameterID),
											  @"default": @(defaultValue),
											  @"flags": @(flags)}];
}

- (BOOL)startParameterSubGroup:(NSString *)name
				   parameterID:(UInt32)parameterID
				parameterFlags:(FxParameterFlags)flags
{
	return [self record:@"startgroup" arguments:@{@"name": name ?: NSNull.null,
												  @"id": @(parameterID),
												  @"flags": @(flags)}];
}

- (BOOL)endParameterSubGroup
{
	return [self record:@"endgroup" arguments:@{}];
}

@end

#pragma mark - Retrieval / setting / dynamic APIs

/*!
	@abstract A stub host retrieval API that records each read and vends configured values.
	@discussion Introduced in FxGrip 0.1.0. Each accessor records the read and returns the configured value, and it can refuse specific histogram channels. Gradient reads fill the sample buffer with a configured byte.
*/
@implementation FxGripParamClassTestRetrievalAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_succeeds = YES;
		_getFlagsParameterIDs = NSMutableArray.new;
		_reads = NSMutableArray.new;
		_alpha = 1.0;
		_refusedHistogramChannels = NSMutableSet.new;
		_gradientFill = 0xAB;
	}
	return self;
}

/*! @abstract Returns the most recently recorded read. */
- (NSDictionary *)lastRead
{
	return self.reads.lastObject;
}

/*! @abstract Records a timed read field by field and returns the configured success flag. */
// CoreMedia is not linked into the test bundle, so the time is recorded field by field.
- (BOOL)record:(NSString *)accessor parameter:(UInt32)parameterID time:(CMTime)time
{
	[self.reads addObject:@{@"accessor": accessor,
							@"id": @(parameterID),
							@"timevalue": @(time.value),
							@"timescale": @(time.timescale)}];
	return self.succeeds;
}

/*! @abstract Records an untimed read and returns the configured success flag. */
- (BOOL)record:(NSString *)accessor parameter:(UInt32)parameterID
{
	[self.reads addObject:@{@"accessor": accessor, @"id": @(parameterID)}];
	return self.succeeds;
}

- (BOOL)getParameterFlags:(FxParameterFlags *)flags fromParameter:(UInt32)parameterID
{
	[self.getFlagsParameterIDs addObject:@(parameterID)];
	if (!self.succeeds) {
		return NO;
	}
	if (flags) {
		*flags = self.flags;
	}
	return YES;
}

- (BOOL)getFloatValue:(double *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL ok = [self record:@"float" parameter:parameterID time:time];
	if (ok && value) {
		*value = self.floatValue;
	}
	return ok;
}

- (BOOL)getIntValue:(int *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL ok = [self record:@"int" parameter:parameterID time:time];
	if (ok && value) {
		*value = self.intValue;
	}
	return ok;
}

- (BOOL)getBoolValue:(BOOL *)value fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL ok = [self record:@"bool" parameter:parameterID time:time];
	if (ok && value) {
		*value = self.boolValue;
	}
	return ok;
}

- (BOOL)getStringParameterValue:(NSString * _Nonnull *)string fromParameter:(UInt32)parameterID
{
	BOOL ok = [self record:@"string" parameter:parameterID];
	if (ok && string) {
		*string = self.stringValue;
	}
	return ok;
}

- (BOOL)getFontName:(NSString * _Nullable *)fontName fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL ok = [self record:@"font" parameter:parameterID time:time];
	if (ok && fontName) {
		*fontName = self.fontName;
	}
	return ok;
}

- (BOOL)getCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> * _Nullable *)value
				  fromParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	BOOL ok = [self record:@"custom" parameter:parameterID time:time];
	if (ok && value) {
		*value = self.customValue;
	}
	return ok;
}

- (BOOL)getPathID:(void * _Nullable *)pathID fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return [self record:@"path" parameter:parameterID time:time];
}

- (BOOL)getRedValue:(double *)red
		 greenValue:(double *)green
		  blueValue:(double *)blue
	  fromParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	BOOL ok = [self record:@"rgb" parameter:parameterID time:time];
	if (ok) {
		if (red) {
			*red = self.red;
		}
		if (green) {
			*green = self.green;
		}
		if (blue) {
			*blue = self.blue;
		}
	}
	return ok;
}

- (BOOL)getRedValue:(double *)red
		 greenValue:(double *)green
		  blueValue:(double *)blue
		 alphaValue:(double *)alpha
	  fromParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	BOOL ok = [self record:@"rgba" parameter:parameterID time:time];
	if (ok) {
		if (red) {
			*red = self.red;
		}
		if (green) {
			*green = self.green;
		}
		if (blue) {
			*blue = self.blue;
		}
		if (alpha) {
			*alpha = self.alpha;
		}
	}
	return ok;
}

- (BOOL)getXValue:(double *)xValue YValue:(double *)yValue fromParameter:(UInt32)parameterID atTime:(CMTime)time
{
	BOOL ok = [self record:@"point" parameter:parameterID time:time];
	if (ok) {
		if (xValue) {
			*xValue = self.x;
		}
		if (yValue) {
			*yValue = self.y;
		}
	}
	return ok;
}

- (BOOL)getHistogramBlackIn:(double *)blackIn
				   BlackOut:(double *)blackOut
					WhiteIn:(double *)whiteIn
				   WhiteOut:(double *)whiteOut
					  Gamma:(double *)gammaValue
				 forChannel:(int)channel
			  fromParameter:(UInt32)parameterID
					 atTime:(CMTime)time
{
	[self.reads addObject:@{@"accessor": @"histogram",
							@"id": @(parameterID),
							@"channel": @(channel),
							@"timevalue": @(time.value)}];
	if (!self.succeeds || [self.refusedHistogramChannels containsObject:@(channel)]) {
		return NO;
	}
	if (blackIn) {
		*blackIn = self.blackIn;
	}
	if (blackOut) {
		*blackOut = self.blackOut;
	}
	if (whiteIn) {
		*whiteIn = self.whiteIn;
	}
	if (whiteOut) {
		*whiteOut = self.whiteOut;
	}
	if (gammaValue) {
		*gammaValue = self.gamma;
	}
	return YES;
}

- (BOOL)getGradientSamples:(void *)samples
				numSamples:(NSUInteger)numSamples
					 depth:(FxDepth)sampleDepth
			 fromParameter:(UInt32)parameterID
					atTime:(CMTime)time
{
	[self.reads addObject:@{@"accessor": @"gradient",
							@"id": @(parameterID),
							@"samples": @(numSamples),
							@"depth": @(sampleDepth),
							@"timevalue": @(time.value)}];
	if (!self.succeeds) {
		return NO;
	}
	if (samples) {
		size_t bytesPerComponent = (sampleDepth == kFxDepth_FLOAT32) ? 4 : ((sampleDepth == kFxDepth_FLOAT16) ? 2 : 1);
		memset(samples, self.gradientFill, 4 * numSamples * bytesPerComponent);
	}
	return YES;
}

@end

/*!
	@abstract A stub host timing API that records each query and vends configured or derived times.
	@discussion Introduced in FxGrip 0.1.0. Start and duration return the configured times; the timeline and image conversions double and halve the query time so a test verifies the direction of the mapping.
*/
@implementation FxGripParamClassTestTimingAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_queries = NSMutableArray.new;
		_startTime = FxGripParamClassTestTime(0, 1);
		_durationTime = FxGripParamClassTestTime(0, 1);
	}
	return self;
}

- (void)startTime:(CMTime *)startTime ofImageParameter:(UInt32)parameterID
{
	[self.queries addObject:@{@"accessor": @"start", @"id": @(parameterID)}];
	if (startTime) {
		*startTime = self.startTime;
	}
}

- (void)durationTime:(CMTime *)duration ofImageParameter:(UInt32)parameterID
{
	[self.queries addObject:@{@"accessor": @"duration", @"id": @(parameterID)}];
	if (duration) {
		*duration = self.durationTime;
	}
}

- (void)timelineTime:(CMTime *)timelineTime fromImageTime:(CMTime)time forParameterID:(UInt32)parameterID
{
	[self.queries addObject:@{@"accessor": @"timeline",
							  @"id": @(parameterID),
							  @"timevalue": @(time.value)}];
	if (timelineTime) {
		*timelineTime = FxGripParamClassTestTime(time.value * 2, time.timescale);
	}
}

- (void)imageTime:(CMTime *)imageTime forParameterID:(UInt32)parameterID fromTimelineTime:(CMTime)time
{
	[self.queries addObject:@{@"accessor": @"image",
							  @"id": @(parameterID),
							  @"timevalue": @(time.value)}];
	if (imageTime) {
		*imageTime = FxGripParamClassTestTime(time.value / 2, time.timescale);
	}
}

@end

/*!
	@abstract A stub host setting API that records each write and flag change.
	@discussion Introduced in FxGrip 0.1.0. Each setter appends its arguments to the writes array under a short accessor key and returns the configured success flag; flag changes are recorded separately.
*/
@implementation FxGripParamClassTestSettingAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_succeeds = YES;
		_setFlagsCalls = NSMutableArray.new;
		_writes = NSMutableArray.new;
	}
	return self;
}

/*! @abstract Returns the most recently recorded write. */
- (NSDictionary *)lastWrite
{
	return self.writes.lastObject;
}

/*! @abstract Records a write under its accessor key and returns the configured success flag. */
- (BOOL)record:(NSString *)accessor arguments:(NSDictionary *)arguments
{
	NSMutableDictionary *write = arguments.mutableCopy;
	write[@"accessor"] = accessor;
	[self.writes addObject:write.copy];
	return self.succeeds;
}

- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID
{
	[self.setFlagsCalls addObject:@{@"flags": @(flags), @"id": @(parameterID)}];
	return self.succeeds;
}

- (BOOL)setFloatValue:(double)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return [self record:@"float" arguments:@{@"id": @(parameterID),
											 @"value": @(value),
											 @"timevalue": @(time.value)}];
}

- (BOOL)setIntValue:(int)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return [self record:@"int" arguments:@{@"id": @(parameterID),
										   @"value": @(value),
										   @"timevalue": @(time.value)}];
}

- (BOOL)setBoolValue:(BOOL)value toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return [self record:@"bool" arguments:@{@"id": @(parameterID),
											@"value": @(value),
											@"timevalue": @(time.value)}];
}

- (BOOL)setStringParameterValue:(NSString *)string toParameter:(UInt32)parameterID
{
	return [self record:@"string" arguments:@{@"id": @(parameterID),
											  @"value": string ?: NSNull.null}];
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		toParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	return [self record:@"rgb" arguments:@{@"id": @(parameterID),
										   @"red": @(red),
										   @"green": @(green),
										   @"blue": @(blue)}];
}

- (BOOL)setRedValue:(double)red
		 greenValue:(double)green
		  blueValue:(double)blue
		 alphaValue:(double)alpha
		toParameter:(UInt32)parameterID
			 atTime:(CMTime)time
{
	return [self record:@"rgba" arguments:@{@"id": @(parameterID),
											@"red": @(red),
											@"green": @(green),
											@"blue": @(blue),
											@"alpha": @(alpha)}];
}

- (BOOL)setXValue:(double)xValue YValue:(double)yValue toParameter:(UInt32)parameterID atTime:(CMTime)time
{
	return [self record:@"point" arguments:@{@"id": @(parameterID),
											 @"x": @(xValue),
											 @"y": @(yValue)}];
}

- (BOOL)setCustomParameterValue:(NSObject<NSSecureCoding, NSCopying> *)value
					toParameter:(UInt32)parameterID
						 atTime:(CMTime)time
{
	return [self record:@"custom" arguments:@{@"id": @(parameterID),
											  @"value": value ?: NSNull.null,
											  @"timevalue": @(time.value)}];
}

@end

/*!
	@abstract A stub host dynamic API that vends and records a parameter name.
	@discussion Introduced in FxGrip 0.1.0. It returns the configured name and error, and records each set-name call.
*/
@implementation FxGripParamClassTestDynamicAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_setNameCalls = NSMutableArray.new;
	}
	return self;
}

- (NSError *)parameter:(FxParameterId)parameterID name:(NSString **)name
{
	if (name) {
		*name = self.name;
	}
	return self.nameError;
}

- (NSError *)setParameter:(FxParameterId)parameterID name:(NSString *)name
{
	[self.setNameCalls addObject:@{@"id": @(parameterID), @"name": name ?: NSNull.null}];
	self.name = name;
	return self.nameError;
}

@end

#pragma mark - API manager

/*!
	@abstract A stub API manager that binds the versioned creation, retrieval, setting, timing, and dynamic stubs.
	@discussion Introduced in FxGrip 0.1.0. The v5 and v6 set APIs share one setting stub so a test observes both versions through the same recorder.
*/
@implementation FxGripParamClassTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_sessionID = 1;
		_paramCreateAPIv5 = [FxGripParamClassTestCreationAPI.alloc init];
		_paramGetAPIv6 = [FxGripParamClassTestRetrievalAPI.alloc init];
		_paramSetAPIv5 = [FxGripParamClassTestSettingAPI.alloc init];
		_paramSetAPIv6 = _paramSetAPIv5;
		_dynamicParamAPIv3 = [FxGripParamClassTestDynamicAPI.alloc init];
		_timingAPIv4 = [FxGripParamClassTestTimingAPI.alloc init];
	}
	return self;
}

@end

#pragma mark - Effect

/*!
	@abstract A stub effect that mirrors the effect base's policy and group notification seams for the parameter-class tests.
	@discussion Introduced in FxGrip 0.1.0. It carries the stub API manager and a priority notifier, attaches policy and group observers driven by its own properties, records group recursion, and vends the recorded creation calls. Parameter subscripting reads from an in-memory dictionary.
*/
@implementation FxGripParamClassTestEffect

- (id)effectBase
{
	// A stub host has no effect base; rich reads degrade through nil.
	return nil;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_apiManager = [FxGripParamClassTestAPIManager.alloc init];
		_notifier = FxGripParamClassTestMakePriorityCenter();
		_defaultFontName = @"Helvetica";
		_addedGroupIDs = NSMutableArray.new;
		_creationOrder = NSMutableArray.new;
		_groupRecursionSucceeds = YES;
		_parameters = NSMutableDictionary.new;
		[self attachHostObservers];
	}
	return self;
}

/*! Mirrors the effect base's policy and group observers, driven by this stub's own properties,
	so the notification-seam flows are what the tests exercise. */
- (void)attachHostObservers
{
	__weak typeof(self) weakSelf = self;
	[self.notifier addObserverForName:FxGripTileableEffectParameterPolicyName object:self queue:nil
						   usingBlock:^(NSNotification *note) {
		NSMutableDictionary *config = note.userInfo[FxGripNotifyAPI_ParameterKey];
		if (![config isKindOfClass:NSMutableDictionary.class]) {
			return;
		}
		FxParameterType type = config.parameterType;
		if (type == FxParameterType_FontMenu) {
			NSString *font = config[kFxParameterProperty_Default];
			if (![font isKindOfClass:NSString.class] || font.length == 0
				|| [font isEqualToString:kFxParameterType_FontNameDefault]) {
				config[kFxParameterProperty_Default] = weakSelf.defaultFontName;
			}
			return;
		}
		if (type == FxParameterType_RGBA || type == FxParameterType_RGB) {
			NSMutableDictionary *colors = config[kFxParameterProperty_Default];
			if (![colors isKindOfClass:NSMutableDictionary.class]) {
				return;
			}
			NSNumber *space = colors[kFxParameterProperty_ColorSpace];
			if (space == nil) {
				return;
			}
			int convertGamma = 0;
			if (space.intValue == 1 && weakSelf.isLinearColorParameters) {
				convertGamma = -1;
			} else if (space.intValue == 0 && weakSelf.isGammaColorParameters) {
				convertGamma = 1;
			}
			if (convertGamma == 0) {
				return;
			}
			const double gamma = 2.2;
			double exponent = convertGamma > 0 ? gamma : 1.0 / gamma;
			for (NSString *key in @[kFxParameterProperty_Red, kFxParameterProperty_Green, kFxParameterProperty_Blue]) {
				NSNumber *component = colors[key];
				if ([component isKindOfClass:NSNumber.class]) {
					colors[key] = @(pow(component.doubleValue, exponent));
				}
			}
		}
	}];
	[self.notifier addObserverForName:FxGripTileableEffectAddGroupParametersName object:self queue:nil
						   usingBlock:^(NSNotification *note) {
		NSNumber *groupID = note.userInfo[FxGripTileableEffectGroupIDKey];
		NSError *error = nil;
		if (![weakSelf addParametersWithGroupID:groupID.unsignedIntValue error:&error] && error != nil) {
			((NSMutableDictionary *)note.userInfo).fxError = error;
		}
	}];
}

/*! @abstract Records a group-recursion request and returns the configured success flag and error. */
- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError *_Nullable *_Nullable)error
{
	[self.addedGroupIDs addObject:@(groupID)];
	[self.creationOrder addObject:[NSString stringWithFormat:@"recurse:%u", groupID]];
	if (!self.groupRecursionSucceeds && error) {
		*error = self.groupRecursionError;
	}
	return self.groupRecursionSucceeds;
}

- (id)objectForKeyedSubscript:(id)key
{
	if (!key) {
		return nil;
	}
	return self.parameters[key];
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
	return self.parameters[@(index)];
}

/*! @abstract Returns the first recorded creation call from the creation stub. */
- (NSDictionary *)creationCall
{
	return self.apiManager.paramCreateAPIv5.calls.firstObject;
}

/*! @abstract Returns every recorded creation call from the creation stub. */
- (NSArray<NSDictionary *> *)creationCalls
{
	return self.apiManager.paramCreateAPIv5.calls;
}

@end

#pragma mark - Configuration helper

/*! @abstract Builds a parameter config dictionary with the id, type, and name, merging any extra keys. */
NSMutableDictionary *FxGripParamClassTestConfig(FxParameterId parameterID,
										   NSString *type,
										   NSString *name,
										   NSDictionary *extra)
{
	NSMutableDictionary *config = NSMutableDictionary.new;
	config[kFxParameterProperty_Id] = @(parameterID);
	config[kFxParameterProperty_Type] = type;
	config[kFxParameterProperty_Name] = name;
	[config addEntriesFromDictionary:extra ?: @{}];
	return config;
}

/*! @abstract Builds a valid CMTime from a value and timescale. */
CMTime FxGripParamClassTestTime(int64_t value, int32_t timescale)
{
	CMTime time = { .value = value, .timescale = timescale, .flags = kCMTimeFlags_Valid, .epoch = 0 };
	return time;
}
