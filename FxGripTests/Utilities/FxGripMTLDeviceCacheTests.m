/*!
	@file       FxGripMTLDeviceCacheTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMTLDeviceCacheTests
	@abstract   Tests the Metal device cache, its command queue pool, library function caching, and render pipeline memoization.
	@discussion Introduced in FxGrip 0.1.0. FxGripMTLDeviceCache keys device cache items by registry ID, pixel format, and plugin ID, and pools command queues for scoped checkout. The cache memoizes library functions and render pipeline states. These tests run against the real system Metal device and cover concurrent access, scoped queue lifetime, synchronous and asynchronous shader compilation, and device removal.
*/

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
#import <CoreVideo/CoreVideo.h>
#import "FxPlugStub.h"
#import <FxGrip/FxGripMTLDeviceCache.h>

static NSString * const kInUseKey = @"InUse";
static NSString * const kCommandQueueKey = @"CommandQueue";


/*! Forwards to a real library but holds asynchronous name compiles until the test releases them. */
@interface FxGripDeferredLibrary : NSProxy
@property (nonatomic, strong) id<MTLLibrary> target;
@property (nonatomic, copy) void (^capturedHandler)(id<MTLFunction>, NSError *);
@property (nonatomic) NSUInteger compileCount;
+ (instancetype)deferredLibraryWithTarget:(id<MTLLibrary>)target;
@end

@implementation FxGripDeferredLibrary

+ (instancetype)deferredLibraryWithTarget:(id<MTLLibrary>)target
{
	FxGripDeferredLibrary *proxy = [self alloc];
	proxy.target = target;
	return proxy;
}

- (void)newFunctionWithName:(NSString *)name
			 constantValues:(MTLFunctionConstantValues *)constantValues
		  completionHandler:(void (^)(id<MTLFunction>, NSError *))completionHandler
{
	self.compileCount += 1;
	self.capturedHandler = completionHandler;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [(NSObject *)self.target methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation invokeWithTarget:self.target];
}

- (BOOL)conformsToProtocol:(Protocol *)protocol
{
	return [self.target conformsToProtocol:protocol];
}

- (BOOL)respondsToSelector:(SEL)sel
{
	return [self.target respondsToSelector:sel];
}

@end

/*! A library stand-in that answers one member the library cache does not implement itself. */
@interface FxGripExtraMemberLibrary : NSObject
@property (nonatomic, strong) id<MTLLibrary> target;
- (NSString *)fxgExtraLibraryMember;
@end

@implementation FxGripExtraMemberLibrary

- (NSString *)fxgExtraLibraryMember
{
	return @"forwarded";
}

- (id)forwardingTargetForSelector:(SEL)selector
{
	return self.target;
}

- (BOOL)respondsToSelector:(SEL)selector
{
	return [super respondsToSelector:selector] || [self.target respondsToSelector:selector];
}

@end

/*! The cache item implements a bounds-sized depth texture that no header declares. */
@interface FxGripMTLDeviceCacheItem (FxGripMTLDeviceCacheTests)
- (nullable id<MTLTexture>)depthTexture:(FxRect)bounds;
@end

@interface FxGripMTLDeviceCacheTests : XCTestCase
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) NSString *pluginID;
@end

@implementation FxGripMTLDeviceCacheTests

- (void)setUp
{
	[super setUp];
	self.device = MTLCreateSystemDefaultDevice();
	self.pluginID = [NSString stringWithFormat:@"test.%@", NSUUID.UUID.UUIDString];
}

- (FxGripMTLDeviceCacheItem *)item
{
	return [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
													  pixelFormat:MTLPixelFormatRGBA16Float
													  andPluginID:self.pluginID];
}

- (BOOL)item:(FxGripMTLDeviceCacheItem *)item marksQueueInUse:(id<MTLCommandQueue>)queue
{
	[item.commandQueueCacheLock lock];
	NSNumber *inUse = nil;
	for (NSDictionary *entry in item.commandQueueCache) {
		if (entry[kCommandQueueKey] == queue) {
			inUse = entry[kInUseKey];
		}
	}
	[item.commandQueueCacheLock unlock];
	XCTAssertNotNil(inUse, @"queue is not pooled by the item");
	return inUse.boolValue;
}

/*! The cache's item list. The cache holds it in an ivar with no accessor. */
- (NSArray<FxGripMTLDeviceCacheItem *> *)cachedItems
{
	return [(id)FxGripMTLDeviceCache.deviceCache valueForKey:@"deviceCaches"];
}

- (id<MTLLibrary>)frameworkLibrary
{
	NSError *error = nil;
	id<MTLLibrary> library = [self.device newDefaultLibraryWithBundle:[NSBundle bundleForClass:FxGripMTLDeviceCache.class]
															   error:&error];
	XCTAssertNotNil(library, @"%@", error);
	return library;
}

#pragma mark Legacy names

/*! @abstract The legacy Guru class and selector are absent while the FxGrip class and scoped selectors respond. */
- (void)testNoGuruSelectorsRemain
{
	XCTAssertNil(NSClassFromString(@"GuruMTLCommandQueue"));
	XCTAssertNotNil(NSClassFromString(@"FxGripMTLCommandQueue"));
	XCTAssertFalse([FxGripMTLDeviceCache respondsToSelector:NSSelectorFromString(@"guruCommandQueueForImageTile:")]);
	XCTAssertTrue([FxGripMTLDeviceCache respondsToSelector:@selector(scopedCommandQueueForImageTile:)]);
	XCTAssertTrue([FxGripMTLDeviceCache respondsToSelector:@selector(scopedCommandQueueForImageTile:pluginID:)]);
}

#pragma mark Cache lookup

/*! @abstract The deviceCache accessor returns the same shared instance on every call. */
- (void)testDeviceCacheIsSingleton
{
	XCTAssertTrue(FxGripMTLDeviceCache.deviceCache == FxGripMTLDeviceCache.deviceCache);
}

