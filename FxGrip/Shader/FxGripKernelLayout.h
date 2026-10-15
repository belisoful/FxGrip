/*!
	@file       FxGripKernelLayout.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelLayout
	@abstract   The binder that reads a Slang kernel's reflection JSON into the roles the GripKernel contract names.
	@discussion Introduced in FxGrip 0.1.0. slangc emits a reflection JSON beside the Metal source it
	            compiles a kernel to. The JSON carries the source names, binding indexes, byte
	            offsets, scalar types, and texture access of every global the kernel declares. The
	            emitted Metal names are mangled, so the framework binds from the JSON and never from
	            Metal reflection. FxGripKernelLayout parses the JSON, validates it against the
	            contract, and exposes the entry point, the uniforms buffer and its members, the tile
	            buffer, the textures, the samplers, and the specialization constants. The class needs
	            no Metal device.
*/

#ifndef FxGripKernelLayout_h
#define FxGripKernelLayout_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

/*! The reflection JSON major version this release reads. */
#define kFxGripKernelLayoutVersion				(1)

/*! The name of the GripKernel struct whose constant buffer receives the tile. */
#define kFxGripKernelTileStructName				@"GripTile"

/*! The byte length of GripTile, which equals the length of the fragment path's FxGripShaderTile. */
#define kFxGripKernelTileLength					(544)

/*!
	@enum		FxGripKernelScalarType
	@abstract	The scalar types the reflection JSON names and the framework packs.
*/
typedef NS_ENUM(NSInteger, FxGripKernelScalarType) {
	/*! A type the framework does not pack, such as an array, a struct, or a 64-bit scalar. */
	FxGripKernelScalarTypeNone = 0,
	/*! Slang float; Metal float. */
	FxGripKernelScalarTypeFloat32,
	/*! Slang half; Metal half. */
	FxGripKernelScalarTypeFloat16,
	/*! Slang int; Metal int. */
	FxGripKernelScalarTypeInt32,
	/*! Slang uint; Metal uint. */
	FxGripKernelScalarTypeUInt32,
	/*! Slang int16_t; Metal short. */
	FxGripKernelScalarTypeInt16,
	/*! Slang uint16_t; Metal ushort. */
	FxGripKernelScalarTypeUInt16,
	/*! Slang int8_t; Metal char. */
	FxGripKernelScalarTypeInt8,
	/*! Slang uint8_t; Metal uchar. */
	FxGripKernelScalarTypeUInt8,
	/*! Slang bool; Metal bool, one byte. */
	FxGripKernelScalarTypeBool,
};

/*!
	@enum		FxGripKernelTextureAccess
	@abstract	The access a kernel declares on a texture global.
*/
typedef NS_ENUM(NSInteger, FxGripKernelTextureAccess) {
	/*! A Texture2D, which the kernel samples or reads. */
	FxGripKernelTextureAccessRead = 0,
	/*! An RWTexture2D, which the kernel writes. The contract declares one: the destination. */
	FxGripKernelTextureAccessReadWrite,
};

/*!
	@function	FxGripKernelMetalDataType
	@abstract	The Metal data type of a scalar type with a component count from 1 through 4.
	@discussion	Introduced in FxGrip 0.1.0. FxGripKernelScalarTypeNone, or a count outside 1 through
				4, gives MTLDataTypeNone.
*/
FOUNDATION_EXPORT MTLDataType FxGripKernelMetalDataType(FxGripKernelScalarType scalarType, NSUInteger componentCount);

/*!
	@class		FxGripKernelMember
	@abstract	One member of the kernel's uniforms struct.
	@discussion	Introduced in FxGrip 0.1.0. A member whose name matches a parameter's key receives
				that parameter's value at offset, converted to scalarType. componentCount is 1 for
				a scalar and 2 through 4 for a vector. A member that is an array, a struct, or a
				type the framework does not pack has scalarType FxGripKernelScalarTypeNone and
				componentCount 0.
*/
@interface FxGripKernelMember : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! The member's name in the Slang source. */
@property (readonly, copy) NSString *name;

/*! The member's byte offset in the uniforms struct. */
@property (readonly) NSUInteger offset;

/*! The member's byte length. */
@property (readonly) NSUInteger length;

/*! The scalar type of the member or of its vector elements. */
@property (readonly) FxGripKernelScalarType scalarType;

/*! 1 for a scalar, 2 through 4 for a vector, 0 for a type the framework does not pack. */
@property (readonly) NSUInteger componentCount;

@end

/*!
	@class		FxGripKernelTexture
	@abstract	One texture global of the kernel.
	@discussion	Introduced in FxGrip 0.1.0. index is the Metal texture index slangc assigned, which
				it assigns in declaration order across every texture global, the destination
				included. The same index selects the texture's coordinate map in GripTile.
*/
@interface FxGripKernelTexture : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! The global's name in the Slang source. */
@property (readonly, copy) NSString *name;

/*! The Metal texture index. */
@property (readonly) NSUInteger index;

