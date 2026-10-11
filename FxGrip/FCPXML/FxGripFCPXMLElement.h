/*!
	@file       FxGripFCPXMLElement.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLElement
	@abstract   The typed wrapper over one FCPXML element.
	@discussion Introduced in FxGrip 0.1.0. An FxGripFCPXMLElement wraps an `NSXMLElement` and
	            reads and writes its attributes as FCPXML types: strings, booleans (`0`/`1`),
	            integers, doubles, rational times, and space-separated number lists. The wrapper
	            holds no state of its own, so two wrappers over the same `NSXMLElement` are equal
	            and any element in a document can be reached and modified through any wrapper.
	            Unknown elements and attributes pass through untouched, which keeps a document
	            round-trip faithful. The class also registers the typed subclasses by element
	            name, so `elementNamed:` and the child accessors return a `FxGripFCPXMLParam`
	            for a `param`, a `FxGripFCPXMLFilter` for a `filter-video`, and so on. Validation
	            reads ``FxGripFCPXMLSchema``.
*/

#ifndef FxGripFCPXMLElement_h
#define FxGripFCPXMLElement_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <FxGrip/FxGripFCPXMLVersion.h>

@class FxGripFCPXMLSchemaElement;
@class FxGripFCPXMLDocument;

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripFCPXMLElement
	@abstract   A typed view of one `NSXMLElement` in an FCPXML tree.
	@discussion Introduced in FxGrip 0.1.0. Create an element with `elementNamed:` or a typed
				subclass's `init`, and attach it with `addChild:`. Read the tree through
				`children`, `childrenNamed:`, and `descendantsNamed:`; each returns the typed
				subclass registered for the element name.
*/
@interface FxGripFCPXMLElement : NSObject <NSCopying>

#pragma mark Creating and wrapping

/*!
	@method     elementNamed:
	@abstract   A new, unattached element of the typed class registered for the name.
*/
+ (instancetype)elementNamed:(NSString *)name;

/*!
	@method     elementWithXMLElement:
	@abstract   The typed wrapper for an existing `NSXMLElement`.
	@discussion The class is chosen by the element's name. The element is not copied.
*/
+ (instancetype)elementWithXMLElement:(NSXMLElement *)xmlElement;

/*!
	@method     classForElementNamed:
	@abstract   The wrapper class registered for an element name; the base class when none is.
*/
+ (Class)classForElementNamed:(nullable NSString *)name;

/*!
	@method     registerClass:forElementNamed:
	@abstract   Registers a wrapper class for an element name, replacing any earlier entry.
	@discussion The class must descend from FxGripFCPXMLElement. FxGrip registers its own typed
				classes before the first lookup.
*/
+ (void)registerClass:(Class)elementClass forElementNamed:(NSString *)name;

/*!
	@method     elementName
	@abstract   The element name a subclass creates by default, or nil for the base class.
	@discussion A subclass that wraps several element names returns the most common one.
*/
+ (nullable NSString *)elementName;

/*!
	@method     elementNames
	@abstract   Every element name a subclass registers for, or an empty array for the base.
*/
+ (NSArray<NSString *> *)elementNames;

/*!
	@method     initWithElementName:
	@abstract   The designated initializer: a new, unattached element with the name.
*/
- (instancetype)initWithElementName:(NSString *)name NS_DESIGNATED_INITIALIZER;

/*!
	@method     initWithXMLElement:
	@abstract   Wraps an existing `NSXMLElement` without copying it.
*/
- (instancetype)initWithXMLElement:(NSXMLElement *)xmlElement NS_DESIGNATED_INITIALIZER;

/*!
	@method     init
	@abstract   A new element named by the class's `elementName`.
	@discussion Unavailable on the base class, which has no element name of its own.
*/
- (instancetype)init;

#pragma mark Tree

/*! The wrapped element. */
@property (readonly, strong) NSXMLElement *xmlElement;
/*! The element name. */
@property (readonly, copy) NSString *name;
/*! The parent element, or nil at the root or while unattached. */
@property (readonly, nullable) FxGripFCPXMLElement *parent;
/*! The child elements, typed, in document order. Text nodes are not included. */
@property (readonly, copy) NSArray<FxGripFCPXMLElement *> *children;
/*! The document the element belongs to, or nil while unattached. */
@property (readonly, nullable) FxGripFCPXMLDocument *document;
/*! The element's position among its parent's children, or `NSNotFound` while unattached. */
@property (readonly) NSUInteger index;
/*! The XPath of the element in its document. */
@property (readonly, copy) NSString *path;

