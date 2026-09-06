/*!
	@file       FxGripTileableEffect+ProjectProperties.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripTileableEffect+ProjectProperties
	@abstract   The category that reads the host project's document, host, aspect ratio, and media folder.
	@discussion Introduced in FxGrip 0.1.0. The category reads project attributes through the host
	            project API. The document ID distinguishes Final Cut Pro, where each instance has a
	            document ID, from Motion, where it is 0. Each attribute has an error-returning form
	            and a convenience form that logs the error and returns a default.
*/

#ifndef FxGripTileableEffect_ProjectProperties_h
#define FxGripTileableEffect_ProjectProperties_h

#import <Foundation/Foundation.h>
#import "FxGripTileableEffect.h"

/*!
	@abstract	The category exposing the host project's attributes to the effect.
	@discussion	Introduced in FxGrip 0.1.0. A document ID of 0 identifies a Motion project.
*/
@interface FxGripTileableEffect (ProjectProperties)

/*! The plugin instance's document ID; 0 in Motion, a per-instance value in Final Cut Pro. */
@property (readonly)			NSUInteger	projectDocumentID;
/*! YES when the host project is Motion, identified by a document ID of 0. */
@property (readonly)			BOOL		isProjectMotion;
/*! YES when the host project is Final Cut Pro, identified by a non-zero document ID. */
@property (readonly)			BOOL		isProjectFinalCutPro;
/*! The project's aspect ratio; defaults to 16x9 when the host does not report one. */
@property (readonly)			float		projectAspectRatio;
/*! The project's media folder URL, or nil when the host reports none. */
@property (readonly, nullable)	NSURL*		projectMediaFolder;

/*! @abstract The document ID, returning any host error. */
- (NSUInteger)projectDocumentIDWithError:(NSError *_Nullable *_Nullable)error;
/*! @abstract The media folder URL, returning any host error. */
- (nullable NSURL *)projectMediaFolderWithError:(NSError *_Nullable *_Nullable)error;
/*! @abstract The project aspect ratio, returning any host error. */
- (float) projectAspectRatioWithError:(NSError *_Nullable *_Nullable)error;

@end

#endif /* ProjectProperties */
