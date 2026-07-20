//
//  FxGripToggle.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
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

- (void)extInit;

@end



@interface FxTileableEffectBase (GoogleAnalytics)

@property (readonly, nullable, nonatomic) FxGripGoogleAnalytics* googleAnalytics;

- (nonnull FxGripGoogleAnalytics*)newGoogleAnalyticsExtension;

@end

#endif
