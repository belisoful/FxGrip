/*!
	@file       FxGripTileableEffect.h
	@copyright  Copyright © 2020-2023 Apple, Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect
	@abstract   The central base class for FxPlug tileable effects built on FxGrip.
	@discussion Introduced in FxGrip 0.1.0. FxGripTileableEffect wraps the FxPlug
	            FxTileableEffect protocol and adds FxGrip's parameter model, extension system,
	            priority notification center, and host-API accessors. A plugin subclasses this
	            class to inherit parameter creation from configuration, lifecycle notifications,
	            render-state compression, and the categories that add timing, color gamut,
	            custom UI, and out-of-band parameter access. The file declares the
	            FxGripTileableEffect protocol, its expanded and coder-state companion protocols,
	            and the concrete FxGripTileableEffect class.
*/

#ifndef FxGripTileableEffect_h
#define FxGripTileableEffect_h

#import <Foundation/Foundation.h>
#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripExtension.h>
#import <FxGrip/FxGripParameterUtility.h>
#import <FxGrip/FxGripAPIAccessing.h>
#import <FxGrip/FxGripImageCompression.h>
#import <BEFoundation/NSPriorityNotificationCenter.h>
#import <FxGrip/FxGripTypes.h>

@class FxGripOOBParameterAccess;




/*!
	@protocol	FxGripTileableEffectExpanded
	@abstract	The FxGrip-added state that every tileable effect exposes beyond FxTileableEffect.
	@discussion	Introduced in FxGrip 0.1.0. The protocol names the plugin identity, the host-API
				accessor, the notification center, the plugin properties, and the setup-progress
				flags an extension or category reads. The optional extensionsFlush returns an
				error when a pending extension flush fails.
*/
@protocol FxGripTileableEffectExpanded
/*! The registered UUID of the plug-in this effect instantiates. */
@property (readonly, nonnull, retain) NSString *pluginUUID;
/*! The wrapped host API manager, through which the effect reaches every host service. */
@property (readonly, nonnull, retain) id<FxGripAPIAccessing> apiManager;
/*! The effect's notification center, which extensions and parameters register observers on. */
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;
/*! The registered plug-in's properties dictionary, as the registrar declared it. */
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;

/*! YES once the host has added the effect to a document. */
@property (assign, readonly) BOOL addedToDocument;
/*! YES once the `addParameters` pass has completed. */
@property (assign, readonly) BOOL addedParameters;

@optional
	/*!
		@method		extensionsFlush
		@abstract	Runs the pending flush on every loaded extension.
		@return		The error from the first extension that failed to flush, or nil.
	*/
	- (nullable NSError*)extensionsFlush;
@end




#import <FxGrip/FxGripEffectHost.h>

/*!
	@protocol	FxGripTileableEffect
	@abstract	The full contract a FxGrip tileable effect presents to its extensions and categories.
	@discussion	Introduced in FxGrip 0.1.0. The protocol composes FxTileableEffect,
				FxGripTileableEffectExpanded, and FxGripEffectHost, and adds plugin naming, the
				default font name, parameter subscripting, and fast enumeration. The optional
				section declares the color-gamut, out-of-band-parameter, and timing members that
				the matching categories implement.
*/
@protocol FxGripTileableEffect <FxTileableEffect, FxGripTileableEffectExpanded, FxGripEffectHost>

/*! The plug-in's display name, as the registrar declared it. */
@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
/*! The UUID of the registration group the plug-in belongs to. */
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
/*! The plug-in's informational string, shown by the host. */
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

/*! The font name a parameter uses when its configuration names none. */
@property (readonly, retain, nonnull) NSString*		defaultFontName;

