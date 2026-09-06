//
//  FxGripGoogleAnalytics.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripGoogleAnalytics.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTileableEffect+Notifications.h"
#import <BEFoundation/BEPredicateRule.h>
#import "FxGripTileableEffect+Extensions.h"
#import "FxGrip_ARC.h"

//@import FirebaseCore;
//@import FirebaseFirestore;
//@import FirebaseAuth;

/*!
	@header		FxGripGoogleAnalytics
	@abstract	Implements the telemetry extension that logs effect notifications to Google Analytics.
	@discussion	Introduced in FxGrip 1.0. The capture path sorts the rules by priority on first use
				after a change, evaluates each notification against them, and applies the idle latch
				before logging. Firebase is invoked by name so the framework carries no link-time
				dependency on it.
*/

@interface FxGripGoogleAnalytics ()
{
	// Cleared when a rule is added; the capture path re-sorts by priority only while set.
	BOOL _captureRulesSorted;
}
@end

/*!
	@class		FxGripGoogleAnalytics
	@abstract	The extension that captures effect notifications and logs them as Google Analytics events.
	@discussion	Introduced in FxGrip 1.0. Rules are sorted by priority on demand, evaluated deny-by-default,
				and the accepted events pass through the idle latch before Firebase logs them.
*/
@implementation FxGripGoogleAnalytics

- (id)init
{
	self = [super init];
	if (self) {
		_captureEvents = NARC_RETAIN(NSMutableArray.new);
		_captureRulesSorted = YES;
		_lastEventDates = NARC_RETAIN(NSMutableDictionary.new);
		_eventLatchInterval = 0.5;
		_measurementID = nil;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_captureEvents);
	NARC_RELEASE(_lastEventDates);

	SUPER_DEALLOC();
}


/*! @abstract Adds a name-matching capture rule at the default priority. */
- (NSPredicate*)addCaptureEvent:(nonnull NSNotificationName)name
{
	return [self addCaptureEvent:name priority:0];
}

/*!
	@method		addCaptureEvent:priority:
	@abstract	Adds a name-matching capture rule, reading the accept or deny outcome from the name.
	@discussion	Introduced in FxGrip 1.0. A leading "-" denies and a leading "+" accepts; the prefix
				is stripped before the name becomes the match pattern. A bare name accepts. */
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

/*! @abstract Adds a name-matching capture rule with an explicit outcome at the default priority. */
- (NSPredicate*)addCaptureEvent:(nonnull NSNotificationName)name outcome:(BOOL)outcome
{
	return [self addCaptureEvent:name outcome:outcome priority:0];
}

/*!
	@method		addCaptureEvent:outcome:priority:
	@abstract	Adds a rule that matches the notification name with LIKE, at a given outcome and priority.
	@return		The created rule. */
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

/*! @abstract Appends a rule and marks the rule list for re-sorting before the next evaluation. */
- (void)addCapturePredicate:(nonnull NSPredicate*)predicate
{
	[_captureEvents addObject:predicate];
	_captureRulesSorted = NO;
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



/*!
	@method		extInit:
	@abstract	Installs the default capture rules and attaches the extension to the effect's notifier.
	@discussion	Introduced in FxGrip 1.0. Firebase is configured by name when the FIRApp class is present. */
// The dispatch table wires the init notification to extInit: (with the NSNotification
// argument); a zero-argument extInit is never invoked.
- (void)extInit:(nonnull NSNotification *)notification
{
	[self addCaptureEvent:FxGripTileableEffectFinishInitialSetupName];
	[self addCaptureEvent:FxGripTileableEffectAddedToDocumentName];
	[self addCaptureEvent:FxGripTileableEffectRemovedFromDocumentName];
	
	[self addCaptureEvent:kFxGripGoogleAnalyticsSelfRemovePredicate priority:32000];
	[self addCaptureEvent:@"-FxGripNotify*" priority:32001];
	[self addCaptureEvent:@"-*" priority:32700];
	
	[self.effect.notifier addObserver:self selector:@selector(captureEvent:) name:nil object:self.effect];
	
	Class firApp = NSClassFromString(@"FIRApp");
	
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[firApp performSelector: NSSelectorFromString(@"configure")];
#pragma clang diagnostic pop
}


/*!
	@method		captureEvent:
	@abstract	Evaluates a posted notification against the capture rules and logs it when accepted.
	@discussion	Introduced in FxGrip 1.0. The rules sort by priority on first use after a change.
				The first matching rule decides the outcome, and the idle latch suppresses repeats
				before the event reaches the logger. Runs on the thread the host posts on. */
- (void)captureEvent:(NSNotification * _Nonnull)notification
{
	NSNotificationName name = notification.name;
	
	if (!name) {
		return;
	}
	
	if (!_captureRulesSorted) {
		[_captureEvents sortArrayUsingItemPriority];
		_captureRulesSorted = YES;
	}

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

	NSNumber *parameterID = notification.userInfo[FxGripTileableEffectParameterChangedIDKey];
	if (![self shouldLogEventForKey:[self latchKeyForName:name parameterID:parameterID]]) {
		return;
	}

	// track aName with UUID, and plugin name.
	//if anObject is a Parameter, send int, float, bool, color, font, click help, menu item, point, RGB/A, String
	NSMutableDictionary *parameters = [@{@"Plugin UUID": self.effect.pluginUUID,
										 @"Plugin Name": self.effect.pluginDisplayName} mutableCopy];
	if (parameterID) {
		parameters[@"Parameter ID"] = parameterID;
	}
	[self logWithName:name parameters:parameters];
}


/*! @abstract The latch key for a notification, combining name and parameter ID so each control latches once. */
- (NSString*)latchKeyForName:(nonnull NSNotificationName)name parameterID:(nullable NSNumber*)parameterID
{
	if (parameterID) {
		// A control byte separates the two components so no name can collide with a name+ID key.
		return [NSString stringWithFormat:@"%@\x01%@", name, parameterID];
	}
	return name;
}

// Leading-edge idle latch: the first event for a key logs; further events with the same key are
// suppressed until the key has been idle for eventLatchInterval. Each event refreshes the key's
// timestamp, so a continuous interaction stays latched for its whole duration and reopens only
// after the control settles. Runs on whatever thread the host posts the notification on.
- (BOOL)shouldLogEventForKey:(nonnull NSString*)key
{
	if (self.eventLatchInterval <= 0.0) {
		return YES;
	}
	@synchronized (_lastEventDates) {
		NSDate *now = NSDate.date;
		NSDate *last = _lastEventDates[key];
		BOOL idle = !last || [now timeIntervalSinceDate:last] >= self.eventLatchInterval;
		_lastEventDates[key] = now;
		return idle;
	}
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




@implementation FxGripTileableEffect (GoogleAnalytics)

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
