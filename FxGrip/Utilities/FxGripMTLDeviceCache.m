//
//  FxGripMTLDeviceCache.m
//  PlugIn
//
//  Created by Apple on 1/24/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.

#import <IOSurface/IOSurfaceObjC.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripMTLDeviceCache.h"
#import "FxGrip_ARC.h"


#pragma mark -
#pragma mark FxGripMTLDeviceCache Implementation

#define kFxGripMTLDeviceDefaultPixelFormat MTLPixelFormatRGBA16Float

@implementation FxGripMTLDeviceCache

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
	/*
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		gDeviceCache = [[FxGripMTLDeviceCache alloc] init];
	});
	
	return gDeviceCache;*/
}


+ (FxGripMTLLibraryCache*)libraryCacheForDevice:(nullable id<MTLDevice>)device
{
	if (!device) {
		return nil;
	}
	NSNumber *key = @(device.registryID);
	FxGripMTLLibraryCache *cache = [self.deviceCache->_deviceDefaultLibraries objectForKey:key];
	if (cache) {
		return cache;
	}
	cache = [FxGripMTLLibraryCache.alloc initWithDevice:device];
	[self.deviceCache->_deviceDefaultLibraries setObject:cache forKey:key];
	return cache;
}

+ (FxGripMTLLibraryCache*)libraryCacheForRegistryID:(uint64_t)registryID
{
	return [self libraryCacheForDevice:[self metalDeviceFromID:registryID]];
}


+ (GuruMTLCommandQueue*)guruCommandQueueForImageTile:(FxImageTile*)imageTile
{
	return [self guruCommandQueueForImageTile:imageTile pluginID:nil];
}

