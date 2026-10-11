/*!
	@file       FxGripFCPXMLPasteboardTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLPasteboardTests
	@abstract   Tests the FCPXML pasteboard helpers and the Final Cut Pro locator.
	@discussion Introduced in FxGrip 0.1.0. The pasteboard tests use a private pasteboard. The locator
	            tests assert the constants and, when Final Cut Pro is installed, that the DTDs and the
	            version are found; without it they assert the absent answers.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripFCPXMLPasteboard.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>
#import <FxGrip/FxGripErrors.h>

@interface FxGripFCPXMLPasteboardTests : XCTestCase
@property (nonatomic, strong) NSPasteboard *pasteboard;
@end

@implementation FxGripFCPXMLPasteboardTests

- (void)setUp
{
	[super setUp];
	self.pasteboard = [NSPasteboard pasteboardWithUniqueName];
}

- (void)tearDown
{
	[self.pasteboard releaseGlobally];
	[super tearDown];
}

- (FxGripFCPXMLDocument *)document
{
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[document.resources effectForFxPlugUUID:@"UUID-1" name:@"Grip"];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:[FxGripFCPXMLStoryElement clipWithName:@"C" duration:CMTimeMake(1, 1)]];
	return document;
}

- (void)testWritesAndReadsTheFCPXMLType
{
	XCTAssertEqualObjects(FxGripFCPXMLPasteboardType, @"com.apple.finalcutpro.xml");
	XCTAssertEqualObjects(FxGripFCPXMLPasteboardType, FxGripFinalCutProFCPXMLTypeIdentifier);
	XCTAssertFalse([FxGripFCPXMLPasteboard pasteboardHasDocument:self.pasteboard]);
	FxGripFCPXMLDocument *document = self.document;
	XCTAssertTrue([FxGripFCPXMLPasteboard writeDocument:document toPasteboard:self.pasteboard]);
	XCTAssertTrue([FxGripFCPXMLPasteboard pasteboardHasDocument:self.pasteboard]);
	XCTAssertNotNil([self.pasteboard dataForType:FxGripFCPXMLPasteboardType]);
	XCTAssertTrue([[self.pasteboard stringForType:NSPasteboardTypeString] containsString:@"<fcpxml"]);
	NSError *error = nil;
	FxGripFCPXMLDocument *read = [FxGripFCPXMLPasteboard documentFromPasteboard:self.pasteboard error:&error];
	XCTAssertNotNil(read, @"%@", error);
	XCTAssertEqualObjects(read.XMLString, document.XMLString);
	XCTAssertFalse([FxGripFCPXMLPasteboard writeDocument:nil toPasteboard:self.pasteboard]);
}

- (void)testReadsAPlainStringAndAFileURL
{
	[self.pasteboard clearContents];
	[self.pasteboard setString:self.document.XMLString forType:NSPasteboardTypeString];
	XCTAssertNotNil([FxGripFCPXMLPasteboard documentFromPasteboard:self.pasteboard error:NULL]);

	[self.pasteboard clearContents];
	[self.pasteboard setString:@"just text" forType:NSPasteboardTypeString];
	XCTAssertNil([FxGripFCPXMLPasteboard documentFromPasteboard:self.pasteboard error:NULL]);

	NSError *error = nil;
	NSURL *fileURL = [FxGripFCPXMLPasteboard writeDocument:self.document toTemporaryFileNamed:@"Drop" error:&error];
	XCTAssertNotNil(fileURL, @"%@", error);
	XCTAssertEqualObjects(fileURL.lastPathComponent, @"Drop.fcpxml");
	[self.pasteboard clearContents];
	[self.pasteboard writeObjects:@[fileURL]];
	FxGripFCPXMLDocument *fromFile = [FxGripFCPXMLPasteboard documentFromPasteboard:self.pasteboard error:&error];
	XCTAssertNotNil(fromFile, @"%@", error);
	[NSFileManager.defaultManager removeItemAtURL:fileURL.URLByDeletingLastPathComponent error:NULL];

	NSURL *named = [FxGripFCPXMLPasteboard writeDocument:self.document toTemporaryFileNamed:@"Already.fcpxml" error:NULL];
	XCTAssertEqualObjects(named.lastPathComponent, @"Already.fcpxml");
	[NSFileManager.defaultManager removeItemAtURL:named.URLByDeletingLastPathComponent error:NULL];
	NSURL *unnamed = [FxGripFCPXMLPasteboard writeDocument:self.document toTemporaryFileNamed:nil error:NULL];
	XCTAssertEqualObjects(unnamed.lastPathComponent, @"FxGrip.fcpxml");
	[NSFileManager.defaultManager removeItemAtURL:unnamed.URLByDeletingLastPathComponent error:NULL];
}

- (void)testPasteboardItemCarriesBothTypes
{
	NSPasteboardItem *item = [FxGripFCPXMLPasteboard pasteboardItemForDocument:self.document];
	XCTAssertTrue([item.types containsObject:FxGripFCPXMLPasteboardType]);
	XCTAssertTrue([item.types containsObject:NSPasteboardTypeString]);
	XCTAssertEqualObjects(FxGripFCPXMLPasteboard.readableTypes.firstObject, FxGripFCPXMLPasteboardType);
}

#pragma mark - Final Cut Pro

- (void)testFinalCutProConstants
{
	XCTAssertEqualObjects(FxGripFinalCutProBundleIdentifier, @"com.apple.FinalCut");
	XCTAssertEqualObjects(FxGripFinalCutProTrialBundleIdentifier, @"com.apple.FinalCutTrial");
	XCTAssertEqualObjects(FxGripFinalCutPro.bundleIdentifiers, (@[@"com.apple.FinalCut", @"com.apple.FinalCutTrial"]));
	XCTAssertEqualObjects(FxGripFinalCutProFCPXMLBundleTypeIdentifier, @"com.apple.finalcutpro.xmld");
	XCTAssertEqualObjects(FxGripFinalCutProWorkflowExtensionPointIdentifier, @"com.apple.FinalCut.WorkflowExtension");
	XCTAssertEqualObjects(FxGripFinalCutProLibraryInspectionAccessGroup, @"com.apple.FinalCut.library.inspection");
}

- (void)testFinalCutProDiscovery
{
	if (!FxGripFinalCutPro.isInstalled) {
		XCTAssertNil(FxGripFinalCutPro.applicationURL);
		XCTAssertNil(FxGripFinalCutPro.installedVersion);
		XCTAssertEqualObjects(FxGripFinalCutPro.installedDTDVersions, @[]);
		XCTAssertFalse(FxGripFCPXMLVersionIsValid(FxGripFinalCutPro.newestInstalledDTDVersion));
		XCTAssertNil([FxGripFinalCutPro installedDTDURLForVersion:FxGripFCPXMLVersionLatest()]);
		XCTestExpectation *failed = [self expectationWithDescription:@"open fails without Final Cut Pro"];
		[FxGripFinalCutPro openDocument:self.document named:@"X" completion:^(NSRunningApplication *application, NSError *error) {
			XCTAssertNil(application);
			XCTAssertEqual(error.code, kFxGripError_FCPXML);
			[failed fulfill];
		}];
		[self waitForExpectations:@[failed] timeout:5];
		return;
	}
	XCTAssertNotNil(FxGripFinalCutPro.applicationURL);
	XCTAssertTrue(FxGripFinalCutPro.installedVersion.length > 0);
	NSArray<NSString *> *versions = FxGripFinalCutPro.installedDTDVersions;
	XCTAssertTrue(versions.count >= 15, @"%@", versions);
	XCTAssertEqualObjects(versions.firstObject, @"1.0");
	FxGripFCPXMLVersion newest = FxGripFinalCutPro.newestInstalledDTDVersion;
	XCTAssertTrue(FxGripFCPXMLVersionCompare(newest, FxGripFCPXMLVersionLatest()) != NSOrderedAscending,
				  @"the installed Final Cut Pro is at least as new as the schema table");
	XCTAssertNotNil([FxGripFinalCutPro installedDTDURLForVersion:FxGripFCPXMLVersionMake(1, 10)]);
	XCTAssertNil([FxGripFinalCutPro installedDTDURLForVersion:FxGripFCPXMLVersionMake(9, 9)]);
	XCTAssertNil([FxGripFinalCutPro installedDTDURLForVersion:FxGripFCPXMLVersionInvalid]);
	XCTAssertEqual(FxGripFinalCutPro.isRunning, FxGripFinalCutPro.runningApplication != nil);
	if (!FxGripFinalCutPro.isRunning) {
		XCTAssertFalse(FxGripFinalCutPro.activate);
	}
}

- (void)testOpenRefusesANilFile
{
	XCTestExpectation *done = [self expectationWithDescription:@"completion runs"];
	[FxGripFinalCutPro openFileURL:nil completion:^(NSRunningApplication *application, NSError *error) {
		XCTAssertNil(application);
		XCTAssertEqual(error.code, kFxGripError_FCPXML);
		[done fulfill];
	}];
	[self waitForExpectations:@[done] timeout:5];
}

@end
