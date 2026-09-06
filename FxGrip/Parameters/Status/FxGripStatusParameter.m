/*!
	@file       FxGripStatusParameter.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripStatusParameter
	@abstract   Implements the read-only status indicator view and its custom parameter.
	@discussion Introduced in FxGrip 0.1.0. The view lays out a BEDotView and a label, and
	            updateFromCustomData: drives the dot state and label text from the parameter's
	            FxGripDictionary value. The parameter creates the custom control and seeds its
	            default state and label from the declaration.
*/

#import "FxGripStatusParameter.h"
#import "FxGripTileableEffect.h"
#import "NSDictionary+FxGripTileableEffect.h"
#import "FxGripDictionary.h"
#import "FxGrip_ARC.h"
#import <BEFoundation/BEDotView.h>

// Layout, in view points.
static const CGFloat kFxGripStatusDotSize = 12.0;
static const CGFloat kFxGripStatusGap = 6.0;

/*!
	@abstract	The status indicator view: a colored dot and a trailing label.
	@discussion	Introduced in FxGrip 0.1.0. The view is flipped and lays the dot at the left edge
				with the label running to the trailing edge. */
@implementation FxGripStatusView
{
	BEDotView *_dot;
	NSTextField *_label;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_dot = [BEDotView.alloc initWithFrame:NSMakeRect(0, 0, kFxGripStatusDotSize, kFxGripStatusDotSize)];
		[_dot setState:BEDotStateOff];
		[self addSubview:_dot];

		_label = [NSTextField labelWithString:@""];
		_label.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		_label.lineBreakMode = NSLineBreakByTruncatingTail;
		[self addSubview:_label];

		[self layoutContents];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

/*! Pins the dot at the left, vertically centered, and runs the label to the trailing edge. */
- (void)layoutContents
{
	CGFloat midY = self.bounds.size.height / 2.0;
	_dot.frame = NSMakeRect(0, midY - kFxGripStatusDotSize / 2.0, kFxGripStatusDotSize, kFxGripStatusDotSize);

	CGFloat labelX = kFxGripStatusDotSize + kFxGripStatusGap;
	CGFloat labelHeight = ceil(_label.intrinsicContentSize.height);
	_label.frame = NSMakeRect(labelX, midY - labelHeight / 2.0,
							  MAX(0, self.bounds.size.width - labelX), labelHeight);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[super resizeSubviewsWithOldSize:oldSize];
	[self layoutContents];
}

/*!
	@method		updateFromCustomData:
	@abstract	Redraws the dot and label from the parameter's FxGripDictionary value.
	@param		value	The parameter value; ignored when it is not an FxGripDictionary.
	@discussion	Introduced in FxGrip 0.1.0. The integer value sets the dot's BEDotState and the
				string value sets the label text. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripDictionary.class]) {
		return;
	}
	FxGripDictionary *dictionary = (FxGripDictionary*)value;

	int state = BEDotStateOff;
	if ([dictionary getIntValue:&state]) {
		[_dot setState:(BEDotState)state];
	}
	NSString *text = nil;
	if ([dictionary getStringParameterValue:&text]) {
		_label.stringValue = text ?: @"";
	}
}

@end


/*!
	@abstract	The read-only status indicator custom parameter.
	@discussion	Introduced in FxGrip 0.1.0. The parameter creates the custom control, seeds its
				default state and label from the declaration, and builds the status view. */
@implementation FxGripStatusParameter

/*! @abstract The registry type string for the status parameter. */
+ (nullable NSString*)parameterTypeString
{
	return kFxParameterType_Status;
}

+ (FxParameterType)parameterType
{
	return FxParameterType_Status;
}

/*! @abstract The value classes the custom parameter decodes: FxGripDictionary and its element classes. */
+ (NSSet<Class> *_Nullable)customValueClasses
{
	NSMutableSet *classes = [NSMutableSet setWithObject:FxGripDictionary.class];
	[classes unionSet:FxGripDictionary.classesForParameter.set];
	return classes;
}

/*!
	@method		addParameter:toEffect:
	@abstract	Creates the status custom parameter on the effect.
	@return		YES when the host creates the parameter.
	@discussion	Introduced in FxGrip 0.1.0. The declared default may set the initial dot state and
				label. Creation adds the custom-UI and no-state flags. */
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxGripEffectHost>)effect
{
	// The declared default may set the initial dot state (an integer) and label (a string).
	NSNumber *state = @(BEDotStateOff);
	NSString *text = @"";
	NSDictionary *declared = parameter.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		if ([declared[kCustomAPI_IntKey] isKindOfClass:NSNumber.class]) {
			state = declared[kCustomAPI_IntKey];
		}
		if ([declared[kCustomAPI_StringKey] isKindOfClass:NSString.class]) {
			text = declared[kCustomAPI_StringKey];
		}
	}

	FxGripDictionary *defaultValue = [FxGripDictionary dictionaryWithDictionary:@{
		kCustomAPI_IntKey: state,
		kCustomAPI_StringKey: text,
	}];

	return [effect.apiManager.paramCreateAPIv5
		addCustomParameterWithName: parameter.parameterName
					   parameterID: parameter.parameterID
					  defaultValue: defaultValue
					parameterFlags: parameter.parameterFlags | kFxParameterFlag_CUSTOM_UI | kFxParameterFlag_NOSTATE];
}

/*!
	@method		newParameterView
	@abstract	Creates the status view and seeds it from the declared default value.
	@return		A new FxGripStatusView.
	@discussion	Introduced in FxGrip 0.1.0. The host pushes the live value after attaching, so the
				view seeds from the declared default. */
- (NSView *_Nullable)newParameterView
{
	FxGripStatusView *view = [FxGripStatusView.alloc initWithFrame:NSMakeRect(0, 0, 200, 20)];
	NSDictionary *declared = _data.parameterDefaultValue;
	if ([declared isKindOfClass:NSDictionary.class]) {
		// The host pushes the live value after attaching; seed from the declared default.
		[view updateFromCustomData:[FxGripDictionary dictionaryWithDictionary:declared]];
	}
	return view;
}

@end
