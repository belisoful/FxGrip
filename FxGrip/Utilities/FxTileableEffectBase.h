//
//  Fx3DBox.h
//  Fx3DBox
//
//  Created by Apple on 1/7/20.
//  Copyright © 2020-2023 Apple, Inc. All rights reserved.
//
#ifndef FxTileableEffectBase_h
#define FxTileableEffectBase_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxParameter.h>
#import <FxGrip/FxExtension.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>

#ifndef FxParameterId
typedef UInt32 FxParameterId;
#endif

@class FxGripOOBParameterAccess;




@protocol FxTileableEffectExpanded
@property (readonly, nonnull, retain) NSString *pluginUUID;
@property (readonly, nonnull, retain) id<FxGripAPIAccessing> apiManager;
@property (readonly, nullable, assign) NSPriorityNotificationCenter *notifier;
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;

@property (assign, readonly) BOOL addedToDocument;
@property (assign, readonly) BOOL addedParameters;

@optional
	- (nullable NSError*)extensionsFlush;
@end




@protocol FxTileableEffectBase <FxTileableEffect, FxTileableEffectExpanded>

@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

@property (readonly, retain, nonnull) NSString*		defaultFontName;

- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (_Nullable id __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;


@optional
// ColorGamut category
@property (readonly, assign) FxColorPrimaries colorPrimaries;
@property (readonly, assign) BOOL isRec2020Gamut;
@property (readonly, assign) BOOL isRec709Gamut;
@property (readonly, assign) BOOL isGammaColorParameters;
@property (readonly, assign) BOOL isLinearColorParameters;


- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

// out of band
- (nonnull FxGripOOBParameterAccess *)startContext;
- (nonnull FxGripOOBParameterAccess *)startContextFlush;


//Timing
@property (readonly) CMTime frameDuration;
@property (readonly) Float64 retimingSpeed;

@property (readonly) CMTime sampleDuration;
@property (readonly) BOOL isInterlacedClip;

@property (readonly) CMTime effectStartTime;
@property (readonly) NSInteger effectStartFrame;
@property (readonly) CMTime effectStartTimeInTimeline;
@property (readonly) CMTime effectDurationTime;
@property (readonly) NSInteger effectDurationFrames;

@property (readonly) CMTime inputStartTime;
@property (readonly) NSInteger inputStartFrame;
@property (readonly) CMTime inputStartTimeInTimeline;
@property (readonly) CMTime inputDurationTime;
@property (readonly) NSInteger inputDurationFrames;

@property (readonly) CMTime effectInPointOfTimeLine;
@property (readonly) CMTime effectOutPointOfTimeLine;

@property (readonly) NSUInteger timelineFpsNumerator;
@property (readonly) NSUInteger timelineFpsDenominator;

@property (readonly) CMTime timelineFrameDuration;
@property (readonly) Float64 timelineFrameDurationFloat;
@property (readonly) CMTime timelineFrameRate;
@property (readonly) Float64 timelineFps;

- (NSInteger)frameForTime:(CMTime)time;

- (void)timelineTime:(nonnull CMTime*)timelineTime fromInputTime:(CMTime)time;
- (void)inputTime:(nonnull CMTime*)inputTime fromTimelineTime:(CMTime)time;


@end


@protocol FxTileableEffectCoderStateWeak

@optional

- (BOOL) pluginCoder:(NSCoder * _Nonnull)coder
			  atTime:(CMTime)renderTime
			 quality:(FxQuality)qualityLevel
			   error:(NSError * _Nullable * _Nullable)error;

- (BOOL)destinationImageRect:(nonnull FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> * _Null_unspecified)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable * _Null_unspecified)outError;

