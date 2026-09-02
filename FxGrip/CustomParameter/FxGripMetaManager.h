//
//  FxGripMetaManager.h
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#ifndef FxGripMetaManager_h
#define FxGripMetaManager_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
#import "FxGripCustomDataClasses.h"

@class FxGripTileableEffect;

/*!
	@class      FxGripMetaManager
	@abstract   Stores per-parameter tags and meta values for an effect instance.
	@discussion Introduced in FxGrip 1.0. The manager is the value of the hidden custom
				parameter `kFxParameterId_InstanceMeta`. Its archive root holds two
				entries: a tag reverse index (`kFxMetaProperty_Tags`, tag string → array
				of parameter IDs) and a parameter record store
				(`kFxMetaProperty_Parameters`, parameter ID → record). Records carry
				`kFxMetaProperty_ParamId`, a `kFxMetaProperty_ParamTags` array, and a
				`kFxMetaProperty_ParamMeta` dictionary. Parameter types and flags belong
				to `FxGripParameterData`.

				Every public method locks the manager's recursive lock. Callers composing
				multi-step atomic edits use the `lock` / `lockWithinTime:` / `unlock`
				triple around their call sequence.

				Failure conditions on tag and meta methods:
				- missing record or tag container → `NSError` in domain
				  `FxGripPlugErrorDomain` (the FxPlug domain inside a host process, the
				  framework's own constant otherwise), code
				  `kFxError_ThirdPartyDeveloperStart` plus the parameter ID
				- `tagCount:` / `metaCountFromParameter:` → −1 for a missing record

				Every mutation marks the manager unsaved; `saveMeta` writes the manager
				to the host through the effect's parameter-setting API and clears the
				unsaved state.
*/
@interface FxGripMetaManager : NSObject <NSSecureCoding, NSCopying, FxGripCustomDataClasses>

@property (readonly, weak, nullable) FxGripTileableEffect *effect;
@property (readonly) BOOL unsaved;

- (nonnull instancetype)initWithEffect:(FxGripTileableEffect *_Nullable)effect;

/*!
	@method     setEffect:
	@abstract   Attaches the owning effect.
	@discussion The effect is not archived; the loader calls this after decoding.
*/
- (void)setEffect:(FxGripTileableEffect *_Nonnull)effect;

#pragma mark Record Management

/*!
	@method     addParameter:
	@abstract   Creates the record for a parameter ID.
	@discussion A record pre-seeded without `kFxMetaProperty_ParamId` is adopted and
				completed; a record that already carries an ID is rejected. Pre-seeded
				`"tags"` and `"meta"` containers are kept and promoted to their mutable
				container classes.
	@result     YES when the record is created or adopted; NO for a duplicate.
*/
- (BOOL)addParameter:(FxParameterId)parameterID;

/*!
	@method     removeParameter:
	@abstract   Removes the record and scrubs the parameter ID from the tag reverse index.
	@result     YES when the record existed.
*/
- (BOOL)removeParameter:(FxParameterId)parameterID;

- (BOOL)parameterExists:(FxParameterId)parameterID;

/*! The IDs of every parameter with a record. */
@property (readonly, nonnull) NSArray<NSNumber*> *parameterIDs;

/*!
	@method     parameterData:
	@abstract   Returns the live mutable record, not a copy.
*/
- (NSMutableDictionary *_Nullable)parameterData:(FxParameterId)parameterID;

#pragma mark Tag API

@property (readonly, nonnull) NSArray<NSString*> *tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;
- (NSArray<NSString*> *_Nullable)parameterTags:(FxParameterId)parameterID;
- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString *_Nullable)tag
			error:(NSError *_Nullable *_Nullable)error;

/*!
	@method     setTags:toParameter:
	@abstract   Replaces the parameter's tags with the supplied array.
*/
- (NSError *_Nullable)setTags:(NSArray<NSString*> *_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)addTag:(NSString *_Nullable)tag toParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)removeTag:(NSString *_Nullable)tag fromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)removeAllTags:(FxParameterId)parameterID;

/*!
	@method     parametersWithTag:
	@abstract   Returns a copy of the parameter IDs carrying the tag; nil for an unknown tag.
*/
- (NSArray<NSNumber*> *_Nullable)parametersWithTag:(NSString *_Nullable)tag;

#pragma mark Meta API

- (SInt32)metaCountFromParameter:(FxParameterId)parameterID;

/*!
	@method     getMeta:fromParameter:
	@abstract   Assigns a copy of the parameter's meta dictionary to the out-parameter.
	@result     nil on success; the failure error otherwise.
*/
- (NSError *_Nullable)getMeta:(NSDictionary *_Nullable *_Nonnull)meta fromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)setMeta:(NSDictionary *_Nonnull)meta toParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)getMetaKeys:(NSArray *_Nullable *_Nonnull)keys fromParameter:(FxParameterId)parameterID;
- (NSError *_Nullable)removeAllMeta:(FxParameterId)parameterID;
- (BOOL)parameter:(FxParameterId)parameterID hasMetaKey:(NSString *_Nonnull)key
			error:(NSError *_Nullable *_Nullable)error;

/*!
	@method     getMeta:forKey:fromParameter:
	@abstract   Reads one meta value. A nil out-pointer performs an existence check.
	@result     YES when the record and key exist.
*/
- (BOOL)getMeta:(NSObject<NSSecureCoding,NSCopying> *_Nullable *_Nullable)value
		 forKey:(NSString *_Nullable)key fromParameter:(FxParameterId)parameterID;
- (BOOL)setMeta:(NSObject<NSSecureCoding,NSCopying> *_Nonnull)value
		 forKey:(NSString *_Nullable)key toParameter:(FxParameterId)parameterID;
- (BOOL)removeMetaKey:(NSString *_Nullable)key fromParameter:(FxParameterId)parameterID;

#pragma mark Persistence

/*!
	@method     saveMeta
	@abstract   Writes the manager to the host as the InstanceMeta custom parameter value.
	@discussion Runs only when unsaved. Requires the effect's parameter-setting API; when
				the API is unavailable the manager stays unsaved and the method returns NO
				so a later flush persists the state.
	@result     YES when nothing needs saving or the write is issued.
*/
- (BOOL)saveMeta;
- (void)setUnsaved:(BOOL)unsavedValue;

#pragma mark Locking

- (BOOL)lock;

/*!
	@method     lockWithinTime:
	@abstract   Attempts the lock; `tryTime` ≤ 0 tries once, otherwise waits up to
				`tryTime` seconds.
*/
- (BOOL)lockWithinTime:(double)tryTime;
- (void)unlock;

/*!
	@method     classesForParameter
	@abstract   The secure-decode allow-list for the manager's archive contents.
*/
+ (NSOrderedSet<Class>*_Nonnull)classesForParameter;

@end

#endif /* FxGripMetaManager_h */
