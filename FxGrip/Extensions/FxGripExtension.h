/*!
	@file       FxGripExtension.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripExtension
	@abstract   The base class and protocols for FxGrip effect extensions.
	@discussion Introduced in FxGrip 0.1.0. An extension is a modular unit of effect behavior that
	            observes the effect's notification stream. FxGripExtensionBase implements the
	            machinery: it holds a weak reference to the effect, a per-instance key, and a
	            notification priority, and on load it registers as an observer for every lifecycle
	            and API notification it implements a handler for. A subclass overrides the handlers
	            it needs. The effect owns its extensions and keys them by extKey.
*/

#ifndef FxGripExtension_h
#define FxGripExtension_h

#import <BEFoundation/NSPriorityNotificationCenter.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/FxGripParameter.h>
//#import "FxGripCustomParameter.h"

//#import "NSCoder+AtIndex.h"
//#import "FxGripToggleParameter.h"

// Forward declaration.
@class FxGripTileableEffect;

/*! The normal extension notification priority; -20 is highest, 20 is lowest. */
extern const NSInteger FxGripExtensionDefaultPriority;


// @todo: change to FxGripExtensionBase for consistency. and sub-types too.

/*!
	@protocol	FxGripExtensionBase
	@abstract	The functional protocol an extension implements to observe an effect.
	@discussion	Introduced in FxGrip 0.1.0. The base protocol declares the extension's identity and
				load hooks, plus the optional lifecycle and API notification handlers. An extension
				implements only the handlers it needs.
*/
@protocol FxGripExtensionBase <NSObject, NSNotificationObjectPriorityItem>

/*! YES when the extension registers its notification observers on load. */
@property (readonly, assign) BOOL 					extActive;
/*! YES when the extension stays loaded even while inactive. */
@property (readonly, assign) BOOL					extIncludeWhenDisabled;
/*!
	@property	effect
	@abstract	The effect the extension observes; nil once the effect deallocates.
	@discussion	The reference is weak. The effect owns its extensions, so a strong
				back-reference forms a retain cycle that keeps every effect instance and its
				observers alive for the process lifetime.
*/
@property (readonly, weak, nullable) id<FxGripTileableEffect>	effect;
/*! The registry key under which the effect stores the extension. */
@property (readonly, nonnull, retain) NSString *	extKey;
/*! The load index appended to extKey for instances after the first. */
@property (readonly) NSInteger 						extKeyIndex;
/*! The priority the extension returns from ncPriority: by default. */
@property (readwrite) NSInteger						extDefaultPriority;

/*! The notification priority for a name; lower numbers run first. */
- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@optional

/*!
	@method     extensionCount
	@abstract   The number of instances of this extension's class loaded in the effect.
	@discussion Counts instances of the receiver's class and its subclasses. The effect
				populates its extension list after loading completes, so the count is
				zero while the extension itself is loading.
*/
- (NSUInteger)extensionCount;

//Not a notification, but initiates all notifications
/*! Binds the extension to the effect and registers its notification observers. */
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect;
/*! Applies the load index, then binds the extension to the effect. */
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect index:(NSInteger)index;
/*! Applies the load index without binding an effect; returns extIncludeWhenDisabled. */
- (BOOL)extLoadWithIndex:(NSInteger)index;

// Lifecycle and API notification handlers. On load the base registers the extension as an
// observer for each handler below that it implements, keyed by the matching notification name.
// Each receives the posted NSNotification. An extension overrides only the handlers it needs.

//Notifications from FxTileableEffect
/*! The effect initialized. */
- (void)extInit:(nonnull NSNotification*)notification;

/*! The host asked the effect for its properties. */
- (void)extProperties:(nonnull NSNotification*)notification;
/*! The effect is adding the parameters it declared. */
- (void)extAddParameters:(nonnull NSNotification*)notification;
/*! The effect finished its initial setup. */
- (void)extFinishInitialSetup:(nonnull NSNotification*)notification;
/*! The host added the effect to a document. */
- (void)extAddedToDocument:(nonnull NSNotification*)notification;

