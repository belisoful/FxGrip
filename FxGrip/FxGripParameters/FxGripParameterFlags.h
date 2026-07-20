//
//  FxGripParameterFlags.h
//  FxGrip 
//
//  Created by ~ ~ on 2/29/24.
//

#ifdef FxGripParameterFlags_h
//#ifndef FxGripParameterFlags_h
#define FxGripParameterFlags_h

#import <FxPlug/FxPlugSDK.h>

typedef union FxGripParameterFlags {
	struct {
		unsigned int notAnimatable:1;		//	bit 0
		unsigned int hidden:1;				//	bit 1
		unsigned int disabled:1;			//	bit 2
		unsigned int collapsed:1;			//	bit 3
		unsigned int dontSave:1;			//	bit 4
		unsigned int dontDisplayInDashboard:1;	//	bit 5
		
		unsigned int customUI:1;			//	bit 6
			unsigned int _reserved7:1;		//	bit 7
		unsigned int ignoreMinMax:1;		//	bit 8
		unsigned int curveEditorHidden:1;	//	bit 9
		unsigned int dontRemapColors:1;		//	bit 10
		unsigned int useFullViewWidth:1;	//	bit 11
		
			unsigned int _reserved12:1;		//	bit 12
			unsigned int _reserved13:1;		//	bit 13
			unsigned int _reserved14:1;		//	bit 14
			unsigned int _reserved15:1;		//	bit 15
			unsigned int _reserved16:1;		//	bit 16
			unsigned int _appleReserved17:1;		//	bit 17 - we don't kow what this is
			unsigned int _reserved18:1;		//	bit 18
			unsigned int _reserved19:1;		//	bit 19
			unsigned int _reserved20:1;		//	bit 20
			unsigned int _reserved21:1;		//	bit 21
		
		unsigned int saving:1;				//	bit 22
		unsigned int cacheDirty:1;			//	bit 23
		unsigned int cache:1;				//	bit 24
		
		unsigned int hiddenProxy:1;			//	bit 25
		unsigned int inDebugMode:1;			//	bit 26
		unsigned int noDebug:1;				//	bit 27
		
		unsigned int noRenderState:1;		//	bit 28
		
/* needed? */	unsigned int presetNoMeta:1;	//	bit 29
/* ditto */		unsigned int presetNoTags:1;	//	bit 30
		
		unsigned int invalid:1;			//	bit 31
	};
	FxParameterFlags	flags;

} FxGripParameterFlags;

#define gfxFlags(flags) ((FxGripParameterFlags)flags)
#define fxFlags(flags) ((FxParameterFlags)flags)


// Requires 64 bit integers.
/* #if __LP64__
	typedef UInt64 FxParameterFlags64;
	#define	kFxParameterFlag_CACHE		(((FxParameterFlags64) 1) << 32)
	#define	kFxParameterFlag_CACHEDIRTY	(((FxParameterFlags64) 1) << 33)
	#define	kFxParameterFlag_PRESETNOMETA	(((FxParameterFlags64) 1) << 34)

	#define	kFxParameterFlag_NO_DEBUG		(((FxParameterFlags64) 1) << 35)
	#define	kFxParameterFlag_IN_DEBUG_MODE	(((FxParameterFlags64) 1) << 36)
	#define	kFxParameterFlag_HIDDEN_PROXY	(((FxParameterFlags64) 1) << 37)

	#define	kFxParameterFlag_FX_MASK			((FxParameterFlags64) 0xFFFFFFFF)
	#define	kFxParameterFlag_APP_MASK		((FxParameterFlags64) 0xFFFFFFFF00000000)
	#define kFxParameterFlag_INVALID		((FxParameterFlags64) -1)
#else */
	typedef FxParameterFlags FxParameterFlags64;

	#define kFxParameterFlag_INVALID		(((FxParameterFlags64) 1) << 31)

	#define	kFxParameterFlag_PRESETNOMETA	(((FxParameterFlags64) 1) << 30)
	#define	kFxParameterFlag_PRESETNOTAGS	(((FxParameterFlags64) 1) << 29)
	#define	kFxParameterFlag_NOSTATE		(((FxParameterFlags64) 1) << 28)

// NO_DEBUG is to not show the parameter in debugmode
	#define	kFxParameterFlag_NO_DEBUG		(((FxParameterFlags64) 1) << 27)
	#define	kFxParameterFlag_IN_DEBUG_MODE	(((FxParameterFlags64) 1) << 26)
    #define	kFxParameterFlag_HIDDEN_PROXY	(((FxParameterFlags64) 1) << 25)

// All of the above bits are in this mask.
	#define	kFxParameterFlag_APP_MASK		((FxParameterFlags64) 0xFE000000)
    #define	kFxParameterFlag_FX_MASK			(~ kFxParameterFlag_APP_MASK)

//Real time flags - CHANGED and VALUEUPDATED are not saved, masked off by APP_MASK
	// This is used when the parameter meta has changed, like its flags but has not
	//	yet been saved to state.
	#define	kFxParameterFlag_CACHE		(((FxParameterFlags64) 1) << 24)
	#define	kFxParameterFlag_CACHEDIRTY	(((FxParameterFlags64) 1) << 23)
	//This is when setting the flags inside the
	#define	kFxParameterFlag_SAVING			(((FxParameterFlags64) 1) << 22)


