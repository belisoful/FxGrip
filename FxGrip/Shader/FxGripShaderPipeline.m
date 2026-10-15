/*!
	@file       FxGripShaderPipeline.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripShaderPipeline
	@abstract   Implements the shader value snapshot, the reflected uniform layout, and the render pipeline.
	@discussion Introduced in FxGrip 0.1.0. The pipeline compiles the prelude and the source per device,
	            specializes the fragment function per constant signature, reflects the uniform struct,
	            and encodes the conversion, shader, and conversion-back passes into one command buffer.
	            The build cache, the converter, and the tile and value helpers are shared with the
	            kernel pipeline through FxGripShaderPipelineInternal.h.
*/

#import "FxGripShaderPipeline.h"
#import "FxGripShaderPipelineInternal.h"
#import "FxGripMTLDeviceCache.h"
#import "FxGripColorGamut.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"
#import <os/lock.h>
#import <simd/simd.h>

/*! The fragment function the prelude supplies for the primaries conversion passes. */
#define kFxGripShaderConvertFunctionName	@"fxGripShaderConvertFragment"

/*! The key under which FxGripShaderValues archives its components. */
#define kFxGripShaderValuesComponentsKey	@"components"

_Static_assert(sizeof(FxGripShaderTile) == 544, "FxGripShaderTile matches GripTile in GripKernel.slang");

/*! The conversion pass uniform; matches FxGripShaderConversion in the prelude. */
typedef struct {
	simd_float3x3 matrix;
	uint32_t gamma;
} FxGripShaderConversion;

static NSString * const FxGripShaderPrelude =
	@"#include <metal_stdlib>\n"
	@"using namespace metal;\n"
	@"\n"
	@"#define FXGRIP_SHADER_TEXTURE_MAP_LIMIT 16\n"
	@"\n"
	@"struct FxGripShaderVertexOut {\n"
	@"    float4 position [[position]];\n"
	@"    float2 texCoord;\n"
	@"    float2 imagePixel;\n"
	@"};\n"
	@"\n"
	@"struct FxGripShaderTextureMap {\n"
	@"    float4 u;\n"
	@"    float4 v;\n"
	@"};\n"
	@"\n"
	@"struct FxGripShaderTile {\n"
	@"    float4 destinationBounds;\n"
	@"    float2 pixelScale;\n"
	@"    uint textureCount;\n"
	@"    uint reserved;\n"
	@"    FxGripShaderTextureMap textures[FXGRIP_SHADER_TEXTURE_MAP_LIMIT];\n"
	@"};\n"
	@"\n"
	@"struct FxGripShaderConversion {\n"
	@"    float3x3 matrix;\n"
	@"    uint gamma;\n"
	@"};\n"
	@"\n"
	@"static inline float2 fxGripShaderTexCoord(constant FxGripShaderTile &tile, uint index, float2 imagePixel)\n"
	@"{\n"
	@"    if (index >= FXGRIP_SHADER_TEXTURE_MAP_LIMIT) {\n"
	@"        return float2(0.0);\n"
	@"    }\n"
	@"    FxGripShaderTextureMap map = tile.textures[index];\n"
	@"    return float2(dot(map.u.xy, imagePixel) + map.u.z, dot(map.v.xy, imagePixel) + map.v.z);\n"
	@"}\n"
	@"\n"
	@"vertex FxGripShaderVertexOut fxGripShaderVertex(uint vertexID [[vertex_id]],\n"
	@"                                                constant FxGripShaderTile &tile [[buffer(0)]])\n"
	@"{\n"
	@"    float2 corner = float2(float(vertexID & 1u), float(vertexID >> 1u));\n"
	@"    float4 d = tile.destinationBounds;\n"
	@"    float2 imagePixel = float2(mix(d.x, d.z, corner.x), mix(d.w, d.y, corner.y));\n"
	@"    FxGripShaderVertexOut out;\n"
	@"    out.position = float4(corner.x * 2.0 - 1.0, 1.0 - corner.y * 2.0, 0.0, 1.0);\n"
	@"    out.imagePixel = imagePixel;\n"
	@"    out.texCoord = fxGripShaderTexCoord(tile, 0u, imagePixel);\n"
	@"    return out;\n"
	@"}\n"
	@"\n"
	@"static float3 fxGripShaderDecodeGamma(float3 v)\n"
	@"{\n"
	@"    float3 a = abs(v);\n"
	@"    return sign(v) * select(pow((a + 0.055) / 1.055, 2.4), a / 12.92, a <= 0.04045);\n"
	@"}\n"
	@"\n"
	@"static float3 fxGripShaderEncodeGamma(float3 v)\n"
	@"{\n"
	@"    float3 a = abs(v);\n"
	@"    return sign(v) * select(1.055 * pow(a, 1.0 / 2.4) - 0.055, a * 12.92, a <= 0.0031308);\n"
	@"}\n"
	@"\n"
	@"fragment float4 fxGripShaderConvertFragment(FxGripShaderVertexOut in [[stage_in]],\n"
	@"                                            texture2d<float, access::read> source [[texture(0)]],\n"
	@"                                            constant FxGripShaderConversion &conversion [[buffer(0)]])\n"
	@"{\n"
	@"    float4 color = source.read(uint2(in.position.xy));\n"
	@"    if (conversion.gamma == 0u) {\n"
	@"        return float4(conversion.matrix * color.rgb, color.a);\n"
	@"    }\n"
	@"    float3 rgb = color.a > 0.0 ? color.rgb / color.a : color.rgb;\n"
	@"    rgb = fxGripShaderEncodeGamma(conversion.matrix * fxGripShaderDecodeGamma(rgb));\n"
	@"    return float4(rgb * color.a, color.a);\n"
	@"}\n"
	@"\n"
	@"#line 1\n";

NSUInteger FxGripShaderComponentCountForType(FxParameterType type)
{
	switch (type) {
		case FxParameterType_Float:
		case FxParameterType_Percent:
		case FxParameterType_Angle:
		case FxParameterType_Int:
		case FxParameterType_Menu:
		case FxParameterType_Toggle:
		case FxParameterType_Switch:
			return 1;
		case FxParameterType_Point:
			return 2;
		case FxParameterType_RGB:
			return 3;
		case FxParameterType_RGBA:
			return 4;
		default:
			return 0;
	}
}

