/*!
	@file       FxGripFCPXMLElement.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLElement
	@abstract   The typed wrapper over one FCPXML element.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLElement.h.
*/

#import <FxGrip/FxGripFCPXMLElement.h>
#import <FxGrip/FxGripFCPXMLSchema.h>
#import <FxGrip/FxGripFCPXMLTime.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

static NSMutableDictionary<NSString *, Class> *FxGripFCPXMLElementRegistry(void)
{
	static NSMutableDictionary *registry = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		registry = [NSMutableDictionary dictionary];
		// The typed classes, by class name; each registers the element names it wraps. The
		// lookup is by name so this file imports none of the subclass headers.
		NSArray<NSString *> *classNames = @[
			@"FxGripFCPXMLResources", @"FxGripFCPXMLFormat", @"FxGripFCPXMLAsset", @"FxGripFCPXMLMediaRep",
			@"FxGripFCPXMLEffect", @"FxGripFCPXMLMedia", @"FxGripFCPXMLLocator",
			@"FxGripFCPXMLParam", @"FxGripFCPXMLKeyframeAnimation", @"FxGripFCPXMLKeyframe", @"FxGripFCPXMLFade",
			@"FxGripFCPXMLFilter", @"FxGripFCPXMLFilterMask", @"FxGripFCPXMLData",
			@"FxGripFCPXMLStoryElement", @"FxGripFCPXMLMarker", @"FxGripFCPXMLMetadata",
			@"FxGripFCPXMLLibrary", @"FxGripFCPXMLEvent", @"FxGripFCPXMLProject",
			@"FxGripFCPXMLTextStyle", @"FxGripFCPXMLText",
		];
		for (NSString *className in classNames) {
			Class cls = NSClassFromString(className);
			for (NSString *name in [cls elementNames]) {
				registry[name] = cls;
			}
		}
	});
	return registry;
}

@interface FxGripFCPXMLElement ()
+ (NSString *)stringForDouble:(double)value;
@end

@implementation FxGripFCPXMLElement

#pragma mark - Creating and wrapping

+ (instancetype)elementNamed:(NSString *)name
{
	Class cls = [self classForElementNamed:name];
	return [[cls alloc] initWithElementName:name];
}

+ (instancetype)elementWithXMLElement:(NSXMLElement *)xmlElement
{
	Class cls = [self classForElementNamed:xmlElement.name];
	return [[cls alloc] initWithXMLElement:xmlElement];
}

+ (Class)classForElementNamed:(NSString *)name
{
	Class cls = name ? FxGripFCPXMLElementRegistry()[name] : nil;
	return cls ?: FxGripFCPXMLElement.class;
}

+ (void)registerClass:(Class)elementClass forElementNamed:(NSString *)name
{
	if (name.length == 0 || ![elementClass isSubclassOfClass:FxGripFCPXMLElement.class]) {
		return;
	}
	@synchronized (FxGripFCPXMLElement.class) {
		FxGripFCPXMLElementRegistry()[name] = elementClass;
	}
}

+ (NSString *)elementName
{
	return nil;
}

+ (NSArray<NSString *> *)elementNames
{
	NSString *name = [self elementName];
	return name ? @[name] : @[];
}

- (instancetype)initWithElementName:(NSString *)name
{
	self = [super init];
	if (self) {
		_xmlElement = [NSXMLElement elementWithName:name];
	}
	return self;
}

- (instancetype)initWithXMLElement:(NSXMLElement *)xmlElement
{
	self = [super init];
	if (self) {
		_xmlElement = xmlElement;
	}
	return self;
}

- (instancetype)init
{
	NSString *name = [self.class elementName];
	NSAssert(name != nil, @"%@ has no default element name; use initWithElementName:", self.class);
	return [self initWithElementName:name ?: @"element"];
}

#pragma mark - Equality

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:FxGripFCPXMLElement.class]) {
		return NO;
	}
	return ((FxGripFCPXMLElement *)object).xmlElement == self.xmlElement;
}

- (NSUInteger)hash
{
	return (NSUInteger)self.xmlElement;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@>", self.className, self.XMLString];
}

#pragma mark - Tree

- (NSString *)name
{
	return self.xmlElement.name ?: @"";
}

- (FxGripFCPXMLElement *)parent
{
	NSXMLNode *parent = self.xmlElement.parent;
	if (![parent isKindOfClass:NSXMLElement.class]) {
		return nil;
	}
	return [FxGripFCPXMLElement elementWithXMLElement:(NSXMLElement *)parent];
}

