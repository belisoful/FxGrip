//
//  FxGripCustomCreationAPI_v1.m
//  FxGrip
//

#import "FxGripCustomCreationAPI_v1.h"
#import "FxGripTypes.h"
#import "FxGripDictionary.h"
#import "FxGripSectionParameter.h"
#import "FxGripSection.h"
#import "FxGripDividerParameter.h"
#import "FxGripBannerParameter.h"
#import "FxGripBanner.h"
#import "FxGripCapsuleParameter.h"
#import "FxGripCapsule.h"
#import "FxGripStatusParameter.h"
#import "FxGripProgressParameter.h"
#import "FxGripSwitchParameter.h"
#import "FxGripRandomParameter.h"
#import "FxGripRandom.h"
#import "FxGripWebViewParameter.h"
#import "FxGripWebView.h"
#import "FxGripVideoViewParameter.h"
#import "FxGripVideoView.h"
#import "FxGripLiveImageParameter.h"
#import "FxGripLiveImage.h"
#import "FxGrip_ARC.h"

@implementation FxGripCustomCreationAPI_v1
{
	id<FxGripEffectHost> _effect;
}

- (nullable instancetype)initWithEffect:(id<FxGripEffectHost>)effect
{
	if (effect == nil) {
		return nil;
	}
	self = [super init];
	if (self != nil) {
		_effect = effect;
	}
	return self;
}

- (id<FxGripEffectHost>)effect
{
	return _effect;
}

/*! Assembles the shared configuration shape and registers through the parameter class. */
- (BOOL)addParameterOfClass:(Class)parameterClass
					   name:(NSString *)name
				parameterID:(UInt32)parameterID
					  flags:(FxParameterFlags)flags
			   defaultValue:(nullable id)defaultValue
{
	// The configuration accessors answer only a record carrying an ID, a type, and a name.
	NSMutableDictionary *parameter = [NSMutableDictionary dictionaryWithDictionary:@{
		kFxParameterProperty_Id:    @(parameterID),
		kFxParameterProperty_Type:  [parameterClass parameterTypeString] ?: kFxParameterType_Custom,
		kFxParameterProperty_Name:  name ?: @"",
		kFxParameterProperty_Flags: @(flags),
	}];
	if (defaultValue != nil) {
		parameter[kFxParameterProperty_Default] = defaultValue;
	}
	return [parameterClass addParameter:parameter toEffect:_effect];
}

- (BOOL)addSectionWithName:(NSString *)name
			   parameterID:(UInt32)parameterID
			parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripSectionParameter.class name:name parameterID:parameterID
							   flags:flags defaultValue:@{ kFxGripSectionKey_Title: name ?: @"" }];
}

- (BOOL)addDividerWithParameterID:(UInt32)parameterID
				   parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripDividerParameter.class name:@"" parameterID:parameterID
							   flags:flags defaultValue:nil];
}

- (BOOL)addBannerWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
					title:(nullable NSString *)title
				 subtitle:(nullable NSString *)subtitle
		   parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *value = [NSMutableDictionary dictionary];
	value[kFxGripBannerKey_Title] = title ?: name;
	if (subtitle != nil) {
		value[kFxGripBannerKey_Subtitle] = subtitle;
	}
	return [self addParameterOfClass:FxGripBannerParameter.class name:name parameterID:parameterID
							   flags:flags defaultValue:value];
}

- (BOOL)addCapsuleWithName:(NSString *)name
			   parameterID:(UInt32)parameterID
					 title:(nullable NSString *)title
			parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripCapsuleParameter.class name:name parameterID:parameterID
							   flags:flags
						defaultValue:@{ kFxGripCapsuleKey_Title: title ?: name ?: @"" }];
}

- (BOOL)addStatusWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
					state:(NSInteger)state
					label:(nullable NSString *)label
		   parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripStatusParameter.class name:name parameterID:parameterID
							   flags:flags
						defaultValue:@{ kCustomAPI_IntKey: @(state),
										kCustomAPI_StringKey: label ?: @"" }];
}

