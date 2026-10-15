/*!
	@file       FxGripKernelLayoutTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelLayoutTests
	@abstract   Verifies the reflection JSON binder's role assignment and validation.
	@discussion Introduced in FxGrip 0.1.0. The tests read the checked-in reflection JSON of the two
	            fixture kernels, confirm every role the contract names, and confirm each rule by
	            editing the JSON's object tree before it is read. No test needs a Metal device.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripKernelLayout.h>
#import "FxGripKernelTestSupport.h"

@interface FxGripKernelLayoutTests : XCTestCase
@end

@implementation FxGripKernelLayoutTests

- (FxGripKernelLayout *)layoutNamed:(NSString *)name
{
	NSError *error = nil;
	FxGripKernelLayout *layout = FxGripKernelTestLayout(name, &error);
	XCTAssertNotNil(layout, @"%@", error);
	return layout;
}

- (NSError *)failureReadingBlurEditedBy:(void (^)(NSMutableDictionary *root))edit code:(NSInteger)code
{
	NSError *error = nil;
	FxGripKernelLayout *layout = [FxGripKernelLayout layoutWithJSONData:FxGripKernelTestEditedLayoutData(@"GripBlur", edit) error:&error];
	XCTAssertNil(layout);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, code, @"%@", error);
	return error;
}

- (NSError *)invalidReadingBlurEditedBy:(void (^)(NSMutableDictionary *root))edit
{
	return [self failureReadingBlurEditedBy:edit code:kFxGripError_KernelLayoutInvalid];
}

/*! The global parameter record with the name. */
- (NSMutableDictionary *)globalNamed:(NSString *)name in:(NSMutableDictionary *)root
{
	for (NSMutableDictionary *parameter in root[@"parameters"]) {
		if ([parameter[@"name"] isEqualToString:name]) {
			return parameter;
		}
	}
	return nil;
}

#pragma mark Roles

/*! @abstract The probe kernel's JSON assigns every role the contract names. */
- (void)testTheBlurKernelAssignsEveryRole
{
	FxGripKernelLayout *layout = [self layoutNamed:@"GripBlur"];

	XCTAssertEqualObjects(layout.version, @"1.1");
	XCTAssertEqualObjects(layout.entryPointName, @"fxGripKernel");
	XCTAssertEqual(layout.threadGroupSize.width, (NSUInteger)8);
	XCTAssertEqual(layout.threadGroupSize.height, (NSUInteger)8);
	XCTAssertEqual(layout.threadGroupSize.depth, (NSUInteger)1);
	XCTAssertEqual(layout.uniformsBufferIndex, (NSUInteger)0);
	XCTAssertEqual(layout.uniformsLength, (NSUInteger)48);
	XCTAssertEqual(layout.tileBufferIndex, (NSUInteger)1);
	XCTAssertEqualObjects([layout.textures valueForKey:@"name"], (@[@"source", @"matte", @"destination"]));
	XCTAssertEqualObjects([layout.textures valueForKey:@"index"], (@[@0, @1, @2]));
	XCTAssertEqual(layout.textures[0].access, FxGripKernelTextureAccessRead);
	XCTAssertEqual(layout.destinationTexture, layout.textures[2]);
	XCTAssertEqual(layout.destinationTexture.access, FxGripKernelTextureAccessReadWrite);
	XCTAssertEqualObjects([layout.samplers valueForKey:@"name"], @[@"bilinear"]);
	XCTAssertEqual(layout.samplers[0].index, (NSUInteger)0);
	XCTAssertEqualObjects([layout.specializationConstants valueForKey:@"name"], (@[@"TAPS", @"INVERT"]));
	XCTAssertEqual([layout constantNamed:@"TAPS"].index, (NSUInteger)0);
	XCTAssertEqual([layout constantNamed:@"TAPS"].scalarType, FxGripKernelScalarTypeInt32);
	XCTAssertEqual([layout constantNamed:@"INVERT"].index, (NSUInteger)1);
	XCTAssertEqual([layout constantNamed:@"INVERT"].scalarType, FxGripKernelScalarTypeBool);
	XCTAssertEqual([layout textureNamed:@"matte"].index, (NSUInteger)1);
	XCTAssertNil([layout textureNamed:@"tile"]);
	XCTAssertNil([layout constantNamed:@"radius"]);
}

