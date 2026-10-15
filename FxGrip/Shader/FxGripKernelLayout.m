/*!
	@file       FxGripKernelLayout.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelLayout
	@abstract   Implements the reflection JSON binder: parsing, role assignment, and validation.
	@discussion Introduced in FxGrip 0.1.0. A private reader walks the JSON's version, entry points,
	            and global parameters, assigns each global its role from its binding kind and type,
	            and stops at the first rule the contract breaks. The layout is immutable once read.
*/

#import "FxGripKernelLayout.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

#define kFxGripKernelJSONVersion				@"version"
#define kFxGripKernelJSONParameters				@"parameters"
#define kFxGripKernelJSONEntryPoints			@"entryPoints"
#define kFxGripKernelJSONName					@"name"
#define kFxGripKernelJSONStage					@"stage"
#define kFxGripKernelJSONThreadGroupSize		@"threadGroupSize"
#define kFxGripKernelJSONBinding				@"binding"
#define kFxGripKernelJSONKind					@"kind"
#define kFxGripKernelJSONIndex					@"index"
#define kFxGripKernelJSONOffset					@"offset"
#define kFxGripKernelJSONSize					@"size"
#define kFxGripKernelJSONType					@"type"
#define kFxGripKernelJSONElementType			@"elementType"
#define kFxGripKernelJSONElementCount			@"elementCount"
#define kFxGripKernelJSONScalarType				@"scalarType"
#define kFxGripKernelJSONFields					@"fields"
#define kFxGripKernelJSONSizes					@"sizes"
#define kFxGripKernelJSONValue					@"value"
#define kFxGripKernelJSONBaseShape				@"baseShape"
#define kFxGripKernelJSONAccess					@"access"

#define kFxGripKernelKindConstantBuffer			@"constantBuffer"
#define kFxGripKernelKindShaderResource			@"shaderResource"
#define kFxGripKernelKindSamplerState			@"samplerState"
#define kFxGripKernelKindSpecializationConstant	@"specializationConstant"
#define kFxGripKernelKindUniform				@"uniform"
#define kFxGripKernelKindStruct					@"struct"
#define kFxGripKernelKindScalar					@"scalar"
#define kFxGripKernelKindVector					@"vector"
#define kFxGripKernelKindResource				@"resource"
#define kFxGripKernelStageCompute				@"compute"
#define kFxGripKernelShapeTexture2D				@"texture2D"
#define kFxGripKernelAccessRead					@"read"
#define kFxGripKernelAccessReadWrite			@"readWrite"

static NSError *FxGripKernelLayoutError(NSInteger code, NSString *reason, NSError *_Nullable underlying)
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"Kernel reflection: %@", reason];
	userInfo[NSLocalizedFailureReasonErrorKey] = reason;
	if (underlying != nil) {
		userInfo[NSUnderlyingErrorKey] = underlying;
	}
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code userInfo:userInfo];
}

static NSError *FxGripKernelLayoutInvalid(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static NSError *FxGripKernelLayoutInvalid(NSString *format, ...)
{
	va_list arguments;
	va_start(arguments, format);
	NSString *reason = NARC_AUTORELEASE([[NSString alloc] initWithFormat:format arguments:arguments]);
	va_end(arguments);
	return FxGripKernelLayoutError(kFxGripError_KernelLayoutInvalid, reason, nil);
}

static BOOL FxGripKernelUnsignedValue(id _Nullable value, NSUInteger *outValue)
{
	if (![value isKindOfClass:NSNumber.class]) {
		return NO;
	}
	double number = [(NSNumber *)value doubleValue];
	if (!isfinite(number) || number < 0.0 || number != floor(number)) {
		return NO;
	}
	*outValue = [(NSNumber *)value unsignedIntegerValue];
	return YES;
}

static NSString *_Nullable FxGripKernelString(id _Nullable value)
{
	return [value isKindOfClass:NSString.class] ? value : nil;
}

static NSDictionary *_Nullable FxGripKernelDictionary(id _Nullable value)
{
	return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSArray *_Nullable FxGripKernelArray(id _Nullable value)
{
	return [value isKindOfClass:NSArray.class] ? value : nil;
}

static FxGripKernelScalarType FxGripKernelScalarTypeNamed(NSString *_Nullable name)
{
	static NSDictionary<NSString *, NSNumber *> *types = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		types = NARC_RETAIN((@{
			@"float32": @(FxGripKernelScalarTypeFloat32),
			@"float16": @(FxGripKernelScalarTypeFloat16),
			@"int32": @(FxGripKernelScalarTypeInt32),
			@"uint32": @(FxGripKernelScalarTypeUInt32),
			@"int16": @(FxGripKernelScalarTypeInt16),
			@"uint16": @(FxGripKernelScalarTypeUInt16),
			@"int8": @(FxGripKernelScalarTypeInt8),
			@"uint8": @(FxGripKernelScalarTypeUInt8),
			@"bool": @(FxGripKernelScalarTypeBool),
		}));
	});
	return name != nil ? types[name].integerValue : FxGripKernelScalarTypeNone;
}

