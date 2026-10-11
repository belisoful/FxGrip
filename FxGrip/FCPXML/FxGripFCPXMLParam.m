/*!
	@file       FxGripFCPXMLParam.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLParam
	@abstract   The `param` element, its keyframe animation, and its fades.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLParam.h.
*/

#import <FxGrip/FxGripFCPXMLParam.h>
#import <FxGrip/FxGripFCPXMLValue.h>

NSString *const FxGripFCPXMLKeyframeInterpolationLinear = @"linear";
NSString *const FxGripFCPXMLKeyframeInterpolationEase = @"ease";
NSString *const FxGripFCPXMLKeyframeInterpolationEaseIn = @"easeIn";
NSString *const FxGripFCPXMLKeyframeInterpolationEaseOut = @"easeOut";
NSString *const FxGripFCPXMLKeyframeCurveLinear = @"linear";
NSString *const FxGripFCPXMLKeyframeCurveSmooth = @"smooth";

#pragma mark - Keyframe

@implementation FxGripFCPXMLKeyframe

+ (NSString *)elementName { return @"keyframe"; }

+ (instancetype)keyframeAtTime:(CMTime)time value:(NSString *)value
{
	FxGripFCPXMLKeyframe *keyframe = [[self alloc] init];
	keyframe.time = time;
	keyframe.value = value;
	return keyframe;
}

- (CMTime)time { return [self timeForAttribute:@"time"]; }
- (void)setTime:(CMTime)time { [self setTime:time forAttribute:@"time"]; }
- (NSString *)value { return [self stringForAttribute:@"value"]; }
- (void)setValue:(NSString *)value { [self setString:value forAttribute:@"value"]; }
- (NSString *)auxValue { return [self stringForAttribute:@"auxValue"]; }
- (void)setAuxValue:(NSString *)auxValue { [self setString:auxValue forAttribute:@"auxValue"]; }
- (NSString *)interpolation { return [self stringForAttribute:@"interp"]; }
- (void)setInterpolation:(NSString *)interpolation { [self setString:interpolation forAttribute:@"interp"]; }
- (NSString *)curve { return [self stringForAttribute:@"curve"]; }
- (void)setCurve:(NSString *)curve { [self setString:curve forAttribute:@"curve"]; }
- (NSArray<NSNumber *> *)numericValue { return [self numbersForAttribute:@"value"]; }

@end

#pragma mark - Keyframe animation

@implementation FxGripFCPXMLKeyframeAnimation

+ (NSString *)elementName { return @"keyframeAnimation"; }

- (NSArray<FxGripFCPXMLKeyframe *> *)keyframes
{
	return [self childrenNamed:@"keyframe"];
}

- (void)addKeyframe:(FxGripFCPXMLKeyframe *)keyframe
{
	if (keyframe == nil) {
		return;
	}
	CMTime time = keyframe.time;
	NSUInteger insertIndex = self.xmlElement.childCount;
	for (FxGripFCPXMLKeyframe *existing in self.keyframes) {
		int32_t comparison = CMTimeCompare(existing.time, time);
		if (comparison == 0) {
			insertIndex = existing.xmlElement.index;
			[self removeChild:existing];
			break;
		}
		if (comparison > 0) {
			insertIndex = existing.xmlElement.index;
			break;
		}
	}
	[self insertChild:keyframe atIndex:insertIndex];
}

- (FxGripFCPXMLKeyframe *)addKeyframeAtTime:(CMTime)time value:(NSString *)value
{
	FxGripFCPXMLKeyframe *keyframe = [FxGripFCPXMLKeyframe keyframeAtTime:time value:value];
	[self addKeyframe:keyframe];
	return keyframe;
}

- (FxGripFCPXMLKeyframe *)keyframeAtTime:(CMTime)time
{
	for (FxGripFCPXMLKeyframe *keyframe in self.keyframes) {
		if (CMTimeCompare(keyframe.time, time) == 0) {
			return keyframe;
		}
	}
	return nil;
}

- (FxGripFCPXMLKeyframe *)keyframeAtOrBeforeTime:(CMTime)time
{
	FxGripFCPXMLKeyframe *found = nil;
	for (FxGripFCPXMLKeyframe *keyframe in self.keyframes) {
		if (CMTimeCompare(keyframe.time, time) <= 0) {
			found = keyframe;
		} else {
			break;
		}
	}
	return found;
}

- (FxGripFCPXMLKeyframe *)keyframeAtOrAfterTime:(CMTime)time
{
	for (FxGripFCPXMLKeyframe *keyframe in self.keyframes) {
		if (CMTimeCompare(keyframe.time, time) >= 0) {
			return keyframe;
		}
	}
	return nil;
}

- (void)removeAllKeyframes
{
	[self removeChildrenNamed:@"keyframe"];
}

@end

#pragma mark - Fade

@implementation FxGripFCPXMLFade

+ (NSString *)elementName { return @"fadeIn"; }
+ (NSArray<NSString *> *)elementNames { return @[@"fadeIn", @"fadeOut"]; }

+ (instancetype)fadeInWithDuration:(CMTime)duration
{
	FxGripFCPXMLFade *fade = [[self alloc] initWithElementName:@"fadeIn"];
	fade.duration = duration;
	return fade;
}

+ (instancetype)fadeOutWithDuration:(CMTime)duration
{
	FxGripFCPXMLFade *fade = [[self alloc] initWithElementName:@"fadeOut"];
	fade.duration = duration;
	return fade;
}