BOOL FxGripShaderScalarType(MTLDataType type, MTLDataType *scalar, NSUInteger *count)
{
	static const struct { MTLDataType first; MTLDataType scalar; } families[] = {
		{ MTLDataTypeFloat, MTLDataTypeFloat },
		{ MTLDataTypeHalf, MTLDataTypeHalf },
		{ MTLDataTypeInt, MTLDataTypeInt },
		{ MTLDataTypeUInt, MTLDataTypeUInt },
		{ MTLDataTypeShort, MTLDataTypeShort },
		{ MTLDataTypeUShort, MTLDataTypeUShort },
		{ MTLDataTypeChar, MTLDataTypeChar },
		{ MTLDataTypeUChar, MTLDataTypeUChar },
		{ MTLDataTypeBool, MTLDataTypeBool },
	};
	// Each family is four consecutive enumerators: the scalar, then its 2-, 3-, and 4-vectors.
	for (size_t index = 0; index < sizeof(families) / sizeof(families[0]); index++) {
		if (type >= families[index].first && type < families[index].first + 4) {
			*scalar = families[index].scalar;
			*count = (NSUInteger)(type - families[index].first) + 1;
			return YES;
		}
	}
	return NO;
}

static NSUInteger FxGripShaderScalarSize(MTLDataType scalar)
{
	switch (scalar) {
		case MTLDataTypeFloat:
		case MTLDataTypeInt:
		case MTLDataTypeUInt:
			return 4;
		case MTLDataTypeHalf:
		case MTLDataTypeShort:
		case MTLDataTypeUShort:
			return 2;
		default:
			return 1;
	}
}

static double FxGripShaderRoundedClamped(double value, double minimum, double maximum)
{
	if (isnan(value)) {
		return 0.0;
	}
	return fmin(fmax(round(value), minimum), maximum);
}

