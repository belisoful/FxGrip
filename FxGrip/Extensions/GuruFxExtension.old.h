/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

/**
 *	GuruFxToggle.h
 *
 *
 * @todo Debug Menu Extension
 * @todo Meta Extension
 * @todo About Menu Extension
 * @todo Google Analytics Extension
 */

#ifndef GuruFxExtension_h
#define GuruFxExtension_h

#import <GuruFxTypes.h>
#import "FxParameter.h"
#import "GuruFxCustomParameter.h"

#import "NSCoder+AtIndex.h"
#import "GuruFxToggleParameter.h"

// Forward declaration.
@class GuruFxTileableEffect;

#define kGuruFxExtensionDefaultPriority 10


// Only GuruFxTileableEffect should use this to be included as an
// extension of GuruFx.
@protocol GuruFxExtensionProtocol <NSObject>

@property (readonly) BOOL 							extActive;
@property (readonly) GuruFxTileableEffect*_Nonnull	effect;
@property (readonly) NSString*_Nonnull				extKey;
@property (readwrite) NSInteger						extDefaultPriority;

- (void)setExtActive:(BOOL)active;
- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@optional

- (BOOL)extLoadWithEffect:(GuruFxTileableEffect*_Nonnull)effect;

- (void)extInit;
- (void)extProcessParameters:(NSMutableArray<NSMutableDictionary*>*_Nonnull)parameters;
- (BOOL)extAddParameter:(nonnull id<GuruFxParameterProtocol>)parameter;
- (BOOL)extFinishInitialSetup;
- (void)extAddedToDocument;

- (FxParameterType)extGetParameterType:(FxParameterId)parameterID;

- (BOOL)extGetParameterFlags:(FxParameterFlags*_Nonnull)flags fromParameter:(FxParameterId)parameterID;
- (void)extSetParameterFlagsPre:(FxParameterFlags*_Nonnull)flags toParameter:(FxParameterId)parameterID;
- (void)extSetParameterFlags:(FxParameterFlags)flags toParameter:(FxParameterId)parameterID;

- (void)extGetParameterName:(NSString*_Nonnull*_Nonnull)name  fromParameter:(FxParameterId)parameterID;
- (void)extSetParameterNamePre:(NSString*_Nonnull*_Nonnull)name  toParameter:(FxParameterId)parameterID;
- (void)extSetParameterName:(NSString*_Nonnull)name  toParameter:(FxParameterId)parameterID;

- (void)extGetParameterStringValue:(NSString*_Nonnull*_Nonnull)value  fromParameter:(FxParameterId)parameterID;
- (void)extSetParameterStringValuePre:(NSString*_Nonnull*_Nonnull)value  toParameter:(FxParameterId)parameterID;

- (NSError*_Nullable)extGetParameterMenu:(NSArray<NSString*>*_Nullable*_Nonnull)entries fromParameter:(FxParameterId)parameterID;
- (void)extSetParameterMenuItemPre:(NSString*_Nonnull*_Nonnull)entry  toParameter:(FxParameterId)parameterID;
- (void)extSetParameterMenu:(nonnull NSArray<NSString*>*)entries defaultValue:(UInt32)defaultValue toParameter:(FxParameterId)parameterID;

- (void)extParameterChanged:(FxParameterId)paramID
							atTime:(CMTime)time
							 error:(NSError * _Nullable * _Nullable)error;


// any changs should be saved
- (void)extFlush;

- (BOOL)extRenderDestinationImage:(FxImageTile *_Nonnull)destinationImage
					 sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
					  pluginState:(id _Nullable)pluginState   //NSData or NSKeyedUnarchiver
						   atTime:(CMTime)renderTime
							error:(NSError *_Nullable *_Nullable)outError;

- (void)extRemoveParameter:(FxParameterId)parameterID;

- (void)extRemovedFromDocument;
- (void)extUnload;

- (FxParameterType)extParameterTypeForString:(nullable NSString *)typeString;
- (nullable Class)extParameterClassForType:(FxParameterType)type;

@end




// Subclass extensions from this class to make things easier
@interface GuruFxExtension : NSObject <GuruFxExtensionProtocol>

- (nullable id)init;

- (NSString*_Nonnull)extKey;
- (NSInteger)ncPriority:(NSNotificationName _Nullable)aName;

@end




@protocol GuruFxExtensionParameterProtocol <GuruFxExtensionProtocol>

- (nullable id) parameterForDictionary:(nonnull NSDictionary *)data;

@end


//This is an extension that is itself a parameter
@interface GuruFxExtensionParameter : GuruFxExtension <GuruFxParameterProtocol, GuruFxExtensionParameterProtocol>
{
	@protected
	
	BOOL					_addedToEffect;
	FxParameterId			_parameterID;
	FxParameterFlags		_parameterFlags;
	NSError*				_error;
	NSMutableDictionary*	_data;
}
- (instancetype _Nullable)init;


//GuruFxParameterLirary

#define flagMethodHeader(flagType) -(BOOL) flagType;

flagMethodHeader(flagInvalid)
flagMethodHeader(flagNoMeta)
flagMethodHeader(flagNoTags)
flagMethodHeader(flagNoState)
flagMethodHeader(flagNoDebug)
flagMethodHeader(flagInDebugMode)
flagMethodHeader(flagHiddenProxy)

flagMethodHeader(flagCache)
flagMethodHeader(flagCacheDirty)
flagMethodHeader(flagSaving)

flagMethodHeader(flagIsDefault)
flagMethodHeader(flagNotAnimatable)
flagMethodHeader(flagHidden)
flagMethodHeader(flagDisabled)
flagMethodHeader(flagCollapsed)
flagMethodHeader(flagDontSave)
flagMethodHeader(flagDontDisplay)
flagMethodHeader(flagCustomUI)
flagMethodHeader(flagIgnoreMinMax)
flagMethodHeader(flagCurveEditorHidden)
flagMethodHeader(flagDontRemapColors)
flagMethodHeader(flagUseFullViewWidth)

- (BOOL)hasState;
- (NSString*_Nonnull)parameterName;
- (void)setParameterName:(NSString*_Nonnull)name;

- (FxParameterType)parameterType NS_UNAVAILABLE;

- (FxParameterFlags)parameterAppFlags;
- (FxParameterFlags)parameterFlags;
- (void)setParameterFlags:(FxParameterFlags)flags;
- (void)setIsCaching:(BOOL)isCaching;

- (BOOL)addParameter NS_UNAVAILABLE;

- (void)parameterFlush;
- (void)createdWithFlags:(FxParameterFlags)flags parentID:(FxParameterId)parentID;
- (void)setParameterParentID:(FxParameterId)parentID;

// Coder

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder;
+ (BOOL)supportsSecureCoding;
@end




@interface GuruFxExtensionCustomParameter : GuruFxExtensionParameter <GuruFxCustomParameterProtocol>

- (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull GuruFxTileableEffect *)effect;

- (id<NSSecureCoding, NSCopying> _Nullable)value;
- (id<NSSecureCoding, NSCopying> _Nullable)valueAtTime:(CMTime)renderTime;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value;
- (void)setValue:(id<NSSecureCoding, NSCopying> _Nullable)value atTime:(CMTime)renderTime;

- (void)encodeWithCoder:(NSCoder *_Nonnull)coder;

@end




@interface GuruFxExtensionToggleParameter : GuruFxExtensionParameter <GuruFxToggleParameter>


@end



#endif
