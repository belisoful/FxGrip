/*!
	@file       FxGripDividerBox.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDividerBox
	@abstract   Implements the separator box that draws a divider parameter's line.
	@discussion Introduced in FxGrip 0.1.0. The box centers itself within its superview at the width
	            fraction and margins from the parameter value. updateFromCustomData: accepts an
	            FxGripDividerData or a plain dictionary and resizes the box and its container. The
	            margin and height setters keep the derived parameter height in sync.
*/

#import "FxGripDividerBox.h"
#import "FxGripDividerData.h"
#import "FxGripTypes.h"
#import "FxGrip_ARC.h"

/*!
	@abstract	The separator box backing a divider parameter, centered in a sizing container.
	@discussion	Introduced in FxGrip 0.1.0. The box reads its width fraction and margins from the
				pushed value and lays itself out centered in the container. */
@implementation FxGripDividerBox

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_percentWidth = phi - 1.0;
		_marginTop = 7;
		_marginBottom = 12;
		_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
		
		self.boxType = NSBoxSeparator;
		self.autoresizingMask = (NSViewWidthSizable | NSViewMinXMargin | NSViewMaxXMargin);
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_topView);
	
	SUPER_DEALLOC();
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview
{
	CGRect superFrame = newSuperview.frame;
	double offset = superFrame.size.width * (1.0 - _percentWidth) / 2.0;
	CGRect newFrame = NSMakeRect(offset, _marginBottom, superFrame.size.width * _percentWidth, kFxGripBoxDividerHeight);
	self.frame = newFrame;
}


/*!
	@method		updateFromCustomData:
	@abstract	Applies the width fraction and margins from the pushed value and resizes the box.
	@param		value	An FxGripDividerData or a dictionary with percentWidth, marginTop, and marginBottom.
	@discussion	Introduced in FxGrip 0.1.0. A change to the geometry updates the container height and
				re-centers the box. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:[FxGripDividerData class]] && ![value isKindOfClass:[NSDictionary class]])
		return;
	BOOL changed = NO;
	if ([value isKindOfClass:[FxGripDividerData class]]) {
		FxGripDividerData *data = (id)value;
		
		if (_percentWidth != data.percentWidth) {
			_percentWidth = data.percentWidth;
			changed = YES;
		}
		if (_marginTop != data.marginTop) {
			_marginTop = data.marginTop;
			changed = YES;
		}
		if (_marginBottom != data.marginBottom) {
			_marginBottom = data.marginBottom;
			changed = YES;
		}
	} else {
		NSDictionary *data = (NSDictionary*)value;
		
		NSNumber *num = data[@"percentWidth"];
		if (num && _percentWidth != num.doubleValue) {
			_percentWidth = num.doubleValue;
			changed = YES;
		}
		num = data[@"marginTop"];
		if (num && _marginTop != num.unsignedShortValue) {
			_marginTop = num.unsignedShortValue;
			changed = YES;
		}
		num = data[@"marginBottom"];
		if (num && _marginBottom != num.unsignedShortValue) {
			_marginBottom = num.unsignedShortValue;
			changed = YES;
		}
	}
	if (changed) {
		_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
		
		if (_topView != nil) {
			[self updateViewHeight];
		}
		[self viewWillMoveToSuperview:self.superview];
	}
}

/*! Lazily builds the full-width container that holds the centered separator box. */
- (NSView *)topView
{
	if (_topView == nil) {
		_topView = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 100, _parameterHeight)];
		
		_topView.autoresizingMask = (NSViewWidthSizable | NSViewMinXMargin | NSViewMaxXMargin) | (NSViewMinYMargin | NSViewMaxYMargin);
		[_topView addSubview:self];
	}
	return _topView;
}


- (void)setPercentWidth:(FxGripDividerSize)percentWidth
{
	_percentWidth = percentWidth;
	[self viewWillMoveToSuperview:self.superview];
}


- (void)setMarginTop:(uint16)marginTop
{
	_marginTop = marginTop;
	
	[self updateViewHeight];
}


- (void)setMarginBottom:(uint16)marginBottom
{
	_marginBottom = marginBottom;
	
	[self updateViewHeight];
	[self viewWillMoveToSuperview:self.superview];
}


- (void)setParameterHeight:(uint16)parameterHeight
{
	_parameterHeight = parameterHeight;
	_marginTop = (parameterHeight - kFxGripBoxDividerHeight) >> 1;
	_marginBottom = parameterHeight - _marginTop - kFxGripBoxDividerHeight;
	
	[self updateViewHeight];
	[self viewWillMoveToSuperview:self.superview];
}

- (void)updateViewHeight
{
	_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
	
	CGRect newFrame = NSMakeRect(_topView.frame.origin.x, _topView.frame.origin.y, _topView.frame.size.width, _parameterHeight);
	_topView.frame = newFrame;
}

@end