static void FxGripShaderWriteScalar(MTLDataType scalar, double value, uint8_t *destination)
{
	switch (scalar) {
		case MTLDataTypeFloat: {
			float stored = (float)value;
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeHalf: {
			__fp16 stored = (__fp16)value;
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeInt: {
			int32_t stored = (int32_t)FxGripShaderRoundedClamped(value, INT32_MIN, INT32_MAX);
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeUInt: {
			uint32_t stored = (uint32_t)FxGripShaderRoundedClamped(value, 0, UINT32_MAX);
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeShort: {
			int16_t stored = (int16_t)FxGripShaderRoundedClamped(value, INT16_MIN, INT16_MAX);
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeUShort: {
			uint16_t stored = (uint16_t)FxGripShaderRoundedClamped(value, 0, UINT16_MAX);
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeChar: {
			int8_t stored = (int8_t)FxGripShaderRoundedClamped(value, INT8_MIN, INT8_MAX);
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		case MTLDataTypeUChar: {
			uint8_t stored = (uint8_t)FxGripShaderRoundedClamped(value, 0, UINT8_MAX);
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
		default: {
			uint8_t stored = (value != 0.0) ? 1 : 0;
			memcpy(destination, &stored, sizeof(stored));
			break;
		}
	}
}

void FxGripShaderWriteComponents(MTLDataType scalar, NSUInteger count, NSArray<NSNumber *> *components, uint8_t *destination)
{
	NSUInteger size = FxGripShaderScalarSize(scalar);
	NSUInteger written = MIN(count, components.count);
	for (NSUInteger index = 0; index < written; index++) {
		FxGripShaderWriteScalar(scalar, components[index].doubleValue, destination + index * size);
	}
}

BOOL FxGripShaderFxColorPrimaries(FxGripShaderPrimaries primaries, FxColorPrimaries *colorPrimaries)
{
	switch (primaries) {
		case FxGripShaderPrimariesRec709:
			*colorPrimaries = kFxColorPrimaries_Rec709;
			return YES;
		case FxGripShaderPrimariesRec2020:
			*colorPrimaries = kFxColorPrimaries_Rec2020;
			return YES;
		default:
			return NO;
	}
}

static FxPoint2D FxGripShaderTransformPoint(FxMatrix44 *_Nullable matrix, FxPoint2D point)
{
	return matrix != nil ? [matrix transform2DPoint:point] : point;
}

/*! The map from destination pixels to the normalized coordinate of a texture covering bounds in its own pixel space.
	A destination pixel goes to image space through the destination's inverse pixel transform, then to the
	texture's pixel space through texturePixelTransform. Three sample points give the affine map exactly. */
static FxGripShaderTextureMap FxGripShaderMakeTextureMap(FxMatrix44 *_Nullable destinationInverse,
														 FxMatrix44 *_Nullable texturePixelTransform,
														 FxRect bounds)
{
	const FxPoint2D samples[3] = { { 0.0, 0.0 }, { 1.0, 0.0 }, { 0.0, 1.0 } };
	double width = MAX((double)(bounds.right - bounds.left), 1.0);
	double height = MAX((double)(bounds.top - bounds.bottom), 1.0);
	simd_double2 coordinates[3];
	for (int index = 0; index < 3; index++) {
		FxPoint2D image = FxGripShaderTransformPoint(destinationInverse, samples[index]);
		FxPoint2D pixel = FxGripShaderTransformPoint(texturePixelTransform, image);
		coordinates[index] = simd_make_double2((pixel.x - bounds.left) / width, (bounds.top - pixel.y) / height);
	}
	FxGripShaderTextureMap map;
	map.u = simd_make_float4((float)(coordinates[1].x - coordinates[0].x), (float)(coordinates[2].x - coordinates[0].x), (float)coordinates[0].x, 0.0f);
	map.v = simd_make_float4((float)(coordinates[1].y - coordinates[0].y), (float)(coordinates[2].y - coordinates[0].y), (float)coordinates[0].y, 0.0f);
	return map;
}

simd_float2 FxGripShaderPixelScale(FxMatrix44 *_Nullable pixelTransform)
{
	FxPoint2D origin = FxGripShaderTransformPoint(pixelTransform, (FxPoint2D){ 0.0, 0.0 });
	FxPoint2D x = FxGripShaderTransformPoint(pixelTransform, (FxPoint2D){ 1.0, 0.0 });
	FxPoint2D y = FxGripShaderTransformPoint(pixelTransform, (FxPoint2D){ 0.0, 1.0 });
	return simd_make_float2((float)hypot(x.x - origin.x, x.y - origin.y), (float)hypot(y.x - origin.x, y.y - origin.y));
}

/*! A tile whose destination and every texture map cover the same texture-sized rectangle, for the conversion passes. */
static FxGripShaderTile FxGripShaderTextureTile(id<MTLTexture> texture)
{
	FxRect bounds = { 0, 0, (SInt32)texture.width, (SInt32)texture.height };
	FxGripShaderTile tile = { 0 };
	tile.destinationBounds = simd_make_float4(bounds.left, bounds.bottom, bounds.right, bounds.top);
	tile.pixelScale = simd_make_float2(1.0f, 1.0f);
	tile.textureCount = 1;
	tile.textures[0] = FxGripShaderMakeTextureMap(nil, nil, bounds);
	return tile;
}

FxGripShaderTile FxGripShaderMakeTile(FxImageTile *destinationImage,
									  NSDictionary<NSNumber *, FxImageTile *> *boundTiles,
									  NSUInteger textureCount,
									  simd_float2 pixelScale)
{
	FxRect destinationBounds = destinationImage.tilePixelBounds;
	FxGripShaderTile tile = { 0 };
	tile.destinationBounds = simd_make_float4(destinationBounds.left, destinationBounds.bottom, destinationBounds.right, destinationBounds.top);
	tile.pixelScale = pixelScale;
	tile.textureCount = (uint32_t)textureCount;
	FxGripShaderTextureMap destinationMap = FxGripShaderMakeTextureMap(nil, nil, destinationBounds);
	for (NSUInteger index = 0; index < kFxGripShaderTextureMapLimit; index++) {
		FxImageTile *textureTile = boundTiles[@(index)];
		tile.textures[index] = textureTile != nil
			? FxGripShaderMakeTextureMap(destinationImage.inversePixelTransform, textureTile.pixelTransform, textureTile.tilePixelBounds)
			: destinationMap;
	}
	return tile;
}

NSArray<NSString *> *FxGripShaderConstantKeys(FxGripShaderMetadata *metadata)
{
	NSMutableArray<NSString *> *constantKeys = [NSMutableArray array];
	for (NSDictionary *record in metadata.allParameters) {
		if ([record[kFxGripShaderProperty_Constant] boolValue]) {
			[constantKeys addObject:record[kFxGripShaderProperty_Key]];
		}
	}
	return [constantKeys sortedArrayUsingSelector:@selector(compare:)];
}

NSSet<NSString *> *FxGripShaderPixelUnitKeys(FxGripShaderMetadata *metadata)
{
	NSMutableSet<NSString *> *pixelUnitKeys = [NSMutableSet set];
	for (NSDictionary *record in metadata.allParameters) {
		if ([record[kFxGripShaderProperty_PixelUnits] boolValue]) {
			[pixelUnitKeys addObject:record[kFxGripShaderProperty_Key]];
		}
	}
	return pixelUnitKeys;
}

NSString *FxGripShaderConstantSignature(NSArray<NSString *> *constantKeys, FxGripShaderValues *values)
{
	NSMutableArray<NSString *> *entries = [NSMutableArray arrayWithCapacity:constantKeys.count];
	for (NSString *key in constantKeys) {
		NSMutableArray<NSString *> *components = [NSMutableArray array];
		for (NSNumber *component in [values componentsForKey:key]) {
			[components addObject:[NSString stringWithFormat:@"%.17g", component.doubleValue]];
		}
		[entries addObject:[NSString stringWithFormat:@"%@=%@", key, [components componentsJoinedByString:@","]]];
	}
	return [entries componentsJoinedByString:@";"];
}

FxGripShaderValues *FxGripShaderValuesScaledToPixels(FxGripShaderValues *values, NSSet<NSString *> *pixelUnitKeys, float pixelScale)
{
	if (pixelUnitKeys.count == 0 || pixelScale == 1.0f) {
		return values;
	}
	FxGripShaderValues *scaled = NARC_AUTORELEASE([values copy]);
	for (NSString *key in pixelUnitKeys) {
		NSMutableArray<NSNumber *> *components = [NSMutableArray array];
		for (NSNumber *component in [values componentsForKey:key]) {
			[components addObject:@(component.doubleValue * pixelScale)];
		}
		[scaled setComponents:components forKey:key];
	}
	return scaled;
}

id<MTLTexture> _Nullable FxGripShaderEmptyTexture(id<MTLDevice> device)
{
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
																						  width:1
																						 height:1
																					  mipmapped:NO];
	id<MTLTexture> texture = NARC_AUTORELEASE([device newTextureWithDescriptor:descriptor]);
	const uint8_t transparent[4] = { 0, 0, 0, 0 };
	[texture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0 withBytes:transparent bytesPerRow:sizeof(transparent)];
	return texture;
}

id<MTLTexture> _Nullable FxGripShaderIntermediateTexture(id<MTLTexture> texture, MTLTextureUsage usage, id<MTLDevice> device)
{
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:texture.pixelFormat
																						  width:texture.width
																						 height:texture.height
																					  mipmapped:NO];
	descriptor.usage = usage;
	descriptor.storageMode = MTLStorageModePrivate;
	return NARC_AUTORELEASE([device newTextureWithDescriptor:descriptor]);
}

id<MTLRenderCommandEncoder> FxGripShaderRenderEncoder(id<MTLTexture> target, id<MTLCommandBuffer> commandBuffer)
{
	MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
	pass.colorAttachments[0].texture = target;
	pass.colorAttachments[0].loadAction = MTLLoadActionClear;
	pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
	pass.colorAttachments[0].storeAction = MTLStoreActionStore;
	id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
	MTLViewport viewport = { 0.0, 0.0, (double)target.width, (double)target.height, 0.0, 1.0 };
	[encoder setViewport:viewport];
	return encoder;
}

NSError *FxGripShaderPipelineError(NSInteger code, NSString *reason, NSError *underlying)
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = reason;
	userInfo[NSLocalizedFailureReasonErrorKey] = reason;
	if (underlying != nil) {
		userInfo[NSUnderlyingErrorKey] = underlying;
	}
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code userInfo:userInfo];
}

BOOL FxGripShaderFail(NSError **error, NSInteger code, NSString *reason, NSError *underlying)
{
	if (error != NULL) {
		*error = FxGripShaderPipelineError(code, reason, underlying);
	}
	return NO;
}

#pragma mark - Values

/*!
	@abstract	The values of a shader's bound parameters at one render time, keyed by shader symbol.
	@discussion	Introduced in FxGrip 0.1.0. The components are stored as arrays of NSNumber.
*/
@implementation FxGripShaderValues
{
	NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *_components;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_components = [NSMutableDictionary new];
	}
	return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self == nil) {
		return nil;
	}
	NSSet<Class> *classes = [NSSet setWithObjects:NSDictionary.class, NSString.class, NSArray.class, NSNumber.class, nil];
	NSDictionary *decoded = [coder decodeObjectOfClasses:classes forKey:kFxGripShaderValuesComponentsKey];
	if (![decoded isKindOfClass:NSDictionary.class]) {
		return self;
	}
	for (id key in decoded) {
		id components = decoded[key];
		if ([key isKindOfClass:NSString.class] && [self isComponentArray:components]) {
			[self setComponents:components forKey:key];
		}
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_components);
	SUPER_DEALLOC();
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	FxGripShaderValues *copy = [[self.class allocWithZone:zone] init];
	[copy->_components addEntriesFromDictionary:_components];
	return copy;
}

- (BOOL)isComponentArray:(id)components
{
	if (![components isKindOfClass:NSArray.class]) {
		return NO;
	}
	for (id component in (NSArray *)components) {
		if (![component isKindOfClass:NSNumber.class]) {
			return NO;
		}
	}
	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_components forKey:kFxGripShaderValuesComponentsKey];
}

- (NSArray<NSString *> *)keys
{
	return [_components.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

- (void)setComponents:(nullable NSArray<NSNumber *> *)components forKey:(NSString *)key
{
	if (components.count == 0) {
		[_components removeObjectForKey:key];
		return;
	}
	NSRange kept = NSMakeRange(0, MIN(components.count, (NSUInteger)4));
	_components[key] = [components subarrayWithRange:kept];
}

- (void)setDouble:(double)value forKey:(NSString *)key
{
	[self setComponents:@[@(value)] forKey:key];
}

- (nullable NSArray<NSNumber *> *)componentsForKey:(NSString *)key
{
	return _components[key];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@>", self.class, _components];
}

@end

#pragma mark - Uniform member

/*! One reflected uniform struct member bound to a parameter key. */
@interface FxGripShaderUniformMember : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) NSUInteger offset;
@property (nonatomic, assign) MTLDataType scalarType;
@property (nonatomic, assign) NSUInteger componentCount;
@end

@implementation FxGripShaderUniformMember

- (void)dealloc
{
	NARC_RELEASE(_key);
	SUPER_DEALLOC();
}

@end

#pragma mark - Build cache

/*! One cache entry under construction. Callers that ask for the same key wait on the group, outside the cache lock. */
@interface FxGripShaderPendingBuild : NSObject
@property (nonatomic, strong) dispatch_group_t group;
@property (nonatomic, strong, nullable) id result;
@end

@implementation FxGripShaderPendingBuild

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_group = dispatch_group_create();
		dispatch_group_enter(_group);
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_group);
	NARC_RELEASE(_result);
	SUPER_DEALLOC();
}

