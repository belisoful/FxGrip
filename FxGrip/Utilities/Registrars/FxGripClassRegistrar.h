//
//  FxGripClassRegistrar.h
//  XPC Service
//
//  Created on 3/11/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripClassRegistrar_h
#define FxGripClassRegistrar_h

#ifndef kProPlugPlugInX_FxRegisteredPlugins_Property
	#define kProPlugPlugInX_FxRegisteredPlugins_Property		@"FxGripRegisteredPlugins"
#endif

#import "FxGripStaticRegistrar.h"

@interface FxGripClassRegistrar : FxGripStaticRegistrar

- (nullable id)plugInReferences;

@end


#endif
