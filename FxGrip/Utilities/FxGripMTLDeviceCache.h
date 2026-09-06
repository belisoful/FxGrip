/*!
	@file       FxGripMTLDeviceCache.h
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripMTLDeviceCache
	@abstract   A thread-safe process-wide cache of Metal devices, command queues, pipeline states, and libraries.
	@discussion Introduced in FxGrip 0.1.0. The cache extends the MetalDeviceCache pattern from
	            Apple's FxPlug samples. It keys a cache item by device registry ID, pixel format,
	            and plugin ID, creating items on first request and dropping them when Metal reports
	            a device removed. Command queues are pooled and handed back after use, and
	            FxGripMTLCommandQueue wraps one to return itself on dealloc. FxGripMTLLibraryCache
	            memoizes the functions a library compiles.
*/

#import <Metal/Metal.h>
#import <BEFoundation/BESingleton.h>
#import <FxGrip/FxTileImage+FxGrip.h>

/*! The plugin ID that selects the shared, non-per-plugin cache item. */
#define kDefaultPluginID			nil
/*! The pixel format that matches a cache item of any pixel format. */
#define FxGripMTLPixelFormatAny		((MTLPixelFormat)-1)

@class FxGripMTLDeviceCacheItem;
@class FxImageTile;
@class FxGripMTLCommandQueue;
@class FxGripMTLLibraryCache;

/*!
	@class      FxGripMTLDeviceCache
	@abstract   Process-wide cache of Metal devices, command queues, pipeline states, and
				shader libraries keyed by device registry ID, pixel format, and plugin ID.
	@discussion Introduced in FxGrip 0.1.0. Extends the `MetalDeviceCache` pattern from Apple's
				FxPlug samples. One `FxGripMTLDeviceCacheItem` exists per (device, pixel format,
				plugin ID) triple; items are created on first request and dropped when Metal
				reports the device's removal.

				Every method is safe to call from concurrent render threads. The cache guards its
				item list and library dictionary with one lock; each item guards its command-queue
				pool and pipeline-state dictionary separately. Callers never hold a cache lock
				while a Metal command buffer executes.

				A command queue obtained from `+commandQueueForImageTile:` must be handed back
				through `+returnCommandQueue:` or `-returnCommandQueueToCache:` once its command
				buffer is committed. `+scopedCommandQueueForImageTile:` returns a
				`FxGripMTLCommandQueue` wrapper that performs the hand-back on dealloc.
*/
@interface FxGripMTLDeviceCache : NSObject <BESingleton>
{
	NSMutableArray<FxGripMTLDeviceCacheItem*>*			_deviceCaches;
	NSMutableDictionary<NSNumber*, FxGripMTLLibraryCache*>*	_deviceDefaultLibraries;
	NSLock*												_deviceCachesLock;

	id <NSObject>	_metalDeviceObserver;
}
/*! The default library cache for a device; nil when no cache item matches. */
+ (nullable FxGripMTLLibraryCache*)libraryCacheForDevice:(nullable id<MTLDevice>)device;
/*! The default library cache for a device registry ID; nil when no cache item matches. */
+ (nullable FxGripMTLLibraryCache*)libraryCacheForRegistryID:(uint64_t)registryID;

/*! A pooled command queue for the tile's device and pixel format; return it with returnCommandQueue:. */
+ (nullable id<MTLCommandQueue>)commandQueueForImageTile:(FxImageTile *_Null_unspecified)imageTile;
/*! A pooled command queue for the tile's device, pixel format, and plugin ID. */
+ (nullable id<MTLCommandQueue>)commandQueueForImageTile:(FxImageTile *_Null_unspecified)imageTile pluginID:(nullable NSString *)pluginID;

/*!
	@method     scopedCommandQueueForImageTile:
	@abstract   Checks out a command queue for the tile's device and pixel format, wrapped so it
				returns itself to the cache on dealloc.
	@discussion Introduced in FxGrip 0.1.0. Equivalent to `+commandQueueForImageTile:` followed by
				`+returnCommandQueue:` when the wrapper is released. Do not pass the wrapper to
				`+returnCommandQueue:`.
	@param      imageTile  The tile whose device and pixel format select the cache item.
	@result     The wrapper, or `nil` when no device matches the tile.
*/
+ (nullable FxGripMTLCommandQueue*)scopedCommandQueueForImageTile:(FxImageTile*_Null_unspecified)imageTile;

