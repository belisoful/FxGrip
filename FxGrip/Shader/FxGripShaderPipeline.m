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
*/

#import "FxGripShaderPipeline.h"
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

/*! The largest uniform struct bound with setFragmentBytes; a larger one goes in a buffer. */
#define kFxGripShaderInlineUniformLimit		(4096)

/*! The vertex-stage geometry: each bound is left, bottom, right, top in image pixels. */
typedef struct {
	simd_float4 destinationBounds;
	simd_float4 sourceBounds;
} FxGripShaderTileGeometry;

/*! The conversion pass uniform; matches FxGripShaderConversion in the prelude. */
typedef struct {
	simd_float3x3 matrix;
	uint32_t gamma;
} FxGripShaderConversion;

static NSString * const FxGripShaderPrelude =
	@"#include <metal_stdlib>\n"
	@"using namespace metal;\n"
	@"\n"
	@"struct FxGripShaderVertexOut {\n"
	@"    float4 position [[position]];\n"
	@"    float2 texCoord;\n"
	@"    float2 imagePixel;\n"
	@"};\n"
	@"\n"
	@"struct FxGripShaderTileGeometry {\n"
	@"    float4 destinationBounds;\n"
	@"    float4 sourceBounds;\n"
	@"};\n"
	@"\n"
	@"struct FxGripShaderConversion {\n"
	@"    float3x3 matrix;\n"
	@"    uint gamma;\n"
	@"};\n"
	@"\n"
	@"vertex FxGripShaderVertexOut fxGripShaderVertex(uint vertexID [[vertex_id]],\n"
	@"                                                constant FxGripShaderTileGeometry &geometry [[buffer(0)]])\n"
	@"{\n"
	@"    float2 corner = float2(float(vertexID & 1u), float(vertexID >> 1u));\n"
	@"    float4 d = geometry.destinationBounds;\n"
	@"    float4 s = geometry.sourceBounds;\n"
	@"    float2 imagePixel = float2(mix(d.x, d.z, corner.x), mix(d.w, d.y, corner.y));\n"
	@"    FxGripShaderVertexOut out;\n"
	@"    out.position = float4(corner.x * 2.0 - 1.0, 1.0 - corner.y * 2.0, 0.0, 1.0);\n"
	@"    out.imagePixel = imagePixel;\n"
	@"    out.texCoord = float2((imagePixel.x - s.x) / (s.z - s.x), (s.w - imagePixel.y) / (s.w - s.y));\n"
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

/*! Resolves a Metal scalar or vector type to its scalar type and component count; NO for any other type. */
static BOOL FxGripShaderScalarType(MTLDataType type, MTLDataType *scalar, NSUInteger *count)
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

/*! Writes up to count components of a Metal scalar or vector type; components with no value stay as they are. */
static void FxGripShaderWriteComponents(MTLDataType scalar, NSUInteger count, NSArray<NSNumber *> *components, uint8_t *destination)
{
	NSUInteger size = FxGripShaderScalarSize(scalar);
	NSUInteger written = MIN(count, components.count);
	for (NSUInteger index = 0; index < written; index++) {
		FxGripShaderWriteScalar(scalar, components[index].doubleValue, destination + index * size);
	}
}

static BOOL FxGripShaderFxColorPrimaries(FxGripShaderPrimaries primaries, FxColorPrimaries *colorPrimaries)
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

static FxGripShaderTileGeometry FxGripShaderGeometry(FxRect destination, FxRect source)
{
	FxGripShaderTileGeometry geometry;
	geometry.destinationBounds = simd_make_float4(destination.left, destination.bottom, destination.right, destination.top);
	geometry.sourceBounds = simd_make_float4(source.left, source.bottom, source.right, source.top);
	return geometry;
}

static FxRect FxGripShaderTextureRect(id<MTLTexture> texture)
{
	return (FxRect){ 0, 0, (SInt32)texture.width, (SInt32)texture.height };
}

