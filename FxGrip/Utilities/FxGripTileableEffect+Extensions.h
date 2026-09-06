/*!
	@file       FxGripTileableEffect+Extensions.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+Extensions
	@abstract   The category that installs and looks up an effect's FxGrip extensions.
	@discussion Introduced in FxGrip 0.1.0. The category builds the extension dictionary during
	            setup by loading the effect's declared extensions, ordering them by load priority,
	            and giving each one its load callback. It provides lookup by protocol, class, and
	            key, in single-result and all-results forms, and flushes the extensions through a
	            notification.
*/

#ifndef FxGripTileableEffect_Extensions_h
#define FxGripTileableEffect_Extensions_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import "FxGripParameter.h"
#import "FxGripExtension.h"
#import <BEFoundation/NSPriorityNotificationCenter.h>

#import "FxGripTileableEffect.h"

// This is the extension key for the main FxTileableEffect class if it were to implement the FxGripExtension Protocol

/*!
	@abstract	The category that lets the effect act as the base object of the FxGripExtension protocol.
	@discussion	Introduced in FxGrip 0.1.0. The effect returns itself as its own extension host.
*/
@interface FxGripTileableEffect (FxGripExtensionBase)
/*! @abstract The effect itself, as the extension's host object. */
- (nonnull id)effect;
@end





/*!
	@abstract	The category that manages the effect's extension dictionary.
	@discussion	Introduced in FxGrip 0.1.0. The category installs the extensions during setup and
				resolves them by protocol, class, or key.
*/
@interface FxGripTileableEffect (Extensions)


/*!
	@method		initializeExtensions
	@abstract	Loads, orders, and activates the effect's extensions, returning them keyed by extension key.
	@return		The extension dictionary, keyed by extension key.
	@discussion	Introduced in FxGrip 0.1.0. The extensions load in ascending load-priority order.
				Each extension receives its load callback, and an extension that reports failure and
				does not include itself when disabled is dropped. */
- (nullable NSMutableDictionary<NSString*, id<FxGripExtension>>*)initializeExtensions;

/*!
	@method		extensionsFlush
	@abstract	Posts the flush notification so extensions commit pending work.
	@return		The error an observer reports, or nil when the flush succeeds. */
- (nullable NSError*)extensionsFlush;

/*! @abstract YES when any installed extension conforms to the protocol. */
- (BOOL)hasExtensionProtocol:(Protocol * _Nullable)extensionProtocol;
/*! @abstract YES when any installed extension is a kind of the class. */
- (BOOL)hasExtensionClass:(Class _Nullable)extensionClass;
/*! @abstract YES when an extension is installed under the key. */
- (BOOL)hasExtensionKey:(NSString*_Nullable)extensionKey;


/*! @abstract The first installed extension conforming to the protocol, or nil. */
- (id<FxGripExtension>_Nullable)extensionForProtocol:(Protocol * _Nullable)extensionClass;
/*! @abstract The first installed extension that is a kind of the class, or nil. */
- (id<FxGripExtension>_Nullable)extensionForClass:(Class _Nullable)extensionClass;
/*! @abstract The extension installed under the key, or nil. */
- (id<FxGripExtension>_Nullable)extensionForKey:(NSString*_Nullable)extensionKey;

/*! @abstract Every installed extension conforming to the protocol. */
- (NSArray<id<FxGripExtension>>* _Nonnull)extensionsForProtocol:(Protocol * _Nullable)extensionClass;
/*! @abstract Every installed extension that is a kind of the class. */
- (NSArray<id<FxGripExtension>>* _Nonnull)extensionsForClass:(Class _Nullable)extensionClass;
/*! @abstract Every installed extension whose extension key matches. */
- (NSArray<id<FxGripExtension>>* _Nonnull)extensionsForKey:(NSString*_Nullable)extensionKey;

@end

#endif
