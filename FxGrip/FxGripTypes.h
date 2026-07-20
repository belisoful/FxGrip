//
//  FxGripTypes.h
//  FxGrip
//
//  Created by ~ ~ on 2/27/24.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripTypes_h
#define FxGripTypes_h

#define kFxGripLibraryActivator true

#import "FxPlug/FxPlugSDK.h"
//#import <FxPlug/FxPlugSDK.h>
//#import <FxPlug/FxTypes.h>
#import <simd/simd.h>
#import <FxGrip/FxGripErrors.h>

// Todo for FxPlug API
/*
1) Parameter Flags Need flag if they are published
 // Is the parameter published by the motion effect template
 #define	kFxParameterFlag_PUBLISHED		(((long) 1) << 12)
 
 2) Parameter value can change when disabled, without needing to enable-change-disable
 
 3) dynamic parameter v4, get the type of the parameter
 	- add "- (FxParameterType)parameterType:(FxParameterId)
 
 4) Generate Tracker Data from plugin? how is it done in other plugins?, eg photogrammetry
 
 5) Setting 3D Environment from plugin?  setting camera-wiew position/matrix
 
 6) change FxParameterFlags to be FxParameterFlags64, and the top 32 bits are reserved for application
    use.  They are always saved and returned but unused by the host application.  They are not filtered
    by the host application.
 
 */

//#import "FxGripParameter.h"


//options for the preset, like ignoring meta, ignoring compatability, etc.
typedef UInt32	FxParameterPresetFlags;
typedef UInt32	FxParameterId;

#define phi (1.618033988749895)

#define kFxImageTileRequest_NoParameter 0
#define kMotionProjectDocumentId		0
#define kAspectRatio16x9 1.777777777777778

#define kProPlugDynamicRegistration_Property				@"ProPlugDynamicRegistration"
#define kProPlugDynamicRegistrationPrincipalClass_Property	@"ProPlugDynamicRegistrationPrincipalClass"

#ifndef kProPlugPlugInList_Property
	#define kProPlugPlugInList_Property							@"ProPlugPlugInList"
#endif

#ifndef kProPlugPlugIn_GroupList_Property
	#define kProPlugPlugIn_GroupList_Property				@"ProPlugPlugInGroupList"
#endif

// For FxGripClassRegistrar
#ifndef kProPlugPlugInX_FxRegisteredPlugins_Property
	#define kProPlugPlugInX_FxRegisteredPlugins_Property		@"FxRegisteredPlugins"
#endif

//PluginGroup list properties

#ifndef kProPlugPlugInX_RegGroupUUIDProperty
	#define kProPlugPlugInX_RegGroupUUIDProperty	@"uuid"
#endif
#ifndef kProPlugPlugInX_RegGroupNameProperty
	#define kProPlugPlugInX_RegGroupNameProperty	@"groupName"
#endif

//Plugin list properties
#define kProPlugPlugIn_UuidProperty				@"uuid"
#define kProPlugPlugIn_ClassNameProperty		@"className"
#define kProPlugPlugIn_DisplayNameProperty		@"displayName"
#define kProPlugPlugIn_GroupUUIDProperty		@"group"   //UUID
#define kProPlugPlugIn_ProtocolNamesProperty	@"protocolNames"
#define kProPlugPlugIn_InfoStringProperty		@"infoString"
#define kProPlugPlugIn_VersionProperty			@"version"		//eg. NSNumber 1000 = v1.0.0.0

#define kProPlugPlugInX_DefaultFontNameProperty	@"defaultFontName"
#define kProPlugPlugInX_PresetsProperty			@"presets"
#define kProPlugPlugInX_PriorUuidsProperty		@"priorUuids"
#define kProPlugPlugInX_EffectPropertiesProperty	@"effectProperties"
#define kProPlugPlugInX_OSCUUIDsProperty		@"osc"

//   array of plugin uuids tied to
#define kProPlugPlugIn_SupportedPluginsProperty	@"supportedPlugins"