@end

/*!
	@abstract	A cache whose entries build outside its lock, with one build per key.
	@discussion	Introduced in FxGrip 0.1.0. One lock guards the entries and the table of pending builds.
*/
@implementation FxGripShaderBuildCache
{
	NSLock *_lock;
	NSUInteger _limit;
	NSMutableDictionary<NSString *, id> *_entries;
	NSMutableArray<NSString *> *_buildOrder;
	NSMutableDictionary<NSString *, FxGripShaderPendingBuild *> *_pendingBuilds;
}

- (instancetype)init
{
	return [self initWithLimit:0];
}

- (instancetype)initWithLimit:(NSUInteger)limit
{
	self = [super init];
	if (self != nil) {
		_lock = [NSLock new];
		_limit = limit;
		_entries = [NSMutableDictionary new];
		_buildOrder = [NSMutableArray new];
		_pendingBuilds = [NSMutableDictionary new];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_lock);
	NARC_RELEASE(_entries);
	NARC_RELEASE(_buildOrder);
	NARC_RELEASE(_pendingBuilds);
	SUPER_DEALLOC();
}

- (id)entryForKey:(NSString *)key build:(id (^)(void))build
{
	[_lock lock];
	id entry = _entries[key];
	FxGripShaderPendingBuild *pending = nil;
	BOOL builds = NO;
	if (entry == nil) {
		pending = _pendingBuilds[key];
		if (pending == nil) {
			pending = NARC_AUTORELEASE([FxGripShaderPendingBuild new]);
			_pendingBuilds[key] = pending;
			builds = YES;
		}
	}
	[_lock unlock];

	if (entry != nil) {
		return entry;
	}
	if (!builds) {
		dispatch_group_wait(pending.group, DISPATCH_TIME_FOREVER);
		return pending.result;
	}

	id result = build();
	pending.result = result;
	[_lock lock];
	_entries[key] = result;
	if (_limit > 0) {
		[_buildOrder addObject:key];
		while (_buildOrder.count > _limit) {
			[_entries removeObjectForKey:_buildOrder.firstObject];
			[_buildOrder removeObjectAtIndex:0];
		}
	}
	[_pendingBuilds removeObjectForKey:key];
	[_lock unlock];
	dispatch_group_leave(pending.group);
	return result;
}

@end

id _Nullable FxGripShaderEntryOrError(id entry, NSError **error)
{
	if ([entry isKindOfClass:NSError.class]) {
		if (error != NULL) {
			*error = entry;
		}
		return nil;
	}
	return entry;
}

#pragma mark - Converter

/*!
	@abstract	The primaries conversion passes, built from the prelude alone.
	@discussion	Introduced in FxGrip 0.1.0. The prelude compiles once per device and the conversion
				pipeline builds once per device and pixel format, through build caches.
*/
@implementation FxGripShaderConverter
{
	FxGripShaderBuildCache *_libraries;
	FxGripShaderBuildCache *_states;
}

+ (instancetype)sharedConverter
{
	static FxGripShaderConverter *converter = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		converter = [FxGripShaderConverter new];
	});
	return converter;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_libraries = [[FxGripShaderBuildCache alloc] initWithLimit:0];
		_states = [[FxGripShaderBuildCache alloc] initWithLimit:0];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_libraries);
	NARC_RELEASE(_states);
	SUPER_DEALLOC();
}

- (nullable id<MTLLibrary>)libraryForDevice:(id<MTLDevice>)device error:(NSError **)error
{
	NSString *key = [NSString stringWithFormat:@"library|%llu", device.registryID];
	id entry = [_libraries entryForKey:key build:^id {
		NSError *compileError = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:FxGripShaderPrelude options:nil error:&compileError];
		if (library != nil) {
			return NARC_AUTORELEASE(library);
		}
		return FxGripShaderPipelineError(kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The shader prelude fails to compile: %@", compileError.localizedDescription], compileError);
	}];
	return FxGripShaderEntryOrError(entry, error);
}

