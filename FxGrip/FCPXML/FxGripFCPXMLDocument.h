/*!
	@file       FxGripFCPXMLDocument.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLDocument
	@abstract   An FCPXML document: the `fcpxml` root, its resources, and its library or items.
	@discussion Introduced in FxGrip 0.1.0. The document reads and writes the `.fcpxml` file and
	            the `.fcpxmld` package (a folder whose `Info.fcpxml` holds the document), tracks
	            the format version, and validates against the schema or Final Cut Pro's installed
	            DTD. It wraps an `NSXMLDocument`, so the whole tree round-trips, and every
	            ``FxGripFCPXMLElement`` reaches its document through `document`.
*/

#ifndef FxGripFCPXMLDocument_h
#define FxGripFCPXMLDocument_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripFCPXMLVersion.h>
#import <FxGrip/FxGripFCPXMLElement.h>
#import <FxGrip/FxGripFCPXMLResources.h>
#import <FxGrip/FxGripFCPXMLLibrary.h>

NS_ASSUME_NONNULL_BEGIN

/*! The `.fcpxml` path extension. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLFileExtension;
/*! The `.fcpxmld` package path extension. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLBundleExtension;
/*! The name of the document inside a `.fcpxmld` package. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLBundleInfoFileName;
/*! The name of the resources folder inside a `.fcpxmld` package. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLBundleResourcesFolderName;

/*!
	@class      FxGripFCPXMLDocument
	@abstract   An FCPXML document.
	@discussion Introduced in FxGrip 0.1.0. A new document carries the latest version, an empty
				`resources` element, and no library. `resources` and `libraryCreatingIfNeeded`
				create their elements on demand, in DTD order.
*/
@interface FxGripFCPXMLDocument : NSObject <NSCopying>

#pragma mark Creating and reading

/*! A new, empty document at the latest version. */
- (instancetype)init;
/*! A new, empty document at a version. */
- (instancetype)initWithVersion:(FxGripFCPXMLVersion)version;

/*!
	@method     initWithData:error:
	@abstract   Parses FCPXML bytes.
	@discussion Fails when the bytes are not XML or the root element is not `fcpxml`. The
				version attribute is read but not enforced; an absent version reads as the
				latest.
*/
- (nullable instancetype)initWithData:(NSData *)data error:(NSError * _Nullable * _Nullable)error;

/*!
	@method     initWithContentsOfURL:error:
	@abstract   Reads a `.fcpxml` file or a `.fcpxmld` package.
	@discussion A package reads its `Info.fcpxml`; `bundleURL` then names the package.
*/
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)error;

/*!
	@method     initWithXMLDocument:error:
	@abstract   Wraps an existing `NSXMLDocument` whose root is `fcpxml`.
*/
- (nullable instancetype)initWithXMLDocument:(NSXMLDocument *)xmlDocument error:(NSError * _Nullable * _Nullable)error;

/*! Parses an FCPXML string. */
- (nullable instancetype)initWithXMLString:(NSString *)string error:(NSError * _Nullable * _Nullable)error;

#pragma mark Structure

/*! The wrapped document. */
@property (readonly, strong) NSXMLDocument *xmlDocument;
/*! The `fcpxml` root element. */
@property (readonly) FxGripFCPXMLElement *rootElement;
/*! The format version the root declares. Setting it rewrites the attribute. */
@property (readwrite) FxGripFCPXMLVersion version;
/*! The `.fcpxmld` package the document was read from or written to, or nil. */
@property (readonly, nullable) NSURL *bundleURL;

/*! The `import-options` as key-value pairs; empty when absent. */
@property (readwrite, copy) NSDictionary<NSString *, NSString *> *importOptions;

/*! The `resources` element, created when absent. */
@property (readonly) FxGripFCPXMLResources *resources;
/*! YES when the document has a `resources` element. */
@property (readonly) BOOL hasResources;

/*! The `library` element, or nil. */
@property (readonly, nullable) FxGripFCPXMLLibrary *library;
/*! The `library` element, created when absent. */
- (FxGripFCPXMLLibrary *)libraryCreatingIfNeeded;

/*! The top-level items after the resources: the library, or the events and event items. */
@property (readonly, copy) NSArray<__kindof FxGripFCPXMLElement *> *topLevelItems;
/*! Appends a top-level item: an event, a clip, a collection, or a project. */
- (void)addTopLevelItem:(FxGripFCPXMLElement *)item;

/*! Every event, inside the library or at the top level. */
@property (readonly, copy) NSArray<FxGripFCPXMLEvent *> *events;
/*! Every project, at any depth. */
@property (readonly, copy) NSArray<FxGripFCPXMLProject *> *projects;

#pragma mark Lookup

/*! Every element with a name, at any depth below the root. */
- (NSArray<__kindof FxGripFCPXMLElement *> *)elementsNamed:(NSString *)name;
/*! The element whose `id` attribute matches, or nil. */
- (nullable __kindof FxGripFCPXMLElement *)elementWithIdentifier:(NSString *)identifier;
/*! The resource an element's `ref` attribute names, or nil. */
- (nullable __kindof FxGripFCPXMLResource *)resourceReferencedByElement:(FxGripFCPXMLElement *)element;

#pragma mark Validation

/*!
	@property   validationProblems
	@abstract   The schema problems the document shows at its declared version.
	@discussion The element checks of ``FxGripFCPXMLElement`` over the whole tree, plus a check
				that every `ref` and `format` reference resolves to a resource identifier.
*/
@property (readonly, copy) NSArray<NSString *> *validationProblems;

/*! The earliest version that defines everything the document carries, or the invalid version
	when an element or attribute is unknown. */
@property (readonly) FxGripFCPXMLVersion minimumVersion;

/*!
	@method     validateAgainstDTDAtURL:error:
	@abstract   Validates the document against a DTD file.
	@discussion Passing nil uses the DTD for the document's version from the installed Final Cut
				Pro, which fails with an error when no DTD is installed. The document is copied
				for validation, so it is not modified.
*/
- (BOOL)validateAgainstDTDAtURL:(nullable NSURL *)dtdURL error:(NSError * _Nullable * _Nullable)error;

#pragma mark Writing

/*! The document as XML bytes, with the XML declaration and the `fcpxml` DOCTYPE. */
@property (readonly, copy) NSData *XMLData;
/*! The document as an XML string. */
@property (readonly, copy) NSString *XMLString;

/*!
	@method     writeToURL:error:
	@abstract   Writes a `.fcpxml` file, or a `.fcpxmld` package when the URL has that extension.
	@discussion A package is a folder holding `Info.fcpxml`; an existing package's other
				contents are kept.
*/
- (BOOL)writeToURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLDocument_h */
