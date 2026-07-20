//
//  FxParameterTagsAPI_v1.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxParameterTagsAPI_v1_h
#define FxParameterTagsAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripTypes.h>
//#import <FxGrip/GuruFxMetaManager.h>

@protocol FxParameterTagsAPI_v1

// Parameter Tags

- (NSArray* _Nullable)tags;
- (SInt32)tagCount;
- (SInt32)tagCount:(FxParameterId)parameterID;

- (NSArray* _Nullable)parameterTags:(FxParameterId)parameterID;

- (BOOL)parameter:(FxParameterId)parameterID hasTag:(NSString* _Nullable)tag error:(NSError* _Nullable * _Nullable)error;
- (NSError* _Nullable)setTags:(NSArray*_Nonnull)tags toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)addTag:(NSString*_Nullable)tag toParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeTag:(NSString*_Nullable)tag fromParameter:(FxParameterId)parameterID;
- (NSError* _Nullable)removeAllTags:(FxParameterId)parameterID;
- (NSArray* _Nullable)parametersWithTag:(NSString*_Nullable)tag;

@end


#endif /* FxParameterTagsAPI_v1_h */

