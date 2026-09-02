/**
 *	FxGripExtension.h
 */

#ifndef FxGripExtension_h
#define FxGripExtension_h

#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTypes.h"
#import "FxParameter.h"
//#import "FxGripCustomParameter.h"

//#import "NSCoder+AtIndex.h"
//#import "FxGripToggleParameter.h"

// Forward declaration.
@class FxGripTileableEffect;



extern const NSInteger FxGripExtensionDefaultPriority;


// @todo: change to FxGripExtensionBase for consistency. and sub-types too.

// The base is the functional implementation, but not the concrete protocol.
@protocol FxGripExtensionBase <NSObject, NSNotificationObjectPriorityItem>

@property (readonly, assign) BOOL 					extActive;
@property (readonly, assign) BOOL					extIncludeWhenDisabled;
// Weak: the effect owns its extensions, so a strong back-reference forms a retain
// cycle that keeps every effect instance and its observers alive for the process
// lifetime. Nil once the effect deallocates.
@property (readonly, weak, nullable) id<FxGripTileableEffect>	effect;
@property (readonly, nonnull, retain) NSString *	extKey;
@property (readonly) NSInteger 						extKeyIndex;
@property (readwrite) NSInteger						extDefaultPriority;

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
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect;
- (BOOL)extLoadWithEffect:(nonnull id<FxGripTileableEffect>)effect index:(NSInteger)index;
- (BOOL)extLoadWithIndex:(NSInteger)index;

//Notifications from FxTileableEffect
- (void)extInit:(nonnull NSNotification*)notification;

- (void)extProperties:(nonnull NSNotification*)notification;
- (void)extAddParameters:(nonnull NSNotification*)notification;
- (void)extFinishInitialSetup:(nonnull NSNotification*)notification;
- (void)extAddedToDocument:(nonnull NSNotification*)notification;

- (void)extParameterChanged:(nonnull NSNotification*)notification;
- (void)extParameterClicked:(nonnull NSNotification*)notification;
- (void)extFlush:(nonnull NSNotification*)notification;

// return BOOL?  or just error?
- (void)extPluginState:(nonnull NSNotification*)notification;
- (void)extDestinationRect:(nonnull NSNotification*)notification;
- (void)extSourceRect:(nonnull NSNotification*)notification;
- (void)extSchedule:(nonnull NSNotification*)notification;
- (void)extRenderDestinationImage:(nonnull NSNotification*)notification;


- (void)extRemovedFromDocument:(nonnull NSNotification*)notification;
- (void)extUnload:(nonnull NSNotification*)notification;

//API Notifications
//	Creation
- (BOOL)extAPIParameterAddPre:(nonnull NSNotification*)notification;
- (void)extAPIParameterAdd:(nonnull NSNotification*)notification;
- (void)extAPIParameterStartGroup:(nonnull NSNotification*)notification;
- (void)extAPIParameterEndGroup:(nonnull NSNotification*)notification;

//	Dynamic
- (void)extAPIParameterRemove:(nonnull NSNotification*)notification;
- (void)extAPIParameterGetName:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetNamePre:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetName:(nonnull NSNotification*)notification;
- (void)extAPIParameterGetType:(nonnull NSNotification*)notification;

- (void)extAPIParameterSetFloatBounds:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetIntBounds:(nonnull NSNotification*)notification;
- (void)extAPIParameterGetMenu:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetMenuPre:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetMenu:(nonnull NSNotification*)notification;

//	Get API
- (void)extAPIParameterGetFlagsPre:(nonnull NSNotification*)notification;
- (void)extAPIParameterGetFlags:(nonnull NSNotification*)notification;
- (void)extAPIParameterGetStringValue:(nonnull NSNotification*)notification;

- (void)extAPIParameterSetBool:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetCustomValue:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetFloat:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetHistogram:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetInt:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetFlagsPre:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetFlags:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetPathID:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetRGBA:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetRGB:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetStringValuePre:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetStringValue:(nonnull NSNotification*)notification;
- (void)extAPIParameterSetXY:(nonnull NSNotification*)notification;

// A parameter-factory extension extends the parameter type system: map a custom type
// string to a type, and a type to the class that backs it. The effect consults every loaded
// extension when its own type map has no entry for a type string.
- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
- (nullable Class)extParameterClassForType:(FxParameterType)type;

@end



// This is the actual concrete implementation protocol
@protocol FxGripExtension <FxGripExtensionBase>
@end






// Subclass extensions from this class to make things easier
@interface FxGripExtensionBase : NSObject <FxGripExtensionBase, NSNotificationObjectPriorityItem>
{
	@protected
	NSString *	_extKey;
	NSInteger	_extKeyIndex;
	BOOL		_extIncludeWhenDisabled;
}

@property (readonly, nonnull, retain) NSString *extKey;
@property (readonly, assign) NSInteger		extKeyIndex;
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

- (nullable id)init;

// Enables/disables the extension. Must be set before the effect is added to the
// document; changing it afterward is rejected (the notification observers are
// registered at extLoadWithEffect: time based on extActive).
- (void)setExtActive:(BOOL)active;

// NSNotificationObjectPriorityItem Implementation
- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@end

// The Concrete protocol version of the FxGripExtensionBase
@interface FxGripExtension : FxGripExtensionBase <FxGripExtension>
@end




#endif
