/*!
	@file       FxGripFinalCutPro.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFinalCutPro
	@abstract   Locates the installed Final Cut Pro and hands it FCPXML documents.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFinalCutPro.h.
*/

#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripFCPXMLPasteboard.h>
#import <FxGrip/FxGripErrors.h>

NSString *const FxGripFinalCutProBundleIdentifier = @"com.apple.FinalCut";
NSString *const FxGripFinalCutProTrialBundleIdentifier = @"com.apple.FinalCutTrial";
NSString *const FxGripFinalCutProFCPXMLTypeIdentifier = @"com.apple.finalcutpro.xml";
NSString *const FxGripFinalCutProFCPXMLBundleTypeIdentifier = @"com.apple.finalcutpro.xmld";
NSString *const FxGripFinalCutProWorkflowExtensionPointIdentifier = @"com.apple.FinalCut.WorkflowExtension";
NSString *const FxGripFinalCutProLibraryInspectionAccessGroup = @"com.apple.FinalCut.library.inspection";

static NSString *const FxGripFinalCutProDTDFolder = @"Contents/Frameworks/Interchange.framework/Resources";

@implementation FxGripFinalCutPro

+ (NSArray<NSString *> *)bundleIdentifiers
{
	return @[FxGripFinalCutProBundleIdentifier, FxGripFinalCutProTrialBundleIdentifier];
}

+ (NSURL *)applicationURL
{
	for (NSString *identifier in self.bundleIdentifiers) {
		NSURL *url = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:identifier];
		if (url != nil) {
			return url;
		}
	}
	return nil;
}

+ (BOOL)isInstalled
{
	return self.applicationURL != nil;
}

+ (NSString *)installedVersion
{
	NSURL *url = self.applicationURL;
	if (url == nil) {
		return nil;
	}
	NSBundle *bundle = [NSBundle bundleWithURL:url];
	id version = bundle.infoDictionary[@"CFBundleShortVersionString"];
	return [version isKindOfClass:NSString.class] ? version : nil;
}

+ (NSRunningApplication *)runningApplication
{
	for (NSString *identifier in self.bundleIdentifiers) {
		NSRunningApplication *application = [NSRunningApplication runningApplicationsWithBundleIdentifier:identifier].firstObject;
		if (application != nil) {
			return application;
		}
	}
	return nil;
}

+ (BOOL)isRunning
{
	return self.runningApplication != nil;
}

+ (NSURL *)dtdFolderURL
{
	NSURL *url = self.applicationURL;
	if (url == nil) {
		return nil;
	}
	// The framework's Resources entry is a symlink into Versions; a directory listing needs the real folder.
	return [[url URLByAppendingPathComponent:FxGripFinalCutProDTDFolder isDirectory:YES] URLByResolvingSymlinksInPath];
}

+ (NSArray<NSString *> *)installedDTDVersions
{
	NSURL *folder = self.dtdFolderURL;
	if (folder == nil) {
		return @[];
	}
	NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:folder
														  includingPropertiesForKeys:nil
																			 options:NSDirectoryEnumerationSkipsHiddenFiles
																			   error:NULL];
	NSMutableArray<NSString *> *versions = [NSMutableArray array];
	NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^FCPXMLv(\\d+)_(\\d+)\\.dtd$"
																			 options:0 error:NULL];
	for (NSURL *file in files) {
		NSString *name = file.lastPathComponent;
		NSTextCheckingResult *match = [pattern firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
		if (match == nil) {
			continue;
		}
		[versions addObject:[NSString stringWithFormat:@"%@.%@", [name substringWithRange:[match rangeAtIndex:1]],
							 [name substringWithRange:[match rangeAtIndex:2]]]];
	}
	[versions sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
		return FxGripFCPXMLVersionCompare(FxGripFCPXMLVersionFromString(lhs), FxGripFCPXMLVersionFromString(rhs));
	}];
	return versions;
}

+ (FxGripFCPXMLVersion)newestInstalledDTDVersion
{
	NSString *newest = self.installedDTDVersions.lastObject;
	return newest ? FxGripFCPXMLVersionFromString(newest) : FxGripFCPXMLVersionInvalid;
}

+ (NSURL *)installedDTDURLForVersion:(FxGripFCPXMLVersion)version
{
	NSURL *folder = self.dtdFolderURL;
	if (folder == nil || !FxGripFCPXMLVersionIsValid(version)) {
		return nil;
	}
	NSString *name = [NSString stringWithFormat:@"FCPXMLv%ld_%ld.dtd", (long)version.major, (long)version.minor];
	NSURL *url = [folder URLByAppendingPathComponent:name];
	return [NSFileManager.defaultManager fileExistsAtPath:url.path] ? url : nil;
}

+ (void)openFileURL:(NSURL *)fileURL completion:(FxGripFinalCutProOpenCompletion)completion
{
	NSURL *application = self.applicationURL;
	if (application == nil || fileURL == nil) {
		if (completion) {
			completion(nil, [NSError errorWithDomain:FxGripPlugErrorDomain code:kFxGripError_FCPXML
											userInfo:@{NSLocalizedDescriptionKey: application == nil
													   ? @"Final Cut Pro is not installed." : @"No file to open."}]);
		}
		return;
	}
	NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
	configuration.activates = YES;
	[NSWorkspace.sharedWorkspace openURLs:@[fileURL] withApplicationAtURL:application configuration:configuration
						completionHandler:^(NSRunningApplication *app, NSError *error) {
		if (completion) {
			completion(app, error);
		}
	}];
}

+ (void)openDocument:(FxGripFCPXMLDocument *)document named:(NSString *)name completion:(FxGripFinalCutProOpenCompletion)completion
{
	NSError *error = nil;
	NSURL *fileURL = [FxGripFCPXMLPasteboard writeDocument:document toTemporaryFileNamed:name error:&error];
	if (fileURL == nil) {
		if (completion) {
			completion(nil, error);
		}
		return;
	}
	[self openFileURL:fileURL completion:completion];
}

+ (BOOL)activate
{
	NSRunningApplication *application = self.runningApplication;
	if (application == nil) {
		return NO;
	}
	[application activateWithOptions:NSApplicationActivateAllWindows];
	return YES;
}

@end
