/*!
	@file       FxTaggedMenuEntry.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-16
	@header     FxTaggedMenuEntry
	@abstract   Test-only implementation of FxPlug's FxTaggedMenuEntry.
	@discussion Introduced in FxGrip 0.1.0. Implements the interface Apple declares in
	            FxParameterAPI.h: an immutable menu item name and tag. Apple's class adopts no
	            protocols, so the stand-in adds no coding, copying, or equality.
*/

#import "FxPlugStub.h"

@implementation FxTaggedMenuEntry
{
	NSString *_menuItemName;
	NSUInteger _tag;
}

+ (FxTaggedMenuEntry *)taggedMenuEntryWithName:(NSString *)itemName tag:(NSUInteger)tag
{
	FxTaggedMenuEntry *entry = [[self alloc] init];
	entry->_menuItemName = [itemName copy];
	entry->_tag = tag;
	return entry;
}

- (NSString *)menuItemName
{
	return _menuItemName;
}

- (NSUInteger)tag
{
	return _tag;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p name=%@ tag=%lu>", self.className, self, _menuItemName, (unsigned long)_tag];
}

@end
