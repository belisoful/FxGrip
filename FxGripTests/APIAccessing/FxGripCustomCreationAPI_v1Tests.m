/*!
	@file       FxGripCustomCreationAPI_v1Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripCustomCreationAPI_v1Tests
	@abstract   Verifies that each FxGripCustomCreationAPI_v1 method registers its control through the host creation API with the default value the arguments describe.
	@discussion Introduced in FxGrip 0.1.0. The API is exercised against the shared parameter-class stub effect, whose creation API records every host call. Each test asserts the recorded ID, name, flags, and the keys of the default value, including the fallbacks for a nil title and the omission of unset URL, whitelist, and height entries.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripDictionary.h>
#import <FxGrip/FxGripParameterFlags.h>
#import <FxGrip/FxGripCustomCreationAPI_v1.h>
#import <FxGrip/FxGripAllParameters.h>
#import <FxGrip/FxGripBanner.h>
#import <FxGrip/FxGripCapsule.h>
#import <FxGrip/FxGripRandom.h>
#import <FxGrip/FxGripSection.h>
#import <FxGrip/FxGripVideoView.h>
#import <FxGrip/FxGripURLWhitelist.h>
#import <FxGrip/FxGripWebView.h>
#import "FxGripParameterClassTestSupport.h"

static const FxParameterId kCustomCreationTestID = 501;

@interface FxGripCustomCreationAPI_v1Tests : XCTestCase
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) FxGripCustomCreationAPI_v1 *api;
@end

@implementation FxGripCustomCreationAPI_v1Tests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.effect.apiManager = [FxGripParamClassTestAPIManager.alloc init];
	self.api = [FxGripCustomCreationAPI_v1.alloc initWithEffect:(id)self.effect];
}

- (void)tearDown
{
	self.api = nil;
	self.effect = nil;
	[super tearDown];
}

- (NSDictionary *)call
{
	return self.effect.creationCall;
}

/*! The recorded default value, read through objectForKey: so a wrapped dictionary answers too. */
- (id)defaultValue:(NSString *)key
{
	return [self.call[@"default"] objectForKey:key];
}

/*!
	Asserts the single recorded registration. A parameter class ORs the custom-UI flag set onto
	the caller's flags, so the caller's flags are asserted by containment. A control that draws
	its own label registers an empty host name and carries its label in the default value.
*/
- (void)assertOneCallWithID:(FxParameterId)parameterID hostName:(NSString *)hostName callerFlags:(FxParameterFlags)callerFlags
{
	XCTAssertEqual(self.effect.creationCalls.count, 1u);
	XCTAssertEqualObjects(self.call[@"id"], @(parameterID));
	XCTAssertEqualObjects(self.call[@"name"], hostName);

	FxParameterFlags recorded = (FxParameterFlags)[self.call[@"flags"] unsignedIntegerValue];
	XCTAssertEqual(recorded & callerFlags, callerFlags);
	XCTAssertNotEqual(recorded & kFxParameterFlag_CUSTOM_UI, 0u);
	XCTAssertNotEqual(recorded & kFxParameterFlag_NOSTATE, 0u);
}