/*! The child elements with a name, in document order. */
- (NSArray<__kindof FxGripFCPXMLElement *> *)childrenNamed:(NSString *)name;
/*! The first child element with a name, or nil. */
- (nullable __kindof FxGripFCPXMLElement *)firstChildNamed:(NSString *)name;
/*! The first child element with a name, created and appended when absent. */
- (__kindof FxGripFCPXMLElement *)childNamed:(NSString *)name create:(BOOL)create;
/*! Every descendant element with a name, in document order. */
- (NSArray<__kindof FxGripFCPXMLElement *> *)descendantsNamed:(NSString *)name;
/*! The elements an XPath selects relative to this element. */
- (NSArray<__kindof FxGripFCPXMLElement *> *)elementsForXPath:(NSString *)xpath;

/*! Appends a child. A child attached elsewhere is detached first. */
- (void)addChild:(FxGripFCPXMLElement *)child;
/*! Inserts a child at an index among the element's child nodes. */
- (void)insertChild:(FxGripFCPXMLElement *)child atIndex:(NSUInteger)index;
/*! Inserts a child before or after the last child with a name, keeping the DTD's ordering
	for elements that group by name; appends when none is present. */
- (void)addChild:(FxGripFCPXMLElement *)child afterLastChildNamed:(NSString *)name;
/*! Removes a direct child. */
- (void)removeChild:(FxGripFCPXMLElement *)child;
/*! Removes every child with a name. */
- (void)removeChildrenNamed:(NSString *)name;
/*! Detaches the element from its parent. */
- (void)removeFromParent;

#pragma mark Attributes

/*! The attributes as strings, keyed by name. */
@property (readonly, copy) NSDictionary<NSString *, NSString *> *attributes;

/*! The string value of an attribute, or nil when absent. */
- (nullable NSString *)stringForAttribute:(NSString *)name;
/*! Sets an attribute; nil removes it. */
- (void)setString:(nullable NSString *)value forAttribute:(NSString *)name;
/*! YES when the attribute is present. */
- (BOOL)hasAttribute:(NSString *)name;
/*! Removes an attribute. */
- (void)removeAttribute:(NSString *)name;

/*! A `0`/`1` attribute as a boolean; the default when absent or malformed. */
- (BOOL)boolForAttribute:(NSString *)name defaultValue:(BOOL)defaultValue;
/*! Writes a boolean as `0` or `1`. */
- (void)setBool:(BOOL)value forAttribute:(NSString *)name;

/*! An integer attribute; the default when absent or malformed. */
- (NSInteger)integerForAttribute:(NSString *)name defaultValue:(NSInteger)defaultValue;
/*! Writes an integer. */
- (void)setInteger:(NSInteger)value forAttribute:(NSString *)name;

/*! A floating-point attribute; the default when absent or malformed. */
- (double)doubleForAttribute:(NSString *)name defaultValue:(double)defaultValue;
/*! Writes a floating-point number with up to fifteen significant digits. */
- (void)setDouble:(double)value forAttribute:(NSString *)name;

/*! A rational time attribute, or `kCMTimeInvalid` when absent or malformed. */
- (CMTime)timeForAttribute:(NSString *)name;
/*! Writes a time in FCPXML rational form; an invalid time removes the attribute. */
- (void)setTime:(CMTime)time forAttribute:(NSString *)name;

/*! A space-separated list of numbers, such as a point `"x y"` or a color `"r g b a"`; empty
	when absent. */
- (NSArray<NSNumber *> *)numbersForAttribute:(NSString *)name;
/*! Writes numbers separated by single spaces; an empty array removes the attribute. */
- (void)setNumbers:(NSArray<NSNumber *> *)numbers forAttribute:(NSString *)name;

#pragma mark Content

/*! The concatenated text content, or nil when the element has no text. */
@property (readwrite, copy, nullable) NSString *stringValue;

#pragma mark Schema and validation

/*! The schema entry for the element name, or nil for an element no version defines. */
@property (readonly, nullable) FxGripFCPXMLSchemaElement *schemaElement;

/*!
	@method     validationProblemsForVersion:recursive:
	@abstract   The schema problems the element shows in a version.
	@discussion Each problem is a sentence naming the element path. The checks:

	- the element name is defined in the version;
	- every attribute is defined for the element in the version and accepts its value;
	- every required attribute is present;
	- every child element name is allowed by the content model.
	@param      version		The version to validate against.
	@param      recursive	YES to include the descendants' problems.
	@return     The problems, empty when the element conforms.
*/
- (NSArray<NSString *> *)validationProblemsForVersion:(FxGripFCPXMLVersion)version recursive:(BOOL)recursive;

/*! The earliest version that defines the element and every attribute and descendant it carries,
	or the invalid version when an element or attribute is unknown. */
- (FxGripFCPXMLVersion)minimumVersion;

#pragma mark Serialization

/*! The element as an XML string, indented. */
@property (readonly, copy) NSString *XMLString;

/*! A deep copy, detached from any parent. */
- (id)copyWithZone:(nullable NSZone *)zone;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLElement_h */