/*!
	@method		objectAtIndexedSubscript:
	@abstract	The parameter for a host ID, or for an ordinal position, as `effect[index]`.
	@discussion	The subscript reads two ways, which the sign selects.

				- index is positive → the parameter carrying that host ID.
				- index is zero or negative → the parameter at ordinal position `-index` in the
				  host's parameter list.
	@param		index	A positive host ID, or a negated ordinal position.
	@return		The parameter, or nil when the effect holds none there.
*/
- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
/*!
	@method		objectForKeyedSubscript:
	@abstract	The parameter or the extension a key names, as `effect[key]`.
	@discussion	The key's shape selects what is returned.

				- an `NSNumber`, or an `NSString` of digits → the parameter, resolved the way
				  ``objectAtIndexedSubscript:`` resolves it.
				- any other `NSString` → the extension registered under that key.
				- any other object, or nil → nil.
	@param		key		The parameter ID or the extension key.
	@return		The parameter, the extension, or nil when neither is found.
*/
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;
/*!
	@method		countByEnumeratingWithState:objects:count:
	@abstract	Enumerates the effect's parameters with `for (id p in effect)`.
	@param		enumerationState	The enumeration state the runtime carries between calls.
	@param		stackBuffer			The buffer the runtime offers for returned objects.
	@param		len					The capacity of stackBuffer.
	@return		The number of objects written, or 0 at the end of the enumeration.
*/
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (_Nullable id __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;


@optional
// ColorGamut category
/*! The project's color primaries, as an `FxColorPrimaries`. */
@property (readonly, assign) FxColorPrimaries colorPrimaries;
/*! YES when the project works in the Rec. 2020 gamut. */
@property (readonly, assign) BOOL isRec2020Gamut;
/*! YES when the project works in the Rec. 709 gamut. */
@property (readonly, assign) BOOL isRec709Gamut;
/*! YES when color parameters carry gamma-encoded values. */
@property (readonly, assign) BOOL isGammaColorParameters;
/*! YES when color parameters carry linear-light values. */
@property (readonly, assign) BOOL isLinearColorParameters;


/*!
	@method		addParametersWithGroupID:error:
	@abstract	Adds the parameters declared for one group.
	@discussion	The effect calls this for the top-level group, and again for each nested group a
				declaration names. A subclass overrides it to add parameters by hand.
	@param		groupID		The host ID of the group to add into.
	@param		error		On return, the reason a parameter could not be added.
	@return		YES when every parameter in the group was added.
*/
- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

// out of band
/*!
	@method		startContext
	@abstract	Opens an out-of-band context for reading and writing parameters outside a render.
	@return		The context, which closes when it goes out of scope.
*/
- (nonnull FxGripOOBParameterAccess *)startContext;
/*!
	@method		startContextFlush
	@abstract	Opens an out-of-band context that flushes the effect's extensions when it closes.
	@return		The context, which closes when it goes out of scope.
*/
- (nonnull FxGripOOBParameterAccess *)startContextFlush;


//Timing
/*! The duration of one frame after retiming, in timeline time. */
@property (readonly) CMTime frameDuration;
/*! The clip's retiming speed; 1.0 is 100%, 2.0 is 200%, 0.5 is slowed to 50%. */
@property (readonly) Float64 retimingSpeed;

/*! The sample duration; equal to the frame duration for progressive clips, half for interlaced. */
@property (readonly) CMTime sampleDuration;
/*! YES when the sample duration differs from the frame duration. */
@property (readonly) BOOL isInterlacedClip;
/*! YES when the project displays timecode in drop-frame format. NO on a host without `FxTimingAPI_v5`. */
@property (readonly) BOOL isTimelineDropFrame;
/*! YES when the filter's input clip requires drop-frame timecode. */
@property (readonly) BOOL isInputDropFrame;

/*! The effect's start time in input time. */
@property (readonly) CMTime effectStartTime;
/*! The effect's start time as a timeline frame index. */
@property (readonly) NSInteger effectStartFrame;
/*! The effect's start time converted to timeline time. */
@property (readonly) CMTime effectStartTimeInTimeline;
/*! The effect's duration in input time. */
@property (readonly) CMTime effectDurationTime;
/*! The effect's duration in timeline frames. */
@property (readonly) NSInteger effectDurationFrames;

/*! The filter input's start time in input time. */
@property (readonly) CMTime inputStartTime;
/*! The filter input's start time as a timeline frame index. */
@property (readonly) NSInteger inputStartFrame;
/*! The filter input's start time converted to timeline time. */
@property (readonly) CMTime inputStartTimeInTimeline;
/*! The filter input's duration in input time. */
@property (readonly) CMTime inputDurationTime;
/*! The filter input's duration in timeline frames. */
@property (readonly) NSInteger inputDurationFrames;

/*! The effect's in point on the timeline. */
@property (readonly) CMTime effectInPointOfTimeLine;
/*! The effect's out point on the timeline. */
@property (readonly) CMTime effectOutPointOfTimeLine;

/*! The numerator of the timeline frame rate. */
@property (readonly) NSUInteger timelineFpsNumerator;
/*! The denominator of the timeline frame rate. */
@property (readonly) NSUInteger timelineFpsDenominator;

/*! The timeline frame duration as a `CMTime`. */
@property (readonly) CMTime timelineFrameDuration;
/*! The timeline frame duration in seconds. */
@property (readonly) Float64 timelineFrameDurationFloat;
/*! The timeline frame rate as a `CMTime`. */
@property (readonly) CMTime timelineFrameRate;
/*! The timeline frame rate in frames per second. */
@property (readonly) Float64 timelineFps;

/*!
	@method		frameForTime:
	@abstract	The timeline frame index for a time.
	@param		time	The time to convert.
	@return		The time multiplied by the timeline frame rate, as a frame index.
*/
- (NSInteger)frameForTime:(CMTime)time;

/*!
	@method		timelineTime:fromInputTime:
	@abstract	Converts an input time to timeline time through the host timing API.
	@param		timelineTime	On return, the equivalent timeline time.
	@param		time			The input time to convert.
*/
- (void)timelineTime:(nonnull CMTime*)timelineTime fromInputTime:(CMTime)time;
/*!
	@method		inputTime:fromTimelineTime:
	@abstract	Converts a timeline time to input time through the host timing API.
	@param		inputTime	On return, the equivalent input time.
	@param		time		The timeline time to convert.
*/
- (void)inputTime:(nonnull CMTime*)inputTime fromTimelineTime:(CMTime)time;


@end


/*!
	@protocol	FxGripTileableEffectCoderStateWeak
	@abstract	The optional NSCoder-based render callbacks a coder-state effect may implement.
	@discussion	Introduced in FxGrip 0.1.0. The callbacks mirror the FxPlug render entry points and
				replace the opaque pluginState NSData with an NSCoder, so an effect encodes and
				decodes its render state through the coder. Every method is optional, so an effect
				adopts the coder path for the render stages it needs.
*/
@protocol FxGripTileableEffectCoderStateWeak

@optional

/*!
	@method		pluginCoder:atTime:quality:error:
	@abstract	Encodes the state the render stages need, in place of `pluginState:atTime:quality:error:`.
	@discussion	The coder replaces the opaque `NSData` plugin state, so the effect writes typed
				values and reads them back in each render stage.
	@param		coder			The coder the render state is written to.
	@param		renderTime		The time the state describes.
	@param		qualityLevel	The quality the host renders at.
	@param		error			On return, the reason the state could not be encoded.
	@return		YES when the state was encoded.
*/
- (BOOL) pluginCoder:(NSCoder * _Nonnull)coder
			  atTime:(CMTime)renderTime
			 quality:(FxQuality)qualityLevel
			   error:(NSError * _Nullable * _Nullable)error;

/*!
	@method		destinationImageRect:sourceImages:destinationImage:pluginCoder:atTime:error:
	@abstract	Reports the bounds the effect draws into, in place of the `pluginState` form.
	@param		destinationImageRect	On return, the rectangle the effect draws into.
	@param		sourceImages			The source tiles for this render.
	@param		destinationImage		The destination tile.
	@param		pluginCoder				The coder holding the state this render encoded.
	@param		renderTime				The time being rendered.
	@param		outError				On return, the reason the bounds could not be computed.
	@return		YES when destinationImageRect holds the bounds.
*/
- (BOOL)destinationImageRect:(nonnull FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> * _Null_unspecified)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable * _Null_unspecified)outError;

