/*!
	@file       FxGripKernelTestSupport.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-14
	@header     FxGripKernelTestSupport
	@abstract   The checked-in kernel fixtures and the slangc lookup shared by the kernel suites.
	@discussion Introduced in FxGrip 0.1.0. The fixtures are Slang kernels written against GripKernel
	            and the Metal source and reflection JSON slangc v2026.19 emitted for them, so every
	            suite runs with no slangc. GripBlur is the Kernels DocC article's worked example.
	            GripInspect writes one bound value per MODE into the destination, so a test reads a
	            binding back as pixels. A test that needs slangc finds it through FXGRIP_SLANGC, then
	            the PATH, and skips when neither has it.
*/

#ifndef FxGripKernelTestSupport_h
#define FxGripKernelTestSupport_h

#import <Foundation/Foundation.h>
#import <FxGrip/FxGripShaderMetadata.h>
#import <FxGrip/FxGripKernelLayout.h>
#import <FxGrip/FxGripKernelPipeline.h>

NS_ASSUME_NONNULL_BEGIN

/*! The URL of a fixture file in the test bundle; nil when the bundle has none. */
NSURL *_Nullable FxGripKernelTestFixtureURL(NSString *name, NSString *extension);

/*! The Slang source of a fixture kernel. */
NSString *FxGripKernelTestSlangSource(NSString *name);

/*! The Metal source slangc emitted for a fixture kernel. */
NSString *FxGripKernelTestMetalSource(NSString *name);

/*! The reflection JSON slangc emitted for a fixture kernel. */
NSData *FxGripKernelTestLayoutData(NSString *name);

/*! The reflection JSON of a fixture kernel after a block edits its mutable object tree, serialized again. */
NSData *FxGripKernelTestEditedLayoutData(NSString *name, void (^edit)(NSMutableDictionary *root));

/*! The layout of a fixture kernel; nil with the error when it fails to read. */
FxGripKernelLayout *_Nullable FxGripKernelTestLayout(NSString *name, NSError *_Nullable *_Nullable error);

/*! The metadata scanned from a fixture kernel's Slang source; nil with the error when it fails to scan. */
FxGripShaderMetadata *_Nullable FxGripKernelTestMetadata(NSString *name, NSError *_Nullable *_Nullable error);

/*! A pipeline of its own for a fixture kernel, with the given Metal source, JSON, and metadata when non-nil, and the fixture's otherwise. */
FxGripKernelPipeline *_Nullable FxGripKernelTestPipeline(NSString *name,
														 NSString *_Nullable metalSource,
														 NSData *_Nullable layoutData,
														 FxGripShaderMetadata *_Nullable metadata);

/*! The URL of the GripKernel.slang the FxGrip framework ships; nil when the framework has none. */
NSURL *_Nullable FxGripKernelTestModuleURL(void);

/*! The slangc executable named by FXGRIP_SLANGC or found on the PATH; nil when neither has one. */
NSString *_Nullable FxGripKernelTestSlangcPath(void);

NS_ASSUME_NONNULL_END

#endif /* FxGripKernelTestSupport_h */