+ (GuruMTLCommandQueue*)guruCommandQueueForImageTile:(FxImageTile*)imageTile pluginID:(nullable NSString *)pluginID
{
	MTLPixelFormat pixelFormat = [self MTLPixelFormatForImageTile:imageTile];
	FxGripMTLDeviceCacheItem *device = [self.deviceCache deviceWithRegistryID:imageTile.deviceRegistryID pixelFormat:pixelFormat andPluginID:pluginID];
	return [GuruMTLCommandQueue.alloc initWithDevice:device];
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


- (instancetype)init
{
	self = [super init];
	
	if (self != nil)
	{
		// FxGripMTLDeviceCache * __weak controller = self; // if used inside the block, to stop recursive references.
		MTLDeviceNotificationHandler notificationHandler = ^(id<MTLDevice> device, MTLDeviceNotificationName name)
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:name object:device];
		};
		
		NSArray<id<MTLDevice>>* devices = MTLCopyAllDevicesWithObserver(&_metalDeviceObserver, notificationHandler);
		
		_deviceDefaultLibraries = [NSMutableDictionary.alloc initWithCapacity:devices.count];
		_deviceCaches = [[NSMutableArray alloc] initWithCapacity:devices.count];
		
		for (id<MTLDevice> nextDevice in devices)
		{
			FxGripMTLDeviceCacheItem*  newCacheItem    = NARC_AUTORELEASE([[FxGripMTLDeviceCacheItem alloc] initWithDevice:nextDevice
																						pixelFormat:kFxGripMTLDeviceDefaultPixelFormat
																						andPluginID:kDefaultPluginID]);
			[_deviceCaches addObject:newCacheItem];
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
	
	SUPER_DEALLOC();
}

- (void)observeDeviceAdded:(NSNotification*)notification
{
	FxGripMTLDeviceCacheItem*  newCacheItem    = NARC_AUTORELEASE([[FxGripMTLDeviceCacheItem alloc] initWithDevice:notification.object
																					  pixelFormat:kFxGripMTLDeviceDefaultPixelFormat
																					  andPluginID:kDefaultPluginID]);
	[_deviceCaches addObject:newCacheItem];
}
- (void)observeDeviceRemovalRequested:(NSNotification*)notification
{
	uint64_t registryID = ((id<MTLDevice>)notification.object).registryID;
	NSNumber *key = @(registryID);
	
	// Remove Device libraries
	FxGripMTLLibraryCache *cache = [_deviceDefaultLibraries objectForKey:key];
	if (cache) {
		[_deviceDefaultLibraries removeObjectForKey:key];
	}
	
	// remove Device caches
	for (FxGripMTLDeviceCacheItem* nextCacheItem in _deviceCaches)
	{
		if (nextCacheItem.gpuDevice.registryID == registryID) {
			[_deviceCaches removeObject:nextCacheItem];
		}
	}
}
- (void)observeDeviceRemovedRequested:(NSNotification*)notification
{
}

//
- (FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
{	// default pixel format is MTLPixelFormatRGBA16Float
	return [self deviceWithRegistryID:registryID pixelFormat:kFxGripMTLDeviceDefaultPixelFormat andPluginID:kDefaultPluginID];
}

- (FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
								  pixelFormat:(MTLPixelFormat)pixFormat
{
	return [self deviceWithRegistryID:registryID pixelFormat:pixFormat andPluginID:kDefaultPluginID];
}

- (FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
								  pixelFormat:(MTLPixelFormat)pixFormat
								  andPluginID:(NSString*)pluginID
{
	for (FxGripMTLDeviceCacheItem* nextCacheItem in _deviceCaches)
	{
		if ((nextCacheItem.gpuDevice.registryID == registryID) &&
			((pluginID == kDefaultPluginID && nextCacheItem.pluginID == kDefaultPluginID) || (pluginID && nextCacheItem.pluginID && [pluginID isEqualToString:nextCacheItem.pluginID])) &&
			(pixFormat == GMTLPixelFormatAny || nextCacheItem.pixelFormat == pixFormat))
		{
			return nextCacheItem;
		}
	}
	id<MTLDevice> device = [self.class metalDeviceFromID:registryID];
	FxGripMTLDeviceCacheItem*  newCacheItem = NARC_AUTORELEASE([[FxGripMTLDeviceCacheItem alloc] initWithDevice:device
																					   pixelFormat:pixFormat
																					   andPluginID:pluginID]);
	if (newCacheItem) {
		[_deviceCaches addObject:newCacheItem];
	}
	
	return newCacheItem;
}


- (id<MTLDepthStencilState>)depthStateWithRegistryID:(uint64_t)registryID
{
	FxGripMTLDeviceCacheItem* deviceCacheItem = [self deviceWithRegistryID:registryID];
	
	return deviceCacheItem.depthState;
}


- (void)returnCommandQueueToCache:(id<MTLCommandQueue>)commandQueue;
{
	for (FxGripMTLDeviceCacheItem* nextCacheItem in _deviceCaches)
	{
		if ([nextCacheItem containsCommandQueue:commandQueue])
		{
			[nextCacheItem returnCommandQueue:commandQueue];
			return;
		}
	}
}

@end


#pragma mark -
#pragma mark GuruMTLCommandQueue Implementation

@implementation GuruMTLCommandQueue

@synthesize queue = _queue;
@synthesize label = _label;


- (id)initWithDevice:(nullable FxGripMTLDeviceCacheItem*)device
{
	id<MTLCommandQueue> queue = [device getNextFreeCommandQueue];
	if (!queue) {
		self = nil;
		return self;
	}
	self = [super init];
	if (self) {
		_deviceCache = device;
		_queue = queue;
	}
	return self;
}



- (void)dealloc {
	[_deviceCache returnCommandQueue:_queue];
	_queue = nil;
	
	SUPER_DEALLOC();
}

#pragma mark MTLCommandQueue implementation

/*! @brief A string to help identify this object */
- (NSString *)label {
	return [_queue label];
}

- (void)setLabel:(NSString *)label {
	[_queue setLabel:label];
}

/*! @brief The device this queue will submit to */
- (id<MTLDevice>)device {
	return [_queue device];
}

/*!
 @method commandBuffer
 @abstract Returns a new autoreleased command buffer used to encode work into this queue that
 maintains strong references to resources used within the command buffer.
*/
- (nullable id <MTLCommandBuffer>)commandBuffer
{
	return [_queue commandBuffer];
}

/*!
 @method commandBufferWithDescriptor
 @param descriptor The requested properties of the command buffer.
 @abstract Returns a new autoreleased command buffer used to encode work into this queue.
*/
- (nullable id <MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor*)descriptor
{
	return [_queue commandBufferWithDescriptor:descriptor];
}


/*!
 @method commandBufferWithUnretainedReferences
 @abstract Returns a new autoreleased command buffer used to encode work into this queue that
 does not maintain strong references to resources used within the command buffer.
*/
- (nullable id <MTLCommandBuffer>)commandBufferWithUnretainedReferences
{
	return [_queue commandBufferWithUnretainedReferences];
}

/*!
 @method insertDebugCaptureBoundary
 @abstract Inform Xcode about when debug capture should start and stop.
 */
- (void)insertDebugCaptureBoundary
{
	return [_queue insertDebugCaptureBoundary];
}

/*!
  @method addResidencySet
  @abstract Marks the residency set as part of the command queue execution. This ensures that the residency set is resident during execution of all the command buffers within the queue.
 */
- (void)addResidencySet:(id <MTLResidencySet>)residencySet
{
	return [_queue addResidencySet:residencySet];
}

/*!
  @method addResidencySets
  @abstract Marks the residency sets as part of the command queue execution. This ensures that the residency sets are resident during execution of all the command buffers within the queue.
 */
- (void)addResidencySets:(const id <MTLResidencySet> _Nonnull[_Nonnull])residencySets
				   count:(NSUInteger)count
{
	return [_queue addResidencySets:residencySets count:count];
}

/*!
  @method removeResidencySet
  @abstract Removes the residency set from the command queue execution. This ensures that only the remaining residency sets are resident during execution of all the command buffers within the queue.
 */
- (void)removeResidencySet:(id <MTLResidencySet>)residencySet
{
	return [_queue removeResidencySet:residencySet];
}

/*!
  @method removeResidencySets
  @abstract Removes the residency sets from the command queue execution. This ensures that only the remaining residency sets are resident during execution of all the command buffers within the queue.
 */
- (void)removeResidencySets:(const id <MTLResidencySet> _Nonnull[_Nonnull])residencySets
					  count:(NSUInteger)count
{
	return [_queue removeResidencySets:residencySets count:count];
}
@end





#pragma mark -
#pragma mark FxGripMTLLibraryCache Implementation


@implementation FxGripMTLLibraryCache

@synthesize library = _library;
@synthesize functionCache = _functionCache;

- (nullable instancetype)init
{
	self = [super init];
	if (self) {
		__functionCache = NARC_RETAIN(NSMutableDictionary.new);
	}
	return self;
}

- (nullable instancetype)initWithLibrary:(nonnull id<MTLLibrary>)library
{
	if (!library) {
		return nil;
	}
	self = [self init];
	if (self) {
		_library = NARC_RETAIN(library);
	}
	return self;
}

- (nullable instancetype)initWithDevice:(nonnull id<MTLDevice>)device
{
	if (!device) {
		return nil;
	}
	self = [self init];
	if (self) {
		_library = device.newDefaultLibrary;
		if (!_library) {
			return nil;
		}
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(__functionCache);
	NARC_RELEASE(_library);
	
	SUPER_DEALLOC();
}

- (BOOL)clearFunctionWithName:(nonnull NSString *)name
{
	BOOL hasObject = NO;
	@synchronized (self) {
		hasObject = [__functionCache objectForKey:name] != nil;
		[__functionCache removeObjectForKey:name];
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
	}
	return _functionCache;
}



- (nullable id<MTLFunction>)objectForKeyedSubscript:(nullable NSString*)key
{
	if (!key) {
		return nil;
	}
	if ([key isKindOfClass:NSString.class]) {
		return __functionCache[key];
	}
	return nil;
}



// MTLLibrary caching and passthrough

/*!
 @property label
 @abstract A string to help identify this object.
 */
- (NSString *)label {
	return [_library label];
}
- (void)setLabel:(NSString *)label {
	[_library setLabel:label];
}

/*!
 @property device
 @abstract The device this resource was created against.  This resource can only be used with this device.
 */
- (id <MTLDevice>)device {
	return [_library device];
}

/*!
 @method newFunctionWithName
 @abstract Returns a pointer to a function object, return nil if the function is not found in the library.
 */
- (nullable id <MTLFunction>) newFunctionWithName:(nonnull NSString *)functionName {
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:functionName])) {
			return (func != (id<MTLFunction>)[NSNull null]) ? func : nil;
		}
		func = [_library newFunctionWithName:functionName];
		[__functionCache setObject:func forKey:functionName];
		
		return func;
	}
}

/*!
 @method newFunctionWithName:constantValues:error:
 @abstract Returns a pointer to a function object obtained by applying the constant values to the named function.
 @discussion This method will call the compiler. Use newFunctionWithName:constantValues:completionHandler: to
 avoid waiting on the compiler.
 */
- (nullable id <MTLFunction>) newFunctionWithName:(nonnull NSString *)name constantValues:(nullable MTLFunctionConstantValues *)constantValues
											error:(__autoreleasing NSError **)error {
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:name])) {
			return (func != (id<MTLFunction>)[NSNull null]) ? func : nil;
		}
		func = [_library newFunctionWithName:name constantValues:constantValues error:error];
		[__functionCache setObject:func forKey:name];
		return func;
	}
}