/*!
	@method		sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginCoder:atTime:error:
	@abstract	Reports the source region one destination tile reads, in place of the `pluginState` form.
	@param		sourceTileRect			On return, the region of the source image the tile reads.
	@param		sourceImageIndex		The index of the source image being described.
	@param		sourceImages			The source tiles for this render.
	@param		destinationTileRect		The destination tile being rendered.
	@param		destinationImage		The destination tile.
	@param		pluginCoder				The coder holding the state this render encoded.
	@param		renderTime				The time being rendered.
	@param		outError				On return, the reason the region could not be computed.
	@return		YES when sourceTileRect holds the region.
*/
- (BOOL)sourceTileRect:(nonnull FxRect*)sourceTileRect
	 sourceImageIndex:(NSUInteger)sourceImageIndex
		 sourceImages:(NSArray<FxImageTile*>*_Null_unspecified)sourceImages
  destinationTileRect:(FxRect)destinationTileRect
	 destinationImage:(FxImageTile*_Null_unspecified)destinationImage
		  pluginCoder:(NSCoder * _Nonnull)pluginCoder
			   atTime:(CMTime)renderTime
				error:(NSError*_Nullable *_Null_unspecified)outError;

/*!
	@method		scheduleInputs:pluginCoder:atTime:error:
	@abstract	Requests the source frames the render needs, in place of the `pluginState` form.
	@discussion	A temporal effect asks for frames other than the one being rendered here.
	@param		inputImageRequests	On return, the requests the host fulfills before the render.
	@param		pluginCoder			The coder holding the state this render encoded, or nil.
	@param		renderTime			The time being rendered.
	@param		error				On return, the reason the requests could not be formed.
	@return		YES when inputImageRequests holds the requests.
*/
- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder* _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;

