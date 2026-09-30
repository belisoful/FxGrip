/*!
	@file       FxGripShaderMetadataTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderMetadataTests
	@abstract   Verifies the shader metadata scanner's block discovery, parsing, and validation.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm which comments count as metadata blocks,
	            the JSON5 body, the merge of several blocks, every parameter rule including the
	            function-constant restriction, the color-space declaration, the version gate, and
	            the source line each failure reports.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripShaderMetadata.h>
#import <FxGrip/FxGripErrors.h>
#import <FxGrip/FxGripTypes.h>

/*! Wraps a JSON5 body in a metadata block comment. */
static NSString *FxGripShaderBlock(NSString *body)
{
	return [NSString stringWithFormat:@"/* FxGripShader\n%@\n*/\n", body];
}

/*! A block declaring one parameter record, given as the JSON5 object text. */
static NSString *FxGripShaderParameterBlock(NSString *parameter)
{
	return FxGripShaderBlock([NSString stringWithFormat:@"{ \"parameters\": [ %@ ] }", parameter]);
}

@interface FxGripShaderMetadataTests : XCTestCase
@end

@implementation FxGripShaderMetadataTests

- (FxGripShaderMetadata *)scan:(NSString *)source
{
	NSError *error = nil;
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:source error:&error];
	XCTAssertNotNil(metadata, @"%@", error);
	XCTAssertNil(error);
	return metadata;
}

- (NSError *)failureScanning:(NSString *)source code:(NSInteger)code
{
	NSError *error = nil;
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithSource:source error:&error];
	XCTAssertNil(metadata);
	XCTAssertEqualObjects(error.domain, FxGripPlugErrorDomain);
	XCTAssertEqual(error.code, code, @"%@", error);
	return error;
}

- (NSError *)invalidScanning:(NSString *)source
{
	return [self failureScanning:source code:kFxGripError_ShaderMetadataInvalid];
}

#pragma mark Documentation

/*! @abstract The worked example in the Shaders DocC article scans as documented. */
- (void)testTheDocumentedExampleScans
{
	NSString *source =
		@"/* FxGripShader\n"
		@"{\n"
		@"    colorSpace: { transfer: \"linear\", primaries: \"rec709\" },\n"
		@"    parameters: [\n"
		@"        { id: 1, type: \"float\", name: \"Radius\", key: \"radius\",\n"
		@"          default: 8, minimum: 0, maximum: 100 },\n"
		@"        { id: 2, type: \"integer\", name: \"Taps\", key: \"TAPS\", constant: true,\n"
		@"          default: 9, minimum: 1, maximum: 33 },\n"
		@"        { id: 10, type: \"group\", name: \"Tint\", parameters: [\n"
		@"            { id: 11, type: \"rgb\", name: \"Color\", key: \"tint\" },\n"
		@"        ] },\n"
		@"    ],\n"
		@"}\n"
		@"*/\n"
		@"\n"
		@"constant int TAPS [[function_constant(0)]];\n";

	FxGripShaderMetadata *metadata = [self scan:source];

	XCTAssertEqual(metadata.primaries, FxGripShaderPrimariesRec709);
	XCTAssertEqualObjects([metadata parameterForKey:@"radius"][kFxParameterProperty_Default], @8);
	XCTAssertEqualObjects([metadata parameterForKey:@"TAPS"][kFxGripShaderProperty_Constant], @YES);
	XCTAssertEqualObjects([metadata parameterForKey:@"tint"][kFxParameterProperty_Id], @11);
	XCTAssertEqualObjects([metadata.allParameters valueForKey:kFxParameterProperty_Id], (@[@1, @2, @10, @11]));
}

#pragma mark Block discovery

