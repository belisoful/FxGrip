/*!
	@file       FxGripStoreKitRegistration.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-03
	@header     FxGripStoreKitRegistration
	@abstract   Registers the StoreKit provider when the framework loads.
	@discussion Introduced in FxGrip 0.1.0. Swift has no `+load`, so this Objective-C class registers
	            `FxGripStoreKitProvider` with `FxGripLicensing` under `storekit` as the image loads. A
	            plugin that links the framework needs no registration call of its own. The class is
	            reached through the runtime, so this file imports no FxGrip header and needs no module
	            map; every class in the image is registered with the runtime before `+load` runs.
*/

#import <Foundation/Foundation.h>
#import <objc/message.h>

@interface FxGripStoreKitRegistration : NSObject
@end

@implementation FxGripStoreKitRegistration

+ (void)load
{
	Class provider = NSClassFromString(@"FxGripStoreKitProvider");
	SEL registerSelector = NSSelectorFromString(@"register");
	if ([provider respondsToSelector:registerSelector]) {
		((void (*)(Class, SEL))objc_msgSend)(provider, registerSelector);
	}
}

@end
