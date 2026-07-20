/// @deprecated Legacy GuruFx implementation retained only for the final merge into the
/// new FxGrip implementations. Do not modify or extend; names intentionally unchanged.

//
//  GuruFxTileableEffect.h
//  Guru subclass of FxTileableEffect
//
//  Created by ~ ~ on 2/27/24.
//

#ifndef GuruFxTileableEffect_h
#define GuruFxTileableEffect_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <GuruFxDynamicRegistrar.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import "GuruFxMetaManager.h"
#import <GuruFxTypes.h>
#import "GuruFxParameterUtility.h"
#import "GuruFxAPIAccessing.h"

//#import "GuruFxExtension.h"
#import "FxParameter.h"

@protocol GuruFxSubParameters;

// Todo for FxPlug API
/*
1) Parameter Flags Need flag if they are published
 // Is the parameter published by the motion effect template
 #define	kFxParameterFlag_PUBLISHED		(((long) 1) << 12)
 
 2) Parameter value can change when disabled, without needing to enable-change-disable
 
 3) dynamic parameter v4, get the type of the parameter
 	- add "- (FxParameterType)parameterType:(FxParameterId)
 
 4) Generate Tracker Data from plugin? how is it done in other plugins?, eg photogrammetry
 
 5) Setting 3D Environment from plugin?  setting camera-wiew position/matrix
 
 6) change FxParameterFlags to be FxParameterFlags64, and the top 32 bits are reserved for application
    use.  They are always saved and returned but unused by the host application.  They are not filtered
    by the host application.
 
 7) expose the OSC being used by Apple plugins for rectangle, direction, direction and magnitude, magnitude, etc
 
 */


/**
 * Questions
 ************
 * Does a custom value NSString return a string from getStringParameterValue
 * Does a custom value NSNumber  return a string from getBoolValue
 * Does a custom value NSNumber  return a string from getFloatValue
 * Does a custom value NSNumber  return a string from getIntValue
 * Does a custom value NSNumber  return a string from getBoolValue
 *
 *does set string on a font name work?
 *	how to set the font?
 *
 * XY and RGB RGBA  float int string  font  bool interchangable?
 
 */

@protocol GuruFxTileEffectOptional

@optional
 -(BOOL) guruParameterChanged:(UInt32)paramID
					   atTime:(CMTime)time
						error:(NSError * _Nullable * _Nullable)error;

- (BOOL) pluginStateWithCoder:(NSCoder * _Nonnull)coder
					   atTime:(CMTime)renderTime
					  quality:(FxQuality)qualityLevel
						error:(NSError * _Nullable * _Nullable)error;