/*! The scalar type and component count of a scalar or vector type description; NO for any other kind. */
static BOOL FxGripKernelScalarOrVector(NSDictionary *_Nullable type, FxGripKernelScalarType *scalarType, NSUInteger *componentCount)
{
	NSString *kind = FxGripKernelString(type[kFxGripKernelJSONKind]);
	if ([kind isEqualToString:kFxGripKernelKindScalar]) {
		*scalarType = FxGripKernelScalarTypeNamed(FxGripKernelString(type[kFxGripKernelJSONScalarType]));
		*componentCount = 1;
		return YES;
	}
	if ([kind isEqualToString:kFxGripKernelKindVector]) {
		NSDictionary *element = FxGripKernelDictionary(type[kFxGripKernelJSONElementType]);
		NSUInteger count = 0;
		if (!FxGripKernelUnsignedValue(type[kFxGripKernelJSONElementCount], &count) || count < 1 || count > 4) {
			return NO;
		}
		*scalarType = FxGripKernelScalarTypeNamed(FxGripKernelString(element[kFxGripKernelJSONScalarType]));
		*componentCount = count;
		return YES;
	}
	return NO;
}

/*! The uniform byte size a type description reports in its sizes array; NO when it reports none. */
static BOOL FxGripKernelUniformSize(NSDictionary *_Nullable type, NSUInteger *size)
{
	for (id entry in FxGripKernelArray(type[kFxGripKernelJSONSizes])) {
		NSDictionary *record = FxGripKernelDictionary(entry);
		if ([FxGripKernelString(record[kFxGripKernelJSONKind]) isEqualToString:kFxGripKernelKindUniform]) {
			return FxGripKernelUnsignedValue(record[kFxGripKernelJSONValue], size);
		}
	}
	return NO;
}

MTLDataType FxGripKernelMetalDataType(FxGripKernelScalarType scalarType, NSUInteger componentCount)
{
	if (componentCount < 1 || componentCount > 4) {
		return MTLDataTypeNone;
	}
	MTLDataType scalar = MTLDataTypeNone;
	switch (scalarType) {
		case FxGripKernelScalarTypeFloat32: scalar = MTLDataTypeFloat; break;
		case FxGripKernelScalarTypeFloat16: scalar = MTLDataTypeHalf; break;
		case FxGripKernelScalarTypeInt32: scalar = MTLDataTypeInt; break;
		case FxGripKernelScalarTypeUInt32: scalar = MTLDataTypeUInt; break;
		case FxGripKernelScalarTypeInt16: scalar = MTLDataTypeShort; break;
		case FxGripKernelScalarTypeUInt16: scalar = MTLDataTypeUShort; break;
		case FxGripKernelScalarTypeInt8: scalar = MTLDataTypeChar; break;
		case FxGripKernelScalarTypeUInt8: scalar = MTLDataTypeUChar; break;
		case FxGripKernelScalarTypeBool: scalar = MTLDataTypeBool; break;
		default: return MTLDataTypeNone;
	}
	// Each Metal family is four consecutive enumerators: the scalar, then its 2-, 3-, and 4-vectors.
	return (MTLDataType)(scalar + (componentCount - 1));
}