- (NSArray<FxGripFCPXMLElement *> *)children
{
	NSMutableArray *children = [NSMutableArray array];
	for (NSXMLNode *node in self.xmlElement.children) {
		if ([node isKindOfClass:NSXMLElement.class]) {
			[children addObject:[FxGripFCPXMLElement elementWithXMLElement:(NSXMLElement *)node]];
		}
	}
	return children;
}

- (FxGripFCPXMLDocument *)document
{
	NSXMLDocument *xmlDocument = self.xmlElement.rootDocument;
	return xmlDocument ? [[FxGripFCPXMLDocument alloc] initWithXMLDocument:xmlDocument error:NULL] : nil;
}

- (NSUInteger)index
{
	return self.xmlElement.parent ? self.xmlElement.index : NSNotFound;
}

- (NSString *)path
{
	return self.xmlElement.XPath ?: self.name;
}

- (NSArray *)childrenNamed:(NSString *)name
{
	NSMutableArray *children = [NSMutableArray array];
	for (NSXMLElement *node in [self.xmlElement elementsForName:name]) {
		[children addObject:[FxGripFCPXMLElement elementWithXMLElement:node]];
	}
	return children;
}

- (FxGripFCPXMLElement *)firstChildNamed:(NSString *)name
{
	NSXMLElement *node = [self.xmlElement elementsForName:name].firstObject;
	return node ? [FxGripFCPXMLElement elementWithXMLElement:node] : nil;
}

- (FxGripFCPXMLElement *)childNamed:(NSString *)name create:(BOOL)create
{
	FxGripFCPXMLElement *child = [self firstChildNamed:name];
	if (child == nil && create) {
		child = [FxGripFCPXMLElement elementNamed:name];
		[self addChild:child];
	}
	return child;
}

- (NSArray *)descendantsNamed:(NSString *)name
{
	return [self elementsForXPath:[NSString stringWithFormat:@".//%@", name]];
}

- (NSArray *)elementsForXPath:(NSString *)xpath
{
	NSArray<NSXMLNode *> *nodes = [self.xmlElement nodesForXPath:xpath error:NULL];
	NSMutableArray *elements = [NSMutableArray array];
	for (NSXMLNode *node in nodes) {
		if ([node isKindOfClass:NSXMLElement.class]) {
			[elements addObject:[FxGripFCPXMLElement elementWithXMLElement:(NSXMLElement *)node]];
		}
	}
	return elements;
}

- (void)addChild:(FxGripFCPXMLElement *)child
{
	if (child == nil) {
		return;
	}
	[child removeFromParent];
	[self.xmlElement addChild:child.xmlElement];
}

- (void)insertChild:(FxGripFCPXMLElement *)child atIndex:(NSUInteger)index
{
	if (child == nil) {
		return;
	}
	[child removeFromParent];
	NSUInteger count = self.xmlElement.childCount;
	[self.xmlElement insertChild:child.xmlElement atIndex:MIN(index, count)];
}

- (void)addChild:(FxGripFCPXMLElement *)child afterLastChildNamed:(NSString *)name
{
	NSXMLElement *last = [self.xmlElement elementsForName:name].lastObject;
	if (last == nil) {
		[self addChild:child];
		return;
	}
	[self insertChild:child atIndex:last.index + 1];
}

- (void)removeChild:(FxGripFCPXMLElement *)child
{
	if (child.xmlElement.parent == self.xmlElement) {
		[self.xmlElement removeChildAtIndex:child.xmlElement.index];
	}
}

- (void)removeChildrenNamed:(NSString *)name
{
	for (NSXMLElement *node in [[self.xmlElement elementsForName:name] copy]) {
		[self.xmlElement removeChildAtIndex:node.index];
	}
}

- (void)removeFromParent
{
	[self.xmlElement detach];
}

#pragma mark - Attributes

- (NSDictionary<NSString *, NSString *> *)attributes
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	for (NSXMLNode *attribute in self.xmlElement.attributes) {
		if (attribute.name != nil) {
			attributes[attribute.name] = attribute.stringValue ?: @"";
		}
	}
	return attributes;
}

- (NSString *)stringForAttribute:(NSString *)name
{
	return [self.xmlElement attributeForName:name].stringValue;
}

- (void)setString:(NSString *)value forAttribute:(NSString *)name
{
	if (name.length == 0) {
		return;
	}
	if (value == nil) {
		[self.xmlElement removeAttributeForName:name];
		return;
	}
	NSXMLNode *existing = [self.xmlElement attributeForName:name];
	if (existing != nil) {
		existing.stringValue = value;
		return;
	}
	[self.xmlElement addAttribute:[NSXMLNode attributeWithName:name stringValue:value]];
}

