//
//  FxGripGradientParameter.m
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripGradientParameter.h"
#import "FxTileableEffectBase.h"
#import "NSDictionary+FxTileableEffect.h"
#import <BEFoundation/NSCoder+AtIndex.h>
#import "NSCoder+FxPlug.h"
#import "FxGrip_ARC.h"

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


+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	return [effect.apiManager.paramCreateAPIv5 addGradientWithName: parameter.parameterName
													   parameterID: parameter.parameterID
													parameterFlags: parameter.parameterFlags];
}

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



@implementation NSCoder (FxGripGradient)

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


