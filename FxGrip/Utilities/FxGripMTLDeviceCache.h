//
//  FxGripMTLDeviceCache.h
//  PlugIn
//
//  Created by Apple on 1/24/18.
//  Copyright © 2019-2023 Apple Inc. All rights reserved.

#import <Metal/Metal.h>
#import <BEFoundation/BESingleton.h>
#import <FxGrip/FxTileImage+FxGrip.h>

#define kDefaultPluginID		nil
#define GMTLPixelFormatAny		-1

@class FxGripMTLDeviceCacheItem;
@class FxImageTile;
@class GuruMTLCommandQueue;
@class FxGripMTLLibraryCache;

@interface FxGripMTLDeviceCache : NSObject <BESingleton>
{
	NSMutableArray<FxGripMTLDeviceCacheItem*>*			_deviceCaches;
	NSMutableDictionary<NSNumber*, FxGripMTLLibraryCache*>*	_deviceDefaultLibraries;
	
	id <NSObject>	_metalDeviceObserver;
}
+ (nullable FxGripMTLLibraryCache*)libraryCacheForDevice:(nullable id<MTLDevice>)device;
+ (nullable FxGripMTLLibraryCache*)libraryCacheForRegistryID:(uint64_t)registryID;

+ (nullable id<MTLCommandQueue>)commandQueueForImageTile:(FxImageTile *_Null_unspecified)imageTile;
+ (nullable id<MTLCommandQueue>)commandQueueForImageTile:(FxImageTile *_Null_unspecified)imageTile pluginID:(nullable NSString *)pluginID;
+ (nullable GuruMTLCommandQueue*)guruCommandQueueForImageTile:(FxImageTile*_Null_unspecified)imageTile;
+ (nullable GuruMTLCommandQueue*)guruCommandQueueForImageTile:(FxImageTile*_Null_unspecified)imageTile pluginID:(nullable NSString *)pluginID;
+ (void)returnCommandQueue:(id<MTLCommandQueue>_Null_unspecified)commandQueue;

+ (nonnull FxGripMTLDeviceCache*)deviceCache;
+ (MTLPixelFormat)MTLPixelFormatForImageTile:(nullable FxImageTile*)imageTile;
+ (nullable id<MTLDevice>)metalDeviceFromID:(uint64_t)registryID;

+ (nullable id<MTLTexture>)depthTexture:(FxRect)bounds forDevice:(nonnull id<MTLDevice>)device;

- (nullable FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID;
- (nullable FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
									  pixelFormat:(MTLPixelFormat)pixFormat;
- (nullable FxGripMTLDeviceCacheItem*)deviceWithRegistryID:(uint64_t)registryID
									  pixelFormat:(MTLPixelFormat)pixFormat
									  andPluginID:(nullable NSString*)pluginID;

- (nullable id<MTLDepthStencilState>)depthStateWithRegistryID:(uint64_t)registryID;
- (void)returnCommandQueueToCache:(nullable id<MTLCommandQueue>)commandQueue;

@end



//Pass through class that returns the command queue to the cache when it's done
@interface GuruMTLCommandQueue : NSObject <MTLCommandQueue>
@property (readonly, nonatomic, nonnull) id<MTLCommandQueue> queue;
@property (readonly, retain, nonnull) FxGripMTLDeviceCacheItem *deviceCache;

- (nullable id)initWithDevice:(nullable FxGripMTLDeviceCacheItem*)device;
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




@interface FxGripMTLLibraryCache : NSObject <MTLLibrary>
{
@protected
	NSMutableDictionary *__functionCache;
}

@property (readonly, retain, nonnull)	id<MTLLibrary>	library;
@property (readonly, retain, nonnull)	NSDictionary<NSString*, id<MTLFunction>>*	functionCache;

- (nullable instancetype)initWithLibrary:(nonnull id<MTLLibrary>)library;
- (nullable instancetype)initWithDevice:(nonnull id<MTLDevice>)device;
- (void)dealloc;

- (BOOL)clearFunctionWithName:(nonnull NSString *)name;



- (nullable id <MTLFunction>)objectForKeyedSubscript:(NSString * _Nullable)key;
- (BOOL)isLoading:(nonnull NSString *)name;
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



@interface FxGripMTLDeviceCacheItem : NSObject

@property (readonly, nonnull)   		id<MTLDevice>                           gpuDevice;
@property (readonly, nonnull)   		id<MTLLibrary>                          defaultLibrary;
@property (readonly, nonnull)   		FxGripMTLLibraryCache*                  defaultLibraryCache;
@property (retain, nonnull)     		NSMutableDictionary<NSString*, id<MTLRenderPipelineState>>*   pipelineStates;
@property (readonly, retain, nonnull, nonatomic) id<MTLDepthStencilState>		depthState;
@property (retain, nonnull)     		NSMutableArray<NSMutableDictionary*>*   commandQueueCache;
@property (readonly, nonnull)   		NSLock*                                 commandQueueCacheLock;
@property (readonly)    				MTLPixelFormat                          pixelFormat;
@property (readonly, nullable)   		NSString*                               pluginID;

@property (readonly)    				uint64_t                          		registryID;

- (nullable instancetype)initWithDevice:(nonnull id<MTLDevice>)device
				   pixelFormat:(MTLPixelFormat)pixFormat
				   andPluginID:(nullable NSString*)newPluginID;
- (unsigned int)max1DTextureWidth;
- (unsigned int)max2DTextureWidth;
- (unsigned int)maxCubeMapTextureWidth;
- (unsigned int)max3DTextureWidth;
- (unsigned int)maxTexturePixels;

- (nullable id<MTLCommandQueue>)getNextFreeCommandQueue;
- (void)returnCommandQueue:(nullable id<MTLCommandQueue>)commandQueue;
- (BOOL)containsCommandQueue:(nullable id<MTLCommandQueue>)commandQueue;

- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader;
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader constantValues:(nullable MTLFunctionConstantValues *)constantValues;
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader constantValues:(nullable MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat;


- (nonnull id<MTLRenderPipelineState>)pipelineStateWithLibrary:(nullable id<MTLLibrary>)library vertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader
										constantValues:(nullable MTLFunctionConstantValues *)constantValues;
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithLibrary:(nullable id<MTLLibrary>)library vertexShader:(nonnull NSString*)vertexShader fragmentShader:(nonnull NSString*)fragmentShader
										constantValues:(nullable MTLFunctionConstantValues *)constantValues specializedFormat:(nullable NSString*)specializedFormat;


- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexDescriptor:(nonnull MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(nonnull MTLFunctionDescriptor*)fragmentDescriptor;
- (nonnull id<MTLRenderPipelineState>)pipelineStateWithLibrary:(nullable id<MTLLibrary>)library vertexDescriptor:(nonnull MTLFunctionDescriptor*)vertexDescriptor fragmentDescriptor:(nonnull MTLFunctionDescriptor*)fragmentDescriptor;

- (nonnull id<MTLRenderPipelineState>)pipelineStateWithVertexFunction:(nonnull id<MTLFunction>)vertexFunction fragmentFunction:(nonnull id<MTLFunction>)fragmentFunction;

@end
