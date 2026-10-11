/*!
	@file       FxGripFCPXMLFilter.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLFilter
	@abstract   The `filter-video`, `filter-audio`, and `filter-video-mask` elements.
	@discussion Introduced in FxGrip 0.1.0. A filter applies an `effect` resource to its parent
	            story element, with `param` children for the effect's parameters and up to two
	            `data` children (`effectData`, `effectConfig`) for opaque effect state. A
	            `filter-video-mask` wraps a video filter in shape or color masks. This is the
	            element an FxPlug effect occupies in a Final Cut Pro project.
*/

#ifndef FxGripFCPXMLFilter_h
#define FxGripFCPXMLFilter_h

#import <FxGrip/FxGripFCPXMLElement.h>
#import <FxGrip/FxGripFCPXMLParam.h>

@class FxGripFCPXMLEffect;

NS_ASSUME_NONNULL_BEGIN

/*! The `data` key Final Cut Pro uses for opaque effect state. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLDataKeyEffectData;
/*! The `data` key Final Cut Pro uses for an effect's configuration. */
FOUNDATION_EXPORT NSString *const FxGripFCPXMLDataKeyEffectConfig;

/*!
	@class      FxGripFCPXMLData
	@abstract   A `data` element: a keyed chunk of base64 data.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLData : FxGripFCPXMLElement

/*! The data key. */
@property (readwrite, copy, nullable) NSString *key;
/*! The decoded bytes; nil when the content is not base64. */
@property (readwrite, copy, nullable) NSData *data;

/*! A data element with a key and bytes. */
+ (instancetype)dataWithKey:(NSString *)key data:(NSData *)data;

@end

/*!
	@class      FxGripFCPXMLFilter
	@abstract   A `filter-video` or `filter-audio`.
	@discussion Introduced in FxGrip 0.1.0. Params are addressed by key first and by name
				second, because a key identifies a parameter across localizations.
*/
@interface FxGripFCPXMLFilter : FxGripFCPXMLElement

/*! The identifier of the effect resource (`ref`). */
@property (readwrite, copy, nullable) NSString *effectIdentifier;
/*! The effect's name as shown in the inspector. */
@property (readwrite, copy, nullable) NSString *filterName;
/*! The user's override of the effect's name. */
@property (readwrite, copy, nullable) NSString *nameOverride;
/*! YES unless `enabled="0"`. */
@property (readwrite) BOOL enabled;
/*! The audio preset identifier, for a `filter-audio`. */
@property (readwrite, copy, nullable) NSString *presetIdentifier;
/*! YES for a `filter-video`. */
@property (readonly) BOOL isVideo;
/*! YES for a `filter-audio`. */
@property (readonly) BOOL isAudio;

/*! The params, in document order. */
@property (readonly, copy) NSArray<FxGripFCPXMLParam *> *params;
/*! The data elements, in document order. */
@property (readonly, copy) NSArray<FxGripFCPXMLData *> *dataElements;

/*! A video filter for an effect resource identifier. */
+ (instancetype)videoFilterWithEffectIdentifier:(nullable NSString *)identifier name:(nullable NSString *)name;
/*! An audio filter for an effect resource identifier. */
+ (instancetype)audioFilterWithEffectIdentifier:(nullable NSString *)identifier name:(nullable NSString *)name;

/*! The param with a key, or nil. */
- (nullable FxGripFCPXMLParam *)paramWithKey:(NSString *)key;
/*! The param with a name, or nil. */
- (nullable FxGripFCPXMLParam *)paramNamed:(NSString *)name;
/*! The param with a key, else the param with a name, or nil. */
- (nullable FxGripFCPXMLParam *)paramWithKey:(nullable NSString *)key orName:(nullable NSString *)name;
/*! Appends a param after the last param, keeping data elements first. */
- (void)addParam:(FxGripFCPXMLParam *)param;
/*! Removes a param. */
- (void)removeParam:(FxGripFCPXMLParam *)param;
/*! Sets a param's value, creating the param when absent; matches by key, then by name. */
- (FxGripFCPXMLParam *)setValue:(nullable NSString *)value forParamNamed:(NSString *)name key:(nullable NSString *)key;

/*! The data element with a key, or nil. */
- (nullable FxGripFCPXMLData *)dataForKey:(NSString *)key;
/*! Sets the data for a key, creating the element when absent; nil removes it. */
- (void)setData:(nullable NSData *)data forKey:(NSString *)key;

/*! The effect resource the filter references, resolved through the document, or nil. */
@property (readonly, nullable) FxGripFCPXMLEffect *effect;

@end

/*!
	@class      FxGripFCPXMLFilterMask
	@abstract   A `filter-video-mask`: a video filter restricted to shape or color masks.
	@discussion Introduced in FxGrip 0.1.0. The mask shapes are generic elements named
				`mask-shape` and `mask-isolation`.
*/
@interface FxGripFCPXMLFilterMask : FxGripFCPXMLElement

/*! YES unless `enabled="0"`. */
@property (readwrite) BOOL enabled;
/*! YES when the mask is inverted. */
@property (readwrite) BOOL inverted;
/*! The mask elements, `mask-shape` and `mask-isolation`. */
@property (readonly, copy) NSArray<FxGripFCPXMLElement *> *masks;
/*! The filter applied inside the mask, or nil. */
@property (readonly, nullable) FxGripFCPXMLFilter *innerFilter;
/*! The color-correction filter applied outside the mask, or nil. */
@property (readonly, nullable) FxGripFCPXMLFilter *outerFilter;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLFilter_h */
