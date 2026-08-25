//
//  BESecurityScopedURLManager.h
//  BESecurityScopedURLManager
//
//  A thread-safe manager for persistently storing and accessing security-scoped bookmarks
//  on macOS. Handles bookmark creation, resolution, staleness, and reference-counted access.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Storage Options

/*!
 @typedef       BESecurityScopedURLStorageOption
 @abstract      Options for configuring persistent storage locations for bookmarks.
 @discussion    This bitmask specifies whether the manager should save long-lived bookmarks to
				UserDefaults, the Caches directory, or both.
 @const         BESecurityScopedURLStorageNone Do not persist bookmarks.
 @const         BESecurityScopedURLStorageUserDefaults Persist bookmarks to UserDefaults.
 @const         BESecurityScopedURLStorageCacheDirectory Persist bookmarks to an archived file in the Caches directory.
 @const         BESecurityScopedURLStorageAll Persist to both UserDefaults and Caches. (Default)
 */
typedef NS_OPTIONS(NSUInteger, BESecurityScopedURLStorageOption) {
	BESecurityScopedURLStorageNone = 0,
	BESecurityScopedURLStorageUserDefaults = 1 << 0,
	BESecurityScopedURLStorageCacheDirectory = 1 << 1,
	BESecurityScopedURLStorageAll = (BESecurityScopedURLStorageUserDefaults | BESecurityScopedURLStorageCacheDirectory)
};

#pragma mark - Bookmark Lifetime

/*!
 @typedef       BESecurityScopedURLBookmarkLifetime
 @abstract      Defines the intended lifetime of a newly created bookmark.
 @discussion    Short-lived bookmarks exist only in memory during the current session and are not persisted.
				Long-lived bookmarks are saved to the configured storage locations and restored on subsequent launches.
 @const         BESecurityScopedURLBookmarkLifetimeShortLived The bookmark is ephemeral and stored only in memory.
 @const         BESecurityScopedURLBookmarkLifetimeLongLived The bookmark is persisted to configured storage.
 */
typedef NS_ENUM(NSUInteger, BESecurityScopedURLBookmarkLifetime) {
	BESecurityScopedURLBookmarkLifetimeShortLived,
	BESecurityScopedURLBookmarkLifetimeLongLived
};

@class BESecurityScopedURLManager;

#pragma mark - Bookmark Entry Model

/*!
 @class         BESecurityScopedURLBookmarkEntry
 @abstract      Model object representing a single bookmark entry and its metadata.
 @discussion    Instances of this class are the values in the public catalog dictionary and conform to
				NSSecureCoding for safe archival and unarchival. Each entry represents a single bookmarked resource
				and maintains metadata about its current state, including staleness and security scope capability.

				The manager hands the same entry instances out through its catalog snapshot, so all of the
				entry's properties are safe to read from any thread.
 */
@interface BESecurityScopedURLBookmarkEntry : NSObject <NSSecureCoding>

/*!
 @property      url
 @abstract      The resolved URL of the bookmarked resource.
 @discussion    This property performs lazy resolution of the bookmark data. The first access triggers resolution
				and handles stale bookmark updates automatically. Returns nil if the bookmark cannot be resolved.
 */
@property (nonatomic, strong, readonly, nullable) NSURL *url;

/*!
 @property      isStale
 @abstract      Whether the bookmark is currently stale (resolved as stale and not yet refreshed).
 @discussion    A stale bookmark indicates the resource has been moved or relocated. Resolution sets this to
				YES when the bookmark is found stale, and it is reset to NO once the bookmark is successfully
				refreshed — which the manager does automatically, also notifying the delegate of relocations.
 */
@property (nonatomic, readonly) BOOL isStale;

/*!
 @property      isSecurityScoped
 @abstract      Whether the resource could be accessed as a security-scoped resource.
 @discussion    This indicates whether the bookmark has valid security scope and can be used to access
				protected file system resources.
 */
