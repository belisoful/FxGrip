/*!
	@file       FxGripFCPXMLFilter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLFilter
	@abstract   The `filter-video`, `filter-audio`, and `filter-video-mask` elements.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLFilter.h.
*/

#import <FxGrip/FxGripFCPXMLFilter.h>
#import <FxGrip/FxGripFCPXMLResources.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

NSString *const FxGripFCPXMLDataKeyEffectData = @"effectData";
NSString *const FxGripFCPXMLDataKeyEffectConfig = @"effectConfig";

#pragma mark - Data

@implementation FxGripFCPXMLData

+ (NSString *)elementName { return @"data"; }

+ (instancetype)dataWithKey:(NSString *)key data:(NSData *)data
{
	FxGripFCPXMLData *element = [[self alloc] init];
	element.key = key;
	element.data = data;
	return element;
}

- (NSString *)key { return [self stringForAttribute:@"key"]; }
- (void)setKey:(NSString *)key { [self setString:key forAttribute:@"key"]; }

- (NSData *)data
{
	NSString *text = self.stringValue;
	if (text == nil) {
		return nil;
	}
	return [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

- (void)setData:(NSData *)data
{
	self.stringValue = data ? [data base64EncodedStringWithOptions:0] : nil;
}

@end

#pragma mark - Filter

@implementation FxGripFCPXMLFilter

+ (NSString *)elementName { return @"filter-video"; }
+ (NSArray<NSString *> *)elementNames { return @[@"filter-video", @"filter-audio"]; }

+ (instancetype)videoFilterWithEffectIdentifier:(NSString *)identifier name:(NSString *)name
{
	FxGripFCPXMLFilter *filter = [[self alloc] initWithElementName:@"filter-video"];
	filter.effectIdentifier = identifier;
	filter.filterName = name;
	return filter;
}

+ (instancetype)audioFilterWithEffectIdentifier:(NSString *)identifier name:(NSString *)name
{
	FxGripFCPXMLFilter *filter = [[self alloc] initWithElementName:@"filter-audio"];
	filter.effectIdentifier = identifier;
	filter.filterName = name;
	return filter;
}

- (NSString *)effectIdentifier { return [self stringForAttribute:@"ref"]; }
- (void)setEffectIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"ref"]; }
- (NSString *)filterName { return [self stringForAttribute:@"name"]; }
- (void)setFilterName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSString *)nameOverride { return [self stringForAttribute:@"nameOverride"]; }
- (void)setNameOverride:(NSString *)name { [self setString:name forAttribute:@"nameOverride"]; }
- (NSString *)presetIdentifier { return [self stringForAttribute:@"presetID"]; }
- (void)setPresetIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"presetID"]; }
- (BOOL)enabled { return [self boolForAttribute:@"enabled" defaultValue:YES]; }

- (void)setEnabled:(BOOL)enabled
{
	if (enabled) {
		[self removeAttribute:@"enabled"];
	} else {
		[self setBool:NO forAttribute:@"enabled"];
	}
}

- (BOOL)isVideo { return [self.name isEqualToString:@"filter-video"]; }
- (BOOL)isAudio { return [self.name isEqualToString:@"filter-audio"]; }

- (NSArray<FxGripFCPXMLParam *> *)params { return [self childrenNamed:@"param"]; }
- (NSArray<FxGripFCPXMLData *> *)dataElements { return [self childrenNamed:@"data"]; }

- (FxGripFCPXMLParam *)paramWithKey:(NSString *)key
{
	if (key == nil) {
		return nil;
	}
	for (FxGripFCPXMLParam *param in self.params) {
		if ([param.key isEqualToString:key]) {
			return param;
		}
	}
	return nil;
}

- (FxGripFCPXMLParam *)paramNamed:(NSString *)name
{
	if (name == nil) {
		return nil;
	}
	for (FxGripFCPXMLParam *param in self.params) {
		if ([param.paramName isEqualToString:name]) {
			return param;
		}
	}
	return nil;
}

- (FxGripFCPXMLParam *)paramWithKey:(NSString *)key orName:(NSString *)name
{
	return [self paramWithKey:key] ?: [self paramNamed:name];
}

- (void)addParam:(FxGripFCPXMLParam *)param
{
	[self addChild:param];
}

- (void)removeParam:(FxGripFCPXMLParam *)param
{
	[self removeChild:param];
}

- (FxGripFCPXMLParam *)setValue:(NSString *)value forParamNamed:(NSString *)name key:(NSString *)key
{
	FxGripFCPXMLParam *param = [self paramWithKey:key orName:name];
	if (param == nil) {
		param = [FxGripFCPXMLParam paramWithName:name key:key value:nil];
		[self addParam:param];
	}
	param.value = value;
	return param;
}

- (FxGripFCPXMLData *)dataForKey:(NSString *)key
{
	for (FxGripFCPXMLData *data in self.dataElements) {
		if ([data.key isEqualToString:key]) {
			return data;
		}
	}
	return nil;
}

- (void)setData:(NSData *)data forKey:(NSString *)key
{
	FxGripFCPXMLData *element = [self dataForKey:key];
	if (data == nil) {
		[self removeChild:element];
		return;
	}
	if (element == nil) {
		element = [FxGripFCPXMLData dataWithKey:key data:data];
		// DTD order: data*, param*.
		FxGripFCPXMLElement *firstParam = [self firstChildNamed:@"param"];
		if (firstParam != nil) {
			[self insertChild:element atIndex:firstParam.xmlElement.index];
		} else {
			[self addChild:element];
		}
		return;
	}
	element.data = data;
}

- (FxGripFCPXMLEffect *)effect
{
	FxGripFCPXMLDocument *document = self.document;
	if (!document.hasResources) {
		return nil;
	}
	FxGripFCPXMLResource *resource = [document.resources resourceWithIdentifier:self.effectIdentifier];
	return [resource isKindOfClass:FxGripFCPXMLEffect.class] ? (FxGripFCPXMLEffect *)resource : nil;
}

@end

#pragma mark - Filter mask

@implementation FxGripFCPXMLFilterMask

+ (NSString *)elementName { return @"filter-video-mask"; }

- (BOOL)enabled { return [self boolForAttribute:@"enabled" defaultValue:YES]; }
- (void)setEnabled:(BOOL)enabled { [self setBool:enabled forAttribute:@"enabled"]; }
- (BOOL)inverted { return [self boolForAttribute:@"inverted" defaultValue:NO]; }
- (void)setInverted:(BOOL)inverted { [self setBool:inverted forAttribute:@"inverted"]; }

- (NSArray<FxGripFCPXMLElement *> *)masks
{
	NSMutableArray *masks = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child.name isEqualToString:@"mask-shape"] || [child.name isEqualToString:@"mask-isolation"]) {
			[masks addObject:child];
		}
	}
	return masks;
}

- (FxGripFCPXMLFilter *)innerFilter
{
	return [self childrenNamed:@"filter-video"].firstObject;
}

- (FxGripFCPXMLFilter *)outerFilter
{
	NSArray *filters = [self childrenNamed:@"filter-video"];
	return filters.count > 1 ? filters[1] : nil;
}

@end
