/*!
	@file       FxGripFCPXMLLibrary.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLLibrary
	@abstract   The `library`, `event`, and `project` elements.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLLibrary.h.
*/

#import <FxGrip/FxGripFCPXMLLibrary.h>

#pragma mark - Project

@implementation FxGripFCPXMLProject

+ (NSString *)elementName { return @"project"; }

+ (instancetype)projectWithName:(NSString *)name sequence:(FxGripFCPXMLStoryElement *)sequence
{
	FxGripFCPXMLProject *project = [[self alloc] init];
	project.projectName = name;
	[project setSequence:sequence];
	return project;
}

- (NSString *)projectName { return [self stringForAttribute:@"name"]; }
- (void)setProjectName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSString *)uid { return [self stringForAttribute:@"uid"]; }
- (void)setUid:(NSString *)uid { [self setString:uid forAttribute:@"uid"]; }
- (NSString *)identifier { return [self stringForAttribute:@"id"]; }
- (void)setIdentifier:(NSString *)identifier { [self setString:identifier forAttribute:@"id"]; }
- (NSString *)modificationDate { return [self stringForAttribute:@"modDate"]; }
- (void)setModificationDate:(NSString *)date { [self setString:date forAttribute:@"modDate"]; }

- (FxGripFCPXMLStoryElement *)sequence
{
	return [self firstChildNamed:@"sequence"];
}

- (void)setSequence:(FxGripFCPXMLStoryElement *)sequence
{
	[self removeChildrenNamed:@"sequence"];
	if (sequence != nil) {
		[self addChild:sequence];
	}
}

@end

#pragma mark - Event

@implementation FxGripFCPXMLEvent

+ (NSString *)elementName { return @"event"; }

+ (instancetype)eventWithName:(NSString *)name
{
	FxGripFCPXMLEvent *event = [[self alloc] init];
	event.eventName = name;
	return event;
}

- (NSString *)eventName { return [self stringForAttribute:@"name"]; }
- (void)setEventName:(NSString *)name { [self setString:name forAttribute:@"name"]; }
- (NSString *)uid { return [self stringForAttribute:@"uid"]; }
- (void)setUid:(NSString *)uid { [self setString:uid forAttribute:@"uid"]; }

- (NSArray<FxGripFCPXMLProject *> *)projects
{
	return [self childrenNamed:@"project"];
}

- (NSArray<FxGripFCPXMLStoryElement *> *)clips
{
	NSMutableArray *clips = [NSMutableArray array];
	for (FxGripFCPXMLElement *child in self.children) {
		if ([child isKindOfClass:FxGripFCPXMLStoryElement.class]) {
			[clips addObject:child];
		}
	}
	return clips;
}

- (NSArray<FxGripFCPXMLElement *> *)items
{
	return self.children;
}

- (void)addItem:(FxGripFCPXMLElement *)item
{
	[self addChild:item];
}

@end

#pragma mark - Library

@implementation FxGripFCPXMLLibrary

+ (NSString *)elementName { return @"library"; }

- (NSString *)location { return [self stringForAttribute:@"location"]; }
- (void)setLocation:(NSString *)location { [self setString:location forAttribute:@"location"]; }
- (NSString *)colorProcessing { return [self stringForAttribute:@"colorProcessing"]; }
- (void)setColorProcessing:(NSString *)value { [self setString:value forAttribute:@"colorProcessing"]; }

- (NSArray<FxGripFCPXMLEvent *> *)events
{
	return [self childrenNamed:@"event"];
}

- (FxGripFCPXMLEvent *)eventNamed:(NSString *)name
{
	for (FxGripFCPXMLEvent *event in self.events) {
		if ([event.eventName isEqualToString:name]) {
			return event;
		}
	}
	return nil;
}

- (void)addEvent:(FxGripFCPXMLEvent *)event
{
	[self addChild:event afterLastChildNamed:@"event"];
}

- (FxGripFCPXMLEvent *)firstEventCreatingIfNeeded
{
	FxGripFCPXMLEvent *event = self.events.firstObject;
	if (event == nil) {
		event = [FxGripFCPXMLEvent eventWithName:nil];
		[self addEvent:event];
	}
	return event;
}

@end