#define kProPlugPlugInX_ParametersProperty		@"parameters"
// Default NO:
#define kProPlugPlugInX_DebugMenuProperty		@"debugMenu"
#define kProPlugPlugInX_DebugActivatorProperty	@"debugActivator"
//Default YES:
#define kProPlugPlugInX_ManagedMetaProperty		@"manageMeta"
//Default NO
#define kProPlugPlugInX_TrackInstancesProperty	@"trackInstances"
#define kProPlugPlugInX_InternationalizeProperty	@"internationalize"
#define kProPlugPlugInX_DelocalizeNamesProperty	@"delocalizenames"
#define kProPlugPlugInX_DelocalizeValuesProperty	@"delocalizevalues"
#define kProPlugPlugInX_DelocalizeMenusProperty	@"delocalizemenus"
#define kProPlugPlugInX_GoogleAnalyticsProperty	@"googleanalytics"

// FxPlug ProtocolNames
#define kProPlugPlugIn_ProtocolFxBaseEffect		@"FxBaseEffect"
#define kProPlugPlugIn_ProtocolFxFilter			@"FxFilter"
#define kProPlugPlugIn_ProtocolFxGenerator		@"FxGenerator"
#define kProPlugPlugIn_ProtocolFxOnScreenControl @"FxOnScreenControl"


// section and banner have "Help" links
// capsule, button, section has tool tips
// button customizing: text, style, font, font size, icon
//

#define kFxParameterProperty_ClassName	kProPlugPlugIn_ClassNameProperty
#define kFxParameterProperty_Factory	@"_factory"
#define kFxParameterProperty_ExtensionKey	@"_extKey"

#define kFxParameterProperty_Id			@"id"
#define kFxParameterProperty_Type		@"type"
#define kFxParameterProperty_Name		@"name"
#define kFxParameterProperty_Description	@"description"
#define kFxParameterProperty_Flags		@"flags"
#define kFxParameterProperty_Tags		@"tags"
#define kFxParameterProperty_Meta		@"meta"
#define kFxParameterPropertyX_PathID	@"pathid"
#define kFxParameterProperty_Default	@"default"
#define kFxParameterProperty_ResetValue	@"resetvalue"
#define kFxParameterProperty_ParentId	@"parentid"
#define kFxParameterProperty_TargetPrefix	@"target"
#define kFxParameterProperty_TargetPreset	@"targetpreset"
#define kFxParameterProperty_TargetPresetNames	@"names"
#define kFxParameterProperty_TargetPresetFlags	@"flags"
#define kFxParameterProperty_TargetPresetTags	@"tags"
#define kFxParameterProperty_TargetPresetValues	@"values"
#define kFxParameterProperty_Minimum	@"minimum"
#define kFxParameterProperty_Maximum	@"maximum"
#define kFxParameterProperty_SliderMinimum	@"slidermin"
#define kFxParameterProperty_SliderMaximum	@"slidermax"
#define kFxParameterProperty_Delta		@"delta"
#define kFxParameterProperty_Red		@"red"
#define kFxParameterProperty_Green		@"green"
#define kFxParameterProperty_Blue		@"blue"
#define kFxParameterProperty_Alpha		@"alpha"
#define kFxParameterProperty_ColorSpace	@"colorspace"
//pushbutton and help
#define kFxParameterProperty_Selector	@"selector"
#define kFxParameterProperty_SelectorObject @"selectorobject"
// "click*" methods need to use FxGripOOBParameterAccess to create a context within the FxPlug to access parameters and other objects.
// "menu*" methods are called within an existing FxPlug context and can start using the FxPlug API 
#define kFxParameterProperty_SelectorPrefix	@"click"
#define kFxParameterProperty_ManagePrefix	@"manage"
#define kFxParameterProperty_X			@"x"
#define kFxParameterProperty_Y			@"y"
#define kFxParameterProperty_MenuItems	@"items"
#define kFxParameterProperty_GroupParameters kProPlugPlugInX_ParametersProperty
#define kFxParameterProperty_GradientSamples @"gradientsamples"
#define kFxParameterProperty_GradientDepth @"gradientdepth"
#define kFxParameterProperty_GradientDepthType @"gradientdepthtype"

#define kFxParameterProperty_GradientDepth_UInt8 @"uchar"
#define kFxParameterProperty_GradientDepth_half16 @"half"
#define kFxParameterProperty_GradientDepth_float32 @"float"

