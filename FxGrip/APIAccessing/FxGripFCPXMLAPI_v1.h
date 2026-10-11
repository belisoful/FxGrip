/*!
	@file       FxGripFCPXMLAPI_v1.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLAPI_v1
	@abstract   Captures the effect as an FCPXML filter and applies an FCPXML filter to it.
	@discussion Introduced in FxGrip 0.1.0. The API is FxGrip's own, in the style of Apple's FxPlug
	            APIs; no host vends it. A capture reads every runtime parameter into a
	            `filter-video` whose params are keyed by parameter ID and named by the parameter
	            name, with keyframes read through the host's keyframe API when it vends one. An
	            apply matches params by key, then by name, and writes the values through the
	            presets API so the compatibility check and the tag boundary hold; keyframed params
	            are written at each keyframe time, with host keyframes added when the keyframe API
	            is vended. The effect resource's uid is `FxPlug:` followed by the plug-in UUID,
	            which is how Final Cut Pro names an FxPlug effect.
*/

#ifndef FxGripFCPXMLAPI_v1_h
#define FxGripFCPXMLAPI_v1_h

#import <FxPlug/FxPlugSDK.h>
#import <FxGrip/FxGripCommonAPI.h>
#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripFCPXMLDocument.h>
#import <FxGrip/FxGripFCPXMLFilter.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@enum       FxGripFCPXMLCaptureOptions
	@abstract   Options that shape a capture.
	@discussion Introduced in FxGrip 0.1.0.
*/
typedef NS_OPTIONS(NSUInteger, FxGripFCPXMLCaptureOptions) {
	/*! Values at the capture time, every parameter that carries a value, no custom values. */
	FxGripFCPXMLCaptureDefault				= 0,
	/*! Read keyframes through `FxKeyframeAPI_v3` and write a `keyframeAnimation` per animated param. */
	FxGripFCPXMLCaptureKeyframes			= 1 << 0,
	/*! Leave out parameters the host hides. */
	FxGripFCPXMLCaptureOmitHidden			= 1 << 1,
	/*! Write custom parameter values as nested archive params. */
	FxGripFCPXMLCaptureCustomValues			= 1 << 2,
};

/*!
	@enum       FxGripFCPXMLApplyOptions
	@abstract   Options that relax an apply.
	@discussion Introduced in FxGrip 0.1.0.
*/
typedef NS_OPTIONS(NSUInteger, FxGripFCPXMLApplyOptions) {
	/*! Match by key, require a compatible effect, apply keyframes, honor the tag boundary. */
	FxGripFCPXMLApplyDefault				= 0,
	/*! Apply a filter whose effect names another plug-in. */
	FxGripFCPXMLApplyIgnoreCompatibility	= 1 << 0,
	/*! Match a param by name when its key names no parameter. */
	FxGripFCPXMLApplyMatchNames				= 1 << 1,
	/*! Write only each param's initial value; leave keyframe animations unread. */
	FxGripFCPXMLApplyIgnoreKeyframes		= 1 << 2,
	/*! Write a parameter the tag boundary would exclude. */
	FxGripFCPXMLApplyIgnoreTagBoundary		= 1 << 3,
	/*! Bracket the writes in one undo group through `FxUndoAPI`. */
	FxGripFCPXMLApplyUndoGroup				= 1 << 4,
};

/*!
	@protocol   FxGripFCPXMLAPI_v1
	@abstract   The FCPXML capture and apply layer, in the style of Apple's FxPlug APIs.
	@discussion Introduced in FxGrip 0.1.0. FxGrip's own API; no host vends it.
				``FxGripFCPXMLAPI_v1-class`` is the implementation.
*/
@protocol FxGripFCPXMLAPI_v1 <NSObject>

/*! The effect uid Final Cut Pro writes for this plug-in: `FxPlug:` and the plug-in UUID. */
- (NSString *)effectUID;

/*! A new, unattached `effect` resource for this plug-in, named by its display name. */
- (FxGripFCPXMLEffect *)effectResource;

