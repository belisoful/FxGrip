//
//  FxGripGoogleAnalytics.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripGoogleAnalytics_h
#define FxGripGoogleAnalytics_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

/*!
	@header		FxGripGoogleAnalytics
	@abstract	The telemetry extension that maps effect notifications to Google Analytics events.
	@discussion	Introduced in FxGrip 1.0. The extension observes the effect's notification stream
				and logs a Google Analytics event for each notification that a capture rule accepts.
				Capture rules are priority-ordered predicates evaluated against the notification, and
				the default outcome is deny, so an event logs only when a rule explicitly accepts it.
				An idle latch coalesces bursts of identical events, such as those from a slider drag,
				into a single log. The Firebase classes are resolved by name at runtime, so a plugin
				that does not link Firebase still builds and runs with telemetry disabled.
*/

/*! The notification-name prefix that marks an event as Google Analytics telemetry. */
#define kFxGripGoogleAnalyticsNotificationPrefix 		(@"GA")
/*! The default rule that denies the extension's own "GA*" notifications from re-entrant logging. */
#define kFxGripGoogleAnalyticsSelfRemovePredicate 		(@"-GA*")

/*!
	@class		FxGripGoogleAnalytics
	@abstract	The extension that captures effect notifications and logs them as Google Analytics events.
	@discussion	Introduced in FxGrip 1.0. The extension holds a list of capture rules and a latch
				table keyed by event. It attaches to the effect's notifier during extInit: and
				evaluates every posted notification against the rules in priority order.
*/
@interface FxGripGoogleAnalytics : FxGripExtension
{
	NSMutableArray *_captureEvents;
	NSMutableDictionary<NSString*, NSDate*> *_lastEventDates;
}
/*!
	@property	measurementID
	@abstract	The Google Analytics measurement identifier the logger sends events under.
	@discussion	Introduced in FxGrip 1.0. A nil value disables logging while the extension keeps
				evaluating rules and updating the latch. */
@property (readwrite, copy) NSString * _Nullable measurementID;

/*!
	@property eventLatchInterval
	@abstract The idle window, in seconds, that coalesces a burst of identical events into one log.
	@discussion Introduced in FxGrip 0.1. A host fires a continuous interaction, such as a slider
		drag, as many `parameterChanged:` callbacks in quick succession. The latch logs the first
		event for a given key immediately, then suppresses further events with the same key until
		the key has been idle for this interval. The key is the notification name combined with the
		changed parameter ID when the notification carries one, so each control counts once per
		interaction. A value of 0 or less disables the latch and logs every event. Default is 0.5. */
@property (readwrite, nonatomic) NSTimeInterval eventLatchInterval;

/*!
	@method		addCaptureRule:outcome:
	@abstract	Adds a capture rule from a predicate format string at the default priority.
	@param		rule	A predicate format string evaluated against the notification.
	@param		outcome	The rule's accept or deny outcome.
	@return		The created rule, for later removal with removeCaptureRule:.
	@discussion	Introduced in FxGrip 1.0. Trailing arguments fill the format string's placeholders. */
- (nonnull NSPredicate*)addCaptureRule:(nonnull NSString*)rule outcome:(NSInteger)outcome, ...;

/*!
	@method		addCaptureRule:outcome:priority:
	@abstract	Adds a capture rule from a predicate format string at a given priority.
	@param		rule		A predicate format string evaluated against the notification.
	@param		outcome		The rule's accept or deny outcome.
	@param		priority	The evaluation priority; lower priority values are evaluated first.
	@return		The created rule, for later removal with removeCaptureRule:.
	@discussion	Introduced in FxGrip 1.0. Trailing arguments fill the format string's placeholders. */
- (nonnull NSPredicate*)addCaptureRule:(nonnull NSString*)rule outcome:(BOOL)outcome priority:(NSInteger)priority, ...;

/*!
	@method		removeCaptureRule:
	@abstract	Removes a previously added capture rule.
	@param		predicate	The rule returned by an addCaptureRule: call.
	@return		YES when the rule was present and removed; NO otherwise. */
- (BOOL)removeCaptureRule:(nonnull NSPredicate*)predicate;

/*! @abstract A copy of the current capture rules, in insertion order. */
- (nonnull NSArray<NSPredicate*>*)captureRules;

/*!
	@method		extInit:
	@abstract	Installs the default capture rules and attaches the extension to the effect's notifier.
	@param		notification	The extension-init notification the host posts.
	@discussion	Introduced in FxGrip 1.0. The default rules capture the setup and document
				lifecycle events and deny the extension's own telemetry. Firebase is configured
				by name when the FIRApp class is present. */
- (void)extInit:(nonnull NSNotification *)notification;

@end



/*!
	@class		FxGripTileableEffect (GoogleAnalytics)
	@abstract	The effect-side accessors that resolve and install the Google Analytics extension.
	@discussion	Introduced in FxGrip 1.0. The loader reads gaIdentifier from the plugin properties
				and installs the extension when isGoogleAnalyticsInstalled is YES.
*/
@interface FxGripTileableEffect (GoogleAnalytics)

/*! @abstract The installed Google Analytics extension, or nil when none is installed. */
@property (readonly, nullable, nonatomic) FxGripGoogleAnalytics* googleAnalytics;

/*! The Google Analytics identifier declared under the "googleanalytics" plugin property.
	A nil, empty, or "-"-prefixed value disables the telemetry extension. */
@property (readonly, nullable, nonatomic) NSString *gaIdentifier;

/*! YES when a usable gaIdentifier is declared; the loader gates the extension on this. */
@property (readonly, nonatomic) BOOL isGoogleAnalyticsInstalled;

/*!
	@method		newGoogleAnalyticsExtension
	@abstract	Creates the Google Analytics extension instance for this effect.
	@return		A new extension the loader installs.
	@discussion	Introduced in FxGrip 1.0. A subclass overrides this to supply a custom subclass. */
- (nonnull FxGripGoogleAnalytics*)newGoogleAnalyticsExtension;

@end

#endif