/*! YES when the recorded registration asked the host for the full inspector width. */
- (BOOL)callUsesFullViewWidth
{
	FxParameterFlags recorded = (FxParameterFlags)[self.call[@"flags"] unsignedIntegerValue];
	return (recorded & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0;
}

#pragma mark Construction

/*! @abstract The API carries the effect it registers against and conforms to its protocol. */
- (void)testTheAPICarriesTheEffect
{
	XCTAssertEqual((id)self.api.effect, (id)self.effect);
	XCTAssertTrue([self.api conformsToProtocol:@protocol(FxGripCustomCreationAPI_v1)]);
}

#pragma mark Sections and dividers

/*! @abstract addSectionWithName: registers a section titled with the name. */
- (void)testAddSectionRegistersATitledSection
{
	XCTAssertTrue([self.api addSectionWithName:@"Look" parameterID:kCustomCreationTestID
								parameterFlags:kFxParameterFlag_COLLAPSED]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"" callerFlags:kFxParameterFlag_COLLAPSED];
	XCTAssertTrue(self.callUsesFullViewWidth);
	XCTAssertEqualObjects([self defaultValue:kFxGripSectionKey_Title], @"Look");
}

/*! @abstract addDividerWithParameterID: registers a divider with an empty name. */
- (void)testAddDividerRegistersAnUnnamedDivider
{
	XCTAssertTrue([self.api addDividerWithParameterID:kCustomCreationTestID parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertTrue(self.callUsesFullViewWidth);
}

#pragma mark Banner and capsule

/*! @abstract addBannerWithName: registers a banner carrying the title and subtitle. */
- (void)testAddBannerRegistersTheTitleAndSubtitle
{
	XCTAssertTrue([self.api addBannerWithName:@"Info" parameterID:kCustomCreationTestID
										title:@"Rendering" subtitle:@"Pass 2"
							   parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertTrue(self.callUsesFullViewWidth);
	XCTAssertEqualObjects([self defaultValue:kFxGripBannerKey_Title], @"Rendering");
	XCTAssertEqualObjects([self defaultValue:kFxGripBannerKey_Subtitle], @"Pass 2");
}

/*! @abstract A banner with no title uses its name, and a nil subtitle is left out of the default. */
- (void)testAddBannerFallsBackToTheNameAndOmitsANilSubtitle
{
	XCTAssertTrue([self.api addBannerWithName:@"Info" parameterID:kCustomCreationTestID
										title:nil subtitle:nil parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects([self defaultValue:kFxGripBannerKey_Title], @"Info");
	XCTAssertNil([self defaultValue:kFxGripBannerKey_Subtitle]);
}

/*! @abstract addCapsuleWithName: registers a capsule carrying the title. */
- (void)testAddCapsuleRegistersTheTitle
{
	XCTAssertTrue([self.api addCapsuleWithName:@"Mode" parameterID:kCustomCreationTestID
										 title:@"Fast" parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"Mode" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertEqualObjects([self defaultValue:kFxGripCapsuleKey_Title], @"Fast");
}

/*! @abstract A capsule with no title uses its name. */
- (void)testAddCapsuleFallsBackToTheName
{
	XCTAssertTrue([self.api addCapsuleWithName:@"Mode" parameterID:kCustomCreationTestID
										 title:nil parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects([self defaultValue:kFxGripCapsuleKey_Title], @"Mode");
}

#pragma mark Status, progress, switch, random

/*! @abstract addStatusWithName: registers the state and label. */
- (void)testAddStatusRegistersTheStateAndLabel
{
	XCTAssertTrue([self.api addStatusWithName:@"State" parameterID:kCustomCreationTestID
										state:2 label:@"Ready" parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"State" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertEqualObjects([self defaultValue:kCustomAPI_IntKey], @2);
	XCTAssertEqualObjects([self defaultValue:kCustomAPI_StringKey], @"Ready");
}

/*! @abstract addProgressWithName: registers the state, label, and fraction; a nil label becomes empty. */
- (void)testAddProgressRegistersTheStateLabelAndFraction
{
	XCTAssertTrue([self.api addProgressWithName:@"Render" parameterID:kCustomCreationTestID
										  state:1 label:nil fraction:0.25
								 parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"Render" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertEqualObjects([self defaultValue:kCustomAPI_IntKey], @1);
	XCTAssertEqualObjects([self defaultValue:kCustomAPI_StringKey], @"");
	XCTAssertEqualObjects([self defaultValue:kCustomAPI_FloatKey], @0.25);
}

/*! @abstract addSwitchWithName: registers the boolean default. */
- (void)testAddSwitchRegistersTheBooleanDefault
{
	XCTAssertTrue([self.api addSwitchWithName:@"Enabled" parameterID:kCustomCreationTestID
								 defaultValue:YES parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"Enabled" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertEqualObjects([self defaultValue:kCustomAPI_BoolKey], @YES);
}

/*! @abstract addSwitchWithName: registers an off default as NO. */
- (void)testAddSwitchRegistersAnOffDefault
{
	XCTAssertTrue([self.api addSwitchWithName:@"Enabled" parameterID:kCustomCreationTestID
								 defaultValue:NO parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertEqualObjects([self defaultValue:kCustomAPI_BoolKey], @NO);
}

/*! @abstract addRandomWithName: registers the value, range, and step. */
- (void)testAddRandomRegistersTheValueRangeAndStep
{
	XCTAssertTrue([self.api addRandomWithName:@"Seed" parameterID:kCustomCreationTestID
								 defaultValue:7 minimum:1 maximum:100 step:3
							   parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"Seed" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertEqualObjects([self defaultValue:kFxGripRandomKey_Value], @7);
	XCTAssertEqualObjects([self defaultValue:kFxGripRandomKey_Min], @1);
	XCTAssertEqualObjects([self defaultValue:kFxGripRandomKey_Max], @100);
	XCTAssertEqualObjects([self defaultValue:kFxGripRandomKey_Step], @3);
}

#pragma mark Web and video views

/*! @abstract addWebViewWithName: registers the URL, whitelist, and height. */
- (void)testAddWebViewRegistersTheURLWhitelistAndHeight
{
	XCTAssertTrue([self.api addWebViewWithName:@"Docs" parameterID:kCustomCreationTestID
										   URL:@"https://example.com/docs"
									 whitelist:@[@"example.com"] height:240
								parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertTrue(self.callUsesFullViewWidth);
	XCTAssertEqualObjects([self defaultValue:kFxGripWebViewKey_URL], @"https://example.com/docs");
	XCTAssertEqualObjects([self defaultValue:kFxGripWebViewKey_Whitelist], @[@"example.com"]);
	XCTAssertEqualObjects([self defaultValue:kFxGripWebViewKey_Height], @240);
}

/*! @abstract A web view with no URL, whitelist, or height leaves those entries out of the default. */
- (void)testAddWebViewOmitsUnsetEntries
{
	XCTAssertTrue([self.api addWebViewWithName:@"Docs" parameterID:kCustomCreationTestID
										   URL:nil whitelist:nil height:0
								parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertNil([self defaultValue:kFxGripWebViewKey_URL]);
	XCTAssertNil([self defaultValue:kFxGripWebViewKey_Height]);

	// The creation API omits an unset whitelist; FxGripWebViewParameter then opens it to all sites.
	XCTAssertEqualObjects([self defaultValue:kFxGripWebViewKey_Whitelist], @[@"*"]);
}

/*! @abstract addVideoViewWithName: registers the URL, whitelist, height, autoplay, and loop. */
- (void)testAddVideoViewRegistersTheSourceAndPlaybackFlags
{
	XCTAssertTrue([self.api addVideoViewWithName:@"Demo" parameterID:kCustomCreationTestID
											 URL:@"https://example.com/demo.mp4"
									   whitelist:@[@"example.com"] height:180
										autoplay:YES loop:NO
								  parameterFlags:kFxParameterFlag_DEFAULT]);

	[self assertOneCallWithID:kCustomCreationTestID hostName:@"" callerFlags:kFxParameterFlag_DEFAULT];
	XCTAssertTrue(self.callUsesFullViewWidth);
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_URL], @"https://example.com/demo.mp4");
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Whitelist], @[@"example.com"]);
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Height], @180);
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Autoplay], @YES);
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Loop], @NO);
}

/*! @abstract A video view with no source leaves the URL, whitelist, and height out but always carries the playback flags. */
- (void)testAddVideoViewOmitsUnsetEntriesAndKeepsThePlaybackFlags
{
	XCTAssertTrue([self.api addVideoViewWithName:@"Demo" parameterID:kCustomCreationTestID
											 URL:nil whitelist:nil height:0
										autoplay:NO loop:YES
								  parameterFlags:kFxParameterFlag_DEFAULT]);

	XCTAssertNil([self defaultValue:kFxGripVideoKey_URL]);
	XCTAssertNil([self defaultValue:kFxGripVideoKey_Height]);

	// The creation API omits an unset whitelist; FxGripVideoViewParameter then supplies the
	// shared video-hosting list rather than opening playback to every site.
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Whitelist],
						  FxGripURLWhitelist.defaultVideoWhitelist.patterns);
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Autoplay], @NO);
	XCTAssertEqualObjects([self defaultValue:kFxGripVideoKey_Loop], @YES);
}

#pragma mark Host refusal

/*! @abstract A host that refuses the registration makes the method answer NO. */
- (void)testAHostRefusalAnswersNo
{
	self.effect.apiManager.paramCreateAPIv5.succeeds = NO;

	XCTAssertFalse([self.api addSectionWithName:@"Look" parameterID:kCustomCreationTestID
								 parameterFlags:kFxParameterFlag_DEFAULT]);
	XCTAssertFalse([self.api addSwitchWithName:@"Enabled" parameterID:kCustomCreationTestID
								  defaultValue:NO parameterFlags:kFxParameterFlag_DEFAULT]);
}

@end
