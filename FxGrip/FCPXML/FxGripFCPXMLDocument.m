/*!
	@file       FxGripFCPXMLDocument.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLDocument
	@abstract   An FCPXML document: the `fcpxml` root, its resources, and its library or items.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLDocument.h.
*/

#import <FxGrip/FxGripFCPXMLDocument.h>
#import <FxGrip/FxGripFCPXMLSchema.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <FxGrip/FxGripErrors.h>

NSString *const FxGripFCPXMLFileExtension = @"fcpxml";
NSString *const FxGripFCPXMLBundleExtension = @"fcpxmld";
NSString *const FxGripFCPXMLBundleInfoFileName = @"Info.fcpxml";
NSString *const FxGripFCPXMLBundleResourcesFolderName = @"Resources";

static NSString *const FxGripFCPXMLRootName = @"fcpxml";

static NSError *FxGripFCPXMLError(NSString *description)
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:kFxGripError_FCPXML
						   userInfo:@{NSLocalizedDescriptionKey: description}];
}

@implementation FxGripFCPXMLDocument

#pragma mark - Creating and reading

- (instancetype)init
{
	return [self initWithVersion:FxGripFCPXMLVersionLatest()];
}

- (instancetype)initWithVersion:(FxGripFCPXMLVersion)version
{
	NSXMLElement *root = [NSXMLElement elementWithName:FxGripFCPXMLRootName];
	NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithRootElement:root];
	xmlDocument.version = @"1.0";
	xmlDocument.characterEncoding = @"UTF-8";
	xmlDocument.standalone = NO;
	self = [self initWithXMLDocument:xmlDocument error:NULL];
	if (self) {
		self.version = FxGripFCPXMLVersionIsValid(version) ? version : FxGripFCPXMLVersionLatest();
		[self resources];
	}
	return self;
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)error
{
	if (data == nil) {
		if (error) {
			*error = FxGripFCPXMLError(@"No FCPXML data.");
		}
		return nil;
	}
	NSError *parseError = nil;
	NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithData:data
															 options:NSXMLNodeLoadExternalEntitiesNever
															   error:&parseError];
	if (xmlDocument == nil) {
		if (error) {
			*error = parseError ?: FxGripFCPXMLError(@"The data is not XML.");
		}
		return nil;
	}
	return [self initWithXMLDocument:xmlDocument error:error];
}

- (instancetype)initWithXMLString:(NSString *)string error:(NSError **)error
{
	return [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] error:error];
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
	NSURL *fileURL = url;
	NSURL *bundleURL = nil;
	if ([url.pathExtension caseInsensitiveCompare:FxGripFCPXMLBundleExtension] == NSOrderedSame) {
		bundleURL = url;
		fileURL = [url URLByAppendingPathComponent:FxGripFCPXMLBundleInfoFileName];
	}
	NSError *readError = nil;
	NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&readError];
	if (data == nil) {
		if (error) {
			*error = readError;
		}
		return nil;
	}
	self = [self initWithData:data error:error];
	if (self && bundleURL != nil) {
		self.xmlDocument.URI = bundleURL.absoluteString;
	}
	return self;
}

- (instancetype)initWithXMLDocument:(NSXMLDocument *)xmlDocument error:(NSError **)error
{
	self = [super init];
	if (self) {
		if (![xmlDocument.rootElement.name isEqualToString:FxGripFCPXMLRootName]) {
			if (error) {
				*error = FxGripFCPXMLError([NSString stringWithFormat:@"The root element is '%@', not 'fcpxml'.",
											xmlDocument.rootElement.name ?: @""]);
			}
			return nil;
		}
		_xmlDocument = xmlDocument;
	}
	return self;
}

#pragma mark - Structure

- (FxGripFCPXMLElement *)rootElement
{
	return [FxGripFCPXMLElement elementWithXMLElement:self.xmlDocument.rootElement];
}

- (FxGripFCPXMLVersion)version
{
	NSString *string = [self.rootElement stringForAttribute:@"version"];
	FxGripFCPXMLVersion version = FxGripFCPXMLVersionFromString(string);
	return FxGripFCPXMLVersionIsValid(version) ? version : FxGripFCPXMLVersionLatest();
}