@property (nonatomic, readonly) BOOL isSecurityScoped;

/*!
 @property      bookmarkError
 @abstract      An error that occurred during bookmark creation or resolution, if any.
 @discussion    This property contains the most recent error encountered. It is set to nil if no error has occurred.
				Clients should check this property to determine if the bookmark is in a valid state.
 */
@property (nonatomic, readonly, nullable) NSError *bookmarkError;

/*!
 @property      bookmarkData
 @abstract      The raw bookmark data created by NSURL bookmark methods, or nil if creation failed.
 @discussion    This is the opaque data that can be resolved into an NSURL. It is archived when the bookmark
				is persisted to storage. The data is automatically updated when stale bookmarks are refreshed.
				It is nil when the security-scoped bookmark could not be created (e.g. in a non-sandboxed
				process); check bookmarkError in that case.
 */
@property (nonatomic, strong, readonly, nullable) NSData *bookmarkData;

/*!
 @property      urlString
 @abstract      The canonical absolute string used as this entry's catalog key.
 @discussion    For directory bookmarks, this string includes a trailing slash for consistency. This is the
				key used to look up the entry in the manager's catalog; it is updated to the new path if the
				resource is relocated.
 */
@property (nonatomic, readonly) NSString *urlString;

/*!
 @property      createdAt
 @abstract      The date this entry was created.
 @discussion    This timestamp is set when the bookmark is first created and is not changed even if the
				bookmark is later updated due to staleness.
 */
@property (nonatomic, strong, readonly) NSDate *createdAt;

/*!
 @property      lifetime
 @abstract      The intended persistence lifetime of the bookmark.
 @discussion    Short-lived bookmarks exist only in memory. Long-lived bookmarks are persisted to storage
				and restored on subsequent application launches.
 */
@property (nonatomic, readonly) BESecurityScopedURLBookmarkLifetime lifetime;

/*!
 @property      isDirectory
 @abstract      Whether the resource is a directory.
 @discussion    This is determined when the bookmark is created and is used to properly handle contained file resolution
				and path normalization (directories have paths ending with "/").
 */
@property (nonatomic, readonly) BOOL isDirectory;

@end

#pragma mark - Delegate Protocol

/*!
 @protocol      BESecurityScopedURLManagerDelegate
 @abstract      Delegate protocol for handling important manager events.
 @discussion    Implement this protocol to receive notifications about bookmark relocations and
				contained URL resolution. All delegate methods are called on the main thread.
 */
@protocol BESecurityScopedURLManagerDelegate <NSObject>
@optional

/*!
 @method        securityScopedURLManager:didRelocateURL:toURL:
 @abstract      Called when a bookmark is resolved and found to be stale, pointing to a new location.
 @discussion    The manager updates its internal catalog automatically. This delegate method allows the client
				to react to the relocation (e.g., updating UI display paths or persistence caches).
				This method is invoked on the main thread.
 @param         manager The manager instance that detected the relocation.
 @param         oldURL The original, stale URL (used as the catalog key).
 @param         newURL The newly resolved URL location after relocation.
 */
- (void)securityScopedURLManager:(BESecurityScopedURLManager *)manager
				   didRelocateURL:(NSURL *)oldURL
							toURL:(NSURL *)newURL;

/*!
 @method        securityScopedURLManager:willResolveContainedURL:withinDirectoryURL:
 @abstract      Called when a URL is resolved because it is contained within a bookmarked directory.
 @discussion    This notification allows clients to track when file URLs are being resolved through directory
				containment matching rather than direct bookmark lookup. This method is delivered asynchronously
				on the main queue, so it arrives after the resolving call has returned.
 @param         manager The manager instance performing the resolution.
 @param         containedURL The file URL being resolved (e.g., a file inside a bookmarked folder).
 @param         directoryURL The resolved URL of the bookmarked directory that contains the file.
 */
- (void)securityScopedURLManager:(BESecurityScopedURLManager *)manager
		 willResolveContainedURL:(NSURL *)containedURL
			  withinDirectoryURL:(NSURL *)directoryURL;