/*!
 @method newFunctionWithName:constantValues:completionHandler:
 @abstract Returns a pointer to a function object obtained by applying the constant values to the named function.
 @discussion This method is asynchronous since it is will call the compiler.
 */
- (void) newFunctionWithName:(nonnull NSString *)name constantValues:(nullable MTLFunctionConstantValues *)constantValues
			completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler {
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:name])) {
			if (func != (id<MTLFunction>)[NSNull null])
				completionHandler(func, nil);
			return;
		}
		// set placeholder for the metal function
		[__functionCache setObject:[NSNull null] forKey:name];
	}
	__block void (^ _Nullable finalizeBlock)(id<MTLFunction> __nullable function, NSError* __nullable error) = BLOCK_COPY(completionHandler);
	[_library newFunctionWithName:name constantValues:constantValues completionHandler:
		 ^(id<MTLFunction> __nullable function, NSError* __nullable error) {
		if (function && !error) {
			@synchronized (self) {
				[self->__functionCache setObject:function forKey:name];
			}
		}
		if (completionHandler) {
			completionHandler(function, error);
			BLOCK_RELEASE(finalizeBlock);
		}
	}];
}

/*!
 @method newFunctionWithDescriptor:completionHandler:
 @abstract Create a new MTLFunction object asynchronously.
 */