- (nullable id<MTLRenderPipelineState>)stateForDevice:(id<MTLDevice>)device
										  pixelFormat:(MTLPixelFormat)pixelFormat
												error:(NSError **)error
{
	id<MTLLibrary> library = [self libraryForDevice:device error:error];
	if (library == nil) {
		return nil;
	}
	NSString *key = [NSString stringWithFormat:@"conversion|%llu|%lu", device.registryID, (unsigned long)pixelFormat];
	id entry = [_states entryForKey:key build:^id {
		MTLRenderPipelineDescriptor *descriptor = NARC_AUTORELEASE([MTLRenderPipelineDescriptor new]);
		descriptor.label = kFxGripShaderConvertFunctionName;
		descriptor.vertexFunction = NARC_AUTORELEASE([library newFunctionWithName:kFxGripShaderVertexFunctionName]);
		descriptor.fragmentFunction = NARC_AUTORELEASE([library newFunctionWithName:kFxGripShaderConvertFunctionName]);
		descriptor.colorAttachments[0].pixelFormat = pixelFormat;
		NSError *buildError = nil;
		id<MTLRenderPipelineState> state = NARC_AUTORELEASE([device newRenderPipelineStateWithDescriptor:descriptor error:&buildError]);
		if (state != nil) {
			return state;
		}
		return FxGripShaderPipelineError(kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The primaries conversion pipeline fails to build: %@", buildError.localizedDescription], buildError);
	}];
	return FxGripShaderEntryOrError(entry, error);
}

- (BOOL)encodeConversionFrom:(id<MTLTexture>)source
						  to:(id<MTLTexture>)destination
					  matrix:(simd_float3x3)matrix
					   gamma:(BOOL)gamma
			   commandBuffer:(id<MTLCommandBuffer>)commandBuffer
					   error:(NSError **)error
{
	id<MTLRenderPipelineState> state = [self stateForDevice:commandBuffer.device pixelFormat:destination.pixelFormat error:error];
	if (state == nil) {
		return NO;
	}
	FxGripShaderTile tile = FxGripShaderTextureTile(destination);
	FxGripShaderConversion conversion = { .matrix = matrix, .gamma = gamma ? 1u : 0u };

	id<MTLRenderCommandEncoder> encoder = FxGripShaderRenderEncoder(destination, commandBuffer);
	[encoder setRenderPipelineState:state];
	[encoder setVertexBytes:&tile length:sizeof(tile) atIndex:0];
	[encoder setFragmentTexture:source atIndex:0];
	[encoder setFragmentBytes:&conversion length:sizeof(conversion) atIndex:0];
	[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
	[encoder endEncoding];
	return YES;
}

@end

#pragma mark - Pipeline state

@interface FxGripShaderPipelineState ()
- (instancetype)initWithRenderPipelineState:(id<MTLRenderPipelineState>)renderPipelineState
						  constantSignature:(NSString *)constantSignature
							  uniformLength:(NSUInteger)uniformLength
							 uniformMembers:(NSArray<FxGripShaderUniformMember *> *)uniformMembers
							 textureIndexes:(NSDictionary<NSString *, NSNumber *> *)textureIndexes;
@end

/*!
	@abstract	One built render pipeline and the uniform and texture layout Metal reflection reports for it.
	@discussion	Introduced in FxGrip 0.1.0. The state is immutable once built.
*/
@implementation FxGripShaderPipelineState
{
	NSArray<FxGripShaderUniformMember *> *_uniformMembers;
}

- (instancetype)initWithRenderPipelineState:(id<MTLRenderPipelineState>)renderPipelineState
						  constantSignature:(NSString *)constantSignature
							  uniformLength:(NSUInteger)uniformLength
							 uniformMembers:(NSArray<FxGripShaderUniformMember *> *)uniformMembers
							 textureIndexes:(NSDictionary<NSString *, NSNumber *> *)textureIndexes
{
	self = [super init];
	if (self != nil) {
		_renderPipelineState = NARC_RETAIN(renderPipelineState);
		_constantSignature = [constantSignature copy];
		_uniformLength = uniformLength;
		_uniformMembers = [uniformMembers copy];
		_textureIndexes = [textureIndexes copy];
		NSMutableDictionary<NSString *, NSNumber *> *offsets = [NSMutableDictionary dictionary];
		for (FxGripShaderUniformMember *member in uniformMembers) {
			offsets[member.key] = @(member.offset);
		}
		_uniformOffsets = [offsets copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_renderPipelineState);
	NARC_RELEASE(_constantSignature);
	NARC_RELEASE(_uniformMembers);
	NARC_RELEASE(_uniformOffsets);
	NARC_RELEASE(_textureIndexes);
	SUPER_DEALLOC();
}

- (nullable NSData *)uniformDataForValues:(FxGripShaderValues *)values
{
	if (self.uniformLength == 0) {
		return nil;
	}
	NSMutableData *data = [NSMutableData dataWithLength:self.uniformLength];
	uint8_t *bytes = data.mutableBytes;
	for (FxGripShaderUniformMember *member in _uniformMembers) {
		NSArray<NSNumber *> *components = [values componentsForKey:member.key];
		FxGripShaderWriteComponents(member.scalarType, member.componentCount, components, bytes + member.offset);
	}
	return data;
}

@end

#pragma mark - Pipeline

/*!
	@abstract	Compiles a shader source, caches its pipelines per constant set, and renders a tile.
	@discussion	Introduced in FxGrip 0.1.0. The library and state caches build outside their locks. A
				caller that asks for a key under construction waits for that build, and a caller
				that asks for any other key proceeds.
*/
@implementation FxGripShaderPipeline
{
	NSArray<NSString *> *_constantKeys;
	NSSet<NSString *> *_pixelUnitKeys;
	FxGripShaderBuildCache *_libraries;
	FxGripShaderBuildCache *_states;
}

+ (instancetype)sharedPipelineWithSource:(NSString *)source
								metadata:(FxGripShaderMetadata *)metadata
					fragmentFunctionName:(NSString *)fragmentFunctionName
{
	static NSMutableDictionary<NSArray<NSString *> *, FxGripShaderPipeline *> *pipelines = nil;
	static os_unfair_lock pipelinesLock = OS_UNFAIR_LOCK_INIT;
	NSArray<NSString *> *key = @[fragmentFunctionName, source];

	os_unfair_lock_lock(&pipelinesLock);
	if (pipelines == nil) {
		pipelines = [NSMutableDictionary new];
	}
	FxGripShaderPipeline *pipeline = pipelines[key];
	if (pipeline == nil) {
		pipeline = NARC_AUTORELEASE([[self alloc] initWithSource:source metadata:metadata fragmentFunctionName:fragmentFunctionName]);
		pipelines[key] = pipeline;
	}
	os_unfair_lock_unlock(&pipelinesLock);
	return pipeline;
}

+ (NSString *)preludeSource
{
	return FxGripShaderPrelude;
}

- (instancetype)initWithSource:(NSString *)source
					  metadata:(FxGripShaderMetadata *)metadata
		  fragmentFunctionName:(NSString *)fragmentFunctionName
{
	self = [super init];
	if (self != nil) {
		_source = [source copy];
		_metadata = NARC_RETAIN(metadata);
		_fragmentFunctionName = [fragmentFunctionName copy];
		_libraries = [[FxGripShaderBuildCache alloc] initWithLimit:0];
		_states = [[FxGripShaderBuildCache alloc] initWithLimit:kFxGripShaderPipelineStateCacheLimit];
		_constantKeys = [FxGripShaderConstantKeys(metadata) copy];
		_pixelUnitKeys = [FxGripShaderPixelUnitKeys(metadata) copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_source);
	NARC_RELEASE(_metadata);
	NARC_RELEASE(_fragmentFunctionName);
	NARC_RELEASE(_constantKeys);
	NARC_RELEASE(_pixelUnitKeys);
	NARC_RELEASE(_libraries);
	NARC_RELEASE(_states);
	SUPER_DEALLOC();
}

#pragma mark Constants

- (NSString *)constantSignatureForValues:(FxGripShaderValues *)values
{
	return FxGripShaderConstantSignature(_constantKeys, values);
}

- (nullable MTLFunctionConstantValues *)constantValuesForFunction:(id<MTLFunction>)function
														   values:(FxGripShaderValues *)values
															error:(NSError **)error
{
	MTLFunctionConstantValues *constantValues = NARC_AUTORELEASE([MTLFunctionConstantValues new]);
	NSDictionary<NSString *, MTLFunctionConstant *> *declared = function.functionConstantsDictionary;
	// Metal specializes a function with an unset required constant without an error, so the pipeline refuses it.
	for (NSString *name in declared) {
		if (declared[name].required && ![_constantKeys containsObject:name]) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The function constant \"%@\" is bound by no constant parameter.", name], nil);
			return nil;
		}
	}
	for (NSString *key in _constantKeys) {
		MTLFunctionConstant *constant = declared[key];
		NSArray<NSNumber *> *components = [values componentsForKey:key];
		if (constant == nil) {
			continue;
		}
		if (components == nil) {
			if (constant.required) {
				FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
					@"The function constant \"%@\" has no value.", key], nil);
				return nil;
			}
			continue;
		}
		NSDictionary *record = [self.metadata parameterForKey:key];
		MTLDataType scalar = MTLDataTypeNone;
		NSUInteger count = 0;
		if (!FxGripShaderScalarType(constant.type, &scalar, &count)) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The function constant \"%@\" has a type no parameter can set.", key], nil);
			return nil;
		}
		NSUInteger expected = FxGripShaderComponentCountForType(record.parameterType);
		if (count != expected) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The function constant \"%@\" has %lu components and parameter %d binds %lu.",
				key, (unsigned long)count, record.parameterID, (unsigned long)expected], nil);
			return nil;
		}
		uint8_t bytes[16] = { 0 };
		FxGripShaderWriteComponents(scalar, count, components, bytes);
		[constantValues setConstantValue:bytes type:constant.type withName:key];
	}
	return constantValues;
}

