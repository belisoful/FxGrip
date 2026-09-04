//
//  FxGripMTLDeviceCacheTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
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

- (id<MTLLibrary>)frameworkLibrary
{
	NSError *error = nil;
	id<MTLLibrary> library = [self.device newDefaultLibraryWithBundle:[NSBundle bundleForClass:FxGripMTLDeviceCache.class]
															   error:&error];
	XCTAssertNotNil(library, @"%@", error);
	return library;
}

#pragma mark Legacy names

- (void)testNoGuruSelectorsRemain
{
	XCTAssertNil(NSClassFromString(@"GuruMTLCommandQueue"));
	XCTAssertNotNil(NSClassFromString(@"FxGripMTLCommandQueue"));
	XCTAssertFalse([FxGripMTLDeviceCache respondsToSelector:NSSelectorFromString(@"guruCommandQueueForImageTile:")]);
	XCTAssertTrue([FxGripMTLDeviceCache respondsToSelector:@selector(scopedCommandQueueForImageTile:)]);
	XCTAssertTrue([FxGripMTLDeviceCache respondsToSelector:@selector(scopedCommandQueueForImageTile:pluginID:)]);
}

#pragma mark Cache lookup

- (void)testDeviceCacheIsSingleton
{
	XCTAssertTrue(FxGripMTLDeviceCache.deviceCache == FxGripMTLDeviceCache.deviceCache);
}

- (void)testDeviceWithRegistryIDReturnsSystemDevice
{
	FxGripMTLDeviceCacheItem *item = [FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:self.device.registryID];
	XCTAssertNotNil(item);
	XCTAssertEqual(item.registryID, self.device.registryID);
	XCTAssertEqual(item.gpuDevice.registryID, self.device.registryID);
	XCTAssertEqual(item.pixelFormat, MTLPixelFormatRGBA16Float);
	XCTAssertNil(item.pluginID);
}

- (void)testUnknownRegistryIDReturnsNil
{
	XCTAssertNil([FxGripMTLDeviceCache.deviceCache deviceWithRegistryID:0xFFFFFFFFFFFFFFFFull]);
	XCTAssertNil([FxGripMTLDeviceCache metalDeviceFromID:0xFFFFFFFFFFFFFFFFull]);
}

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

- (void)testScopedCommandQueueWithNilItemIsNil
{
	XCTAssertNil([[FxGripMTLCommandQueue alloc] initWithDeviceCacheItem:nil]);
}

#pragma mark Library cache

- (void)testLibraryCacheForNilDeviceIsNil
{
	XCTAssertNil([FxGripMTLDeviceCache libraryCacheForDevice:nil]);
	XCTAssertNil([FxGripMTLDeviceCache libraryCacheForRegistryID:0xFFFFFFFFFFFFFFFFull]);
}

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

- (void)testLibraryCacheInitWithNilIsNil
{
	XCTAssertNil([[FxGripMTLLibraryCache alloc] initWithLibrary:nil]);
	XCTAssertNil([[FxGripMTLLibraryCache alloc] initWithDevice:nil]);
}


#pragma mark Asynchronous function loading

- (NSString *)firstFunctionNameIn:(id<MTLLibrary>)library
{
	NSString *name = library.functionNames.firstObject;
	XCTAssertNotNil(name, @"the FxGrip shader library has no functions");
	return name;
}

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

- (void)testPipelineStateWithMissingFunctionIsNil
{
	FxGripMTLDeviceCacheItem *item = self.item;
	XCTAssertNil([item pipelineStateWithLibrary:self.frameworkLibrary
								   vertexShader:@"fxGripDoesNotExist"
								 fragmentShader:@"fxGripOSCFragmentShader"
								 constantValues:nil]);
	XCTAssertEqual(item.pipelineStates.count, 0u);
}

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

- (void)testDepthStateIsMemoized
{
	FxGripMTLDeviceCacheItem *item = self.item;
	id<MTLDepthStencilState> depth = item.depthState;
	XCTAssertNotNil(depth);
	XCTAssertTrue(depth == item.depthState);
	XCTAssertTrue([FxGripMTLDeviceCache.deviceCache depthStateWithRegistryID:self.device.registryID] != nil);
}

- (void)testDepthTextureMatchesBounds
{
	FxRect bounds = { .left = 10, .bottom = 2, .right = 74, .top = 50 };
	id<MTLTexture> texture = [FxGripMTLDeviceCache depthTexture:bounds forDevice:self.device];
	XCTAssertEqual(texture.width, 64u);
	XCTAssertEqual(texture.height, 48u);
	XCTAssertEqual(texture.pixelFormat, MTLPixelFormatDepth32Float);
	XCTAssertNil([FxGripMTLDeviceCache depthTexture:bounds forDevice:nil]);
}

#pragma mark Device removal

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

@end
