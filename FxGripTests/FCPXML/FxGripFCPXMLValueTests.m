/*!
	@file       FxGripFCPXMLValueTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLValueTests
	@abstract   Tests the parameter value codec and the preset-to-filter conversion.
	@discussion Introduced in FxGrip 0.1.0. The tests cover every FxPlug parameter type's string
	            form in both directions, the shape inference used without a host, number formatting,
	            the secure archive form of a custom value, and the preset category.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripFCPXMLValue.h>
#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripPreset+FCPXML.h>
#import <FxGrip/FxGripFCPXMLDocument.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>

@interface FxGripFCPXMLValueTests : XCTestCase
@end

@implementation FxGripFCPXMLValueTests

#pragma mark - Numbers

- (void)testNumberFormatting
{
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForDouble:0.5], @"0.5");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForDouble:2], @"2");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForDouble:-3], @"-3");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForDouble:1.0 / 3.0], @"0.333333333333333");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForNumbers:(@[@1, @0.25, @-1])], @"1 0.25 -1");
	XCTAssertEqualObjects([FxGripFCPXMLValue numbersForString:@" 1  0.25\t-1 "], (@[@1, @0.25, @-1]));
	XCTAssertEqualObjects([FxGripFCPXMLValue numbersForString:@"1 x"], @[]);
	XCTAssertEqualObjects([FxGripFCPXMLValue numbersForString:nil], @[]);
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForRed:1 green:0.5 blue:0 alpha:NAN], @"1 0.5 0");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForRed:1 green:0.5 blue:0 alpha:1], @"1 0.5 0 1");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForX:0.25 y:-0.5], @"0.25 -0.5");
}

#pragma mark - Typed encoding

- (void)testEncodesEachType
{
	NSDictionary *rgba = @{kFxParameterProperty_Red: @1, kFxParameterProperty_Green: @0.5, kFxParameterProperty_Blue: @0.25, kFxParameterProperty_Alpha: @0.75};
	NSDictionary *rgb = @{kFxParameterProperty_Red: @1, kFxParameterProperty_Green: @0.5, kFxParameterProperty_Blue: @0.25};
	NSDictionary *point = @{kFxParameterProperty_X: @0.1, kFxParameterProperty_Y: @0.2};
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:rgba type:FxParameterType_RGBA], @"1 0.5 0.25 0.75");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:rgb type:FxParameterType_RGBA], @"1 0.5 0.25 1", @"a missing alpha writes as opaque");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:rgb type:FxParameterType_RGB], @"1 0.5 0.25");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:rgba type:FxParameterType_RGB], @"1 0.5 0.25 0.75", @"an RGB parameter keeps an alpha it carries");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:point type:FxParameterType_Point], @"0.1 0.2");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@"Text" type:FxParameterType_String], @"Text");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@"Helvetica" type:FxParameterType_FontMenu], @"Helvetica");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@YES type:FxParameterType_Toggle], @"1");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@NO type:FxParameterType_Toggle], @"0");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@3 type:FxParameterType_Int], @"3");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@2 type:FxParameterType_Menu], @"2");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@0.5 type:FxParameterType_Float], @"0.5");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@45 type:FxParameterType_Angle], @"45");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@50 type:FxParameterType_Percent], @"50");
	XCTAssertNil([FxGripFCPXMLValue stringForValue:(@{@"curve": @[]}) type:FxParameterType_Custom]);
	XCTAssertNil([FxGripFCPXMLValue stringForValue:nil type:FxParameterType_Float]);
	XCTAssertNil([FxGripFCPXMLValue stringForValue:@"x" type:FxParameterType_Point], @"a mismatched shape has no encoding");
	XCTAssertNil([FxGripFCPXMLValue stringForValue:@"x" type:FxParameterType_Toggle]);
}

- (void)testEncodesByInferredShape
{
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:@"s"], FxParameterType_String);
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:@1], FxParameterType_Float);
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:(@{kFxParameterProperty_Red: @1})], FxParameterType_RGB);
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:(@{kFxParameterProperty_Red: @1, kFxParameterProperty_Alpha: @1})], FxParameterType_RGBA);
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:(@{kFxParameterProperty_X: @1})], FxParameterType_Point);
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:(@{@"a": @1})], FxParameterType_Custom);
	XCTAssertEqual([FxGripFCPXMLValue inferredTypeForValue:nil], FxParameterType_None);
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:(@{kFxParameterProperty_X: @1, kFxParameterProperty_Y: @2}) type:FxParameterType_None], @"1 2");
	XCTAssertEqualObjects([FxGripFCPXMLValue stringForValue:@7 type:FxParameterType_None], @"7");
}

- (void)testDecodesEachType
{
	NSDictionary *rgba = [FxGripFCPXMLValue valueForString:@"1 0.5 0.25 0.75" type:FxParameterType_RGBA];
	XCTAssertEqualObjects(rgba[kFxParameterProperty_Alpha], @0.75);
	NSDictionary *opaque = [FxGripFCPXMLValue valueForString:@"1 0.5 0.25" type:FxParameterType_RGBA];
	XCTAssertEqualObjects(opaque[kFxParameterProperty_Alpha], @1);
	NSDictionary *rgb = [FxGripFCPXMLValue valueForString:@"1 0.5 0.25" type:FxParameterType_RGB];
	XCTAssertNil(rgb[kFxParameterProperty_Alpha]);
	XCTAssertEqualObjects(rgb[kFxParameterProperty_Blue], @0.25);
	NSDictionary *rgbWithAlpha = [FxGripFCPXMLValue valueForString:@"1 0.5 0.25 0.5" type:FxParameterType_RGB];
	XCTAssertEqualObjects(rgbWithAlpha[kFxParameterProperty_Alpha], @0.5);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"1 0.5" type:FxParameterType_RGB]);
	NSDictionary *point = [FxGripFCPXMLValue valueForString:@"0.1 0.2" type:FxParameterType_Point];
	XCTAssertEqualObjects(point[kFxParameterProperty_Y], @0.2);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"0.1" type:FxParameterType_Point]);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"Hi there" type:FxParameterType_String], @"Hi there");
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"1" type:FxParameterType_Toggle], @YES);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"0" type:FxParameterType_Toggle], @NO);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"true" type:FxParameterType_Toggle], @YES);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"no" type:FxParameterType_Toggle], @NO);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"maybe" type:FxParameterType_Toggle]);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"3" type:FxParameterType_Int], @3);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"2.6" type:FxParameterType_Menu], @3, @"a menu index rounds");
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"0.5" type:FxParameterType_Float], @0.5);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"x" type:FxParameterType_Float]);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"" type:FxParameterType_Float]);
	XCTAssertNil([FxGripFCPXMLValue valueForString:nil type:FxParameterType_Float]);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"abc" type:FxParameterType_Custom]);
}

- (void)testDecodesByTokenCount
{
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"0.5" type:FxParameterType_None], @0.5);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"1 2" type:FxParameterType_None][kFxParameterProperty_X], @1);
	XCTAssertNil([FxGripFCPXMLValue valueForString:@"1 2 3" type:FxParameterType_None][kFxParameterProperty_Alpha]);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"1 2 3 4" type:FxParameterType_None][kFxParameterProperty_Alpha], @4);
	XCTAssertEqualObjects([FxGripFCPXMLValue valueForString:@"Hello world" type:FxParameterType_None], @"Hello world");
}

#pragma mark - Archives

- (void)testArchiveRoundTrip
{
	NSDictionary *custom = @{@"points": @[@1, @2], @"name": @"curve"};
	NSString *archive = [FxGripFCPXMLValue archiveStringForObject:custom];
	XCTAssertNotNil(archive);
	XCTAssertEqualObjects([FxGripFCPXMLValue objectForArchiveString:archive classes:nil], custom);
	XCTAssertNil([FxGripFCPXMLValue objectForArchiveString:@"not base64!" classes:nil]);
	XCTAssertNil([FxGripFCPXMLValue objectForArchiveString:nil classes:nil]);
	XCTAssertNil([FxGripFCPXMLValue archiveStringForObject:nil]);
	XCTAssertNil([FxGripFCPXMLValue objectForArchiveString:archive classes:[NSSet setWithObject:NSDate.class]],
				 @"a class outside the allow-list fails to decode");
}

#pragma mark - Preset category

- (void)testPresetToFilterAndBack
{
	FxGripPreset *preset = [[FxGripPreset alloc] init];
	preset.name = @"Warm";
	preset.parameterValues = @{
		@"1": @0.5,
		@"2": @{kFxParameterProperty_Red: @1, kFxParameterProperty_Green: @0.5, kFxParameterProperty_Blue: @0, kFxParameterProperty_Alpha: @1},
		@"3": @{kFxParameterProperty_X: @0.25, kFxParameterProperty_Y: @0.5},
		@"4": @"Label",
		@"5": @{@"curve": @[@0, @1]},
		@"10": @YES,
	};
	FxGripFCPXMLFilter *filter = [preset fcpxmlFilterWithEffectIdentifier:@"r3" parameterNames:@{@1: @"Amount", @2: @"Tint"}];
	XCTAssertEqualObjects(filter.effectIdentifier, @"r3");
	XCTAssertEqualObjects(filter.filterName, @"Warm");
	XCTAssertEqual(filter.params.count, (NSUInteger)6);
	XCTAssertEqualObjects([filter.params valueForKey:@"key"], (@[@"1", @"2", @"3", @"4", @"5", @"10"]), @"params sort by ID");
	XCTAssertEqualObjects([filter paramWithKey:@"1"].paramName, @"Amount");
	XCTAssertEqualObjects([filter paramWithKey:@"3"].paramName, @"Parameter 3");
	XCTAssertEqualObjects([filter paramWithKey:@"2"].value, @"1 0.5 0 1");
	XCTAssertEqualObjects([filter paramWithKey:@"3"].value, @"0.25 0.5");
	XCTAssertEqualObjects([filter paramWithKey:@"4"].value, @"Label");
	XCTAssertEqualObjects([filter paramWithKey:@"10"].value, @"1");
	FxGripFCPXMLParam *custom = [filter paramWithKey:@"5"];
	XCTAssertNil(custom.value);
	FxGripFCPXMLParam *archive = [custom subparamNamed:FxGripFCPXMLValueArchiveParamName];
	XCTAssertEqualObjects(archive.auxValue, FxGripFCPXMLValueArchiveMarker);
	XCTAssertNotNil(archive.value);

	FxGripPreset *back = [FxGripPreset presetWithFCPXMLFilter:filter];
	XCTAssertEqualObjects(back.name, @"Warm");
	XCTAssertEqualObjects(back.framework, @"FxGrip");
	XCTAssertNotNil(back.uuid);
	XCTAssertNotNil(back.createdTime);
	XCTAssertNil(back.pluginUuid, @"a detached filter names no plug-in");
	XCTAssertEqualObjects(back.parameterValues[@"1"], @0.5);
	XCTAssertEqualObjects(back.parameterValues[@"2"][kFxParameterProperty_Alpha], @1);
	XCTAssertEqualObjects(back.parameterValues[@"3"][kFxParameterProperty_Y], @0.5);
	XCTAssertEqualObjects(back.parameterValues[@"4"], @"Label");
	XCTAssertEqualObjects(back.parameterValues[@"5"], (@{@"curve": @[@0, @1]}));
	XCTAssertEqualObjects(back.parameterValues[@"10"], @1, @"a toggle reads back as a number without a type");
}

- (void)testPresetFromFilterInDocumentTakesThePluginIdentity
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	FxGripFCPXMLEffect *effect = [document.resources effectForFxPlugUUID:@"UUID-9" name:@"Grip"];
	FxGripFCPXMLStoryElement *clip = [FxGripFCPXMLStoryElement clipWithName:@"C" duration:CMTimeMake(1, 1)];
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:effect.identifier name:@"Grip"];
	filter.nameOverride = @"Mine";
	[filter setValue:@"0.5" forParamNamed:@"Amount" key:@"1"];
	[filter setValue:@"1" forParamNamed:@"NoKey" key:nil];
	[filter setValue:@"1" forParamNamed:@"TextKey" key:@"abc"];
	[clip addVideoFilter:filter];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:clip];
	FxGripPreset *preset = [FxGripPreset presetWithFCPXMLFilter:filter];
	XCTAssertEqualObjects(preset.pluginUuid, @"UUID-9");
	XCTAssertEqualObjects(preset.pluginLocalizedName, @"Grip");
	XCTAssertEqualObjects(preset.name, @"Mine");
	XCTAssertEqual(preset.parameterValues.count, (NSUInteger)1, @"params without a numeric key are skipped");
}

@end
