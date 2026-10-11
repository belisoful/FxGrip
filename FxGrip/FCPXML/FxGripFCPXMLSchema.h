/*!
	@file       FxGripFCPXMLSchema.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLSchema
	@abstract   The FCPXML element and attribute schema across every format version.
	@discussion Introduced in FxGrip 0.1.0. The schema answers which elements exist in a
	            version, what each may contain, and what attributes each takes, with the
	            attribute's kind, enumerated values, default, and required flag. The data comes
	            from the C tables in FxGripFCPXMLSchemaTable.m, which
	            `Scripts/make-fcpxml-schema.py` generates from the DTDs Final Cut Pro installs.
	            Validation through ``FxGripFCPXMLElement`` and ``FxGripFCPXMLDocument`` reads this
	            schema; it needs no DTD at run time.
*/

#ifndef FxGripFCPXMLSchema_h
#define FxGripFCPXMLSchema_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripFCPXMLVersion.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripFCPXMLAttributeKind
	@abstract   The value kind an attribute takes.
	@discussion Introduced in FxGrip 0.1.0.
*/
typedef NS_ENUM(NSInteger, FxGripFCPXMLAttributeKind) {
	/*! Free text (`CDATA`). */
	FxGripFCPXMLAttributeKindString = 0,
	/*! A rational time, such as `1001/30000s`. */
	FxGripFCPXMLAttributeKindTime,
	/*! One of a fixed list of tokens. */
	FxGripFCPXMLAttributeKindEnumeration,
	/*! A resource identifier the document defines (`ID`). */
	FxGripFCPXMLAttributeKindIdentifier,
	/*! A reference to a resource identifier (`IDREF`). */
	FxGripFCPXMLAttributeKindReference,
};

/*! One generated attribute row. A minor version of -1 in `removedMinor` means still present. */
typedef struct FxGripFCPXMLSchemaAttributeRecord {
	const char *element;
	const char *attribute;
	NSInteger introducedMinor;
	NSInteger removedMinor;
	FxGripFCPXMLAttributeKind kind;
	BOOL required;
	const char * _Nullable defaultValue;
	const char * _Nullable values;
} FxGripFCPXMLSchemaAttributeRecord;

/*! One generated element row. `children` is a space-separated list of element names. */
typedef struct FxGripFCPXMLSchemaElementRecord {
	const char *element;
	NSInteger introducedMinor;
	NSInteger removedMinor;
	const char *children;
} FxGripFCPXMLSchemaElementRecord;

/*! The minor version of the newest DTD the table was generated from. */
FOUNDATION_EXPORT const NSInteger FxGripFCPXMLSchemaLatestMinorVersion;
/*! The generated attribute rows, sorted by element then attribute. */
FOUNDATION_EXPORT const FxGripFCPXMLSchemaAttributeRecord FxGripFCPXMLSchemaAttributeRecords[];
/*! The number of attribute rows. */
FOUNDATION_EXPORT const NSUInteger FxGripFCPXMLSchemaAttributeRecordCount;
/*! The generated element rows, sorted by element name. */
FOUNDATION_EXPORT const FxGripFCPXMLSchemaElementRecord FxGripFCPXMLSchemaElementRecords[];
/*! The number of element rows. */
FOUNDATION_EXPORT const NSUInteger FxGripFCPXMLSchemaElementRecordCount;

/*!
	@class      FxGripFCPXMLSchemaAttribute
	@abstract   One attribute of one element.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLSchemaAttribute : NSObject

/*! The attribute name. */
@property (readonly, copy) NSString *name;
/*! The value kind. */
@property (readonly) FxGripFCPXMLAttributeKind kind;
/*! YES when the DTD marks the attribute `#REQUIRED`. */
@property (readonly) BOOL required;
/*! The default the DTD declares, or nil. */
@property (readonly, copy, nullable) NSString *defaultValue;
/*! The tokens an enumeration accepts; empty for other kinds. */
@property (readonly, copy) NSArray<NSString *> *enumeratedValues;
/*! The version that introduced the attribute. */
@property (readonly) FxGripFCPXMLVersion introducedIn;
/*! The version that removed the attribute, or the invalid version while it remains. */
@property (readonly) FxGripFCPXMLVersion removedIn;

/*! YES when the attribute exists in the version. */
- (BOOL)isAvailableInVersion:(FxGripFCPXMLVersion)version;

/*! YES when a value fits the kind: an enumeration token, a parseable time, or a non-empty
	identifier or reference. A string kind accepts any value. */
- (BOOL)acceptsValue:(nullable NSString *)value;

@end

/*!
	@class      FxGripFCPXMLSchemaElement
	@abstract   One element: its lifetime across versions, its children, and its attributes.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLSchemaElement : NSObject

/*! The element name. */
@property (readonly, copy) NSString *name;
/*! The version that introduced the element. */
@property (readonly) FxGripFCPXMLVersion introducedIn;
/*! The version that removed the element, or the invalid version while it remains. */
@property (readonly) FxGripFCPXMLVersion removedIn;
/*! The element names the content model allows as children. */
@property (readonly, copy) NSSet<NSString *> *childElementNames;
/*! The attributes, keyed by name. */
@property (readonly, copy) NSDictionary<NSString *, FxGripFCPXMLSchemaAttribute *> *attributes;
/*! The names of the required attributes, sorted. */
@property (readonly, copy) NSArray<NSString *> *requiredAttributeNames;

/*! YES when the element exists in the version. */
- (BOOL)isAvailableInVersion:(FxGripFCPXMLVersion)version;
/*! YES when the content model allows a child element of the name. */
- (BOOL)allowsChildNamed:(NSString *)name;
/*! The attribute for a name, or nil. */
- (nullable FxGripFCPXMLSchemaAttribute *)attributeNamed:(NSString *)name;

@end

/*!
	@class      FxGripFCPXMLSchema
	@abstract   The schema over every FCPXML version the table knows.
	@discussion Introduced in FxGrip 0.1.0. The shared schema builds its objects from the
				generated tables on first use.
*/
@interface FxGripFCPXMLSchema : NSObject

/*! The shared schema. */
+ (instancetype)sharedSchema;

/*! The newest version the table knows. */
@property (readonly) FxGripFCPXMLVersion latestVersion;
/*! The oldest version the table knows, 1.0. */
@property (readonly) FxGripFCPXMLVersion earliestVersion;

/*! Every element name, sorted. */
@property (readonly, copy) NSArray<NSString *> *elementNames;

/*! The element for a name, or nil when no version defines it. */
- (nullable FxGripFCPXMLSchemaElement *)elementNamed:(NSString *)name;

/*! The names of the elements a version defines, sorted. */
- (NSArray<NSString *> *)elementNamesAvailableInVersion:(FxGripFCPXMLVersion)version;
/*! The names of the elements a version added, sorted. */
- (NSArray<NSString *> *)elementNamesIntroducedInVersion:(FxGripFCPXMLVersion)version;
/*! The names of the elements a version dropped, sorted. */
- (NSArray<NSString *> *)elementNamesRemovedInVersion:(FxGripFCPXMLVersion)version;

/*!
	@method     minimumVersionForElementNamed:attributeNamed:
	@abstract   The earliest version that defines an element, or one of its attributes.
	@param      elementName		The element.
	@param      attributeName	An attribute of the element, or nil for the element itself.
	@return     The introducing version, or the invalid version when the name is unknown.
*/
- (FxGripFCPXMLVersion)minimumVersionForElementNamed:(NSString *)elementName
									  attributeNamed:(nullable NSString *)attributeName;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLSchema_h */
