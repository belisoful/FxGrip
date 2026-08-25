/*!
 @header     BEColor+BEWebColor.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @author     belisoful@icloud.com
 @abstract   The 141 CSS/SVG color keywords as constants, colors, and name lookups on
             @c BEColor (@c NSColor on macOS, @c UIColor on iOS).
 @discussion Each keyword is available three ways: a @c BEWebColorName... string constant, a
             @c web-prefixed class property, and a case-insensitive lookup by name. The
             @c web prefix keeps every one of them clear of AppKit's and UIKit's own color
             names, and of Swift's @c NSColor.red and friends.

             Colors are built through @c colorWithHexString: in @c BEColor(BExtension), so
             they are opaque sRGB and round-trip through @c hexString exactly.
 @since      1.1
 */

#ifndef BEColor_BEWebColor_h
#define BEColor_BEWebColor_h

#import <Foundation/Foundation.h>
#import <BEFoundation/BEPlatformTypes.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Web color name constants

/*!
 @group      Web color names
 @abstract   The 141 CSS/SVG extended color keywords as string constants.
 @discussion Each constant is the canonical spelling of the keyword (@c BEWebColorNameAliceBlue
             is @c @"AliceBlue"). Pass one to @c webColorNamed: , or read the matching
             @c web-prefixed class property. Lookups are case-insensitive, so a name read from
             a file or a user setting resolves without normalizing it first.
*/
FOUNDATION_EXPORT NSString * const BEWebColorNameWhite;   /*!< @c #FFFFFF */
FOUNDATION_EXPORT NSString * const BEWebColorNameSilver;   /*!< @c #C0C0C0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameGray;   /*!< @c #808080 */
FOUNDATION_EXPORT NSString * const BEWebColorNameBlack;   /*!< @c #000000 */
FOUNDATION_EXPORT NSString * const BEWebColorNameRed;   /*!< @c #FF0000 */
FOUNDATION_EXPORT NSString * const BEWebColorNameMaroon;   /*!< @c #800000 */
FOUNDATION_EXPORT NSString * const BEWebColorNameOrange;   /*!< @c #FFA500 */
FOUNDATION_EXPORT NSString * const BEWebColorNameYellow;   /*!< @c #FFFF00 */
FOUNDATION_EXPORT NSString * const BEWebColorNameOlive;   /*!< @c #808000 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLime;   /*!< @c #00FF00 */
FOUNDATION_EXPORT NSString * const BEWebColorNameGreen;   /*!< @c #008000 */
FOUNDATION_EXPORT NSString * const BEWebColorNameAqua;   /*!< @c #00FFFF */
FOUNDATION_EXPORT NSString * const BEWebColorNameCyan;   /*!< @c #00FFFF */
FOUNDATION_EXPORT NSString * const BEWebColorNameTeal;   /*!< @c #008080 */
FOUNDATION_EXPORT NSString * const BEWebColorNameBlue;   /*!< @c #0000FF */
FOUNDATION_EXPORT NSString * const BEWebColorNameNavy;   /*!< @c #000080 */
FOUNDATION_EXPORT NSString * const BEWebColorNameFuchsia;   /*!< @c #FF00FF */
FOUNDATION_EXPORT NSString * const BEWebColorNameMagenta;   /*!< @c #FF00FF */
FOUNDATION_EXPORT NSString * const BEWebColorNamePurple;   /*!< @c #800080 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkSlateGray;   /*!< @c #2F4F4F */
FOUNDATION_EXPORT NSString * const BEWebColorNameDimGray;   /*!< @c #696969 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSlateGray;   /*!< @c #708090 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightSlateGray;   /*!< @c #778899 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkGray;   /*!< @c #A9A9A9 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightGray;   /*!< @c #D3D3D3 */
FOUNDATION_EXPORT NSString * const BEWebColorNameGainsboro;   /*!< @c #DCDCDC */
FOUNDATION_EXPORT NSString * const BEWebColorNameMistyRose;   /*!< @c #FFE4E1 */
FOUNDATION_EXPORT NSString * const BEWebColorNameAntiqueWhite;   /*!< @c #FAEBD7 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLinen;   /*!< @c #FAF0E6 */
FOUNDATION_EXPORT NSString * const BEWebColorNameBeige;   /*!< @c #F5F5DC */
FOUNDATION_EXPORT NSString * const BEWebColorNameWhiteSmoke;   /*!< @c #F5F5F5 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLavenderBlush;   /*!< @c #FFF0F5 */
FOUNDATION_EXPORT NSString * const BEWebColorNameOldLace;   /*!< @c #FDF5E6 */
FOUNDATION_EXPORT NSString * const BEWebColorNameAliceBlue;   /*!< @c #F0F8FF */
FOUNDATION_EXPORT NSString * const BEWebColorNameSeashell;   /*!< @c #FFF5EE */
FOUNDATION_EXPORT NSString * const BEWebColorNameGhostWhite;   /*!< @c #F8F8FF */
FOUNDATION_EXPORT NSString * const BEWebColorNameHoneydew;   /*!< @c #F0FFF0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameFloralWhite;   /*!< @c #FFFAF0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameAzure;   /*!< @c #F0FFFF */
FOUNDATION_EXPORT NSString * const BEWebColorNameMintCream;   /*!< @c #F5FFFA */
FOUNDATION_EXPORT NSString * const BEWebColorNameSnow;   /*!< @c #FFFAFA */
FOUNDATION_EXPORT NSString * const BEWebColorNameIvory;   /*!< @c #FFFFF0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumVioletRed;   /*!< @c #C71585 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDeepPink;   /*!< @c #FF1493 */
FOUNDATION_EXPORT NSString * const BEWebColorNamePaleVioletRed;   /*!< @c #DB7093 */
FOUNDATION_EXPORT NSString * const BEWebColorNameHotPink;   /*!< @c #FF69B4 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightPink;   /*!< @c #FFB6C1 */
FOUNDATION_EXPORT NSString * const BEWebColorNamePink;   /*!< @c #FFC0CB */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkRed;   /*!< @c #8B0000 */
FOUNDATION_EXPORT NSString * const BEWebColorNameFirebrick;   /*!< @c #B22222 */
FOUNDATION_EXPORT NSString * const BEWebColorNameCrimson;   /*!< @c #DC143C */
FOUNDATION_EXPORT NSString * const BEWebColorNameIndianRed;   /*!< @c #CD5C5C */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightCoral;   /*!< @c #F08080 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSalmon;   /*!< @c #FA8072 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkSalmon;   /*!< @c #E9967A */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightSalmon;   /*!< @c #FFA07A */
FOUNDATION_EXPORT NSString * const BEWebColorNameOrangeRed;   /*!< @c #FF4500 */
FOUNDATION_EXPORT NSString * const BEWebColorNameTomato;   /*!< @c #FF6347 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkOrange;   /*!< @c #FF8C00 */
FOUNDATION_EXPORT NSString * const BEWebColorNameCoral;   /*!< @c #FF7F50 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkKhaki;   /*!< @c #BDB76B */
FOUNDATION_EXPORT NSString * const BEWebColorNameGold;   /*!< @c #FFD700 */
FOUNDATION_EXPORT NSString * const BEWebColorNameKhaki;   /*!< @c #F0E68C */
FOUNDATION_EXPORT NSString * const BEWebColorNamePeachPuff;   /*!< @c #FFDAB9 */
FOUNDATION_EXPORT NSString * const BEWebColorNamePaleGoldenrod;   /*!< @c #EEE8AA */
FOUNDATION_EXPORT NSString * const BEWebColorNameMoccasin;   /*!< @c #FFE4B5 */
FOUNDATION_EXPORT NSString * const BEWebColorNamePapayaWhip;   /*!< @c #FFEFD5 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightGoldenrodYellow;   /*!< @c #FAFAD2 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLemonChiffon;   /*!< @c #FFFACD */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightYellow;   /*!< @c #FFFFE0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameBrown;   /*!< @c #A52A2A */
FOUNDATION_EXPORT NSString * const BEWebColorNameSaddleBrown;   /*!< @c #8B4513 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSienna;   /*!< @c #A0522D */
FOUNDATION_EXPORT NSString * const BEWebColorNameChocolate;   /*!< @c #D2691E */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkGoldenrod;   /*!< @c #B8860B */
FOUNDATION_EXPORT NSString * const BEWebColorNamePeru;   /*!< @c #CD853F */
FOUNDATION_EXPORT NSString * const BEWebColorNameRosyBrown;   /*!< @c #BC8F8F */
FOUNDATION_EXPORT NSString * const BEWebColorNameGoldenrod;   /*!< @c #DAA520 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSandyBrown;   /*!< @c #F4A460 */
FOUNDATION_EXPORT NSString * const BEWebColorNameTan;   /*!< @c #D2B48C */
FOUNDATION_EXPORT NSString * const BEWebColorNameBurlyWood;   /*!< @c #DEB887 */
FOUNDATION_EXPORT NSString * const BEWebColorNameWheat;   /*!< @c #F5DEB3 */
FOUNDATION_EXPORT NSString * const BEWebColorNameNavajoWhite;   /*!< @c #FFDEAD */
FOUNDATION_EXPORT NSString * const BEWebColorNameBisque;   /*!< @c #FFE4C4 */
FOUNDATION_EXPORT NSString * const BEWebColorNameBlanchedAlmond;   /*!< @c #FFEBCD */
FOUNDATION_EXPORT NSString * const BEWebColorNameCornsilk;   /*!< @c #FFF8DC */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkGreen;   /*!< @c #006400 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkOliveGreen;   /*!< @c #556B2F */
FOUNDATION_EXPORT NSString * const BEWebColorNameForestGreen;   /*!< @c #228B22 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSeaGreen;   /*!< @c #2E8B57 */
FOUNDATION_EXPORT NSString * const BEWebColorNameOliveDrab;   /*!< @c #6B8E23 */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumSeaGreen;   /*!< @c #3CB371 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLimeGreen;   /*!< @c #32CD32 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSpringGreen;   /*!< @c #00FF7F */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumSpringGreen;   /*!< @c #00FA9A */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkSeaGreen;   /*!< @c #8FBC8F */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumAquamarine;   /*!< @c #66CDAA */
FOUNDATION_EXPORT NSString * const BEWebColorNameYellowGreen;   /*!< @c #9ACD32 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLawnGreen;   /*!< @c #7CFC00 */
FOUNDATION_EXPORT NSString * const BEWebColorNameChartreuse;   /*!< @c #7FFF00 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightGreen;   /*!< @c #90EE90 */
FOUNDATION_EXPORT NSString * const BEWebColorNameGreenYellow;   /*!< @c #ADFF2F */
FOUNDATION_EXPORT NSString * const BEWebColorNamePaleGreen;   /*!< @c #98FB98 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkCyan;   /*!< @c #008B8B */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightSeaGreen;   /*!< @c #20B2AA */
FOUNDATION_EXPORT NSString * const BEWebColorNameCadetBlue;   /*!< @c #5F9EA0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkTurquoise;   /*!< @c #00CED1 */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumTurquoise;   /*!< @c #48D1CC */
FOUNDATION_EXPORT NSString * const BEWebColorNameTurquoise;   /*!< @c #40E0D0 */
FOUNDATION_EXPORT NSString * const BEWebColorNameAquamarine;   /*!< @c #7FFFD4 */
FOUNDATION_EXPORT NSString * const BEWebColorNamePaleTurquoise;   /*!< @c #AFEEEE */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightCyan;   /*!< @c #E0FFFF */
FOUNDATION_EXPORT NSString * const BEWebColorNameMidnightBlue;   /*!< @c #191970 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkBlue;   /*!< @c #00008B */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumBlue;   /*!< @c #0000CD */
FOUNDATION_EXPORT NSString * const BEWebColorNameRoyalBlue;   /*!< @c #4169E1 */
FOUNDATION_EXPORT NSString * const BEWebColorNameSteelBlue;   /*!< @c #4682B4 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDodgerBlue;   /*!< @c #1E90FF */
FOUNDATION_EXPORT NSString * const BEWebColorNameDeepSkyBlue;   /*!< @c #00BFFF */
FOUNDATION_EXPORT NSString * const BEWebColorNameCornflowerBlue;   /*!< @c #6495ED */
FOUNDATION_EXPORT NSString * const BEWebColorNameSkyBlue;   /*!< @c #87CEEB */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightSkyBlue;   /*!< @c #87CEFA */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightSteelBlue;   /*!< @c #B0C4DE */
FOUNDATION_EXPORT NSString * const BEWebColorNameLightBlue;   /*!< @c #ADD8E6 */
FOUNDATION_EXPORT NSString * const BEWebColorNamePowderBlue;   /*!< @c #B0E0E6 */
FOUNDATION_EXPORT NSString * const BEWebColorNameIndigo;   /*!< @c #4B0082 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkMagenta;   /*!< @c #8B008B */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkViolet;   /*!< @c #9400D3 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkSlateBlue;   /*!< @c #483D8B */
FOUNDATION_EXPORT NSString * const BEWebColorNameBlueViolet;   /*!< @c #8A2BE2 */
FOUNDATION_EXPORT NSString * const BEWebColorNameDarkOrchid;   /*!< @c #9932CC */
FOUNDATION_EXPORT NSString * const BEWebColorNameSlateBlue;   /*!< @c #6A5ACD */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumSlateBlue;   /*!< @c #7B68EE */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumOrchid;   /*!< @c #BA55D3 */
FOUNDATION_EXPORT NSString * const BEWebColorNameMediumPurple;   /*!< @c #9370DB */
FOUNDATION_EXPORT NSString * const BEWebColorNameOrchid;   /*!< @c #DA70D6 */
FOUNDATION_EXPORT NSString * const BEWebColorNameViolet;   /*!< @c #EE82EE */
FOUNDATION_EXPORT NSString * const BEWebColorNamePlum;   /*!< @c #DDA0DD */
FOUNDATION_EXPORT NSString * const BEWebColorNameThistle;   /*!< @c #D8BFD8 */
FOUNDATION_EXPORT NSString * const BEWebColorNameLavender;   /*!< @c #E6E6FA */
FOUNDATION_EXPORT NSString * const BEWebColorNameRebeccaPurple;   /*!< @c #663399 */