/*! A parameter's value changed. */
- (void)extParameterChanged:(nonnull NSNotification*)notification;
/*! The user clicked a parameter. */
- (void)extParameterClicked:(nonnull NSNotification*)notification;
/*! The effect is flushing its pending writes to the host. */
- (void)extFlush:(nonnull NSNotification*)notification;

// return BOOL?  or just error?
/*! The effect is encoding its render state. */
- (void)extPluginState:(nonnull NSNotification*)notification;
/*! The effect is reporting the bounds it draws into. */
- (void)extDestinationRect:(nonnull NSNotification*)notification;
/*! The effect is reporting the source region one destination tile reads. */
- (void)extSourceRect:(nonnull NSNotification*)notification;
/*! The effect is requesting the source frames its render needs. */
- (void)extSchedule:(nonnull NSNotification*)notification;
/*! The effect is drawing a destination tile. */
- (void)extRenderDestinationImage:(nonnull NSNotification*)notification;


/*! The host removed the effect from a document. */
- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;
/*! The effect is unloading. */
- (void)extUnload:(nonnull NSNotification*)notification;

//API Notifications
//	Creation
/*! A parameter is about to be added through the creation API. Answer NO to refuse the add. */
- (BOOL)extAPIParameterAddPre:(nonnull NSNotification*)notification;
/*! A parameter was added through the creation API. */
- (void)extAPIParameterAdd:(nonnull NSNotification*)notification;
/*! A parameter group opened. */
- (void)extAPIParameterStartGroup:(nonnull NSNotification*)notification;
/*! A parameter group closed. */
- (void)extAPIParameterEndGroup:(nonnull NSNotification*)notification;

//	Dynamic
/*! A parameter was removed through the dynamic-parameter API. */
- (void)extAPIParameterRemove:(nonnull NSNotification*)notification;
/*! A parameter's name was read. */
- (void)extAPIParameterGetName:(nonnull NSNotification*)notification;
/*! A parameter's name is about to be written. */
- (void)extAPIParameterSetNamePre:(nonnull NSNotification*)notification;
/*! A parameter's name was written. */
- (void)extAPIParameterSetName:(nonnull NSNotification*)notification;
/*! A parameter's type was read. */
- (void)extAPIParameterGetType:(nonnull NSNotification*)notification;

/*! A parameter's floating-point bounds were written. */
- (void)extAPIParameterSetFloatBounds:(nonnull NSNotification*)notification;
/*! A parameter's integer bounds were written. */
- (void)extAPIParameterSetIntBounds:(nonnull NSNotification*)notification;
/*! A menu parameter's entries were read. */
- (void)extAPIParameterGetMenu:(nonnull NSNotification*)notification;
/*! A menu parameter's entries are about to be written. */
- (void)extAPIParameterSetMenuPre:(nonnull NSNotification*)notification;
/*! A menu parameter's entries were written. */
- (void)extAPIParameterSetMenu:(nonnull NSNotification*)notification;

//	Get API
/*! A parameter's flags are about to be read. An observer may serve the read from its own cache. */
- (void)extAPIParameterGetFlagsPre:(nonnull NSNotification*)notification;
/*! A parameter's flags were read. */
- (void)extAPIParameterGetFlags:(nonnull NSNotification*)notification;
/*! A parameter's string value was read. */
- (void)extAPIParameterGetStringValue:(nonnull NSNotification*)notification;