/*! @abstract Each uniforms member carries its name, offset, length, scalar type, and component count. */
- (void)testTheUniformsMembersCarryTheirOffsetsAndTypes
{
	FxGripKernelLayout *layout = [self layoutNamed:@"GripBlur"];

	XCTAssertEqualObjects([layout.uniformsMembers valueForKey:@"name"], (@[@"radius", @"tint", @"offset", @"enabled"]));
	XCTAssertEqualObjects([layout.uniformsMembers valueForKey:@"offset"], (@[@0, @16, @32, @40]));
	XCTAssertEqualObjects([layout.uniformsMembers valueForKey:@"length"], (@[@4, @16, @8, @1]));
	XCTAssertEqual([layout memberNamed:@"radius"].scalarType, FxGripKernelScalarTypeFloat32);
	XCTAssertEqual([layout memberNamed:@"radius"].componentCount, (NSUInteger)1);
	XCTAssertEqual([layout memberNamed:@"tint"].scalarType, FxGripKernelScalarTypeFloat32);
	XCTAssertEqual([layout memberNamed:@"tint"].componentCount, (NSUInteger)3);
	XCTAssertEqual([layout memberNamed:@"offset"].scalarType, FxGripKernelScalarTypeInt32);
	XCTAssertEqual([layout memberNamed:@"offset"].componentCount, (NSUInteger)2);
	XCTAssertEqual([layout memberNamed:@"enabled"].scalarType, FxGripKernelScalarTypeBool);
	XCTAssertNil([layout memberNamed:@"missing"]);
}

/*! @abstract The inspect kernel's JSON names the narrow scalar types and keeps the textures in declaration order. */
- (void)testTheInspectKernelNamesNarrowTypesAndDeclarationOrder
{
	FxGripKernelLayout *layout = [self layoutNamed:@"GripInspect"];

	XCTAssertEqual(layout.uniformsLength, (NSUInteger)40);
	XCTAssertEqual([layout memberNamed:@"level"].scalarType, FxGripKernelScalarTypeFloat16);
	XCTAssertEqual([layout memberNamed:@"small"].scalarType, FxGripKernelScalarTypeInt16);
	XCTAssertEqual([layout memberNamed:@"byte"].scalarType, FxGripKernelScalarTypeUInt8);
	XCTAssertEqual([layout memberNamed:@"count"].scalarType, FxGripKernelScalarTypeUInt32);
	XCTAssertEqual([layout memberNamed:@"center"].componentCount, (NSUInteger)2);
	XCTAssertEqualObjects([layout.textures valueForKey:@"name"], (@[@"first", @"second", @"ramp", @"mask", @"destination"]));
	XCTAssertEqual(layout.destinationTexture.index, (NSUInteger)4);
	XCTAssertEqualObjects([layout.specializationConstants valueForKey:@"name"], (@[@"MODE", @"TAPS", @"FILL"]));
	XCTAssertEqual([layout constantNamed:@"FILL"].scalarType, FxGripKernelScalarTypeFloat32);
}

/*! @abstract A struct member that is not a scalar or vector has no scalar type and no components. */
- (void)testAnArrayMemberHasNoScalarType
{
	NSData *data = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		// The tile's struct, renamed, reads as the uniforms, with its array member.
		[self globalNamed:@"tile" in:root][@"type"][@"elementType"][@"name"] = @"Tile";
		[root[@"parameters"] removeObject:[self globalNamed:@"uniforms" in:root]];
	});
	NSError *error = nil;

	FxGripKernelLayout *layout = [FxGripKernelLayout layoutWithJSONData:data error:&error];

	XCTAssertNotNil(layout, @"%@", error);
	XCTAssertEqual(layout.uniformsBufferIndex, (NSUInteger)1);
	XCTAssertEqual(layout.uniformsLength, (NSUInteger)544);
	XCTAssertEqual(layout.tileBufferIndex, (NSUInteger)NSNotFound);
	XCTAssertEqual([layout memberNamed:@"textures"].scalarType, FxGripKernelScalarTypeNone);
	XCTAssertEqual([layout memberNamed:@"textures"].componentCount, (NSUInteger)0);
	XCTAssertEqual([layout memberNamed:@"textures"].offset, (NSUInteger)32);
}