static NSError *FxGripShaderPipelineError(NSInteger code, NSString *reason, NSError *underlying)
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = reason;
	userInfo[NSLocalizedFailureReasonErrorKey] = reason;
	if (underlying != nil) {
		userInfo[NSUnderlyingErrorKey] = underlying;
	}
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code userInfo:userInfo];
}

static BOOL FxGripShaderFail(NSError **error, NSInteger code, NSString *reason, NSError *underlying)
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

#pragma mark - Pipeline state

@interface FxGripShaderPipelineState ()
- (instancetype)initWithRenderPipelineState:(id<MTLRenderPipelineState>)renderPipelineState
						  constantSignature:(NSString *)constantSignature
							  uniformLength:(NSUInteger)uniformLength
							 uniformMembers:(NSArray<FxGripShaderUniformMember *> *)uniformMembers;
@end

/*!
	@abstract	One built render pipeline and the uniform layout Metal reflection reports for it.
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
{
	self = [super init];
	if (self != nil) {
		_renderPipelineState = NARC_RETAIN(renderPipelineState);
		_constantSignature = [constantSignature copy];
		_uniformLength = uniformLength;
		_uniformMembers = [uniformMembers copy];
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
	@discussion	Introduced in FxGrip 0.1.0. One recursive lock guards the library, state, and
				conversion caches. A cache miss compiles under the lock, so concurrent renders of an
				uncompiled shader wait for one compile.
*/
@implementation FxGripShaderPipeline
{
	NSRecursiveLock *_cacheLock;
	NSArray<NSString *> *_constantKeys;
	NSMutableDictionary<NSNumber *, id> *_libraries;
	NSMutableDictionary<NSString *, id> *_states;
	NSMutableArray<NSString *> *_stateBuildOrder;
	NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_conversionStates;
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
		_cacheLock = [NSRecursiveLock new];
		_libraries = [NSMutableDictionary new];
		_states = [NSMutableDictionary new];
		_stateBuildOrder = [NSMutableArray new];
		_conversionStates = [NSMutableDictionary new];

		NSMutableArray<NSString *> *constantKeys = [NSMutableArray array];
		for (NSDictionary *record in metadata.allParameters) {
			if ([record[kFxGripShaderProperty_Constant] boolValue]) {
				[constantKeys addObject:record[kFxGripShaderProperty_Key]];
			}
		}
		_constantKeys = [[constantKeys sortedArrayUsingSelector:@selector(compare:)] copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_source);
	NARC_RELEASE(_metadata);
	NARC_RELEASE(_fragmentFunctionName);
	NARC_RELEASE(_cacheLock);
	NARC_RELEASE(_constantKeys);
	NARC_RELEASE(_libraries);
	NARC_RELEASE(_states);
	NARC_RELEASE(_stateBuildOrder);
	NARC_RELEASE(_conversionStates);
	SUPER_DEALLOC();
}

#pragma mark Constants

- (NSString *)constantSignatureForValues:(FxGripShaderValues *)values
{
	NSMutableArray<NSString *> *entries = [NSMutableArray arrayWithCapacity:_constantKeys.count];
	for (NSString *key in _constantKeys) {
		NSMutableArray<NSString *> *components = [NSMutableArray array];
		for (NSNumber *component in [values componentsForKey:key]) {
			[components addObject:[NSString stringWithFormat:@"%.17g", component.doubleValue]];
		}
		[entries addObject:[NSString stringWithFormat:@"%@=%@", key, [components componentsJoinedByString:@","]]];
	}
	return [entries componentsJoinedByString:@";"];
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
	NSNumber *key = @(device.registryID);
	[_cacheLock lock];
	id entry = _libraries[key];
	if (entry == nil) {
		NSError *compileError = nil;
		id<MTLLibrary> library = [device newLibraryWithSource:[self compiledSource] options:nil error:&compileError];
		if (library != nil) {
			entry = NARC_AUTORELEASE(library);
		} else {
			entry = FxGripShaderPipelineError(kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
				@"The shader source fails to compile: %@", compileError.localizedDescription], compileError);
		}
		_libraries[key] = entry;
	}
	[_cacheLock unlock];

	if ([entry isKindOfClass:NSError.class]) {
		if (error != NULL) {
			*error = entry;
		}
		return nil;
	}
	return entry;
}

