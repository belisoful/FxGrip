/*!
	@file       FxGripObjectTrackerOSC.m
	@copyright  Copyright © 2026 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerOSC
	@abstract   Composes the tracker region from the shared rectangle part family.
	@discussion Introduced in FxGrip 0.1.0. The region is an FxGripOSCRectPart body with corner handles,
	            plus a rotation handle when an angle parameter is supplied.
*/

#import "FxGripObjectTrackerOSC.h"

/*!
	@abstract	The on-screen control that places and shapes an object tracker's region.
	@discussion	Introduced in FxGrip 0.1.0. The control builds the region parts and appends them; a
				subclass calls addTrackerRegionWithLowerLeftParameterID:... from its initializer.
*/
@implementation FxGripObjectTrackerOSC

/*!
	@method		trackerRegionPartsWithFirstPartID:lowerLeftParameterID:upperRightParameterID:angleParameterID:
	@abstract	Builds the region parts numbered from firstPartID.
	@discussion	Introduced in FxGrip 0.1.0. The rotation handle is included only when angleParameterID
				is nonzero. */
+ (NSArray<FxGripOSCPart *> *)trackerRegionPartsWithFirstPartID:(NSInteger)firstPartID
										  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
										 upperRightParameterID:(FxParameterId)upperRightParameterID
											  angleParameterID:(FxParameterId)angleParameterID
{
	FxGripOSCShapeOptions options = FxGripOSCShapeOptionBody | FxGripOSCShapeOptionCornerHandles;
	if (angleParameterID != 0) {
		options |= FxGripOSCShapeOptionRotationHandle;
	}
	return [FxGripOSCRectPart rectPartsWithOptions:options
									  firstPartID:firstPartID
							 lowerLeftParameterID:lowerLeftParameterID
							upperRightParameterID:upperRightParameterID
								 angleParameterID:angleParameterID];
}

/*!
	@method		addTrackerRegionWithLowerLeftParameterID:upperRightParameterID:angleParameterID:
	@abstract	Composes the region parts and appends them, numbering them after the existing parts.
	@discussion	Introduced in FxGrip 0.1.0. */
- (void)addTrackerRegionWithLowerLeftParameterID:(FxParameterId)lowerLeftParameterID
						  upperRightParameterID:(FxParameterId)upperRightParameterID
							   angleParameterID:(FxParameterId)angleParameterID
{
	[self addParts:[self.class trackerRegionPartsWithFirstPartID:(NSInteger)self.parts.count + 1
										   lowerLeftParameterID:lowerLeftParameterID
										  upperRightParameterID:upperRightParameterID
											   angleParameterID:angleParameterID]];
}

@end