typedef enum {
	FxGripDepthTypeNone = 0,
	FxGripDepthTypeFxDepth = 1,
	FxGripDepthTypeBytes = 2
} FxGripDepthType;

#define kFxParameterProperty_GradientDepthType_Bytes @"bytes"
#define kFxParameterProperty_GradientDepthType_FxDepth @"fxdepth"


// Histogram values
#define kFxParameterProperty_BlackIn	@"blackin"
#define kFxParameterProperty_BlackOut	@"blackout"
#define kFxParameterProperty_WhiteIn	@"whitein"
#define kFxParameterProperty_WhiteOut	@"whiteout"
#define kFxParameterProperty_Gamma		@"gamma"
// FxHistogramChannel
#define kFxParameterProperty_Channel	@"channel"

// counting parameters during loading
#define kFxParameterProperty_Index		@"index"


#define kFxParameterProperty_Time		@"time"

/*
 point with direction (w and w/o arrow end), magnitude (w and with circle)
 2 points, rect (option: rotate, scale, translate), line (w and w/o arrow), none.
 2 circles magnitude
 etc
 */

#if DEBUG
#define DebugLog(x, y) NSLog(@"%@(%lld)::%s %@", (self != nil) ? [self className] : @"<no self>", x, __func__, y)
#define DebugLog2(x, y, z) NSLog(@"%@(%lld)::%s %@ %@", [self className], x, __func__, y, z)
#else
	#define DebugLog(x, y)
	#define DebugLog2(x, y, z)
#endif


CG_INLINE CGRect
CGRectFromFxRect(FxRect fxRect)
{
  CGRect rect;
  rect.origin.x = fxRect.left; rect.origin.y = fxRect.bottom;
  rect.size.width = fxRect.right - fxRect.left; rect.size.height = fxRect.top - fxRect.bottom;
  return rect;
}

CG_INLINE FxRect
FxRectFromCGRect(CGRect cgRect)
{
  FxRect rect;
  rect.left = cgRect.origin.x ; rect.bottom = cgRect.origin.y;
  rect.right = cgRect.origin.x + cgRect.size.width; rect.top = cgRect.origin.y + cgRect.size.height;
  return rect;
}

// Double Structs
typedef __attribute__((__aligned__(16))) union FxGripDouble2 {
	union {
		struct {
			double x;
			double y;
		};
		struct {
			double gray;
			double alpha;
		};
		struct {
			double u;
			double v;
		};
	};
	simd_double2 vec;
	float f[2];
} FxGripDouble2;

typedef __attribute__((__aligned__(8))) union FxGripDouble3 {
	struct {
		union {
			double r;
			double red;
			double x;
		};
		union {
			double g;
			double green;
			double y;
		};
		union {
			double b;
			double blue;
			double z;
		};
	};
	simd_double3 vec;
	double f[3];
} FxGripDouble3;


typedef __attribute__((__aligned__(16))) union FxGripDouble4 {
	struct {
		union {
			double r;
			double red;
			double x;
		};
		union {
			double g;
			double green;
			double y;
		};
		union {
			double b;
			double blue;
			double z;
		};
		union {
			double a;
			double alpha;
			double w;
		};
	};
	simd_double4 vec;
	double f[4];
} FxGripDouble4;


// Float Structs
typedef __attribute__((__aligned__(8))) union FxGripFloat2 {
	union {
		struct {
			float x;
			float y;
		};
		struct {
			float gray;
			float alpha;
		};
		struct {
			float u;
			float v;
		};
	};
	simd_float2 vec;
	float f[2];
} FxGripFloat2;

typedef __attribute__((__aligned__(4))) union FxGripFloat3 {
	struct {
		union {
			float r;
			float red;
			float x;
		};
		union {
			float g;
			float green;
			float y;
		};
		union {
			float b;
			float blue;
			float z;
		};
	};
	simd_float3 vec;
	float f[3];
} FxGripFloat3;

