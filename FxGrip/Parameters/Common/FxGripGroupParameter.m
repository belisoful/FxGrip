/*!
	@file       FxGripGroupParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGroupParameter
	@abstract   Implements the parameter model for a host parameter group.
	@discussion Introduced in FxGrip 0.1.0. The class registers a parameter subgroup through the parameter-creation API and holds its child parameters. Group registration opens the subgroup, posts a notification for the configuration's owner to add the children, and closes the subgroup.
*/

#import "FxGripGroupParameter.h"
#import "FxGripTileableEffect+Notifications.h"
#import "FxGripAPINotifications.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The parameter model for a host parameter group.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a parameter subgroup and holds its child parameters for enumeration and indexed access.
*/
@implementation FxGripGroupParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Group;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Group;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the parameter group and its children with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host opens the group, adds every child, and closes the group.
	@discussion	Introduced in FxGrip 0.1.0. The method posts FxGripTileableEffectAddGroupParametersName for the configuration's owner to register the children. The subgroup closes even when a child fails, so the parameter tree stays balanced. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	BOOL success = [effect.apiManager.paramCreateAPIv5
					startParameterSubGroup: parameter.parameterName
							   parameterID: parameter.parameterID
							parameterFlags: parameter.parameterFlags];
	if (!success) {
		return NO;
	}

	// The group's children belong to whichever observer owns the configuration (the effect base's
	// plist walk, or a plain host's own registration).
	NSMutableDictionary *userInfo = @{FxGripTileableEffectGroupIDKey: @(parameter.parameterID)}.mutableCopy;
	[effect.notifier postNotificationName:FxGripTileableEffectAddGroupParametersName
								   object:effect
								 userInfo:userInfo];
	NSError *error = userInfo.fxError;
	if (error != nil) {
		NSLog(@"Error: could not add the child parameters of group #%d: %@", parameter.parameterID, error);
		success = NO;
	}

	// The group is closed even when a child fails, so the parameter tree stays balanced.
	success = [effect.apiManager.paramCreateAPIv5 endParameterSubGroup] && success;
	return success;
}

/*!
	@method		initWithDictionary:effect:
	@abstract	Initializes the group and its empty child array.
	@param		dictionary	The parameter configuration dictionary.
	@param		effect		The host that owns the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The children are added later through the host registration API. */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary effect:(nonnull id<FxGripEffectHost>)effect;
{
	self = [super initWithDictionary:dictionary effect:effect];
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


/*!
	@method		addChildParameter:
	@abstract	Adds a parameter to the group's children.
	@param		parameter	The parameter to add.
	@return		YES when the parameter is added; NO when it is already a child. */
- (BOOL)addChildParameter:(id<FxGripParameter> _Nonnull)parameter
{
	BOOL isChild = [_children containsObject:parameter];

	if (isChild) {
		return NO;
	}
	[_children addObject:parameter];
	return YES;
}

/*!
	@method		removeChildParameter:
	@abstract	Removes a parameter from the group's children.
	@param		parameter	The parameter to remove.
	@return		YES when the parameter is removed; NO when it is not a child. */
- (BOOL)removeChildParameter:(id<FxGripParameter> _Nonnull)parameter
{
	BOOL isChild = [_children containsObject:parameter];

	if (!isChild) {
		return NO;
	}
	[_children removeObject:parameter];
	return YES;
}

//
- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index
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

- (nonnull NSArray<id<FxGripParameter>>*)children
{
	return _children;
}


/*! @abstract Counts the direct children plus the children of every nested group, recursively. */
- (NSUInteger)allCount
{
	NSUInteger count = self.count;
	for(id<FxGripParameter> child in self.children) {
		if ([child conformsToProtocol:@protocol(FxGripSubParameters)]) {
			count += ((id<FxGripSubParameters>)child).allCount;
		}
	}
	return count;
}

/*! @abstract Flattens the direct children and the children of every nested group into one array, recursively. */
- (nonnull NSArray<id<FxGripParameter>>*)allChildren
{
	NSArray<id<FxGripParameter>>* children = self.children;
	NSMutableArray *all = [NSMutableArray.alloc initWithCapacity:children.count];
	for(id<FxGripParameter> child in children) {
		if ([child conformsToProtocol:@protocol(FxGripSubParameters)]) {
			[all addObjectsFromArray:((id<FxGripSubParameters>)child).allChildren];
		}
		[all addObject:child];
	}
	return [all copy];
}



@end
