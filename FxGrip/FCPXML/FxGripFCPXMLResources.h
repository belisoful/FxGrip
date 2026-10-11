/*!
	@file       FxGripFCPXMLResources.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLResources
	@abstract   The `resources` element and the resource kinds it holds.
	@discussion Introduced in FxGrip 0.1.0. A resource is an element other elements reference by
	            its `id`: a `format` (frame size and rate), an `asset` (a media file with its
	            `media-rep` locations), an `effect` (a Motion template, FxPlug plug-in, or audio
	            unit), a `media` (a compound or multicam sequence), or a `locator` (a data file).
	            ``FxGripFCPXMLResources`` allocates identifiers in Final Cut Pro's `r1`, `r2`, …
	            form and finds a resource by identifier or by effect uid.
*/

#ifndef FxGripFCPXMLResources_h
#define FxGripFCPXMLResources_h

#import <FxGrip/FxGripFCPXMLElement.h>

NS_ASSUME_NONNULL_BEGIN

/*! The prefix Final Cut Pro writes before an FxPlug plug-in's UUID in an effect uid. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLEffectFxPlugUIDPrefix;

/*!
	@class      FxGripFCPXMLResource
	@abstract   The base of every resource: an identifier, a name, and a uid.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLResource : FxGripFCPXMLElement

/*! The document-local identifier other elements reference (`id`). */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The display name. */
@property (readwrite, copy, nullable) NSString *resourceName;
/*! The Final Cut Pro assigned unique identifier, where the kind carries one. */
@property (readwrite, copy, nullable) NSString *uid;

@end

/*!
	@class      FxGripFCPXMLFormat
	@abstract   A `format`: the frame size, frame duration, and color space of video.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLFormat : FxGripFCPXMLResource

/*! The duration of one frame, or `kCMTimeInvalid`. */
@property (readwrite) CMTime frameDuration;
/*! The frame width in pixels; 0 when absent. */
@property (readwrite) NSInteger width;
/*! The frame height in pixels; 0 when absent. */
@property (readwrite) NSInteger height;
/*! The field order, such as `progressive`. */
@property (readwrite, copy, nullable) NSString *fieldOrder;
/*! The color space in the `<cp>-<tc>-<mc> (<name>)` form, such as `1-1-1 (Rec. 709)`. */
@property (readwrite, copy, nullable) NSString *colorSpace;
/*! The horizontal pixel aspect numerator; 0 when absent. */
@property (readwrite) NSInteger pixelAspectHorizontal;
/*! The vertical pixel aspect denominator; 0 when absent. */
@property (readwrite) NSInteger pixelAspectVertical;

/*! A format with a frame duration and size. */
+ (instancetype)formatWithFrameDuration:(CMTime)frameDuration width:(NSInteger)width height:(NSInteger)height;

@end

/*!
	@class      FxGripFCPXMLMediaRep
	@abstract   A `media-rep`: one location of an asset's media.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLMediaRep : FxGripFCPXMLElement

/*! `original-media` or `proxy-media`. */
@property (readwrite, copy, nullable) NSString *kind;
/*! The media file URL string (`src`). */
@property (readwrite, copy, nullable) NSString *source;
/*! The file URL, when `source` parses as one. */
@property (readonly, nullable) NSURL *sourceURL;
/*! The Final Cut Pro signature. */
@property (readwrite, copy, nullable) NSString *signature;
/*! The filename to use when the URL does not supply one. */
@property (readwrite, copy, nullable) NSString *suggestedFilename;

@end

/*!
	@class      FxGripFCPXMLAsset
	@abstract   An `asset`: a reference to a media file.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLAsset : FxGripFCPXMLResource

/*! The media start time, or `kCMTimeInvalid`. */
@property (readwrite) CMTime start;
/*! The media duration, or `kCMTimeInvalid`. */
@property (readwrite) CMTime duration;
/*! YES when the asset carries video. */
@property (readwrite) BOOL hasVideo;
/*! YES when the asset carries audio. */
@property (readwrite) BOOL hasAudio;
/*! The identifier of the asset's format resource. */
@property (readwrite, copy, nullable) NSString *formatIdentifier;
/*! The number of audio channels; 0 when absent. */
@property (readwrite) NSInteger audioChannels;
/*! The audio sample rate; 0 when absent. */
@property (readwrite) NSInteger audioRate;
/*! The media representations, original first. */
@property (readonly, copy) NSArray<FxGripFCPXMLMediaRep *> *mediaReps;
/*! The original media representation, or nil. */
@property (readonly, nullable) FxGripFCPXMLMediaRep *originalMediaRep;