/*!
	@method		renderDestinationImage:sourceImages:pluginCoder:atTime:error:
	@abstract	Draws one destination tile, in place of the `pluginState` form.
	@param		destinationImage	The tile to draw into.
	@param		sourceImages		The source tiles for this render.
	@param		pluginCoder			The coder holding the state this render encoded.
	@param		renderTime			The time being rendered.
	@param		outError			On return, the reason the tile could not be drawn.
	@return		YES when the tile was drawn.
*/
- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
				   pluginCoder:(NSCoder * _Nonnull)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;
@end



/*!
	@protocol	FxGripTileableEffectCoderState
	@abstract	The required NSCoder-based render callbacks a full coder-state effect implements.
	@discussion	Introduced in FxGrip 0.1.0. The protocol promotes the coder, destination-bounds,
				source-tile, and render callbacks to required members, so a conforming effect
				provides the complete coder-based render path. The scheduleInputs callback stays
				optional.
*/
@protocol FxGripTileableEffectCoderState <FxGripTileableEffectCoderStateWeak>

/*!
	@method		pluginCoder:atTime:quality:error:
	@abstract	Encodes the state the render stages need, in place of `pluginState:atTime:quality:error:`.
	@discussion	The coder replaces the opaque `NSData` plugin state, so the effect writes typed
				values and reads them back in each render stage.
	@param		coder			The coder the render state is written to.
	@param		renderTime		The time the state describes.
	@param		qualityLevel	The quality the host renders at.
	@param		error			On return, the reason the state could not be encoded.
	@return		YES when the state was encoded.
*/
- (BOOL) pluginCoder:(NSCoder * _Nonnull)coder
			  atTime:(CMTime)renderTime
			 quality:(FxQuality)qualityLevel
			   error:(NSError * _Nullable * _Nullable)error;




