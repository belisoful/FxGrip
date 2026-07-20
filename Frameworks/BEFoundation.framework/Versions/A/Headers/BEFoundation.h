//
//  BEFoundation.h
//  BEFoundation
//
//  Created by belisoful@icloud.com on 12/24/24.
//

#import <Foundation/Foundation.h>
#import <BEFoundation/BEPlatformTypes.h>

//! Project version number for BEFoundation.
FOUNDATION_EXPORT double BEFoundationVersionNumber;

//! Project version string for BEFoundation.
FOUNDATION_EXPORT const unsigned char BEFoundationVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <BEFoundation/PublicHeader.h>

#import <BEFoundation/NSNotification+ExtraProperties.h>
#import <BEFoundation/NSNotification+MutableUserInfo.h>
#import <BEFoundation/NSPriorityNotification.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>

#import <BEFoundation/BEPathControl.h>
#import <BEFoundation/BESecurityScopedURLManager.h>
#import <BEFoundation/BETabView.h>
#import <BEFoundation/BEWindowController.h>
#import <BEFoundation/BEWindowControllerManager.h>
#import <BEFoundation/NSOpenPanel+BESecurityScopedURLManager.h>

#import <BEFoundation/BECharacterSet.h>
#import <BEFoundation/BEMetalHelper.h>
#import <BEFoundation/BEMutable.h>
#import <BEFoundation/BEFileCache.h>
#import <BEFoundation/BEObjectRegistry.h>
#import <BEFoundation/BEPathWatcher.h>
#import <BEFoundation/BEPredicateRule.h>
#import <BEFoundation/BEPriorityExtensions.h>
#import <BEFoundation/BERuntime.h>
#import <BEFoundation/BESingleton.h>
#import <BEFoundation/BEStackExtensions.h>
#import <BEFoundation/BEWebData.h>
#import <BEFoundation/CIImage+BExtension.h>
#import <BEFoundation/BEColor+BExtension.h>
#import <BEFoundation/BEView+BExtension.h>
#import <BEFoundation/BEImage+BExtension.h>
#import <BEFoundation/NSPasteboard+BExtension.h>
#import <BEFoundation/FxTime.h>
#import <BEFoundation/NSArray+BExtension.h>
#import <BEFoundation/NSCoder+AtIndex.h>
#import <BEFoundation/NSCoder+HalfFloat.h>
#import <BEFoundation/NSData+URLDownload.h>
#import <BEFoundation/NSDateFormatter+RFC2822.h>
#import <BEFoundation/NSDateFormatter+RFC3339.h>
#import <BEFoundation/NSDictionary+BExtension.h>
#import <BEFoundation/NSMethodSignature+BlockSignatures.h>
#import <BEFoundation/NSMutableNumber.h>
#import <BEFoundation/NSNumber+BExtension.h>
#import <BEFoundation/NSNumber+Primes16b.h>
#import <BEFoundation/NSObject+DynamicMethods.h>
#import <BEFoundation/NSObject+GlobalRegistry.h>
#import <BEFoundation/NSObject+Macroable.h>
#import <BEFoundation/NSOrderedSet+BExtension.h>
#import <BEFoundation/NSSet+BExtension.h>
#import <BEFoundation/NSString+BExtension.h>
#import <BEFoundation/NSURL+Data.h>