- (BOOL)addProgressWithName:(NSString *)name
				parameterID:(UInt32)parameterID
					  state:(NSInteger)state
					  label:(nullable NSString *)label
				   fraction:(double)fraction
			 parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripProgressParameter.class name:name parameterID:parameterID
							   flags:flags
						defaultValue:@{ kCustomAPI_IntKey: @(state),
										kCustomAPI_StringKey: label ?: @"",
										kCustomAPI_FloatKey: @(fraction) }];
}

- (BOOL)addSwitchWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
			 defaultValue:(BOOL)defaultValue
		   parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripSwitchParameter.class name:name parameterID:parameterID
							   flags:flags defaultValue:@{ kCustomAPI_BoolKey: @(defaultValue) }];
}

- (BOOL)addRandomWithName:(NSString *)name
			  parameterID:(UInt32)parameterID
			 defaultValue:(NSInteger)defaultValue
				  minimum:(NSInteger)minimum
				  maximum:(NSInteger)maximum
					 step:(NSInteger)step
		   parameterFlags:(FxParameterFlags)flags
{
	return [self addParameterOfClass:FxGripRandomParameter.class name:name parameterID:parameterID
							   flags:flags
						defaultValue:@{ kFxGripRandomKey_Value: @(defaultValue),
										kFxGripRandomKey_Min: @(minimum),
										kFxGripRandomKey_Max: @(maximum),
										kFxGripRandomKey_Step: @(step) }];
}

- (BOOL)addWebViewWithName:(NSString *)name
			   parameterID:(UInt32)parameterID
					   URL:(nullable NSString *)urlString
				 whitelist:(nullable NSArray<NSString *> *)whitelist
					height:(double)height
			parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *value = [NSMutableDictionary dictionary];
	if (urlString != nil) {
		value[kFxGripWebViewKey_URL] = urlString;
	}
	if (whitelist != nil) {
		value[kFxGripWebViewKey_Whitelist] = whitelist;
	}
	if (height > 0.0) {
		value[kFxGripWebViewKey_Height] = @(height);
	}
	return [self addParameterOfClass:FxGripWebViewParameter.class name:name parameterID:parameterID
							   flags:flags defaultValue:value];
}

- (BOOL)addVideoViewWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
						 URL:(nullable NSString *)urlString
				   whitelist:(nullable NSArray<NSString *> *)whitelist
					  height:(double)height
					autoplay:(BOOL)autoplay
						loop:(BOOL)loop
			  parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *value = [NSMutableDictionary dictionary];
	if (urlString != nil) {
		value[kFxGripVideoKey_URL] = urlString;
	}
	if (whitelist != nil) {
		value[kFxGripVideoKey_Whitelist] = whitelist;
	}
	if (height > 0.0) {
		value[kFxGripVideoKey_Height] = @(height);
	}
	value[kFxGripVideoKey_Autoplay] = @(autoplay);
	value[kFxGripVideoKey_Loop] = @(loop);
	return [self addParameterOfClass:FxGripVideoViewParameter.class name:name parameterID:parameterID
							   flags:flags defaultValue:value];
}

- (BOOL)addLiveImageWithName:(NSString *)name
				 parameterID:(UInt32)parameterID
					  labels:(nullable NSArray<NSString *> *)labels
					  height:(double)height
			  parameterFlags:(FxParameterFlags)flags
{
	NSMutableDictionary *value = [NSMutableDictionary dictionary];
	if (labels != nil) {
		value[kFxGripLiveImageKey_Labels] = labels;
	}
	if (height > 0.0) {
		value[kFxGripLiveImageKey_Height] = @(height);
	}
	return [self addParameterOfClass:FxGripLiveImageParameter.class name:name parameterID:parameterID
							   flags:flags defaultValue:value];
}

@end
