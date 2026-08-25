//
//  FxTileableEffectBase.m
//  FxTileableEffectBase
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//

#import "FxTileableEffectBase+Extensions.h"
#import "FxTileableEffectBase.h"
#import "FxTileableEffectBase+Notifications.h"
#import "FxAPINotifications.h"
#import "FxGrip_ARC.h"

NSString * _Nonnull const FxTileableEffectExtKey = @"FxTileableEffect";

@implementation FxTileableEffectBase (FxExtensionBase)

- (nonnull id)effect {
	return self;
}

@end



@implementation FxTileableEffectBase (Extensions)

- (nullable NSMutableDictionary<NSString*, id<FxExtension>>*)initializeExtensions
{
	
	NSMutableArray<id<FxExtension>> *extensions = [self loadExtensions];
	if (!extensions) {
		extensions = NSMutableArray.new;
	}
	
	[extensions sortUsingComparator:^NSComparisonResult(id<FxExtension> a, id<FxExtension> b) {
		// Compare, not subtract: a difference of two NSIntegers can overflow and flip the
		// ordering sign.
		NSInteger pa = [a ncPriority:FxTileableEffectLoadName];
		NSInteger pb = [b ncPriority:FxTileableEffectLoadName];
		if (pa < pb) { return NSOrderedAscending; }
		if (pa > pb) { return NSOrderedDescending; }
		return NSOrderedSame;
	}];
	
	NSMutableDictionary <NSString*, NSNumber*> *indices = NSMutableDictionary.new;
	[extensions filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<FxExtension> object, NSDictionary *bindings) {
		NSNumber *extIndex = indices[object.class.className];
		if (!extIndex) {
			extIndex = @0;
		}
		NSInteger objIndex = extIndex.intValue;
		extIndex = @(extIndex.intValue + 1);
		indices[object.class.className] = extIndex;
		
		if ([object respondsToSelector:@selector(extLoadWithEffect:index:)]) {
			return [object extLoadWithEffect:self index:objIndex];
		} else if ([object respondsToSelector:@selector(extLoadWithEffect:)]) {
			BOOL success = [object extLoadWithEffect:self];
			if (!success) {
				return NO;
			} else if (![object respondsToSelector:@selector(extLoadWithIndex:)]) {
				return YES;
			}
		}
		if ([object respondsToSelector:@selector(extLoadWithIndex:)]) {
			return [object extLoadWithIndex:objIndex];
		}
		return object.extActive && object.extIncludeWhenDisabled;
	}]];
	NSMutableDictionary *extensionDict = [NSMutableDictionary.alloc initWithCapacity:extensions.count];
	for(id<FxExtension> ext in extensions) {
		extensionDict[ext.extKey] = ext;
	}
	NARC_RELEASE(extensions);
	
	return [extensionDict copy];
}


- (nullable NSError*)extensionsFlush
{
	NSMutableDictionary *userInfo = @{}.mutableCopy;
	[self.notifier postNotificationName:FxTileableEffectFlushName object:self userInfo:userInfo];
	
	NSError *error = nil;
	if ((error = userInfo.fxError) && ![error isKindOfClass:NSError.class]) {
		NSLog (@"%s Error: Error returned from notification is not NSError class but got %@.", __func__, (error).className);
	}
	return error;
}



- (BOOL)hasExtensionProtocol:(nullable Protocol *)extensionProtocol
{
	for (id element in self.extensions.allValues) {
		if ([element conformsToProtocol:extensionProtocol]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)hasExtensionClass:(Class _Nullable)extensionClass
{
	for (id element in self.extensions.allValues) {
		if ([element isKindOfClass:extensionClass]) {
			return YES;
		}
	}
	return NO;
}

- (BOOL)hasExtensionKey:(NSString*_Nullable)extensionKey
{
	if (!extensionKey) {
		return NO;
	}
	return self.extensions[extensionKey] != nil;
}




- (id<FxExtension>_Nullable)extensionForProtocol:(nullable Protocol *)extensionProtocol
{
	if (!extensionProtocol)
		return nil;

	for (id element in self.extensions.allValues) {
		if ([element conformsToProtocol:extensionProtocol]) {
			return element;
		}
	}
	return nil;
}

- (id<FxExtension>_Nullable)extensionForClass:(Class _Nullable)extensionClass
{
	if (!extensionClass)
		return nil;

	for (id element in self.extensions.allValues) {
		if ([element isKindOfClass:extensionClass]) {
			return element;
		}
	}
	return nil;
}

- (id<FxExtension>_Nullable)extensionForKey:(nullable NSString *)extensionKey
{
	if (!extensionKey)
		return nil;

	return self.extensions[extensionKey];
}




// In the case of multiple extensions with the same name, maybe with different settings on each one.
- (NSArray<id<FxExtension>>* _Nonnull)extensionsForProtocol:(nullable Protocol *)extensionProtocol
{
	if (!extensionProtocol)
		return nil;
	
	NSMutableArray *results = [NSMutableArray.alloc init];
	for (id element in self.extensions.allValues) {
		if ([element conformsToProtocol:extensionProtocol]) {
			[results addObject:element];
		}
	}
	return [results copy];
}

- (NSArray<id<FxExtension>>* _Nonnull)extensionsForClass:(nullable Class)extensionClass
{
	if (!extensionClass)
		return nil;
	
	NSMutableArray *results = [NSMutableArray.alloc init];
	for (id element in self.extensions.allValues) {
		if ([element isKindOfClass:extensionClass]) {
			[results addObject:element];
		}
	}
	return [results copy];
}

- (NSArray<id<FxExtension>>* _Nonnull)extensionsForKey:(nullable NSString *)extensionKey
{
	if (!extensionKey)
		return nil;
	
	NSMutableArray *results = [NSMutableArray.alloc init];
	for (id<FxExtension> element in self.extensions.allValues) {
		if ([element.extKey compare:extensionKey] == NSOrderedSame) {
			[results addObject:element];
		}
	}
	return [results copy];
}


@end

