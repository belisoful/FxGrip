/*!
	@file       FxGripObjectTrackerOSCTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripObjectTrackerOSCTests
	@abstract   Verifies part composition for the FxGripObjectTrackerOSC tracker region control.
	@discussion Introduced in FxGrip 0.1.0. The control composes the shared rectangle parts for a region's two corner point parameters, adding a rotation handle when an angle parameter is linked. The tests confirm an axis-aligned region composes a body and four corners numbered from the first part ID, a linked angle adds a rotation handle, and adding a second region appends and continues the part numbering.
*/

#import <XCTest/XCTest.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>

@interface FxGripOSCPart : NSObject
@property (nonatomic, assign) NSInteger partID;
@end

@interface FxGripObjectTrackerOSC : NSObject
- (instancetype)initWithAPIManager:(id)apiManager;
@property (readonly, nonatomic) NSArray<FxGripOSCPart *> *parts;
- (void)addTrackerRegionWithLowerLeftParameterID:(FxParameterId)lowerLeftParameterID
						  upperRightParameterID:(FxParameterId)upperRightParameterID
							   angleParameterID:(FxParameterId)angleParameterID;
+ (NSArray<FxGripOSCPart *> *)trackerRegionPartsWithFirstPartID:(NSInteger)firstPartID
										  lowerLeftParameterID:(FxParameterId)lowerLeftParameterID
										 upperRightParameterID:(FxParameterId)upperRightParameterID
											  angleParameterID:(FxParameterId)angleParameterID;
@end


@interface FxGripObjectTrackerOSCTests : XCTestCase
@end

@implementation FxGripObjectTrackerOSCTests

- (Class)oscClass
{
	return NSClassFromString(@"FxGripObjectTrackerOSC");
}

/*! @abstract An axis-aligned region composes a body and four corner handles numbered from the first part ID. */
- (void)testAxisAlignedRegionComposesBodyAndFourCorners
{
	NSArray<FxGripOSCPart *> *parts = [[self oscClass] trackerRegionPartsWithFirstPartID:1
																   lowerLeftParameterID:21
																  upperRightParameterID:22
																	   angleParameterID:0];
	XCTAssertEqual(parts.count, 5u, @"body + four corner handles");
	for (NSUInteger i = 0; i < parts.count; i++) {
		XCTAssertEqual(parts[i].partID, (NSInteger)(1 + i), @"parts numbered from firstPartID");
	}
}

/*! @abstract A linked angle parameter adds a rotation handle to the body and four corners. */
- (void)testLinkedAngleAddsRotationHandle
{
	NSArray<FxGripOSCPart *> *parts = [[self oscClass] trackerRegionPartsWithFirstPartID:1
																   lowerLeftParameterID:21
																  upperRightParameterID:22
																	   angleParameterID:9];
	XCTAssertEqual(parts.count, 6u, @"body + four corners + rotation handle");
}

/*! @abstract Adding a second tracker region appends its parts and continues the part numbering. */
- (void)testAddTrackerRegionAppendsAndRenumbers
{
	id osc = [[[self oscClass] alloc] initWithAPIManager:(id)nil];
	[osc addTrackerRegionWithLowerLeftParameterID:21 upperRightParameterID:22 angleParameterID:0];
	XCTAssertEqual([[osc parts] count], 5u);

	[osc addTrackerRegionWithLowerLeftParameterID:31 upperRightParameterID:32 angleParameterID:0];
	XCTAssertEqual([[osc parts] count], 10u);
	XCTAssertEqual([[osc parts][5] partID], 6, @"the second region continues the numbering");
}

@end