/*! @abstract A registry-ID lookup returns an item bound to the system device with the default pixel format and no plugin ID. */
- (void)testDeviceWithRegistryIDReturnsSystemDevice
{
	FxGripMTLDeviceCacheItem *item = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID];
	XCTAssertNotNil(item);
	XCTAssertEqual(item.registryID, self.device.registryID);
	XCTAssertEqual(item.gpuDevice.registryID, self.device.registryID);
	XCTAssertEqual(item.pixelFormat, MTLPixelFormatRGBA16Float);
	XCTAssertNil(item.pluginID);
}

/*! @abstract An unknown registry ID returns nil from both the cache lookup and the device-from-ID resolver. */
- (void)testUnknownRegistryIDReturnsNil
{
	XCTAssertNil([FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:0xFFFFFFFFFFFFFFFFull]);
	XCTAssertNil([FxGripMTLDeviceCache metalDeviceFromID:0xFFFFFFFFFFFFFFFFull]);
}

/*! @abstract The same key reuses one item, a different pixel format creates a distinct item, and the wildcard format matches an existing item. */
- (void)testSameKeyReusesItemAndDifferentKeyCreatesItem
{
	FxGripMTLDeviceCacheItem *first = self.item;
	XCTAssertNotNil(first);
	XCTAssertTrue(first == self.item);

	FxGripMTLDeviceCacheItem *otherFormat = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
																					   pixelFormat:MTLPixelFormatBGRA8Unorm
																					   andPluginID:self.pluginID];
	XCTAssertNotNil(otherFormat);
	XCTAssertFalse(first == otherFormat);
	XCTAssertEqual(otherFormat.pixelFormat, MTLPixelFormatBGRA8Unorm);

	FxGripMTLDeviceCacheItem *anyFormat = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
																					 pixelFormat:FxGripMTLPixelFormatAny
																					 andPluginID:self.pluginID];
	XCTAssertTrue(anyFormat == first || anyFormat == otherFormat);
}

/*! @abstract Concurrent lookups over four distinct plugin IDs create exactly one item per key. */
- (void)testConcurrentLookupsCreateOneItemPerKey
{
	NSMutableSet *items = [NSMutableSet set];
	NSLock *lock = [[NSLock alloc] init];
	dispatch_apply(64, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
		NSString *pluginID = [NSString stringWithFormat:@"%@.%zu", self.pluginID, i % 4];
		FxGripMTLDeviceCacheItem *item = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
																					pixelFormat:MTLPixelFormatRGBA16Float
																					andPluginID:pluginID];
		[lock lock];
		[items addObject:[NSValue valueWithNonretainedObject:item]];
		[lock unlock];
	});
	XCTAssertEqual(items.count, 4u);
}

#pragma mark Command queue pool

/*! @abstract Checking out a queue marks it in use and pooled, and returning it clears the in-use flag. */
- (void)testCommandQueueCheckoutAndReturn
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLCommandQueue> queue = [item getNextFreeCommandQueue];
	XCTAssertNotNil(queue);
	XCTAssertTrue([item containsCommandQueue:queue]);
	XCTAssertTrue([self item:item marksQueueInUse:queue]);

	[FxGripMTLDeviceCache returnCommandQueue:queue];
	XCTAssertFalse([self item:item marksQueueInUse:queue]);
}

/*! @abstract The pool grows to hand every caller a distinct queue, and each returns to the free state. */
- (void)testPoolGrowsWhenEveryQueueIsCheckedOut
{
	FxGripMTLDeviceCacheItem *item = self.item;
	NSUInteger initialCount = item.commandQueueCache.count;
	NSMutableArray<id<MTLCommandQueue>> *queues = [NSMutableArray array];
	for (NSUInteger i = 0; i < initialCount + 2; i++) {
		id<MTLCommandQueue> queue = [item getNextFreeCommandQueue];
		XCTAssertNotNil(queue);
		XCTAssertFalse([queues containsObject:queue], @"a checked-out queue was handed out twice");
		[queues addObject:queue];
	}
	XCTAssertEqual(item.commandQueueCache.count, initialCount + 2);

	dispatch_apply(queues.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
		[FxGripMTLDeviceCache.deviceCache returnCommandQueueToCache:queues[i]];
	});
	for (id<MTLCommandQueue> queue in queues) {
		XCTAssertFalse([self item:item marksQueueInUse:queue]);
	}
}

/*! @abstract Returning nil or a queue the item does not own is ignored without throwing. */
- (void)testReturningNilOrForeignQueueIsIgnored
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLCommandQueue> foreign = [self.device newCommandQueue];
	XCTAssertFalse([item containsCommandQueue:foreign]);
	XCTAssertFalse([item containsCommandQueue:nil]);
	XCTAssertNoThrow([FxGripMTLDeviceCache returnCommandQueue:nil]);
	XCTAssertNoThrow([FxGripMTLDeviceCache returnCommandQueue:foreign]);
	XCTAssertNoThrow([item returnCommandQueue:nil]);
}

#pragma mark Scoped command queue

/*! @abstract A scoped command queue exposes its underlying queue while held and returns it to the pool when it deallocates. */
- (void)testScopedCommandQueueReturnsQueueOnDealloc
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLCommandQueue> raw = nil;
	@autoreleasepool {
		FxGripMTLCommandQueue *scoped = [[FxGripMTLCommandQueue alloc] initWithDeviceCacheItem:item];
		XCTAssertNotNil(scoped);
		XCTAssertTrue(scoped.deviceCacheItem == item);
		raw = scoped.queue;
		XCTAssertTrue([self item:item marksQueueInUse:raw]);
		XCTAssertEqual(scoped.device.registryID, self.device.registryID);
		XCTAssertNotNil([scoped commandBuffer]);
		scoped.label = @"scoped";
		XCTAssertEqualObjects(raw.label, @"scoped");
		scoped = nil;
	}
	XCTAssertFalse([self item:item marksQueueInUse:raw]);
}

/*! @abstract Initializing a scoped command queue with a nil cache item returns nil. */
- (void)testScopedCommandQueueWithNilItemIsNil
{
	XCTAssertNil([[FxGripMTLCommandQueue alloc] initWithDeviceCacheItem:nil]);
}

