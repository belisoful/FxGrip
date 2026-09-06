//
//  FxGripPresetFileTests.m
//  FxGripTests
//
//  Unit tests for the preset model and its file form: the presetDictionary /
//  initWithPresetDictionary round trip over the seven FxFactory keys and the seven FxGrip
//  keys, nil omission, the string keying of parameter-keyed sections, the presetSections
//  shape, the XML property list I/O, and fidelity against the FxFactory sample shipped
//  with the repository.
//

#import <XCTest/XCTest.h>
#import <CoreMedia/CoreMedia.h>
#import "FxGrip/FxGripPreset.h"

/*! The FxFactory sample is an external fixture kept beside the project. It is not committed
	(the gitignored Local/ copy is the working original), so the resolver tries each known
	location and returns the first that exists; when none does it returns the primary
	repo-root path so the skip message names a sensible spot to restore it. */
static NSURL *FxGripPresetFileTestSampleURL(void)
{
	NSString *source = [NSString stringWithUTF8String:__FILE__];
	NSString *root = source.stringByDeletingLastPathComponent.stringByDeletingLastPathComponent;
	NSArray<NSString *> *candidates = @[
		@"FxFactory Circle Preset.fxpreset",
		@"Local/FxFactory Circle Preset xml.fxpreset",
		@"Local/FxFactory Circle Preset.fxpreset"
	];
	for (NSString *candidate in candidates) {
		NSString *path = [root stringByAppendingPathComponent:candidate];
		if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
			return [NSURL fileURLWithPath:path];
		}
	}
	return [NSURL fileURLWithPath:[root stringByAppendingPathComponent:candidates.firstObject]];
}

@interface FxGripPresetFileTests : XCTestCase
@property (nonatomic, strong) NSURL *folderURL;
@end

@implementation FxGripPresetFileTests

- (void)setUp
{
	[super setUp];
	self.folderURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
					  URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:self.folderURL
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];
}

- (void)tearDown
{
	[NSFileManager.defaultManager removeItemAtURL:self.folderURL error:NULL];
	self.folderURL = nil;
	[super tearDown];
}

- (NSURL *)fileURLNamed:(NSString *)name
{
	return [self.folderURL URLByAppendingPathComponent:name];
}

/*! A preset carrying every field, so omission and round trip are both observable. */
- (FxGripPreset *)fullPreset
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.createdByParameterId = 117;
	preset.parameterValues = @{@"104": @12, @"112": @{@"x": @0.5, @"y": @0.25}};
	preset.parameterTags = @{@"104": @[@"warm", @"cool"]};
	preset.parameterMeta = @{@"112": @{@"note": @"center"}};
	preset.framework = @"FxGrip";
	preset.uuid = @"B1D0A6C6-0000-4000-8000-000000000001";
	preset.name = @"Sunset";
	preset.tag = @"look";
	preset.createdTime = @"2026-08-04T12:00:00Z";
	preset.pluginAuthor = @"Belisoful";
	preset.pluginLocalizedName = @"Circle";
	preset.pluginUuid = @"77C0D916-29A6-4D97-A09A-21DE2858C8E5";
	preset.pluginVersion = @"1.0";
	preset.productId = @"fxgrip";
	return preset;
}

- (void)assertPreset:(FxGripPreset *)actual matchesFieldsOf:(FxGripPreset *)expected
{
	XCTAssertEqual(actual.createdByParameterId, expected.createdByParameterId);
	XCTAssertEqualObjects(actual.parameterValues, expected.parameterValues);
	XCTAssertEqualObjects(actual.parameterTags, expected.parameterTags);
	XCTAssertEqualObjects(actual.parameterMeta, expected.parameterMeta);
	XCTAssertEqualObjects(actual.framework, expected.framework);
	XCTAssertEqualObjects(actual.uuid, expected.uuid);
	XCTAssertEqualObjects(actual.name, expected.name);
	XCTAssertEqualObjects(actual.tag, expected.tag);
	XCTAssertEqualObjects(actual.createdTime, expected.createdTime);
	XCTAssertEqualObjects(actual.pluginAuthor, expected.pluginAuthor);
	XCTAssertEqualObjects(actual.pluginLocalizedName, expected.pluginLocalizedName);
	XCTAssertEqualObjects(actual.pluginUuid, expected.pluginUuid);
	XCTAssertEqualObjects(actual.pluginVersion, expected.pluginVersion);
	XCTAssertEqualObjects(actual.productId, expected.productId);
}