- (void)setVersion:(FxGripFCPXMLVersion)version
{
	[self.rootElement setString:FxGripFCPXMLVersionString(version) forAttribute:@"version"];
}

- (NSURL *)bundleURL
{
	NSString *uri = self.xmlDocument.URI;
	return uri ? [NSURL URLWithString:uri] : nil;
}

- (NSDictionary<NSString *, NSString *> *)importOptions
{
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	FxGripFCPXMLElement *element = [self.rootElement firstChildNamed:@"import-options"];
	for (FxGripFCPXMLElement *option in [element childrenNamed:@"option"]) {
		NSString *key = [option stringForAttribute:@"key"];
		if (key != nil) {
			options[key] = [option stringForAttribute:@"value"] ?: @"";
		}
	}
	return options;
}

- (void)setImportOptions:(NSDictionary<NSString *, NSString *> *)importOptions
{
	FxGripFCPXMLElement *root = self.rootElement;
	[root removeChildrenNamed:@"import-options"];
	if (importOptions.count == 0) {
		return;
	}
	FxGripFCPXMLElement *element = [FxGripFCPXMLElement elementNamed:@"import-options"];
	for (NSString *key in [importOptions.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
		FxGripFCPXMLElement *option = [FxGripFCPXMLElement elementNamed:@"option"];
		[option setString:key forAttribute:@"key"];
		[option setString:importOptions[key] forAttribute:@"value"];
		[element addChild:option];
	}
	// DTD order: import-options?, resources?, then the content.
	[root insertChild:element atIndex:0];
}

- (BOOL)hasResources
{
	return [self.rootElement firstChildNamed:@"resources"] != nil;
}

- (FxGripFCPXMLResources *)resources
{
	FxGripFCPXMLElement *root = self.rootElement;
	FxGripFCPXMLResources *resources = [root firstChildNamed:@"resources"];
	if (resources == nil) {
		resources = [[FxGripFCPXMLResources alloc] init];
		FxGripFCPXMLElement *importOptions = [root firstChildNamed:@"import-options"];
		[root insertChild:resources atIndex:(importOptions ? importOptions.xmlElement.index + 1 : 0)];
	}
	return resources;
}

- (FxGripFCPXMLLibrary *)library
{
	return [self.rootElement firstChildNamed:@"library"];
}

- (FxGripFCPXMLLibrary *)libraryCreatingIfNeeded
{
	FxGripFCPXMLLibrary *library = self.library;
	if (library == nil) {
		library = [[FxGripFCPXMLLibrary alloc] init];
		[self addTopLevelItem:library];
	}
	return library;
}

- (NSArray *)topLevelItems
{
	NSMutableArray *items = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.rootElement.children) {
		if (![child.name isEqualToString:@"import-options"] && ![child.name isEqualToString:@"resources"]) {
			[items addObject:child];
		}
	}
	return items;
}

- (void)addTopLevelItem:(FxGripFCPXMLElement *)item
{
	[self.rootElement addChild:item];
}

- (NSArray<FxGripFCPXMLEvent *> *)events
{
	NSMutableArray *events = [NSMutableArray array];
	for (FxGripFCPXMLElement *item in self.topLevelItems) {
		if ([item isKindOfClass:FxGripFCPXMLLibrary.class]) {
			[events addObjectsFromArray:((FxGripFCPXMLLibrary *)item).events];
		} else if ([item isKindOfClass:FxGripFCPXMLEvent.class]) {
			[events addObject:item];
		}
	}
	return events;
}

- (NSArray<FxGripFCPXMLProject *> *)projects
{
	return [self elementsNamed:@"project"];
}

#pragma mark - Lookup

- (NSArray *)elementsNamed:(NSString *)name
{
	return [self.rootElement descendantsNamed:name];
}

- (FxGripFCPXMLElement *)elementWithIdentifier:(NSString *)identifier
{
	if (identifier.length == 0) {
		return nil;
	}
	NSString *xpath = [NSString stringWithFormat:@"//*[@id='%@']",
					   [identifier stringByReplacingOccurrencesOfString:@"'" withString:@"&apos;"]];
	return [self.rootElement elementsForXPath:xpath].firstObject;
}

- (FxGripFCPXMLResource *)resourceReferencedByElement:(FxGripFCPXMLElement *)element
{
	NSString *reference = [element stringForAttribute:@"ref"];
	if (reference == nil || !self.hasResources) {
		return nil;
	}
	return [self.resources resourceWithIdentifier:reference];
}