#pragma mark Library cache

/*! @abstract A nil device and an unknown registry ID both yield no library cache. */
- (void)testLibraryCacheForNilDeviceIsNil
{
	XCTAssertNil([FxGripMTLDeviceCache libraryCacheForDevice:nil]);
	XCTAssertNil([FxGripMTLDeviceCache libraryCacheForRegistryID:0xFFFFFFFFFFFFFFFFull]);
}

/*! @abstract The library cache memoizes a resolved function, returns nil for an unknown name without caching, and clears a cached function on request. */
- (void)testLibraryCacheMemoizesFunctionsAndSkipsMisses
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	XCTAssertNotNil(cache);
	XCTAssertEqual(cache.device.registryID, self.device.registryID);

	NSString *name = cache.functionNames.firstObject;
	XCTAssertNotNil(name, @"the FxGrip shader library has no functions");
	XCTAssertFalse([cache isLoaded:name]);
	id<MTLFunction> first = [cache newFunctionWithName:name];
	XCTAssertNotNil(first);
	XCTAssertTrue([cache isLoaded:name]);
	XCTAssertTrue([cache newFunctionWithName:name] == first);
	XCTAssertTrue(cache[name] == first);
	XCTAssertEqual(cache.functionCache.count, 1u);

	XCTAssertNil([cache newFunctionWithName:@"fxGripDoesNotExist"]);
	XCTAssertFalse([cache isLoaded:@"fxGripDoesNotExist"]);
	XCTAssertFalse([cache isLoading:@"fxGripDoesNotExist"]);
	XCTAssertNil(cache[@"fxGripDoesNotExist"]);
	XCTAssertNil(cache[nil]);
	XCTAssertEqual(cache.functionCache.count, 1u);

	XCTAssertTrue([cache clearFunctionWithName:name]);
	XCTAssertFalse([cache clearFunctionWithName:name]);
	XCTAssertEqual(cache.functionCache.count, 0u);
}

/*! @abstract Initializing a library cache with a nil library or a nil device returns nil. */
- (void)testLibraryCacheInitWithNilIsNil
{
	id<MTLLibrary> noLibrary = nil;
	id<MTLDevice> noDevice = nil;
	XCTAssertNil([[FxGripMTLLibraryCache alloc] initWithLibrary:noLibrary]);
	XCTAssertNil([[FxGripMTLLibraryCache alloc] initWithDevice:noDevice]);
}


#pragma mark Asynchronous function loading

- (NSString *)firstFunctionNameIn:(id<MTLLibrary>)library
{
	NSString *name = library.functionNames.firstObject;
	XCTAssertNotNil(name, @"the FxGrip shader library has no functions");
	return name;
}

/*! @abstract An asynchronous load delivers the function, caches it, and serves a later request from the cache. */
- (void)testAsyncLoadDeliversFunctionAndCachesIt
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	NSString *name = [self firstFunctionNameIn:cache];
	XCTestExpectation *done = [self expectationWithDescription:@"async load"];
	__block id<MTLFunction> loaded = nil;
	[cache newFunctionWithName:name constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
		loaded = function;
		XCTAssertNil(error);
		[done fulfill];
	}];
	[self waitForExpectations:@[done] timeout:10.0];
	XCTAssertNotNil(loaded);
	XCTAssertTrue([cache isLoaded:name]);
	XCTAssertFalse([cache isLoading:name]);
	XCTAssertTrue(cache[name] == loaded);

	XCTestExpectation *again = [self expectationWithDescription:@"cached load"];
	[cache newFunctionWithName:name constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
		XCTAssertTrue(function == loaded);
		[again fulfill];
	}];
	[self waitForExpectations:@[again] timeout:1.0];
}

/*! @abstract An asynchronous load of an unknown name reports an error and leaves the cache empty. */
- (void)testAsyncLoadOfMissingFunctionReportsErrorWithoutCaching
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	XCTestExpectation *done = [self expectationWithDescription:@"async miss"];
	[cache newFunctionWithName:@"fxGripDoesNotExist" constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
		XCTAssertNil(function);
		XCTAssertNotNil(error);
		[done fulfill];
	}];
	[self waitForExpectations:@[done] timeout:10.0];
	XCTAssertFalse([cache isLoaded:@"fxGripDoesNotExist"]);
	XCTAssertFalse([cache isLoading:@"fxGripDoesNotExist"]);
	XCTAssertEqual(cache.functionCache.count, 0u);
}

/*! @abstract An asynchronous descriptor load caches under the descriptor's function name, which a later synchronous descriptor request reuses. */
- (void)testAsyncDescriptorLoadKeysByName
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	NSString *name = [self firstFunctionNameIn:cache];
	MTLFunctionDescriptor *descriptor = MTLFunctionDescriptor.functionDescriptor;
	descriptor.name = name;
	XCTestExpectation *done = [self expectationWithDescription:@"descriptor load"];
	[cache newFunctionWithDescriptor:descriptor completionHandler:^(id<MTLFunction> function, NSError *error) {
		XCTAssertNotNil(function);
		[done fulfill];
	}];
	[self waitForExpectations:@[done] timeout:10.0];
	XCTAssertTrue([cache isLoaded:name]);
	XCTAssertTrue([cache newFunctionWithDescriptor:descriptor error:NULL] == cache[name]);
}