- (BOOL)hasAttribute:(NSString *)name
{
	return [self.xmlElement attributeForName:name] != nil;
}

- (void)removeAttribute:(NSString *)name
{
	[self.xmlElement removeAttributeForName:name];
}

- (BOOL)boolForAttribute:(NSString *)name defaultValue:(BOOL)defaultValue
{
	NSString *value = [self stringForAttribute:name];
	if (value == nil) {
		return defaultValue;
	}
	if ([value isEqualToString:@"1"] || [value caseInsensitiveCompare:@"true"] == NSOrderedSame) {
		return YES;
	}
	if ([value isEqualToString:@"0"] || [value caseInsensitiveCompare:@"false"] == NSOrderedSame) {
		return NO;
	}
	return defaultValue;
}

- (void)setBool:(BOOL)value forAttribute:(NSString *)name
{
	[self setString:(value ? @"1" : @"0") forAttribute:name];
}

- (NSInteger)integerForAttribute:(NSString *)name defaultValue:(NSInteger)defaultValue
{
	NSString *value = [self stringForAttribute:name];
	if (value == nil) {
		return defaultValue;
	}
	NSScanner *scanner = [NSScanner scannerWithString:value];
	NSInteger result = 0;
	if ([scanner scanInteger:&result] && scanner.isAtEnd) {
		return result;
	}
	return defaultValue;
}

- (void)setInteger:(NSInteger)value forAttribute:(NSString *)name
{
	[self setString:[NSString stringWithFormat:@"%ld", (long)value] forAttribute:name];
}

- (double)doubleForAttribute:(NSString *)name defaultValue:(double)defaultValue
{
	NSString *value = [self stringForAttribute:name];
	if (value == nil) {
		return defaultValue;
	}
	NSScanner *scanner = [NSScanner scannerWithString:value];
	scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	double result = 0;
	if ([scanner scanDouble:&result] && scanner.isAtEnd) {
		return result;
	}
	return defaultValue;
}

- (void)setDouble:(double)value forAttribute:(NSString *)name
{
	[self setString:[FxGripFCPXMLElement stringForDouble:value] forAttribute:name];
}

+ (NSString *)stringForDouble:(double)value
{
	if (value == (double)(long long)value && fabs(value) < 1e15) {
		return [NSString stringWithFormat:@"%lld", (long long)value];
	}
	return [NSString stringWithFormat:@"%.15g", value];
}

- (CMTime)timeForAttribute:(NSString *)name
{
	return [FxGripFCPXMLTime timeFromString:[self stringForAttribute:name]];
}

- (void)setTime:(CMTime)time forAttribute:(NSString *)name
{
	[self setString:[FxGripFCPXMLTime stringFromTime:time] forAttribute:name];
}

- (NSArray<NSNumber *> *)numbersForAttribute:(NSString *)name
{
	NSString *value = [self stringForAttribute:name];
	if (value == nil) {
		return @[];
	}
	NSMutableArray *numbers = [NSMutableArray array];
	NSLocale *posix = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	for (NSString *token in [value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]) {
		if (token.length == 0) {
			continue;
		}
		NSScanner *scanner = [NSScanner scannerWithString:token];
		scanner.locale = posix;
		double number = 0;
		if ([scanner scanDouble:&number] && scanner.isAtEnd) {
			[numbers addObject:@(number)];
		} else {
			return @[];
		}
	}
	return numbers;
}

- (void)setNumbers:(NSArray<NSNumber *> *)numbers forAttribute:(NSString *)name
{
	if (numbers.count == 0) {
		[self removeAttribute:name];
		return;
	}
	NSMutableArray *tokens = [NSMutableArray arrayWithCapacity:numbers.count];
	for (NSNumber *number in numbers) {
		[tokens addObject:[FxGripFCPXMLElement stringForDouble:number.doubleValue]];
	}
	[self setString:[tokens componentsJoinedByString:@" "] forAttribute:name];
}

#pragma mark - Content

- (NSString *)stringValue
{
	NSMutableString *text = nil;
	for (NSXMLNode *node in self.xmlElement.children) {
		if (node.kind == NSXMLTextKind) {
			if (text == nil) {
				text = [NSMutableString string];
			}
			[text appendString:node.stringValue ?: @""];
		}
	}
	return text;
}