/*!
	@method		destinationImageRect:sourceImages:destinationImage:pluginCoder:atTime:error:
	@abstract	Reports the bounds the effect draws into, in place of the `pluginState` form.
	@param		destinationImageRect	On return, the rectangle the effect draws into.
	@param		sourceImages			The source tiles for this render.
	@param		destinationImage		The destination tile.
	@param		pluginCoder				The coder holding the state this render encoded.
	@param		renderTime				The time being rendered.
	@param		outError				On return, the reason the bounds could not be computed.
	@return		YES when destinationImageRect holds the bounds.
*/
- (BOOL)destinationImageRect:(nonnull FxRect *)destinationImageRect
				sourceImages:(NSArray<FxImageTile *> *_Null_unspecified)sourceImages
			destinationImage:(nonnull FxImageTile *)destinationImage
				 pluginCoder:(NSCoder * _Nonnull)pluginCoder
					  atTime:(CMTime)renderTime
					   error:(NSError * _Nullable *_Null_unspecified)outError;

/*!
	@method		sourceTileRect:sourceImageIndex:sourceImages:destinationTileRect:destinationImage:pluginCoder:atTime:error:
	@abstract	Reports the source region one destination tile reads, in place of the `pluginState` form.
	@param		sourceTileRect			On return, the region of the source image the tile reads.
	@param		sourceImageIndex		The index of the source image being described.
	@param		sourceImages			The source tiles for this render.
	@param		destinationTileRect		The destination tile being rendered.
	@param		destinationImage		The destination tile.
	@param		pluginCoder				The coder holding the state this render encoded.
	@param		renderTime				The time being rendered.
	@param		outError				On return, the reason the region could not be computed.
	@return		YES when sourceTileRect holds the region.
*/
- (BOOL)sourceTileRect:(nonnull FxRect*)sourceTileRect
	 sourceImageIndex:(NSUInteger)sourceImageIndex
		 sourceImages:(NSArray<FxImageTile*>*_Null_unspecified)sourceImages
  destinationTileRect:(FxRect)destinationTileRect
	 destinationImage:(FxImageTile*_Null_unspecified)destinationImage
		  pluginCoder:(NSCoder * _Nonnull)pluginCoder
			   atTime:(CMTime)renderTime
				error:(NSError*_Nullable *_Null_unspecified)outError;


/*!
	@method		renderDestinationImage:sourceImages:pluginCoder:atTime:error:
	@abstract	Draws one destination tile, in place of the `pluginState` form.
	@param		destinationImage	The tile to draw into.
	@param		sourceImages		The source tiles for this render.
	@param		pluginCoder			The coder holding the state this render encoded.
	@param		renderTime			The time being rendered.
	@param		outError			On return, the reason the tile could not be drawn.
	@return		YES when the tile was drawn.
*/
- (BOOL)renderDestinationImage:(FxImageTile *_Nonnull)destinationImage
				  sourceImages:(NSArray<FxImageTile *> *_Nullable)sourceImages
				   pluginCoder:(NSCoder * _Nonnull)pluginCoder
						atTime:(CMTime)renderTime
						 error:(NSError * _Nullable * _Nullable)outError;

@optional
/*!
	@method		scheduleInputs:pluginCoder:atTime:error:
	@abstract	Requests the source frames the render needs, in place of the `pluginState` form.
	@discussion	A temporal effect asks for frames other than the one being rendered here.
	@param		inputImageRequests	On return, the requests the host fulfills before the render.
	@param		pluginCoder			The coder holding the state this render encoded, or nil.
	@param		renderTime			The time being rendered.
	@param		error				On return, the reason the requests could not be formed.
	@return		YES when inputImageRequests holds the requests.
*/
- (BOOL)scheduleInputs:(NSArray<FxImageTileRequest*>* _Nullable * _Nullable)inputImageRequests
		   pluginCoder:(NSCoder* _Nullable)pluginCoder
				atTime:(CMTime)renderTime
				 error:(NSError*_Nullable*_Nonnull)error;
@end