@interface BEColor (BEWebColor)

#pragma mark - Web color lookup


/*!
 @method     webColorNamed:
 @abstract   The color for a CSS/SVG color keyword.
 @param      name A color keyword such as @c @"DeepSkyBlue" . Matching ignores case and
                  surrounding whitespace, so @c @"deep skY blue " does not resolve but
                  @c @" deepskyblue " does — inner spaces are not part of a keyword.
 @return     An opaque sRGB color, or @c nil when the name is not a color keyword.
 @discussion Prefer the @c BEWebColorName... constants over string literals; a typo in a
             literal is a runtime @c nil, a typo in a constant is a compile error.
 @since      1.1
*/
+ (nullable BEColor *)webColorNamed:(NSString *)name;

/*!
 @method     webColorNameForColor:
 @abstract   The CSS/SVG keyword whose value equals a color exactly.
 @param      color The color to identify. It is converted to sRGB before comparison.
 @return     The canonical keyword (as in the @c BEWebColorName... constants), or @c nil when
             no keyword has that exact RGB value. Alpha is ignored.
 @discussion The comparison is exact, not nearest: a color one component away from
             @c DeepSkyBlue returns @c nil rather than @c @"DeepSkyBlue" . Where two keywords
             share a value (@c Aqua and @c Cyan, @c Fuchsia and @c Magenta, @c Gray and
             @c Grey), the first in @c webColorNames wins, so the result is stable.
 @since      1.1
*/
+ (nullable NSString *)webColorNameForColor:(BEColor *)color;