#pragma mark Pipeline states

- (nullable FxGripShaderPipelineState *)stateForDevice:(id<MTLDevice>)device
										   pixelFormat:(MTLPixelFormat)pixelFormat
												values:(FxGripShaderValues *)values
												 error:(NSError * _Nullable *)error
{
	NSString *signature = [self constantSignatureForValues:values];
	NSString *key = [NSString stringWithFormat:@"%llu|%lu|%@", device.registryID, (unsigned long)pixelFormat, signature];

	[_cacheLock lock];
	id entry = _states[key];
	if (entry == nil) {
		NSError *failure = nil;
		entry = [self buildStateForDevice:device pixelFormat:pixelFormat values:values signature:signature error:&failure];
		if (entry == nil) {
			entry = failure;
		}
		[self cacheState:entry forKey:key];
	}
	[_cacheLock unlock];

	if ([entry isKindOfClass:NSError.class]) {
		if (error != NULL) {
			*error = entry;
		}
		return nil;
	}
	return entry;
}

/*! Stores a state or its build error, evicting the oldest entry past the cache limit. Runs under the cache lock. */
- (void)cacheState:(id)entry forKey:(NSString *)key
{
	_states[key] = entry;
	[_stateBuildOrder addObject:key];
	while (_stateBuildOrder.count > kFxGripShaderPipelineStateCacheLimit) {
		[_states removeObjectForKey:_stateBuildOrder.firstObject];
		[_stateBuildOrder removeObjectAtIndex:0];
	}
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
	return NARC_AUTORELEASE([[FxGripShaderPipelineState alloc] initWithRenderPipelineState:renderPipelineState
																		 constantSignature:signature
																			 uniformLength:uniformLength
																			uniformMembers:members]);
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

#pragma mark Primaries conversion

- (BOOL)convertsFromHostPrimaries:(FxColorPrimaries)hostPrimaries
{
	FxColorPrimaries shaderPrimaries = kFxColorPrimaries_Rec709;
	if (!FxGripShaderFxColorPrimaries(self.metadata.primaries, &shaderPrimaries)) {
		return NO;
	}
	return shaderPrimaries != hostPrimaries;
}

- (nullable id<MTLRenderPipelineState>)conversionStateForDevice:(id<MTLDevice>)device
													pixelFormat:(MTLPixelFormat)pixelFormat
														  error:(NSError **)error
{
	id<MTLLibrary> library = [self libraryForDevice:device error:error];
	if (library == nil) {
		return nil;
	}
	NSString *key = [NSString stringWithFormat:@"%llu|%lu", device.registryID, (unsigned long)pixelFormat];
	[_cacheLock lock];
	id<MTLRenderPipelineState> state = _conversionStates[key];
	NSError *buildError = nil;
	if (state == nil) {
		MTLRenderPipelineDescriptor *descriptor = NARC_AUTORELEASE([MTLRenderPipelineDescriptor new]);
		descriptor.label = kFxGripShaderConvertFunctionName;
		descriptor.vertexFunction = NARC_AUTORELEASE([library newFunctionWithName:kFxGripShaderVertexFunctionName]);
		descriptor.fragmentFunction = NARC_AUTORELEASE([library newFunctionWithName:kFxGripShaderConvertFunctionName]);
		descriptor.colorAttachments[0].pixelFormat = pixelFormat;
		state = NARC_AUTORELEASE([device newRenderPipelineStateWithDescriptor:descriptor error:&buildError]);
		if (state != nil) {
			_conversionStates[key] = state;
		}
	}
	[_cacheLock unlock];
	if (state == nil) {
		FxGripShaderFail(error, kFxGripError_ShaderCompileFailed, [NSString stringWithFormat:
			@"The primaries conversion pipeline fails to build: %@", buildError.localizedDescription], buildError);
	}
	return state;
}

- (nullable id<MTLTexture>)intermediateTextureLike:(id<MTLTexture>)texture device:(id<MTLDevice>)device
{
	MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:texture.pixelFormat
																						  width:texture.width
																						 height:texture.height
																					  mipmapped:NO];
	descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	descriptor.storageMode = MTLStorageModePrivate;
	return NARC_AUTORELEASE([device newTextureWithDescriptor:descriptor]);
}