#pragma mark - Validation

- (NSArray<NSString *> *)validationProblems
{
	NSMutableArray *problems = [[self.rootElement validationProblemsForVersion:self.version recursive:YES] mutableCopy];
	NSMutableSet *identifiers = [NSMutableSet set];
	for (FxGripFCPXMLElement *element in [self.rootElement elementsForXPath:@"//*[@id]"]) {
		NSString *identifier = [element stringForAttribute:@"id"];
		if ([identifiers containsObject:identifier]) {
			[problems addObject:[NSString stringWithFormat:@"%@: the identifier '%@' is declared twice.", element.path, identifier]];
		}
		[identifiers addObject:identifier];
	}
	for (NSString *attribute in @[@"ref", @"format", @"tracking", @"dataLocator", @"projectRef"]) {
		NSString *xpath = [NSString stringWithFormat:@"//*[@%@]", attribute];
		for (FxGripFCPXMLElement *element in [self.rootElement elementsForXPath:xpath]) {
			NSString *reference = [element stringForAttribute:attribute];
			if (![identifiers containsObject:reference]) {
				[problems addObject:[NSString stringWithFormat:@"%@: '%@' refers to '%@', which no element declares.",
									 element.path, attribute, reference]];
			}
		}
	}
	return problems;
}

- (FxGripFCPXMLVersion)minimumVersion
{
	return self.rootElement.minimumVersion;
}

- (BOOL)validateAgainstDTDAtURL:(NSURL *)dtdURL error:(NSError **)error
{
	NSURL *url = dtdURL ?: [FxGripFinalCutPro installedDTDURLForVersion:self.version];
	if (url == nil) {
		if (error) {
			*error = FxGripFCPXMLError([NSString stringWithFormat:@"No FCPXML %@ DTD is installed.",
										FxGripFCPXMLVersionString(self.version) ?: @""]);
		}
		return NO;
	}
	NSError *dtdError = nil;
	NSXMLDTD *dtd = [[NSXMLDTD alloc] initWithContentsOfURL:url options:0 error:&dtdError];
	if (dtd == nil) {
		if (error) {
			*error = dtdError ?: FxGripFCPXMLError(@"The DTD could not be read.");
		}
		return NO;
	}
	dtd.name = FxGripFCPXMLRootName;
	NSXMLDocument *copy = [self.xmlDocument copy];
	copy.DTD = dtd;
	NSError *validationError = nil;
	BOOL valid = [copy validateAndReturnError:&validationError];
	if (!valid && error) {
		*error = validationError ?: FxGripFCPXMLError(@"The document does not match the DTD.");
	}
	return valid;
}

#pragma mark - Writing

- (NSData *)XMLData
{
	return [self.XMLString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)XMLString
{
	NSString *body = [self.xmlDocument.rootElement XMLStringWithOptions:NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement];
	return [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE fcpxml>\n%@\n", body];
}

- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error
{
	NSURL *fileURL = url;
	NSURL *bundleURL = nil;
	if ([url.pathExtension caseInsensitiveCompare:FxGripFCPXMLBundleExtension] == NSOrderedSame) {
		bundleURL = url;
		fileURL = [url URLByAppendingPathComponent:FxGripFCPXMLBundleInfoFileName];
		if (![NSFileManager.defaultManager createDirectoryAtURL:url withIntermediateDirectories:YES
													 attributes:nil error:error]) {
			return NO;
		}
	}
	if (![self.XMLData writeToURL:fileURL options:NSDataWritingAtomic error:error]) {
		return NO;
	}
	if (bundleURL != nil) {
		self.xmlDocument.URI = bundleURL.absoluteString;
	}
	return YES;
}

#pragma mark - Copying

- (id)copyWithZone:(NSZone *)zone
{
	NSXMLDocument *copy = [self.xmlDocument copy];
	return [[FxGripFCPXMLDocument alloc] initWithXMLDocument:copy error:NULL];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ resources=%lu items=%lu>", self.className,
			FxGripFCPXMLVersionString(self.version), (unsigned long)(self.hasResources ? self.resources.resources.count : 0),
			(unsigned long)self.topLevelItems.count];
}

@end