/*!
 @property   webColorNames
 @abstract   Every CSS/SVG color keyword, in the canonical spelling.
 @discussion Ordered as the CSS specification lists them: the 16 original HTML keywords first,
             then the extended set grouped by hue.
 @since      1.1
*/
@property (class, readonly, nonatomic) NSArray<NSString *> *webColorNames;

/*!
 @property   webColors
 @abstract   Every CSS/SVG color keyword mapped to its color.
 @discussion Keys are the canonical spellings. Use @c webColorNamed: for a case-insensitive
             single lookup; this is for enumerating the whole set.
 @since      1.1
*/
@property (class, readonly, nonatomic) NSDictionary<NSString *, BEColor *> *webColors;


/*!
 @group      Web color properties
 @abstract   Each CSS/SVG color keyword as a ready color.
 @discussion The @c web prefix keeps these clear of AppKit and UIKit's own color names
             (and of Swift's @c NSColor.red and friends). Values are opaque sRGB.
*/
@property (class, readonly, nonatomic) BEColor *webWhite;   /*!< @c #FFFFFF */
@property (class, readonly, nonatomic) BEColor *webSilver;   /*!< @c #C0C0C0 */
@property (class, readonly, nonatomic) BEColor *webGray;   /*!< @c #808080 */
@property (class, readonly, nonatomic) BEColor *webBlack;   /*!< @c #000000 */
@property (class, readonly, nonatomic) BEColor *webRed;   /*!< @c #FF0000 */
@property (class, readonly, nonatomic) BEColor *webMaroon;   /*!< @c #800000 */
@property (class, readonly, nonatomic) BEColor *webOrange;   /*!< @c #FFA500 */
@property (class, readonly, nonatomic) BEColor *webYellow;   /*!< @c #FFFF00 */
@property (class, readonly, nonatomic) BEColor *webOlive;   /*!< @c #808000 */
@property (class, readonly, nonatomic) BEColor *webLime;   /*!< @c #00FF00 */
@property (class, readonly, nonatomic) BEColor *webGreen;   /*!< @c #008000 */
@property (class, readonly, nonatomic) BEColor *webAqua;   /*!< @c #00FFFF */
@property (class, readonly, nonatomic) BEColor *webCyan;   /*!< @c #00FFFF */
@property (class, readonly, nonatomic) BEColor *webTeal;   /*!< @c #008080 */
@property (class, readonly, nonatomic) BEColor *webBlue;   /*!< @c #0000FF */
@property (class, readonly, nonatomic) BEColor *webNavy;   /*!< @c #000080 */
@property (class, readonly, nonatomic) BEColor *webFuchsia;   /*!< @c #FF00FF */
@property (class, readonly, nonatomic) BEColor *webMagenta;   /*!< @c #FF00FF */
@property (class, readonly, nonatomic) BEColor *webPurple;   /*!< @c #800080 */
@property (class, readonly, nonatomic) BEColor *webDarkSlateGray;   /*!< @c #2F4F4F */
@property (class, readonly, nonatomic) BEColor *webDimGray;   /*!< @c #696969 */
@property (class, readonly, nonatomic) BEColor *webSlateGray;   /*!< @c #708090 */
@property (class, readonly, nonatomic) BEColor *webLightSlateGray;   /*!< @c #778899 */
@property (class, readonly, nonatomic) BEColor *webDarkGray;   /*!< @c #A9A9A9 */
@property (class, readonly, nonatomic) BEColor *webLightGray;   /*!< @c #D3D3D3 */
@property (class, readonly, nonatomic) BEColor *webGainsboro;   /*!< @c #DCDCDC */
@property (class, readonly, nonatomic) BEColor *webMistyRose;   /*!< @c #FFE4E1 */
@property (class, readonly, nonatomic) BEColor *webAntiqueWhite;   /*!< @c #FAEBD7 */
@property (class, readonly, nonatomic) BEColor *webLinen;   /*!< @c #FAF0E6 */
@property (class, readonly, nonatomic) BEColor *webBeige;   /*!< @c #F5F5DC */
@property (class, readonly, nonatomic) BEColor *webWhiteSmoke;   /*!< @c #F5F5F5 */
@property (class, readonly, nonatomic) BEColor *webLavenderBlush;   /*!< @c #FFF0F5 */
@property (class, readonly, nonatomic) BEColor *webOldLace;   /*!< @c #FDF5E6 */
@property (class, readonly, nonatomic) BEColor *webAliceBlue;   /*!< @c #F0F8FF */
@property (class, readonly, nonatomic) BEColor *webSeashell;   /*!< @c #FFF5EE */
@property (class, readonly, nonatomic) BEColor *webGhostWhite;   /*!< @c #F8F8FF */
@property (class, readonly, nonatomic) BEColor *webHoneydew;   /*!< @c #F0FFF0 */
@property (class, readonly, nonatomic) BEColor *webFloralWhite;   /*!< @c #FFFAF0 */
@property (class, readonly, nonatomic) BEColor *webAzure;   /*!< @c #F0FFFF */
@property (class, readonly, nonatomic) BEColor *webMintCream;   /*!< @c #F5FFFA */
@property (class, readonly, nonatomic) BEColor *webSnow;   /*!< @c #FFFAFA */
@property (class, readonly, nonatomic) BEColor *webIvory;   /*!< @c #FFFFF0 */
@property (class, readonly, nonatomic) BEColor *webMediumVioletRed;   /*!< @c #C71585 */
@property (class, readonly, nonatomic) BEColor *webDeepPink;   /*!< @c #FF1493 */
@property (class, readonly, nonatomic) BEColor *webPaleVioletRed;   /*!< @c #DB7093 */
@property (class, readonly, nonatomic) BEColor *webHotPink;   /*!< @c #FF69B4 */
@property (class, readonly, nonatomic) BEColor *webLightPink;   /*!< @c #FFB6C1 */
@property (class, readonly, nonatomic) BEColor *webPink;   /*!< @c #FFC0CB */
@property (class, readonly, nonatomic) BEColor *webDarkRed;   /*!< @c #8B0000 */
@property (class, readonly, nonatomic) BEColor *webFirebrick;   /*!< @c #B22222 */
@property (class, readonly, nonatomic) BEColor *webCrimson;   /*!< @c #DC143C */
@property (class, readonly, nonatomic) BEColor *webIndianRed;   /*!< @c #CD5C5C */
@property (class, readonly, nonatomic) BEColor *webLightCoral;   /*!< @c #F08080 */
@property (class, readonly, nonatomic) BEColor *webSalmon;   /*!< @c #FA8072 */
@property (class, readonly, nonatomic) BEColor *webDarkSalmon;   /*!< @c #E9967A */
@property (class, readonly, nonatomic) BEColor *webLightSalmon;   /*!< @c #FFA07A */
@property (class, readonly, nonatomic) BEColor *webOrangeRed;   /*!< @c #FF4500 */
@property (class, readonly, nonatomic) BEColor *webTomato;   /*!< @c #FF6347 */
@property (class, readonly, nonatomic) BEColor *webDarkOrange;   /*!< @c #FF8C00 */
@property (class, readonly, nonatomic) BEColor *webCoral;   /*!< @c #FF7F50 */
@property (class, readonly, nonatomic) BEColor *webDarkKhaki;   /*!< @c #BDB76B */
@property (class, readonly, nonatomic) BEColor *webGold;   /*!< @c #FFD700 */
@property (class, readonly, nonatomic) BEColor *webKhaki;   /*!< @c #F0E68C */
@property (class, readonly, nonatomic) BEColor *webPeachPuff;   /*!< @c #FFDAB9 */
@property (class, readonly, nonatomic) BEColor *webPaleGoldenrod;   /*!< @c #EEE8AA */
@property (class, readonly, nonatomic) BEColor *webMoccasin;   /*!< @c #FFE4B5 */
@property (class, readonly, nonatomic) BEColor *webPapayaWhip;   /*!< @c #FFEFD5 */
@property (class, readonly, nonatomic) BEColor *webLightGoldenrodYellow;   /*!< @c #FAFAD2 */
@property (class, readonly, nonatomic) BEColor *webLemonChiffon;   /*!< @c #FFFACD */
@property (class, readonly, nonatomic) BEColor *webLightYellow;   /*!< @c #FFFFE0 */
@property (class, readonly, nonatomic) BEColor *webBrown;   /*!< @c #A52A2A */
@property (class, readonly, nonatomic) BEColor *webSaddleBrown;   /*!< @c #8B4513 */
@property (class, readonly, nonatomic) BEColor *webSienna;   /*!< @c #A0522D */
@property (class, readonly, nonatomic) BEColor *webChocolate;   /*!< @c #D2691E */
@property (class, readonly, nonatomic) BEColor *webDarkGoldenrod;   /*!< @c #B8860B */
@property (class, readonly, nonatomic) BEColor *webPeru;   /*!< @c #CD853F */
@property (class, readonly, nonatomic) BEColor *webRosyBrown;   /*!< @c #BC8F8F */
@property (class, readonly, nonatomic) BEColor *webGoldenrod;   /*!< @c #DAA520 */
@property (class, readonly, nonatomic) BEColor *webSandyBrown;   /*!< @c #F4A460 */
@property (class, readonly, nonatomic) BEColor *webTan;   /*!< @c #D2B48C */
@property (class, readonly, nonatomic) BEColor *webBurlyWood;   /*!< @c #DEB887 */
@property (class, readonly, nonatomic) BEColor *webWheat;   /*!< @c #F5DEB3 */
@property (class, readonly, nonatomic) BEColor *webNavajoWhite;   /*!< @c #FFDEAD */
@property (class, readonly, nonatomic) BEColor *webBisque;   /*!< @c #FFE4C4 */
@property (class, readonly, nonatomic) BEColor *webBlanchedAlmond;   /*!< @c #FFEBCD */
@property (class, readonly, nonatomic) BEColor *webCornsilk;   /*!< @c #FFF8DC */
@property (class, readonly, nonatomic) BEColor *webDarkGreen;   /*!< @c #006400 */
@property (class, readonly, nonatomic) BEColor *webDarkOliveGreen;   /*!< @c #556B2F */
@property (class, readonly, nonatomic) BEColor *webForestGreen;   /*!< @c #228B22 */
@property (class, readonly, nonatomic) BEColor *webSeaGreen;   /*!< @c #2E8B57 */
@property (class, readonly, nonatomic) BEColor *webOliveDrab;   /*!< @c #6B8E23 */
@property (class, readonly, nonatomic) BEColor *webMediumSeaGreen;   /*!< @c #3CB371 */
@property (class, readonly, nonatomic) BEColor *webLimeGreen;   /*!< @c #32CD32 */
@property (class, readonly, nonatomic) BEColor *webSpringGreen;   /*!< @c #00FF7F */
@property (class, readonly, nonatomic) BEColor *webMediumSpringGreen;   /*!< @c #00FA9A */
@property (class, readonly, nonatomic) BEColor *webDarkSeaGreen;   /*!< @c #8FBC8F */
@property (class, readonly, nonatomic) BEColor *webMediumAquamarine;   /*!< @c #66CDAA */
@property (class, readonly, nonatomic) BEColor *webYellowGreen;   /*!< @c #9ACD32 */
@property (class, readonly, nonatomic) BEColor *webLawnGreen;   /*!< @c #7CFC00 */
@property (class, readonly, nonatomic) BEColor *webChartreuse;   /*!< @c #7FFF00 */
@property (class, readonly, nonatomic) BEColor *webLightGreen;   /*!< @c #90EE90 */
@property (class, readonly, nonatomic) BEColor *webGreenYellow;   /*!< @c #ADFF2F */
@property (class, readonly, nonatomic) BEColor *webPaleGreen;   /*!< @c #98FB98 */
@property (class, readonly, nonatomic) BEColor *webDarkCyan;   /*!< @c #008B8B */
@property (class, readonly, nonatomic) BEColor *webLightSeaGreen;   /*!< @c #20B2AA */
@property (class, readonly, nonatomic) BEColor *webCadetBlue;   /*!< @c #5F9EA0 */
@property (class, readonly, nonatomic) BEColor *webDarkTurquoise;   /*!< @c #00CED1 */
@property (class, readonly, nonatomic) BEColor *webMediumTurquoise;   /*!< @c #48D1CC */
@property (class, readonly, nonatomic) BEColor *webTurquoise;   /*!< @c #40E0D0 */
@property (class, readonly, nonatomic) BEColor *webAquamarine;   /*!< @c #7FFFD4 */
@property (class, readonly, nonatomic) BEColor *webPaleTurquoise;   /*!< @c #AFEEEE */
@property (class, readonly, nonatomic) BEColor *webLightCyan;   /*!< @c #E0FFFF */
@property (class, readonly, nonatomic) BEColor *webMidnightBlue;   /*!< @c #191970 */
@property (class, readonly, nonatomic) BEColor *webDarkBlue;   /*!< @c #00008B */
@property (class, readonly, nonatomic) BEColor *webMediumBlue;   /*!< @c #0000CD */
@property (class, readonly, nonatomic) BEColor *webRoyalBlue;   /*!< @c #4169E1 */
@property (class, readonly, nonatomic) BEColor *webSteelBlue;   /*!< @c #4682B4 */
@property (class, readonly, nonatomic) BEColor *webDodgerBlue;   /*!< @c #1E90FF */
@property (class, readonly, nonatomic) BEColor *webDeepSkyBlue;   /*!< @c #00BFFF */
@property (class, readonly, nonatomic) BEColor *webCornflowerBlue;   /*!< @c #6495ED */
@property (class, readonly, nonatomic) BEColor *webSkyBlue;   /*!< @c #87CEEB */
@property (class, readonly, nonatomic) BEColor *webLightSkyBlue;   /*!< @c #87CEFA */
@property (class, readonly, nonatomic) BEColor *webLightSteelBlue;   /*!< @c #B0C4DE */
@property (class, readonly, nonatomic) BEColor *webLightBlue;   /*!< @c #ADD8E6 */
@property (class, readonly, nonatomic) BEColor *webPowderBlue;   /*!< @c #B0E0E6 */
@property (class, readonly, nonatomic) BEColor *webIndigo;   /*!< @c #4B0082 */
@property (class, readonly, nonatomic) BEColor *webDarkMagenta;   /*!< @c #8B008B */
@property (class, readonly, nonatomic) BEColor *webDarkViolet;   /*!< @c #9400D3 */
@property (class, readonly, nonatomic) BEColor *webDarkSlateBlue;   /*!< @c #483D8B */
@property (class, readonly, nonatomic) BEColor *webBlueViolet;   /*!< @c #8A2BE2 */
@property (class, readonly, nonatomic) BEColor *webDarkOrchid;   /*!< @c #9932CC */
@property (class, readonly, nonatomic) BEColor *webSlateBlue;   /*!< @c #6A5ACD */
@property (class, readonly, nonatomic) BEColor *webMediumSlateBlue;   /*!< @c #7B68EE */
@property (class, readonly, nonatomic) BEColor *webMediumOrchid;   /*!< @c #BA55D3 */
@property (class, readonly, nonatomic) BEColor *webMediumPurple;   /*!< @c #9370DB */
@property (class, readonly, nonatomic) BEColor *webOrchid;   /*!< @c #DA70D6 */
@property (class, readonly, nonatomic) BEColor *webViolet;   /*!< @c #EE82EE */
@property (class, readonly, nonatomic) BEColor *webPlum;   /*!< @c #DDA0DD */
@property (class, readonly, nonatomic) BEColor *webThistle;   /*!< @c #D8BFD8 */
@property (class, readonly, nonatomic) BEColor *webLavender;   /*!< @c #E6E6FA */
@property (class, readonly, nonatomic) BEColor *webRebeccaPurple;   /*!< @c #663399 */

@end

NS_ASSUME_NONNULL_END

#endif // !BEColor_BEWebColor_h
