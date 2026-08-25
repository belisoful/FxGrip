//
//  FxGripGoogleAnalytics.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripGoogleAnalytics.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxTileableEffectBase+Notifications.h"
#import <BEFoundation/BEPredicateRule.h>
#import "FxTileableEffectBase+Extensions.h"
#import "FxGrip_ARC.h"

//@import FirebaseCore;
//@import FirebaseFirestore;
//@import FirebaseAuth;

@implementation FxGripGoogleAnalytics

- (id)init
{
	self = [super init];
	if (self) {
		_captureEvents = NARC_RETAIN(NSMutableArray.new);
		_measurementID = nil;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_captureEvents);
	
	SUPER_DEALLOC();
}


- (NSPredicate*)addCaptureEvent:(nonnull NSNotificationName)name
{
	return [self addCaptureEvent:name priority:0];
}

- (NSPredicate*)addCaptureEvent:(nonnull NSNotificationName)name priority:(NSInteger)priority
{
	BOOL outcome = YES;
	BOOL strip = [name hasPrefix:@"+"];
	if ([name hasPrefix:@"-"]) {
		outcome = NO;
		strip = YES;
	}
	if (strip) {
		name = [name substringFromIndex:1];
	}
	return [self addCaptureEvent:name outcome:outcome priority:priority];
}

- (NSPredicate*)addCaptureEvent:(nonnull NSNotificationName)name outcome:(BOOL)outcome
{
	return [self addCaptureEvent:name outcome:outcome priority:0];
}

- (BEPredicateRule *)addCaptureEvent:(nonnull NSNotificationName)name outcome:(BOOL)outcome priority:(NSInteger)priority
{
	BEPredicateRule *predicate = [BEPredicateRule ruleWithFormat:@"name LIKE %@", name];
	predicate.outcome = outcome;
	predicate.itemPriorityInteger = priority;
	[self addCapturePredicate:predicate];
	return predicate;
}

- (BEPredicateRule *)addCaptureRule:(nonnull NSString*)rule outcome:(NSInteger)outcome, ...
{
	va_list args;
	va_start(args, outcome);
	BEPredicateRule *predicate = [BEPredicateRule ruleWithFormat:rule arguments:args];
	va_end(args);
	predicate.outcome = outcome;
	[self addCapturePredicate:predicate];
	return predicate;
}
 
- (BEPredicateRule*)addCaptureRule:(nonnull NSString*)rule outcome:(BOOL)outcome priority:(NSInteger)priority, ...
{
	va_list args;
	va_start(args, priority);
	BEPredicateRule *predicate = [BEPredicateRule ruleWithFormat:rule arguments:args];
	va_end(args);
	predicate.outcome = outcome;
	predicate.itemPriorityInteger = priority;
	[self addCapturePredicate:predicate];
	return predicate;
}

- (void)addCapturePredicate:(nonnull NSPredicate*)predicate
{
	[_captureEvents addObject:predicate];
}


- (BOOL)removeCaptureRule:(nonnull NSPredicate*)predicate
{
	BOOL hasElement = [_captureEvents containsObject:predicate];
	[_captureEvents removeObject:predicate];
	return hasElement;
}

- (nonnull NSArray*)captureRules
{
	return [_captureEvents copy];
}



// The dispatch table wires the init notification to extInit: (with the NSNotification
// argument); a zero-argument extInit is never invoked.
- (void)extInit:(nonnull NSNotification *)notification
{
	[self addCaptureEvent:FxTileableEffectFinishInitialSetupName];
	[self addCaptureEvent:FxTileableEffectAddedToDocumentName];
	[self addCaptureEvent:FxTileableEffectRemovedFromDocumentName];
	
	[self addCaptureEvent:kFxGripGoogleAnalyticsSelfRemovePredicate priority:32000];
	[self addCaptureEvent:@"-FxNotify*" priority:32001];
	[self addCaptureEvent:@"-*" priority:32700];
	
	[self.effect.notifier addObserver:self selector:@selector(captureEvent:) name:nil object:self.effect];
	
	Class firApp = NSClassFromString(@"FIRApp");
	
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[firApp performSelector: NSSelectorFromString(@"configure")];
#pragma clang diagnostic pop
}


- (void)captureEvent:(NSNotification * _Nonnull)notification
{
	NSNotificationName name = notification.name;
	
	if (!name) {
		return;
	}
	
	[_captureEvents sortArrayUsingItemPriority];

	// Deny by default: an event is logged only when the first matching rule explicitly
	// accepts it. No match, or a match with any non-accept outcome, denies. This makes
	// the privacy default structural — omitting a catch-all reject rule can never
	// fail open into logging every event.
	BOOL shouldLog = NO;
	for (BEPredicateRule *predicate in _captureEvents) {
		if (![predicate evaluateWithObject:notification]) {
			continue;
		}
		shouldLog = (predicate.outcome == BEPredicateRuleAccept);
		break;
	}
	if (!shouldLog) {
		return;
	}

	// track aName with UUID, and plugin name.
	//if anObject is a Parameter, send int, float, bool, color, font, click help, menu item, point, RGB/A, String
	[self logWithName:name parameters:@{@"Plugin UUID": self.effect.pluginUUID, @"Plugin Name": self.effect.pluginDisplayName}];
}
 

- (void)logWithName:(NSString*_Nonnull)eventName parameters:(NSDictionary*)parameters
{
	if (_measurementID) {
		Class firAnalytics = NSClassFromString(@"FIRAnalytics");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[firAnalytics performSelector: NSSelectorFromString(@"logEventWithName:parameters:") withObject:eventName.copy withObject:parameters.copy];
#pragma clang diagnostic pop
	}
	
}


@end




@implementation FxTileableEffectBase (GoogleAnalytics)

- (BOOL)isGoogleAnalyticsInstalled
{
	NSString *identifier = self.gaIdentifier;
	if (!identifier || !identifier.length || [identifier hasPrefix:@"-"]) {
		return NO;
	}
	return YES;
}

- (nullable NSString*)gaIdentifier
{
	return self.pluginProperties[kProPlugPlugInX_GoogleAnalyticsProperty];;
}

- (FxGripGoogleAnalytics*)googleAnalytics
{
	return [self extensionForClass:FxGripGoogleAnalytics.class];
}


- (nonnull FxGripGoogleAnalytics*)newGoogleAnalyticsExtension
{
	return [FxGripGoogleAnalytics.alloc init];
}

@end