#pragma mark - Bindings

@interface FxGripKernelMember ()
- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset length:(NSUInteger)length
				  scalarType:(FxGripKernelScalarType)scalarType componentCount:(NSUInteger)componentCount;
@end

@implementation FxGripKernelMember

- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset length:(NSUInteger)length
				  scalarType:(FxGripKernelScalarType)scalarType componentCount:(NSUInteger)componentCount
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_offset = offset;
		_length = length;
		_scalarType = scalarType;
		_componentCount = componentCount;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_name);
	SUPER_DEALLOC();
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ offset=%lu length=%lu type=%ld components=%lu>", self.class, self.name,
			(unsigned long)self.offset, (unsigned long)self.length, (long)self.scalarType, (unsigned long)self.componentCount];
}

@end

@interface FxGripKernelTexture ()
- (instancetype)initWithName:(NSString *)name index:(NSUInteger)index access:(FxGripKernelTextureAccess)access;
@end

@implementation FxGripKernelTexture

- (instancetype)initWithName:(NSString *)name index:(NSUInteger)index access:(FxGripKernelTextureAccess)access
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_index = index;
		_access = access;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_name);
	SUPER_DEALLOC();
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ index=%lu access=%ld>", self.class, self.name, (unsigned long)self.index, (long)self.access];
}

@end

@interface FxGripKernelSampler ()
- (instancetype)initWithName:(NSString *)name index:(NSUInteger)index;
@end

@implementation FxGripKernelSampler

- (instancetype)initWithName:(NSString *)name index:(NSUInteger)index
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_index = index;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_name);
	SUPER_DEALLOC();
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ index=%lu>", self.class, self.name, (unsigned long)self.index];
}

@end

@interface FxGripKernelConstant ()
- (instancetype)initWithName:(NSString *)name index:(NSUInteger)index scalarType:(FxGripKernelScalarType)scalarType;
@end

@implementation FxGripKernelConstant

- (instancetype)initWithName:(NSString *)name index:(NSUInteger)index scalarType:(FxGripKernelScalarType)scalarType
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_index = index;
		_scalarType = scalarType;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_name);
	SUPER_DEALLOC();
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ index=%lu type=%ld>", self.class, self.name, (unsigned long)self.index, (long)self.scalarType];
}

@end

#pragma mark - Reader

/*! Walks one reflection JSON object and accumulates the roles; the first broken rule stops it. */
@interface FxGripKernelLayoutReader : NSObject
@property (nonatomic, readonly) NSDictionary *root;
@property (nonatomic, copy, nullable) NSString *version;
@property (nonatomic, copy, nullable) NSString *entryPointName;
@property (nonatomic, assign) MTLSize threadGroupSize;
@property (nonatomic, assign) NSUInteger uniformsBufferIndex;
@property (nonatomic, copy, nullable) NSString *uniformsName;
@property (nonatomic, assign) NSUInteger uniformsLength;
@property (nonatomic, readonly) NSMutableArray<FxGripKernelMember *> *members;
@property (nonatomic, assign) NSUInteger tileBufferIndex;
@property (nonatomic, readonly) NSMutableArray<FxGripKernelTexture *> *textures;
@property (nonatomic, readonly) NSMutableArray<FxGripKernelSampler *> *samplers;
@property (nonatomic, readonly) NSMutableArray<FxGripKernelConstant *> *constants;
@end

@implementation FxGripKernelLayoutReader

- (instancetype)initWithRoot:(NSDictionary *)root
{
	self = [super init];
	if (self != nil) {
		_root = NARC_RETAIN(root);
		_uniformsBufferIndex = NSNotFound;
		_tileBufferIndex = NSNotFound;
		_members = [NSMutableArray new];
		_textures = [NSMutableArray new];
		_samplers = [NSMutableArray new];
		_constants = [NSMutableArray new];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_root);
	NARC_RELEASE(_version);
	NARC_RELEASE(_entryPointName);
	NARC_RELEASE(_uniformsName);
	NARC_RELEASE(_members);
	NARC_RELEASE(_textures);
	NARC_RELEASE(_samplers);
	NARC_RELEASE(_constants);
	SUPER_DEALLOC();
}