/*!
	@method     scopedCommandQueueForImageTile:pluginID:
	@abstract   Checks out a command queue for the tile's device, pixel format, and plugin ID,
				wrapped so it returns itself to the cache on dealloc.
	@discussion Introduced in FxGrip 0.1.0.
	@param      imageTile  The tile whose device and pixel format select the cache item.
	@param      pluginID   Selects a per-plugin cache item; `nil` selects the shared item.
	@result     The wrapper, or `nil` when no device matches the tile.
*/
+ (nullable FxGripMTLCommandQueue*)scopedCommandQueueForImageTile:(FxImageTile*_Null_unspecified)imageTile pluginID:(nullable NSString *)pluginID;
/*! Returns a pooled command queue checked out with commandQueueForImageTile: to its cache item. */
+ (void)returnCommandQueue:(id<MTLCommandQueue>_Null_unspecified)commandQueue;

/*! The shared device-cache singleton. */
+ (nonnull FxGripMTLDeviceCache*)deviceCache;
/*! The Metal pixel format for a tile's IOSurface. */
+ (MTLPixelFormat)MTLPixelFormatForImageTile:(nullable FxImageTile*)imageTile;
/*! The MTLDevice for a device registry ID; nil when none matches. */
+ (nullable id<MTLDevice>)metalDeviceFromID:(uint64_t)registryID;

/*! A depth texture sized to bounds on a device; nil on allocation failure. */
+ (nullable id<MTLTexture>)depthTexture:(FxRect)bounds forDevice:(nonnull id<MTLDevice>)device;