/*!
 @method        securityScopedURLManager:accessFailedForURL:entry:completionHandler:
 @abstract      Called when security-scoped access cannot be started for a URL.
 @discussion    This is the framework's request for help when a bookmark cannot be accessed. The URL could not be
				resolved, or resolution succeeded but security-scoped access failed (e.g., stale bookmark, moved file).
				
				The delegate is responsible for deciding how to handle this:
				- Show a file picker to let the user locate the file
				- Try an alternative location
				- Ignore the failure
				- Log and report to the user
				
				If the delegate locates an alternative URL, it MUST call the completionHandler with the new URL.
				If the delegate cannot resolve the issue, call the completionHandler with nil.
				
				This method is invoked on the main thread. The completionHandler must be called exactly once.
				When the originating call is already running on the main thread the manager cannot wait, so
				the handler must be called before this method returns; a handler called later arrives after
				the access attempt has finished and its relocation is discarded (an error is logged).
				Callers that need to run a sheet or panel before answering should start the access from a
				background thread, where the manager waits for the handler. Failing to call the handler at
				all will prevent proper cleanup, and blocks a background caller indefinitely.
 @param         manager The manager instance that encountered the access failure.
 @param         url The original URL that could not be accessed.
 @param         entry The BESecurityScopedURLBookmarkEntry for the resource (may be nil if not in catalog).
 @param         completionHandler Called with a new URL to try (if delegate located the file), or nil (if giving up).
				The handler may be called on any thread and must be safe for concurrent access.
 */
- (void)securityScopedURLManager:(BESecurityScopedURLManager *)manager
			  accessFailedForURL:(NSURL *)url
						   entry:(nullable BESecurityScopedURLBookmarkEntry *)entry
				 completionHandler:(void (^)(NSURL * _Nullable relocatedURL))completionHandler;

@end

#pragma mark - Main Manager Class

/*!
 @class         BESecurityScopedURLManager
 @abstract      A thread-safe manager for persistently storing and accessing security-scoped bookmarks.
 @discussion    This class manages the complete lifecycle of security-scoped bookmarks, including creation,
				resolution, persistence, and reference-counted access. All operations are thread-safe through
				internal serialization on a dedicated dispatch queue. The manager automatically handles bookmark
				staleness and relocation, notifying delegates of changes. A singleton instance is available via
				+sharedManager, though private instances can be created for isolated bookmark management.

				@code
				BESecurityScopedURLManager *manager = [BESecurityScopedURLManager sharedManager];

				// Persist a user-granted folder so it survives relaunches.
				NSURL *folder = openPanel.URL;
				[manager addURLToCatalog:folder lifetime:BESecurityScopedURLBookmarkLifetimeLongLived];

				// Later — resolve and access a file inside that folder. Access is
				// reference-counted; balance every start with an end.
				NSURL *file = [manager startAccessingURL:fileInFolder];
				if (file) {
					NSData *data = [NSData dataWithContentsOfURL:file];
					[manager endAccessingURL:file];
				}
				@endcode
 @since         1.1
 */
@interface BESecurityScopedURLManager : NSObject <NSFastEnumeration>

#pragma mark - Singleton

/*!
 @method        sharedManager
 @abstract      Returns the shared, singleton instance of the manager.
 @discussion    The shared manager is created on first access and persists for the application lifetime.
				Initialization with -init can be used for private instances if needed, though the shared
				manager is recommended for most use cases.
 @return        The shared BESecurityScopedURLManager instance.
 @since         1.1
 */
+ (instancetype)sharedManager;

#pragma mark - Properties

/*!
 @property      delegate
 @abstract      The manager's delegate for receiving important event notifications.
 @discussion    The delegate is held with a weak reference to prevent retain cycles. Delegate methods
				are called on the main thread. Set to nil to disable delegate notifications.
 */
