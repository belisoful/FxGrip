#import <TargetConditionals.h>
#if TARGET_OS_OSX
/*!
 @header     BEPathControl.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-11-03
 @author     belisoful@icloud.com
 @abstract   Provides an NSPathControl subclass that limits displayed path items based on a relative URL.
 @discussion BEPathControl extends NSPathControl to introduce a concept of a "relative"
			 root for the displayed file path. When a @c relativeURL is set, the
			 path control will automatically filter its path items (@c pathItems)
			 to only show the components of the full URL that are descendants of
			 the @c relativeURL, including the relative URL itself.
			 
			 This is useful for displaying file paths within a project or document
			 structure, where the full path is known, but only the parts relative
			 to the project's root should be visible to the user.
			 
			 The control behaves as follows:
			 - Path items are trimmed to only show paths within the @c relativeURL.
			 - The @c relativeURL is always considered the root of the path control.
			 - Containment is compared on standardized path components, so directory
			   boundaries are exact (e.g. @c /a/Projects never matches @c /a/ProjectsX).

			 Note: @c relativeURL is an absolute "root" URL despite its name; it is not a
			 relative path. Standardization resolves @c . / @c .. but does not resolve
			 symlinks. All access (this is an AppKit view) must occur on the main thread.

			 Caveat: the inherited @c URL property continues to report the full absolute URL
			 even while only the trimmed @c pathItems are displayed; the two intentionally
			 disagree. A @c URL set entirely outside @c relativeURL displays zero items.
			 
			 Example usage:
			 @code
			 BEPathControl *pathControl = [[BEPathControl alloc] initWithFrame:frame];
			 
			 // Full path to a file inside a project
			 NSURL *fullURL = [NSURL fileURLWithPath:@"/Users/user/Projects/MyProject/Sources/File.m"];
			 
			 // The project's root path
			 NSURL *relativeURL = [NSURL fileURLWithPath:@"/Users/user/Projects/MyProject/"];
			 
			 pathControl.relativeURL = relativeURL;
			 pathControl.URL = fullURL;
			 
			 // The path control will display: MyProject / Sources / File.m
			 // It hides: / / Users / user / Projects
			 @endcode
 */

#ifndef BEPathControl_h
#define BEPathControl_h

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @class      BEPathControl
 @abstract   An NSPathControl subclass that supports limiting the displayed path to a relative URL.
 @discussion Subclass of NSPathControl that automatically filters the displayed path
			 components based on the value of the @c relativeURL property. It ensures
			 that only path items that are descendants (or the same as) the
			 @c relativeURL are visible.
			 
			 Overrides the standard @c setURL: method to trigger the path trimming logic.

			 @code
			 BEPathControl *pathControl = [[BEPathControl alloc] initWithFrame:frame];
			 pathControl.relativeURL = [NSURL fileURLWithPath:@"/Users/me/Projects/App/"];

			 // Containment is exact on standardized path components.
			 NSURL *inside  = [NSURL fileURLWithPath:@"/Users/me/Projects/App/Sources/Main.m"];
			 NSURL *sibling = [NSURL fileURLWithPath:@"/Users/me/Projects/AppX/Main.m"];
			 [pathControl containsURL:inside];   // YES: descendant of relativeURL
			 [pathControl containsURL:sibling];  // NO: /App never matches /AppX
			 @endcode
 */
@interface BEPathControl : NSPathControl

#pragma mark - Properties

/*!
 @property   relativeURL
 @abstract   The URL defining the root of the displayed path items.
 @discussion When set, the path control will only display path items (@c NSPathControlItem)
			 whose URL is a descendant of, or equal to, this URL. Any leading path
			 components up to and including the system root will be hidden.
			 
			 Setting this property triggers a rebuild of the path items based on the
			 currently set @c URL property. The URL is automatically standardized for
			 reliable path comparison.
			 
			 If set to @c nil, the path control behaves like a standard @c NSPathControl
			 and displays the full absolute path from the root.
			 
			 Example:
			 @code
			 // Set the project root
			 pathControl.relativeURL = [NSURL fileURLWithPath:@"/path/to/project/"];
			 @endcode
 */
@property (nullable, nonatomic)	NSURL			*relativeURL;

#pragma mark - Path Comparison

/*!
 @method     containsURL:
 @abstract   Determines if a given URL is a descendant of the relative URL.
 @param      checkUrl The URL to check for containment.
 @discussion This method compares the provided @c checkUrl against the current
			 @c relativeURL property. It returns @c YES if:

			 1. The @c relativeURL is @c nil (no restriction).
			 2. @c checkUrl is exactly equal to @c relativeURL.
			 3. @c checkUrl is a descendant of @c relativeURL.

			 Comparison is performed on standardized path components (not raw strings), so
			 the match is exact at directory boundaries: @c /a/Projects does not match
			 @c /a/ProjectsX, files are not treated as directories, and percent-encoding
			 differences are normalized. Schemes must match. Symlinks are NOT resolved.
			 Comparison is case-SENSITIVE regardless of the underlying file system, so on a
			 case-insensitive volume @c /a/Docs and @c /a/docs are treated as different.
 @return     @c YES if the @c checkUrl is contained within the @c relativeURL's
			 path hierarchy, @c NO otherwise.
 */
- (BOOL)containsURL:(nullable NSURL*)checkUrl;

@end

NS_ASSUME_NONNULL_END

#endif // !BEPathControl_h
#endif // TARGET_OS_OSX