/*! @abstract Concurrent asynchronous requests for one name trigger a single compile, and every handler receives the compiled function when it completes. */
- (void)testConcurrentAsyncRequestsShareOneCompileAndEveryHandlerFires
{
	id<MTLLibrary> real = self.frameworkLibrary;
	FxGripDeferredLibrary *deferred = [FxGripDeferredLibrary deferredLibraryWithTarget:real];
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:(id<MTLLibrary>)deferred];
	NSString *name = [self firstFunctionNameIn:real];

	NSMutableArray<id<MTLFunction>> *delivered = [NSMutableArray array];
	NSLock *lock = [[NSLock alloc] init];
	dispatch_apply(3, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
		[cache newFunctionWithName:name constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
			[lock lock];
			[delivered addObject:function];
			[lock unlock];
		}];
	});
	XCTAssertEqual(deferred.compileCount, 1u);
	XCTAssertEqual(delivered.count, 0u);
	XCTAssertTrue([cache isLoading:name]);
	XCTAssertFalse([cache isLoaded:name]);

	id<MTLFunction> compiled = [real newFunctionWithName:name];
	deferred.capturedHandler(compiled, nil);
	XCTAssertEqual(delivered.count, 3u);
	for (id<MTLFunction> function in delivered) {
		XCTAssertTrue(function == compiled);
	}
	XCTAssertTrue([cache isLoaded:name]);
	XCTAssertTrue(cache[name] == compiled);

	XCTestExpectation *late = [self expectationWithDescription:@"late caller"];
	[cache newFunctionWithName:name constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
		XCTAssertTrue(function == compiled);
		[late fulfill];
	}];
	[self waitForExpectations:@[late] timeout:1.0];
	XCTAssertEqual(deferred.compileCount, 1u);
}

/*! @abstract A failed compile delivers the error to every waiter, clears the loading placeholder, and permits a later retry to compile again. */
- (void)testAsyncFailureReachesEveryWaiterAndClearsThePlaceholder
{
	FxGripDeferredLibrary *deferred = [FxGripDeferredLibrary deferredLibraryWithTarget:self.frameworkLibrary];
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:(id<MTLLibrary>)deferred];
	NSError *failure = [NSError errorWithDomain:@"FxGripTests" code:7 userInfo:nil];
	__block NSUInteger errors = 0;
	for (NSUInteger i = 0; i < 2; i++) {
		[cache newFunctionWithName:@"fxGripDeferred" constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
			XCTAssertNil(function);
			XCTAssertTrue(error == failure);
			errors++;
		}];
	}
	XCTAssertEqual(deferred.compileCount, 1u);
	deferred.capturedHandler(nil, failure);
	XCTAssertEqual(errors, 2u);
	XCTAssertFalse([cache isLoading:@"fxGripDeferred"]);
	XCTAssertFalse([cache isLoaded:@"fxGripDeferred"]);

	[cache newFunctionWithName:@"fxGripDeferred" constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {}];
	XCTAssertEqual(deferred.compileCount, 2u, @"a failed compile must not block a retry");
}

/*! @abstract A synchronous request made while an asynchronous compile is pending compiles the function directly and caches that result. */
- (void)testSyncRequestDuringAsyncCompileCompilesDirectly
{
	id<MTLLibrary> real = self.frameworkLibrary;
	FxGripDeferredLibrary *deferred = [FxGripDeferredLibrary deferredLibraryWithTarget:real];
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:(id<MTLLibrary>)deferred];
	NSString *name = [self firstFunctionNameIn:real];
	__block id<MTLFunction> asyncResult = nil;
	[cache newFunctionWithName:name constantValues:nil completionHandler:^(id<MTLFunction> function, NSError *error) {
		asyncResult = function;
	}];
	XCTAssertTrue([cache isLoading:name]);

	id<MTLFunction> direct = [cache newFunctionWithName:name];
	XCTAssertNotNil(direct);
	XCTAssertTrue([cache isLoaded:name]);
	XCTAssertTrue(cache[name] == direct);

	deferred.capturedHandler(direct, nil);
	XCTAssertTrue(asyncResult == direct);
}

#pragma mark Pipeline states

/*! @abstract A render pipeline state built from the supplied library is memoized, so a matching request returns the same state. */
- (void)testPipelineStateUsesSuppliedLibraryAndIsCached
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLLibrary> library = self.frameworkLibrary;
	id<MTLRenderPipelineState> first = [item pipelineStateWithLibrary:library
														 vertexShader:@"fxGripOSCVertexShader"
													   fragmentShader:@"fxGripOSCFragmentShader"
													   constantValues:nil];
	XCTAssertNotNil(first);
	id<MTLRenderPipelineState> second = [item pipelineStateWithLibrary:library
														  vertexShader:@"fxGripOSCVertexShader"
														fragmentShader:@"fxGripOSCFragmentShader"
														constantValues:nil];
	XCTAssertTrue(first == second);
	XCTAssertEqual(item.pipelineStates.count, 1u);
}

/*! @abstract A pipeline state request naming a missing shader returns nil and caches nothing. */
- (void)testPipelineStateWithMissingFunctionIsNil
{
	FxGripMTLDeviceCacheItem *item = self.item;
	XCTAssertNil([item pipelineStateWithLibrary:self.frameworkLibrary
								   vertexShader:@"fxGripDoesNotExist"
								 fragmentShader:@"fxGripOSCFragmentShader"
								 constantValues:nil]);
	XCTAssertEqual(item.pipelineStates.count, 0u);
}

/*! @abstract Concurrent requests for the same pipeline state resolve to a single cached state. */
- (void)testConcurrentPipelineStateRequestsShareOneState
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLLibrary> library = self.frameworkLibrary;
	NSMutableSet *states = [NSMutableSet set];
	NSLock *lock = [[NSLock alloc] init];
	dispatch_apply(16, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
		id<MTLRenderPipelineState> state = [item pipelineStateWithLibrary:library
															vertexShader:@"fxGripOSCVertexShader"
														  fragmentShader:@"fxGripOSCFragmentShader"
														  constantValues:nil];
		[lock lock];
		[states addObject:[NSValue valueWithNonretainedObject:state]];
		[lock unlock];
	});
	XCTAssertEqual(states.count, 1u);
	XCTAssertEqual(item.pipelineStates.count, 1u);
}

/*! @abstract The item's depth stencil state is memoized, and the cache resolves a depth state by registry ID. */
- (void)testDepthStateIsMemoized
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLDepthStencilState> depth = item.depthState;
	XCTAssertNotNil(depth);
	XCTAssertTrue(depth == item.depthState);
	XCTAssertTrue([FxGripMTLDeviceCache.deviceCache depthStateWithRegistryID:self.device.registryID] != nil);
}

