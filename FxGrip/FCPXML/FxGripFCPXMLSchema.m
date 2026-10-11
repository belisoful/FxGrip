/*!
	@file       FxGripFCPXMLSchema.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLSchema
	@abstract   The FCPXML element and attribute schema across every format version.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLSchema.h.
*/

#import <FxGrip/FxGripFCPXMLSchema.h>
#import <FxGrip/FxGripFCPXMLTime.h>

static FxGripFCPXMLVersion FxGripFCPXMLVersionFromMinor(NSInteger minor)
{
	return minor < 0 ? FxGripFCPXMLVersionInvalid : FxGripFCPXMLVersionMake(1, minor);
}

static BOOL FxGripFCPXMLLifetimeContains(FxGripFCPXMLVersion introduced, FxGripFCPXMLVersion removed,
										 FxGripFCPXMLVersion version)
{
	if (!FxGripFCPXMLVersionIsValid(version)
		|| FxGripFCPXMLVersionCompare(version, introduced) == NSOrderedAscending) {
		return NO;
	}
	if (FxGripFCPXMLVersionIsValid(removed)
		&& FxGripFCPXMLVersionCompare(version, removed) != NSOrderedAscending) {
		return NO;
	}
	return YES;
}

#pragma mark - Attribute

@interface FxGripFCPXMLSchemaAttribute ()
- (instancetype)initWithRecord:(const FxGripFCPXMLSchemaAttributeRecord *)record;
@end

@implementation FxGripFCPXMLSchemaAttribute

- (instancetype)initWithRecord:(const FxGripFCPXMLSchemaAttributeRecord *)record
{
	self = [super init];
	if (self) {
		_name = [NSString stringWithUTF8String:record->attribute];
		_kind = record->kind;
		_required = record->required;
		_defaultValue = record->defaultValue ? [NSString stringWithUTF8String:record->defaultValue] : nil;
		_enumeratedValues = record->values
			? [[NSString stringWithUTF8String:record->values] componentsSeparatedByString:@"|"] : @[];
		_introducedIn = FxGripFCPXMLVersionFromMinor(record->introducedMinor);
		_removedIn = FxGripFCPXMLVersionFromMinor(record->removedMinor);
	}
	return self;
}

- (BOOL)isAvailableInVersion:(FxGripFCPXMLVersion)version
{
	return FxGripFCPXMLLifetimeContains(self.introducedIn, self.removedIn, version);
}

- (BOOL)acceptsValue:(NSString *)value
{
	if (value == nil) {
		return !self.required;
	}
	switch (self.kind) {
		case FxGripFCPXMLAttributeKindEnumeration:
			return [self.enumeratedValues containsObject:value];
		case FxGripFCPXMLAttributeKindTime:
			return [FxGripFCPXMLTime isTimeString:value];
		case FxGripFCPXMLAttributeKindIdentifier:
		case FxGripFCPXMLAttributeKindReference:
			return value.length > 0;
		case FxGripFCPXMLAttributeKindString:
			return YES;
	}
	return YES;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ kind=%ld required=%d>", self.className, self.name,
			(long)self.kind, self.required];
}

@end

#pragma mark - Element

@interface FxGripFCPXMLSchemaElement ()
- (instancetype)initWithRecord:(const FxGripFCPXMLSchemaElementRecord *)record
					attributes:(NSDictionary<NSString *, FxGripFCPXMLSchemaAttribute *> *)attributes;
@end

@implementation FxGripFCPXMLSchemaElement

- (instancetype)initWithRecord:(const FxGripFCPXMLSchemaElementRecord *)record
					attributes:(NSDictionary<NSString *, FxGripFCPXMLSchemaAttribute *> *)attributes
{
	self = [super init];
	if (self) {
		_name = [NSString stringWithUTF8String:record->element];
		_introducedIn = FxGripFCPXMLVersionFromMinor(record->introducedMinor);
		_removedIn = FxGripFCPXMLVersionFromMinor(record->removedMinor);
		NSString *children = [NSString stringWithUTF8String:record->children];
		NSMutableSet *names = [NSMutableSet set];
		for (NSString *child in [children componentsSeparatedByString:@" "]) {
			if (child.length > 0) {
				[names addObject:child];
			}
		}
		_childElementNames = [names copy];
		_attributes = [attributes copy];
		NSMutableArray *required = [NSMutableArray array];
		for (NSString *name in [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
			if (attributes[name].required) {
				[required addObject:name];
			}
		}
		_requiredAttributeNames = [required copy];
	}
	return self;
}

- (BOOL)isAvailableInVersion:(FxGripFCPXMLVersion)version
{
	return FxGripFCPXMLLifetimeContains(self.introducedIn, self.removedIn, version);
}

- (BOOL)allowsChildNamed:(NSString *)name
{
	return name != nil && [self.childElementNames containsObject:name];
}

- (FxGripFCPXMLSchemaAttribute *)attributeNamed:(NSString *)name
{
	return name == nil ? nil : self.attributes[name];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ since=%@ attributes=%lu>", self.className, self.name,
			FxGripFCPXMLVersionString(self.introducedIn), (unsigned long)self.attributes.count];
}