- (nullable NSError *)read
{
	NSError *failure = [self readVersion];
	if (failure != nil) {
		return failure;
	}
	failure = [self readEntryPoints];
	if (failure != nil) {
		return failure;
	}
	failure = [self readParameters];
	if (failure != nil) {
		return failure;
	}
	return [self checkDestination];
}

- (nullable NSError *)readVersion
{
	NSString *version = FxGripKernelString(self.root[kFxGripKernelJSONVersion]);
	NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
	NSUInteger major = 0;
	if (version == nil || parts.count < 2 || !FxGripKernelUnsignedValue(@(parts[0].integerValue), &major)
		|| ![parts[0] isEqualToString:[NSString stringWithFormat:@"%lu", (unsigned long)major]] || major != kFxGripKernelLayoutVersion) {
		return FxGripKernelLayoutError(kFxGripError_KernelLayoutMalformed, [NSString stringWithFormat:
			@"the version \"%@\" is not one this release reads (%d.x).", version, kFxGripKernelLayoutVersion], nil);
	}
	self.version = version;
	return nil;
}

- (nullable NSError *)readEntryPoints
{
	NSArray *entryPoints = FxGripKernelArray(self.root[kFxGripKernelJSONEntryPoints]);
	if (entryPoints.count != 1) {
		return FxGripKernelLayoutInvalid(@"the kernel declares %lu entry points; the contract declares one.", (unsigned long)entryPoints.count);
	}
	NSDictionary *entryPoint = FxGripKernelDictionary(entryPoints.firstObject);
	NSString *name = FxGripKernelString(entryPoint[kFxGripKernelJSONName]);
	if (name.length == 0) {
		return FxGripKernelLayoutInvalid(@"the entry point has no name.");
	}
	if (![FxGripKernelString(entryPoint[kFxGripKernelJSONStage]) isEqualToString:kFxGripKernelStageCompute]) {
		return FxGripKernelLayoutInvalid(@"the entry point \"%@\" is not a compute entry point.", name);
	}
	NSArray *size = FxGripKernelArray(entryPoint[kFxGripKernelJSONThreadGroupSize]);
	NSUInteger dimensions[3] = { 0, 0, 0 };
	for (NSUInteger axis = 0; axis < 3; axis++) {
		if (size.count != 3 || !FxGripKernelUnsignedValue(size[axis], &dimensions[axis]) || dimensions[axis] == 0) {
			return FxGripKernelLayoutInvalid(@"the entry point \"%@\" has no threadgroup size of three positive counts.", name);
		}
	}
	for (id entry in FxGripKernelArray(entryPoint[kFxGripKernelJSONParameters])) {
		NSDictionary *parameter = FxGripKernelDictionary(entry);
		if (parameter[kFxGripKernelJSONBinding] != nil) {
			return FxGripKernelLayoutInvalid(@"the entry point parameter \"%@\" has a binding; the entry point takes system values only.",
											 FxGripKernelString(parameter[kFxGripKernelJSONName]));
		}
	}
	self.entryPointName = name;
	self.threadGroupSize = MTLSizeMake(dimensions[0], dimensions[1], dimensions[2]);
	return nil;
}

- (nullable NSError *)readParameters
{
	NSArray *parameters = FxGripKernelArray(self.root[kFxGripKernelJSONParameters]);
	if (parameters == nil) {
		return FxGripKernelLayoutError(kFxGripError_KernelLayoutMalformed, @"the JSON has no \"parameters\" array.", nil);
	}
	NSUInteger position = 0;
	for (id entry in parameters) {
		NSDictionary *parameter = FxGripKernelDictionary(entry);
		NSString *name = FxGripKernelString(parameter[kFxGripKernelJSONName]);
		NSDictionary *binding = FxGripKernelDictionary(parameter[kFxGripKernelJSONBinding]);
		NSString *kind = FxGripKernelString(binding[kFxGripKernelJSONKind]);
		NSUInteger index = 0;
		if (name.length == 0 || kind == nil || !FxGripKernelUnsignedValue(binding[kFxGripKernelJSONIndex], &index)) {
			return FxGripKernelLayoutInvalid(@"the global at position %lu has no name, binding kind, and index.", (unsigned long)position);
		}
		NSDictionary *type = FxGripKernelDictionary(parameter[kFxGripKernelJSONType]);
		NSError *failure = [self addGlobalNamed:name kind:kind index:index type:type];
		if (failure != nil) {
			return failure;
		}
		position += 1;
	}
	return nil;
}