/*! The extension key identifying the main effect itself when it acts as an FxGripExtension. */
extern NSString * _Nonnull const FxGripTileableEffectExtKey;





/*!
	@class		FxGripTileableEffect
	@abstract	The concrete base class a FxGrip tileable effect plugin subclasses.
	@discussion	Introduced in FxGrip 0.1.0. The class implements the FxPlug properties and
				parameter callbacks, holds the extension dictionary, parameter dictionary, and
				priority notification center, and drives setup through the addingParameters,
				addedParameters, finishedSetup, and addedToDocument stages. It reads the plugin
				identity and properties from the registration record. Subclasses override
				loadExtensions, addParametersWithGroupID:error:, parametersConfiguration, and the
				render callbacks. The render state supports optional lossless compression through
				pluginStateCompression.
*/
@interface FxGripTileableEffect : FxGripExtensionBase <FxGripTileableEffect, FxGripTileableEffectCoderStateWeak>
{
	NSMutableDictionary<id, Class> *__typeToClassMap;
}

/*!
	@method		initWithAPIManager:
	@abstract	The designated initializer, which the FxPlug host calls with its API manager.
	@discussion	Introduced in FxGrip 0.1.0. The host owns the effect's lifetime and constructs it
				through this initializer. Declaring it designated is what lets a subclass in another
				language inherit it correctly: a Swift subclass that adds stored properties has its
				property defaults applied only when the initializer it inherits is designated.
*/
- (nullable instancetype)initWithAPIManager:(nullable id<PROAPIAccessing>)apiManager NS_DESIGNATED_INITIALIZER;

/*! Constructs an effect with no host, by delegating to `initWithAPIManager:` with a nil manager. */
- (nonnull instancetype)init;

/*! The host-API accessor the effect uses to reach FxPlug host services. */
@property (readonly, nonnull) id<FxGripAPIAccessing> apiManager;

/*! The priority notification center that carries the effect's lifecycle and parameter events. */
@property (readonly, nonnull, assign) NSPriorityNotificationCenter *notifier;
/*! The installed extensions, keyed by extension identifier. */
@property (readonly, nonnull, retain) NSDictionary<NSString*, id<FxGripExtension>> *extensions;
/*! The effect's parameters, keyed by parameter ID. */
@property (readonly, nonnull, retain) NSDictionary<NSNumber*, id<FxGripParameter>> *parameters;

//Plugin Properties
/*! The plugin's UUID from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginUUID;
/*! The identifier of the effect instance's render session. */
@property (readonly) UInt64 sessionID;
//The following is from the plist, or the dynamic registration class in the plist
/*! The plugin registration dictionary, from the plist or the dynamic registration class. */
@property (readonly, nonnull, retain) NSDictionary<NSString*, id> *pluginProperties;
/*! The plugin's display name from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginDisplayName;
/*! The plugin group's UUID from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginGroupUUID;
/*! The plugin's information string from its registration record. */
@property (readonly, nonnull, retain) NSString*		pluginInfoString;

// FxPlug FxTileableEffect Properties
/*! YES once the host has called `properties:error:` on the effect. */
@property (assign, readonly) BOOL finishedProperties;
/*! Whether the effect requires the full source buffer instead of a tile. */
@property (assign, readwrite, nonatomic) BOOL needsFullBuffer;
/*! Whether the output varies over time while the parameters stay static. */
@property (assign, readwrite, nonatomic) BOOL variesWhenParamsAreStatic;
/*! Whether the effect changes the output image size. */
@property (assign, readwrite, nonatomic) BOOL changesOutputSize;
/*! The color space the effect wants its source and destination images processed in. */
@property (assign, readwrite, nonatomic) FxImageColorInfo desiredProcessingColorInfo;
/*! Whether the effect remaps the timeline time of its input. */
@property (assign, readwrite, nonatomic) BOOL mayRemapTime;
/*! Whether the effect's textures use a layout that does not match the host's default. */
@property (assign, readwrite, nonatomic) BOOL usesNonmatchingTextureLayout;
/*! Whether the effect draws in screen space instead of image space. */
@property (assign, readwrite, nonatomic) BOOL drawsInScreenSpace;
/*! The effect's support for pixel-transform rendering. */
@property (assign, readwrite, nonatomic) FxPixelTransformSupport pixelTransformSupport;

