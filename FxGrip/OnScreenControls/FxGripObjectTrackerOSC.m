//
//  FxGripObjectTrackerOSC.m
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#import "FxGripObjectTrackerOSC.h"

@implementation FxGripObjectTrackerOSC

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