#pragma mark Library

- (NSString *)compiledSource
{
	return [FxGripShaderPrelude stringByAppendingString:self.source];
}

- (nullable id<MTLLibrary>)libraryForDevice:(id<MTLDevice>)device error:(NSError * _Nullable *)error
{
	NSString *key = [NSString stringWithFormat:@"library|%llu", device.registryID];
	id entry = [_libraries entryForKey:key build:^id {
		NSError *compileError = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:[self compiledSource] options:nil error:&compileError];
		if (library != nil) {
			return NARC_AUTORELEASE(library);
		}
		return FxGripShaderPipelineError(kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The shader source fails to compile: %@", compileError.localizedDescription], compileError);
	}];
	return FxGripShaderEntryOrError(entry, error);
}

#pragma mark Pipeline states

- (nullable FxGripShaderPipelineState *)stateForDevice:(id<MTLDevice>)device
										   pixelFormat:(MTLPixelFormat)pixelFormat
												values:(FxGripShaderValues *)values
												 error:(NSError * _Nullable *)error
{
	NSString *signature = [self constantSignatureForValues:values];
	NSString *key = [NSString stringWithFormat:@"state|%llu|%lu|%@", device.registryID, (unsigned long)pixelFormat, signature];
	id entry = [_states entryForKey:key build:^id {
		NSError *failure = nil;
		FxGripShaderPipelineState *state = [self buildStateForDevice:device pixelFormat:pixelFormat values:values signature:signature error:&failure];
		return state ?: failure;
	}];
	return FxGripShaderEntryOrError(entry, error);
}

- (nullable FxGripShaderPipelineState *)buildStateForDevice:(id<MTLDevice>)device
												pixelFormat:(MTLPixelFormat)pixelFormat
													 values:(FxGripShaderValues *)values
												  signature:(NSString *)signature
													  error:(NSError **)error
{
	id<MTLLibrary> library = [self libraryForDevice:device error:error];
	if (library == nil) {
		return nil;
	}
	id<MTLFunction> fragment = [self fragmentFunctionInLibrary:library values:values error:error];
	if (fragment == nil) {
		return nil;
	}

	MTLRenderPipelineDescriptor *descriptor = NARC_AUTORELEASE([MTLRenderPipelineDescriptor new]);
	descriptor.label = self.fragmentFunctionName;
	descriptor.vertexFunction = NARC_AUTORELEASE([library newFunctionWithName:kFxGripShaderVertexFunctionName]);
	descriptor.fragmentFunction = fragment;
	descriptor.colorAttachments[0].pixelFormat = pixelFormat;

	NSError *buildError = nil;
	MTLAutoreleasedRenderPipelineReflection reflection = nil;
	id<MTLRenderPipelineState> renderPipelineState = NARC_AUTORELEASE([device newRenderPipelineStateWithDescriptor:descriptor
																										   options:MTLPipelineOptionBindingInfo
																										reflection:&reflection
																											 error:&buildError]);
	if (renderPipelineState == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The shader pipeline fails to build: %@", buildError.localizedDescription], buildError);
		return nil;
	}
	NSUInteger uniformLength = 0;
	NSArray<FxGripShaderUniformMember *> *members = [self uniformMembersInReflection:reflection length:&uniformLength error:error];
	if (members == nil) {
		return nil;
	}
	NSDictionary<NSString *, NSNumber *> *textureIndexes = [self textureIndexesInReflection:reflection error:error];
	if (textureIndexes == nil) {
		return nil;
	}
	return NARC_AUTORELEASE([[FxGripShaderPipelineState alloc] initWithRenderPipelineState:renderPipelineState
																		 constantSignature:signature
																			 uniformLength:uniformLength
																			uniformMembers:members
																			textureIndexes:textureIndexes]);
}