/*! @abstract A source with no block yields empty metadata with the default color space. */
- (void)testASourceWithoutABlockYieldsEmptyMetadata
{
	FxGripShaderMetadata *metadata = [self scan:@"/* Copyright */\nfragment float4 f() { return 0; }\n"];

	XCTAssertEqual(metadata.blockCount, (NSUInteger)0);
	XCTAssertEqual(metadata.parameters.count, (NSUInteger)0);
	XCTAssertEqual(metadata.allParameters.count, (NSUInteger)0);
	XCTAssertEqualObjects(metadata.properties, @{});
	XCTAssertEqual(metadata.processingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_LINEAR);
	XCTAssertEqual(metadata.primaries, FxGripShaderPrimariesHost);
}

/*! @abstract The block's parameters are read in order and indexed by ID and key. */
- (void)testABlocksParametersAreReadInOrderAndIndexed
{
	NSString *source = [@"/* Copyright */\n#include <metal_stdlib>\n" stringByAppendingString:FxGripShaderBlock(
		@"{ \"parameters\": ["
		@"  { \"id\": 1, \"type\": \"float\", \"name\": \"Radius\", \"key\": \"radius\", \"default\": 8 },"
		@"  { \"id\": 2, \"type\": \"toggle\", \"name\": \"Invert\" }"
		@"] }")];

	FxGripShaderMetadata *metadata = [self scan:source];

	XCTAssertEqual(metadata.blockCount, (NSUInteger)1);
	XCTAssertEqual(metadata.parameters.count, (NSUInteger)2);
	XCTAssertEqualObjects(metadata.parameters[0][kFxParameterProperty_Name], @"Radius");
	XCTAssertEqualObjects(metadata.parameters[1][kFxParameterProperty_Name], @"Invert");
	XCTAssertEqualObjects([metadata parameterForKey:@"radius"][kFxParameterProperty_Default], @8);
	XCTAssertEqualObjects([metadata parameterWithID:2][kFxParameterProperty_Type], @"toggle");
	XCTAssertNil([metadata parameterForKey:@"missing"]);
	XCTAssertNil([metadata parameterWithID:3]);
	XCTAssertEqualObjects(metadata.properties[kFxGripShaderProperty_Parameters], metadata.parameters);
}

/*! @abstract The body is JSON5: trailing commas and line comments parse. */
- (void)testTheBodyAcceptsJSON5
{
	FxGripShaderMetadata *metadata = [self scan:FxGripShaderBlock(
		@"{\n"
		@"  // The blur radius.\n"
		@"  parameters: [ { id: 1, type: 'float', name: 'Radius', }, ],\n"
		@"}")];

	XCTAssertEqual(metadata.parameters.count, (NSUInteger)1);
}

/*! @abstract The opener may carry the HeaderDoc bang and indentation. */
- (void)testTheOpenerMayCarryTheBangAndIndentation
{
	FxGripShaderMetadata *metadata = [self scan:@"  /*!FxGripShader { \"parameters\": [] } */"];

	XCTAssertEqual(metadata.blockCount, (NSUInteger)1);
}

/*! @abstract An opener that does not start its line is not a block. */
- (void)testAnOpenerThatDoesNotStartItsLineIsIgnored
{
	FxGripShaderMetadata *metadata = [self scan:
		@"float x = 1; /* FxGripShader { broken */\n"
		@"// /* FxGripShader { broken */\n"];

	XCTAssertEqual(metadata.blockCount, (NSUInteger)0);
}

/*! @abstract The sentinel must be a whole word. */
- (void)testTheSentinelMustBeAWholeWord
{
	FxGripShaderMetadata *metadata = [self scan:@"/* FxGripShaders { broken */\n"];

	XCTAssertEqual(metadata.blockCount, (NSUInteger)0);
}

/*! @abstract Several blocks concatenate their parameters in source order. */
- (void)testSeveralBlocksConcatenateTheirParameters
{
	NSString *source = [NSString stringWithFormat:@"%@float a;\n%@",
		FxGripShaderParameterBlock(@"{ \"id\": 5, \"type\": \"float\", \"name\": \"A\" }"),
		FxGripShaderParameterBlock(@"{ \"id\": 3, \"type\": \"float\", \"name\": \"B\" }")];

	FxGripShaderMetadata *metadata = [self scan:source];

	XCTAssertEqual(metadata.blockCount, (NSUInteger)2);
	XCTAssertEqualObjects([metadata.parameters valueForKey:kFxParameterProperty_Id], (@[@5, @3]));
}

