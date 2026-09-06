/*!
	@file       FxGripParameterRetrievalAPI_v7Tests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripParameterRetrievalAPI_v7Tests
	@abstract   Verifies the v7 retrieval wrapper forwards the image-size query to the host, propagates failure, and remains a v6 wrapper.
	@discussion Introduced in FxGrip 0.1.0. The tests drive the wrapper against a recording stub host. They assert the forwarded parameter ID and returned size, the failure result, and the v6 protocol conformance.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripParameterRetrievalAPI_v7.h>

static CMTime FxGripV7Time(void)
{
	return (CMTime){ .value = 0, .timescale = 30, .flags = kCMTimeFlags_Valid };
}

/*! A stand-in host v7 API recording the request and returning a staged size. */
@interface FxGripV7StubAPI : NSObject
@property (nonatomic, assign) CGSize stagedSize;
@property (nonatomic, assign) BOOL stagedResult;
@property (nonatomic, assign) UInt32 lastParameterID;
@end

@implementation FxGripV7StubAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_stagedSize = CGSizeMake(1920, 1080);
		_stagedResult = YES;
	}
	return self;
}

- (BOOL)imageSize:(CGSize *)imageSize fromParameter:(UInt32)parameterID atTime:(CMTime)time error:(NSError **)error
{
	self.lastParameterID = parameterID;
	if (imageSize != NULL) {
		*imageSize = self.stagedSize;
	}
	return self.stagedResult;
}

@end

@interface FxGripV7StubEffect : NSObject
@property (nonatomic, strong) NSNotificationCenter *notifier;
@end

@implementation FxGripV7StubEffect
- (instancetype)init
{
	self = [super init];
	if (self) {
		_notifier = [NSNotificationCenter new];
	}
	return self;
}
@end

@interface FxGripParameterRetrievalAPI_v7Tests : XCTestCase
@end

@implementation FxGripParameterRetrievalAPI_v7Tests

- (FxGripParameterRetrievalAPI_v7 *)wrapperWithHost:(FxGripV7StubAPI *)host
{
	return [FxGripParameterRetrievalAPI_v7.alloc initWithAPI:(id)host
										   parameterInfoAPIv1:nil
													  effect:(id)FxGripV7StubEffect.new];
}

/*! @abstract imageSize: forwards the parameter ID to the host and returns the host's staged size. */
- (void)testImageSizeForwardsToTheHostAPI
{
	FxGripV7StubAPI *host = FxGripV7StubAPI.new;
	host.stagedSize = CGSizeMake(3840, 2160);
	FxGripParameterRetrievalAPI_v7 *wrapper = [self wrapperWithHost:host];

	CGSize size = CGSizeMake(0, 0);
	NSError *error = nil;
	BOOL ok = [wrapper imageSize:&size fromParameter:42 atTime:FxGripV7Time() error:&error];

	XCTAssertTrue(ok);
	XCTAssertEqual(size.width, 3840.0);
	XCTAssertEqual(size.height, 2160.0);
	XCTAssertEqual(host.lastParameterID, (UInt32)42);
}

/*! @abstract imageSize: propagates a host failure as NO. */
- (void)testImageSizePropagatesFailure
{
	FxGripV7StubAPI *host = FxGripV7StubAPI.new;
	host.stagedResult = NO;
	FxGripParameterRetrievalAPI_v7 *wrapper = [self wrapperWithHost:host];

	CGSize size = CGSizeMake(0, 0);
	XCTAssertFalse([wrapper imageSize:&size fromParameter:1 atTime:FxGripV7Time() error:NULL]);
}

/*! @abstract The v7 wrapper conforms to both the v7 and v6 retrieval protocols and subclasses the v6 wrapper. */
- (void)testTheV7WrapperIsAlsoAV6Wrapper
{
	FxGripParameterRetrievalAPI_v7 *wrapper = [self wrapperWithHost:FxGripV7StubAPI.new];
	XCTAssertTrue([wrapper conformsToProtocol:@protocol(FxParameterRetrievalAPI_v7)]);
	XCTAssertTrue([wrapper conformsToProtocol:@protocol(FxParameterRetrievalAPI_v6)]);
	XCTAssertTrue([wrapper isKindOfClass:FxGripParameterRetrievalAPI_v6.class]);
}

@end
