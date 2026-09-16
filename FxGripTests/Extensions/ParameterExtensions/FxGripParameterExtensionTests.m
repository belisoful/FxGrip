/*!
	@file       FxGripParameterExtensionTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripParameterExtensionTests
	@abstract   Unit tests for the parameter extension's add observer, ID freeze, and change bracket.
	@discussion Introduced in FxGrip 0.1.0. The extension observes the parameter-add notification on
	            the effect's notifier and tags the matching parameter with its extension key. The
	            tests drive that observer through a stub effect carrying an isolated priority center,
	            covering the ID match, the extension-key and factory tagging, and the ID freeze that
	            follows the first observed add.
*/

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripAPINotifications.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripCustomExtension.h>

static const FxParameterId kFxGripParamExtTestParameter = 812;

/*! Stands in for the effect whose notifier the extension observes. */
@interface FxGripParamExtTestEffect : NSObject
@property (nonatomic, strong, readonly) NSNotificationCenter *notifier;
@end

@implementation FxGripParamExtTestEffect

- (instancetype)init
{
	self = [super init];
	if (self) {
		Class cls = NSClassFromString(@"NSPriorityNotificationCenter");
		_notifier = [[cls alloc] init];
	}
	return self;
}

- (id)effectBase { return self; }
- (id)objectAtIndexedSubscript:(NSInteger)index { return nil; }

@end

/*! A parameter extension that also builds parameters, so the add observer tags the factory. */
@interface FxGripParamExtTestFactoryExtension : FxGripCustomExtension <FxParameterFactory>
@end

@implementation FxGripParamExtTestFactoryExtension
@end

@interface FxGripParameterExtensionTests : XCTestCase
@property (nonatomic, strong) FxGripParamExtTestEffect *effect;
@property (nonatomic, strong) FxGripCustomExtension *extension;
@end

@implementation FxGripParameterExtensionTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamExtTestEffect.alloc init];
	self.extension = [FxGripCustomExtension.alloc init];
	self.extension.parameterID = kFxGripParamExtTestParameter;
	XCTAssertTrue([self.extension extLoadWithEffect:(id)self.effect]);
}

- (void)tearDown
{
	self.extension = nil;
	self.effect = nil;
	[super tearDown];
}

/*! Posts the pre-add notification the parameter creation API posts, carrying one parameter. */
- (void)postAddPreForParameter:(NSMutableDictionary *)parameter
{
	NSMutableDictionary *userInfo = @{kFxParameterProperty_Id: parameter[kFxParameterProperty_Id],
									  FxGripNotifyAPI_ParameterKey: parameter}.mutableCopy;
	[self.effect.notifier postNotificationName:FxGripNotifyAPI_ParameterAddPreName
										object:self.effect
									  userInfo:userInfo];
}

- (NSMutableDictionary *)parameterWithID:(FxParameterId)parameterID
{
	return @{kFxParameterProperty_Id: @(parameterID),
			 kFxParameterProperty_Type: kFxParameterType_Custom,
			 kFxParameterProperty_Name: @"Extension Parameter"}.mutableCopy;
}

#pragma mark The parameter-add observer

/*! @abstract The add observer tags the matching parameter with the extension's key. */
- (void)testTheAddObserverTagsTheMatchingParameterWithTheExtensionKey
{
	NSMutableDictionary *parameter = [self parameterWithID:kFxGripParamExtTestParameter];

	[self postAddPreForParameter:parameter];

	XCTAssertEqualObjects(parameter[kFxParameterProperty_ExtensionKey], self.extension.extKey);
	XCTAssertNil(parameter[kFxParameterProperty_Factory],
				 @"a plain parameter extension builds no parameters, so it tags no factory");
}

/*! @abstract The add observer leaves a parameter carrying another extension's key alone. */
- (void)testTheAddObserverKeepsAnExistingExtensionKey
{
	NSMutableDictionary *parameter = [self parameterWithID:kFxGripParamExtTestParameter];
	parameter[kFxParameterProperty_ExtensionKey] = @"SomeOtherExtension";

	[self postAddPreForParameter:parameter];

	XCTAssertEqualObjects(parameter[kFxParameterProperty_ExtensionKey], @"SomeOtherExtension");
}

/*! @abstract The add observer ignores a parameter whose ID is not the extension's. */
- (void)testTheAddObserverIgnoresAnotherParametersAdd
{
	NSMutableDictionary *parameter = [self parameterWithID:kFxGripParamExtTestParameter + 1];

	[self postAddPreForParameter:parameter];

	XCTAssertNil(parameter[kFxParameterProperty_ExtensionKey]);
}

/*! @abstract An extension that builds parameters tags itself as the parameter's factory. */
- (void)testAFactoryExtensionTagsItselfAsTheParameterFactory
{
	FxGripParamExtTestFactoryExtension *factory = [FxGripParamExtTestFactoryExtension.alloc init];
	factory.parameterID = kFxGripParamExtTestParameter;
	XCTAssertTrue([factory extLoadWithEffect:(id)self.effect]);

	NSMutableDictionary *parameter = [self parameterWithID:kFxGripParamExtTestParameter];
	[self postAddPreForParameter:parameter];

	XCTAssertEqual((id)parameter[kFxParameterProperty_Factory], (id)factory);
}

#pragma mark The parameter ID freeze

/*! @abstract The parameter ID can be set until the first add is observed, and is frozen after it. */
- (void)testTheParameterIDFreezesAfterTheFirstObservedAdd
{
	self.extension.parameterID = kFxGripParamExtTestParameter + 5;
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)(kFxGripParamExtTestParameter + 5));

	[self postAddPreForParameter:[self parameterWithID:kFxGripParamExtTestParameter + 5]];

	self.extension.parameterID = kFxGripParamExtTestParameter + 9;
	XCTAssertEqual(self.extension.parameterID, (FxParameterId)(kFxGripParamExtTestParameter + 5),
				   @"registration is underway, so the ID no longer moves");
}

#pragma mark The change bracket

/*! @abstract The change bracket accepts a start and an end without reporting an error. */
- (void)testTheChangeBracketAcceptsAStartAndAnEnd
{
	CMTime time = (CMTime){.value = 0, .timescale = 1, .flags = kCMTimeFlags_Valid};
	NSError *error = nil;

	XCTAssertTrue([self.extension startChangedTime:time error:&error]);
	XCTAssertNil(error);
	XCTAssertTrue([self.extension endChangedTime:time error:&error]);
	XCTAssertNil(error);
}

@end
