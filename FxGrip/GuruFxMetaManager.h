/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  MasterFxAPIAccess.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef GuruFxMetaManager_h
#define GuruFxMetaManager_h

#import <FxPlug/FxPlugSDK.h>
#import "GuruFxTypes.h"
#import "FxCustomDataClasses.h"

// the collection of all the tags used and the parameter IDs with the tag
#define kFxMetaProperty_Tags		@"tags"
#define kFxMetaProperty_Parameters 	@"parameters"
#define kFxMetaProperty_ParamId		@"id"
#define kFxMetaProperty_ParamType	@"type"
#define kFxMetaProperty_ParamFlags	@"flags"
#define kFxMetaProperty_ParamMeta	@"meta"
#define kFxMetaProperty_ParamTargetPreset kFxParameterProperty_TargetPreset
#define kFxMetaProperty_ResetValue	kFxParameterProperty_ResetValue
#define kFxMetaProperty_ParamTags	kFxMetaProperty_Tags
#define kFxMetaProperty_ParamCustomClass	kFxParameterProperty_CustomClass
#define kFxMetaProperty_ParamCustomClasses	kFxParameterProperty_CustomClasses
// when kFxParameterFlag_CACHEDIRTY is set, the following key has the value.
#define kFxMetaProperty_ParamValue	@"value"
#define kFxMetaProperty_ParamValueTime	@"valuetime"

// The menu can target other paramater's "data", like name, or min/max, slider min/max, or value.
// NSDictionary for single, or NSArray of NSDictionary for multiple
//#define kFxMetaProperty_ParamTargets @"targets"
// a target preset sets the preset based on the menu item, has the tag.
// the target parameter id if not a preset
#define kFxMetaProperty_ParamTargetId @"id"
// list of names to set based on menu item selected
#define kFxMetaProperty_ParamTargetNames @"names"
// list of values to set based on menu item selected
#define kFxMetaProperty_ParamTargetValues @"values"
// Todo target min, max, slidermin, slider max, also.

//default set value to the parameter value
#define kFxMetaProperty_ParamTargetMetaKey @"metakey"

//if no meta values, then use values, else set to menu index
#define kFxMetaProperty_ParamTargetMetaValues @"metavalues"

@class GuruFxAPIAccessing;
@class GuruFxTileableEffect;


/*!
	@interface  GuruFxMetaManager:
	@abstract   Initializes the API manager for your plug-in.
	@discussion Accesses the apis with error checking.
 */
//@interface GuruFxMetaManager : NSMutableDictionary <NSSecureCoding, NSCopying, FxCustomDataClasses>
@interface GuruFxMetaManager : NSObject <NSSecureCoding, NSCopying, FxCustomDataClasses>
{
	BOOL			unsaved;
	GuruFxTileableEffect *effect;
	NSMutableDictionary<NSString*, NSMutableArray<NSNumber*>*>		 	*__tags; // Dictionary of tags and the parameter IDs with those tags
	NSMutableDictionary<NSNumber*, NSMutableDictionary<NSString*, id>*>	*__parameters; // Dictionary of Parameter IDs and
}
	@property(readonly) NSUInteger count;
	@property (strong, readonly) NSMutableDictionary<NSString*, NSObject*> * _Nonnull data;

	@property (assign, readonly) CFAbsoluteTime lastModified;
	@property (assign, readonly) GuruFxTileableEffect* _Nonnull effect;

- (nonnull instancetype)initWithEffect:(GuruFxTileableEffect* _Nullable)effect;
- (void)setEffect:(GuruFxTileableEffect* _Nonnull)effect;

- (BOOL)metaInstalled;

// Parameter Management
- (BOOL)addParameter:(FxParameterId)parameterID type:(FxParameterType)type flags:(FxParameterFlags)flags;
- (BOOL)addParameter:(FxParameterId)parameterID customClass:(Class _Nonnull )className flags:(FxParameterFlags)flags;
- (BOOL)removeParameter:(FxParameterId)parameterID;
- (FxParameterType)parameterType:(FxParameterId)parameterID;
- (NSMutableDictionary* _Nullable)parameterData:(FxParameterId)parameterID;

// Parameter Flags
- (BOOL)getParameterFlags:(nonnull FxParameterFlags *)flags fromParameter:(UInt32)parameterID;
- (BOOL)setParameterFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID;
- (BOOL)addFlags:(FxParameterFlags)flags toParameter:(UInt32)parameterID;
- (BOOL)removeFlags:(FxParameterFlags)flags fromParameter:(UInt32)parameterID;


- (BOOL)saveMeta;
- (void)setUnsaved:(BOOL)unsavedValue;


// Parameter Tag API
@property (assign, readonly) NSArray* _Nonnull tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;
- (NSArray* _Nullable)parameterTags:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error;
- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID;
- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag;


// Parameter Meta API

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;
- (NSError*_Nullable)getMeta:(NSDictionary*_Nullable*_Nullable)meta fromParameter:(FxParameterId)parameterID;
- (NSError*_Nullable)setMeta:(NSDictionary*_Nonnull) meta   toParameter:(FxParameterId)parameterID;
- (NSError*_Nullable)getMetaKeys:(NSArray *_Nullable*_Nullable)keys fromParameter:(FxParameterId)parameterID;
- (NSError*_Nullable)removeAllMeta:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString*_Nonnull)key error:(NSError*_Nullable*_Nullable)error;
- (BOOL)getMeta:(NSObject<NSSecureCoding,NSCopying> * _Nullable * _Nonnull)value forKey:(NSString* _Nullable)key fromParameter:(FxParameterId)parameterID;
- (BOOL)setMeta:(NSObject<NSSecureCoding,NSCopying>*_Nonnull)value forKey:(NSString*_Nullable)key toParameter:(FxParameterId)parameterID;
- (BOOL)removeMetaKey:(NSString*_Nullable)key fromParameter:(FxParameterId)parameterID;


// Meta Locking
- (BOOL)lock;
- (BOOL)lockWithinTime:(double)tryTime;
- (void)unlock;


@end


#endif /* GuruFxMetaManager_h */