- (BOOL)encodeConversionFrom:(id<MTLTexture>)source
						  to:(id<MTLTexture>)destination
					  matrix:(simd_float3x3)matrix
					   gamma:(BOOL)gamma
			   commandBuffer:(id<MTLCommandBuffer>)commandBuffer
					   error:(NSError **)error
{
	id<MTLRenderPipelineState> state = [self conversionStateForDevice:commandBuffer.device pixelFormat:destination.pixelFormat error:error];
	if (state == nil) {
		return NO;
	}
	FxRect bounds = FxGripShaderTextureRect(destination);
	FxGripShaderTileGeometry geometry = FxGripShaderGeometry(bounds, bounds);
	FxGripShaderConversion conversion = { .matrix = matrix, .gamma = gamma ? 1u : 0u };

	id<MTLRenderCommandEncoder> encoder = [self encoderForTarget:destination commandBuffer:commandBuffer];
	[encoder setRenderPipelineState:state];
	[encoder setVertexBytes:&geometry length:sizeof(geometry) atIndex:0];
	[encoder setFragmentTexture:source atIndex:0];
	[encoder setFragmentBytes:&conversion length:sizeof(conversion) atIndex:0];
	[encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
	[encoder endEncoding];
	return YES;
}

#pragma mark Rendering

- (id<MTLRenderCommandEncoder>)encoderForTarget:(id<MTLTexture>)target commandBuffer:(id<MTLCommandBuffer>)commandBuffer
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

- (BOOL)renderDestinationImage:(FxImageTile *)destinationImage
				  sourceImages:(nullable NSArray<FxImageTile *> *)sourceImages
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
	FxGripShaderPipelineState *state = [self stateForDevice:device pixelFormat:outputTexture.pixelFormat values:values error:error];
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

	id<MTLTexture> target = outputTexture;
	if (converts) {
		simd_float3x3 toShader = FxGripGamutConversionMatrix(hostPrimaries, shaderPrimaries);
		for (NSUInteger index = 0; index < sourceTextures.count; index++) {
			id<MTLTexture> converted = [self intermediateTextureLike:sourceTextures[index] device:device];
			if (converted == nil) {
				return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The primaries conversion texture fails to allocate.", nil);
			}
			if (![self encodeConversionFrom:sourceTextures[index] to:converted matrix:toShader gamma:gamma commandBuffer:commandBuffer error:error]) {
				return NO;
			}
			sourceTextures[index] = converted;
		}
		target = [self intermediateTextureLike:outputTexture device:device];
		if (target == nil) {
			return FxGripShaderFail(error, kFxGripError_ShaderRenderFailed, @"The primaries conversion texture fails to allocate.", nil);
		}
	}

	FxRect sourceBounds = sourceImages.count > 0 ? sourceImages[0].tilePixelBounds : destinationImage.tilePixelBounds;
	FxGripShaderTileGeometry geometry = FxGripShaderGeometry(destinationImage.tilePixelBounds, sourceBounds);
	id<MTLRenderCommandEncoder> encoder = [self encoderForTarget:target commandBuffer:commandBuffer];
	[encoder setRenderPipelineState:state.renderPipelineState];
	[encoder setVertexBytes:&geometry length:sizeof(geometry) atIndex:0];
	for (NSUInteger index = 0; index < sourceTextures.count; index++) {
		[encoder setFragmentTexture:sourceTextures[index] atIndex:index];
	}
	NSData *uniforms = [state uniformDataForValues:values];
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
		if (![self encodeConversionFrom:target to:outputTexture matrix:toHost gamma:gamma commandBuffer:commandBuffer error:error]) {
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