#pragma mark presetDictionary

- (void)testPresetDictionaryWritesTheSevenFxFactoryKeys
{
	NSDictionary *dictionary = [self fullPreset].presetDictionary;

	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_CreatedByParameterId], @117);
	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_ParameterValues][@"104"], @12);
	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_PluginAuthor], @"Belisoful");
	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_LocalizedName], @"Circle");
	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_PluginUuid], @"77C0D916-29A6-4D97-A09A-21DE2858C8E5");
	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_PluginVersion], @"1.0");
	XCTAssertEqualObjects(dictionary[kFxFactoryPresetKey_ProductId], @"fxgrip");
}

- (void)testPresetDictionaryWritesTheSevenFxGripKeys
{
	NSDictionary *dictionary = [self fullPreset].presetDictionary;

	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_Framework], @"FxGrip");
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_Uuid], @"B1D0A6C6-0000-4000-8000-000000000001");
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_DisplayName], @"Sunset");
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_Tag], @"look");
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_CreatedTime], @"2026-08-04T12:00:00Z");
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_ParameterMeta][@"112"], @{@"note": @"center"});
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_ParameterTags][@"104"], (@[@"warm", @"cool"]));
}

- (void)testPresetDictionaryOfAFullPresetCarriesExactlyFourteenKeys
{
	XCTAssertEqual([self fullPreset].presetDictionary.count, 14u);
}

- (void)testPresetDictionaryOfABarePresetIsEmpty
{
	FxGripPreset *preset = [FxGripPreset.alloc init];

	XCTAssertEqual(preset.presetDictionary.count, 0u);
}

- (void)testPresetDictionaryOmitsAZeroCreatedByParameterId
{
	FxGripPreset *preset = [self fullPreset];
	preset.createdByParameterId = 0;

	XCTAssertNil(preset.presetDictionary[kFxFactoryPresetKey_CreatedByParameterId]);
}

- (void)testPresetDictionaryOmitsEachNilProperty
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.name = @"Only";

	NSDictionary *dictionary = preset.presetDictionary;
	XCTAssertEqual(dictionary.count, 1u);
	XCTAssertEqualObjects(dictionary[kFxGripPresetKey_DisplayName], @"Only");
}

- (void)testPresetDictionaryWritesNumberKeyedValuesWithStringKeys
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterValues = @{@104: @12, @112: @"text"};

	NSDictionary *written = preset.presetDictionary[kFxFactoryPresetKey_ParameterValues];
	XCTAssertEqualObjects(written, (@{@"104": @12, @"112": @"text"}));
}

- (void)testPresetDictionaryWritesNumberKeyedTagsAndMetaWithStringKeys
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterTags = @{@104: @[@"warm"]};
	preset.parameterMeta = @{@112: @{@"note": @"center"}};

	XCTAssertEqualObjects(preset.presetDictionary[kFxGripPresetKey_ParameterTags], (@{@"104": @[@"warm"]}));
	XCTAssertEqualObjects(preset.presetDictionary[kFxGripPresetKey_ParameterMeta], (@{@"112": @{@"note": @"center"}}));
}

- (void)testPresetDictionaryKeepsStringParameterKeysUnchanged
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterValues = @{@"104": @12};

	XCTAssertEqualObjects(preset.presetDictionary[kFxFactoryPresetKey_ParameterValues], (@{@"104": @12}));
}

- (void)testPresetDictionaryWritesAnEmptyParameterValuesSection
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterValues = @{};

	XCTAssertEqualObjects(preset.presetDictionary[kFxFactoryPresetKey_ParameterValues], @{});
}