/*! @abstract A depth texture matches the width and height of the requested bounds with the depth pixel format, and a nil device yields no texture. */
- (void)testDepthTextureMatchesBounds
{
	FxRect bounds = { .left = 10, .bottom = 2, .right = 74, .top = 50 };
	id<MTLTexture> texture = [FxGripMTLDeviceCache depthTexture:bounds forDevice:self.device];
	XCTAssertEqual(texture.width, 64u);
	XCTAssertEqual(texture.height, 48u);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatDepth32Float);
	id<MTLDevice> noDevice = nil;
	XCTAssertNil([FxGripMTLDeviceCache depthTexture:bounds forDevice:noDevice]);
}

#pragma mark Device removal

/*! @abstract A device-removal notification drops the cached items, so a later lookup builds a fresh item. */
- (void)testDeviceRemovalDropsItemsWithoutThrowing
{
	FxGripMTLDeviceCacheItem *before = self.item;
	XCTAssertNotNil(before);
	XCTAssertNoThrow([NSNotificationCenter.defaultCenter postNotificationName:MTLDeviceRemovalRequestedNotification
																	  object:self.device]);
	FxGripMTLDeviceCacheItem *after = self.item;
	XCTAssertNotNil(after);
	XCTAssertFalse(before == after, @"the removed item was handed out again");
}

#pragma mark Pixel format for a tile

/*! @abstract Every supported IOSurface format maps to its Metal format, and an unrecognized one falls back to RGBA16Float. */
- (void)testPixelFormatForAnImageTileMapsEverySupportedSurfaceFormat
{
	NSArray<NSNumber *> *surfaceFormats = @[
		@(kCVPixelFormatType_32BGRA), @(kCVPixelFormatType_32RGBA), @(kCVPixelFormatType_64RGBALE),
		@(kCVPixelFormatType_64RGBAHalf), @(kCVPixelFormatType_128RGBAFloat),
	];
	NSArray<NSNumber *> *metalFormats = @[
		@(MTLPixelFormatBGRA8Unorm), @(MTLPixelFormatRGBA8Unorm), @(MTLPixelFormatRGBA16Unorm),
		@(MTLPixelFormatRGBA16Float), @(MTLPixelFormatRGBA32Float),
	];

	for (NSUInteger index = 0; index < surfaceFormats.count; index++) {
		FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
													 pixelFormat:surfaceFormats[index].unsignedIntValue
														  device:nil];
		XCTAssertEqual([FxGripMTLDeviceCache MTLPixelFormatForImageTile:tile],
					   (MTLPixelFormat)metalFormats[index].unsignedIntegerValue,
					   @"format %@", surfaceFormats[index]);
	}

	FxImageTile *surfaceless = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }];
	XCTAssertEqual([FxGripMTLDeviceCache MTLPixelFormatForImageTile:surfaceless], MTLPixelFormatRGBA16Float);
}

#pragma mark Command queues for a tile

/*! @abstract A tile checks out a pooled queue from the item keyed by its registry ID and surface format. */
- (void)testCommandQueueForAnImageTileUsesTheTilesDeviceAndFormat
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];

	id<MTLCommandQueue> queue = [FxGripMTLDeviceCache commandQueueForImageTile:tile pluginID:self.pluginID];

	FxGripMTLDeviceCacheItem *item = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
																			   pixelFormat:MTLPixelFormatBGRA8Unorm
																			   andPluginID:self.pluginID];
	XCTAssertNotNil(queue);
	XCTAssertEqual(queue.device, self.device);
	XCTAssertTrue([item containsCommandQueue:queue], @"the queue comes from the item keyed by the tile's format");
	XCTAssertTrue([self item:item marksQueueInUse:queue]);

	[FxGripMTLDeviceCache returnCommandQueue:queue];
	XCTAssertFalse([self item:item marksQueueInUse:queue]);
}

/*! @abstract The plugin-less command queue accessor keys the item by the default plugin ID. */
- (void)testCommandQueueForAnImageTileDefaultsThePluginID
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
												 pixelFormat:kCVPixelFormatType_64RGBAHalf
													  device:self.device];

	id<MTLCommandQueue> queue = [FxGripMTLDeviceCache commandQueueForImageTile:tile];

	FxGripMTLDeviceCacheItem *item = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
																			   pixelFormat:MTLPixelFormatRGBA16Float];
	XCTAssertNotNil(queue);
	XCTAssertNil(item.pluginID);
	XCTAssertTrue([item containsCommandQueue:queue]);
	[FxGripMTLDeviceCache returnCommandQueue:queue];
}

/*! @abstract A scoped command queue for a tile wraps a pooled queue and returns it when the wrapper is released. */
- (void)testScopedCommandQueueForAnImageTileReturnsItsQueueOnDealloc
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
												 pixelFormat:kCVPixelFormatType_32BGRA
													  device:self.device];
	FxGripMTLDeviceCacheItem *item = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID
																			   pixelFormat:MTLPixelFormatBGRA8Unorm
																			   andPluginID:self.pluginID];
	id<MTLCommandQueue> wrapped = nil;
	@autoreleasepool {
		FxGripMTLCommandQueue *scoped = [FxGripMTLDeviceCache scopedCommandQueueForImageTile:tile pluginID:self.pluginID];
		XCTAssertNotNil(scoped);
		wrapped = scoped.queue;
		XCTAssertTrue([self item:item marksQueueInUse:wrapped]);
	}

	XCTAssertFalse([self item:item marksQueueInUse:wrapped], @"the wrapper returns its queue to the pool");
}

/*! @abstract The plugin-less scoped accessor keys the item by the default plugin ID. */
- (void)testScopedCommandQueueForAnImageTileDefaultsThePluginID
{
	FxImageTile *tile = [FxImageTile stubTileWithPixelBounds:(FxRect){ 0, 0, 8, 8 }
												 pixelFormat:kCVPixelFormatType_64RGBAHalf
													  device:self.device];

	@autoreleasepool {
		FxGripMTLCommandQueue *scoped = [FxGripMTLDeviceCache scopedCommandQueueForImageTile:tile];
		XCTAssertNotNil(scoped);
		XCTAssertEqual(scoped.device, self.device);
	}
}