/*! @abstract A top-level key other than parameters may appear in one block only. */
- (void)testATopLevelKeyInTwoBlocksIsInvalid
{
	NSString *colorSpace = FxGripShaderBlock(@"{ \"colorSpace\": { \"transfer\": \"linear\" } }");
	NSString *source = [colorSpace stringByAppendingString:colorSpace];

	NSError *error = [self invalidScanning:source];

	XCTAssertEqualObjects(error.userInfo[FxGripShaderMetadataErrorLineKey], @4, @"the second block opens on line 4");
}

/*! @abstract Unrecognized top-level keys pass through in properties. */
- (void)testUnrecognizedTopLevelKeysPassThrough
{
	FxGripShaderMetadata *metadata = [self scan:FxGripShaderBlock(@"{ \"passes\": [ \"blur\", \"composite\" ] }")];

	XCTAssertEqualObjects(metadata.properties[@"passes"], (@[@"blur", @"composite"]));
}

#pragma mark Malformed blocks

/*! @abstract A block without a comment close is malformed. */
- (void)testABlockWithoutACommentCloseIsMalformed
{
	[self failureScanning:@"/* FxGripShader { \"parameters\": [] }" code:kFxGripError_ShaderMetadataMalformed];
}

/*! @abstract Invalid JSON is malformed and reports the block line and the parser error. */
- (void)testInvalidJSONReportsTheBlockLineAndTheParserError
{
	NSString *source = [@"// one\n// two\n" stringByAppendingString:FxGripShaderBlock(@"{ \"parameters\": [ }")];

	NSError *error = [self failureScanning:source code:kFxGripError_ShaderMetadataMalformed];

	XCTAssertEqualObjects(error.userInfo[FxGripShaderMetadataErrorLineKey], @3);
	XCTAssertNotNil(error.userInfo[NSUnderlyingErrorKey]);
	XCTAssertTrue([error.localizedDescription containsString:@"line 3"]);
}

/*! @abstract A block whose JSON is not an object is malformed. */
- (void)testABlockThatIsNotAnObjectIsMalformed
{
	[self failureScanning:FxGripShaderBlock(@"[ 1, 2 ]") code:kFxGripError_ShaderMetadataMalformed];
}

/*! @abstract An empty block is malformed. */
- (void)testAnEmptyBlockIsMalformed
{
	[self failureScanning:@"/* FxGripShader */" code:kFxGripError_ShaderMetadataMalformed];
}

#pragma mark Parameter records

/*! @abstract The parameters value must be an array. */
- (void)testParametersMustBeAnArray
{
	[self invalidScanning:FxGripShaderBlock(@"{ \"parameters\": { \"id\": 1 } }")];
}

/*! @abstract Each parameter must be an object. */
- (void)testEachParameterMustBeAnObject
{
	[self invalidScanning:FxGripShaderParameterBlock(@"7")];
}

/*! @abstract The ID must be an integer within the shader range. */
- (void)testTheIDMustBeAnIntegerWithinTheShaderRange
{
	NSArray<NSString *> *badIDs = @[@"", @"\"id\": 0,", @"\"id\": 9980,", @"\"id\": 1.5,", @"\"id\": true,", @"\"id\": \"1\","];
	for (NSString *badID in badIDs) {
		NSString *parameter = [NSString stringWithFormat:@"{ %@ \"type\": \"float\", \"name\": \"A\" }", badID];
		[self invalidScanning:FxGripShaderParameterBlock(parameter)];
	}
}

/*! @abstract The highest shader ID is accepted. */
- (void)testTheHighestShaderIDIsAccepted
{
	FxGripShaderMetadata *metadata = [self scan:FxGripShaderParameterBlock(@"{ \"id\": 9979, \"type\": \"float\", \"name\": \"A\" }")];

	XCTAssertNotNil([metadata parameterWithID:kFxGripShaderParameterIdMaximum]);
}