@end

#pragma mark - Schema

@interface FxGripFCPXMLSchema ()
@property (readonly, copy) NSDictionary<NSString *, FxGripFCPXMLSchemaElement *> *elements;
@end

@implementation FxGripFCPXMLSchema

+ (instancetype)sharedSchema
{
	static FxGripFCPXMLSchema *shared = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		shared = [[FxGripFCPXMLSchema alloc] init];
	});
	return shared;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		NSMutableDictionary<NSString *, NSMutableDictionary *> *attributesByElement = [NSMutableDictionary dictionary];
		for (NSUInteger index = 0; index < FxGripFCPXMLSchemaAttributeRecordCount; index++) {
			const FxGripFCPXMLSchemaAttributeRecord *record = &FxGripFCPXMLSchemaAttributeRecords[index];
			NSString *element = [NSString stringWithUTF8String:record->element];
			NSMutableDictionary *attributes = attributesByElement[element];
			if (attributes == nil) {
				attributes = [NSMutableDictionary dictionary];
				attributesByElement[element] = attributes;
			}
			FxGripFCPXMLSchemaAttribute *attribute = [[FxGripFCPXMLSchemaAttribute alloc] initWithRecord:record];
			attributes[attribute.name] = attribute;
		}
		NSMutableDictionary *elements = [NSMutableDictionary dictionary];
		for (NSUInteger index = 0; index < FxGripFCPXMLSchemaElementRecordCount; index++) {
			const FxGripFCPXMLSchemaElementRecord *record = &FxGripFCPXMLSchemaElementRecords[index];
			NSString *name = [NSString stringWithUTF8String:record->element];
			FxGripFCPXMLSchemaElement *element =
				[[FxGripFCPXMLSchemaElement alloc] initWithRecord:record attributes:attributesByElement[name] ?: @{}];
			elements[name] = element;
		}
		_elements = [elements copy];
		_elementNames = [elements.allKeys sortedArrayUsingSelector:@selector(compare:)];
	}
	return self;
}

- (FxGripFCPXMLVersion)latestVersion
{
	return FxGripFCPXMLVersionLatest();
}

- (FxGripFCPXMLVersion)earliestVersion
{
	return FxGripFCPXMLVersionEarliest;
}

- (FxGripFCPXMLSchemaElement *)elementNamed:(NSString *)name
{
	return name == nil ? nil : self.elements[name];
}

- (NSArray<NSString *> *)elementNamesAvailableInVersion:(FxGripFCPXMLVersion)version
{
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *name in self.elementNames) {
		if ([self.elements[name] isAvailableInVersion:version]) {
			[names addObject:name];
		}
	}
	return names;
}

- (NSArray<NSString *> *)elementNamesIntroducedInVersion:(FxGripFCPXMLVersion)version
{
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *name in self.elementNames) {
		if (FxGripFCPXMLVersionEqual(self.elements[name].introducedIn, version)) {
			[names addObject:name];
		}
	}
	return names;
}

- (NSArray<NSString *> *)elementNamesRemovedInVersion:(FxGripFCPXMLVersion)version
{
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *name in self.elementNames) {
		if (FxGripFCPXMLVersionEqual(self.elements[name].removedIn, version)) {
			[names addObject:name];
		}
	}
	return names;
}

- (FxGripFCPXMLVersion)minimumVersionForElementNamed:(NSString *)elementName attributeNamed:(NSString *)attributeName
{
	FxGripFCPXMLSchemaElement *element = [self elementNamed:elementName];
	if (element == nil) {
		return FxGripFCPXMLVersionInvalid;
	}
	if (attributeName == nil) {
		return element.introducedIn;
	}
	FxGripFCPXMLSchemaAttribute *attribute = [element attributeNamed:attributeName];
	return attribute ? attribute.introducedIn : FxGripFCPXMLVersionInvalid;
}

@end
