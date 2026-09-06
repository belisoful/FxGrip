/*!
	@file       FxGripMTLDeviceCache.m
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMTLDeviceCache
	@abstract   Implements the process-wide Metal device, queue, pipeline, and library cache.
	@discussion Introduced in FxGrip 0.1.0. The cache observes Metal device add and remove
	            notifications to keep its item list current. A lookup holds the cache lock across
	            find and insert, so concurrent misses create one item. Each cache item pools
	            command queues and caches pipeline states. FxGripMTLLibraryCache memoizes functions
	            and coalesces concurrent asynchronous compiles of the same name.
*/

#import <IOSurface/IOSurfaceObjC.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripMTLDeviceCache.h"
#import "FxGrip_ARC.h"


#pragma mark -
#pragma mark FxGripMTLDeviceCache Implementation

#define kFxGripMTLDeviceDefaultPixelFormat MTLPixelFormatRGBA16Float

/*!
	@abstract	The process-wide cache of Metal devices, queues, pipeline states, and libraries.
	@discussion	Introduced in FxGrip 0.1.0. Items are keyed by device registry ID, pixel format,
				and plugin ID, and every method is safe to call from concurrent render threads.
*/
@implementation FxGripMTLDeviceCache

/*! @abstract The Metal pixel format for a tile's IOSurface; RGBA16Float for an unexpected format. */
+ (MTLPixelFormat)MTLPixelFormatForImageTile:(FxImageTile*)imageTile
{
	MTLPixelFormat  result  = MTLPixelFormatRGBA16Float;

	switch (imageTile.ioSurface.pixelFormat)
	{
		case kCVPixelFormatType_32BGRA:
			result = MTLPixelFormatBGRA8Unorm;
			break;

		case kCVPixelFormatType_32RGBA:
			result = MTLPixelFormatRGBA8Unorm;
			break;

		case kCVPixelFormatType_64RGBALE:
			result = MTLPixelFormatRGBA16Unorm;
			break;

		case kCVPixelFormatType_64RGBAHalf: // Most Common Case
			result = MTLPixelFormatRGBA16Float;
			break;

		case kCVPixelFormatType_128RGBAFloat:
			result = MTLPixelFormatRGBA32Float;
			break;

		default:
			NSLog (@"Got an unexpected pixel format in the IOSurface: %c%c%c%c",
				   (imageTile.ioSurface.pixelFormat >> 24) & 0x000000FF,
				   (imageTile.ioSurface.pixelFormat >> 16) & 0x000000FF,
				   (imageTile.ioSurface.pixelFormat >> 8) & 0x000000FF,
				   (imageTile.ioSurface.pixelFormat & 0x000000FF));
			break;
	}

	return result;
}

+ (BOOL)isSingleton
{
	return YES;
}

+ (FxGripMTLDeviceCache*)deviceCache;
{
	return self.__BESingleton;
}


+ (FxGripMTLLibraryCache*)libraryCacheForDevice:(nullable id<MTLDevice>)device
{
	return [self.deviceCache libraryCacheForDevice:device];
}

+ (FxGripMTLLibraryCache*)libraryCacheForRegistryID:(uint64_t)registryID
{
	return [self libraryCacheForDevice:[self metalDeviceFromID:registryID]];
}


+ (FxGripMTLCommandQueue*)scopedCommandQueueForImageTile:(FxImageTile*)imageTile
{
	return [self scopedCommandQueueForImageTile:imageTile pluginID:nil];
}

+ (FxGripMTLCommandQueue*)scopedCommandQueueForImageTile:(FxImageTile*)imageTile pluginID:(nullable NSString *)pluginID
{
	MTLPixelFormat pixelFormat = [self MTLPixelFormatForImageTile:imageTile];
	FxGripMTLDeviceCacheItem *device = [self.deviceCache deviceWithRegistryID:imageTile.deviceRegistryID pixelFormat:pixelFormat andPluginID:pluginID];
	return NARC_AUTORELEASE([FxGripMTLCommandQueue.alloc initWithDeviceCacheItem:device]);
}

+ (id<MTLCommandQueue>)commandQueueForImageTile:(FxImageTile*)imageTile {
	return [self commandQueueForImageTile:imageTile pluginID:nil];
}

+ (id<MTLCommandQueue>)commandQueueForImageTile:(FxImageTile*)imageTile pluginID:(NSString*)pluginID
{
	MTLPixelFormat pixelFormat = [self MTLPixelFormatForImageTile:imageTile];
	FxGripMTLDeviceCacheItem *device = [self.deviceCache deviceWithRegistryID:imageTile.deviceRegistryID pixelFormat:pixelFormat andPluginID:pluginID];
	return [device getNextFreeCommandQueue];
}


+ (void)returnCommandQueue:(id<MTLCommandQueue>)commandQueue
{
	[self.deviceCache returnCommandQueueToCache:commandQueue];
}

/*! @abstract The MTLDevice among all Metal devices whose registry ID matches; nil when none does. */
+ (id<MTLDevice>)metalDeviceFromID:(uint64_t)registryID
{
	id<MTLDevice>   device  = nil;

	NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
	for (id<MTLDevice> nextDevice in devices)
	{
		if (nextDevice.registryID == registryID)
		{
			device = NARC_RETAIN(nextDevice);
			break;
		}
	}
	NARC_RELEASE(devices);

	return NARC_RETAIN_AUTORELEASE(device);
}