/*! @abstract A repeated ID is invalid, across blocks as well. */
- (void)testARepeatedIDIsInvalidAcrossBlocks
{
	NSString *parameter = FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\" }");

	NSError *error = [self invalidScanning:[parameter stringByAppendingString:parameter]];

	XCTAssertTrue([error.localizedDescription containsString:@"parameter 1"]);
}

/*! @abstract The type must resolve to a parameter type; a type number is accepted. */
- (void)testTheTypeMustResolve
{
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"name\": \"A\" }")];
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"slider\", \"name\": \"A\" }")];
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"ñabc\", \"name\": \"A\" }")];
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": true, \"name\": \"A\" }")];

	NSString *numbered = [NSString stringWithFormat:@"{ \"id\": 1, \"type\": %d, \"name\": \"A\" }", (int)FxParameterType_Float];
	XCTAssertNotNil([[self scan:FxGripShaderParameterBlock(numbered)] parameterWithID:1]);
}

/*! @abstract The name is required, because the parameter factory ignores a record without one. */
- (void)testTheNameIsRequired
{
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\" }")];
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": 4 }")];
}

/*! @abstract The key must be a C identifier and unique. */
- (void)testTheKeyMustBeAUniqueCIdentifier
{
	for (NSString *badKey in @[@"\"1abc\"", @"\"a-b\"", @"\"\"", @"3"]) {
		NSString *parameter = [NSString stringWithFormat:@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\", \"key\": %@ }", badKey];
		[self invalidScanning:FxGripShaderParameterBlock(parameter)];
	}
	[self invalidScanning:FxGripShaderParameterBlock(
		@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\", \"key\": \"radius\" },"
		@"{ \"id\": 2, \"type\": \"float\", \"name\": \"B\", \"key\": \"radius\" }")];

	FxGripShaderMetadata *metadata = [self scan:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\", \"key\": \"_radius2\" }")];
	XCTAssertNotNil([metadata parameterForKey:@"_radius2"]);
}

#pragma mark Function constants

/*! @abstract A discrete type may be a constant. */
- (void)testADiscreteTypeMayBeAConstant
{
	for (NSString *type in @[@"integer", @"toggle", @"menu", @"switch"]) {
		NSString *parameter = [NSString stringWithFormat:@"{ \"id\": 1, \"type\": \"%@\", \"name\": \"A\", \"key\": \"K\", \"constant\": true }", type];
		XCTAssertNotNil([[self scan:FxGripShaderParameterBlock(parameter)] parameterForKey:@"K"], @"%@", type);
	}
}

/*! @abstract A constant needs a key to bind by name. */
- (void)testAConstantNeedsAKey
{
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"integer\", \"name\": \"A\", \"constant\": true }")];
}

/*! @abstract A continuous type is refused as a constant unless the record opts in. */
- (void)testAContinuousTypeNeedsTheOptInToBeAConstant
{
	for (NSString *type in @[@"float", @"percent", @"angle", @"rgb", @"rgba", @"point"]) {
		NSString *refused = [NSString stringWithFormat:@"{ \"id\": 1, \"type\": \"%@\", \"name\": \"A\", \"key\": \"K\", \"constant\": true }", type];
		NSError *error = [self invalidScanning:FxGripShaderParameterBlock(refused)];
		XCTAssertTrue([error.localizedDescription containsString:kFxGripShaderProperty_AllowContinuousConstant], @"%@", type);

		NSString *permitted = [NSString stringWithFormat:
			@"{ \"id\": 1, \"type\": \"%@\", \"name\": \"A\", \"key\": \"K\", \"constant\": true, \"allowContinuousConstant\": true }", type];
		XCTAssertNotNil([[self scan:FxGripShaderParameterBlock(permitted)] parameterForKey:@"K"], @"%@", type);
	}
}

