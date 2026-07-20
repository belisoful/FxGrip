/*!
 @header     BEColor+BExtension.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @author     belisoful@icloud.com
 @abstract   Hex parsing/formatting and appearance-aware convenience for @c BEColor
             (@c NSColor on macOS, @c UIColor on iOS).
 @discussion AppKit/UIKit ship no hex support and make component access error-prone
             (NSColor's component accessors raise on non-RGB colors). This category adds
             robust @c #RGB / @c #RRGGBBAA parsing and formatting that always round-trips
             through sRGB, plus a one-call light/dark dynamic color.
 */

#ifndef BEColor_BExtension_h
#define BEColor_BExtension_h

#import <Foundation/Foundation.h>
#import <BEFoundation/BEPlatformTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface BEColor (BExtension)

/*!
 @method     colorWithHexString:
 @abstract   Creates a color from a hex string.
 @param      hexString A hex color. Accepts an optional @c # or @c 0x prefix and 3, 4, 6, or 8
                       hex digits: @c RGB, @c RGBA, @c RRGGBB, or @c RRGGBBAA (alpha last,
                       CSS-style). 3/4-digit shorthand is expanded (@c "#1a2" → @c "#11aa22").
                       Surrounding whitespace is ignored; case is insensitive.
 @return     An sRGB color, or @c nil if the string is empty, malformed, or has an unsupported
             digit count.
 */
+ (nullable BEColor *)colorWithHexString:(NSString *)hexString;

/*!
 @property   hexString
 @abstract   The color as an opaque @c "#RRGGBB" string, computed in sRGB.
 @discussion The receiver is converted to sRGB first, so this never raises and is stable across
             color spaces. Components are clamped to the 0–255 range. Alpha is not included; use
             @c hexStringWithAlpha for that.
 */
@property (nonatomic, readonly, copy) NSString *hexString;

/*!
 @property   hexStringWithAlpha
 @abstract   The color as a @c "#RRGGBBAA" string (alpha last), computed in sRGB.
 */
@property (nonatomic, readonly, copy) NSString *hexStringWithAlpha;

/*!
 @method     dynamicColorWithLight:dark:
 @abstract   A color that resolves to @c lightColor or @c darkColor based on the current appearance.
 @param      lightColor The color used in a light appearance.
 @param      darkColor  The color used in a dark appearance.
 @discussion Wraps @c +[NSColor colorWithName:dynamicProvider:] on macOS and
             @c +[UIColor colorWithDynamicProvider:] on iOS, so the result tracks
             light/dark mode automatically when drawn.
 @return     A dynamic color.
 */
+ (BEColor *)dynamicColorWithLight:(BEColor *)lightColor dark:(BEColor *)darkColor;

@end

NS_ASSUME_NONNULL_END

#endif // !BEColor_BExtension_h