/*! A parameter's boolean value was written. */
- (void)extAPIParameterSetBool:(nonnull NSNotification*)notification;
/*! A custom parameter's value was written. */
- (void)extAPIParameterSetCustomValue:(nonnull NSNotification*)notification;
/*! A parameter's floating-point value was written. */
- (void)extAPIParameterSetFloat:(nonnull NSNotification*)notification;
/*! A histogram parameter's value was written. */
- (void)extAPIParameterSetHistogram:(nonnull NSNotification*)notification;
/*! A parameter's integer value was written. */
- (void)extAPIParameterSetInt:(nonnull NSNotification*)notification;
/*! A parameter's flags are about to be written. An observer may absorb the write into its own cache. */
- (void)extAPIParameterSetFlagsPre:(nonnull NSNotification*)notification;
/*! A parameter's flags were written. */
- (void)extAPIParameterSetFlags:(nonnull NSNotification*)notification;
/*! A parameter's path ID was written. */
- (void)extAPIParameterSetPathID:(nonnull NSNotification*)notification;
/*! A parameter's RGBA value was written. */
- (void)extAPIParameterSetRGBA:(nonnull NSNotification*)notification;
/*! A parameter's RGB value was written. */
- (void)extAPIParameterSetRGB:(nonnull NSNotification*)notification;
/*! A parameter's string value is about to be written. */
- (void)extAPIParameterSetStringValuePre:(nonnull NSNotification*)notification;
/*! A parameter's string value was written. */
- (void)extAPIParameterSetStringValue:(nonnull NSNotification*)notification;
/*! A point parameter's X and Y values were written. */
- (void)extAPIParameterSetXY:(nonnull NSNotification*)notification;

// A parameter-factory extension extends the parameter type system: map a custom type
// string to a type, and a type to the class that backs it. The effect consults every loaded
// extension when its own type map has no entry for a type string.
/*! Maps a custom type string to a parameter type, or None when unrecognized. */
- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
/*! Maps a parameter type to the class that backs it, or nil when unrecognized. */
- (nullable Class)extParameterClassForType:(FxParameterType)type;

@end



/*!
	@protocol	FxGripExtension
	@abstract	The concrete extension protocol effects require.
	@discussion	Introduced in FxGrip 0.1.0. Adds no members to FxGripExtensionBase; it names the
				concrete extension contract that FxGripExtension adopts.
*/
@protocol FxGripExtension <FxGripExtensionBase>
@end






/*!
	@class		FxGripExtensionBase
	@abstract	The base implementation an extension subclasses.
	@discussion	Introduced in FxGrip 0.1.0. Supplies the identity, priority, and load machinery. On
				load it registers as an observer for every notification whose handler the subclass
				implements. A subclass overrides the handlers it needs.
*/
@interface FxGripExtensionBase : NSObject <FxGripExtensionBase, NSNotificationObjectPriorityItem>
{
	@protected
	NSString *	_extKey;
	NSInteger	_extKeyIndex;
	BOOL		_extIncludeWhenDisabled;
}

/*! The registry key under which the effect stores the extension. */
@property (readonly, nonnull, retain) NSString *extKey;
/*! The load index appended to extKey for instances after the first. */
@property (readonly, assign) NSInteger		extKeyIndex;
/*! YES when the extension stays loaded even while inactive. */
@property (readonly, assign) BOOL			extIncludeWhenDisabled;

/*!
	@property   extIndividuate
	@abstract   Forces a per-instance extension key.
	@discussion The effect keys its extensions by `extKey`, so instances sharing a key
				replace one another. Loading appends the load index to `extKey` when the
				index is greater than zero, giving every instance of a class a distinct
				key; the first instance keeps the bare class name.

				A subclass overrides this getter to return YES when the key must carry
				the index even for the first instance.
*/
@property (readonly, assign) BOOL			extIndividuate;

/*!
	@method		init
	@abstract	Creates an unbound extension.
	@discussion	The extension takes its key from its class name and binds to an effect later,
				through `extLoadWithEffect:`.
	@return		The extension.
*/
- (nonnull instancetype)init;

/*!
	@method		setExtActive:
	@abstract	Enables or disables the extension's notification observers.
	@discussion	Introduced in FxGrip 0.1.0. Set this before the effect is added to the document.
				Changing it afterward is rejected, because the observers are registered at
				extLoadWithEffect: time based on extActive. */
- (void)setExtActive:(BOOL)active;

/*! The notification priority for a name; the base returns extDefaultPriority. */
- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@end

/*!
	@class		FxGripExtension
	@abstract	The concrete extension base that adopts the FxGripExtension protocol.
	@discussion	Introduced in FxGrip 0.1.0. Adds no members to FxGripExtensionBase; concrete
				extensions subclass this.
*/
@interface FxGripExtension : FxGripExtensionBase <FxGripExtension>
@end




#endif