- (nullable NSError *)addGlobalNamed:(NSString *)name kind:(NSString *)kind index:(NSUInteger)index type:(nullable NSDictionary *)type
{
	if ([kind isEqualToString:kFxGripKernelKindConstantBuffer]) {
		return [self addConstantBufferNamed:name index:index type:type];
	}
	if ([kind isEqualToString:kFxGripKernelKindShaderResource]) {
		return [self addTextureNamed:name index:index type:type];
	}
	if ([kind isEqualToString:kFxGripKernelKindSamplerState]) {
		[self.samplers addObject:NARC_AUTORELEASE([[FxGripKernelSampler alloc] initWithName:name index:index])];
		return nil;
	}
	if ([kind isEqualToString:kFxGripKernelKindSpecializationConstant]) {
		return [self addConstantNamed:name index:index type:type];
	}
	return FxGripKernelLayoutInvalid(@"the global \"%@\" has the binding kind \"%@\", which the contract does not bind.", name, kind);
}

- (nullable NSError *)addConstantBufferNamed:(NSString *)name index:(NSUInteger)index type:(nullable NSDictionary *)type
{
	NSDictionary *element = FxGripKernelDictionary(type[kFxGripKernelJSONElementType]);
	NSString *elementKind = FxGripKernelString(element[kFxGripKernelJSONKind]);
	if (![elementKind isEqualToString:kFxGripKernelKindStruct]) {
		return FxGripKernelLayoutInvalid(@"the constant buffer \"%@\" holds a %@; the contract binds a struct.", name, elementKind ?: @"value of no kind");
	}
	NSUInteger length = 0;
	if (!FxGripKernelUniformSize(element, &length)) {
		return FxGripKernelLayoutInvalid(@"the constant buffer \"%@\" reports no size.", name);
	}
	if ([FxGripKernelString(element[kFxGripKernelJSONName]) isEqualToString:kFxGripKernelTileStructName]) {
		if (self.tileBufferIndex != NSNotFound) {
			return FxGripKernelLayoutInvalid(@"the kernel declares two %@ buffers; the contract binds one tile.", kFxGripKernelTileStructName);
		}
		if (length != kFxGripKernelTileLength) {
			return FxGripKernelLayoutInvalid(@"the kernel's %@ is %lu bytes and FxGrip's is %d; rebuild the kernel against the shipped GripKernel.slang.",
											 kFxGripKernelTileStructName, (unsigned long)length, kFxGripKernelTileLength);
		}
		self.tileBufferIndex = index;
		return nil;
	}
	if (self.uniformsBufferIndex != NSNotFound) {
		return FxGripKernelLayoutInvalid(@"the kernel declares the constant buffers \"%@\" and \"%@\"; the contract binds one uniforms buffer.",
										 self.uniformsName, name);
	}
	self.uniformsBufferIndex = index;
	self.uniformsName = name;
	self.uniformsLength = length;
	return [self addMembersOfStruct:element bufferName:name];
}

