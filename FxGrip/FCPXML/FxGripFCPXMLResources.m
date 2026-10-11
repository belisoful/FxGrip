/*!
	@file       FxGripFCPXMLResources.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLResources
	@abstract   The `resources` element and the resource kinds it holds.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLResources.h.
*/

#import <FxGrip/FxGripFCPXMLResources.h>

NSString *const FxGripFCPXMLEffectFxPlugUIDPrefix = @"FxPlug:";

#pragma mark - Resource

@implementation FxGripFCPXMLResource

- (NSString *)identifier { return [self stringForAttribute:@"id"]; }
- (void)setIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"id"]; }
- (NSString *)resourceName { return [self stringForAttribute:@"name"]; }
- (void)setResourceName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSString *)uid { return [self stringForAttribute:@"uid"]; }
- (void)setUid:(NSString *)uid { [self setString:uid forAttribute:@"uid"]; }

@end

#pragma mark - Format

@implementation FxGripFCPXMLFormat

+ (NSString *)elementName { return @"format"; }

+ (instancetype)formatWithFrameDuration:(CMTime)frameDuration width:(NSInteger)width height:(NSInteger)height
{
	FxGripFCPXMLFormat *format = [[self alloc] init];
	format.frameDuration = frameDuration;
	format.width = width;
	format.height = height;
	return format;
}

- (CMTime)frameDuration { return [self timeForAttribute:@"frameDuration"]; }
- (void)setFrameDuration:(CMTime)frameDuration { [self setTime:frameDuration forAttribute:@"frameDuration"]; }
- (NSInteger)width { return [self integerForAttribute:@"width" defaultValue:0]; }
- (void)setWidth:(NSInteger)width { [self setInteger:width forAttribute:@"width"]; }
- (NSInteger)height { return [self integerForAttribute:@"height" defaultValue:0]; }
- (void)setHeight:(NSInteger)height { [self setInteger:height forAttribute:@"height"]; }
- (NSString *)fieldOrder { return [self stringForAttribute:@"fieldOrder"]; }
- (void)setFieldOrder:(NSString *)fieldOrder { [self setString:fieldOrder forAttribute:@"fieldOrder"]; }
- (NSString *)colorSpace { return [self stringForAttribute:@"colorSpace"]; }
- (void)setColorSpace:(NSString *)colorSpace { [self setString:colorSpace forAttribute:@"colorSpace"]; }
- (NSInteger)pixelAspectHorizontal { return [self integerForAttribute:@"paspH" defaultValue:0]; }
- (void)setPixelAspectHorizontal:(NSInteger)value { [self setInteger:value forAttribute:@"paspH"]; }
- (NSInteger)pixelAspectVertical { return [self integerForAttribute:@"paspV" defaultValue:0]; }
- (void)setPixelAspectVertical:(NSInteger)value { [self setInteger:value forAttribute:@"paspV"]; }

@end

#pragma mark - Media rep

@implementation FxGripFCPXMLMediaRep

+ (NSString *)elementName { return @"media-rep"; }

- (NSString *)kind { return [self stringForAttribute:@"kind"]; }
- (void)setKind:(NSString *)kind { [self setString:kind forAttribute:@"kind"]; }
- (NSString *)source { return [self stringForAttribute:@"src"]; }
- (void)setSource:(NSString *)source { [self setString:source forAttribute:@"src"]; }
- (NSURL *)sourceURL { return self.source ? [NSURL URLWithString:self.source] : nil; }
- (NSString *)signature { return [self stringForAttribute:@"sig"]; }
- (void)setSignature:(NSString *)signature { [self setString:signature forAttribute:@"sig"]; }
- (NSString *)suggestedFilename { return [self stringForAttribute:@"suggestedFilename"]; }
- (void)setSuggestedFilename:(NSString *)name { [self setString:name forAttribute:@"suggestedFilename"]; }

@end

#pragma mark - Asset

@implementation FxGripFCPXMLAsset

+ (NSString *)elementName { return @"asset"; }