#pragma mark Command queue forwarding

/*! @abstract Every MTLCommandQueue message on the wrapper reaches the pooled queue. */
- (void)testTheScopedQueueForwardsEveryCommandQueueMessage
{
	FxGripMTLCommandQueue *scoped = [FxGripMTLCommandQueue.alloc initWithDeviceCacheItem:self.item];
	XCTAssertNotNil(scoped);

	scoped.label = @"FxGripScopedQueue";
	XCTAssertEqualObjects(scoped.label, @"FxGripScopedQueue");
	XCTAssertEqualObjects(scoped.queue.label, @"FxGripScopedQueue");
	XCTAssertEqual(scoped.device, self.device);

	XCTAssertNotNil([scoped commandBuffer]);
	MTLCommandBufferDescriptor *descriptor = MTLCommandBufferDescriptor.new;
	XCTAssertNotNil([scoped commandBufferWithDescriptor:descriptor]);
	XCTAssertNotNil([scoped commandBufferWithUnretainedReferences]);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	XCTAssertNoThrow([scoped insertDebugCaptureBoundary]);
#pragma clang diagnostic pop

	if (@available(macOS 15.0, *)) {
		MTLResidencySetDescriptor *residencyDescriptor = MTLResidencySetDescriptor.new;
		NSError *error = nil;
		id<MTLResidencySet> residencySet = [self.device newResidencySetWithDescriptor:residencyDescriptor error:&error];
		XCTAssertNotNil(residencySet, @"%@", error);
		id<MTLResidencySet> sets[1] = { residencySet };

		XCTAssertNoThrow([scoped addResidencySet:residencySet]);
		XCTAssertNoThrow([scoped removeResidencySet:residencySet]);
		XCTAssertNoThrow([scoped addResidencySets:sets count:1]);
		XCTAssertNoThrow([scoped removeResidencySets:sets count:1]);
	}
}

#pragma mark Device notifications

/*! @abstract A device-added notification installs a default cache item for the device. */
- (void)testDeviceAddedNotificationInstallsADefaultItem
{
	NSUInteger before = [self cachedItems].count;

	[NSNotificationCenter.defaultCenter postNotificationName:MTLDeviceWasAddedNotification object:self.device];

	NSArray<FxGripMTLDeviceCacheItem *> *items = [self cachedItems];
	XCTAssertEqual(items.count, before + 1);
	XCTAssertEqual(items.lastObject.gpuDevice.registryID, self.device.registryID);
	XCTAssertEqual(items.lastObject.pixelFormat, MTLPixelFormatRGBA16Float);
	XCTAssertNil(items.lastObject.pluginID);
}

/*! @abstract A device-added notification carrying no device installs nothing. */
- (void)testDeviceAddedNotificationWithoutADeviceInstallsNothing
{
	NSUInteger before = [self cachedItems].count;

	[NSNotificationCenter.defaultCenter postNotificationName:MTLDeviceWasAddedNotification object:nil];

	XCTAssertEqual([self cachedItems].count, before);
}

/*! @abstract The device-was-removed notification is accepted and changes nothing; the removal request does the dropping. */
- (void)testDeviceWasRemovedNotificationKeepsTheCache
{
	FxGripMTLDeviceCacheItem *item = self.item;

	[NSNotificationCenter.defaultCenter postNotificationName:MTLDeviceWasRemovedNotification object:self.device];

	XCTAssertTrue([[self cachedItems] containsObject:item]);
}

#pragma mark Library cache for a device

/*! @abstract The library cache for a device is memoized, so the same cache answers a repeat lookup. */
- (void)testLibraryCacheForADeviceIsMemoized
{
	FxGripMTLLibraryCache *first = [FxGripMTLDeviceCache libraryCacheForDevice:self.device];
	FxGripMTLLibraryCache *second = [FxGripMTLDeviceCache libraryCacheForDevice:self.device];
	FxGripMTLLibraryCache *byRegistryID = [FxGripMTLDeviceCache libraryCacheForRegistryID:self.device.registryID];

	XCTAssertEqual(first, second, @"one library cache is kept per device");
	XCTAssertEqual(first, byRegistryID);
	// A device whose default library is unavailable in the test process caches nothing;
	// the memoization above holds either way.
	if (first != nil) {
		XCTAssertNotNil(first.library);
		XCTAssertEqual(first.device.registryID, self.device.registryID);
	}
}

#pragma mark Library cache pass-through

/*! @abstract The library cache forwards label, type, and install name to the wrapped library. */
- (void)testLibraryCacheForwardsTheLibraryProperties
{
	id<MTLLibrary> library = self.frameworkLibrary;
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:library];

	cache.label = @"FxGripCachedLibrary";

	XCTAssertEqualObjects(cache.label, @"FxGripCachedLibrary");
	XCTAssertEqualObjects(library.label, @"FxGripCachedLibrary");
	XCTAssertEqual(cache.type, library.type);
	XCTAssertEqualObjects(cache.installName, library.installName);
}

/*! @abstract The constant-values function accessor memoizes its result and reports an unknown name as an error. */
- (void)testConstantValuesFunctionIsMemoizedAndReportsAMissingName
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	NSString *name = [self firstFunctionNameIn:cache];
	NSError *error = nil;

	id<MTLFunction> first = [cache newFunctionWithName:name constantValues:nil error:&error];
	id<MTLFunction> second = [cache newFunctionWithName:name constantValues:nil error:&error];

	XCTAssertNotNil(first, @"%@", error);
	XCTAssertTrue(first == second, @"the function is served from the cache on the second request");
	XCTAssertEqual(cache.functionCache.count, 1u);

	NSError *missingError = nil;
	XCTAssertNil([cache newFunctionWithName:@"fxGripDoesNotExist" constantValues:nil error:&missingError]);
	XCTAssertNotNil(missingError);
	XCTAssertEqual(cache.functionCache.count, 1u);
}