/*! @abstract A private-storage Depth32Float texture sized to bounds; nil for a nil device. */
+ (id<MTLTexture>)depthTexture:(FxRect)bounds forDevice:(id<MTLDevice>)device
{
	if (!device) {
		return nil;
	}
	id<MTLTexture>  result  = nil;

	MTLTextureDescriptor*   depthTexDesc    = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
																								 width:bounds.right - bounds.left
																								height:bounds.top - bounds.bottom
																							 mipmapped:NO];
	depthTexDesc.storageMode = MTLStorageModePrivate;
	result = NARC_RETAIN_AUTORELEASE([device newTextureWithDescriptor:depthTexDesc]);

	return result;
}


/*! @abstract Builds a cache item for every current Metal device and registers for device add and remove notifications. */
- (instancetype)init
{
	self = [super init];

	if (self != nil)
	{
		MTLDeviceNotificationHandler notificationHandler = ^(id<MTLDevice> device, MTLDeviceNotificationName name)
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:name object:device];
		};

		NSArray<id<MTLDevice>>* devices = MTLCopyAllDevicesWithObserver(&_metalDeviceObserver, notificationHandler);

		_deviceCachesLock = [[NSLock alloc] init];
		_deviceCachesLock.name = @"FxGripMTLDeviceCache";
		_deviceDefaultLibraries = [NSMutableDictionary.alloc initWithCapacity:devices.count];
		_deviceCaches = [[NSMutableArray alloc] initWithCapacity:devices.count];

		for (id<MTLDevice> nextDevice in devices)
		{
			FxGripMTLDeviceCacheItem*  newCacheItem    = NARC_AUTORELEASE([[FxGripMTLDeviceCacheItem alloc] initWithDevice:nextDevice
																						pixelFormat:kFxGripMTLDeviceDefaultPixelFormat
																						andPluginID:kDefaultPluginID]);
			if (newCacheItem) {
				[_deviceCaches addObject:newCacheItem];
			}
		}
		NARC_RELEASE(devices);

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(observeDeviceAdded:)
														 name:MTLDeviceWasAddedNotification
													   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(observeDeviceRemovalRequested:)
														 name:MTLDeviceRemovalRequestedNotification
													   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(observeDeviceRemovedRequested:)
														 name:MTLDeviceWasRemovedNotification
													   object:nil];
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	MTLRemoveDeviceObserver(_metalDeviceObserver);
	_metalDeviceObserver = nil;

	NARC_RELEASE(_deviceDefaultLibraries);
	NARC_RELEASE(_deviceCaches);
	NARC_RELEASE(_deviceCachesLock);

	SUPER_DEALLOC();
}

- (FxGripMTLLibraryCache*)libraryCacheForDevice:(nullable id<MTLDevice>)device
{
	if (!device) {
		return nil;
	}
	NSNumber *key = @(device.registryID);
	[_deviceCachesLock lock];
	FxGripMTLLibraryCache *cache = [_deviceDefaultLibraries objectForKey:key];
	if (!cache) {
		cache = NARC_AUTORELEASE([FxGripMTLLibraryCache.alloc initWithDevice:device]);
		if (cache) {
			[_deviceDefaultLibraries setObject:cache forKey:key];
		}
	}
	[_deviceCachesLock unlock];
	return cache;
}

/*! @abstract Adds a default cache item for a newly added Metal device. */
- (void)observeDeviceAdded:(NSNotification*)notification
{
	FxGripMTLDeviceCacheItem*  newCacheItem    = NARC_AUTORELEASE([[FxGripMTLDeviceCacheItem alloc] initWithDevice:notification.object
																					  pixelFormat:kFxGripMTLDeviceDefaultPixelFormat
																					  andPluginID:kDefaultPluginID]);
	if (!newCacheItem) {
		return;
	}
	[_deviceCachesLock lock];
	[_deviceCaches addObject:newCacheItem];
	[_deviceCachesLock unlock];
}

/*! @abstract Drops every cache item and library for a device Metal reports removed. */
- (void)observeDeviceRemovalRequested:(NSNotification*)notification
{
	uint64_t registryID = ((id<MTLDevice>)notification.object).registryID;
	NSNumber *key = @(registryID);

	[_deviceCachesLock lock];
	[_deviceDefaultLibraries removeObjectForKey:key];

	NSIndexSet *removed = [_deviceCaches indexesOfObjectsPassingTest:^BOOL(FxGripMTLDeviceCacheItem *item, NSUInteger idx, BOOL *stop) {
		return item.gpuDevice.registryID == registryID;
	}];
	[_deviceCaches removeObjectsAtIndexes:removed];
	[_deviceCachesLock unlock];
}

- (void)observeDeviceRemovedRequested:(NSNotification*)notification
{
}

