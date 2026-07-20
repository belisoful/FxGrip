/**
 *	FxExtension.h
 */

#ifndef FxExtension_h
#define FxExtension_h

#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "FxGripTypes.h"
#import "FxParameter.h"
//#import "FxGripCustomParameter.h"

//#import "NSCoder+AtIndex.h"
//#import "FxGripToggleParameter.h"

// Forward declaration.
@class FxTileableEffectBase;



extern const NSInteger FxExtensionDefaultPriority;


// The base is the functional implementation, but not the concrete protocol.
@protocol FxExtensionBase <NSObject, NSNotificationObjectPriorityItem>

@property (readonly, assign) BOOL 					extActive;
@property (readonly, assign) BOOL					extIncludeWhenDisabled;
@property (readonly, nonnull) id<FxTileableEffectBase>	effect;
@property (readonly, nonnull, retain) NSString *	extKey;
@property (readonly) NSInteger 						extKeyIndex;
@property (readwrite) NSInteger						extDefaultPriority;

- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@optional

// How many instances of this class are in the effect
- (NSUInteger)extensionCount;

//Not a notification, but initiates all notifications
- (BOOL)extLoadWithEffect:(nonnull id<FxTileableEffectBase>)effect;
- (BOOL)extLoadWithEffect:(nonnull id<FxTileableEffectBase>)effect index:(NSInteger)index;
- (BOOL)extLoadWithIndex:(NSInteger)index;

//Notifications from FxTileableEffect
- (void)extInit:(nonnull NSNotification*)notification;

- (void)extProperties:(nonnull NSNotification*)notification;
- (void)extAddParameters:(nonnull NSNotification*)notification;
- (void)extFinishInitialSetup:(nonnull NSNotification*)notification;
- (void)extAddedToDocument:(nonnull NSNotification*)notification;

- (void)extParameterChanged:(nonnull NSNotification*)notification;
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

@end



// This is the actual concrete implementation protocol
@protocol FxExtension <FxExtensionBase>
@end






// Subclass extensions from this class to make things easier
@interface FxExtensionBase : NSObject <FxExtensionBase, NSNotificationObjectPriorityItem>
{
	@protected
	NSString *	_extKey;
	NSInteger	_extKeyIndex;
	BOOL		_extIncludeWhenDisabled;
}

@property (readonly, nonnull, retain) NSString *extKey;
@property (readonly, assign) NSInteger		extKeyIndex;
@property (readonly, assign) BOOL			extIncludeWhenDisabled;
@property (readonly, assign) BOOL			extIndividuate;

- (nullable id)init;

// Enables/disables the extension. Must be set before the effect is added to the
// document; changing it afterward is rejected (the notification observers are
// registered at extLoadWithEffect: time based on extActive).
- (void)setExtActive:(BOOL)active;

// NSNotificationObjectPriorityItem Implementation
- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@end

// The Concrete protocol version of the FxExtensionBase
@interface FxExtension : FxExtensionBase <FxExtension>
@end



/*
@interface FxGripExtensionCustomParameter : FxGripExtensionParameter <FxGripCustomParameterProtocol>

- (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull GuruFxTileableEffect *)effect;

- (id<NSSecureCoding, NSCopying> _Nullable)value;
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end




@interface FxGripExtensionToggleParameter : FxGripExtensionParameter <FxGripToggleParameterProtocol>


@end

*/

#endif