- (void)newFunctionWithDescriptor:(nonnull MTLFunctionDescriptor *)descriptor
				completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler {
	NSString *name = descriptor.specializedName ? descriptor.specializedName : descriptor.name;
	
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:name])) {
			if (func != (id<MTLFunction>)[NSNull null])
				completionHandler(func, nil);
			return;
		}
		// set placeholder for the metal function
		[__functionCache setObject:[NSNull null] forKey:name];
	}
	__block void (^ _Nullable finalizeBlock)(id<MTLFunction> __nullable function, NSError* __nullable error) = BLOCK_COPY(completionHandler);
	[_library newFunctionWithDescriptor:descriptor completionHandler:
				^(id<MTLFunction> __nullable function, NSError* __nullable error) {
		if (function && !error) {
			@synchronized (self) {
				[self->__functionCache setObject:function forKey:name];
			}
		}
		if (completionHandler) {
			completionHandler(function, error);
			BLOCK_RELEASE(finalizeBlock);
		}
	}];
}

/*!
 @method newFunctionWithDescriptor:error:
 @abstract Create  a new MTLFunction object synchronously.
 */
- (nullable id <MTLFunction>)newFunctionWithDescriptor:(nonnull MTLFunctionDescriptor *)descriptor
												 error:(__autoreleasing NSError *_Nullable*_Nullable)error {
	NSString *name = descriptor.specializedName ? descriptor.specializedName : descriptor.name;
	
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:name])) {
			return (func != (id<MTLFunction>)[NSNull null]) ? func : nil;
		}
		func = [_library newFunctionWithDescriptor:descriptor error:error];
		[__functionCache setObject:func forKey:name];
		return func;
	}
}



/*!
 @method newIntersectionFunctionWithDescriptor:completionHandler:
 @abstract Create a new MTLFunction object asynchronously.
 */
- (void)newIntersectionFunctionWithDescriptor:(nonnull MTLIntersectionFunctionDescriptor *)descriptor
							completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler  {
	NSString *name = descriptor.specializedName ? descriptor.specializedName : descriptor.name;
	
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:name])) {
			if (func != (id<MTLFunction>)[NSNull null])
				completionHandler(func, nil);
			return;
		}
		// set placeholder for the metal function
		[__functionCache setObject:[NSNull null] forKey:name];
	}
	__block void (^ _Nullable finalizeBlock)(id<MTLFunction> __nullable function, NSError* __nullable error) = BLOCK_COPY(completionHandler);
	[_library newIntersectionFunctionWithDescriptor:descriptor completionHandler:
				^(id<MTLFunction> __nullable function, NSError* __nullable error) {
		if (function && !error) {
			@synchronized (self) {
				[self->__functionCache setObject:function forKey:name];
			}
		}
		if (completionHandler) {
			completionHandler(function, error);
			BLOCK_RELEASE(finalizeBlock);
		}
	}];
}