- (FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
{
	return [self deviceWithRegistryID:registryID pixelFormat:kFxGripMTLDeviceDefaultPixelFormat andPluginID:kDefaultPluginID];
}

- (FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
								  pixelFormat:(MTLPixelFormat)pixFormat
{
	return [self deviceWithRegistryID:registryID pixelFormat:pixFormat andPluginID:kDefaultPluginID];
}

/*! @abstract YES when an item matches the registry ID, pixel format (or any), and plugin ID. */
- (BOOL)cacheItem:(FxGripMTLDeviceCacheItem*)item matchesRegistryID:(uint64_t)registryID pixelFormat:(MTLPixelFormat)pixFormat pluginID:(NSString*)pluginID
{
	if (item.gpuDevice.registryID != registryID) {
		return NO;
	}
	if (pixFormat != FxGripMTLPixelFormatAny && item.pixelFormat != pixFormat) {
		return NO;
	}
	if (pluginID == kDefaultPluginID) {
		return item.pluginID == kDefaultPluginID;
	}
	return item.pluginID != nil && [pluginID isEqualToString:item.pluginID];
}

/*!
	@method		deviceWithRegistryID:pixelFormat:andPluginID:
	@abstract	The matching cache item, created and inserted when absent.
	@discussion	Introduced in FxGrip 0.1.0. The lock spans lookup and insertion so concurrent
				misses create one item. Returns nil when no Metal device matches the registry ID. */
- (FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
								  pixelFormat:(MTLPixelFormat)pixFormat
								  andPluginID:(NSString*)pluginID
{
	// The lock spans lookup and insertion so concurrent misses create one item, not one per thread.
	[_deviceCachesLock lock];
	FxGripMTLDeviceCacheItem *result = nil;
	for (FxGripMTLDeviceCacheItem* nextCacheItem in _deviceCaches)
	{
		if ([self cacheItem:nextCacheItem matchesRegistryID:registryID pixelFormat:pixFormat pluginID:pluginID]) {
			result = nextCacheItem;
			break;
		}
	}
	if (!result) {
		id<MTLDevice> device = [self.class metalDeviceFromID:registryID];
		if (device) {
			result = NARC_AUTORELEASE([[FxGripMTLDeviceCacheItem alloc] initWithDevice:device
																		 pixelFormat:pixFormat
																		 andPluginID:pluginID]);
		}
		if (result) {
			[_deviceCaches addObject:result];
		}
	}
	[_deviceCachesLock unlock];

	return NARC_RETAIN_AUTORELEASE(result);
}


- (id<MTLDepthStencilState>)depthStateWithRegistryID:(uint64_t)registryID
{
	FxGripMTLDeviceCacheItem* deviceCacheItem = [self deviceWithRegistryID:registryID];

	return deviceCacheItem.depthState;
}


/*! @abstract Returns a pooled command queue to whichever cache item owns it. */
- (void)returnCommandQueueToCache:(id<MTLCommandQueue>)commandQueue;
{
	if (!commandQueue) {
		return;
	}
	[_deviceCachesLock lock];
	for (FxGripMTLDeviceCacheItem* nextCacheItem in _deviceCaches)
	{
		if ([nextCacheItem containsCommandQueue:commandQueue])
		{
			[nextCacheItem returnCommandQueue:commandQueue];
			break;
		}
	}
	[_deviceCachesLock unlock];
}

@end


#pragma mark -
#pragma mark FxGripMTLCommandQueue Implementation

/*!
	@abstract	An MTLCommandQueue pass-through that returns its queue to the cache item on dealloc.
	@discussion	Introduced in FxGrip 0.1.0. Every MTLCommandQueue method forwards to the wrapped
				queue.
*/
@implementation FxGripMTLCommandQueue

@synthesize queue = _queue;
@synthesize label = _label;


/*! @abstract Checks a command queue out of the cache item; nil when the item has no queue to give. */
- (instancetype)initWithDeviceCacheItem:(nullable FxGripMTLDeviceCacheItem*)deviceCacheItem
{
	id<MTLCommandQueue> queue = [deviceCacheItem getNextFreeCommandQueue];
	if (!queue) {
		NARC_RELEASE(self);
		return nil;
	}
	self = [super init];
	if (self) {
		_deviceCacheItem = NARC_RETAIN(deviceCacheItem);
		_queue = NARC_RETAIN(queue);
	} else {
		[deviceCacheItem returnCommandQueue:queue];
	}
	return self;
}



/*! @abstract Returns the wrapped queue to its cache item. */
- (void)dealloc {
	[_deviceCacheItem returnCommandQueue:_queue];
	NARC_RELEASE(_queue);
	NARC_RELEASE(_deviceCacheItem);

	SUPER_DEALLOC();
}

#pragma mark MTLCommandQueue implementation

- (NSString *)label {
	return [_queue label];
}

- (void)setLabel:(NSString *)label {
	[_queue setLabel:label];
}

- (id<MTLDevice>)device {
	return [_queue device];
}

- (nullable id <MTLCommandBuffer>)commandBuffer
{
	return [_queue commandBuffer];
}

- (nullable id <MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor*)descriptor
{
	return [_queue commandBufferWithDescriptor:descriptor];
}

- (nullable id <MTLCommandBuffer>)commandBufferWithUnretainedReferences
{
	return [_queue commandBufferWithUnretainedReferences];
}

- (void)insertDebugCaptureBoundary
{
	return [_queue insertDebugCaptureBoundary];
}

- (void)addResidencySet:(id <MTLResidencySet>)residencySet
{
	return [_queue addResidencySet:residencySet];
}

- (void)addResidencySets:(const id <MTLResidencySet> _Nonnull[_Nonnull])residencySets
				   count:(NSUInteger)count
{
	return [_queue addResidencySets:residencySets count:count];
}

- (void)removeResidencySet:(id <MTLResidencySet>)residencySet
{
	return [_queue removeResidencySet:residencySet];
}

- (void)removeResidencySets:(const id <MTLResidencySet> _Nonnull[_Nonnull])residencySets
					  count:(NSUInteger)count
{
	return [_queue removeResidencySets:residencySets count:count];
}
@end





#pragma mark -
#pragma mark FxGripMTLLibraryCache Implementation


typedef void (^FxGripMTLFunctionHandler)(id<MTLFunction> _Nullable function, NSError * _Nullable error);

@interface FxGripMTLLibraryCache ()
{
	NSMutableDictionary<NSString*, NSMutableArray<FxGripMTLFunctionHandler>*> *_pendingHandlers;
}
@end

/*!
	@abstract	An MTLLibrary pass-through that memoizes the functions it creates.
	@discussion	Introduced in FxGrip 0.1.0. An NSNull placeholder marks a name whose asynchronous
				compile is in flight, so concurrent asynchronous requests share one compile while a
				synchronous request compiles on its own thread.
*/
@implementation FxGripMTLLibraryCache

@synthesize library = _library;
@synthesize functionCache = _functionCache;

- (nullable instancetype)init
{
	self = [super init];
	if (self) {
		__functionCache = NARC_RETAIN(NSMutableDictionary.new);
		_pendingHandlers = NARC_RETAIN(NSMutableDictionary.new);
	}
	return self;
}

/*! @abstract Wraps an existing library; nil for a nil library. */
- (nullable instancetype)initWithLibrary:(nonnull id<MTLLibrary>)library
{
	if (!library) {
		NARC_RELEASE(self);
		return nil;
	}
	self = [self init];
	if (self) {
		_library = NARC_RETAIN(library);
	}
	return self;
}

/*! @abstract Wraps a device's default library; nil for a nil device or a device with no default library. */
- (nullable instancetype)initWithDevice:(nonnull id<MTLDevice>)device
{
	if (!device) {
		NARC_RELEASE(self);
		return nil;
	}
	self = [self init];
	if (self) {
		_library = device.newDefaultLibrary;
		if (!_library) {
			NARC_RELEASE(self);
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(__functionCache);
	NARC_RELEASE(_functionCache);
	NARC_RELEASE(_pendingHandlers);
	NARC_RELEASE(_library);

	SUPER_DEALLOC();
}

/*! @abstract Drops the memoized function for a name; NO when none was cached. */
- (BOOL)clearFunctionWithName:(nonnull NSString *)name
{
	BOOL hasObject = NO;
	@synchronized (self) {
		hasObject = [__functionCache objectForKey:name] != nil;
		[__functionCache removeObjectForKey:name];
		NARC_RELEASE(_functionCache);
	}
	return hasObject;
}


- (BOOL)isLoading:(nonnull NSString *)name
{
	@synchronized (self) {
		return (__functionCache[name] == [NSNull null]);
	}
}

- (BOOL)isLoaded:(nonnull NSString *)name
{
	@synchronized (self) {
		return __functionCache[name] && (__functionCache[name] != [NSNull null]);
	}
}

- (NSDictionary *)functionCache
{
	@synchronized (self) {
		if (!_functionCache) {
			_functionCache = __functionCache.copy;
		}
		return _functionCache;
	}
}

- (void)storeFunction:(nullable id<MTLFunction>)function forName:(NSString *)name
{
	@synchronized (self) {
		if (function) {
			[__functionCache setObject:function forKey:name];
		} else {
			[__functionCache removeObjectForKey:name];
		}
		NARC_RELEASE(_functionCache);
	}
}

/*! @abstract The memoized function for a name, or nil for a loading placeholder or a miss. */
- (nullable id<MTLFunction>)objectForKeyedSubscript:(nullable NSString*)key
{
	if (![key isKindOfClass:NSString.class]) {
		return nil;
	}
	@synchronized (self) {
		id<MTLFunction> func = __functionCache[key];
		return (func != (id<MTLFunction>)[NSNull null]) ? func : nil;
	}
}



// MTLLibrary caching and passthrough

- (NSString *)label {
	return [_library label];
}
- (void)setLabel:(NSString *)label {
	[_library setLabel:label];
}

- (id <MTLDevice>)device {
	return [_library device];
}

- (nullable id <MTLFunction>) newFunctionWithName:(nonnull NSString *)functionName {
	@synchronized (self) {
		id<MTLFunction> func = [self loadedFunctionNamed:functionName];
		if (func) {
			return func;
		}
		func = [_library newFunctionWithName:functionName];
		[self storeLoadedFunction:func forName:functionName];
		return func;
	}
}

- (nullable id <MTLFunction>) newFunctionWithName:(nonnull NSString *)name constantValues:(nullable MTLFunctionConstantValues *)constantValues
											error:(__autoreleasing NSError **)error {
	@synchronized (self) {
		id<MTLFunction> func = [self loadedFunctionNamed:name];
		if (func) {
			return func;
		}
		func = [_library newFunctionWithName:name constantValues:constantValues error:error];
		[self storeLoadedFunction:func forName:name];
		return func;
	}
}

- (void) newFunctionWithName:(nonnull NSString *)name constantValues:(nullable MTLFunctionConstantValues *)constantValues
			completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler {
	if (![self beginLoadingFunctionNamed:name completionHandler:completionHandler]) {
		return;
	}
	[_library newFunctionWithName:name constantValues:constantValues completionHandler:
		 ^(id<MTLFunction> __nullable function, NSError* __nullable error) {
		[self finishLoadingFunctionNamed:name function:function error:error];
	}];
}

- (void)newFunctionWithDescriptor:(nonnull MTLFunctionDescriptor *)descriptor
				completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler {
	NSString *name = [self cacheNameForDescriptor:descriptor];
	if (![self beginLoadingFunctionNamed:name completionHandler:completionHandler]) {
		return;
	}
	[_library newFunctionWithDescriptor:descriptor completionHandler:
				^(id<MTLFunction> __nullable function, NSError* __nullable error) {
		[self finishLoadingFunctionNamed:name function:function error:error];
	}];
}

- (nullable id <MTLFunction>)newFunctionWithDescriptor:(nonnull MTLFunctionDescriptor *)descriptor
												 error:(__autoreleasing NSError *_Nullable*_Nullable)error {
	NSString *name = [self cacheNameForDescriptor:descriptor];
	@synchronized (self) {
		id<MTLFunction> func = [self loadedFunctionNamed:name];
		if (func) {
			return func;
		}
		func = [_library newFunctionWithDescriptor:descriptor error:error];
		[self storeLoadedFunction:func forName:name];
		return func;
	}
}

- (void)newIntersectionFunctionWithDescriptor:(nonnull MTLIntersectionFunctionDescriptor *)descriptor
							completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler  {
	NSString *name = [self cacheNameForDescriptor:descriptor];
	if (![self beginLoadingFunctionNamed:name completionHandler:completionHandler]) {
		return;
	}
	[_library newIntersectionFunctionWithDescriptor:descriptor completionHandler:
				^(id<MTLFunction> __nullable function, NSError* __nullable error) {
		[self finishLoadingFunctionNamed:name function:function error:error];
	}];
}

- (nullable id <MTLFunction>)newIntersectionFunctionWithDescriptor:(nonnull MTLIntersectionFunctionDescriptor *)descriptor
															 error:(__autoreleasing NSError *_Nullable * _Null_unspecified)error {
	NSString *name = [self cacheNameForDescriptor:descriptor];
	@synchronized (self) {
		id<MTLFunction> func = [self loadedFunctionNamed:name];
		if (func) {
			return func;
		}
		func = [_library newIntersectionFunctionWithDescriptor:descriptor error:error];
		[self storeLoadedFunction:func forName:name];
		return func;
	}
}

#pragma mark Function loading

- (NSString *)cacheNameForDescriptor:(MTLFunctionDescriptor *)descriptor
{
	return descriptor.specializedName ? descriptor.specializedName : descriptor.name;
}

// Callers hold @synchronized (self). A loading placeholder reads as not loaded, so a synchronous
// request during an asynchronous compile compiles on its own thread instead of returning nil.
- (nullable id<MTLFunction>)loadedFunctionNamed:(NSString *)name
{
	id entry = [__functionCache objectForKey:name];
	return (entry && entry != [NSNull null]) ? entry : nil;
}

// Callers hold @synchronized (self). A miss leaves the cache untouched, so an in-flight
// asynchronous compile keeps its placeholder.
- (void)storeLoadedFunction:(nullable id<MTLFunction>)function forName:(NSString *)name
{
	if (function) {
		[self storeFunction:function forName:name];
	}
}

/*!
	@method		beginLoadingFunctionNamed:completionHandler:
	@abstract	Registers a completion handler for an asynchronous compile and reports who owns it.
	@return		YES when this caller starts the compile; NO when the function is already cached
				(the handler runs at once) or another compile is in flight (the handler waits). */
- (BOOL)beginLoadingFunctionNamed:(NSString *)name completionHandler:(FxGripMTLFunctionHandler)completionHandler
{
	id<MTLFunction> cached = nil;
	BOOL ownsCompile = NO;
	@synchronized (self) {
		id entry = [__functionCache objectForKey:name];
		if (entry && entry != [NSNull null]) {
			cached = entry;
		} else {
			ownsCompile = (entry == nil);
			if (ownsCompile) {
				[__functionCache setObject:[NSNull null] forKey:name];
			}
			NSMutableArray *waiters = _pendingHandlers[name];
			if (!waiters) {
				waiters = [NSMutableArray array];
				_pendingHandlers[name] = waiters;
			}
			[waiters addObject:BLOCK_COPY(completionHandler)];
		}
	}
	if (cached) {
		completionHandler(cached, nil);
	}
	return ownsCompile;
}

/*! @abstract Caches a compiled function and runs every waiting completion handler. */
- (void)finishLoadingFunctionNamed:(NSString *)name function:(nullable id<MTLFunction>)function error:(nullable NSError *)error
{
	NSArray<FxGripMTLFunctionHandler> *waiters = nil;
	@synchronized (self) {
		[self storeFunction:(function && !error) ? function : nil forName:name];
		waiters = NARC_AUTORELEASE([_pendingHandlers[name] copy]);
		[_pendingHandlers removeObjectForKey:name];
	}
	for (FxGripMTLFunctionHandler waiter in waiters) {
		waiter(function, error);
	}
}

- (NSArray <NSString *> *)functionNames {
	return [_library functionNames];
}

- (MTLLibraryType)type {
	return [_library type];
}

- (NSString *)installName {
	return [_library installName];
}

@end


#pragma mark -
#pragma mark FxGripMTLDeviceCacheItem Implementation

const NSUInteger    kFxGripMTLInitialCommandQueueCount   = 3;
static NSString*    kKey_InUse          = @"InUse";
static NSString*    kKey_CommandQueue   = @"CommandQueue";

/*!
	@abstract	One device's pooled command queues, pipeline states, library, and depth state.
	@discussion	Introduced in FxGrip 0.1.0. The command-queue pool starts with a fixed count and
				grows when every queue is checked out. Pipeline states cache by function names.
*/
@implementation FxGripMTLDeviceCacheItem

@synthesize defaultLibrary = _defaultLibrary;
@synthesize defaultLibraryCache = _defaultLibraryCache;
@synthesize depthState = _depthState;

/*! @abstract Creates the item and seeds the command-queue pool; nil for a nil device. */
- (instancetype)initWithDevice:(id<MTLDevice>)device
                   pixelFormat:(MTLPixelFormat)pixFormat
                   andPluginID:(NSString*)newPluginID
{
	if (!device) {
		NARC_RELEASE(self);
		return nil;
	}
    self = [super init];

    if (self != nil)
    {
        _gpuDevice = NARC_RETAIN(device);
        _pluginID = [newPluginID copy];
		_pixelFormat = pixFormat;

        _commandQueueCache = [[NSMutableArray alloc] initWithCapacity:kFxGripMTLInitialCommandQueueCount];
		_commandQueueCacheLock = [[NSLock alloc] init];
		_commandQueueCacheLock.name = @"FxGripMTLDeviceCacheItem.commandQueues";
		_pipelineStates = [[NSMutableDictionary alloc] initWithCapacity:3];
        for (NSUInteger i = 0; i < kFxGripMTLInitialCommandQueueCount; i++)
        {
            [self addNewCommandQueue];
        }
    }

    return self;
}

/*! @abstract Adds a new, free command queue to the pool. */
// Callers hold _commandQueueCacheLock, or are still inside init.
- (id<MTLCommandQueue>)addNewCommandQueue
{
	id<MTLCommandQueue> commandQueue    = [_gpuDevice newCommandQueue];
	if (!commandQueue) {
		return nil;
	}
	NSMutableDictionary*   commandDict = [NSMutableDictionary dictionary];
	[commandDict setObject:[NSNumber numberWithBool:NO]
					forKey:kKey_InUse];
	[commandDict setObject:commandQueue
					forKey:kKey_CommandQueue];

	[_commandQueueCache addObject:commandDict];
	return NARC_AUTORELEASE(commandQueue);
}

- (void)dealloc
{
	NARC_RELEASE(_pipelineStates);
	NARC_RELEASE(_commandQueueCache);
	NARC_RELEASE(_commandQueueCacheLock);
	NARC_RELEASE(_defaultLibraryCache);
	NARC_RELEASE(_defaultLibrary);
	NARC_RELEASE(_depthState);
	NARC_RELEASE(_pluginID);
	NARC_RELEASE(_gpuDevice);

	SUPER_DEALLOC();
}

- (id<MTLLibrary>) defaultLibrary
{
	@synchronized (self) {
		if (!_defaultLibrary) {
			_defaultLibrary = [_gpuDevice newDefaultLibrary];
		}
		return _defaultLibrary;
	}
}

- (FxGripMTLLibraryCache*)defaultLibraryCache
{
	@synchronized (self) {
		if (!_defaultLibraryCache) {
			_defaultLibraryCache = [FxGripMTLLibraryCache.alloc initWithLibrary:self.defaultLibrary];
		}
		return _defaultLibraryCache;
	}
}

- (uint64_t)registryID {
	return _gpuDevice.registryID;
}

- (id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader
{
	return [self pipelineStateWithLibrary:nil vertexShader:vertexShader fragmentShader:fragmentShader constantValues:nil specializedFormat:nil];
}

- (id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader constantValues:(MTLFunctionConstantValues *)constantValues
{
	return [self pipelineStateWithLibrary:nil vertexShader:vertexShader fragmentShader:fragmentShader constantValues:constantValues specializedFormat:nil];
}

- (id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader constantValues:(MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat
{
	return [self pipelineStateWithLibrary:nil vertexShader:vertexShader fragmentShader:fragmentShader constantValues:constantValues specializedFormat:specializedFormat];
}


- (id<MTLRenderPipelineState>)pipelineStateWithLibrary:(id<MTLLibrary>)library vertexShader:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader
	constantValues:(MTLFunctionConstantValues *)constantValues
{
	return [self pipelineStateWithLibrary:library vertexShader:vertexShader fragmentShader:fragmentShader constantValues:constantValues specializedFormat:nil];
}

- (NSString*)pipelineKeyForVertexName:(NSString*)vertexName fragmentName:(NSString*)fragmentName
{
	return fragmentName ? [NSString stringWithFormat:@"%@:%@", vertexName, fragmentName] : @"";
}

- (id<MTLRenderPipelineState>)cachedPipelineStateForKey:(NSString*)key
{
	@synchronized (self) {
		return [_pipelineStates objectForKey:key];
	}
}

/*!
	@method		pipelineStateWithLibrary:vertexShader:fragmentShader:constantValues:specializedFormat:
	@abstract	The render pipeline state for a function pair, built once and cached by name.
	@discussion	Introduced in FxGrip 0.1.0. A specialized format specializes the function names for
				the cache key. A nil library uses the item's default library cache. */
- (id<MTLRenderPipelineState>)pipelineStateWithLibrary:(id<MTLLibrary>)library vertexShader:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader
	constantValues:(MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat
{
	NSString *specializedVertexName = nil;
	NSString *specializedFragmentName = nil;
	if (specializedFormat) {
		specializedVertexName = [NSString stringWithFormat:specializedFormat, vertexShader];
		specializedFragmentName = [NSString stringWithFormat:specializedFormat, fragmentShader];
	}
	NSString *key = specializedFormat
		? [self pipelineKeyForVertexName:specializedVertexName fragmentName:specializedFragmentName]
		: [self pipelineKeyForVertexName:vertexShader fragmentName:fragmentShader];
	id<MTLRenderPipelineState> pipelineState = [self cachedPipelineStateForKey:key];
	if (pipelineState) {
		return pipelineState;
	}

	MTLFunctionDescriptor *vertexDescriptor = MTLFunctionDescriptor.functionDescriptor;
	MTLFunctionDescriptor *fragmentDescriptor = MTLFunctionDescriptor.functionDescriptor;

	vertexDescriptor.name = vertexShader;
	fragmentDescriptor.name = fragmentShader;

	if (specializedFormat) {
		vertexDescriptor.specializedName = specializedVertexName;
		fragmentDescriptor.specializedName = specializedFragmentName;
	}
	if (constantValues) {
		vertexDescriptor.constantValues = constantValues;
		fragmentDescriptor.constantValues = constantValues;
	}

	return [self pipelineStateWithLibrary:library vertexDescriptor:vertexDescriptor fragmentDescriptor:fragmentDescriptor];
}

- (id<MTLRenderPipelineState>)pipelineStateWithVertexDescriptor:(MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(MTLFunctionDescriptor*)fragmentDescriptor
{
	return [self pipelineStateWithLibrary:nil vertexDescriptor:vertexDescriptor fragmentDescriptor:fragmentDescriptor];
}

/*!
	@method		pipelineStateWithLibrary:vertexDescriptor:fragmentDescriptor:
	@abstract	The pipeline state for a function descriptor pair, cached by name.
	@discussion	Introduced in FxGrip 0.1.0. A nil library uses the item's default library cache.
				Returns nil when a descriptor has no name or the vertex function fails to load. */
- (id<MTLRenderPipelineState>)pipelineStateWithLibrary:(id<MTLLibrary>)library vertexDescriptor:(MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(MTLFunctionDescriptor*)fragmentDescriptor
{
	if (!library) {
		library = self.defaultLibraryCache;
	}

	if (!library || (vertexDescriptor && !vertexDescriptor.name) || (fragmentDescriptor && !fragmentDescriptor.name)) {
		return nil;
	}

	NSString *vertexName = vertexDescriptor.specializedName ? vertexDescriptor.specializedName : vertexDescriptor.name;
	NSString *fragmentName = fragmentDescriptor.specializedName ? fragmentDescriptor.specializedName : fragmentDescriptor.name;
	NSString *key = fragmentDescriptor ? [self pipelineKeyForVertexName:vertexName fragmentName:fragmentName] : @"";

	id<MTLRenderPipelineState> pipelineState = [self cachedPipelineStateForKey:key];
	if (pipelineState) {
		return pipelineState;
	}

	NSError    *vertexError = nil, *fragmentError = nil;
	id<MTLFunction> vertexFunction = NARC_AUTORELEASE([library newFunctionWithDescriptor:vertexDescriptor error:&vertexError]);
	id<MTLFunction> fragmentFunction = NARC_AUTORELEASE([library newFunctionWithDescriptor:fragmentDescriptor error:&fragmentError]);
	if (!vertexFunction) {
		NSLog(@"Error loading vertex function %@: %@", vertexName, vertexError);
		return nil;
	}
	return [self pipelineStateWithVertexFunction:vertexFunction fragmentFunction:fragmentFunction];
}

/*!
	@method		pipelineStateWithVertexFunction:fragmentFunction:
	@abstract	The pipeline state for an already-built function pair, compiled once and cached.
	@discussion	Introduced in FxGrip 0.1.0. The lock spans lookup and compilation so concurrent
				misses compile one state. The state targets the item's pixel format and a
				Depth32Float attachment. */
- (id<MTLRenderPipelineState>)pipelineStateWithVertexFunction:(id<MTLFunction>)vertexFunction fragmentFunction:(id<MTLFunction>)fragmentFunction
{
	NSString *key = fragmentFunction ? [self pipelineKeyForVertexName:vertexFunction.name fragmentName:fragmentFunction.name] : @"";

	// The lock spans lookup and compilation so concurrent misses compile one state, not one per thread.
	@synchronized (self) {
		id<MTLRenderPipelineState> pipelineState = [_pipelineStates objectForKey:key];
		if (pipelineState) {
			return pipelineState;
		}

		MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
		if (_pluginID) {
			pipelineStateDescriptor.label = _pluginID;
		}

		NSError*    error = nil;

		pipelineStateDescriptor.vertexFunction = vertexFunction;
		pipelineStateDescriptor.fragmentFunction = fragmentFunction;
		pipelineStateDescriptor.colorAttachments[0].pixelFormat = _pixelFormat;
		pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

		pipelineState = NARC_AUTORELEASE([_gpuDevice newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error]);
		if (pipelineState) {
			_pipelineStates[key] = pipelineState;
		} else {
			NSLog (@"Error generating pipeline state: %@", error);
		}
		NARC_RELEASE(pipelineStateDescriptor);
		return pipelineState;
	}
}

- (id<MTLTexture>)depthTexture:(FxRect)bounds
{
	return [FxGripMTLDeviceCache depthTexture:bounds forDevice:_gpuDevice];
}

- (unsigned int)max1DTextureWidth
{
	int maxLength = 8192;

	if ([_gpuDevice supportsFamily:MTLGPUFamilyApple1] || [_gpuDevice supportsFamily:MTLGPUFamilyApple2]) {
		maxLength = 8192; // A7 and A8 chips
	} else {
		maxLength = 16384; // A9 and later chips
	}
	return maxLength;
}

- (unsigned int)max2DTextureWidth
{
	int maxLength = 4096;

	if ([_gpuDevice supportsFamily:MTLGPUFamilyApple1] || [_gpuDevice supportsFamily:MTLGPUFamilyApple2]) {
		maxLength = 8192; // A7 and A8 chips
	} else {
		maxLength = 16384; // A9 and later chips
	}
	return maxLength;
}

- (unsigned int)maxCubeMapTextureWidth
{
	int maxLength = 4096;

	if ([_gpuDevice supportsFamily:MTLGPUFamilyApple1] || [_gpuDevice supportsFamily:MTLGPUFamilyApple2]) {
		maxLength = 8192; // A7 and A8 chips
	} else {
		maxLength = 16384; // A9 and later chips
	}
	return maxLength;
}

- (unsigned int)max3DTextureWidth
{
	return 2048;
}

- (unsigned int)maxTexturePixels
{
	int maxLength = 4096 * 4096;

	if ([_gpuDevice supportsFamily:MTLGPUFamilyApple1] || [_gpuDevice supportsFamily:MTLGPUFamilyApple2]) {
		maxLength = 8192 * 8192; // A7 and A8 chips
	} else {
		maxLength = 16384 * 16384; // A9 and later chips
	}
	return maxLength;
}


/*! @abstract The item's depth-stencil state (less-compare, depth write on), built on first use. */
- (id<MTLDepthStencilState>)depthState
{
	@synchronized (self) {
		if (!_depthState) {
			MTLDepthStencilDescriptor   *depthStencilDescriptor = NARC_AUTORELEASE([MTLDepthStencilDescriptor.alloc init]);
			depthStencilDescriptor.label = @"3D Depth Stencil State";
			depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
			depthStencilDescriptor.depthWriteEnabled = YES;

			_depthState = [_gpuDevice newDepthStencilStateWithDescriptor:depthStencilDescriptor];
		}
		return _depthState;
	}
}


/*! @abstract A free command queue from the pool, marked in-use; a new queue when all are busy. */
- (id<MTLCommandQueue>)getNextFreeCommandQueue
{
    id<MTLCommandQueue> result  = nil;

    [_commandQueueCacheLock lock];
    for (NSMutableDictionary* nextCommandQueue in _commandQueueCache)
    {
        NSNumber* inUse = [nextCommandQueue objectForKey:kKey_InUse];
        if (![inUse boolValue])
        {
            [nextCommandQueue setObject:[NSNumber numberWithBool:YES]
                                 forKey:kKey_InUse];
            result = [nextCommandQueue objectForKey:kKey_CommandQueue];
            break;
        }
    }
	if (!result) {
		result = [self addNewCommandQueue];
		if (result) {
			[_commandQueueCache.lastObject setObject:[NSNumber numberWithBool:YES] forKey:kKey_InUse];
		}
	}
    [_commandQueueCacheLock unlock];

    return result;
}

/*! @abstract Marks a pooled command queue free again. */
- (void)returnCommandQueue:(id<MTLCommandQueue>)commandQueue
{
	if (!commandQueue) {
		return;
	}
    [_commandQueueCacheLock lock];
    for (NSMutableDictionary* nextCommandQueueDict in _commandQueueCache)
    {
        if ([nextCommandQueueDict objectForKey:kKey_CommandQueue] == commandQueue)
        {
            [nextCommandQueueDict setObject:[NSNumber numberWithBool:NO]
                                     forKey:kKey_InUse];
            break;
        }
    }
    [_commandQueueCacheLock unlock];
}

/*! @abstract YES when the command queue is in this item's pool. */
- (BOOL)containsCommandQueue:(id<MTLCommandQueue>)commandQueue
{
	if (!commandQueue) {
		return NO;
	}
    BOOL found = NO;
	[_commandQueueCacheLock lock];
    for (NSMutableDictionary* nextCommandQueueDict in _commandQueueCache)
    {
        if ([nextCommandQueueDict objectForKey:kKey_CommandQueue] == commandQueue)
        {
            found = YES;
            break;
        }
    }
	[_commandQueueCacheLock unlock];

    return found;
}

@end