#pragma mark initWithPresetDictionary:

- (void)testInitWithPresetDictionaryReadsEveryFileKey
{
	NSDictionary *dictionary = @{
		kFxFactoryPresetKey_CreatedByParameterId: @117,
		kFxFactoryPresetKey_ParameterValues: @{@"104": @12},
		kFxFactoryPresetKey_PluginAuthor: @"Belisoful",
		kFxFactoryPresetKey_LocalizedName: @"Circle",
		kFxFactoryPresetKey_PluginUuid: @"UUID-1",
		kFxFactoryPresetKey_PluginVersion: @"1.0",
		kFxFactoryPresetKey_ProductId: @"fxgrip",
		kFxGripPresetKey_Framework: @"FxGrip",
		kFxGripPresetKey_Uuid: @"UUID-2",
		kFxGripPresetKey_DisplayName: @"Sunset",
		kFxGripPresetKey_Tag: @"look",
		kFxGripPresetKey_CreatedTime: @"2026-08-04T12:00:00Z",
		kFxGripPresetKey_ParameterTags: @{@"104": @[@"warm"]},
		kFxGripPresetKey_ParameterMeta: @{@"112": @{@"note": @"center"}}
	};

	FxGripPreset *preset = [FxGripPreset.alloc initWithPresetDictionary:dictionary];

	XCTAssertEqual(preset.createdByParameterId, 117u);
	XCTAssertEqualObjects(preset.parameterValues, (@{@"104": @12}));
	XCTAssertEqualObjects(preset.pluginAuthor, @"Belisoful");
	XCTAssertEqualObjects(preset.pluginLocalizedName, @"Circle");
	XCTAssertEqualObjects(preset.pluginUuid, @"UUID-1");
	XCTAssertEqualObjects(preset.pluginVersion, @"1.0");
	XCTAssertEqualObjects(preset.productId, @"fxgrip");
	XCTAssertEqualObjects(preset.framework, @"FxGrip");
	XCTAssertEqualObjects(preset.uuid, @"UUID-2");
	XCTAssertEqualObjects(preset.name, @"Sunset");
	XCTAssertEqualObjects(preset.tag, @"look");
	XCTAssertEqualObjects(preset.createdTime, @"2026-08-04T12:00:00Z");
	XCTAssertEqualObjects(preset.parameterTags, (@{@"104": @[@"warm"]}));
	XCTAssertEqualObjects(preset.parameterMeta, (@{@"112": @{@"note": @"center"}}));
}

- (void)testInitWithAnEmptyDictionaryLeavesEveryFieldUnset
{
	FxGripPreset *preset = [FxGripPreset.alloc initWithPresetDictionary:@{}];

	XCTAssertNotNil(preset);
	[self assertPreset:preset matchesFieldsOf:[FxGripPreset.alloc init]];
}

- (void)testInitWithPresetDictionaryIgnoresUnknownKeys
{
	FxGripPreset *preset = [FxGripPreset.alloc initWithPresetDictionary:@{@"SomeFutureKey": @"value",
																		  kFxGripPresetKey_DisplayName: @"Sunset"}];

	XCTAssertEqualObjects(preset.name, @"Sunset");
	XCTAssertEqual(preset.presetDictionary.count, 1u);
}

- (void)testInitWithANilDictionaryIsNil
{
	NSDictionary *dictionary = nil;

	XCTAssertNil([FxGripPreset.alloc initWithPresetDictionary:dictionary]);
}

- (void)testInitWithANonDictionaryIsNil
{
	XCTAssertNil([FxGripPreset.alloc initWithPresetDictionary:(id)@"not a dictionary"]);
}

#pragma mark Round trip

- (void)testTheFileFormRoundTripsEveryField
{
	FxGripPreset *original = [self fullPreset];

	FxGripPreset *reread = [FxGripPreset.alloc initWithPresetDictionary:original.presetDictionary];

	[self assertPreset:reread matchesFieldsOf:original];
}

