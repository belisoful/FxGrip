//
//  FxGripSwitchParameter.m
//  FxGrip
//

#import "FxGripSwitchParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGrip_ARC.h"

@implementation FxGripSwitchView

- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	BOOL flag = NO;
	if ([(FxGripDictionary*)value getBoolValue:&flag]) {
		self.state = flag ? NSControlStateValueOn : NSControlStateValueOff;
	}
}

/*! The action runs outside a host call, so the write goes through an out-of-band
	access context. */
- (void)fxSwitchToggled:(nullable id)sender
{
	FxTileableEffectBase *effect = (FxTileableEffectBase*)self.parameterEffect;
	if (effect == nil) {
		return;
	}
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:effect];
	CMTime time = access.currentTime;

	NSObject<NSSecureCoding, NSCopying> *value = nil;
	[effect.apiManager.paramGetAPIv6 getCustomParameterValue:&value
											   fromParameter:self.parameterID
													  atTime:time];
	FxGripDictionary *dictionary = [value isKindOfClass:FxGripDictionary.class]
		? (FxGripDictionary*)value
		: [FxGripDictionary dictionaryWithDictionary:@{}];
	dictionary.locked = NO;
	[dictionary setBoolValue:self.state == NSControlStateValueOn];
	[effect.apiManager.paramSetAPIv5 setCustomParameterValue:dictionary
												 toParameter:self.parameterID
													  atTime:time];
}

@end


@implementation FxGripSwitchParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Switch;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Switch;
}

+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	NSNumber *defaultValue = @NO;
	NSNumber *declared = parameter.parameterDefaultValue;
	if ([declared isKindOfClass:NSNumber.class]) {
		defaultValue = declared;
	}

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: [FxGripDictionary dictionaryWithDictionary:@{kCustomAPI_BoolKey: defaultValue}]
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE];
}

- (NSView *_Nullable)newParameterView
{
	FxGripSwitchView *switchView = [FxGripSwitchView.alloc initWithFrame:NSMakeRect(0, 0, 80, 24)];
	switchView.controlSize = NSControlSizeMini;
	switchView.parameterEffect = self.effect;
	switchView.parameterID = self.parameterID;
	switchView.target = switchView;
	switchView.action = @selector(fxSwitchToggled:);

	NSNumber *declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSNumber.class] && declared.boolValue) {
		switchView.state = NSControlStateValueOn;
	}
	return switchView;
}

@end
