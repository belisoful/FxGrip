/*!
	@file       FxGripPathParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPathParameter
	@abstract   Implements the parameter model for a host path picker.
	@discussion Introduced in FxGrip 0.1.0. The class registers a path picker through the parameter-creation API and reads its FxPathID at a render time. It encodes the identifier into the FxPlug plugin-state coder.
*/

#import "FxGripPathParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "NSCoder+FxPlug.h"

/*!
	@abstract	The parameter model for a host path picker.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a path picker, reads its path identifier at a render time, and encodes the identifier into the plugin-state coder.
*/
@implementation FxGripPathParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_PathID;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_PathID;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Registers the path picker with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addPathPickerWithName: parameter.parameterName
														 parameterID: parameter.parameterID
													  parameterFlags: parameter.parameterFlags];
}

/*!
	@method		valueAtTime:
	@abstract	Reads the path identifier at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		The path identifier, or nil when FxParameterRetrievalAPI_v6 is unavailable.
	@discussion	Introduced in FxGrip 0.1.0. A retrieval failure sets the parameter's error. */
-(FxPathID _Nullable) valueAtTime:(CMTime)renderTime
{
	FxPathID pathValue = nil;
	if(![self.effect.apiManager.paramGetAPIv6 getPathID:&pathValue fromParameter:self.parameterID atTime:renderTime]) {
		_error = [NSError errorWithDomain:FxGripPlugErrorDomain
									 code:kFxGripParameterErrorBool
								 userInfo:@{ NSLocalizedFailureReasonErrorKey : @"Unable to obtain the FxParameterRetrievalAPI_v6" }];
	}
	return pathValue;
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the path identifier at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the identifier.
	@discussion	Introduced in FxGrip 0.1.0. The identifier encodes only when the coder is an FxPlug plugin-state encoder. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		FxPathID pathId = [self valueAtTime:coder.renderTime];
		[coder encodeBytes:(void*)&pathId length:sizeof(pathId) atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

@end