+ (instancetype)assetWithName:(NSString *)name fileURL:(NSURL *)fileURL
{
	FxGripFCPXMLAsset *asset = [[self alloc] init];
	asset.resourceName = name ?: fileURL.lastPathComponent;
	[asset addMediaRepOfKind:@"original-media" source:fileURL.absoluteString];
	return asset;
}

- (CMTime)start { return [self timeForAttribute:@"start"]; }
- (void)setStart:(CMTime)start { [self setTime:start forAttribute:@"start"]; }
- (CMTime)duration { return [self timeForAttribute:@"duration"]; }
- (void)setDuration:(CMTime)duration { [self setTime:duration forAttribute:@"duration"]; }
- (BOOL)hasVideo { return [self boolForAttribute:@"hasVideo" defaultValue:NO]; }
- (void)setHasVideo:(BOOL)hasVideo { [self setBool:hasVideo forAttribute:@"hasVideo"]; }
- (BOOL)hasAudio { return [self boolForAttribute:@"hasAudio" defaultValue:NO]; }
- (void)setHasAudio:(BOOL)hasAudio { [self setBool:hasAudio forAttribute:@"hasAudio"]; }
- (NSString *)formatIdentifier { return [self stringForAttribute:@"format"]; }
- (void)setFormatIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"format"]; }
- (NSInteger)audioChannels { return [self integerForAttribute:@"audioChannels" defaultValue:0]; }
- (void)setAudioChannels:(NSInteger)channels { [self setInteger:channels forAttribute:@"audioChannels"]; }
- (NSInteger)audioRate { return [self integerForAttribute:@"audioRate" defaultValue:0]; }
- (void)setAudioRate:(NSInteger)rate { [self setInteger:rate forAttribute:@"audioRate"]; }

- (NSArray<FxGripFCPXMLMediaRep *> *)mediaReps
{
	return [self childrenNamed:@"media-rep"];
}

- (FxGripFCPXMLMediaRep *)originalMediaRep
{
	for (FxGripFCPXMLMediaRep *rep in self.mediaReps) {
		if (rep.kind == nil || [rep.kind isEqualToString:@"original-media"]) {
			return rep;
		}
	}
	return nil;
}

- (FxGripFCPXMLMediaRep *)addMediaRepOfKind:(NSString *)kind source:(NSString *)source
{
	FxGripFCPXMLMediaRep *rep = [[FxGripFCPXMLMediaRep alloc] init];
	rep.kind = kind;
	rep.source = source;
	[self addChild:rep afterLastChildNamed:@"media-rep"];
	return rep;
}

@end

#pragma mark - Effect

@implementation FxGripFCPXMLEffect

+ (NSString *)elementName { return @"effect"; }

+ (instancetype)effectWithFxPlugUUID:(NSString *)pluginUUID name:(NSString *)name
{
	FxGripFCPXMLEffect *effect = [[self alloc] init];
	effect.uid = [self uidForFxPlugUUID:pluginUUID];
	effect.resourceName = name;
	return effect;
}

+ (NSString *)uidForFxPlugUUID:(NSString *)pluginUUID
{
	return [FxGripFCPXMLEffectFxPlugUIDPrefix stringByAppendingString:pluginUUID ?: @""];
}

+ (NSString *)fxPlugUUIDForUID:(NSString *)uid
{
	if (![uid hasPrefix:FxGripFCPXMLEffectFxPlugUIDPrefix]) {
		return nil;
	}
	NSString *remainder = [uid substringFromIndex:FxGripFCPXMLEffectFxPlugUIDPrefix.length];
	// Apple's own entries carry a ":preset<n>" or "_wrapper" suffix after the UUID.
	NSRange suffix = [remainder rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@":_"]];
	if (suffix.location != NSNotFound) {
		remainder = [remainder substringToIndex:suffix.location];
	}
	return remainder.length > 0 ? remainder : nil;
}

- (NSString *)source { return [self stringForAttribute:@"src"]; }
- (void)setSource:(NSString *)source { [self setString:source forAttribute:@"src"]; }
- (BOOL)isFxPlug { return [self.uid hasPrefix:FxGripFCPXMLEffectFxPlugUIDPrefix]; }
- (NSString *)fxPlugUUID { return [self.class fxPlugUUIDForUID:self.uid]; }

@end

#pragma mark - Media