/*! @abstract A kernel may declare no uniforms buffer and no tile. */
- (void)testAKernelMayDeclareNoUniformsAndNoTile
{
	NSData *data = FxGripKernelTestEditedLayoutData(@"GripBlur", ^(NSMutableDictionary *root) {
		[root[@"parameters"] removeObject:[self globalNamed:@"uniforms" in:root]];
		[root[@"parameters"] removeObject:[self globalNamed:@"tile" in:root]];
	});
	NSError *error = nil;

	FxGripKernelLayout *layout = [FxGripKernelLayout layoutWithJSONData:data error:&error];

	XCTAssertNotNil(layout, @"%@", error);
	XCTAssertEqual(layout.uniformsBufferIndex, (NSUInteger)NSNotFound);
	XCTAssertEqual(layout.uniformsLength, (NSUInteger)0);
	XCTAssertEqual(layout.uniformsMembers.count, (NSUInteger)0);
	XCTAssertEqual(layout.tileBufferIndex, (NSUInteger)NSNotFound);
}

/*! @abstract A layout reads from a file URL. */
- (void)testALayoutReadsFromAURL
{
	NSError *error = nil;

	FxGripKernelLayout *layout = [FxGripKernelLayout layoutWithContentsOfURL:FxGripKernelTestFixtureURL(@"GripBlur", @"json") error:&error];

	XCTAssertNotNil(layout, @"%@", error);
	XCTAssertEqualObjects(layout.entryPointName, @"fxGripKernel");
	XCTAssertNil([FxGripKernelLayout layoutWithContentsOfURL:[NSURL fileURLWithPath:@"/nonexistent/GripBlur.json"] error:&error]);
	XCTAssertNotNil(error);
}

/*! @abstract The Metal data type of a scalar type and count follows the Metal families. */
- (void)testTheMetalDataTypeFollowsTheFamilies
{
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeFloat32, 1), MTLDataTypeFloat);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeFloat32, 3), MTLDataTypeFloat3);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeInt32, 2), MTLDataTypeInt2);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeUInt8, 4), MTLDataTypeUChar4);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeFloat16, 1), MTLDataTypeHalf);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeBool, 1), MTLDataTypeBool);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeNone, 1), MTLDataTypeNone);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeFloat32, 0), MTLDataTypeNone);
	XCTAssertEqual(FxGripKernelMetalDataType(FxGripKernelScalarTypeFloat32, 5), MTLDataTypeNone);
}

#pragma mark Malformed

/*! @abstract Data that is not JSON, or not an object, is malformed. */
- (void)testNonJSONDataIsMalformed
{
	NSError *error = nil;

	XCTAssertNil([FxGripKernelLayout layoutWithJSONData:[@"not json" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
	XCTAssertEqual(error.code, (NSInteger)kFxGripError_KernelLayoutMalformed);
	XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);

	XCTAssertNil([FxGripKernelLayout layoutWithJSONData:[@"[1, 2]" dataUsingEncoding:NSUTF8StringEncoding] error:&error]);
	XCTAssertEqual(error.code, (NSInteger)kFxGripError_KernelLayoutMalformed);
}

/*! @abstract A version of another major, or no version, is malformed. */
- (void)testAnotherMajorVersionIsMalformed
{
	[self failureReadingBlurEditedBy:^(NSMutableDictionary *root) { root[@"version"] = @"2.0"; } code:kFxGripError_KernelLayoutMalformed];
	[self failureReadingBlurEditedBy:^(NSMutableDictionary *root) { [root removeObjectForKey:@"version"]; } code:kFxGripError_KernelLayoutMalformed];
	[self failureReadingBlurEditedBy:^(NSMutableDictionary *root) { root[@"version"] = @1; } code:kFxGripError_KernelLayoutMalformed];
}

/*! @abstract A JSON with no parameters array is malformed. */
- (void)testNoParametersArrayIsMalformed
{
	[self failureReadingBlurEditedBy:^(NSMutableDictionary *root) { [root removeObjectForKey:@"parameters"]; } code:kFxGripError_KernelLayoutMalformed];
}

#pragma mark Invalid

/*! @abstract A kernel with no entry point, or two, is invalid. */
- (void)testTheEntryPointCountMustBeOne
{
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { root[@"entryPoints"] = @[]; }];
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		[root[@"entryPoints"] addObject:[root[@"entryPoints"][0] mutableCopy]];
	}];
}

/*! @abstract An entry point of another stage, with no name, or with no threadgroup size is invalid. */
- (void)testTheEntryPointMustBeAComputeEntryPointWithAThreadgroup
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { root[@"entryPoints"][0][@"stage"] = @"fragment"; }];
	XCTAssertTrue([error.localizedDescription containsString:@"fxGripKernel"]);
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [root[@"entryPoints"][0] removeObjectForKey:@"name"]; }];
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { root[@"entryPoints"][0][@"threadGroupSize"] = @[@8, @8]; }];
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { root[@"entryPoints"][0][@"threadGroupSize"] = @[@8, @0, @1]; }];
}

