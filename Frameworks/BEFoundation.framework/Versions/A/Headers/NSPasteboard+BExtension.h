/*!
 @header     NSPasteboard+BExtension.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @author     belisoful@icloud.com
 @abstract   Typed read/write convenience for @c NSPasteboard (macOS only).
 @discussion NSPasteboard's API is low-level and stringly-typed (UTIs, @c declareTypes:,
             @c readObjectsForClasses:options:). The common cases — put a string, URL, or
             image on the pasteboard and read it back, checking availability — are the same
             boilerplate everywhere. These helpers cover them: each writer clears the pasteboard
             and writes the value; each reader returns the first value of that type, or @c nil.
             This is macOS only — @c UIPasteboard is a separate, simpler API and isn't bridged here.

             @code
             // Write a string, then read it back.
             NSPasteboard *pb = NSPasteboard.generalPasteboard;
             [pb writeString:@"Frame 01"];
             NSString *value = [pb readString];
             @endcode
 */

#ifndef NSPasteboard_BExtension_h
#define NSPasteboard_BExtension_h

#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSPasteboard (BExtension)

#pragma mark - Write (clears existing contents, then writes)

/*! @method writeString:  Clears the pasteboard and writes @c string. Returns @c NO if @c string is nil. */
- (BOOL)writeString:(NSString *)string;

/*! @method writeURL:  Clears the pasteboard and writes @c url. Returns @c NO if @c url is nil. */
- (BOOL)writeURL:(NSURL *)url;

/*! @method writeURLs:  Clears the pasteboard and writes @c urls. Returns @c NO if @c urls is empty. */
- (BOOL)writeURLs:(NSArray<NSURL *> *)urls;

/*! @method writeImage:  Clears the pasteboard and writes @c image. Returns @c NO if @c image is nil. */
- (BOOL)writeImage:(NSImage *)image;

#pragma mark - Typed reads

/*! @method readString  The first string on the pasteboard, or @c nil. */
- (nullable NSString *)readString;

/*! @method readURL  The first URL on the pasteboard, or @c nil. */
- (nullable NSURL *)readURL;

/*! @method readURLs  All URLs on the pasteboard, or @c nil if there are none. */
- (nullable NSArray<NSURL *> *)readURLs;

/*! @method readImage  The first image on the pasteboard, or @c nil. */
- (nullable NSImage *)readImage;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX

#endif // !NSPasteboard_BExtension_h
