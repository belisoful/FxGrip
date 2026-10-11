/*!
	@file       FxGripFCPXMLText.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLText
	@abstract   The `text`, `text-style`, and `text-style-def` elements of titles and captions.
	@discussion Introduced in FxGrip 0.1.0. A `title` or `caption` holds `text` elements whose
	            runs are plain strings or `text-style` spans that reference a `text-style-def`
	            by identifier or carry their own font attributes.
*/

#ifndef FxGripFCPXMLText_h
#define FxGripFCPXMLText_h

#import <FxGrip/FxGripFCPXMLElement.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripFCPXMLTextStyle
	@abstract   A `text-style` span or a `text-style-def` definition.
	@discussion Introduced in FxGrip 0.1.0. A definition carries an identifier and wraps one
				`text-style` with the attributes; a span references a definition through `ref`
				or carries the attributes itself.
*/
@interface FxGripFCPXMLTextStyle : FxGripFCPXMLElement

/*! YES for a `text-style-def`. */
@property (readonly) BOOL isDefinition;
/*! The definition identifier. */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The definition name. */
@property (readwrite, copy, nullable) NSString *styleName;
/*! The identifier of the definition a span references. */
@property (readwrite, copy, nullable) NSString *referenceIdentifier;
/*! The element that carries the font attributes: the span itself, or the definition's inner `text-style`. */
@property (readonly) FxGripFCPXMLElement *attributeElement;

/*! The font family. */
@property (readwrite, copy, nullable) NSString *font;
/*! The font size in points; 0 when absent. */
@property (readwrite) double fontSize;
/*! The font face, such as `Bold`. */
@property (readwrite, copy, nullable) NSString *fontFace;
/*! The font color as `r g b a` components in 0…1. */
@property (readwrite, copy) NSArray<NSNumber *> *fontColor;
/*! YES when bold. */
@property (readwrite) BOOL bold;
/*! YES when italic. */
@property (readwrite) BOOL italic;
/*! The alignment: `left`, `center`, `right`, or `justified`. */
@property (readwrite, copy, nullable) NSString *alignment;
/*! The stroke color as `r g b a`. */
@property (readwrite, copy) NSArray<NSNumber *> *strokeColor;
/*! The stroke width; 0 when absent. */
@property (readwrite) double strokeWidth;

/*! A span that references a definition and carries text. */
+ (instancetype)spanWithReferenceIdentifier:(NSString *)identifier text:(nullable NSString *)text;
/*! A definition with an identifier and a font. */
+ (instancetype)definitionWithIdentifier:(NSString *)identifier font:(nullable NSString *)font size:(double)fontSize;

@end

/*!
	@class      FxGripFCPXMLText
	@abstract   A `text` element: the runs of a title's or caption's text.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLText : FxGripFCPXMLElement

/*! The text with styles stripped, runs concatenated. */
@property (readonly, copy) NSString *plainText;
/*! The styled spans, in order. */
@property (readonly, copy) NSArray<FxGripFCPXMLTextStyle *> *spans;
/*! The CEA-608 caption display style, when present. */
@property (readwrite, copy, nullable) NSString *displayStyle;
/*! The caption placement, when present. */
@property (readwrite, copy, nullable) NSString *placement;

/*! Replaces the content with one span referencing a style definition. */
- (void)setPlainText:(NSString *)text styleReference:(nullable NSString *)identifier;
/*! Appends a styled span. */
- (void)addSpan:(FxGripFCPXMLTextStyle *)span;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLText_h */
