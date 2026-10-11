/*!
	@file       FxGripFinalCutPro.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFinalCutPro
	@abstract   Locates the installed Final Cut Pro and hands it FCPXML documents.
	@discussion Introduced in FxGrip 0.1.0. The class finds the application by bundle identifier
	            (the App Store build and the trial), reports whether it is running, finds the
	            FCPXML DTDs it installs, and opens an FCPXML file in it, which imports the file's
	            contents into the open library. Opening is the one route into Final Cut Pro that
	            works from any process; a workflow extension additionally drags documents into
	            the timeline through ``FxGripFCPXMLPasteboard``.
*/

#ifndef FxGripFinalCutPro_h
#define FxGripFinalCutPro_h

#import <AppKit/AppKit.h>
#import <FxGrip/FxGripFCPXMLVersion.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

NS_ASSUME_NONNULL_BEGIN

/*! Final Cut Pro's bundle identifier, `com.apple.FinalCut`. */
FOUNDATION_EXPORT NSString *const FxGripFinalCutProBundleIdentifier;
/*! The Final Cut Pro trial's bundle identifier, `com.apple.FinalCutTrial`. */
FOUNDATION_EXPORT NSString *const FxGripFinalCutProTrialBundleIdentifier;
/*! The uniform type identifier of a `.fcpxml` file, `com.apple.finalcutpro.xml`. */
FOUNDATION_EXPORT NSString *const FxGripFinalCutProFCPXMLTypeIdentifier;
/*! The uniform type identifier of a `.fcpxmld` package, `com.apple.finalcutpro.xmld`. */
FOUNDATION_EXPORT NSString *const FxGripFinalCutProFCPXMLBundleTypeIdentifier;
/*! The extension point a workflow extension declares, `com.apple.FinalCut.WorkflowExtension`. */
FOUNDATION_EXPORT NSString *const FxGripFinalCutProWorkflowExtensionPointIdentifier;
/*! The scripting access group a workflow extension needs to inspect libraries,
	`com.apple.FinalCut.library.inspection`. */
FOUNDATION_EXPORT NSString *const FxGripFinalCutProLibraryInspectionAccessGroup;

/*! Receives the result of an open request. */
typedef void (^FxGripFinalCutProOpenCompletion)(NSRunningApplication * _Nullable application, NSError * _Nullable error);

/*!
	@class      FxGripFinalCutPro
	@abstract   The installed Final Cut Pro.
	@discussion Introduced in FxGrip 0.1.0. Every method is a pure class method.
*/
@interface FxGripFinalCutPro : NSObject

/*! The bundle identifiers that name Final Cut Pro, the App Store build first. */
+ (NSArray<NSString *> *)bundleIdentifiers;

/*! The installed application, or nil when none is installed. */
+ (nullable NSURL *)applicationURL;
/*! YES when Final Cut Pro is installed. */
+ (BOOL)isInstalled;
/*! The installed application's version string, or nil. */
+ (nullable NSString *)installedVersion;
/*! The running Final Cut Pro, or nil. */
+ (nullable NSRunningApplication *)runningApplication;
/*! YES when Final Cut Pro is running. */
+ (BOOL)isRunning;

/*! The FCPXML versions whose DTDs the installed application carries, ascending. */
+ (NSArray<NSString *> *)installedDTDVersions;
/*! The newest installed DTD version, or the invalid version when none is installed. */
+ (FxGripFCPXMLVersion)newestInstalledDTDVersion;
/*! The installed DTD file for a version, or nil. */
+ (nullable NSURL *)installedDTDURLForVersion:(FxGripFCPXMLVersion)version;

/*!
	@method     openFileURL:completion:
	@abstract   Opens a `.fcpxml` or `.fcpxmld` file in Final Cut Pro, which imports it.
	@discussion The completion runs on an arbitrary queue when the application reports the open.
				Fails at once with an error when Final Cut Pro is not installed.
*/
+ (void)openFileURL:(nullable NSURL *)fileURL completion:(nullable FxGripFinalCutProOpenCompletion)completion;

/*!
	@method     openDocument:named:completion:
	@abstract   Writes a document to a temporary `.fcpxml` file and opens it in Final Cut Pro.
	@param      document	The document.
	@param      name		The file name Final Cut Pro shows for the import, or nil.
	@param      completion	The completion, as for `openFileURL:completion:`.
*/
+ (void)openDocument:(FxGripFCPXMLDocument *)document named:(nullable NSString *)name
		  completion:(nullable FxGripFinalCutProOpenCompletion)completion;

/*! Brings Final Cut Pro to the front when it is running; YES when it was. */
+ (BOOL)activate;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFinalCutPro_h */