/*! @abstract A type with no scalar value is never a constant, even with the opt-in. */
- (void)testATypeWithoutAScalarValueIsNeverAConstant
{
	[self invalidScanning:FxGripShaderParameterBlock(
		@"{ \"id\": 1, \"type\": \"gradient\", \"name\": \"A\", \"key\": \"K\", \"constant\": true, \"allowContinuousConstant\": true }")];
}

/*! @abstract The constant flags must be booleans. */
- (void)testTheConstantFlagsMustBeBooleans
{
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"integer\", \"name\": \"A\", \"key\": \"K\", \"constant\": 1 }")];
	[self invalidScanning:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\", \"allowContinuousConstant\": \"yes\" }")];
}

/*! @abstract A false constant flag leaves the parameter a uniform. */
- (void)testAFalseConstantFlagNeedsNoKey
{
	XCTAssertNotNil([[self scan:FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\", \"constant\": false }")] parameterWithID:1]);
}

#pragma mark Groups

/*! @abstract A group's nested parameters are validated and indexed, and stay nested in parameters. */
- (void)testAGroupsNestedParametersAreIndexed
{
	FxGripShaderMetadata *metadata = [self scan:FxGripShaderParameterBlock(
		@"{ \"id\": 10, \"type\": \"group\", \"name\": \"Blur\", \"parameters\": ["
		@"    { \"id\": 11, \"type\": \"float\", \"name\": \"Radius\", \"key\": \"radius\" }"
		@"] },"
		@"{ \"id\": 12, \"type\": \"toggle\", \"name\": \"Invert\" }")];

	XCTAssertEqualObjects([metadata.parameters valueForKey:kFxParameterProperty_Id], (@[@10, @12]));
	XCTAssertEqualObjects([metadata.allParameters valueForKey:kFxParameterProperty_Id], (@[@10, @11, @12]));
	XCTAssertEqualObjects([metadata parameterForKey:@"radius"][kFxParameterProperty_Id], @11);
}

/*! @abstract Only a group nests parameters, and only in an array. */
- (void)testOnlyAGroupNestsParametersInAnArray
{
	[self invalidScanning:FxGripShaderParameterBlock(
		@"{ \"id\": 10, \"type\": \"float\", \"name\": \"A\", \"parameters\": [] }")];
	[self invalidScanning:FxGripShaderParameterBlock(
		@"{ \"id\": 10, \"type\": \"group\", \"name\": \"A\", \"parameters\": { \"x\": { \"id\": 11, \"type\": \"float\", \"name\": \"B\" } } }")];
}

/*! @abstract A nested child obeys the parameter rules, including ID uniqueness. */
- (void)testANestedChildObeysTheParameterRules
{
	[self invalidScanning:FxGripShaderParameterBlock(
		@"{ \"id\": 10, \"type\": \"group\", \"name\": \"A\", \"parameters\": [ { \"id\": 10, \"type\": \"float\", \"name\": \"B\" } ] }")];
	[self invalidScanning:FxGripShaderParameterBlock(
		@"{ \"id\": 10, \"type\": \"group\", \"name\": \"A\", \"parameters\": [ { \"id\": 11, \"type\": \"float\" } ] }")];
}

#pragma mark Color space and version

/*! @abstract The declared transfer and primaries are resolved. */
- (void)testTheDeclaredColorSpaceIsResolved
{
	FxGripShaderMetadata *metadata = [self scan:FxGripShaderBlock(@"{ \"colorSpace\": { \"transfer\": \"gamma\", \"primaries\": \"rec2020\" } }")];

	XCTAssertEqual(metadata.processingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_GAMMA_VIDEO);
	XCTAssertEqual(metadata.primaries, FxGripShaderPrimariesRec2020);

	metadata = [self scan:FxGripShaderBlock(@"{ \"colorSpace\": { \"transfer\": \"linear\", \"primaries\": \"rec709\" } }")];
	XCTAssertEqual(metadata.processingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_LINEAR);
	XCTAssertEqual(metadata.primaries, FxGripShaderPrimariesRec709);
}

