//
//  FxGripGoogleAnalytics.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripGoogleAnalytics_h
#define FxGripGoogleAnalytics_h

#import "FxExtension.h"
#import "FxTileableEffectBase.h"

#define kFxGripGoogleAnalyticsNotificationPrefix 		(@"GA")
#define kFxGripGoogleAnalyticsSelfRemovePredicate 		(@"-GA*")

@interface FxGripGoogleAnalytics : FxExtension
{
	NSMutableArray *_captureEvents;
}
@property (readwrite, copy) NSString * _Nullable measurementID;

- (nonnull NSPredicate*)addCaptureRule:(nonnull NSString*)rule outcome:(NSInteger)outcome, ...;
- (nonnull NSPredicate*)addCaptureRule:(nonnull NSString*)rule outcome:(BOOL)outcome priority:(NSInteger)priority, ...;
- (BOOL)removeCaptureRule:(nonnull NSPredicate*)predicate;
- (nonnull NSArray<NSPredicate*>*)captureRules;

- (void)extInit:(nonnull NSNotification *)notification;

@end



@interface FxTileableEffectBase (GoogleAnalytics)

@property (readonly, nullable, nonatomic) FxGripGoogleAnalytics* googleAnalytics;

/*! The Google Analytics identifier declared under the "googleanalytics" plugin property.
	A nil, empty, or "-"-prefixed value disables the telemetry extension. */
@property (readonly, nullable, nonatomic) NSString *gaIdentifier;

/*! YES when a usable gaIdentifier is declared; the loader gates the extension on this. */
@property (readonly, nonatomic) BOOL isGoogleAnalyticsInstalled;

- (nonnull FxGripGoogleAnalytics*)newGoogleAnalyticsExtension;

@end

#endif
