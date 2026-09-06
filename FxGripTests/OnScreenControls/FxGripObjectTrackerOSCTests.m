//
//  FxGripObjectTrackerOSCTests.m
//  FxGripTests
//
//  The object tracker on-screen control composes the shared rectangle parts for the region's
//  two corner point parameters: the body and four corner handles, plus a rotation handle when
//  an angle parameter is linked. Part composition is geometry, so no GPU is needed. The
//  control header is framework-internal, so the surface is re-declared and reached by name.
//

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

- (void)testLinkedAngleAddsRotationHandle
{
	NSArray<FxGripOSCPart *> *parts = [[self oscClass] trackerRegionPartsWithFirstPartID:1
																   lowerLeftParameterID:21
																  upperRightParameterID:22
																	   angleParameterID:9];
	XCTAssertEqual(parts.count, 6u, @"body + four corners + rotation handle");
}

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