- (nullable id<MTLFunction>)fragmentFunctionInLibrary:(id<MTLLibrary>)library
											   values:(FxGripShaderValues *)values
												error:(NSError **)error
{
	id<MTLFunction> generic = NARC_AUTORELEASE([library newFunctionWithName:self.fragmentFunctionName]);
	if (generic == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The shader source has no function named \"%@\".", self.fragmentFunctionName], nil);
		return nil;
	}
	if (generic.functionConstantsDictionary.count == 0) {
		return generic;
	}

	MTLFunctionConstantValues *constantValues = [self constantValuesForFunction:generic values:values error:error];
	if (constantValues == nil) {
		return nil;
	}
	NSError *specializeError = nil;
	id<MTLFunction> specialized = [library newFunctionWithName:self.fragmentFunctionName
												constantValues:constantValues
														 error:&specializeError];
	if (specialized == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The function \"%@\" fails to specialize: %@", self.fragmentFunctionName, specializeError.localizedDescription], specializeError);
		return nil;
	}
	return NARC_AUTORELEASE(specialized);
}

/*! The bound members of the uniform struct at the uniform buffer index; an empty array when the fragment function reads none. */
- (nullable NSArray<FxGripShaderUniformMember *> *)uniformMembersInReflection:(MTLRenderPipelineReflection *)reflection
																	   length:(NSUInteger *)length
																		error:(NSError **)error
{
	*length = 0;
	for (id<MTLBinding> binding in reflection.fragmentBindings) {
		if (binding.type != MTLBindingTypeBuffer || binding.index != kFxGripShaderUniformBufferIndex) {
			continue;
		}
		id<MTLBufferBinding> bufferBinding = (id<MTLBufferBinding>)binding;
		if (bufferBinding.bufferDataType != MTLDataTypeStruct) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"Fragment buffer %d is not a struct.", kFxGripShaderUniformBufferIndex], nil);
			return nil;
		}
		*length = bufferBinding.bufferDataSize;
		return [self uniformMembersOfStruct:bufferBinding.bufferStructType error:error];
	}
	return @[];
}

- (nullable NSArray<FxGripShaderUniformMember *> *)uniformMembersOfStruct:(MTLStructType *)structType error:(NSError **)error
{
	NSMutableArray<FxGripShaderUniformMember *> *members = [NSMutableArray array];
	for (MTLStructMember *structMember in structType.members) {
		NSDictionary *record = [self.metadata parameterForKey:structMember.name];
		if (record == nil || [record[kFxGripShaderProperty_Constant] boolValue]) {
			continue;
		}
		NSUInteger expected = FxGripShaderComponentCountForType(record.parameterType);
		if (expected == 0) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"Parameter %d has a type that binds to no uniform member.", record.parameterID], nil);
			return nil;
		}
		MTLDataType scalar = MTLDataTypeNone;
		NSUInteger count = 0;
		if (!FxGripShaderScalarType(structMember.dataType, &scalar, &count) || count != expected) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The uniform member \"%@\" needs a scalar or vector of %lu components for parameter %d.",
				structMember.name, (unsigned long)expected, record.parameterID], nil);
			return nil;
		}
		FxGripShaderUniformMember *member = NARC_AUTORELEASE([FxGripShaderUniformMember new]);
		member.key = structMember.name;
		member.offset = structMember.offset;
		member.scalarType = scalar;
		member.componentCount = count;
		[members addObject:member];
	}
	return members;
}

/*! The texture index of each fragment texture argument named by an image or gradient parameter's key. */
- (nullable NSDictionary<NSString *, NSNumber *> *)textureIndexesInReflection:(MTLRenderPipelineReflection *)reflection
																		error:(NSError **)error
{
	NSMutableDictionary<NSString *, NSNumber *> *indexes = [NSMutableDictionary dictionary];
	for (id<MTLBinding> binding in reflection.fragmentBindings) {
		if (binding.type != MTLBindingTypeTexture) {
			continue;
		}
		NSDictionary *record = [self.metadata parameterForKey:binding.name];
		if (record == nil) {
			continue;
		}
		FxParameterType type = record.parameterType;
		if (type != FxParameterType_ImageRef && type != FxParameterType_Gradient) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"Parameter %d has a type that binds to no texture.", record.parameterID], nil);
			return nil;
		}
		if (((id<MTLTextureBinding>)binding).textureType != MTLTextureType2D) {
			FxGripShaderFail(error, kFxGripError_ShaderBindingInvalid, [NSString stringWithFormat:
				@"The texture \"%@\" needs to be a texture2d for parameter %d.", binding.name, record.parameterID], nil);
			return nil;
		}
		indexes[binding.name] = @(binding.index);
	}
	return indexes;
}

#pragma mark Primaries conversion

- (BOOL)convertsFromHostPrimaries:(FxColorPrimaries)hostPrimaries
{
	FxColorPrimaries shaderPrimaries = kFxColorPrimaries_Rec709;
	if (!FxGripShaderFxColorPrimaries(self.metadata.primaries, &shaderPrimaries)) {
		return NO;
	}
	return shaderPrimaries != hostPrimaries;
}