/*! The cache item for a device registry ID, of any pixel format and the default plugin ID. */
- (nullable FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID;
/*! The cache item for a device registry ID and pixel format, default plugin ID. */
- (nullable FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
									  pixelFormat:(MTLPixelFormat)pixFormat;
/*! The cache item for a device registry ID, pixel format, and plugin ID; created when absent. */
- (nullable FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
									  pixelFormat:(MTLPixelFormat)pixFormat
									  andPluginID:(nullable NSString*)pluginID;

/*! The depth-stencil state for a device registry ID; nil when none matches. */
- (nullable id<MTLDepthStencilState>)depthStateWithRegistryID:(uint64_t)registryID;
/*! Returns a pooled command queue to whichever cache item owns it. */
- (void)returnCommandQueueToCache:(nullable id<MTLCommandQueue>)commandQueue;

@end



/*!
	@class      FxGripMTLCommandQueue
	@abstract   An `MTLCommandQueue` pass-through that returns the wrapped queue to its
				`FxGripMTLDeviceCacheItem` on dealloc.
	@discussion Introduced in FxGrip 0.1.0. The queue is checked out of the item at init and
				checked back in at dealloc, so a render method that keeps the wrapper in a local
				variable releases the queue when the variable goes out of scope. Obtain one from
				`+[FxGripMTLDeviceCache scopedCommandQueueForImageTile:]`.
*/
@interface FxGripMTLCommandQueue : NSObject <MTLCommandQueue>
@property (readonly, nonatomic, nonnull) id<MTLCommandQueue> queue;
@property (readonly, retain, nonnull) FxGripMTLDeviceCacheItem *deviceCacheItem;

/*!
	@method     initWithDeviceCacheItem:
	@abstract   Checks a command queue out of `deviceCacheItem`.
	@result     `nil` when `deviceCacheItem` is `nil` or has no queue to give.
*/
- (nullable instancetype)initWithDeviceCacheItem:(nullable FxGripMTLDeviceCacheItem*)deviceCacheItem;
- (void)dealloc;

// MTLCommandQueue interface

/*! @brief A string to help identify this object */
@property (nullable, copy, atomic) NSString *label;

/*! @brief The device this queue will submit to */
@property (readonly) id<MTLDevice> _Null_unspecified device;

/*!
 @method commandBuffer
 @abstract Returns a new autoreleased command buffer used to encode work into this queue that
 maintains strong references to resources used within the command buffer.
*/
- (nullable id <MTLCommandBuffer>)commandBuffer;

/*!
 @method commandBufferWithDescriptor
 @param descriptor The requested properties of the command buffer.
 @abstract Returns a new autoreleased command buffer used to encode work into this queue.
*/
- (nullable id <MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor*_Null_unspecified)descriptor API_AVAILABLE(macos(11.0), ios(14.0));


/*!
 @method commandBufferWithUnretainedReferences
 @abstract Returns a new autoreleased command buffer used to encode work into this queue that
 does not maintain strong references to resources used within the command buffer.
*/
- (nullable id <MTLCommandBuffer>)commandBufferWithUnretainedReferences;

/*!
 @method insertDebugCaptureBoundary
 @abstract Inform Xcode about when debug capture should start and stop.
 */
- (void)insertDebugCaptureBoundary API_DEPRECATED("Use MTLCaptureScope instead", macos(10.11, 10.13), ios(8.0, 11.0));

/*!
  @method addResidencySet
  @abstract Marks the residency set as part of the command queue execution. This ensures that the residency set is resident during execution of all the command buffers within the queue.
 */
- (void)addResidencySet:(id <MTLResidencySet>_Null_unspecified)residencySet
				   API_AVAILABLE(macos(15.0), ios(18.0));
/*!
  @method addResidencySets
  @abstract Marks the residency sets as part of the command queue execution. This ensures that the residency sets are resident during execution of all the command buffers within the queue.
 */
- (void)addResidencySets:(const id <MTLResidencySet> _Nonnull[_Nonnull])residencySets
				   count:(NSUInteger)count
				   API_AVAILABLE(macos(15.0), ios(18.0));

/*!
  @method removeResidencySet
  @abstract Removes the residency set from the command queue execution. This ensures that only the remaining residency sets are resident during execution of all the command buffers within the queue.
 */
- (void)removeResidencySet:(id <MTLResidencySet>_Null_unspecified)residencySet
				   API_AVAILABLE(macos(15.0), ios(18.0));

/*!
  @method removeResidencySets
  @abstract Removes the residency sets from the command queue execution. This ensures that only the remaining residency sets are resident during execution of all the command buffers within the queue.
 */
- (void)removeResidencySets:(const id <MTLResidencySet> _Nonnull[_Nonnull])residencySets
					  count:(NSUInteger)count
API_AVAILABLE(macos(15.0), ios(18.0));

@end




/*!
	@class      FxGripMTLLibraryCache
	@abstract   An `MTLLibrary` pass-through that memoizes the `MTLFunction` objects it creates.
	@discussion Introduced in FxGrip 0.1.0. Functions are cached by name, or by specialized name
				when a descriptor supplies one. A lookup that yields no function is not cached.
				All methods are safe to call concurrently.

				Asynchronous requests for one name share one compile: the first caller starts it
				and every caller's completion handler runs when it finishes, with the function or
				the error. A synchronous request for a name whose asynchronous compile is in flight
				compiles on the calling thread and returns its own result.
*/
@interface FxGripMTLLibraryCache : NSObject <MTLLibrary>
{
@protected
	NSMutableDictionary *__functionCache;
}

/*! The wrapped MTLLibrary. */
@property (readonly, retain, nonnull)	id<MTLLibrary>	library;
/*! A snapshot of the memoized functions, keyed by name. */
@property (readonly, retain, nonnull)	NSDictionary<NSString*, id<MTLFunction>>*	functionCache;

/*! Wraps an existing library. */
- (nullable instancetype)initWithLibrary:(nonnull id<MTLLibrary>)library;
/*! Wraps a device's default library; nil when the device has none. */
- (nullable instancetype)initWithDevice:(nonnull id<MTLDevice>)device;
- (void)dealloc;

/*! Drops the memoized function for a name; NO when none was cached. */
- (BOOL)clearFunctionWithName:(nonnull NSString *)name;



/*! The memoized function for a name, compiling and caching it on first request. */
- (nullable id <MTLFunction>)objectForKeyedSubscript:(NSString * _Nullable)key;
/*! YES while an asynchronous compile for a name is in flight. */
- (BOOL)isLoading:(nonnull NSString *)name;
/*! YES when a function for a name is memoized. */
- (BOOL)isLoaded:(nonnull NSString *)name;

// MTLLibrary caching and passthrough
/*!
 @property label
 @abstract A string to help identify this object.
 */
@property (nullable, copy, atomic) NSString *label;

/*!
 @property device
 @abstract The device this resource was created against.  This resource can only be used with this device.
 */
@property (readonly, nonnull) id <MTLDevice> device;

/*!
 @method newFunctionWithName
 @abstract Returns a pointer to a function object, return nil if the function is not found in the library.
 */
- (nullable id <MTLFunction>) newFunctionWithName:(nonnull NSString *)functionName;

/*!
 @method newFunctionWithName:constantValues:error:
 @abstract Returns a pointer to a function object obtained by applying the constant values to the named function.
 @discussion This method will call the compiler. Use newFunctionWithName:constantValues:completionHandler: to
 avoid waiting on the compiler.
 */
- (nullable id <MTLFunction>) newFunctionWithName:(nonnull NSString *)name constantValues:(nullable MTLFunctionConstantValues *)constantValues
					error:(__autoreleasing NSError *_Nullable *_Nullable)error API_AVAILABLE(macos(10.12), ios(10.0));


/*!
 @method newFunctionWithName:constantValues:completionHandler:
 @abstract Returns a pointer to a function object obtained by applying the constant values to the named function.
 @discussion This method is asynchronous since it is will call the compiler.
 */
- (void) newFunctionWithName:(nonnull NSString *)name constantValues:(nullable MTLFunctionConstantValues *)constantValues
			completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler API_AVAILABLE(macos(10.12), ios(10.0));


/*!
 @method newFunctionWithDescriptor:completionHandler:
 @abstract Create a new MTLFunction object asynchronously.
 */
- (void)newFunctionWithDescriptor:(nonnull MTLFunctionDescriptor *)descriptor
				completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler API_AVAILABLE(macos(11.0), ios(14.0));

/*!
 @method newFunctionWithDescriptor:error:
 @abstract Create  a new MTLFunction object synchronously.
 */
- (nullable id <MTLFunction>)newFunctionWithDescriptor:(nonnull MTLFunctionDescriptor *)descriptor
												 error:(__autoreleasing NSError *_Nullable*_Nullable)error API_AVAILABLE(macos(11.0), ios(14.0));



/*!
 @method newIntersectionFunctionWithDescriptor:completionHandler:
 @abstract Create a new MTLFunction object asynchronously.
 */
- (void)newIntersectionFunctionWithDescriptor:(nonnull MTLIntersectionFunctionDescriptor *)descriptor
							completionHandler:(void (^_Nonnull)(id<MTLFunction> __nullable function, NSError* __nullable error))completionHandler
	API_AVAILABLE(macos(11.0), ios(14.0));

/*!
 @method newIntersectionFunctionWithDescriptor:error:
 @abstract Create  a new MTLFunction object synchronously.
 */
- (nullable id <MTLFunction>)newIntersectionFunctionWithDescriptor:(nonnull MTLIntersectionFunctionDescriptor *)descriptor
															 error:(__autoreleasing NSError *_Nullable * _Null_unspecified)error
	API_AVAILABLE(macos(11.0), ios(14.0));



/*!
 @property functionNames
 @abstract The array contains NSString objects, with the name of each function in library.
 */
@property (readonly, null_unspecified) NSArray <NSString *> *functionNames;

/*!
 @property type
 @abstract The library type provided when this MTLLibrary was created.
 Libraries with MTLLibraryTypeExecutable can be used to obtain MTLFunction from.
 Libraries with MTLLibraryTypeDynamic can be used to resolve external references in other MTLLibrary from.
 @see MTLCompileOptions
 */
@property (readonly) MTLLibraryType type API_AVAILABLE(macos(11.0), ios(14.0));

/*!
 @property installName
 @abstract The installName provided when this MTLLibrary was created.
 @discussion Always nil if the type of the library is not MTLLibraryTypeDynamic.
 @see MTLCompileOptions
 */
@property (readonly, nullable) NSString* installName API_AVAILABLE(macos(11.0), ios(14.0));

@end



/*!
	@class      FxGripMTLDeviceCacheItem
	@abstract   One Metal device's pooled command queues, cached pipeline states, default
				library, and depth-stencil state for a given pixel format and plugin ID.
	@discussion Introduced in FxGrip 0.1.0. The command-queue pool starts with a fixed number of
				queues and grows when every pooled queue is checked out. Pipeline states are keyed
				by vertex and fragment function names. All methods are safe to call concurrently.
*/
@interface FxGripMTLDeviceCacheItem : NSObject

/*! The Metal device this item caches for. */
@property (readonly, nonnull)   		id<MTLDevice>                           gpuDevice;
/*! The device's default shader library. */
@property (readonly, nonnull)   		id<MTLLibrary>                          defaultLibrary;
/*! The memoizing cache over the default library. */
@property (readonly, nonnull)   		FxGripMTLLibraryCache*                  defaultLibraryCache;
/*! The render pipeline states, keyed by vertex and fragment function names. */
@property (retain, nonnull)     		NSMutableDictionary<NSString*, id<MTLRenderPipelineState>>*   pipelineStates;
/*! The depth-stencil state for this item's pixel format. */
@property (readonly, retain, nonnull, nonatomic) id<MTLDepthStencilState>		depthState;
/*! The pooled command queues and their checked-out state. */
@property (retain, nonnull)     		NSMutableArray<NSMutableDictionary*>*   commandQueueCache;
/*! The lock guarding the command-queue pool. */
@property (readonly, nonnull)   		NSLock*                                 commandQueueCacheLock;
/*! The pixel format this item's pipeline and depth states are built for. */
@property (readonly)    				MTLPixelFormat                          pixelFormat;
/*! The plugin ID this item is keyed under; nil for the shared item. */
@property (readonly, nullable)   		NSString*                               pluginID;

/*! The device registry ID this item is keyed under. */
@property (readonly)    				uint64_t                          		registryID;

/*! Creates an item for a device, pixel format, and plugin ID. */
- (nullable instancetype)initWithDevice:(nonnull id<MTLDevice>)device
				   pixelFormat:(MTLPixelFormat)pixFormat
				   andPluginID:(nullable NSString*)newPluginID;
/*! The device's maximum 1D texture width. */
- (unsigned int)max1DTextureWidth;
/*! The device's maximum 2D texture width. */
- (unsigned int)max2DTextureWidth;
/*! The device's maximum cube-map texture width. */
- (unsigned int)maxCubeMapTextureWidth;
/*! The device's maximum 3D texture width. */
- (unsigned int)max3DTextureWidth;
/*! The device's maximum 2D texture area in pixels. */
- (unsigned int)maxTexturePixels;

/*! A free command queue from the pool, growing the pool when every queue is checked out. */
- (nullable id<MTLCommandQueue>)getNextFreeCommandQueue;
/*! Marks a command queue free in the pool. */
- (void)returnCommandQueue:(nullable id<MTLCommandQueue>)commandQueue;
/*! YES when the command queue belongs to this item's pool. */
- (BOOL)containsCommandQueue:(nullable id<MTLCommandQueue>)commandQueue;

/*! The render pipeline state for a vertex and fragment function pair, cached by name. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader;
/*! The pipeline state for a function pair with function constants applied. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader constantValues:(nullable MTLFunctionConstantValues *)constantValues;
/*! The pipeline state for a function pair with function constants, cached under a specialized format key. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader constantValues:(nullable MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat;


/*! The pipeline state for a function pair from a given library, with function constants. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithLibrary:(nullable id<MTLLibrary>)library vertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader
										constantValues:(nullable MTLFunctionConstantValues *)constantValues;
/*! The pipeline state for a function pair from a given library, with function constants and a specialized format key. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithLibrary:(nullable id<MTLLibrary>)library vertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader
										constantValues:(nullable MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat;


/*! The pipeline state for a vertex and fragment function descriptor pair. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexDescriptor:(nonnull MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(nonnull MTLFunctionDescriptor*)fragmentDescriptor;
/*! The pipeline state for a function descriptor pair from a given library. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithLibrary:(nullable id<MTLLibrary>)library vertexDescriptor:(nonnull MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(nonnull MTLFunctionDescriptor*)fragmentDescriptor;

/*! The pipeline state for an already-built vertex and fragment function pair. */
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexFunction:(nonnull id<MTLFunction>)vertexFunction fragmentFunction:(nonnull id<MTLFunction>)fragmentFunction;

@end
