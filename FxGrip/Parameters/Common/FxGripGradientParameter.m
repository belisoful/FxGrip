/*!
	@file       FxGripGradientParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripGradientParameter
	@abstract   Implements the parameter model for a host gradient parameter.
	@discussion Introduced in FxGrip 0.1.0. The class registers a gradient parameter, samples its color ramp into a new buffer at a render time, and encodes the sampled gradient into the FxPlug plugin-state coder. The NSCoder category decodes the gradient and builds a Metal texture from it.
*/

#import "FxGripGradientParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import <BEFoundation/NSCoder+AtIndex.h>
#import "NSCoder+FxPlug.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The parameter model for a host gradient parameter.
	@discussion	Introduced in FxGrip 0.1.0. The class registers a gradient parameter, samples its color ramp at a render time, and encodes the samples into the plugin-state coder. Each sample fills a new buffer, so concurrent plugin-state calls do not share a gradient.
*/
@implementation FxGripGradientParameter

+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Gradient;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Gradient;
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
	@method		gradientDataAtTime:
	@abstract	Samples the gradient at a render time into a new buffer.
	@param		renderTime	The time to sample the parameter at.
	@return		The gradient header followed by the samples, or nil when the retrieval API fails.
	@discussion	Introduced in FxGrip 0.1.0. The buffer holds samples count of RGBA samples at the fxDepth component size. The method reads samples and fxDepth once, so the header always matches the buffer. The method is safe to call concurrently. */
- (nullable NSData *)gradientDataAtTime:(CMTime)renderTime
{
	NSUInteger count = self.samples;
	FxDepth depth = self.fxDepth;
	NSMutableData *data = [NSMutableData dataWithLength:sizeof(FxGripGradientHeader) + 4 * count * bytesFromFxDepth(depth)];
	FxGripGradient *gradient = data.mutableBytes;
	gradient->count = count;
	gradient->depth = depth;
	if (![self.effect.apiManager.paramGetAPIv6 getGradientSamples:gradient->samples
													   numSamples:count
															depth:depth
													fromParameter:self.parameterID
														   atTime:renderTime]) {
		return nil;
	}
	return data;
}

/*!
	@method		valueAtTime:
	@abstract	Samples the gradient at a render time.
	@param		renderTime	The time to sample the parameter at.
	@return		A pointer to the sampled gradient, valid until the enclosing autorelease pool drains, or nil when the retrieval API fails.
	@discussion	Introduced in FxGrip 0.1.0. The gradient lives in the autoreleased buffer gradientDataAtTime: returns, so the method is safe to call concurrently. */
- (FxGripGradient*)valueAtTime:(CMTime)renderTime NS_RETURNS_INNER_POINTER
{
	// The autorelease pool owns the buffer for the lifetime of the returned pointer.
	__autoreleasing NSData *data = [self gradientDataAtTime:renderTime];
	return (FxGripGradient *)data.bytes;
}

/*!
	@method		encodeWithCoder:
	@abstract	Encodes the sampled gradient at the coder's render time into the plugin-state coder.
	@param		coder	The coder that receives the gradient.
	@discussion	Introduced in FxGrip 0.1.0. The gradient encodes only when the coder is an FxPlug plugin-state encoder and the read succeeds. The encoded length is the header size plus the sample bytes at the gradient's depth. */
- (void)encodeWithCoder:(NSCoder *_Nonnull)coder
{
	[super encodeWithCoder:coder];

	if (coder.isFxPluginStateEncoder) {
		NSData *gradient = [self gradientDataAtTime:coder.renderTime];
		if (gradient) {
			[coder encodeBytes:gradient.bytes length:gradient.length atIndex:self.parameterID];
		}
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