/*! @abstract The descriptor function accessor memoizes by name and serves a later descriptor request from the cache. */
- (void)testDescriptorFunctionIsMemoizedAcrossBothAccessors
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	NSString *name = [self firstFunctionNameIn:cache];
	MTLFunctionDescriptor *descriptor = MTLFunctionDescriptor.functionDescriptor;
	descriptor.name = name;
	NSError *error = nil;

	id<MTLFunction> first = [cache newFunctionWithDescriptor:descriptor error:&error];
	id<MTLFunction> second = [cache newFunctionWithDescriptor:descriptor error:&error];
	XCTAssertNotNil(first, @"%@", error);
	XCTAssertTrue(first == second);

	XCTestExpectation *cached = [self expectationWithDescription:@"cached descriptor load"];
	[cache newFunctionWithDescriptor:descriptor completionHandler:^(id<MTLFunction> function, NSError *handlerError) {
		XCTAssertTrue(function == first, @"a cached name answers its handler without recompiling");
		XCTAssertNil(handlerError);
		[cached fulfill];
	}];
	[self waitForExpectations:@[cached] timeout:5.0];
}

/*! @abstract An intersection-function request for a name the library does not declare reports an error and caches nothing. */
- (void)testIntersectionFunctionForAMissingNameReportsAnError
{
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:self.frameworkLibrary];
	MTLIntersectionFunctionDescriptor *descriptor = MTLIntersectionFunctionDescriptor.new;
	descriptor.name = @"fxGripDoesNotIntersect";
	NSError *error = nil;

	XCTAssertNil([cache newIntersectionFunctionWithDescriptor:descriptor error:&error]);
	XCTAssertNotNil(error);
	XCTAssertEqual(cache.functionCache.count, 0u);

	XCTestExpectation *done = [self expectationWithDescription:@"async intersection load"];
	[cache newIntersectionFunctionWithDescriptor:descriptor completionHandler:^(id<MTLFunction> function, NSError *handlerError) {
		XCTAssertNil(function);
		XCTAssertNotNil(handlerError);
		[done fulfill];
	}];
	[self waitForExpectations:@[done] timeout:10.0];
	XCTAssertEqual(cache.functionCache.count, 0u);
}

#pragma mark Library cache conformance

/*! @abstract The library cache answers reflection for a function exactly as the wrapped library does. */
- (void)testTheLibraryCacheAnswersReflectionLikeTheWrappedLibrary
{
	if (@available(macOS 26.0, *)) {
		id<MTLLibrary> library = self.frameworkLibrary;
		XCTSkipIf(library == nil, @"No Metal device.");
		FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:library];
		NSString *name = library.functionNames.firstObject;
		XCTAssertNotNil(name);

		MTLFunctionReflection *expected = [library reflectionForFunctionWithName:name];
		MTLFunctionReflection *reflection = [cache reflectionForFunctionWithName:name];

		XCTAssertEqual(reflection == nil, expected == nil);
		XCTAssertEqual(reflection.bindings.count, expected.bindings.count);
		XCTAssertNil([cache reflectionForFunctionWithName:@"fxgNoSuchFunction"]);
	} else {
		XCTSkip(@"reflectionForFunctionWithName: requires macOS 26.");
	}
}

/*! @abstract A member the library cache does not implement reaches the wrapped library. */
- (void)testAnUnimplementedMemberIsForwardedToTheWrappedLibrary
{
	id<MTLLibrary> library = self.frameworkLibrary;
	XCTSkipIf(library == nil, @"No Metal device.");
	FxGripExtraMemberLibrary *wrapped = [FxGripExtraMemberLibrary.alloc init];
	wrapped.target = library;
	FxGripMTLLibraryCache *cache = [[FxGripMTLLibraryCache alloc] initWithLibrary:(id<MTLLibrary>)wrapped];

	XCTAssertTrue([cache respondsToSelector:@selector(fxgExtraLibraryMember)]);
	XCTAssertEqualObjects([(id)cache fxgExtraLibraryMember], @"forwarded");
	XCTAssertFalse([cache respondsToSelector:NSSelectorFromString(@"fxgNoLibraryMember")]);
	XCTAssertTrue([cache respondsToSelector:@selector(functionNames)], @"implemented members still answer");
}

/*! @abstract The library cache implements every required MTLLibrary member itself, so none depends on forwarding. */
- (void)testTheLibraryCacheImplementsEveryRequiredLibraryMember
{
	unsigned int count = 0;
	struct objc_method_description *required = protocol_copyMethodDescriptionList(@protocol(MTLLibrary), YES, YES, &count);
	NSMutableArray<NSString *> *missing = NSMutableArray.new;
	for (unsigned int index = 0; index < count; index++) {
		if (!class_getInstanceMethod(FxGripMTLLibraryCache.class, required[index].name)) {
			[missing addObject:NSStringFromSelector(required[index].name)];
		}
	}
	free(required);

	XCTAssertEqualObjects(missing, @[], @"a newer SDK added required MTLLibrary members");
}

#pragma mark Cache item

/*! @abstract A cache item refuses to build without a device. */
- (void)testCacheItemWithoutADeviceIsNil
{
	id<MTLDevice> noDevice = nil;
	XCTAssertNil([[FxGripMTLDeviceCacheItem alloc] initWithDevice:noDevice
													 pixelFormat:MTLPixelFormatRGBA16Float
													 andPluginID:self.pluginID]);
}

/*! @abstract The item's default library and its library cache are memoized together. */
- (void)testTheItemMemoizesItsDefaultLibraryAndCache
{
	FxGripMTLDeviceCacheItem *item = self.item;

	id<MTLLibrary> library = item.defaultLibrary;
	FxGripMTLLibraryCache *cache = item.defaultLibraryCache;

	XCTAssertEqual(item.defaultLibrary, library);
	XCTAssertEqual(item.defaultLibraryCache, cache);
	// The test process has no main-bundle default library, so both resolve to nil there.
	XCTAssertEqual(cache != nil, library != nil, @"the library cache exists exactly when the library does");
}