- (NSString *)type { return [self stringForAttribute:@"type"]; }
- (void)setType:(NSString *)type { [self setString:type forAttribute:@"type"]; }
- (CMTime)duration { return [self timeForAttribute:@"duration"]; }
- (void)setDuration:(CMTime)duration { [self setTime:duration forAttribute:@"duration"]; }
- (BOOL)isFadeIn { return [self.name isEqualToString:@"fadeIn"]; }

@end

#pragma mark - Param

@implementation FxGripFCPXMLParam

+ (NSString *)elementName { return @"param"; }

+ (instancetype)paramWithName:(NSString *)name key:(NSString *)key value:(NSString *)value
{
	FxGripFCPXMLParam *param = [[self alloc] init];
	param.paramName = name;
	param.key = key;
	param.value = value;
	return param;
}

- (NSString *)paramName { return [self stringForAttribute:@"name"]; }
- (void)setParamName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSString *)key { return [self stringForAttribute:@"key"]; }
- (void)setKey:(NSString *)key { [self setString:key forAttribute:@"key"]; }
- (NSString *)value { return [self stringForAttribute:@"value"]; }
- (void)setValue:(NSString *)value { [self setString:value forAttribute:@"value"]; }
- (NSString *)auxValue { return [self stringForAttribute:@"auxValue"]; }
- (void)setAuxValue:(NSString *)auxValue { [self setString:auxValue forAttribute:@"auxValue"]; }
- (BOOL)enabled { return [self boolForAttribute:@"enabled" defaultValue:YES]; }

- (void)setEnabled:(BOOL)enabled
{
	// The DTD default is enabled, so the attribute appears only when it carries information.
	if (enabled) {
		[self removeAttribute:@"enabled"];
	} else {
		[self setBool:NO forAttribute:@"enabled"];
	}
}

- (FxGripFCPXMLKeyframeAnimation *)keyframeAnimation
{
	return [self firstChildNamed:@"keyframeAnimation"];
}

- (FxGripFCPXMLKeyframeAnimation *)keyframeAnimationCreatingIfNeeded
{
	FxGripFCPXMLKeyframeAnimation *animation = self.keyframeAnimation;
	if (animation == nil) {
		animation = [[FxGripFCPXMLKeyframeAnimation alloc] init];
		// DTD order: fadeIn?, fadeOut?, keyframeAnimation?, param*.
		FxGripFCPXMLElement *firstParam = [self firstChildNamed:@"param"];
		if (firstParam != nil) {
			[self insertChild:animation atIndex:firstParam.xmlElement.index];
		} else {
			[self addChild:animation];
		}
	}
	return animation;
}

- (void)removeKeyframeAnimation
{
	[self removeChildrenNamed:@"keyframeAnimation"];
}

- (FxGripFCPXMLFade *)fadeIn { return [self firstChildNamed:@"fadeIn"]; }
- (FxGripFCPXMLFade *)fadeOut { return [self firstChildNamed:@"fadeOut"]; }

- (void)setFadeIn:(FxGripFCPXMLFade *)fade
{
	[self removeChildrenNamed:@"fadeIn"];
	if (fade != nil) {
		[self insertChild:fade atIndex:0];
	}
}

- (void)setFadeOut:(FxGripFCPXMLFade *)fade
{
	[self removeChildrenNamed:@"fadeOut"];
	if (fade != nil) {
		FxGripFCPXMLElement *fadeIn = self.fadeIn;
		[self insertChild:fade atIndex:(fadeIn ? fadeIn.xmlElement.index + 1 : 0)];
	}
}

- (NSArray<FxGripFCPXMLParam *> *)subparams
{
	return [self childrenNamed:@"param"];
}

- (FxGripFCPXMLParam *)subparamNamed:(NSString *)name
{
	for (FxGripFCPXMLParam *param in self.subparams) {
		if ([param.paramName isEqualToString:name]) {
			return param;
		}
	}
	return nil;
}

- (FxGripFCPXMLParam *)subparamWithKey:(NSString *)key
{
	for (FxGripFCPXMLParam *param in self.subparams) {
		if ([param.key isEqualToString:key]) {
			return param;
		}
	}
	return nil;
}

- (void)addSubparam:(FxGripFCPXMLParam *)param
{
	[self addChild:param];
}

- (BOOL)isAnimated
{
	return self.keyframeAnimation.keyframes.count > 0;
}

- (NSString *)valueAtTime:(CMTime)time
{
	FxGripFCPXMLKeyframeAnimation *animation = self.keyframeAnimation;
	if (animation.keyframes.count == 0 || !CMTIME_IS_NUMERIC(time)) {
		return self.value;
	}
	FxGripFCPXMLKeyframe *exact = [animation keyframeAtTime:time];
	if (exact != nil) {
		return exact.value;
	}
	FxGripFCPXMLKeyframe *before = [animation keyframeAtOrBeforeTime:time];
	FxGripFCPXMLKeyframe *after = [animation keyframeAtOrAfterTime:time];
	if (before == nil) {
		return after.value ?: self.value;
	}
	if (after == nil) {
		return before.value;
	}
	NSArray<NSNumber *> *from = before.numericValue;
	NSArray<NSNumber *> *to = after.numericValue;
	if (from.count == 0 || from.count != to.count) {
		return before.value;
	}
	double span = CMTimeGetSeconds(CMTimeSubtract(after.time, before.time));
	double fraction = span > 0 ? CMTimeGetSeconds(CMTimeSubtract(time, before.time)) / span : 0;
	NSMutableArray *mixed = [NSMutableArray arrayWithCapacity:from.count];
	for (NSUInteger index = 0; index < from.count; index++) {
		double a = from[index].doubleValue;
		double b = to[index].doubleValue;
		[mixed addObject:@(a + (b - a) * fraction)];
	}
	return [FxGripFCPXMLValue stringForNumbers:mixed];
}

@end