/*!
 @method newIntersectionFunctionWithDescriptor:error:
 @abstract Create  a new MTLFunction object synchronously.
 */
- (nullable id <MTLFunction>)newIntersectionFunctionWithDescriptor:(nonnull MTLIntersectionFunctionDescriptor *)descriptor
															 error:(__autoreleasing NSError *_Nullable * _Null_unspecified)error {
	NSString *name = descriptor.specializedName ? descriptor.specializedName : descriptor.name;
	
	@synchronized (self) {
		id<MTLFunction> func;
		if ((func = [__functionCache objectForKey:name])) {
			return (func != (id<MTLFunction>)[NSNull null]) ? func : nil;
		}
		func = [_library newIntersectionFunctionWithDescriptor:descriptor error:error];
		[__functionCache setObject:func forKey:name];
		return func;
	}
}



/*!
 @property functionNames
 @abstract The array contains NSString objects, with the name of each function in library.
 */
- (NSArray <NSString *> *)functionNames {
	return [_library functionNames];
}

/*!
 @property type
 @abstract The library type provided when this MTLLibrary was created.
 Libraries with MTLLibraryTypeExecutable can be used to obtain MTLFunction from.
 Libraries with MTLLibraryTypeDynamic can be used to resolve external references in other MTLLibrary from.
 @see MTLCompileOptions
 */
- (MTLLibraryType)type {
	return [_library type];
}

/*!
 @property installName
 @abstract The installName provided when this MTLLibrary was created.
 @discussion Always nil if the type of the library is not MTLLibraryTypeDynamic.
 @see MTLCompileOptions
 */
- (NSString *)installName {
	return [_library installName];
}

@end


#pragma mark -
#pragma mark FxGripMTLDeviceCacheItem Implementation

const NSUInteger    kMTLMaxCommandQueues   = 3;
static NSString*    kKey_InUse          = @"InUse";
static NSString*    kKey_CommandQueue   = @"CommandQueue";

//static FxGripMTLDeviceCache*   gDeviceCache    = nil;

@implementation FxGripMTLDeviceCacheItem

@synthesize defaultLibrary = _defaultLibrary;
@synthesize defaultLibraryCache = _defaultLibraryCache;
@synthesize depthState = _depthState;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                   pixelFormat:(MTLPixelFormat)pixFormat
                   andPluginID:(NSString*)newPluginID
{
    self = [super init];
    
    if (self != nil)
    {
        _gpuDevice = NARC_RETAIN(device);
        _pluginID = [newPluginID copy];
        
        _commandQueueCache = [[NSMutableArray alloc] initWithCapacity:kMTLMaxCommandQueues];
		_pipelineStates = [[NSMutableDictionary alloc] initWithCapacity:3];
        for (NSUInteger i = 0; (_commandQueueCache != nil) && (i < kMTLMaxCommandQueues); i++)
        {
            [self addNewCommandQueue];
        }
        
		_pixelFormat = pixFormat;
		 
        if (_commandQueueCache != nil)
        {
            _commandQueueCacheLock = [[NSLock alloc] init];
        }
        
        if ((_gpuDevice == nil) || (_commandQueueCache == nil) || (_commandQueueCacheLock == nil) )
        {
			NARC_RELEASE(_gpuDevice);
			NARC_RELEASE(_commandQueueCache);
			NARC_RELEASE(_commandQueueCacheLock);
			
			NARC_RELEASE(self);
        }
    }
    
    return self;
}

- (id<MTLCommandQueue>)addNewCommandQueue
{
	NSMutableDictionary*   commandDict = [NSMutableDictionary dictionary];
	[commandDict setObject:[NSNumber numberWithBool:NO]
					forKey:kKey_InUse];
	
	id<MTLCommandQueue> commandQueue    = [_gpuDevice newCommandQueue];
	[commandDict setObject:commandQueue
					forKey:kKey_CommandQueue];
	
	[_commandQueueCache addObject:commandDict];
	return commandQueue;
}

