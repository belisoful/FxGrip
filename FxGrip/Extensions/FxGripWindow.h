//
//  FxGripWindow.h
//  FxGrip
//

#ifndef FxGripWindow_h
#define FxGripWindow_h

#import <AppKit/AppKit.h>
#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const FxGripWindowExtensionKey;

/*!
	@class      FxGripWindow
	@abstract   The extension that manages the plug-in's one host window.
	@discussion Introduced in FxGrip 1.0. FxRemoteWindowAPI limits a plug-in instance to a single
				host-created window: repeat requests return the same parent view, and the user can
				close the window at any time. This extension owns that lifecycle. It requests the
				window through the highest FxRemoteWindowAPI version the host vends, installs the
				content view into the host's parent view when the window arrives, and tracks
				whether a window is presented.

				The host shows its own affordance for an open plug-in window (the plug-in button
				near the title bar), so presenting the window is the only integration a plug-in
				performs.

				The reply from the host arrives asynchronously. State changes and the completion
				run on the caller's thread of the host's reply; present from the main thread.
*/
@interface FxGripWindow : FxGripExtension

/*! The host's parent view for the plug-in's window; nil when no window is presented. */
@property (readonly, nullable, nonatomic) NSView *windowParentView;

/*! YES between a successful presentation and closeWindow (or a failed present). */
@property (readonly, nonatomic, getter=isWindowPresented) BOOL windowPresented;

/*! The view installed into the window. Setting while presented swaps it in place. */
@property (readwrite, strong, nullable, nonatomic) NSView *contentView;

/*!
	@method     presentWindowOfSize:completion:
	@abstract   Requests the host window at a fixed content size; installs contentView on arrival.
	@discussion Completion receives the host's parent view, or nil and an error when the host
				cannot create the window or no FxRemoteWindowAPI is vended. While a window is
				already presented, the host returns the same parent view.
*/
- (void)presentWindowOfSize:(CGSize)contentSize
				 completion:(void (^ _Nullable)(NSView * _Nullable parentView, NSError * _Nullable error))completion;

/*!
	@method     presentWindowWithMinimumSize:maximumSize:completion:
	@abstract   Requests a resizable host window; installs contentView on arrival.
	@discussion Uses FxRemoteWindowAPI_v2. The host caps the maximum at 80% of its own window.
				Falls back to a fixed-size window of minContentSize when the host vends only v1.
*/
- (void)presentWindowWithMinimumSize:(CGSize)minContentSize
						 maximumSize:(CGSize)maxContentSize
						  completion:(void (^ _Nullable)(NSView * _Nullable parentView, NSError * _Nullable error))completion;

/*!
	@method     closeWindow
	@abstract   Asks the host to close the window; returns YES when the request was made.
	@discussion Uses FxRemoteWindowAPI_v3. A host that vends only v1 or v2 cannot close the
				window programmatically; the method clears the extension's state and returns NO,
				and the user closes the window.
*/
- (BOOL)closeWindow;

/*!
	@method     noteWindowClosed
	@abstract   Clears the presented state after the user closes the window.
	@discussion The host does not notify the plug-in when the user closes the window. A plug-in
				that detects the closure (its content view left the window) calls this so the next
				present request starts clean. Calling it while presented only clears state.
*/
- (void)noteWindowClosed;

@end


@interface FxGripTileableEffect (Window)

/*! The loaded FxGripWindow extension; nil when none is loaded. */
@property (readonly, nullable, nonatomic) FxGripWindow *windowExtension;

/*! YES when an FxGripWindow extension is loaded. */
@property (readonly, nonatomic) BOOL hasWindowExtension;

/*! A new window extension for the effect's loadExtensions override. */
- (FxGripWindow *)newWindowExtension;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripWindow_h */