- (void)testTheFileFormRoundTripsALocalizedNameDictionaryVerbatim
{
	FxGripPreset *original = [self fullPreset];
	original.pluginLocalizedName = @{@"English": @"Circle", @"French": @"Cercle"};

	FxGripPreset *reread = [FxGripPreset.alloc initWithPresetDictionary:original.presetDictionary];

	XCTAssertEqualObjects(reread.pluginLocalizedName, (@{@"English": @"Circle", @"French": @"Cercle"}));
}

- (void)testTheFileFormRoundTripNormalizesNumberParameterKeysToStrings
{
	FxGripPreset *original = [FxGripPreset.alloc init];
	original.parameterValues = @{@104: @12};

	FxGripPreset *reread = [FxGripPreset.alloc initWithPresetDictionary:original.presetDictionary];

	XCTAssertEqualObjects(reread.parameterValues, (@{@"104": @12}));
	XCTAssertNil(reread.parameterValues[@104]);
}

- (void)testASecondRoundTripIsStable
{
	NSDictionary *once = [self fullPreset].presetDictionary;
	NSDictionary *twice = [FxGripPreset.alloc initWithPresetDictionary:once].presetDictionary;

	XCTAssertEqualObjects(twice, once);
}

#pragma mark presetSections

- (void)testPresetSectionsCarriesTheThreeSectionsUnderTheTargetPresetKeys
{
	FxGripPreset *preset = [self fullPreset];

	NSDictionary *sections = preset.presetSections;
	XCTAssertEqual(sections.count, 3u);
	XCTAssertEqualObjects(sections[kFxParameterProperty_TargetPresetValues], preset.parameterValues);
	XCTAssertEqualObjects(sections[kFxParameterProperty_TargetPresetTags], preset.parameterTags);
	XCTAssertEqualObjects(sections[kFxParameterProperty_TargetPresetMeta], preset.parameterMeta);
}

- (void)testPresetSectionsOmitsTheSectionsThePresetDoesNotCarry
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterValues = @{@"104": @12};

	NSDictionary *sections = preset.presetSections;
	XCTAssertEqual(sections.count, 1u);
	XCTAssertNotNil(sections[kFxParameterProperty_TargetPresetValues]);
	XCTAssertNil(sections[kFxParameterProperty_TargetPresetTags]);
	XCTAssertNil(sections[kFxParameterProperty_TargetPresetMeta]);
}

- (void)testPresetSectionsOfABarePresetIsEmpty
{
	XCTAssertEqual([FxGripPreset.alloc init].presetSections.count, 0u);
}

- (void)testPresetSectionsCarriesNeitherFlagsNorNames
{
	NSDictionary *sections = [self fullPreset].presetSections;

	XCTAssertNil(sections[kFxParameterProperty_TargetPresetFlags]);
	XCTAssertNil(sections[kFxParameterProperty_TargetPresetNames]);
}

- (void)testPresetSectionsKeepsTheParameterKeysAsCarried
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterValues = @{@104: @12};

	NSDictionary *values = preset.presetSections[kFxParameterProperty_TargetPresetValues];
	XCTAssertEqualObjects(values[@104], @12);
}

#pragma mark savePresetToURL: / loadPresetFromURL:

- (void)testSavePresetWritesAnXMLPropertyList
{
	NSURL *url = [self fileURLNamed:@"Sunset.fxpreset"];

	XCTAssertTrue([[self fullPreset] savePresetToURL:url]);

	NSData *data = [NSData dataWithContentsOfURL:url];
	NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	XCTAssertTrue([text hasPrefix:@"<?xml"]);
	XCTAssertTrue([text containsString:kFxFactoryPresetKey_PluginUuid]);
	XCTAssertTrue([text containsString:kFxGripPresetKey_DisplayName]);
}

- (void)testASavedFileParsesBackToThePresetDictionary
{
	FxGripPreset *original = [self fullPreset];
	NSURL *url = [self fileURLNamed:@"Sunset.fxpreset"];
	XCTAssertTrue([original savePresetToURL:url]);

	NSData *data = [NSData dataWithContentsOfURL:url];
	id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];

	XCTAssertEqualObjects(plist, original.presetDictionary);
}

