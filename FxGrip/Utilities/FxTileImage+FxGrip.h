//
//  FxTileImage+FxGrip.h
//  XPC Service
//
//  Created by ~ ~ on 3/19/24.
//

#ifndef FxTileImage_FxGrip_h
#define FxTileImage_FxGrip_h

#import <FxPlug/FxPlugSDK.h>


@interface FxImageTile (FxGrip)

@property (readonly, nonatomic) id<MTLDevice>   device;

@property (readonly) OSType pixelFormat;

//@property (readonly) MTLPixelFormat glPixelFormat;

@property (readonly) MTLPixelFormat metalPixelFormat;

- (id<MTLTexture>)metalTexture;

@end



#endif	//	NSCoder_AtIndex_AtTime
