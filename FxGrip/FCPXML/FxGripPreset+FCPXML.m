/*!
	@file       FxGripPreset+FCPXML.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripPreset+FCPXML
	@abstract   Converts between a preset and an FCPXML filter.
	@discussion Introduced in FxGrip 0.1.0. See FxGripPreset+FCPXML.h.
*/

#import <FxGrip/FxGripPreset+FCPXML.h>
#import <FxGrip/FxGripFCPXMLValue.h>
#import <FxGrip/FxGripFCPXMLResources.h>

@implementation FxGripPreset (FCPXML)

- (FxGripFCPXMLFilter *)fcpxmlFilterWithEffectIdentifier:(NSString *)identifier
										  parameterNames:(NSDictionary<NSNumber *, NSString *> *)names
{
	FxGripFCPXMLFilter *filter = [FxGripFCPXMLFilter videoFilterWithEffectIdentifier:identifier name:self.name];
	NSDictionary *values = self.parameterValues;
	NSArray *keys = [values.allKeys sortedArrayUsingComparator:^NSComparisonResult(id lhs, id rhs) {
		return [@([lhs integerValue]) compare:@([rhs integerValue])];
	}];
	for (id key in keys) {
		NSInteger parameterID = [key integerValue];
		NSString *name = names[@(parameterID)] ?: [NSString stringWithFormat:@"Parameter %ld", (long)parameterID];
		FxGripFCPXMLParam *param = [FxGripFCPXMLParam paramWithName:name
																key:[NSString stringWithFormat:@"%ld", (long)parameterID]
															  value:nil];
		[FxGripPreset writeValue:values[key] toParam:param];
		[filter addParam:param];
	}
	return filter;
}

+ (instancetype)presetWithFCPXMLFilter:(FxGripFCPXMLFilter *)filter
{
	FxGripPreset *preset = [[self alloc] init];
	NSMutableDictionary *values = [NSMutableDictionary dictionary];
	for (FxGripFCPXMLParam *param in filter.params) {
		NSString *key = param.key;
		NSScanner *scanner = [NSScanner scannerWithString:key ?: @""];
		NSInteger parameterID = 0;
		if (key.length == 0 || ![scanner scanInteger:&parameterID] || !scanner.isAtEnd) {
			continue;
		}
		id value = [self valueFromParam:param archiveClasses:nil];
		if (value != nil) {
			values[[NSString stringWithFormat:@"%ld", (long)parameterID]] = value;
		}
	}
	preset.parameterValues = values;
	preset.name = filter.nameOverride ?: filter.filterName;
	preset.framework = @"FxGrip";
	preset.uuid = NSUUID.UUID.UUIDString;
	NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
	preset.createdTime = [formatter stringFromDate:NSDate.date];
	FxGripFCPXMLEffect *effect = filter.effect;
	preset.pluginUuid = effect.fxPlugUUID;
	preset.pluginLocalizedName = effect.resourceName;
	return preset;
}

+ (void)writeValue:(id)value toParam:(FxGripFCPXMLParam *)param
{
	FxParameterType type = [FxGripFCPXMLValue inferredTypeForValue:value];
	NSString *string = [FxGripFCPXMLValue stringForValue:value type:type];
	if (string != nil) {
		param.value = string;
		return;
	}
	NSString *archive = [FxGripFCPXMLValue archiveStringForObject:value];
	if (archive == nil) {
		return;
	}
	FxGripFCPXMLParam *nested = [param subparamNamed:FxGripFCPXMLValueArchiveParamName];
	if (nested == nil) {
		nested = [FxGripFCPXMLParam paramWithName:FxGripFCPXMLValueArchiveParamName key:nil value:nil];
		[param addSubparam:nested];
	}
	nested.value = archive;
	nested.auxValue = FxGripFCPXMLValueArchiveMarker;
}

+ (id)valueFromParam:(FxGripFCPXMLParam *)param archiveClasses:(NSSet<Class> *)classes
{
	FxGripFCPXMLParam *nested = [param subparamNamed:FxGripFCPXMLValueArchiveParamName];
	if (nested != nil && [nested.auxValue isEqualToString:FxGripFCPXMLValueArchiveMarker]) {
		return [FxGripFCPXMLValue objectForArchiveString:nested.value classes:classes];
	}
	return [FxGripFCPXMLValue valueForString:param.value type:FxParameterType_None];
}

@end
