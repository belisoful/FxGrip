/*!
	@file       FxGripPreset+FCPXML.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripPreset+FCPXML
	@abstract   Converts between a preset and an FCPXML filter.
	@discussion Introduced in FxGrip 0.1.0. A preset's parameter values become the `param`
	            children of a `filter-video`, keyed by parameter ID, and a filter's params become
	            a preset's values. The conversion needs no host; ``FxGripFCPXMLValue`` encodes each
	            value by its shape. ``FxGripFCPXMLAPI_v1`` adds the host-aware capture and apply.
*/

#ifndef FxGripPreset_FCPXML_h
#define FxGripPreset_FCPXML_h

#import <FxGrip/FxGripPreset.h>
#import <FxGrip/FxGripFCPXMLFilter.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@abstract   The preset to FCPXML conversions.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripPreset (FCPXML)

/*!
	@method     fcpxmlFilterWithEffectIdentifier:parameterNames:
	@abstract   A `filter-video` carrying the preset's values as params.
	@discussion Each value becomes a param whose `key` is the parameter ID and whose `name` is
				the name the dictionary supplies, or `Parameter <id>` when it supplies none. A
				custom value becomes a nested archive param. The filter's name is the preset's
				display name.
	@param      identifier	The effect resource identifier the filter references.
	@param      names		Display names keyed by parameter ID, or nil.
*/
- (FxGripFCPXMLFilter *)fcpxmlFilterWithEffectIdentifier:(NSString *)identifier
										  parameterNames:(nullable NSDictionary<NSNumber *, NSString *> *)names;

/*!
	@method     presetWithFCPXMLFilter:
	@abstract   A preset from a filter's params.
	@discussion A param whose key is a whole number contributes its value under that parameter
				ID; a param without a numeric key is skipped, because a preset keys by ID. A
				nested archive param decodes to its object. The plug-in UUID comes from the
				filter's effect resource when the filter sits in a document; the name comes from
				the filter's name override or name.
*/
+ (instancetype)presetWithFCPXMLFilter:(FxGripFCPXMLFilter *)filter;

/*! Writes one preset value into a param, as a value string or a nested archive. */
+ (void)writeValue:(nullable id)value toParam:(FxGripFCPXMLParam *)param;

/*! Reads a param's value as a preset value, decoding a nested archive with the allowed classes. */
+ (nullable id)valueFromParam:(FxGripFCPXMLParam *)param archiveClasses:(nullable NSSet<Class> *)classes;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPreset_FCPXML_h */