@property (nonatomic, weak, nullable) id<BESecurityScopedURLManagerDelegate> delegate;

/*!
 @property      storageOptions
 @abstract      Configures where long-lived bookmarks are persisted.
 @discussion    Defaults to BESecurityScopedURLStorageAll. Changes to this property only affect subsequent
				save operations. Must be set before calling any persistence methods to take effect.
				Changing this after bookmarks are loaded may result in bookmarks existing in only one storage
				location. Set to BESecurityScopedURLStorageNone to disable persistence entirely.
 */
@property (nonatomic) BESecurityScopedURLStorageOption storageOptions;

/*!
 @property      catalog
 @abstract      A snapshot of the currently managed bookmarks.
 @discussion    Keys are the canonical absolute string paths of the bookmarked URLs. Values are
				BESecurityScopedURLBookmarkEntry objects. This property returns a copy of the internal
				catalog for thread-safety; modifications to the returned dictionary have no effect on the
				manager's state. For modifications, use the add/remove methods.
 @return        A dictionary mapping URL strings to BESecurityScopedURLBookmarkEntry objects.
 */
@property (nonatomic, readonly) NSDictionary<NSString *, BESecurityScopedURLBookmarkEntry *> *catalog;

#pragma mark - Bookmark Management

/*!
 @method        addURLToCatalog:lifetime:
 @abstract      Creates a security-scoped bookmark for the given URL and adds it to the catalog.
 @discussion    If the URL is already in the catalog, its bookmark data and metadata are updated. This method
				verifies that the resource can be bookmarked before adding it. Long-lived bookmarks are
				automatically persisted to the configured storage locations. This is a thread-safe operation.
 @param         url The file URL to bookmark. Must be a security-scoped resource and a valid file URL.
 @param         lifetime The persistence option for the bookmark (short-lived or long-lived).
 @return        YES if the bookmark was successfully created and added, NO if the URL is invalid or
				bookmark creation failed. Check the entry's bookmarkError property for details.
 */
- (BOOL)addURLToCatalog:(NSURL *)url
			   lifetime:(BESecurityScopedURLBookmarkLifetime)lifetime;

/*!
 @method        removeURLFromCatalog:
 @abstract      Removes the bookmark associated with the given URL from the catalog and persistence.
 @discussion    This is the canonical removal method. The entry is matched by the exact stored
				catalog key, including the trailing-slash form used for directory entries.
				Also ends any active reference-counted access sessions associated with this URL.
				Changes are persisted to configured storage locations. This is a thread-safe operation.
 @param         url The file URL associated with the bookmark to remove.
 */
- (void)removeURLFromCatalog:(NSURL *)url;

/*!
 @method        removeAbsolutePathFromCatalog:
 @abstract      Removes the bookmark entry associated with the given absolute path string.
 @discussion    This is a convenience method that converts the string to an NSURL and calls
				removeURLFromCatalog:. Ends any active reference-counted access sessions and
				persists the change. This is a thread-safe operation.
 @param         absolutePathString The canonical absolute string path of the bookmark key.
 */
- (void)removeAbsolutePathFromCatalog:(NSString *)absolutePathString;

/*!
 @method        clearCatalog
 @abstract      Removes all bookmarks from the catalog, ends all access sessions, and clears persistence.
 @discussion    This operation is useful for cleanup or reset scenarios. All reference counts are
				released and underlying resource access is terminated. Persisted bookmarks are also cleared.
				This is a thread-safe operation that executes atomically.
 */
- (void)clearCatalog;

#pragma mark - URL Resolution

/*!
 @method        urlFromCatalog:
 @abstract      Resolves a URL from the catalog, handling staleness and directory containment.
 @discussion    If the provided URL matches a direct bookmark or is contained within a bookmarked directory,
				the resolved URL is returned. Stale bookmarks are automatically updated. This method does NOT
				start access; use startAccessingURLWithAbsolutePath: or related methods for that.
				This is a thread-safe operation.
 @param         url The URL to resolve (which may be stale or contained within a bookmarked directory).
 @return        The current, resolved URL from the catalog, or nil if not found or if the URL is invalid.
 */