typedef __attribute__((__aligned__(16))) union FxGripFloat4 {
	struct {
		union {
			float r;
			float red;
			float x;
		};
		union {
			float g;
			float green;
			float y;
		};
		union {
			float b;
			float blue;
			float z;
		};
		union {
			float a;
			float alpha;
			float w;
		};
	};
	simd_float4 vec;
	float f[4];
} FxGripFloat4;


// Half Structs
typedef __attribute__((__aligned__(4))) union FxGripHalf2 {
	union {
		struct {
			_Float16 x;
			_Float16 y;
		};
		struct {
			_Float16 gray;
			_Float16 alpha;
		};
		struct {
			_Float16 u;
			_Float16 v;
		};
	};
	simd_half2 vec;
	_Float16 f[2];
} FxGripHalf2;

typedef __attribute__((__aligned__(2))) union FxGripHalf3 {
	struct {
		union {
			_Float16 r;
			_Float16 red;
			_Float16 x;
		};
		union {
			_Float16 g;
			_Float16 green;
			_Float16 y;
		};
		union {
			_Float16 b;
			_Float16 blue;
			_Float16 z;
		};
	};
	simd_half3 vec;
	_Float16 f[3];
} FxGripHalf3;

typedef __attribute__((__aligned__(8))) union FxGripHalf4 {
	struct {
		union {
			_Float16 r;
			_Float16 red;
			_Float16 x;
		};
		union {
			_Float16 g;
			_Float16 green;
			_Float16 y;
		};
		union {
			_Float16 b;
			_Float16 blue;
			_Float16 z;
		};
		union {
			_Float16 a;
			_Float16 alpha;
			_Float16 w;
		};
	};
	simd_half4 vec;
	_Float16 f[4];
} FxGripHalf4;

//8 bit unsigned char
typedef __attribute__((__aligned__(2))) union FxGripUChar2 {
	union {
		struct {
			unsigned char x;
			unsigned char y;
		};
		struct {
			unsigned char gray;
			unsigned char alpha;
		};
		struct {
			unsigned char u;
			unsigned char v;
		};
	};
	simd_char2 vec;
	unsigned short s;
	unsigned char c[2];
} FxGripUChar2;

typedef __attribute__((__aligned__(1))) union FxGripUChar3 {
	struct {
		union {
			unsigned char r;
			unsigned char red;
			unsigned char x;
		};
		union {
			unsigned char g;
			unsigned char green;
			unsigned char y;
		};
		union {
			unsigned char b;
			unsigned char blue;
			unsigned char z;
		};
	};
	simd_char3 vec;
	unsigned char c[3];
} FxGripUChar3;

typedef __attribute__((__aligned__(4))) union FxGripUChar4 {
	struct {
		union {
			unsigned char r;
			unsigned char red;
			unsigned char x;
		};
		union {
			unsigned char g;
			unsigned char green;
			unsigned char y;
		};
		union {
			unsigned char b;
			unsigned char blue;
			unsigned char z;
		};
		union {
			unsigned char a;
			unsigned char alpha;
			unsigned char w;
		};
	};
	simd_char4 vec;
	unsigned long l;
	unsigned char c[4];
} FxGripUChar4;

#define kZeroVector2 {0.0, 0.0}
#define kZeroVector3 {0.0, 0.0, 0.0}
#define kZeroVector4 {0.0, 0.0, 0.0, 0.0}


// Custom types

typedef FxGripDouble2 FxGripPoint;
typedef FxGripDouble4 FxGripColor;

#define kFxGripWhiteTransparent {1.0, 1.0, 1.0, 0.0}
#define kFxGripWhiteOpaque {1.0, 1.0, 1.0, 1.0}
#define kFxGripBlackTransparent {0.0, 0.0, 0.0, 0.0}
#define kFxGripBlackOpaque {0.0, 0.0, 0.0, 1.0}

#define linearToGamma(x, g) (pow((x), (g)))
#define gammaToLinear(x, g) (pow((x), 1.0/(g)))

#define linearToGamma2(x, g) {pow(((x)[0]), (g)), pow(((x)[1]), (g))}
#define gammaToLinear2(x, g) {pow(((x)[0]), 1.0/(g)), pow(((x)[1]), 1.0/(g))}

