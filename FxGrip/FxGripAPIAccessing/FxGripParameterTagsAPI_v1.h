//
//  FxGripParameterCreationAPI_v5.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripParameterTagsAPI_v1_h
#define FxGripParameterTagsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import "FxParameterTagsAPI_v1.h"
#import "FxGripCommonAPI.h"

/*!
	@interface  FxGripParameterTagsAPI_v1
	@abstract   Allows your plugin to create parameters on-the-fly
	@discussion With this API your plugin can create and remove parameters outside of its
				-addParameters method. It can also get and set various properties of parameters
				during run-time, as well, such as the minimum and maximum allowable values.
				NOTE: You should only implement this protocol in plug-ins that use FxPlug 4
				or later. It will not be called in plug-ins that are written with FxPlug 2 or 3.
*/
@interface FxGripParameterTagsAPI_v1 : FxGripCommonAPI<FxParameterTagsAPI_v1>

	@property (assign, readonly) id<FxParameterTagsAPI_v1> _Nonnull api;

- (nullable instancetype)initWithAPI:(id<FxParameterTagsAPI_v1> _Nullable)api effect:(nonnull id<FxTileableEffectBase>)effect;

// Parameter Tags

- (NSArray* _Nullable)tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;

- (NSArray<NSString*>* _Nullable)parameterTags:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error;
- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)addTag:(NSString*_Nullable)label toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeTag:(NSString*_Nullable)label fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID;
- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)label;

@end


#endif /* FxGripDynamicParameterAPI_v3_h */