- (void)setStringValue:(NSString *)stringValue
{
	for (NSXMLNode *node in [self.xmlElement.children copy]) {
		if (node.kind == NSXMLTextKind) {
			[node detach];
		}
	}
	if (stringValue != nil) {
		[self.xmlElement insertChild:[NSXMLNode textWithStringValue:stringValue] atIndex:0];
	}
}

#pragma mark - Schema and validation

- (FxGripFCPXMLSchemaElement *)schemaElement
{
	return [FxGripFCPXMLSchema.sharedSchema elementNamed:self.name];
}

- (NSArray<NSString *> *)validationProblemsForVersion:(FxGripFCPXMLVersion)version recursive:(BOOL)recursive
{
	NSMutableArray<NSString *> *problems = [NSMutableArray array];
	NSString *path = self.path;
	FxGripFCPXMLSchemaElement *schema = self.schemaElement;
	NSString *versionString = FxGripFCPXMLVersionString(version) ?: @"?";
	if (schema == nil) {
		[problems addObject:[NSString stringWithFormat:@"%@: the element '%@' is not an FCPXML element.", path, self.name]];
	} else if (![schema isAvailableInVersion:version]) {
		[problems addObject:[NSString stringWithFormat:@"%@: the element '%@' is not in FCPXML %@.", path, self.name, versionString]];
	} else {
		NSDictionary<NSString *, NSString *> *attributes = self.attributes;
		for (NSString *name in [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
			FxGripFCPXMLSchemaAttribute *attribute = [schema attributeNamed:name];
			if (attribute == nil) {
				[problems addObject:[NSString stringWithFormat:@"%@: the attribute '%@' is not defined for '%@'.", path, name, self.name]];
			} else if (![attribute isAvailableInVersion:version]) {
				[problems addObject:[NSString stringWithFormat:@"%@: the attribute '%@' is not in FCPXML %@.", path, name, versionString]];
			} else if (![attribute acceptsValue:attributes[name]]) {
				[problems addObject:[NSString stringWithFormat:@"%@: the attribute '%@' does not accept '%@'.", path, name, attributes[name]]];
			}
		}
		for (NSString *name in schema.requiredAttributeNames) {
			if (attributes[name] == nil && [[schema attributeNamed:name] isAvailableInVersion:version]) {
				[problems addObject:[NSString stringWithFormat:@"%@: the required attribute '%@' is missing.", path, name]];
			}
		}
		for (FxGripFCPXMLElement *child in self.children) {
			if (![schema allowsChildNamed:child.name]) {
				[problems addObject:[NSString stringWithFormat:@"%@: '%@' does not allow a '%@' child.", path, self.name, child.name]];
			}
		}
	}
	if (recursive) {
		for (FxGripFCPXMLElement *child in self.children) {
			[problems addObjectsFromArray:[child validationProblemsForVersion:version recursive:YES]];
		}
	}
	return problems;
}

- (FxGripFCPXMLVersion)minimumVersion
{
	FxGripFCPXMLSchema *schema = FxGripFCPXMLSchema.sharedSchema;
	FxGripFCPXMLVersion minimum = [schema minimumVersionForElementNamed:self.name attributeNamed:nil];
	if (!FxGripFCPXMLVersionIsValid(minimum)) {
		return FxGripFCPXMLVersionInvalid;
	}
	for (NSString *attribute in self.attributes) {
		FxGripFCPXMLVersion attributeVersion = [schema minimumVersionForElementNamed:self.name attributeNamed:attribute];
		if (!FxGripFCPXMLVersionIsValid(attributeVersion)) {
			return FxGripFCPXMLVersionInvalid;
		}
		if (FxGripFCPXMLVersionCompare(attributeVersion, minimum) == NSOrderedDescending) {
			minimum = attributeVersion;
		}
	}
	for (FxGripFCPXMLElement *child in self.children) {
		FxGripFCPXMLVersion childVersion = child.minimumVersion;
		if (!FxGripFCPXMLVersionIsValid(childVersion)) {
			return FxGripFCPXMLVersionInvalid;
		}
		if (FxGripFCPXMLVersionCompare(childVersion, minimum) == NSOrderedDescending) {
			minimum = childVersion;
		}
	}
	return minimum;
}

#pragma mark - Serialization

- (NSString *)XMLString
{
	return [self.xmlElement XMLStringWithOptions:NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement];
}

- (id)copyWithZone:(NSZone *)zone
{
	NSXMLElement *copy = [self.xmlElement copy];
	return [[self.class alloc] initWithXMLElement:copy];
}

@end
