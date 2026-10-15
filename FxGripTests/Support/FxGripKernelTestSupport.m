/*!
	@file       FxGripKernelTestSupport.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelTestSupport
	@abstract   Implements the fixture loaders and the slangc lookup.
	@discussion Introduced in FxGrip 0.1.0. The fixtures are copied flat into the test bundle's
	            resources, so a fixture is found by name and extension.
*/

#import "FxGripKernelTestSupport.h"

@interface FxGripKernelTestSupportAnchor : NSObject
@end

@implementation FxGripKernelTestSupportAnchor
@end

static NSBundle *FxGripKernelTestBundle(void)
{
	return [NSBundle bundleForClass:FxGripKernelTestSupportAnchor.class];
}

NSURL *_Nullable FxGripKernelTestFixtureURL(NSString *name, NSString *extension)
{
	return [FxGripKernelTestBundle() URLForResource:name withExtension:extension];
}

static NSString *FxGripKernelTestText(NSString *name, NSString *extension)
{
	NSURL *url = FxGripKernelTestFixtureURL(name, extension);
	NSString *text = url != nil ? [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:NULL] : nil;
	NSCAssert(text != nil, @"The fixture %@.%@ is missing from the test bundle.", name, extension);
	return text;
}

NSString *FxGripKernelTestSlangSource(NSString *name)
{
	return FxGripKernelTestText(name, @"slang");
}

NSString *FxGripKernelTestMetalSource(NSString *name)
{
	return FxGripKernelTestText(name, @"metal");
}

NSData *FxGripKernelTestLayoutData(NSString *name)
{
	NSURL *url = FxGripKernelTestFixtureURL(name, @"json");
	NSData *data = url != nil ? [NSData dataWithContentsOfURL:url] : nil;
	NSCAssert(data != nil, @"The fixture %@.json is missing from the test bundle.", name);
	return data;
}

NSData *FxGripKernelTestEditedLayoutData(NSString *name, void (^edit)(NSMutableDictionary *root))
{
	NSMutableDictionary *root = [NSJSONSerialization JSONObjectWithData:FxGripKernelTestLayoutData(name)
																options:NSJSONReadingMutableContainers
																  error:NULL];
	edit(root);
	return [NSJSONSerialization dataWithJSONObject:root options:0 error:NULL];
}

FxGripKernelLayout *_Nullable FxGripKernelTestLayout(NSString *name, NSError *_Nullable *_Nullable error)
{
	return [FxGripKernelLayout layoutWithJSONData:FxGripKernelTestLayoutData(name) error:error];
}

FxGripShaderMetadata *_Nullable FxGripKernelTestMetadata(NSString *name, NSError *_Nullable *_Nullable error)
{
	return [FxGripShaderMetadata metadataWithSource:FxGripKernelTestSlangSource(name) error:error];
}

FxGripKernelPipeline *_Nullable FxGripKernelTestPipeline(NSString *name,
														 NSString *_Nullable metalSource,
														 NSData *_Nullable layoutData,
														 FxGripShaderMetadata *_Nullable metadata)
{
	FxGripKernelLayout *layout = [FxGripKernelLayout layoutWithJSONData:layoutData ?: FxGripKernelTestLayoutData(name) error:NULL];
	FxGripShaderMetadata *scanned = metadata ?: FxGripKernelTestMetadata(name, NULL);
	if (layout == nil || scanned == nil) {
		return nil;
	}
	return [[FxGripKernelPipeline alloc] initWithMetalSource:metalSource ?: FxGripKernelTestMetalSource(name)
													  layout:layout
													metadata:scanned];
}

NSURL *_Nullable FxGripKernelTestModuleURL(void)
{
	return [[NSBundle bundleForClass:FxGripKernelLayout.class] URLForResource:@"GripKernel" withExtension:@"slang"];
}

NSString *_Nullable FxGripKernelTestSlangcPath(void)
{
	NSFileManager *files = NSFileManager.defaultManager;
	NSDictionary<NSString *, NSString *> *environment = NSProcessInfo.processInfo.environment;
	NSString *named = environment[@"FXGRIP_SLANGC"];
	if (named.length > 0) {
		return [files isExecutableFileAtPath:named] ? named : nil;
	}
	for (NSString *directory in [environment[@"PATH"] componentsSeparatedByString:@":"]) {
		NSString *candidate = [directory stringByAppendingPathComponent:@"slangc"];
		if (directory.length > 0 && [files isExecutableFileAtPath:candidate]) {
			return candidate;
		}
	}
	return nil;
}