- (nullable NSError *)addMembersOfStruct:(NSDictionary *)element bufferName:(NSString *)bufferName
{
	for (id entry in FxGripKernelArray(element[kFxGripKernelJSONFields])) {
		NSDictionary *field = FxGripKernelDictionary(entry);
		NSString *name = FxGripKernelString(field[kFxGripKernelJSONName]);
		NSDictionary *binding = FxGripKernelDictionary(field[kFxGripKernelJSONBinding]);
		NSUInteger offset = 0;
		NSUInteger length = 0;
		if (name.length == 0 || ![FxGripKernelString(binding[kFxGripKernelJSONKind]) isEqualToString:kFxGripKernelKindUniform]
			|| !FxGripKernelUnsignedValue(binding[kFxGripKernelJSONOffset], &offset)
			|| !FxGripKernelUnsignedValue(binding[kFxGripKernelJSONSize], &length)) {
			return FxGripKernelLayoutInvalid(@"a member of \"%@\" has no name, uniform offset, and size.", bufferName);
		}
		FxGripKernelScalarType scalarType = FxGripKernelScalarTypeNone;
		NSUInteger componentCount = 0;
		if (!FxGripKernelScalarOrVector(FxGripKernelDictionary(field[kFxGripKernelJSONType]), &scalarType, &componentCount)) {
			scalarType = FxGripKernelScalarTypeNone;
			componentCount = 0;
		}
		if (scalarType == FxGripKernelScalarTypeNone) {
			componentCount = 0;
		}
		[self.members addObject:NARC_AUTORELEASE([[FxGripKernelMember alloc] initWithName:name offset:offset length:length
																				 scalarType:scalarType componentCount:componentCount])];
	}
	return nil;
}

- (nullable NSError *)addTextureNamed:(NSString *)name index:(NSUInteger)index type:(nullable NSDictionary *)type
{
	NSString *shape = FxGripKernelString(type[kFxGripKernelJSONBaseShape]);
	if (![FxGripKernelString(type[kFxGripKernelJSONKind]) isEqualToString:kFxGripKernelKindResource] || ![shape isEqualToString:kFxGripKernelShapeTexture2D]) {
		return FxGripKernelLayoutInvalid(@"the resource \"%@\" is a %@; the contract binds Texture2D and RWTexture2D.", name, shape ?: @"resource of no shape");
	}
	NSString *access = FxGripKernelString(type[kFxGripKernelJSONAccess]) ?: kFxGripKernelAccessRead;
	FxGripKernelTextureAccess textureAccess = FxGripKernelTextureAccessRead;
	if ([access isEqualToString:kFxGripKernelAccessReadWrite]) {
		textureAccess = FxGripKernelTextureAccessReadWrite;
	} else if (![access isEqualToString:kFxGripKernelAccessRead]) {
		return FxGripKernelLayoutInvalid(@"the texture \"%@\" has the access \"%@\"; the contract binds read and readWrite.", name, access);
	}
	[self.textures addObject:NARC_AUTORELEASE([[FxGripKernelTexture alloc] initWithName:name index:index access:textureAccess])];
	return nil;
}

- (nullable NSError *)addConstantNamed:(NSString *)name index:(NSUInteger)index type:(nullable NSDictionary *)type
{
	FxGripKernelScalarType scalarType = FxGripKernelScalarTypeNone;
	NSUInteger componentCount = 0;
	if (!FxGripKernelScalarOrVector(type, &scalarType, &componentCount) || componentCount != 1 || scalarType == FxGripKernelScalarTypeNone) {
		return FxGripKernelLayoutInvalid(@"the specialization constant \"%@\" is not a scalar the framework sets.", name);
	}
	[self.constants addObject:NARC_AUTORELEASE([[FxGripKernelConstant alloc] initWithName:name index:index scalarType:scalarType])];
	return nil;
}

- (nullable NSError *)checkDestination
{
	NSUInteger destinations = 0;
	for (FxGripKernelTexture *texture in self.textures) {
		if (texture.access == FxGripKernelTextureAccessReadWrite) {
			destinations += 1;
		}
	}
	if (destinations == 0) {
		return FxGripKernelLayoutInvalid(@"the kernel declares no RWTexture2D; the contract declares one destination.");
	}
	if (destinations > 1) {
		return FxGripKernelLayoutInvalid(@"the kernel declares %lu RWTexture2D globals; the contract declares one destination.", (unsigned long)destinations);
	}
	return nil;
}

@end

#pragma mark - Layout

