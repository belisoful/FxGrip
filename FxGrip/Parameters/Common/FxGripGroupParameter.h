/*!
	@file       FxGripGroupParameter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGroupParameter
	@abstract   The parameter model for a host parameter group that holds child parameters.
	@discussion Introduced in FxGrip 0.1.0. The class registers a parameter subgroup and holds its child parameters. It conforms to FxGripSubParameters for child enumeration and indexed access. The collapsed state maps to the COLLAPSED parameter flag. The group registration opens the host subgroup, posts a notification for the owner to add the children, and closes the subgroup.
*/

#ifndef FxGripGroupParameter_h
#define FxGripGroupParameter_h

#import "FxGripParameter.h"


/*!
	@class		FxGripGroupParameter
	@abstract	The parameter model for a host parameter group.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a parameter subgroup and holds its child parameters for enumeration and indexed access.
*/
@interface FxGripGroupParameter : FxGripParameter <FxGripSubParameters>
{
	@protected
	NSMutableArray *_children;
}

/*!
	@property	flagCollapsed
	@abstract	The COLLAPSED parameter flag as a boolean.
	@discussion	Introduced in FxGrip 0.1.0. A YES value tells the host to draw the group collapsed. */
@property (readwrite, nonatomic) BOOL flagCollapsed;

/*! @abstract The FxPlug type key string this class registers. */
+ (nullable NSString*)parameterTypeString;
/*! @abstract The FxParameterType this class registers. */
+ (FxParameterType)parameterType;
/*!
	@method		addParameter:toEffect:
	@abstract	Registers the parameter group and its children with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the group and every child.
	@discussion	Introduced in FxGrip 0.1.0. The method opens the host subgroup, posts a notification for the configuration's owner to register the children, and closes the subgroup even when a child fails. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect;


// ***  FxGripSubParameters Implementation  ***
/*! @abstract The number of direct child parameters. */
- (NSUInteger)count;
/*! @abstract The direct child parameters. */
- (nonnull NSArray<id<FxGripParameter>>*)children;
/*! @abstract The number of child parameters counted recursively through nested groups. */
- (NSUInteger)allCount;
/*! @abstract The child parameters flattened recursively through nested groups. */
- (nonnull NSArray<id<FxGripParameter>>*)allChildren;
/*! @abstract The direct child parameter at an index. */
- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
/*! @abstract Enumerates the direct child parameters for fast enumeration. */
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *_Nonnull) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

@end

#endif
