/*!
	@file       FxGripGradientParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGradientParameter
	@abstract   Implements the parameter model for a host gradient parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a gradient parameter, samples its color ramp into a heap buffer at a render time, and encodes the sampled gradient into the FxPlug plugin-state coder. The NSCoder category decodes the gradient and builds a Metal texture from it.
*/

#import "FxGripGradientParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/NSCoder+AtIndex.h>
#import "NSCoder+FxPlug.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The parameter model for a host gradient parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a gradient parameter, samples its color ramp at a render time, and encodes the samples into the plugin-state coder. The sampled gradient is held in a heap buffer that the parameter frees on the next sample and on deallocation.
*/
@implementation FxGripGradientParameter
{
	FxGripGradient *_gradient;
}

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Gradient;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Gradient;
}

- (void)dealloc
{
	if (_gradient) {
		free(_gradient);
		_gradient = nil;
	}
	SUPER_DEALLOC();
}


/*!
	@method		addParameter:toEffect:
	@abstract	Registers the gradient parameter with the effect's host.
	@param		parameter	The parameter configuration dictionary.
	@param		effect		The host that receives the parameter.
	@return		YES when the host creates the parameter. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addGradientWithName: parameter.parameterName
													   parameterID: parameter.parameterID
													parameterFlags: parameter.parameterFlags];
}

/*!
	@method		valueAtTime:
	@abstract	Samples the gradient at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		A pointer to the sampled gradient, or nil when the retrieval API fails.
	@discussion	Introduced in FxGrip 0.1.0. The method allocates a buffer sized for the sample count and depth, frees any prior buffer, and fills the header before reading the samples. */
- (FxGripGradient*)valueAtTime:(CMTime)renderTime NS_RETURNS_INNER_POINTER
{
	if (_gradient) {
		free(_gradient);
	}
	_gradient = malloc(4 * self.samples * self.byteDepth + sizeof(FxGripGradientHeader));
	_gradient->count = self.samples;
	_gradient->depth = self.fxDepth;
	if(![self.effect.apiManager.paramGetAPIv6 getGradientSamples:&_gradient->samples
							   numSamples:_gradient->count
									depth:_gradient->depth
							fromParameter:self.parameterID
								atTime:renderTime]) {
		return nil;
	}
	return _gradient;
}


/*!
	@method		encodeWithCoder:
	@abstract	Encodes the sampled gradient at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the gradient.
	@discussion	Introduced in FxGrip 0.1.0. The gradient encodes only when the coder is an FxPlug plugin-state encoder. The encoded length is the header size plus the sample bytes at the gradient's depth. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {

		FxGripGradient *gradient = [self valueAtTime:coder.renderTime];
		int samplesDepth = bytesFromFxDepth(gradient->depth);
		[coder encodeBytes:(void*)gradient length:sizeof(FxGripGradientHeader) + 4 * gradient->count * samplesDepth atIndex:self.parameterID];
	} else {
		// encode meta
	}
}

@end



/*!
	@abstract	The NSCoder additions that decode a gradient from the plugin-state coder.
	@discussion	Introduced in FxGrip 0.1.0. The category reads a gradient encoded by FxGripGradientParameter and builds a Metal texture from the decoded samples.
*/
@implementation NSCoder (FxGripGradient)

/*!
	@method		decodeGradientAtIndex:
	@abstract	Decodes a gradient from the coder at an index.
	@param		index	The parameter index the gradient was encoded at.
	@return		A pointer to the decoded gradient, or NULL when the coder is not a plugin-state encoder.
	@discussion	Introduced in FxGrip 0.1.0. A decoded length that does not match the header and sample sizes logs an error. */
- (nullable FxGripGradient *)decodeGradientAtIndex:(int64_t)index NS_RETURNS_INNER_POINTER
{
	if (self.isFxPluginStateEncoder) {
		NSUInteger size = 0;
		FxGripGradient *gradient = (FxGripGradient*)[self decodeBytesAtIndex:index returnedLength:&size];
		
		int samplesDepth = bytesFromFxDepth(gradient->depth);
		
		if (size != sizeof(FxGripGradientHeader) + 4 * gradient->count * samplesDepth) {
			NSLog(@"Error Gradient decoding is malformed and sizes are different.");
		}
		
		return gradient;
	} else {
		// encode meta
	}
	return NULL;
}


/*!
	@method		decodeGradientAtIndex:device:
	@abstract	Decodes a gradient and builds a Metal texture from it.
	@param		index	The parameter index the gradient was encoded at.
	@param		device	The Metal device that allocates the texture.
	@return		A texture one pixel tall and the sample count wide, in the pixel format for the gradient's depth. */
// A MTLTexture that is 1 pixel in height and number of Samples in width
- (nullable id<MTLTexture>) decodeGradientAtIndex:(int64_t)index device:(nonnull id<MTLDevice>)device NS_RETURNS_RETAINED
{
	FxGripGradient *gradient = [self decodeGradientAtIndex:index];
	
	MTLTextureDescriptor*   textureDescriptor   = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlPixelFormatFromFxDepth(gradient->depth)
																									 width:gradient->count
																									height:1
																								 mipmapped:NO];
	id<MTLTexture>  gradientTexture    = NARC_AUTORELEASE([device newTextureWithDescriptor:textureDescriptor]);
	MTLRegion   region = {
		{ 0, 0, 0 },
		{ gradient->count, 1, 1 }
	};
	int samplesDepth = bytesFromFxDepth(gradient->depth);
	[gradientTexture replaceRegion:region
					   mipmapLevel:0
						 withBytes:gradient->samples // float, half, or char
					   bytesPerRow:gradient->count * samplesDepth];
	
	return gradientTexture;
	
}

@end