/*! @abstract An omitted color-space field keeps its default. */
- (void)testAnOmittedColorSpaceFieldKeepsItsDefault
{
	FxGripShaderMetadata *metadata = [self scan:FxGripShaderBlock(@"{ \"colorSpace\": { \"primaries\": \"host\" } }")];

	XCTAssertEqual(metadata.processingColorInfo, (FxImageColorInfo)kFxImageColorInfo_RGB_LINEAR);
	XCTAssertEqual(metadata.primaries, FxGripShaderPrimariesHost);
}

/*! @abstract An unknown color-space value or key is invalid. */
- (void)testAnUnknownColorSpaceValueOrKeyIsInvalid
{
	[self invalidScanning:FxGripShaderBlock(@"{ \"colorSpace\": \"linear\" }")];
	[self invalidScanning:FxGripShaderBlock(@"{ \"colorSpace\": { \"transfer\": \"sRGB\" } }")];
	[self invalidScanning:FxGripShaderBlock(@"{ \"colorSpace\": { \"transfer\": 0 } }")];
	[self invalidScanning:FxGripShaderBlock(@"{ \"colorSpace\": { \"primaries\": \"p3\" } }")];
	[self invalidScanning:FxGripShaderBlock(@"{ \"colorSpace\": { \"gamut\": \"rec709\" } }")];
}

/*! @abstract The version must be an integer this release reads. */
- (void)testTheVersionMustBeReadable
{
	XCTAssertNotNil([self scan:FxGripShaderBlock(@"{ \"version\": 1 }")]);
	[self invalidScanning:FxGripShaderBlock(@"{ \"version\": 2 }")];
	[self invalidScanning:FxGripShaderBlock(@"{ \"version\": 0 }")];
	[self invalidScanning:FxGripShaderBlock(@"{ \"version\": \"1\" }")];
}

#pragma mark Failure lines

/*! @abstract A parameter failure reports the line of the block that holds it. */
- (void)testAParameterFailureReportsItsBlocksLine
{
	NSString *source = [NSString stringWithFormat:@"%@\n\n%@",
		FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": \"A\" }"),
		FxGripShaderParameterBlock(@"{ \"id\": 2, \"type\": \"float\" }")];

	NSError *error = [self invalidScanning:source];

	XCTAssertEqualObjects(error.userInfo[FxGripShaderMetadataErrorLineKey], @6);
	XCTAssertTrue([error.localizedDescription containsString:@"parameter 2"]);
}

#pragma mark Files

/*! @abstract A shader file is read as UTF-8 and scanned. */
- (void)testAShaderFileIsReadAndScanned
{
	NSURL *url = [NSFileManager.defaultManager.temporaryDirectory
		URLByAppendingPathComponent:[NSString stringWithFormat:@"FxGripShaderMetadataTests-%@.metal", NSUUID.UUID.UUIDString]];
	NSString *source = FxGripShaderParameterBlock(@"{ \"id\": 1, \"type\": \"float\", \"name\": \"Größe\" }");
	XCTAssertTrue([source writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
	[self addTeardownBlock:^{
		[NSFileManager.defaultManager removeItemAtURL:url error:NULL];
	}];

	NSError *error = nil;
	FxGripShaderMetadata *metadata = [FxGripShaderMetadata metadataWithContentsOfURL:url error:&error];

	XCTAssertNil(error);
	XCTAssertEqualObjects([metadata parameterWithID:1][kFxParameterProperty_Name], @"Größe");
}

/*! @abstract A missing file returns nil with the read error. */
- (void)testAMissingFileReturnsTheReadError
{
	NSURL *url = [NSFileManager.defaultManager.temporaryDirectory URLByAppendingPathComponent:@"FxGripShaderMetadataTests-missing.metal"];
	NSError *error = nil;

	XCTAssertNil([FxGripShaderMetadata metadataWithContentsOfURL:url error:&error]);
	XCTAssertEqualObjects(error.domain, NSCocoaErrorDomain);
}

@end