- (BOOL)scheduleInputs:(NSMutableArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
			 withCoder:(NSCoder* _Nullable)pluginState
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;

- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
			  pluginStateCoder:(NSCoder * _Nonnull)pluginState
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;
@end


typedef NS_OPTIONS(NSUInteger, GuruFxPresetOptions) {
	PresetAll		= -1,
	PresetName		= 1 << 0,
	PresetFlags		= 1 << 1,
	PresetTags      = 1 << 2,
	PresetValues    = 1 << 3
};

typedef BOOL (*GuruFxManagedSelector)(id _Nonnull , SEL _Nonnull , FxParameterId, CMTime, NSError*_Nullable*_Nullable);

typedef struct GuruFxPluginState {
	// template
} GuruFxPluginState;



#define GuruFxPluginDefault	{/* fill in */}



/*!
 
 NSFastEnumeration loops through all the parameters
 */
@interface GuruFxTileableEffect : NSObject <FxTileableEffect, FxCustomParameterViewHost_v2, GuruFxTileEffectOptional, NSFastEnumeration>
{
	@protected
	
	// These are for the FxTileableEffect::properties method
	BOOL _needsFullBuffer; // default: NO
	BOOL _variesWhenParamsAreStatic; // default: NO
	BOOL _changesOutputSize; // Default: YES

	BOOL _mayRemapTime; // Default: YES
	BOOL _usesNonmatchingTextureLayout; // Default: NO
	BOOL _drawsInScreenSpace; // Default: NO

	FxImageColorInfo _desiredProcessingColorInfo;
	FxPixelTransformSupport _pixelTransformSupport;
	
	@private
	BOOL _retreivedHasPluginMeta;
	
	NSMutableDictionary<NSNumber*, NSView*> *parameterViews;
	
	NSMutableDictionary<NSNumber*, FxParameter*>	*_parameters;
	NSMutableArray<id<GuruFxSubParameters>>*_Nullable _subgroupStack;
	
	//GuruFxExtension
	BOOL		_extActive;
	NSInteger	_extDefaultPriority;
}
// v1.0
	@property (readonly) GuruFxAPIAccessing * _Nonnull apiManager;
@property (readonly) NSDictionary<NSNumber*, id<FxParameter>>*_Nonnull parameters;
	@property (assign, readonly) BOOL addedToDocument;
	@property (nonnull, readonly, retain) NSPriorityNotificationCenter *notifier;

	// Plugin plist Properties
	@property (strong, readonly) NSDictionary<NSString*, id>* _Nonnull properties; // of the plugin plist
	@property (strong, readonly, nonnull) NSArray<NSDictionary*>* initialParametersList;
	@property (strong, readonly) NSString* _Nonnull parametersFile;
	@property (strong, readonly) NSDictionary<NSNumber*, NSDictionary*>* _Nonnull initialParameters;

	// Plugin Properties
	@property (strong, readonly) NSString* _Nonnull uuid;
	@property (strong, readonly) NSArray* _Nonnull priorUuids;
	@property (strong, readonly) NSString* _Nonnull displayName;
	@property (strong, readonly) NSString* _Nonnull groupUuid;
	@property (strong, readonly) NSString* _Nonnull infoString;
	@property (strong, readonly) NSArray* _Nonnull protocolNames;
	@property (strong, readonly) NSString* _Nonnull defaultFontName;
	@property (assign, readonly) BOOL isGenerator;
	@property (assign, readonly) BOOL isFilter;

	// Project Properties
	@property (assign, readonly) NSUInteger documentID;
	@property (assign, readonly) BOOL isMotion;
	@property (assign, readonly) BOOL isFinalCutPro;
	@property (assign, readonly) NSURL* _Nullable mediaFolder;
	@property (assign, readonly) float projectAspectRatio;

- (NSUInteger)documentIDWithError:(NSError * _Nullable * _Nullable)error;
- (NSURL* _Nullable) mediaFolderWithError:(NSError * _Nullable * _Nullable)error;
- (float) projectAspectRatioWithError:(NSError * _Nullable * _Nullable)error;

	// Fx Properties
	@property (assign, readonly) BOOL needsFullBuffer; // default: NO
	@property (assign, readonly) BOOL variesWhenParamsAreStatic; // default: NO
	@property (assign, readonly) BOOL changesOutputSize; // Default: YES

	@property (assign, readonly) BOOL mayRemapTime; // Default: YES
	@property (assign, readonly) BOOL usesNonmatchingTextureLayout; // Default: NO
	@property (assign, readonly) BOOL drawsInScreenSpace; // Default: NO

	@property (assign, readonly) FxImageColorInfo desiredProcessingColorInfo;
	@property (assign, readonly) FxPixelTransformSupport pixelTransformSupport;

	@property (assign, readonly) BOOL isGammaColorParameters;
	@property (assign, readonly) BOOL isLinearColorParameters;

	// Project Color - Is the project HDR or sRGB
	@property (assign, readonly) FxColorPrimaries colorPrimaries;
	@property (assign, readonly) BOOL isHDRProject;
	@property (assign, readonly) BOOL issRGBProject;
	
	// Effect Utilities
	@property (assign, readonly) BOOL hasDebugMenu;
	@property (assign, readonly) BOOL hasDebugActivator;
	@property (assign, readonly) BOOL hasMeta;
	@property (assign, readonly) BOOL hasLoadedMeta;
	@property (assign, readonly) BOOL trackInstances;

	//Implementation

- (nullable instancetype)initWithAPIManager:(nonnull id<PROAPIAccessing>)newApiManager;

	// Parameter Properties

- (NSDictionary*_Nullable)initialParameter:(FxParameterId)parameterID;

- (NSView *_Nullable)viewForParameterID:(UInt32)parameterID;

- (BOOL)handleParameterChanged:(UInt32)paramID
						atTime:(CMTime)time
						 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)completeParameterChanged:(UInt32)paramID
						  atTime:(CMTime)time
						   error:(NSError * _Nullable * _Nullable)error;
- (NSUInteger)gradientSamples:(UInt32)parameterID;
- (NSUInteger)gradientDepth:(UInt32)parameterID;



- (BOOL)setParameterTargetPreset:(FxParameterId)paramID
						  atTime:(CMTime)time
						 options:(GuruFxPresetOptions)options;

// subcclasses change their "parameterChanged" by adding "guru" to the front (capitalizing "P" in parameter)
//- (BOOL)guruParameterChanged:(UInt32)paramID atTime:(CMTime)time error:(NSError * _Nullable * _Nullable)error;
// This is an optional method. when implemented gets the handle and complete method pre-implemented.

- (UInt32)parameterCount;
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

- (BOOL)generateParameters:(NSArray<NSDictionary*>*_Nullable)parameters error:(NSError * _Nullable * _Nullable)error;
- (BOOL)generateParameters:(NSArray<NSDictionary*>*_Nullable)parameters parameterID:(FxParameterId)parentParameterId error:(NSError * _Nullable * _Nullable)error;

@property (strong, readonly) GuruFxMetaManager * _Nonnull meta;


//	GuruFxTileableEffect as its own GuruFxExtension
@property (readonly) BOOL 			extActive;
@property (readwrite) NSInteger		extDefaultPriority;

@end

#endif
