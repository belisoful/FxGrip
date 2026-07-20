//
//  FxGripGroupParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripGroupParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
//#import "GuruFxTileableEffect+Parameters.h"
#import "FxGrip_ARC.h"

@implementation FxGripGroupParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Group;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Group;
}

+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect
{
	__block BOOL success = [effect.apiManager.paramCreateAPIv5
							startParameterSubGroup: parameter.parameterName
									   parameterID: parameter.parameterID
									parameterFlags: parameter.parameterFlags];
	if (!success) {
		return NO;
	}
	
	NSError *error = nil;
	
	[effect addParametersWithGroupID:parameter.parameterID error:&error];
	
	success = [effect.apiManager.paramCreateAPIv5 endParameterSubGroup] && success;
	return success;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxTileableEffectBase>)effect;
{
	self = [super init];
	if(self) {
		_children = [NSMutableArray.alloc init];
		
		// children are added upon use of API
		/*
		id fChildren = dictionary[kFxParameterProperty_GroupParameters];
		if (fChildren && [fChildren isKindOfClass:NSDictionary.class]) {
			fChildren = ((NSDictionary*)fChildren).allValues;
		}
		if (fChildren && [fChildren isKindOfClass:NSArray.class]) {
			for(NSDictionary *newParameterData in fChildren) {
				if (![newParameterData isKindOfClass:NSDictionary.class])
					continue;
				id<FxGripParameterProtocol> parameter = [[self.effect parameterClassForType:newParameterData.parameterType] initWithDictionary:newParameterData];
				if (!parameter) {
					continue;
				}
				[_children addObject:parameter];
			}
			
		}*/
		
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_children);
	
	SUPER_DEALLOC();
}

- (BOOL)flagCollapsed {
	return flagCollapsed(self.parameterFlags);
}

- (void)setFlagCollapsed:(BOOL)collapsed {
	if (flagCollapsed(self.parameterFlags) && !collapsed) {
		self.parameterFlags &= ~kFxParameterFlag_COLLAPSED;
		
	} else if (!flagCollapsed(self.parameterFlags) && collapsed) {
		self.parameterFlags |= kFxParameterFlag_COLLAPSED;
	}
}








#pragma mark -
#pragma mark FxGripSubParameters


- (BOOL)addChildParameter:(id<FxParameter> _Nonnull)parameter
{
	BOOL isChild = [_children containsObject:parameter];
	
	if (isChild) {
		return NO;
	}
	[_children addObject:parameter];
	return YES;
}

- (BOOL)removeChildParameter:(id<FxParameter> _Nonnull)parameter
{
	BOOL isChild = [_children containsObject:parameter];
	
	if (!isChild) {
		return NO;
	}
	[_children removeObject:parameter];
	return YES;
}

//
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index
{
	return [_children objectAtIndex:index];
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *) enumerationState
								   objects: (id __unsafe_unretained []) stackBuffer
									 count: (NSUInteger) len
{
	return [_children countByEnumeratingWithState:enumerationState objects:stackBuffer count:len];
}

- (NSUInteger)count
{
	return _children.count;
}

- (nonnull NSArray<id<FxParameter>>*)children
{
	return _children;
}


- (NSUInteger)allCount
{
	NSUInteger count = self.count;
	for(id<FxParameter> child in self.children) {
		if ([child conformsToProtocol:@protocol(FxSubParameters)]) {
			count += ((id<FxSubParameters>)child).count;
		}
	}
	return count;
}

- (nonnull NSArray<id<FxParameter>>*)allChildren
{
	NSArray<id<FxParameter>>* children = self.children;
	NSMutableArray *all = [NSMutableArray.alloc initWithCapacity:children.count];
	for(id<FxParameter> child in children) {
		if ([child conformsToProtocol:@protocol(FxSubParameters)]) {
			[all addObjectsFromArray:((id<FxSubParameters>)child).allChildren];
		}
		[all addObject:child];
	}
	return [all copy];
}



@end
