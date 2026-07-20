/*!
 @header     BEPlatformTypes.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @author     belisoful@icloud.com
 @abstract   Cross-platform aliases for the AppKit/UIKit types BEFoundation uses.
 @discussion BEFoundation targets both macOS (AppKit) and iOS (UIKit). A handful of
             APIs traffic in UI types that are spelled differently on each platform —
             @c NSColor vs @c UIColor, @c NSImage vs @c UIImage, and so on. These
             @c \@compatibility_alias declarations give each a single BEFoundation
             spelling that resolves to the right platform class at compile time, so the
             same source (and the same call sites, e.g. @c [BEColor whiteColor] or
             @c @interface MyView : BEView) compiles on both platforms.
 */

#ifndef BEPlatformTypes_h
#define BEPlatformTypes_h

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

/*! @typedef BEColor A platform color: @c NSColor on macOS, @c UIColor on iOS. */
@compatibility_alias BEColor NSColor;
/*! @typedef BEImage A platform image: @c NSImage on macOS, @c UIImage on iOS. */
@compatibility_alias BEImage NSImage;
/*! @typedef BEFont  A platform font:  @c NSFont on macOS,  @c UIFont on iOS. */
@compatibility_alias BEFont  NSFont;
/*! @typedef BEView  A platform view:  @c NSView on macOS,  @c UIView on iOS. */
@compatibility_alias BEView  NSView;

/*! @typedef BEEdgeInsets Platform edge insets: @c NSEdgeInsets on macOS, @c UIEdgeInsets on iOS.
    Use @c BEEdgeInsetsMake(top,left,bottom,right) to construct one cross-platform. */
typedef NSEdgeInsets BEEdgeInsets;
#define BEEdgeInsetsMake(top, left, bottom, right) NSEdgeInsetsMake((top), (left), (bottom), (right))

#else
#import <UIKit/UIKit.h>

@compatibility_alias BEColor UIColor;
@compatibility_alias BEImage UIImage;
@compatibility_alias BEFont  UIFont;
@compatibility_alias BEView  UIView;

typedef UIEdgeInsets BEEdgeInsets;
#define BEEdgeInsetsMake(top, left, bottom, right) UIEdgeInsetsMake((top), (left), (bottom), (right))

#endif

#endif // !BEPlatformTypes_h