- (BOOL)sourceTileRect:(nonnull FxRect*)sourceTileRect
	 sourceImageIndex:(NSUInteger)sourceImageIndex
		 sourceImages:(NSArray<FxImageTile*>*_Null_unspecified)sourceImages
  destinationTileRect:(FxRect)destinationTileRect
	 destinationImage:(FxImageTile*_Null_unspecified)destinationImage
		  pluginCoder:(NSCoder * _Nonnull)pluginCoder
			   atTime:(CMTime)renderTime
				error:(NSError*_Nullable *_Null_unspecified)outError;

- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
			 withCoder:(NSCoder* _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;

- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
				   pluginCoder:(NSCoder * _Nonnull)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;
@end



@protocol FxTileableEffectCoderState <FxTileableEffectCoderStateWeak>

- (BOOL) pluginCoder:(NSCoder * _Nonnull)coder
			  atTime:(CMTime)renderTime
			 quality:(FxQuality)qualityLevel
			   error:(NSError * _Nullable * _Nullable)error;




- (BOOL)destinationImageRect:(nonnull FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *_Null_unspecified)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *_Null_unspecified)outError;

- (BOOL)sourceTileRect:(nonnull FxRect*)sourceTileRect
	 sourceImageIndex:(NSUInteger)sourceImageIndex
		 sourceImages:(NSArray<FxImageTile*>*_Null_unspecified)sourceImages
  destinationTileRect:(FxRect)destinationTileRect
	 destinationImage:(FxImageTile*_Null_unspecified)destinationImage
		  pluginCoder:(NSCoder * _Nonnull)pluginCoder
			   atTime:(CMTime)renderTime
				error:(NSError*_Nullable *_Null_unspecified)outError;


- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
				   pluginCoder:(NSCoder * _Nonnull)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;

@optional
- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder* _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;
@end





extern NSString * _Nonnull const FxTileableEffectExtKey;






@interface FxTileableEffectBase : FxExtensionBase <FxTileableEffectBase, FxTileableEffectCoderStateWeak>
{
	NSMutableDictionary<id, Class> *__typeToClassMap;
}

@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;

@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;
@property (readonly, nonnull, retain) NSDictionary<NSString*, id<FxExtension>> *extensions;
@property (readonly, nonnull, retain) NSDictionary<NSNumber*, id<FxParameter>> *parameters;

//Plugin Properties
@property (readonly, nonnull, retain) NSString*		pluginUUID;
@property (readonly) UInt64 sessionID;
//The following is from the plist, or the dynamic registration class in the plist
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;
@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

// FxPlug FxTileableEffect Properties
@property (assign, readonly) BOOL finishedProperties; // True when `-properties:error:` is called
@property (assign, readwrite, nonatomic) BOOL needsFullBuffer;
@property (assign, readwrite, nonatomic) BOOL variesWhenParamsAreStatic;
@property (assign, readwrite, nonatomic) BOOL changesOutputSize;
@property (assign, readwrite, nonatomic) FxImageColorInfo desiredProcessingColorInfo;
@property (assign, readwrite, nonatomic) BOOL mayRemapTime;
@property (assign, readwrite, nonatomic) BOOL usesNonmatchingTextureLayout;
@property (assign, readwrite, nonatomic) BOOL drawsInScreenSpace;
@property (assign, readwrite, nonatomic) FxPixelTransformSupport pixelTransformSupport;

// Stack Location
@property (assign, readonly) BOOL addingParameters;
@property (assign, readonly) BOOL addedParameters;
@property (assign, readonly) BOOL finishedSetup;
@property (assign, readonly) BOOL addedToDocument;

//	FxTileableEffect Implementation
- (BOOL) properties:(NSDictionary *_Nullable *_Null_unspecified) properties
			  error:(NSError *_Nullable *_Null_unspecified) error;

//Parameters
- (UInt32)parameterCount;
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nullable __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

// Sub-Class override implementations
@property (readonly, retain, nonnull) NSString* defaultFontName;

- (nullable NSMutableArray<id<FxExtension>>*)loadExtensions;
- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

@end




@interface FxTileableEffectBase (ConfigurationProperties)

@property (readonly) BOOL		propertiesFromConfiguration;

@end

#endif
