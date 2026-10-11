/*!
	@file       FxGripFCPXMLText.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLText
	@abstract   The `text`, `text-style`, and `text-style-def` elements of titles and captions.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLText.h.
*/

#import <FxGrip/FxGripFCPXMLText.h>

#pragma mark - Text style

@implementation FxGripFCPXMLTextStyle

+ (NSString *)elementName { return @"text-style"; }
+ (NSArray<NSString *> *)elementNames { return @[@"text-style", @"text-style-def"]; }

+ (instancetype)spanWithReferenceIdentifier:(NSString *)identifier text:(NSString *)text
{
	FxGripFCPXMLTextStyle *span = [[self alloc] initWithElementName:@"text-style"];
	span.referenceIdentifier = identifier;
	span.stringValue = text;
	return span;
}

+ (instancetype)definitionWithIdentifier:(NSString *)identifier font:(NSString *)font size:(double)fontSize
{
	FxGripFCPXMLTextStyle *definition = [[self alloc] initWithElementName:@"text-style-def"];
	definition.identifier = identifier;
	definition.font = font;
	definition.fontSize = fontSize;
	return definition;
}

- (BOOL)isDefinition { return [self.name isEqualToString:@"text-style-def"]; }
- (NSString *)identifier { return [self stringForAttribute:@"id"]; }
- (void)setIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"id"]; }
- (NSString *)styleName { return [self stringForAttribute:@"name"]; }
- (void)setStyleName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSString *)referenceIdentifier { return [self.attributeElement stringForAttribute:@"ref"]; }
- (void)setReferenceIdentifier:(NSString *)identifier { [self.attributeElement setString:identifier forAttribute:@"ref"]; }

- (FxGripFCPXMLElement *)attributeElement
{
	if (!self.isDefinition) {
		return self;
	}
	return [self childNamed:@"text-style" create:YES];
}

- (NSString *)font { return [self.attributeElement stringForAttribute:@"font"]; }
- (void)setFont:(NSString *)font { [self.attributeElement setString:font forAttribute:@"font"]; }
- (double)fontSize { return [self.attributeElement doubleForAttribute:@"fontSize" defaultValue:0]; }
- (void)setFontSize:(double)fontSize { [self.attributeElement setDouble:fontSize forAttribute:@"fontSize"]; }
- (NSString *)fontFace { return [self.attributeElement stringForAttribute:@"fontFace"]; }
- (void)setFontFace:(NSString *)fontFace { [self.attributeElement setString:fontFace forAttribute:@"fontFace"]; }
- (NSArray<NSNumber *> *)fontColor { return [self.attributeElement numbersForAttribute:@"fontColor"]; }
- (void)setFontColor:(NSArray<NSNumber *> *)color { [self.attributeElement setNumbers:color forAttribute:@"fontColor"]; }
- (BOOL)bold { return [self.attributeElement boolForAttribute:@"bold" defaultValue:NO]; }
- (void)setBold:(BOOL)bold { [self.attributeElement setBool:bold forAttribute:@"bold"]; }
- (BOOL)italic { return [self.attributeElement boolForAttribute:@"italic" defaultValue:NO]; }
- (void)setItalic:(BOOL)italic { [self.attributeElement setBool:italic forAttribute:@"italic"]; }
- (NSString *)alignment { return [self.attributeElement stringForAttribute:@"alignment"]; }
- (void)setAlignment:(NSString *)alignment { [self.attributeElement setString:alignment forAttribute:@"alignment"]; }
- (NSArray<NSNumber *> *)strokeColor { return [self.attributeElement numbersForAttribute:@"strokeColor"]; }
- (void)setStrokeColor:(NSArray<NSNumber *> *)color { [self.attributeElement setNumbers:color forAttribute:@"strokeColor"]; }
- (double)strokeWidth { return [self.attributeElement doubleForAttribute:@"strokeWidth" defaultValue:0]; }
- (void)setStrokeWidth:(double)width { [self.attributeElement setDouble:width forAttribute:@"strokeWidth"]; }

@end

#pragma mark - Text

@implementation FxGripFCPXMLText

+ (NSString *)elementName { return @"text"; }

- (NSString *)plainText
{
	NSMutableString *text = [NSMutableString string];
	for (NSXMLNode *node in self.xmlElement.children) {
		if (node.kind == NSXMLTextKind) {
			[text appendString:node.stringValue ?: @""];
		} else if (node.kind == NSXMLElementKind) {
			[text appendString:node.stringValue ?: @""];
		}
	}
	return text;
}

- (NSArray<FxGripFCPXMLTextStyle *> *)spans
{
	return [self childrenNamed:@"text-style"];
}

- (NSString *)displayStyle { return [self stringForAttribute:@"display-style"]; }
- (void)setDisplayStyle:(NSString *)style { [self setString:style forAttribute:@"display-style"]; }
- (NSString *)placement { return [self stringForAttribute:@"placement"]; }
- (void)setPlacement:(NSString *)placement { [self setString:placement forAttribute:@"placement"]; }

- (void)setPlainText:(NSString *)text styleReference:(NSString *)identifier
{
	for (NSXMLNode *node in [self.xmlElement.children copy]) {
		[node detach];
	}
	if (identifier == nil) {
		self.stringValue = text;
		return;
	}
	[self addSpan:[FxGripFCPXMLTextStyle spanWithReferenceIdentifier:identifier text:text]];
}

- (void)addSpan:(FxGripFCPXMLTextStyle *)span
{
	[self addChild:span];
}

@end
