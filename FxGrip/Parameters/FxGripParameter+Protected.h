/*!
	@file       FxGripParameter+Protected.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-11
	@header     FxGripParameter+Protected
	@abstract   The framework-internal writable error property of the parameter root classes.
	@discussion Introduced in FxGrip 0.1.0. The header is project visibility and is absent from the
	            umbrella header. FxGripParameter.m and FxGripParameterExtension.m import it so the
	            synthesized error accessors include an atomic setter. Parameter classes import it to
	            record a failed host call through that setter, because FxPlug calls
	            pluginState:atTime:quality:error: on several threads at once.
*/

#ifndef FxGripParameter_Protected_h
#define FxGripParameter_Protected_h

#import <FxGrip/FxGripParameter.h>
#import <FxGrip/FxGripParameterExtension.h>

NS_ASSUME_NONNULL_BEGIN

/*! @abstract The writable error property of FxGripParameterBase and its subclasses. */
@interface FxGripParameterBase ()
/*! @abstract The error from the most recent failed host call, or nil. The atomic setter is safe to call from concurrent render threads. */
@property (readwrite, retain, nullable) NSError *error;
@end

/*! @abstract The writable error property of FxGripParameterExtension and its subclasses. */
@interface FxGripParameterExtension ()
/*! @abstract The error from the most recent failed host call, or nil. The atomic setter is safe to call from concurrent render threads. */
@property (readwrite, retain, nullable) NSError *error;
@end

NS_ASSUME_NONNULL_END

#endif /* FxGripParameter_Protected_h */
