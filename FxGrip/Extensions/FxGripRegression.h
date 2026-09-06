/*!
	@file       FxGripRegression.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripRegression
	@abstract   The extension that validates a plugin's plist properties at load time.
	@discussion Introduced in FxGrip 0.1.0. A DEBUG-only pass that reports problems with the plugin's
	            UUID and version, and the FxFactory update security policy. It reports and continues;
	            it never blocks the plugin from loading.
*/

#ifndef FxGripRegression_h
#define FxGripRegression_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

/*!
	@class		FxGripRegression
	@abstract	The extension that runs the plist validation pass.
	@discussion	Introduced in FxGrip 0.1.0. The checks run on load and report each problem.
*/
@interface FxGripRegression : FxGripExtension

@end



/*!
	@abstract	The effect-side accessors for the regression extension.
	@discussion	Introduced in FxGrip 0.1.0. isRegression reads the plugin property that gates the
				extension in DEBUG builds.
*/
@interface FxGripTileableEffect (Regression)

/*! The installed regression extension, or nil when none is installed. */
@property (readonly, nullable, nonatomic) FxGripRegression* regression;

/*! YES when the plugin opts into the regression validation pass via the "regression"
	property; the loader gates on this (DEBUG builds only). */
@property (readonly, nonatomic) BOOL isRegression;

/*! Creates the regression extension instance for the loader to install. */
- (nonnull FxGripRegression*)newRegressionExtension;

@end

#endif