- (nullable NSURL *)urlFromCatalog:(NSURL *)url;

/*!
 @method        urlFromCatalogWithAbsolutePath:
 @abstract      Resolves a bookmarked URL entry using its canonical absolute path string key.
 @discussion    This is the core resolution implementation used by other resolution methods. Handles bookmark
				staleness, relocation, and directory containment internally. Returns the current resolved location
				of the resource. This is a thread-safe operation.

				Resolution proceeds through four tiers, in order:
				1. Direct catalog match on the exact key.
				2. A URL already present in the active reference-count set.
				3. Directory containment — the path lies inside a bookmarked directory.
				4. Filename fallback — a file with the same last path component exists inside ANY
				   bookmarked directory.

				WARNING: Tier 4 matches on filename alone. If two bookmarked directories each contain
				a file with the requested name, the first directory enumerated wins and the other is
				ignored silently. Callers that require an exact path must verify the returned URL's full
				path rather than relying on this method's fallback. Tiers 1–3 are path-exact and unaffected.
 @param         absolutePathString The canonical absolute string of the URL in the catalog.
 @return        The current, resolved URL from the catalog, or nil if not found.
 */
- (nullable NSURL *)urlFromCatalogWithAbsolutePath:(NSString *)absolutePathString;

/*!
 @method        objectForKeyedSubscript:
 @abstract      Allows subscript access to resolve URLs, e.g., manager[staleURL] or manager[@"file:///path"].
 @discussion    This method provides convenient syntax sugar for URL resolution. The key must be an NSURL or
				NSString representing a file URL or absolute path string. This is equivalent to calling
				urlFromCatalog: or urlFromCatalogWithAbsolutePath: depending on key type.
 @param         key An NSURL or NSString key for resolution.
 @return        The resolved URL, or nil if not found or key type is unsupported.
 */
- (nullable NSURL *)objectForKeyedSubscript:(id)key;

#pragma mark - Access Control (URL-based)

/*!
 @method        startAccessingURL:
 @abstract      Starts reference-counted security-scoped access for a given URL.
 @discussion    Resolves the URL through the catalog and starts security-scoped access. Access is
				reference-counted: the underlying startAccessingSecurityScopedResource call is made only
				on the 0→1 transition; subsequent calls increment the count. Each call must be balanced
				with a corresponding endAccessingURL:. If resolution or access fails, the delegate's
				accessFailedForURL:entry:completionHandler: is invoked (on the main thread) so it can
				locate the resource or give up. This is a thread-safe operation.
 @param         url The URL for which to start access. If nil, returns nil.
 @return        The resolved URL if access was successfully started, nil otherwise.
 */
- (nullable NSURL *)startAccessingURL:(NSURL *)url;

/*!
 @method        endAccessingURL:
 @abstract      Ends reference-counted security-scoped access for a given URL.
 @discussion    Decrements the reference count for the URL and calls stopAccessingSecurityScopedResource
				only when the count reaches zero. This allows multiple callers to share access to the same
				resource safely. Each call balances one prior startAccessingURL:. This is a thread-safe operation.
 @param         url The URL for which to end access. If nil, returns NO.
 @return        YES if access was successfully ended, NO if the URL was not active or an error occurred.
 */
- (BOOL)endAccessingURL:(NSURL *)url;

#pragma mark - Access Control (Reference-Counted)

/*!
 @method        startAccessingURLWithAbsolutePath:
 @abstract      Resolves a bookmarked URL path and starts reference-counted access to it.
 @discussion    If the URL is found and access starts successfully, the resolved URL is returned. Reference
				counting ensures that the underlying resource access is maintained until all callers have called
				the corresponding end method. This is the recommended method for managed access. This is a
				thread-safe operation.
 @param         absolutePathString The canonical absolute string of the URL in the catalog.
 @return        The resolved URL if access successfully started, otherwise nil.
 */