- (void)testASavedFileReloadsFieldForField
{
	FxGripPreset *original = [self fullPreset];
	NSURL *url = [self fileURLNamed:@"Sunset.fxpreset"];
	XCTAssertTrue([original savePresetToURL:url]);

	[self assertPreset:[FxGripPreset loadPresetFromURL:url] matchesFieldsOf:original];
}

- (void)testABarePresetSurvivesTheFileRoundTrip
{
	FxGripPreset *original = [FxGripPreset.alloc init];
	NSURL *url = [self fileURLNamed:@"Bare.fxpreset"];
	XCTAssertTrue([original savePresetToURL:url]);

	[self assertPreset:[FxGripPreset loadPresetFromURL:url] matchesFieldsOf:original];
}

- (void)testSavePresetToANilURLReturnsNo
{
	NSURL *url = nil;

	XCTAssertFalse([[self fullPreset] savePresetToURL:url]);
}

- (void)testSavePresetToAMissingDirectoryReturnsNo
{
	NSURL *url = [[self.folderURL URLByAppendingPathComponent:@"absent" isDirectory:YES]
				  URLByAppendingPathComponent:@"Sunset.fxpreset"];

	XCTAssertFalse([[self fullPreset] savePresetToURL:url]);
}

- (void)testLoadPresetFromAMissingFileIsNil
{
	XCTAssertNil([FxGripPreset loadPresetFromURL:[self fileURLNamed:@"absent.fxpreset"]]);
}

- (void)testLoadPresetFromANilURLIsNil
{
	NSURL *url = nil;

	XCTAssertNil([FxGripPreset loadPresetFromURL:url]);
}

- (void)testLoadPresetFromAnArrayPropertyListIsNil
{
	NSURL *url = [self fileURLNamed:@"array.fxpreset"];
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:@[@"one", @"two"]
															  format:NSPropertyListXMLFormat_v1_0
															 options:0
															   error:NULL];
	XCTAssertTrue([data writeToURL:url atomically:YES]);

	XCTAssertNil([FxGripPreset loadPresetFromURL:url]);
}