/*! Read for a Texture2D, read-write for the RWTexture2D destination. */
@property (readonly) FxGripKernelTextureAccess access;

@end

/*!
	@class		FxGripKernelSampler
	@abstract	One SamplerState global of the kernel.
	@discussion	Introduced in FxGrip 0.1.0. The kernel pipeline binds a bilinear, clamp-to-edge
				sampler at index.
*/
@interface FxGripKernelSampler : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! The global's name in the Slang source. */
@property (readonly, copy) NSString *name;

/*! The Metal sampler index. */
@property (readonly) NSUInteger index;

@end

/*!
	@class		FxGripKernelConstant
	@abstract	One specialization constant of the kernel.
	@discussion	Introduced in FxGrip 0.1.0. A constant whose name matches a constant parameter's key
				receives that parameter's value as the Metal function constant at index.
*/
@interface FxGripKernelConstant : NSObject

- (instancetype)init NS_UNAVAILABLE;

/*! The constant's name in the Slang source. */
@property (readonly, copy) NSString *name;

/*! The Metal function constant index. */
@property (readonly) NSUInteger index;

/*! The constant's scalar type. Slang restricts a specialization constant to a scalar. */
@property (readonly) FxGripKernelScalarType scalarType;

@end

/*!
	@class		FxGripKernelLayout
	@abstract	The validated reflection JSON of one compiled kernel.
	@discussion	Introduced in FxGrip 0.1.0. The layout reads the JSON that
				`slangc -reflection-json` writes for a Metal target and assigns each global its
				role in the GripKernel contract:

	- A `ConstantBuffer` whose struct is named GripTile → the tile buffer. Its length must be
	  kFxGripKernelTileLength.
	- Any other `ConstantBuffer` → the uniforms buffer. The kernel declares at most one.
	- A `Texture2D` → a texture with read access. An `RWTexture2D` → a texture with read-write
	  access. The kernel declares exactly one read-write texture, the destination.
	- A `SamplerState` → a sampler.
	- A `[SpecializationConstant]` → a specialization constant, which Slang restricts to a scalar.
	- Exactly one entry point, of the compute stage, whose parameters are system values only.

	The validation failures are as follows:

	- The data does not parse as a JSON object, or its version is not one this release reads →
	  kFxGripError_KernelLayoutMalformed.
	- A global, an entry point, or a count breaks a rule above → kFxGripError_KernelLayoutInvalid.
*/
@interface FxGripKernelLayout : NSObject

/*!
	@method		layoutWithJSONData:error:
	@abstract	Reads and validates a reflection JSON; nil with an error on failure.
	@discussion	Introduced in FxGrip 0.1.0. A failure fills error with
				kFxGripError_KernelLayoutMalformed or kFxGripError_KernelLayoutInvalid.
*/
+ (nullable instancetype)layoutWithJSONData:(NSData *)data error:(NSError * _Nullable *)error;

/*! Reads a reflection JSON file and validates it as layoutWithJSONData:error: does. */
+ (nullable instancetype)layoutWithContentsOfURL:(NSURL *)url error:(NSError * _Nullable *)error;

- (instancetype)init NS_UNAVAILABLE;

/*! The reflection JSON's version string, such as "1.1". */
@property (readonly, copy) NSString *version;

/*! The name of the compute entry point. */
@property (readonly, copy) NSString *entryPointName;

/*! The threadgroup size the entry point declares with numthreads. */
@property (readonly) MTLSize threadGroupSize;

/*! The Metal buffer index of the uniforms struct; NSNotFound when the kernel declares none. */
@property (readonly) NSUInteger uniformsBufferIndex;

/*! The byte length of the uniforms struct; 0 when the kernel declares none. */
@property (readonly) NSUInteger uniformsLength;

/*! The members of the uniforms struct in declaration order; empty when the kernel declares none. */
@property (readonly, copy) NSArray<FxGripKernelMember *> *uniformsMembers;

/*! The Metal buffer index of the GripTile buffer; NSNotFound when the kernel declares none. */
@property (readonly) NSUInteger tileBufferIndex;

/*! Every texture global in declaration order, the destination included. */
@property (readonly, copy) NSArray<FxGripKernelTexture *> *textures;

/*! The one read-write texture, which receives the destination tile. */
@property (readonly) FxGripKernelTexture *destinationTexture;

/*! Every sampler global in declaration order. */
@property (readonly, copy) NSArray<FxGripKernelSampler *> *samplers;

/*! Every specialization constant in declaration order. */
@property (readonly, copy) NSArray<FxGripKernelConstant *> *specializationConstants;

/*! The uniforms member with the name; nil when none has it. */
- (nullable FxGripKernelMember *)memberNamed:(NSString *)name;

/*! The texture with the name; nil when none has it. */
- (nullable FxGripKernelTexture *)textureNamed:(NSString *)name;

/*! The specialization constant with the name; nil when none has it. */
- (nullable FxGripKernelConstant *)constantNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripKernelLayout_h */