@implementation FxGripFCPXMLMedia

+ (NSString *)elementName { return @"media"; }

- (NSString *)projectReference { return [self stringForAttribute:@"projectRef"]; }
- (void)setProjectReference:(NSString *)reference { [self setString:reference forAttribute:@"projectRef"]; }
- (NSString *)modificationDate { return [self stringForAttribute:@"modDate"]; }
- (void)setModificationDate:(NSString *)date { [self setString:date forAttribute:@"modDate"]; }

- (FxGripFCPXMLElement *)content
{
	return [self firstChildNamed:@"sequence"] ?: [self firstChildNamed:@"multicam"];
}

@end

#pragma mark - Locator

@implementation FxGripFCPXMLLocator

+ (NSString *)elementName { return @"locator"; }

- (NSString *)urlString { return [self stringForAttribute:@"url"]; }
- (void)setUrlString:(NSString *)urlString { [self setString:urlString forAttribute:@"url"]; }

@end

#pragma mark - Resources

@implementation FxGripFCPXMLResources

+ (NSString *)elementName { return @"resources"; }

- (NSArray *)resources
{
	NSMutableArray *resources = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child isKindOfClass:FxGripFCPXMLResource.class]) {
			[resources addObject:child];
		}
	}
	return resources;
}

- (NSArray<FxGripFCPXMLFormat *> *)formats { return [self childrenNamed:@"format"]; }
- (NSArray<FxGripFCPXMLAsset *> *)assets { return [self childrenNamed:@"asset"]; }
- (NSArray<FxGripFCPXMLEffect *> *)effects { return [self childrenNamed:@"effect"]; }
- (NSArray<FxGripFCPXMLMedia *> *)media { return [self childrenNamed:@"media"]; }
- (NSArray<FxGripFCPXMLLocator *> *)locators { return [self childrenNamed:@"locator"]; }

- (FxGripFCPXMLResource *)resourceWithIdentifier:(NSString *)identifier
{
	if (identifier == nil) {
		return nil;
	}
	for (FxGripFCPXMLResource *resource in self.resources) {
		if ([resource.identifier isEqualToString:identifier]) {
			return resource;
		}
	}
	return nil;
}

- (FxGripFCPXMLEffect *)effectWithUID:(NSString *)uid
{
	if (uid == nil) {
		return nil;
	}
	for (FxGripFCPXMLEffect *effect in self.effects) {
		if ([effect.uid isEqualToString:uid]) {
			return effect;
		}
	}
	return nil;
}

- (FxGripFCPXMLEffect *)effectWithFxPlugUUID:(NSString *)pluginUUID
{
	if (pluginUUID == nil) {
		return nil;
	}
	for (FxGripFCPXMLEffect *effect in self.effects) {
		if ([effect.fxPlugUUID caseInsensitiveCompare:pluginUUID] == NSOrderedSame) {
			return effect;
		}
	}
	return nil;
}

- (NSString *)allocateIdentifier
{
	NSMutableSet *used = [NSMutableSet set];
	for (FxGripFCPXMLResource *resource in self.resources) {
		if (resource.identifier != nil) {
			[used addObject:resource.identifier];
		}
	}
	NSUInteger number = used.count + 1;
	NSString *candidate = [NSString stringWithFormat:@"r%lu", (unsigned long)number];
	while ([used containsObject:candidate]) {
		number += 1;
		candidate = [NSString stringWithFormat:@"r%lu", (unsigned long)number];
	}
	return candidate;
}

- (NSString *)addResource:(FxGripFCPXMLResource *)resource
{
	if (resource.identifier.length == 0) {
		resource.identifier = [self allocateIdentifier];
	}
	[self addChild:resource];
	return resource.identifier;
}

- (FxGripFCPXMLEffect *)effectForFxPlugUUID:(NSString *)pluginUUID name:(NSString *)name
{
	FxGripFCPXMLEffect *effect = [self effectWithFxPlugUUID:pluginUUID];
	if (effect == nil) {
		effect = [FxGripFCPXMLEffect effectWithFxPlugUUID:pluginUUID name:name];
		[self addResource:effect];
	}
	return effect;
}

@end