- (void)testLoadPresetFromDataThatIsNotAPropertyListIsNil
{
	NSURL *url = [self fileURLNamed:@"garbage.fxpreset"];
	XCTAssertTrue([[@"not a property list" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url atomically:YES]);

	XCTAssertNil([FxGripPreset loadPresetFromURL:url]);
}

- (void)testLoadPresetFromAnEmptyFileIsNil
{
	NSURL *url = [self fileURLNamed:@"empty.fxpreset"];
	XCTAssertTrue([NSData.data writeToURL:url atomically:YES]);

	XCTAssertNil([FxGripPreset loadPresetFromURL:url]);
}

/*! A malformed section never reaches the apply path: the load drops it, so
	presetSections omits it. */
- (void)testPresetSectionsOmitsAMalformedSection
{
	FxGripPreset *preset = [FxGripPreset.alloc initWithPresetDictionary:@{kFxFactoryPresetKey_ParameterValues: @"oops"}];

	XCTAssertNil(preset.presetSections[kFxParameterProperty_TargetPresetValues]);
}

- (void)testSavePresetReturnsNoForAValueThatIsNotAPropertyListType
{
	FxGripPreset *preset = [FxGripPreset.alloc init];
	preset.parameterValues = @{@"104": [NSObject new]};

	XCTAssertFalse([preset savePresetToURL:[self fileURLNamed:@"bad.fxpreset"]]);
}

- (void)testANonDictionaryValuesSectionIsDroppedAtLoadAndTheRestStillSaves
{
	FxGripPreset *preset = [FxGripPreset.alloc initWithPresetDictionary:@{kFxFactoryPresetKey_ParameterValues: @"oops",
																		  kFxGripPresetKey_DisplayName: @"Kept"}];

	XCTAssertNil(preset.parameterValues);
	BOOL saved = NO;
	XCTAssertNoThrow(saved = [preset savePresetToURL:[self fileURLNamed:@"oops.fxpreset"]]);
	XCTAssertTrue(saved);
	XCTAssertEqualObjects([FxGripPreset loadPresetFromURL:[self fileURLNamed:@"oops.fxpreset"]].name, @"Kept");
}

/*! A wrongly-typed scalar is dropped, so the listing's filename fill-in applies. */
- (void)testANonStringDisplayNameIsDroppedAtLoad
{
	FxGripPreset *preset = [FxGripPreset.alloc initWithPresetDictionary:@{kFxGripPresetKey_DisplayName: @42,
																		  kFxGripPresetKey_Tag: @[@"nope"]}];

	XCTAssertNil(preset.name);
	XCTAssertNil(preset.tag);
}

#pragma mark FxFactory sample fidelity

- (FxGripPreset *)fxFactorySample
{
	// The sample is an external fixture beside the project; skip rather than fail when it is
	// absent so a moved fixture reads as "restore the file", not a code regression.
	if (![NSFileManager.defaultManager fileExistsAtPath:FxGripPresetFileTestSampleURL().path]) {
		XCTSkip(@"the FxFactory sample is expected at %@", FxGripPresetFileTestSampleURL().path);
	}
	NSURL *url = FxGripPresetFileTestSampleURL();
	FxGripPreset *preset = [FxGripPreset loadPresetFromURL:url];
	XCTAssertNotNil(preset, @"the FxFactory sample is expected at %@", url.path);
	return preset;
}

- (void)testFxFactorySampleReadsTheCreatedByParameterId
{
	FxGripPreset *preset = [self fxFactorySample];
	XCTAssertEqual(preset.createdByParameterId, 117u);
}

- (void)testFxFactorySampleReadsTheParameterValuesUnderStringKeys
{
	NSDictionary *values = [self fxFactorySample].parameterValues;

	XCTAssertEqualObjects(values[@"104"], @12);
	XCTAssertEqualObjects(values[@"112"], (@{@"x": @0.5, @"y": @0.5}));
	XCTAssertEqualObjects(values[@"118"], @"Curve/InverseQuadratic.png");
	XCTAssertNil(values[@104]);
}

- (void)testFxFactorySampleReadsThePluginIdentity
{
	FxGripPreset *preset = [self fxFactorySample];

	XCTAssertEqualObjects(preset.pluginUuid, @"77C0D916-29A6-4D97-A09A-21DE2858C8E5");
	XCTAssertEqualObjects(preset.pluginAuthor, @"Noise Industries, LLC");
	XCTAssertEqualObjects(preset.pluginLocalizedName, (@{@"English": @"Circle"}));
	XCTAssertEqualObjects(preset.pluginVersion, @"1.0");
	XCTAssertEqualObjects(preset.productId, @"fxfactorypro");
}

- (void)testFxFactorySampleCarriesNoneOfTheFxGripOnlyFields
{
	FxGripPreset *preset = [self fxFactorySample];

	XCTAssertNil(preset.framework);
	XCTAssertNil(preset.uuid);
	XCTAssertNil(preset.name);
	XCTAssertNil(preset.tag);
	XCTAssertNil(preset.createdTime);
	XCTAssertNil(preset.parameterTags);
	XCTAssertNil(preset.parameterMeta);
}

- (void)testFxFactorySampleRewritesToTheSameFileKeys
{
	FxGripPreset *preset = [self fxFactorySample];
	NSURL *url = [self fileURLNamed:@"Circle.fxpreset"];
	XCTAssertTrue([preset savePresetToURL:url]);

	NSDictionary *rewritten = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:url]
																	   options:NSPropertyListImmutable
																		format:NULL
																		 error:NULL];
	NSDictionary *sample = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:FxGripPresetFileTestSampleURL()]
																	options:NSPropertyListImmutable
																	 format:NULL
																	  error:NULL];
	XCTAssertEqualObjects(rewritten, sample);
}

@end