/*!
	@method     captureFilter:atTime:options:
	@abstract   Captures the effect's parameters as a `filter-video`.
	@discussion The filter references no effect resource until it is added to a document;
				`captureDocument:atTime:options:` does both.
	@param      filter	On return, the filter.
	@param      time	The time the values are read at.
	@param      options	See ``FxGripFCPXMLCaptureOptions``.
	@return     The error that stopped the capture, or nil.
*/
- (nullable NSError *)captureFilter:(FxGripFCPXMLFilter * _Nullable * _Nonnull)filter
							 atTime:(CMTime)time
							options:(FxGripFCPXMLCaptureOptions)options;

/*!
	@method     captureDocument:atTime:options:
	@abstract   Captures the effect into a document: the effect resource and one clip carrying the filter.
	@discussion The clip is named after the plug-in and lasts the effect's duration, or one second
				when the host reports none. The document is a container for the filter, for a
				file, a pasteboard, or the workflow mailbox; Final Cut Pro imports it as a clip.
*/
- (nullable NSError *)captureDocument:(FxGripFCPXMLDocument * _Nullable * _Nonnull)document
							   atTime:(CMTime)time
							  options:(FxGripFCPXMLCaptureOptions)options;

/*!
	@method     applyFilter:atTime:options:
	@abstract   Writes a filter's params into the effect's parameters.
	@discussion A param whose key is a parameter ID the effect holds writes that parameter; with
				`FxGripFCPXMLApplyMatchNames`, a param whose key matches nothing writes the
				parameter of the same name. Values write at `time`; a keyframe animation writes
				its keyframes at their own times. A filter whose effect resource names another
				plug-in is refused unless `FxGripFCPXMLApplyIgnoreCompatibility`; a filter in no
				document, which references no resource, is accepted.
	@return     The error that stopped the apply, or nil.
*/
- (nullable NSError *)applyFilter:(FxGripFCPXMLFilter *)filter
						   atTime:(CMTime)time
						  options:(FxGripFCPXMLApplyOptions)options;

/*!
	@method     applyDocument:atTime:options:
	@abstract   Applies the first compatible filter in a document.
	@discussion With `FxGripFCPXMLApplyIgnoreCompatibility` the first video filter applies.
*/
- (nullable NSError *)applyDocument:(FxGripFCPXMLDocument *)document
							 atTime:(CMTime)time
							options:(FxGripFCPXMLApplyOptions)options;

/*! YES when the filter's effect names this plug-in or one of its `supportedPlugins`, or when the
	filter references no resolvable effect. */
- (BOOL)isCompatibleFilter:(FxGripFCPXMLFilter *)filter;

/*! The video filters in a document whose effect names this plug-in or a supported plug-in. */
- (NSArray<FxGripFCPXMLFilter *> *)compatibleFiltersInDocument:(FxGripFCPXMLDocument *)document;

/*! A preset from a filter, labeled; the plug-in identity is this effect's. */
- (FxGripPreset *)presetFromFilter:(FxGripFCPXMLFilter *)filter label:(nullable NSString *)label;

/*! A filter from a preset, referencing the plug-in's effect resource in a document; the resource
	is added to the document when absent. A nil document yields a filter referencing `r1`. */
- (FxGripFCPXMLFilter *)filterFromPreset:(FxGripPreset *)preset inDocument:(nullable FxGripFCPXMLDocument *)document;

@end

/*!
	@interface  FxGripFCPXMLAPI_v1
	@abstract   The FCPXML capture and apply layer.
	@discussion Introduced in FxGrip 0.1.0. FxGrip implements this API itself; no host vends it,
				so the wrapper is constructed without a host API.
*/
@interface FxGripFCPXMLAPI_v1 : FxGripCommonAPI <FxGripFCPXMLAPI_v1>

/*! The wrapped API, which stays nil because FxGrip implements the FCPXML API itself. */
@property (assign, readonly, nullable) id<FxGripFCPXMLAPI_v1> api;

/*!
	@method     initWithAPI:effect:
	@abstract   Creates the FCPXML API for an effect.
	@param      api		Unused; no host vends an FCPXML API, so callers pass nil.
	@param      effect	The effect whose parameters the API captures and applies.
	@return     The API, or nil when it cannot be built.
*/
- (nullable instancetype)initWithAPI:(nullable id<FxGripFCPXMLAPI_v1>)api
							  effect:(id<FxGripEffectHost>)effect;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLAPI_v1_h */