/*! @abstract An entry point parameter with a binding is invalid. */
- (void)testABoundEntryPointParameterIsInvalid
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		root[@"entryPoints"][0][@"parameters"][0][@"binding"] = @{ @"kind": @"uniform", @"offset": @0, @"size": @4 };
	}];

	XCTAssertTrue([error.localizedDescription containsString:@"tid"]);
}

/*! @abstract A global with no name, kind, or index is invalid. */
- (void)testAGlobalWithoutANameKindOrIndexIsInvalid
{
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [[self globalNamed:@"source" in:root] removeObjectForKey:@"name"]; }];
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [[self globalNamed:@"source" in:root][@"binding"] removeObjectForKey:@"kind"]; }];
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [self globalNamed:@"source" in:root][@"binding"][@"index"] = @(-1); }];
}

/*! @abstract A binding kind outside the contract is invalid. */
- (void)testAnUnknownBindingKindIsInvalid
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		[self globalNamed:@"source" in:root][@"binding"][@"kind"] = @"descriptorTableSlot";
	}];

	XCTAssertTrue([error.localizedDescription containsString:@"descriptorTableSlot"]);
}

/*! @abstract A constant buffer that holds a value other than a struct is invalid. */
- (void)testANonStructConstantBufferIsInvalid
{
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		[self globalNamed:@"uniforms" in:root][@"type"][@"elementType"] = @{ @"kind": @"scalar", @"scalarType": @"float32",
			@"sizes": @[@{ @"kind": @"uniform", @"value": @4, @"alignment": @4 }] };
	}];
}

/*! @abstract Two uniforms buffers, or two tiles, are invalid. */
- (void)testTwoUniformsBuffersOrTwoTilesAreInvalid
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		[self globalNamed:@"tile" in:root][@"type"][@"elementType"][@"name"] = @"Other";
	}];
	XCTAssertTrue([error.localizedDescription containsString:@"uniforms"] && [error.localizedDescription containsString:@"tile"]);
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		NSMutableDictionary *uniforms = [self globalNamed:@"uniforms" in:root];
		uniforms[@"type"][@"elementType"][@"name"] = @"GripTile";
		uniforms[@"type"][@"elementType"][@"sizes"] = @[@{ @"kind": @"uniform", @"value": @544, @"alignment": @16 }];
	}];
}

/*! @abstract A GripTile of another size is invalid. */
- (void)testATileOfAnotherSizeIsInvalid
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		[self globalNamed:@"tile" in:root][@"type"][@"elementType"][@"sizes"] = @[@{ @"kind": @"uniform", @"value": @540, @"alignment": @16 }];
	}];

	XCTAssertTrue([error.localizedDescription containsString:@"540"]);
	XCTAssertTrue([error.localizedDescription containsString:@"544"]);
}

/*! @abstract A texture of another shape, or with another access, is invalid. */
- (void)testATextureOfAnotherShapeOrAccessIsInvalid
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [self globalNamed:@"matte" in:root][@"type"][@"baseShape"] = @"texture3D"; }];
	XCTAssertTrue([error.localizedDescription containsString:@"texture3D"]);
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [self globalNamed:@"matte" in:root][@"type"][@"access"] = @"write"; }];
}

/*! @abstract A kernel with no destination, or two, is invalid. */
- (void)testTheDestinationCountMustBeOne
{
	NSError *error = [self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [[self globalNamed:@"destination" in:root][@"type"] removeObjectForKey:@"access"]; }];
	XCTAssertTrue([error.localizedDescription containsString:@"no RWTexture2D"]);
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [self globalNamed:@"matte" in:root][@"type"][@"access"] = @"readWrite"; }];
}

/*! @abstract A specialization constant that is not a scalar is invalid. */
- (void)testANonScalarConstantIsInvalid
{
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) {
		[self globalNamed:@"TAPS" in:root][@"type"] = @{ @"kind": @"vector", @"elementCount": @2, @"elementType": @{ @"kind": @"scalar", @"scalarType": @"int32" } };
	}];
	[self invalidReadingBlurEditedBy:^(NSMutableDictionary *root) { [self globalNamed:@"TAPS" in:root][@"type"][@"scalarType"] = @"int64"; }];
}

@end