/*!
	@property   pluginStateCompression
	@abstract   The lossless codec applied to the render-time pluginState blob.
	@discussion Introduced in FxGrip 0.1.0. The default FxGripCompressionNone leaves the blob
				uncompressed, matching the pre-1.0 wire format. Setting a lossless codec
				(LZFSE, LZ4, zlib, LZMA) enables size-gated compression: the encoded state is
				compressed only when it reaches pluginStateCompressionThreshold and the codec
				shrinks it, and it passes through uncompressed otherwise. The render side
				detects the codec from the blob and decompresses without further
				configuration, so the setting is safe to change per instance. A lossy codec is
				treated as FxGripCompressionNone, since the blob is not an image.
*/
@property (assign, readwrite, nonatomic) FxGripCompression pluginStateCompression;

/*!
	@property   pluginStateCompressionThreshold
	@abstract   The byte count below which pluginState is left uncompressed.
	@discussion Introduced in FxGrip 0.1.0. Defaults to
				FxGripCompressionEnvelopeThresholdDefault. A small blob's compression saving
				does not repay the codec's per-call cost on the per-frame render path, so it
				passes through uncompressed. Has no effect while pluginStateCompression is
				FxGripCompressionNone.
*/
@property (assign, readwrite, nonatomic) NSUInteger pluginStateCompressionThreshold;

// Stack Location
/*! YES while the effect is inside its parameter-creation pass. */
@property (assign, readonly) BOOL addingParameters;
/*! YES once the effect has finished creating its parameters. */
@property (assign, readonly) BOOL addedParameters;
/*! YES once the effect has finished its initial setup. */
@property (assign, readonly) BOOL finishedSetup;
/*! YES once the effect has been added to a document. */
@property (assign, readonly) BOOL addedToDocument;

//	FxTileableEffect Implementation
/*!
	@method		properties:error:
	@abstract	Fills the FxPlug property dictionary the host reads during setup.
	@param		properties	On return, the effect's FxPlug property dictionary.
	@param		error		On failure, the error describing why the properties could not be built.
	@return		YES when the properties are supplied; NO on failure.
	@discussion	Introduced in FxGrip 0.1.0. The base implementation maps the effect's property
				settings, such as needsFullBuffer and pixelTransformSupport, into the FxPlug keys.
				The call marks finishedProperties YES. */
- (BOOL) properties:(NSDictionary *_Nullable *_Null_unspecified) properties
			  error:(NSError *_Nullable *_Null_unspecified) error;

//Parameters
/*! @abstract The number of parameters the effect currently holds. */
- (UInt32)parameterCount;