#define linearToGamma3(x, g) {pow(((x)[0]), (g)), pow(((x)[1]), (g)), pow(((x)[2]), (g))}
#define gammaToLinear3(x, g) {pow(((x)[0]), 1.0/(g)), pow(((x)[1]), 1.0/(g)), pow(((x)[2]), 1.0/(g))}

#define linearToGamma4(x, g) {pow(((x)[0]), (g)), pow(((x)[1]), (g)), pow(((x)[2]), (g)), pow(((x)[3]), (g))}
#define gammaToLinear4(x, g) {pow(((x)[0]), 1.0/(g)), pow(((x)[1]), 1.0/(g)), pow(((x)[2]), 1.0/(g)), pow(((x)[3]), (g))}


typedef struct {
	double blackIn;
	double blackOut;
	double whiteIn;
	double whiteOut;
	double gamma;
	FxHistogramChannel	channel;
} FxGripChannelHistogram;

#define kZeroChannelHistogram {0.0, 0.0, 1.0, 1.0, 1.0, -1}

typedef __attribute__((__aligned__(16))) union {
	struct {
		union {
			struct {
				double blackIn;
				double blackOut;
				double whiteIn;
				double whiteOut;
				double gamma;
				FxHistogramChannel	channel;
			};
			FxGripChannelHistogram rgb;
		};
		union {
			FxGripChannelHistogram r;
			FxGripChannelHistogram red;
		};
		union {
			FxGripChannelHistogram g;
			FxGripChannelHistogram green;
		};
		union {
			FxGripChannelHistogram b;
			FxGripChannelHistogram blue;
		};
		union {
			FxGripChannelHistogram a;
			FxGripChannelHistogram alpha;
		};
	};
	FxGripChannelHistogram component[5]; // FxHistogramChannel 0=rgb 1=r 2=g 3=b 4=a
} FxGripHistogram;

#define kZeroHistogram { \
0.0, 0.0, 1.0, 1.0, 1.0, 0, \
0.0, 0.0, 1.0, 1.0, 1.0, 1, \
0.0, 0.0, 1.0, 1.0, 1.0, 2, \
0.0, 0.0, 1.0, 1.0, 1.0, 3, \
0.0, 0.0, 1.0, 1.0, 1.0, 4}

#define bytesFromFxDepth(depth) ((depth == kFxDepth_FLOAT32) ? 4 : ((depth == kFxDepth_FLOAT16) ? 2 : 1))

#define mtlPixelFormatFromFxDepth(depth) ((depth == kFxDepth_FLOAT32) ? MTLPixelFormatRGBA32Float : ((depth == kFxDepth_FLOAT16) ? MTLPixelFormatRGBA16Float : MTLPixelFormatRGBA8Unorm))

typedef struct {
	NSUInteger	count;
	FxDepth		depth; // 0 = 8b int, 2 = 16b half, 3 = 32b float
} FxGripGradientHeader;


typedef struct {
	union {
		struct {
			NSUInteger	count;
			FxDepth		depth; // 0 = 8b int, 2 = 16b half, 3 = 32b float
		};
		FxGripGradientHeader header;
	};
	FxGripFloat4		samples[];
} FxGripGradientFloat;


typedef struct {
	union {
		struct {
			NSUInteger	count;
			FxDepth		depth; // 0 = 8b int, 2 = 16b half, 3 = 32b float
		};
		FxGripGradientHeader header;
	};
	FxGripHalf4			samples[];
} FxGripGradientHalf;


typedef struct {
	union {
		struct {
			NSUInteger	count;
			FxDepth		depth; // 0 = 8b int, 2 = 16b half, 3 = 32b float
		};
		FxGripGradientHeader header;
	};
	
	FxGripUChar4		samples[];
} FxGripGradientUInt8;

typedef FxGripGradientFloat FxGripGradient;

#define kZeroGradient {0, 3}


