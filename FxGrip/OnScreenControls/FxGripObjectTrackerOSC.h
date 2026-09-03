//
//  FxGripObjectTrackerOSC.h
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#ifndef FxGripObjectTrackerOSC_h
#define FxGripObjectTrackerOSC_h

#import <Foundation/Foundation.h>
#import "FxGripOnScreenControl.h"
#import "FxGripOSCPart.h"

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripObjectTrackerOSC
	@abstract   The on-screen control that places an object tracker's region.
	@discussion Introduced in FxGrip 1.0. Draws the trackable region as a rectangle whose two
				diagonal corners are point parameters: a lower-left and an upper-right point.
				A drag on the body moves the region; a drag on a corner resizes it. Those two
				points are the region the analysis pass reads to seed the tracker, and they
				are the FxFactory-style top-left / bottom-right links other parameters bind to.

				An angle parameter is optional. When it is set the control adds the rotation
				handle and the region rotates, which is the quadrilateral tracker's surface;
				an angle parameter of 0 keeps the region axis-aligned. The control composes the
				shared FxGripOSCRectPart family, so it inherits the standard handle drawing,
				hit-testing, and modifier behavior. A subclass calls
				`addTrackerRegionWithLowerLeftParameterID:upperRightParameterID:angleParameterID:`
				from its initializer, the way FxGripPointOSC adds a point.
*/
@interface FxGripObjectTrackerOSC : FxGripOnScreenControl

/*! Composes and appends the region parts, numbering them after the existing parts. */
- (void)addTrackerRegionWithLowerLeftParameterID:(FxParameterId)lowerLeftParameterID
						  upperRightParameterID:(FxParameterId)upperRightParameterID
							   angleParameterID:(FxParameterId)angleParameterID;

/*! The region parts, numbered from firstPartID: the body, the four corner handles, and the
	rotation handle when angleParameterID is nonzero. */
+ (nonnull NSArray<FxGripOSCPart *> *)trackerRegionPartsWithFirstPartID:(NSInteger)firstPartID
												  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
												 upperRightParameterID:(FxParameterId)upperRightParameterID
													  angleParameterID:(FxParameterId)angleParameterID;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripObjectTrackerOSC_h */