/*! @abstract The item reports the device's texture limits. */
- (void)testTheItemReportsItsTextureLimits
{
	FxGripMTLDeviceCacheItem *item = self.item;
	BOOL isEarlyAppleGPU = [self.device supportsFamily:MTLGPUFamilyApple1] || [self.device supportsFamily:MTLGPUFamilyApple2];
	unsigned int expectedWidth = isEarlyAppleGPU ? 8192 : 16384;

	XCTAssertEqual(item.max1DTextureWidth, expectedWidth);
	XCTAssertEqual(item.max2DTextureWidth, expectedWidth);
	XCTAssertEqual(item.maxCubeMapTextureWidth, expectedWidth);
	XCTAssertEqual(item.max3DTextureWidth, 2048u);
	XCTAssertEqual(item.maxTexturePixels, expectedWidth * expectedWidth);
}

/*! @abstract The item's depth texture matches the requested bounds. */
- (void)testTheItemBuildsADepthTextureForBounds
{
	FxGripMTLDeviceCacheItem *item = self.item;

	id<MTLTexture> texture = [item depthTexture:(FxRect){ .left = 4, .bottom = 6, .right = 36, .top = 22 }];

	XCTAssertEqual(texture.width, 32u);
	XCTAssertEqual(texture.height, 16u);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatDepth32Float);
}

#pragma mark Pipeline state variants

/*! @abstract The shader-name convenience accessors resolve through the item's own default library, which the test process lacks. */
- (void)testTheShaderNameAccessorsUseTheItemsDefaultLibrary
{
	FxGripMTLDeviceCacheItem *item = self.item;
	XCTAssertNil(item.defaultLibraryCache, @"the test process has no main-bundle default library");

	XCTAssertNil([item pipelineStateWithVertexShader:@"fxGripOSCVertexShader" fragmentShader:@"fxGripOSCFragmentShader"]);
	XCTAssertNil([item pipelineStateWithVertexShader:@"fxGripOSCVertexShader"
									  fragmentShader:@"fxGripOSCFragmentShader"
									  constantValues:MTLFunctionConstantValues.new]);
	XCTAssertNil([item pipelineStateWithVertexShader:@"fxGripOSCVertexShader"
									  fragmentShader:@"fxGripOSCFragmentShader"
									  constantValues:nil
								   specializedFormat:@"%@_srgb"]);
	XCTAssertEqual(item.pipelineStates.count, 0u);
}

/*! @abstract A specialized format renames both functions, so the specialized pair caches apart from the plain pair. */
- (void)testASpecializedFormatRenamesBothFunctions
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLLibrary> library = self.frameworkLibrary;

	id<MTLRenderPipelineState> specialized = [item pipelineStateWithLibrary:library
															  vertexShader:@"fxGripOSCVertexShader"
															fragmentShader:@"fxGripOSCFragmentShader"
															constantValues:MTLFunctionConstantValues.new
														 specializedFormat:@"%@_fxGripSpecialized"];
	id<MTLRenderPipelineState> plain = [item pipelineStateWithLibrary:library
														vertexShader:@"fxGripOSCVertexShader"
													  fragmentShader:@"fxGripOSCFragmentShader"
													  constantValues:nil];

	XCTAssertNotNil(specialized);
	XCTAssertNotNil(plain);
	XCTAssertFalse(specialized == plain, @"the specialized names key their own cache entry");
	XCTAssertEqual(item.pipelineStates.count, 2u);
	XCTAssertNotNil(item.pipelineStates[@"fxGripOSCVertexShader_fxGripSpecialized:fxGripOSCFragmentShader_fxGripSpecialized"]);
}

/*! @abstract A pipeline state built from function descriptors is cached under the descriptor names. */
- (void)testAPipelineStateFromDescriptorsIsCachedByName
{
	FxGripMTLDeviceCacheItem *item = self.item;
	MTLFunctionDescriptor *vertexDescriptor = MTLFunctionDescriptor.functionDescriptor;
	MTLFunctionDescriptor *fragmentDescriptor = MTLFunctionDescriptor.functionDescriptor;
	vertexDescriptor.name = @"fxGripOSCVertexShader";
	fragmentDescriptor.name = @"fxGripOSCFragmentShader";

	id<MTLRenderPipelineState> viaDefaultLibrary = [item pipelineStateWithVertexDescriptor:vertexDescriptor
																	   fragmentDescriptor:fragmentDescriptor];
	id<MTLRenderPipelineState> first = [item pipelineStateWithLibrary:self.frameworkLibrary
													vertexDescriptor:vertexDescriptor
												  fragmentDescriptor:fragmentDescriptor];
	id<MTLRenderPipelineState> second = [item pipelineStateWithLibrary:self.frameworkLibrary
													 vertexDescriptor:vertexDescriptor
												   fragmentDescriptor:fragmentDescriptor];

	XCTAssertNil(viaDefaultLibrary, @"the test process has no main-bundle default library");
	XCTAssertNotNil(first);
	XCTAssertTrue(first == second);
	XCTAssertEqual(item.pipelineStates.count, 1u);
}

/*! @abstract A descriptor with no function name yields no pipeline state. */
- (void)testAPipelineStateFromANamelessDescriptorIsNil
{
	FxGripMTLDeviceCacheItem *item = self.item;
	MTLFunctionDescriptor *named = MTLFunctionDescriptor.functionDescriptor;
	named.name = @"fxGripOSCVertexShader";

	XCTAssertNil([item pipelineStateWithLibrary:self.frameworkLibrary
							   vertexDescriptor:MTLFunctionDescriptor.functionDescriptor
							 fragmentDescriptor:named]);
	XCTAssertNil([item pipelineStateWithLibrary:self.frameworkLibrary
							   vertexDescriptor:named
							 fragmentDescriptor:MTLFunctionDescriptor.functionDescriptor]);
	XCTAssertEqual(item.pipelineStates.count, 0u);
}


@end