typedef NS_ENUM(NSInteger, FxParameterType) {
	FxParameterType_None = 0,
	FxParameterType_Angle = 1,
	FxParameterType_RGBA = 2,
	FxParameterType_RGB = 3,
	FxParameterType_Custom = 4,
	FxParameterType_Float = 5,
	FxParameterType_FontMenu = 6,
	FxParameterType_Gradient = 7,
	FxParameterType_Help = 8,
	FxParameterType_Histogram = 9,
	FxParameterType_ImageRef = 10,
	FxParameterType_Int = 11,
	FxParameterType_PathID = 12,
	FxParameterType_Percent = 13,
	FxParameterType_Point = 14,
	FxParameterType_Menu = 15,
	FxParameterType_PushButton = 16,
	FxParameterType_String = 17,
	FxParameterType_Toggle = 18,
	FxParameterType_Group = 19,
	
	FxParameterType_Section		= 120,
	FxParameterType_Random		= 121,
	FxParameterType_Capsule		= 122,
	FxParameterType_Banner		= 123,
	FxParameterType_Presets		= 124,
	FxParameterType_Status		= 125, 	// Colored Dot with text
	FxParameterType_Progress	= 126,
	FxParameterType_Switch		= 127,
	FxParameterType_Divider		= 128,
	FxParameterType_WebView		= 129,	// can display links.
	FxParameterType_VideoView	= 130,	// can display videos.
	// https://developers.google.com/youtube/player_parameters
	
	//
	FxParameterType_Array = -1,
	FxParameterType_Dictionary = -2
};

#define kFxAllParameters				-2


// the Paramatere ID for None.  all other negative are invalid by the system.
// -1 is invalid except in FxGrip.
#define kFxParameterId_None					-1

// 0 is technically invalid and cannot be accessed, but is documented
// as the top level group container for all Plugin parameters.
#define kFxParameterId_TopLevelGroup		0


#define kFxParameterId_DebugActivator		(9996)
#define kFxParameterId_DebugMenu			(9997)
#define kFxParameterId_ParameterData		(9998)
#define kFxParameterId_ApplePluginData		(9999)		//Not accessible


//FxPlug Types for Parameters
#define kFxParameterType_Angle		@"angle"
#define kFxParameterType_RGBA		@"rgba"
#define kFxParameterType_RGB		@"rgb"
#define kFxParameterType_Custom		@"custom"
#define kFxParameterProperty_CustomClass	@"customClass"
#define kFxParameterProperty_CustomClasses	@"customClasses"
#define kFxParameterType_Float		@"float"
#define kFxParameterType_FontMenu	@"font"
#define kFxParameterType_FontNameDefault @"Helvetica"
#define kFxParameterType_Gradient	@"gradient"
#define kFxParameterType_Help		@"help"
#define kFxParameterProperty_CustomHelp		@"customHelp"
#define kFxParameterType_Histogram	@"histogram"
#define kFxParameterType_ImageRef	@"imageref"
#define kFxParameterType_Integer	@"integer"
#define kFxParameterType_PathID		@"path"
#define kFxParameterType_Percent	@"percent"
#define kFxParameterType_Point		@"point"
#define kFxParameterType_Menu		@"menu"
#define kFxParameterProperty_MenuLinks	 @"links"
#define kFxParameterType_PushButton	@"button"
#define kFxParameterProperty_ButtonTitle	@"title"
#define kFxParameterProperty_ButtonImageName @"imageName"
#define kFxParameterProperty_ButtonImageURL	@"imageUrl"
#define kFxParameterProperty_ButtonFont	@"font"
#define kFxParameterProperty_ButtonFontSize	@"size"
#define kFxParameterProperty_ButtonStyle	@"style"
#define kFxParameterType_String		@"string"
// multiline, default YES
#define kFxParameterProperty_MultiLine		@"multiline"
#define kFxParameterType_Toggle		@"toggle"
#define kFxParameterType_Group		@"group"



//Custom Types, TODO
#define kFxParameterType_Section	@"section"
#define kFxParameterType_Random		@"random"
#define kFxParameterType_Capsule	@"capsule"
#define kFxParameterType_Banner		@"banner"
// Preset adds a preset
#define kFxParameterType_Presets	@"presets"
#define kFxParameterType_Status		@"status"
#define kFxParameterType_Progress	@"progress"
#define kFxParameterType_Switch		@"switch"
#define kFxParameterType_Divider	@"divider"
#define kFxParameterType_WebView	@"webview"



#endif