/*! Adds a representation of a kind at a URL string. */
- (FxGripFCPXMLMediaRep *)addMediaRepOfKind:(NSString *)kind source:(NSString *)source;

/*! An asset for a file URL, with an original media representation. */
+ (instancetype)assetWithName:(nullable NSString *)name fileURL:(NSURL *)fileURL;

@end

/*!
	@class      FxGripFCPXMLEffect
	@abstract   An `effect`: a Motion template, an FxPlug plug-in, an audio bundle, or an audio unit.
	@discussion Introduced in FxGrip 0.1.0. An FxPlug plug-in's uid is `FxPlug:` followed by the
				plug-in's UUID; a Motion template's uid is the template's path under the Motion
				Templates folder.
*/
@interface FxGripFCPXMLEffect : FxGripFCPXMLResource

/*! The source path, where Final Cut Pro writes one. */
@property (readwrite, copy, nullable) NSString *source;
/*! YES when the uid names an FxPlug plug-in. */
@property (readonly) BOOL isFxPlug;
/*! The FxPlug plug-in UUID the uid names, or nil for another kind. */
@property (readonly, nullable) NSString *fxPlugUUID;

/*! An effect for an FxPlug plug-in UUID. */
+ (instancetype)effectWithFxPlugUUID:(NSString *)pluginUUID name:(nullable NSString *)name;
/*! The uid for an FxPlug plug-in UUID. */
+ (NSString *)uidForFxPlugUUID:(NSString *)pluginUUID;
/*! The plug-in UUID an FxPlug uid names, or nil for another kind. */
+ (nullable NSString *)fxPlugUUIDForUID:(nullable NSString *)uid;

@end

/*!
	@class      FxGripFCPXMLMedia
	@abstract   A `media`: a compound clip or multicam clip definition.
	@discussion Introduced in FxGrip 0.1.0. The content is a `sequence` or `multicam` child.
*/
@interface FxGripFCPXMLMedia : FxGripFCPXMLResource

/*! The project reference identifier. */
@property (readwrite, copy, nullable) NSString *projectReference;
/*! The modification date string. */
@property (readwrite, copy, nullable) NSString *modificationDate;
/*! The `sequence` or `multicam` child, or nil. */
@property (readonly, nullable) __kindof FxGripFCPXMLElement *content;

@end

/*!
	@class      FxGripFCPXMLLocator
	@abstract   A `locator`: a data file a clip refers to.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLLocator : FxGripFCPXMLResource

/*! The data file URL string. */
@property (readwrite, copy, nullable) NSString *urlString;

@end

/*!
	@class      FxGripFCPXMLResources
	@abstract   The `resources` element: the document's formats, assets, effects, media, and locators.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLResources : FxGripFCPXMLElement

/*! Every resource, in document order. */
@property (readonly, copy) NSArray<__kindof FxGripFCPXMLResource *> *resources;
/*! The format resources. */
@property (readonly, copy) NSArray<FxGripFCPXMLFormat *> *formats;
/*! The asset resources. */
@property (readonly, copy) NSArray<FxGripFCPXMLAsset *> *assets;
/*! The effect resources. */
@property (readonly, copy) NSArray<FxGripFCPXMLEffect *> *effects;
/*! The media resources. */
@property (readonly, copy) NSArray<FxGripFCPXMLMedia *> *media;
/*! The locator resources. */
@property (readonly, copy) NSArray<FxGripFCPXMLLocator *> *locators;

/*! The resource with an identifier, or nil. */
- (nullable __kindof FxGripFCPXMLResource *)resourceWithIdentifier:(NSString *)identifier;
/*! The effect with a uid, or nil. */
- (nullable FxGripFCPXMLEffect *)effectWithUID:(NSString *)uid;
/*! The effect for an FxPlug plug-in UUID, or nil. */
- (nullable FxGripFCPXMLEffect *)effectWithFxPlugUUID:(NSString *)pluginUUID;

/*!
	@method     allocateIdentifier
	@abstract   An identifier no resource in the element uses, in the `r<n>` form.
*/
- (NSString *)allocateIdentifier;

/*!
	@method     addResource:
	@abstract   Appends a resource, assigning an identifier when it has none.
	@return     The resource's identifier.
*/
- (NSString *)addResource:(FxGripFCPXMLResource *)resource;

/*! The effect for an FxPlug plug-in, added when absent. */
- (FxGripFCPXMLEffect *)effectForFxPlugUUID:(NSString *)pluginUUID name:(nullable NSString *)name;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLResources_h */