#define SavingFlags(flags)  (flags | kFxParameterFlag_SAVING)
#define UnsavingFlags(flags)  (flags & ~kFxParameterFlag_SAVING)

#define RemoveTempFlags(flags)  (flags & ~(kFxParameterFlag_SAVING | kFxParameterFlag_CACHE | kFxParameterFlag_CACHEDIRTY))


// We don't know what this is yet.
	#define	kFxParameterFlag_UNKNOWN_APPLE_FLAG	(((FxParameterFlags64) 1) << 17)

#define flagInvalid(x)			((x & kFxParameterFlag_INVALID) != 0)
#define flagNoMeta(x)			((x & kFxParameterFlag_PRESETNOMETA) != 0)
#define flagNoTags(x)			((x & kFxParameterFlag_PRESETNOTAGS) != 0)
#define flagNoState(x)			((x & kFxParameterFlag_NOSTATE) != 0)
#define flagNoDebug(x)			((x & kFxParameterFlag_NO_DEBUG) != 0)
#define flagInDebugMode(x)		((x & kFxParameterFlag_IN_DEBUG_MODE) != 0)
#define flagHiddenProxy(x)		((x & kFxParameterFlag_HIDDEN_PROXY) != 0)

#define flagCache(x)			((x & kFxParameterFlag_CACHE) != 0)
#define flagCacheDirty(x)		((x & kFxParameterFlag_CACHEDIRTY) != 0)
#define flagSaving(x)			((x & kFxParameterFlag_SAVING) != 0)

// Apple Flags
#define flagIsDefault(x)		((x & kFxParameterFlag_DEFAULT) != 0)
#define flagNotAnimatable(x)	((x & kFxParameterFlag_NOT_ANIMATABLE) != 0)
#define flagHidden(x)			((x & kFxParameterFlag_HIDDEN) != 0)
#define flagDisabled(x)			((x & kFxParameterFlag_DISABLED) != 0)
#define flagCollapsed(x)		((x & kFxParameterFlag_COLLAPSED) != 0)
#define flagDontSave(x)			((x & kFxParameterFlag_DONT_SAVE) != 0)
#define flagDontDisplay(x)		((x & kFxParameterFlag_DONT_DISPLAY_IN_DASHBOARD) != 0)
#define flagCustomUI(x)			((x & kFxParameterFlag_CUSTOM_UI) != 0)
#define flagIgnoreMinMax(x)		((x & kFxParameterFlag_IGNORE_MINMAX) != 0)
#define flagCurveEditorHidden(x)((x & kFxParameterFlag_CURVE_EDITOR_HIDDEN) != 0)
#define flagDontRemapColors(x)	((x & kFxParameterFlag_DONT_REMAP_COLORS) != 0)
#define flagUseFullViewWidth(x)	((x & kFxParameterFlag_USE_FULL_VIEW_WIDTH) != 0)


//#endif

#define FxParameterFlagsFxMask(m) ((FxParameterFlags)(kFxParameterFlag_FX_MASK & (m)))
#define FxParameterFlagsAppMask(m) ((FxParameterFlags)(kFxParameterFlag_APP_MASK & (m)))
#define FxParameterAddFlag(flags, f) {if (!(flags & f)) {flags |= f; flags |= kFxParameterFlag_CACHE; }}
#define FxParameterRemoveFlag(flags, f) {if (flags & f) {flags &= ~f; flags |= kFxParameterFlag_CACHE; }}
#define FxParameterSetFlagOn(flags, f, on) {if (on) { FxParameterAddFlag(flags, f); } else { FxParameterRemoveFlag(flags, f); }}

#define kFxParameterFlag_DEBUG_UNHIDE		kFxParameterFlag_IN_DEBUG_MODE

#define kParameterFlagString_NOT_ANIMATABLE			@"notanimatable"
#define kParameterFlagString_HIDDEN					@"hidden"
#define kParameterFlagString_DISABLED				@"disabled"
#define kParameterFlagString_COLLAPSED				@"collapsed"
#define kParameterFlagString_DONT_SAVE				@"dontsave"
#define kParameterFlagString_DONT_DISPLAY			@"dontdisplay"
#define kParameterFlagString_CUSTOM_UI				@"customui"
#define kParameterFlagString_IGNORE_MIN_MAX			@"ignoreminmax"
#define kParameterFlagString_CURVE_EDITOR_HIDDEN	@"curveeditorhidden"
#define kParameterFlagString_DONT_REMAP_COLORS		@"dontremapcolors"
#define kParameterFlagString_FULL_VIEW_WIDTH		@"fullviewwidth"

// @todo move these to tags
#define kParameterFlagString_PRESETNOMETA			@"presetnometa"
#define kParameterFlagString_PRESETNOTAGS			@"presetnotags"
#define kParameterFlagString_NO_STATE				@"nostate"
#define kParameterFlagString_NO_DEBUG				@"nodebug"
#define kParameterFlagString_IN_DEBUG_MODE			@"indebugmode"
#define kParameterFlagString_HIDDEN_PROXY			@"hiddenproxy"

#endif /* FxGripParameterFlags_h */