- (void)dealloc
{
	NARC_RELEASE(_pipelineStates);
	NARC_RELEASE(_commandQueueCache);
	NARC_RELEASE(_commandQueueCacheLock);
	NARC_RELEASE(_defaultLibrary);
	NARC_RELEASE(_gpuDevice);
    
	SUPER_DEALLOC();
}

- (id<MTLLibrary>) defaultLibrary
{
	if (!_defaultLibrary) {
		_defaultLibrary = [_gpuDevice newDefaultLibrary];
	}
	return _defaultLibrary;
}

- (FxGripMTLLibraryCache*)defaultLibraryCache
{
	if (!_defaultLibraryCache) {
		_defaultLibraryCache = [FxGripMTLLibraryCache.alloc initWithLibrary:self.defaultLibrary];
	}
	return _defaultLibraryCache;
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
	return [self pipelineStateWithLibrary:nil vertexShader:vertexShader fragmentShader:fragmentShader constantValues:constantValues specializedFormat:nil];
}


- (id<MTLRenderPipelineState>)pipelineStateWithLibrary:(id<MTLLibrary>)library vertexShader:(NSString*)vertexShader fragmentShader:(NSString*)fragmentShader
	constantValues:(MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat
{
	NSString *specializedVertexName = nil;
	NSString *specializedFragmentName = nil;
	if (specializedFormat) {
		specializedVertexName = [NSString stringWithFormat:specializedFormat, vertexShader];
		specializedFragmentName = [NSString stringWithFormat:specializedFormat, fragmentShader];
		
		NSString *key = fragmentShader ? [NSString stringWithFormat:@"%@:%@", specializedVertexName, specializedFragmentName] : @"";
	 
		if ([_pipelineStates objectForKey:key]) {
			return _pipelineStates[key];
		}
	} else {
		NSString *key = fragmentShader ? [NSString stringWithFormat:@"%@:%@", vertexShader, fragmentShader] : @"";
	 
		if ([_pipelineStates objectForKey:key]) {
			return _pipelineStates[key];
		}
	}
	MTLFunctionDescriptor *vertexDescriptor = MTLFunctionDescriptor.functionDescriptor;
	MTLFunctionDescriptor *fragmentDescriptor = MTLFunctionDescriptor.functionDescriptor;
	
	vertexDescriptor.name = vertexShader;
	fragmentDescriptor.name = fragmentShader;
	
	if (specializedFormat) {
		vertexDescriptor.specializedName = [NSString stringWithFormat:specializedFormat, vertexShader];
		fragmentDescriptor.specializedName = [NSString stringWithFormat:specializedFormat, fragmentShader];
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

- (id<MTLRenderPipelineState>)pipelineStateWithLibrary:(id<MTLLibrary>)library vertexDescriptor:(MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(MTLFunctionDescriptor*)fragmentDescriptor
{
	if (!library) {
		library = self.defaultLibraryCache;
	}
	
	if (!library || (vertexDescriptor && !vertexDescriptor.name) || (fragmentDescriptor && !fragmentDescriptor.name)) {
		return nil;
	}
	
	NSString *key = fragmentDescriptor ? [NSString stringWithFormat:@"%@:%@", vertexDescriptor.specializedName ? vertexDescriptor.specializedName : vertexDescriptor.name, fragmentDescriptor.specializedName ? fragmentDescriptor.specializedName : fragmentDescriptor.name] : @"";
	
	id<MTLRenderPipelineState> pipelineState;
	if ((pipelineState = [_pipelineStates objectForKey:key])) {
		return pipelineState;
	}
	
	NSError    *vertexError = nil, *fragmetError = nil;
	return [self pipelineStateWithVertexFunction:[library newFunctionWithDescriptor:vertexDescriptor error:&vertexError] fragmentFunction:[library newFunctionWithDescriptor:fragmentDescriptor error:&fragmetError]];
}

- (id<MTLRenderPipelineState>)pipelineStateWithVertexFunction:(id<MTLFunction>)vertexFunction fragmentFunction:(id<MTLFunction>)fragmentFunction
{
	NSString *key = fragmentFunction ? [NSString stringWithFormat:@"%@:%@", vertexFunction.name, fragmentFunction.name] : @"";
	
	id<MTLRenderPipelineState> pipelineState;
	if ((pipelineState = [_pipelineStates objectForKey:key])) {
		return pipelineState;
	}
	// Configure a pipeline descriptor that is used to create a pipeline state
	
	MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
	if (_pluginID) {
		pipelineStateDescriptor.label = _pluginID;
	}
	
	NSError*    error = nil;
	
	pipelineStateDescriptor.vertexFunction = vertexFunction;
	pipelineStateDescriptor.fragmentFunction = fragmentFunction;
	pipelineStateDescriptor.colorAttachments[0].pixelFormat = _pixelFormat;
	pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
	
	id<MTLRenderPipelineState> pipe = _pipelineStates[key] = [_gpuDevice newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
																										error:&error];
	if (error != nil)
	{
		NSLog (@"Error generating pipeline state: %@", error);
	}
	NARC_RELEASE(pipelineStateDescriptor);
	return pipe;
}

- (id<MTLTexture>)depthTexture:(FxRect)bounds
{
	id<MTLTexture>  result  = nil;
	
	MTLTextureDescriptor*   depthTexDesc    = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
																								 width:bounds.right - bounds.left
																								height:bounds.top - bounds.bottom
																							 mipmapped:NO];
	depthTexDesc.storageMode = MTLStorageModePrivate;
	result = NARC_RETAIN_AUTORELEASE([_gpuDevice newTextureWithDescriptor:depthTexDesc]);
	
	return result;
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


- (id<MTLDepthStencilState>)depthState
{
	if (!_depthState) {
		MTLDepthStencilDescriptor   *depthStencilDescriptor = NARC_AUTORELEASE([MTLDepthStencilDescriptor.alloc init]);
		depthStencilDescriptor.label = @"3D Depth Stencil State";
		depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
		depthStencilDescriptor.depthWriteEnabled = YES;
		
		_depthState = [_gpuDevice newDepthStencilStateWithDescriptor:depthStencilDescriptor];
	}
	return _depthState;
}


- (id<MTLCommandQueue>)getNextFreeCommandQueue
{
    id<MTLCommandQueue> result  = nil;
    
    [_commandQueueCacheLock lock];
    NSUInteger  index   = 0;
    while ((result == nil) && (index < _commandQueueCache.count))
    {
        NSMutableDictionary*    nextCommandQueue    = [_commandQueueCache objectAtIndex:index];
        NSNumber*               inUse               = [nextCommandQueue objectForKey:kKey_InUse];
        if (![inUse boolValue])
        {
            [nextCommandQueue setObject:[NSNumber numberWithBool:YES]
                                 forKey:kKey_InUse];
            result = [nextCommandQueue objectForKey:kKey_CommandQueue];
        }
        index++;
    }
	if (!result) {
		result = [self addNewCommandQueue];
	}
    [_commandQueueCacheLock unlock];
    
    return result;
}

- (void)returnCommandQueue:(id<MTLCommandQueue>)commandQueue
{
    [_commandQueueCacheLock lock];
    
    BOOL        found   = false;
    NSUInteger  index   = 0;
    while ((!found) && (index < _commandQueueCache.count))
    {
        NSMutableDictionary*    nextCommandQueuDict = [_commandQueueCache objectAtIndex:index];
        id<MTLCommandQueue>     nextCommandQueue    = [nextCommandQueuDict objectForKey:kKey_CommandQueue];
        if (nextCommandQueue == commandQueue)
        {
            found = YES;
            [nextCommandQueuDict setObject:[NSNumber numberWithBool:NO]
                                    forKey:kKey_InUse];
        }
        index++;
    }
    
    [_commandQueueCacheLock unlock];
}

- (BOOL)containsCommandQueue:(id<MTLCommandQueue>)commandQueue
{
	[_commandQueueCacheLock lock];
	
    BOOL        found   = NO;
    NSUInteger  index   = 0;
    while ((!found) && (index < _commandQueueCache.count))
    {
        NSMutableDictionary*    nextCommandQueuDict = [_commandQueueCache objectAtIndex:index];
        id<MTLCommandQueue>     nextCommandQueue    = [nextCommandQueuDict objectForKey:kKey_CommandQueue];
        if (nextCommandQueue == commandQueue)
        {
            found = YES;
        }
        index++;
    }
	
	[_commandQueueCacheLock unlock];
    
    return found;
}

@end