#pragma mark Rendering

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
						values:(FxGripShaderValues *)values
				 hostPrimaries:(FxColorPrimaries)hostPrimaries
					 colorInfo:(FxImageColorInfo)colorInfo
						 error:(NSError * _Nullable *)error
{
	return [self renderDestinationImage:destinationImage
						   sourceImages:sourceImages
						  keyedTextures:nil
								 values:values
						  hostPrimaries:hostPrimaries
							  colorInfo:colorInfo
								  error:error];
}

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
				 keyedTextures:(nullable NSDictionary<NSString *, id<MTLTexture>> *)keyedTextures
						values:(FxGripShaderValues *)values
				 hostPrimaries:(FxColorPrimaries)hostPrimaries
					 colorInfo:(FxImageColorInfo)colorInfo
						 error:(NSError * _Nullable *)error
{
	id<MTLDevice> device = [FxGripMTLDeviceCache metalDeviceFromID:destinationImage.deviceRegistryID];
	if (device == nil) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The destination tile's Metal device is unavailable.", nil);
	}
	id<MTLTexture> outputTexture = [destinationImage metalTextureForDevice:device];
	if (outputTexture == nil) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The destination tile has no Metal texture.", nil);
	}
	simd_float2 pixelScale = FxGripShaderPixelScale(destinationImage.pixelTransform);
	FxGripShaderValues *boundValues = FxGripShaderValuesScaledToPixels(values, _pixelUnitKeys, pixelScale.x);
	FxGripShaderPipelineState *state = [self stateForDevice:device pixelFormat:outputTexture.pixelFormat values:boundValues error:error];
	if (state == nil) {
		return NO;
	}

	NSMutableArray<id<MTLTexture>> *sourceTextures = [NSMutableArray arrayWithCapacity:sourceImages.count];
	for (FxImageTile *sourceImage in sourceImages) {
		id<MTLTexture> texture = [sourceImage metalTextureForDevice:device];
		if (texture == nil) {
			return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, [NSString stringWithFormat:
				@"Source image %lu has no Metal texture.", (unsigned long)sourceTextures.count], nil);
		}
		[sourceTextures addObject:texture];
	}

	NSMutableDictionary<NSNumber *, id<MTLTexture>> *boundTextures = [NSMutableDictionary dictionary];
	NSMutableDictionary<NSNumber *, FxImageTile *> *boundTiles = [NSMutableDictionary dictionary];
	for (NSUInteger index = 0; index < sourceTextures.count; index++) {
		boundTextures[@(index)] = sourceTextures[index];
		boundTiles[@(index)] = sourceImages[index];
	}
	id<MTLTexture> emptyTexture = nil;
	for (NSString *key in state.textureIndexes) {
		NSNumber *index = state.textureIndexes[key];
		NSDictionary *record = [self.metadata parameterForKey:key];
		id<MTLTexture> texture = nil;
		FxImageTile *tile = nil;
		if (record.parameterType == FxParameterType_ImageRef) {
			for (NSUInteger source = 0; source < sourceImages.count; source++) {
				if (sourceImages[source].parameterID == record.parameterID) {
					texture = sourceTextures[source];
					tile = sourceImages[source];
					break;
				}
			}
		} else {
			texture = keyedTextures[key];
		}
		if (texture == nil) {
			if (emptyTexture == nil) {
				emptyTexture = FxGripShaderEmptyTexture(device);
			}
			texture = emptyTexture;
		}
		boundTextures[index] = texture;
		if (tile != nil) {
			boundTiles[index] = tile;
		} else {
			[boundTiles removeObjectForKey:index];
		}
	}

	FxGripMTLCommandQueue *commandQueue = [FxGripMTLDeviceCache scopedCommandQueueForImageTile:destinationImage];
	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
	if (commandBuffer == nil) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"No Metal command queue is available for the destination tile.", nil);
	}
	commandBuffer.label = self.fragmentFunctionName;

	BOOL converts = [self convertsFromHostPrimaries:hostPrimaries];
	BOOL gamma = (colorInfo == kFxImageColorInfo_RGB_GAMMA_VIDEO);
	FxColorPrimaries shaderPrimaries = hostPrimaries;
	FxGripShaderFxColorPrimaries(self.metadata.primaries, &shaderPrimaries);

	FxGripShaderConverter *converter = FxGripShaderConverter.sharedConverter;
	id<MTLTexture> target = outputTexture;
	if (converts) {
		simd_float3x3 toShader = FxGripGamutConversionMatrix(hostPrimaries, shaderPrimaries);
		NSMapTable<id<MTLTexture>, id<MTLTexture>> *converted = [NSMapTable strongToStrongObjectsMapTable];
		for (NSNumber *index in boundTextures.allKeys) {
			id<MTLTexture> texture = boundTextures[index];
			if (texture == emptyTexture) {
				continue;
			}
			id<MTLTexture> conversion = [converted objectForKey:texture];
			if (conversion == nil) {
				conversion = FxGripShaderIntermediateTexture(texture, MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead, device);
				if (conversion == nil) {
					return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The primaries conversion texture fails to allocate.", nil);
				}
				if (![converter encodeConversionFrom:texture to:conversion matrix:toShader gamma:gamma commandBuffer:commandBuffer error:error]) {
					return NO;
				}
				[converted setObject:conversion forKey:texture];
			}
			boundTextures[index] = conversion;
		}
		target = FxGripShaderIntermediateTexture(outputTexture, MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead, device);
		if (target == nil) {
			return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The primaries conversion texture fails to allocate.", nil);
		}
	}

	NSUInteger textureCount = 0;
	for (NSNumber *index in boundTextures) {
		textureCount = MAX(textureCount, index.unsignedIntegerValue + 1);
	}
	FxGripShaderTile tile = FxGripShaderMakeTile(destinationImage, boundTiles, textureCount, pixelScale);

	id<MTLRenderCommandEncoder> encoder = FxGripShaderRenderEncoder(target, commandBuffer);
	[encoder setRenderPipelineState:state.renderPipelineState];
	[encoder setVertexBytes:&tile length:sizeof(tile) atIndex:0];
	[encoder setFragmentBytes:&tile length:sizeof(tile) atIndex:kFxGripShaderTileBufferIndex];
	for (NSNumber *index in boundTextures) {
		[encoder setFragmentTexture:boundTextures[index] atIndex:index.unsignedIntegerValue];
	}
	NSData *uniforms = [state uniformDataForValues:boundValues];
	if (uniforms.length > kFxGripShaderInlineUniformLimit) {
		id<MTLBuffer> buffer = NARC_AUTORELEASE([device newBufferWithBytes:uniforms.bytes length:uniforms.length options:MTLResourceStorageModeShared]);
		[encoder setFragmentBuffer:buffer offset:0 atIndex:kFxGripShaderUniformBufferIndex];
	} else if (uniforms != nil) {
		[encoder setFragmentBytes:uniforms.bytes length:uniforms.length atIndex:kFxGripShaderUniformBufferIndex];
	}
	[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
	[encoder endEncoding];

	if (converts) {
		simd_float3x3 toHost = FxGripGamutConversionMatrix(shaderPrimaries, hostPrimaries);
		if (![converter encodeConversionFrom:target to:outputTexture matrix:toHost gamma:gamma commandBuffer:commandBuffer error:error]) {
			return NO;
		}
	}

	[commandBuffer commit];
	[commandBuffer waitUntilCompleted];
	if (commandBuffer.status == MTLCommandBufferStatusError) {
		return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, [NSString stringWithFormat:
			@"The shader command buffer fails: %@", commandBuffer.error.localizedDescription], commandBuffer.error);
	}
	return YES;
}

@end
