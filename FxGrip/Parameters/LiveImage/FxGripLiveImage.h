/*!
	@file       FxGripLiveImage.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripLiveImage
	@abstract   The value dictionary keys and defaults for the live image parameter's configuration.
	@discussion Introduced in FxGrip 0.1.0. A live image control's value carries only its
	            configuration; the pixels it shows are published in-process and never reach the host
	            document. The labels array names each slot and sets the slot count. The remaining keys
	            set the row height, info caption, checkerboard, vertical flip, and snapshot size.
*/

#ifndef FxGripLiveImage_h
#define FxGripLiveImage_h

#import <Foundation/Foundation.h>
#import "FxGripDictionary.h"

// A live image control's value carries only its configuration; the pixels it shows are
// published in-process and never reach the host document. The labels array names each
// slot and sets the slot count; the slots key sets the count when no labels are given.
#define kFxGripLiveImageKey_Labels			@"labels"
#define kFxGripLiveImageKey_Slots			@"slots"
#define kFxGripLiveImageKey_Height			@"height"
#define kFxGripLiveImageKey_ShowInfo		@"showInfo"
#define kFxGripLiveImageKey_Checkerboard	@"checkerboard"
#define kFxGripLiveImageKey_Flip			@"flip"
#define kFxGripLiveImageKey_SnapshotSize	@"snapshotSize"

#define kFxGripLiveImageDefaultHeight		(120.0)
/*! The default longest side, in pixels, of the snapshot read back from a published texture. */
#define kFxGripLiveImageDefaultSnapshotSize	(640)

#endif