- (nullable NSURL *)startAccessingURLWithAbsolutePath:(NSString *)absolutePathString;

/*!
 @method        endAccessingURLWithAbsolutePath:
 @abstract      Ends reference-counted access for a bookmarked URL path.
 @discussion    Decrements the reference count for the path and stops the underlying resource access only if
				the count reaches zero. This allows multiple parts of the application to safely share access
				to the same resource. This is a thread-safe operation.
 @param         absolutePathString The canonical absolute string of the URL in the catalog.
 @return        YES if a tracked reference count was ended, NO if the path had no active access or could not be resolved.
 */
- (BOOL)endAccessingURLWithAbsolutePath:(NSString *)absolutePathString;

#pragma mark - Bulk Access Control

/*!
 @method        startAccessingAllURLs
 @abstract      Starts reference-counted access for every URL in the catalog.
 @discussion    This is useful on application launch or after loading the catalog to ensure all bookmarked
				resources are immediately accessible. Returns the array of successfully accessed URLs. The
				returned URLs are guaranteed to have active security-scoped access until endAccessingAllURLs
				is called. This is a thread-safe operation.

				NOTE: Unlike startAccessingURL:, this bulk method does NOT invoke the delegate's
				accessFailedForURL:entry:completionHandler: for entries that fail to resolve or whose
				security-scoped access cannot be started. Such entries are simply omitted from the
				returned array. Compare the returned count (or contents) against `catalog` to detect
				which bookmarks failed, and re-acquire them individually via startAccessingURL: if you
				need the delegate's relocation flow.
 @return        An array of all resolved URLs for which access was successfully started. May be empty if no
				bookmarks exist or none could be accessed.
 */
- (NSArray<NSURL *> *)startAccessingAllURLs;

/*!
 @method        endAccessingAllURLs
 @abstract      Ends all reference-counted access sessions tracked by the manager.
 @discussion    This method releases access for all bookmarked resources managed by the manager, regardless of
				how many times startAccessingAllURLs or individual start methods were called. This is typically
				called during application shutdown or when access to all bookmarked resources should be released.
				This is a thread-safe operation.
 */
- (void)endAccessingAllURLs;

@end

#pragma mark - NSURL Convenience Category

/*!
 @category      NSURL (BESecurityScopedURLManagerHelpers)
 @abstract      Convenience methods to quickly start/end security-scoped access using reference counting.
 @discussion    These methods use the reference-counted access logic of the shared manager. They ensure that
				a single URL's access is properly managed, even if multiple parts of the app access it. These
				methods provide the simplest API for most use cases.

				@code
				if ([fileURL ss_startAccessingSecurityScopedResource]) {
					NSData *data = [NSData dataWithContentsOfURL:fileURL];
					[fileURL ss_endAccessingSecurityScopedResource];
				}
				@endcode
 */
@interface NSURL (BESecurityScopedURLManagerHelpers)

/*!
 @method        ss_startAccessingSecurityScopedResource
 @abstract      Starts reference-counted security-scoped access for this URL via the shared manager.
 @discussion    The underlying resource access is only started if the reference count transitions from 0 to 1.
				Subsequent calls increment the count without starting access again. Use ss_endAccessingSecurityScopedResource
				to balance each call and properly release access.
 @return        YES if access was successfully started or the reference count was incremented, NO otherwise.
 */
- (BOOL)ss_startAccessingSecurityScopedResource;

/*!
 @method        ss_endAccessingSecurityScopedResource
 @abstract      Ends reference-counted security-scoped access for this URL via the shared manager.
 @discussion    The underlying resource access is only stopped if the reference count drops to 0. Calls to this
				method must be balanced with calls to ss_startAccessingSecurityScopedResource to avoid premature
				resource release.
 */
- (void)ss_endAccessingSecurityScopedResource;

@end

NS_ASSUME_NONNULL_END
