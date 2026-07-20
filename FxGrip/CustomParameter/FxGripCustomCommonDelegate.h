//
//  FxGripCustomCommonDelegate.h
//  MetalFx ML Upscale
//
//  Created by ~ ~ on 2/29/24.
//

#ifndef FxGripCustomCommonDelegate_h
#define FxGripCustomCommonDelegate_h

#import <Foundation/Foundation.h>


/*!
 https://developer.apple.com/documentation/appkit/nscontroltexteditingdelegate/3005177-controltextdidchange?language=objc
	@interface  FxGripCustomCommonDelegate
	@abstract   Wraps the FxCustomParameterActionAPIv4 in a class that calls -startAction on
 				instancing, and endAction when dealloc.
	@discussion This is a utility call and should only be used when a custom view is called
 				by the OS outside the managed host connection for the plugin.
 				When the OS does UI callbacks on custom Parameter NSView[s], the plugin doesn't
 				know about or have access to the host parameters.  FxCustomParameterActionAPIv4
 				is used to connect to the host application outside the usual managed scope of the
 				FxTileableEffect protocol implementation call stack.
 */
@interface FxGripCustomCommonDelegate : NSObject


@end

#endif /* FxGripOOBParameterAccess */
