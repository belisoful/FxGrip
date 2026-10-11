/*!
	@file       FxGripWorkflowViewController.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowViewController
	@abstract   The principal view controller base for a Final Cut Pro workflow extension.
	@discussion Introduced in FxGrip 0.1.0. A workflow extension is an app extension of the
	            `com.apple.FinalCut.WorkflowExtension` point whose Info.plist names its
	            `ProExtensionPrincipalViewControllerClass`; Final Cut Pro shows the controller's
	            view in a floating window sized by the `ProExtensionAttributes` minimums. This base
	            owns the mailbox client and the host client, accepts FCPXML drops through
	            ``FxGripWorkflowDropView``, starts FCPXML drags into Final Cut Pro, sends documents
	            to the host for import, and checks the extension bundle's configuration.
*/

#ifndef FxGripWorkflowViewController_h
#define FxGripWorkflowViewController_h

#import <AppKit/AppKit.h>
#import <FxGrip/FxGripFCPXMLDocument.h>
#import <FxGripWorkflow/FxGripWorkflowClient.h>
#import <FxGripWorkflow/FxGripFinalCutHost.h>

NS_ASSUME_NONNULL_BEGIN

/*! The Info.plist key that names the principal view controller class. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowPrincipalViewControllerClassKey;
/*! The Info.plist key of the extension attributes dictionary. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowExtensionAttributesKey;
/*! The attribute naming the content view's minimum width. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowContentViewMinimumWidthKey;
/*! The attribute naming the content view's minimum height. */
FOUNDATION_EXPORT NSString *const FxGripWorkflowContentViewMinimumHeightKey;

/*!
	@class      FxGripWorkflowDropView
	@abstract   A view that accepts FCPXML drops and hands the parsed document to a handler.
	@discussion Introduced in FxGrip 0.1.0. It accepts the FCPXML pasteboard type, `.fcpxml`
				and `.fcpxmld` file URLs, and text that parses as FCPXML.
*/
@interface FxGripWorkflowDropView : NSView
/*! Runs with each dropped document. */
@property (readwrite, copy, nullable) void (^documentHandler)(FxGripFCPXMLDocument *document);
/*! The drag operation a drop performs; default copy. */
@property (readwrite) NSDragOperation dropOperation;
@end

/*!
	@class      FxGripWorkflowViewController
	@abstract   The base class of a workflow extension's principal view controller.
	@discussion Introduced in FxGrip 0.1.0. Subclass it, name the subclass in the Info.plist, and
				override `workflowDidReceiveDocument:` and `workflowClientDidChange`.
*/
@interface FxGripWorkflowViewController : NSViewController

/*! The extension point identifier, `com.apple.FinalCut.WorkflowExtension`. */
+ (NSString *)extensionPointIdentifier;

/*!
	@method     configurationProblemsForBundle:
	@abstract   The Info.plist and entitlement problems an extension bundle shows.
	@discussion Checks the extension point identifier, the principal view controller class, the
				content view minimums, the sandbox, and the Apple Events entitlements the library
				inspection needs. Each problem is a sentence. An empty array means the bundle is
				configured as a workflow extension.
*/
+ (NSArray<NSString *> *)configurationProblemsForBundle:(NSBundle *)bundle;

/*! The checks of `configurationProblemsForBundle:` over an Info.plist and an entitlements
	dictionary; nil entitlements skips the entitlement checks. */
+ (NSArray<NSString *> *)configurationProblemsForInfoDictionary:(nullable NSDictionary<NSString *, id> *)info
												   entitlements:(nullable NSDictionary<NSString *, id> *)entitlements;

/*! The mailbox client, or nil when the process has no App Group. Created on first access. */
@property (readonly, nullable, strong, nonatomic) FxGripWorkflowClient *client;
/*! The host client. */
@property (readonly, strong, nonatomic) FxGripFinalCutHost *host;

/*!
	@method     workflowDidReceiveDocument:
	@abstract   Called with each document dropped on a registered drop view.
	@discussion The base does nothing; a subclass overrides it.
*/
- (void)workflowDidReceiveDocument:(FxGripFCPXMLDocument *)document;

/*!
	@method     workflowClientDidChange
	@abstract   Called on the main queue after the mailbox changes: new instances, exports, or presence.
	@discussion The base does nothing; a subclass overrides it to refresh its instance list.
*/
- (void)workflowClientDidChange;

/*! Makes a view accept FCPXML drops, routing each document to `workflowDidReceiveDocument:`. */
- (void)registerForFCPXMLDropsOnView:(FxGripWorkflowDropView *)view;

/*!
	@method     draggingItemForDocument:inView:image:
	@abstract   A dragging item that carries a document, for `beginDraggingSessionWithItems:event:source:`.
	@discussion Final Cut Pro accepts the drop in its browser and timeline as an FCPXML import.
*/
- (NSDraggingItem *)draggingItemForDocument:(FxGripFCPXMLDocument *)document
									 inView:(NSView *)view
									  image:(nullable NSImage *)image;

/*! Opens a document in Final Cut Pro, which imports it. */
- (void)sendDocumentToFinalCutPro:(FxGripFCPXMLDocument *)document named:(nullable NSString *)name
					   completion:(nullable void (^)(NSError * _Nullable error))completion;

/*! Starts the mailbox client; `viewDidLoad` calls it. */
- (void)startWorkflowClient;
/*! Stops the mailbox client. */
- (void)stopWorkflowClient;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripWorkflowViewController_h */