/*!
	@method		objectAtIndexedSubscript:
	@abstract	The parameter for a host ID, or for an ordinal position, as `effect[index]`.
	@discussion	The subscript reads two ways, which the sign selects.

				- index is positive → the parameter carrying that host ID.
				- index is zero or negative → the parameter at ordinal position `-index` in the
				  host's parameter list.
	@param		index	A positive host ID, or a negated ordinal position.
	@return		The parameter, or nil when the effect holds none there.
*/
- (id<FxGripParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;

/*!
	@method		objectForKeyedSubscript:
	@abstract	The parameter or the extension a key names, as `effect[key]`.
	@discussion	The key's shape selects what is returned.

				- an `NSNumber`, or an `NSString` of digits → the parameter, resolved the way
				  ``objectAtIndexedSubscript:`` resolves it.
				- any other `NSString` → the extension registered under that key.
				- any other object, or nil → nil.
	@param		key		The parameter ID or the extension key.
	@return		The parameter, the extension, or nil when neither is found.
*/
- (id _Nullable)objectForKeyedSubscript:(id _Nullable)key;

/*! @abstract Enumerates the effect's parameters for fast enumeration. */
- (NSUInteger) countByEnumeratingWithState: (nonnull NSFastEnumerationState *) enumerationState
								   objects: (id _Nullable __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

// Sub-Class override implementations
/*! The font name a subclass supplies for parameters that default to the plugin's font. */
@property (readonly, retain, nonnull) NSString* defaultFontName;

/*!
	@method		loadExtensions
	@abstract	Returns the extensions to install on the effect during setup.
	@return		A mutable array of extensions, or nil when the effect installs none.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to add extensions, and
				calls super to keep the framework-installed extensions. */
- (nullable NSMutableArray<id<FxGripExtension>>*)loadExtensions;

/*!
	@method		addParametersWithGroupID:error:
	@abstract	Creates the effect's parameters within a parameter group.
	@param		groupID	The parameter group the created parameters are added under.
	@param		error	On failure, the error describing why a parameter could not be created.
	@return		YES when the parameters are created; NO on failure.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to build parameters in code,
				and calls super to keep the configuration-driven parameters. */
- (BOOL)addParametersWithGroupID:(FxParameterId)groupID error:(NSError*_Nonnull*_Nullable)error;

/*!
	@method     parametersConfiguration
	@abstract   Returns the parameter configuration records that seed addParametersWithError:.
	@discussion Introduced in FxGrip 0.1.0. The base implementation returns the `"parameters"`
				array from the plugin's registration dictionary
				(`kProPlugPlugInX_ParametersProperty`), so a plugin declares its parameters
				in the plist or dynamic-registration record without writing creation code.
				A subclass overrides to build the records in code, or calls super and
				appends. Each record uses `kFxParameterProperty_*` keys.
*/
- (nonnull NSMutableArray<NSDictionary *> *)parametersConfiguration;

/*!
	@method     configurationForParameter:
	@abstract   Returns the parameter's configuration record from the flattened
				parameters configuration.
	@discussion Introduced in FxGrip 0.1.0. The record carries the declared parameter
				properties (`kFxParameterProperty_*` keys) including tags, meta, reset
				value, and target-preset definitions.
*/
- (NSDictionary *_Nullable)configurationForParameter:(FxParameterId)parameterID;

/*!
	@method     parameterClicked:
	@abstract   Standardized dispatch for push-button and help-button clicks.
	@discussion Introduced in FxGrip 0.1.0. Button parameters register a synthesized
				selector that encodes the parameter ID
				(`FxGripParameterUtility clickSelectorNameForParameter:`). The runtime
				resolves that selector to a trampoline that decodes the ID and calls this
				method, so one entry point serves every button and subclasses do not
				implement a method per button.

				The dispatch, wrapped in the action API's `startAction:` / `endAction:`
				when the effect is not an on-screen control:
				- posts `FxGripTileableEffectParameterClickedName` with
				  `FxGripTileableEffectParameterClickedIDKey` so extensions observe the click
				- performs the configuration-declared `"selector"` when the subclass
				  implements it
				- otherwise performs the parameter object's `defaultParameterAction`

				Subclasses may override to intercept every click; call super to keep the
				notification and dispatch behavior.
	@result     NO when a notification observer reports an error; YES otherwise.
*/
- (BOOL)parameterClicked:(FxParameterId)parameterID;

@end




/*!
	@abstract	The category that reports whether the effect's FxPlug properties come from configuration.
	@discussion	Introduced in FxGrip 0.1.0. The category exposes propertiesFromConfiguration, which
				is YES when the properties callback fills the FxPlug property dictionary from the
				plugin's registration record rather than from subclass code.
*/
@interface FxGripTileableEffect (ConfigurationProperties)

/*! YES when the effect's FxPlug properties are populated from the plugin configuration record. */
@property (readonly) BOOL		propertiesFromConfiguration;

@end

#endif
