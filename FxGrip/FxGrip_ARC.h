/*!
	@file       FxGrip_ARC.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGrip_ARC
	@abstract   Memory-management macros that compile under both ARC and manual retain/release.
	@discussion Introduced in FxGrip 0.1.0. FxPlug hosts load plugins that may be built either way, so
	            the framework's retain, release, autorelease, dealloc, and block-copy operations go
	            through these macros. Under ARC each macro expands to a no-op or a plain assignment;
	            under manual retain/release each expands to the matching runtime call.
*/

#ifndef FxGrip_ARC_h
#define FxGrip_ARC_h

#if __has_feature(objc_arc)

	#define NARC_RETAIN(obj)				(obj)
	#define NARC_AUTORELEASE(obj)			(obj)
	#define NARC_RETAIN_AUTORELEASE(obj)	(obj)
	#define NARC_RELEASE(obj)				(obj = nil)
	#define NARC_RELEASE_RAW(obj)
	#define SUPER_DEALLOC()
	#define BLOCK_COPY(block)   			[(block) copy]
	#define BLOCK_RELEASE(block)   			((block) = nil)

#else

	#define NARC_RETAIN(obj)				[(obj) retain]
	#define NARC_AUTORELEASE(obj)			[(obj) autorelease]
	#define NARC_RETAIN_AUTORELEASE(obj)	[[(obj) retain] autorelease]
	#define NARC_RELEASE(obj)				([(obj) release], obj = nil)
	#define NARC_RELEASE_RAW(obj)			[(obj) release]
	#define SUPER_DEALLOC() 				[super dealloc]
	#define BLOCK_COPY(block)   			Block_copy(block)
	#define BLOCK_RELEASE(block)   { if (block) { Block_release(block); block = nil; } }

#endif


#endif	//	BPS_ARC_h