/*!
	@abstract	The validated reflection JSON of one compiled kernel.
	@discussion	Introduced in FxGrip 0.1.0. The layout is immutable once read.
*/
@implementation FxGripKernelLayout
{
	NSDictionary<NSString *, FxGripKernelMember *> *_membersByName;
	NSDictionary<NSString *, FxGripKernelTexture *> *_texturesByName;
	NSDictionary<NSString *, FxGripKernelConstant *> *_constantsByName;
}

+ (nullable instancetype)layoutWithJSONData:(NSData *)data error:(NSError * _Nullable *)error
{
	NSError *parseError = nil;
	id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
	NSError *failure = nil;
	if (object == nil) {
		failure = FxGripKernelLayoutError(kFxGripError_KernelLayoutMalformed, @"the data is not valid JSON.", parseError);
	} else if (![object isKindOfClass:NSDictionary.class]) {
		failure = FxGripKernelLayoutError(kFxGripError_KernelLayoutMalformed, @"the JSON is not an object.", nil);
	}
	FxGripKernelLayoutReader *reader = nil;
	if (failure == nil) {
		reader = NARC_AUTORELEASE([[FxGripKernelLayoutReader alloc] initWithRoot:object]);
		failure = [reader read];
	}
	if (failure != nil) {
		if (error != NULL) {
			*error = failure;
		}
		return nil;
	}
	return NARC_AUTORELEASE([[self alloc] initWithReader:reader]);
}

+ (nullable instancetype)layoutWithContentsOfURL:(NSURL *)url error:(NSError * _Nullable *)error
{
	NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
	if (data == nil) {
		return nil;
	}
	return [self layoutWithJSONData:data error:error];
}

- (instancetype)initWithReader:(FxGripKernelLayoutReader *)reader
{
	self = [super init];
	if (self != nil) {
		_version = [reader.version copy];
		_entryPointName = [reader.entryPointName copy];
		_threadGroupSize = reader.threadGroupSize;
		_uniformsBufferIndex = reader.uniformsBufferIndex;
		_uniformsLength = reader.uniformsLength;
		_uniformsMembers = [reader.members copy];
		_tileBufferIndex = reader.tileBufferIndex;
		_textures = [reader.textures copy];
		_samplers = [reader.samplers copy];
		_specializationConstants = [reader.constants copy];

		NSMutableDictionary *members = [NSMutableDictionary dictionary];
		for (FxGripKernelMember *member in _uniformsMembers) {
			members[member.name] = member;
		}
		NSMutableDictionary *textures = [NSMutableDictionary dictionary];
		for (FxGripKernelTexture *texture in _textures) {
			textures[texture.name] = texture;
			if (texture.access == FxGripKernelTextureAccessReadWrite) {
				_destinationTexture = NARC_RETAIN(texture);
			}
		}
		NSMutableDictionary *constants = [NSMutableDictionary dictionary];
		for (FxGripKernelConstant *constant in _specializationConstants) {
			constants[constant.name] = constant;
		}
		_membersByName = [members copy];
		_texturesByName = [textures copy];
		_constantsByName = [constants copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_version);
	NARC_RELEASE(_entryPointName);
	NARC_RELEASE(_uniformsMembers);
	NARC_RELEASE(_textures);
	NARC_RELEASE(_destinationTexture);
	NARC_RELEASE(_samplers);
	NARC_RELEASE(_specializationConstants);
	NARC_RELEASE(_membersByName);
	NARC_RELEASE(_texturesByName);
	NARC_RELEASE(_constantsByName);
	SUPER_DEALLOC();
}

- (nullable FxGripKernelMember *)memberNamed:(NSString *)name
{
	return _membersByName[name];
}

- (nullable FxGripKernelTexture *)textureNamed:(NSString *)name
{
	return _texturesByName[name];
}

- (nullable FxGripKernelConstant *)constantNamed:(NSString *)name
{
	return _constantsByName[name];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@ uniforms=%lu tile=%lu textures=%@ samplers=%@ constants=%@>", self.class,
			self.entryPointName, self.version, (unsigned long)self.uniformsBufferIndex, (unsigned long)self.tileBufferIndex,
			self.textures, self.samplers, self.specializationConstants];
}

@end
