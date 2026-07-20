#import <TargetConditionals.h>
#if TARGET_OS_OSX
//
//  NSOpenPanel+BESecurityScopedURLManager.h
//  BESecurityScopedURLManager
//
//  Optional AppKit convenience category for NSOpenPanel integration.
//  Include this file only in projects that use macOS AppKit.
//

#import <AppKit/AppKit.h>
#import <BEFoundation/BESecurityScopedURLManager.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - NSOpenPanel Convenience Category

/*!
 @category      NSOpenPanel (BESecurityScopedURLManager)
 @abstract      Extends NSOpenPanel to automatically bookmark selected URLs.
 @discussion    These methods allow users to select files/directories via NSOpenPanel, and upon successful
				completion, automatically add security-scoped bookmarks to an associated BESecurityScopedURLManager.
				This simplifies the common workflow of allowing users to grant persistent access to files and folders.
				
				This is an OPTIONAL category that requires AppKit. Include this file only if your project uses AppKit.
				The core BESecurityScopedURLManager framework does not require AppKit.

				@code
				BESecurityScopedURLManager *manager = ...;

				NSOpenPanel *panel = [NSOpenPanel ss_openPanelWithManager:manager];
				panel.canChooseDirectories = YES;
				panel.allowsMultipleSelection = YES;

				// On NSModalResponseOK the chosen URLs are bookmarked into the manager
				// (via ss_addURLsToCatalog:) before the handler runs.
				[panel ss_beginWithCompletionHandler:^(NSModalResponse result) {
					if (result == NSModalResponseOK) {
						// Bookmarks already added; manager now has persistent access.
					}
				}];

				// Or drive bookmark creation directly (e.g. in tests), without the panel UI:
				NSArray<NSURL *> *failed = [panel ss_addURLsToCatalog:someURLs];
				@endcode
 */
@interface NSOpenPanel (BESecurityScopedURLManager)

/*!
 @property      ss_urlManager
 @abstract      The manager instance to receive the security-scoped bookmarks after the panel completes.
 @discussion    Set this property before presenting the panel to specify where bookmarks should be stored.
				If nil, no bookmarks are created when the user selects files. The panel holds a strong
				reference to the manager for its lifetime, keeping it alive while the panel is open.
 */
@property (nonatomic, strong, nullable) BESecurityScopedURLManager *ss_urlManager;

/*!
 @property      ss_bookmarkLifetime
 @abstract      The bookmark lifetime to use when adding bookmarks from panel selections.
 @discussion    Default: BESecurityScopedURLBookmarkLifetimeLongLived. Short-lived bookmarks exist only for the
				current session, while long-lived bookmarks are persisted and restored on future launches.
 */
@property (nonatomic) BESecurityScopedURLBookmarkLifetime ss_bookmarkLifetime;

/*!
 @method        ss_openPanel
 @abstract      Creates and configures an NSOpenPanel with the shared manager.
 @discussion    Convenience factory that creates a new panel and associates it with the shared manager instance.
				Use this method when you want bookmarks stored in the application-wide manager.
 @return        A new NSOpenPanel instance configured with the shared manager and default bookmark lifetime.
 */
+ (instancetype)ss_openPanel;

/*!
 @method        ss_openPanelWithManager:
 @abstract      Creates and configures an NSOpenPanel with a specific manager.
 @discussion    Convenience factory that allows you to specify which manager should receive bookmarks from
				the panel. Useful when managing separate bookmark catalogs for different purposes.
 @param         manager The manager instance to associate with the panel. May be nil, in
				which case no bookmarks are created from the panel's selection.
 @return        A new NSOpenPanel instance configured with the provided manager.
 */
+ (instancetype)ss_openPanelWithManager:(nullable BESecurityScopedURLManager *)manager;

/*!
 @method        ss_beginWithCompletionHandler:
 @abstract      Presents the open panel and automatically adds selected URLs to the configured manager.
 @discussion    This method wraps the standard beginWithCompletionHandler: and adds automatic bookmark creation.
				If the user selects OK, all chosen URLs are added to the manager's catalog (via
				ss_addURLsToCatalog:) using the configured bookmark lifetime, and the completion handler is
				then called. URLs that fail to bookmark are logged but do not abort the others; if you need to
				react to partial failures, call ss_addURLsToCatalog: yourself from the handler.

				Like all NSOpenPanel presentation, this must be called on the main thread, and the completion
				handler is invoked on the main thread.
 @param         handler The completion handler to execute after the panel closes and bookmarks have been
				processed. May be nil. The handler receives the NSModalResponse from the user's action.
 */
- (void)ss_beginWithCompletionHandler:(nullable void (^)(NSModalResponse result))handler;

/*!
 @method        ss_addURLsToCatalog:
 @abstract      Adds the given URLs to the configured manager's catalog as security-scoped bookmarks.
 @discussion    Uses ss_bookmarkLifetime for each URL. This is the seam invoked by
				ss_beginWithCompletionHandler: on NSModalResponseOK; it is exposed so the bookmark-creation
				logic can be exercised directly (including in unit tests) without driving the panel UI. If
				ss_urlManager is nil, no work is performed and an empty array is returned.
 @param         urls The file URLs to bookmark.
 @return        The subset of @c urls that were attempted but could not be bookmarked (empty if all
				succeeded, or if there is no manager).
 */
- (NSArray<NSURL *> *)ss_addURLsToCatalog:(NSArray<NSURL *> *)urls;

@end

#pragma mark - NSOpenPanel Helper Category

/*!
 @category      NSOpenPanel (BEPanelHelper)
 @abstract      Helper methods for configuring the appearance and starting location of panels.
 @discussion    These methods provide convenient ways to set the initial directory shown in an open panel
				based on a file URL, automatically determining whether to show the directory itself or its parent.
 */
@interface NSOpenPanel (BEPanelHelper)

/*!
 @method        ss_presetDirectoryAtURL:
 @abstract      Sets the panel's initial directory based on the provided URL.
 @discussion    Intelligently determines the appropriate directory to display. If the URL points to a directory,
				that directory is used. If the URL points to a file, the file's parent directory is used.
				This is useful for returning to the last-selected file or folder on subsequent file selection dialogs.
 @param         url The file or directory URL to start browsing from. A nil or non-file URL is ignored
				(the panel's directory is left unchanged).
 */
- (void)ss_presetDirectoryAtURL:(nullable NSURL *)url;

@end

NS_ASSUME_NONNULL_END
#endif // TARGET_OS_OSX
