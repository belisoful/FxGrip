/*!
	@file       FxGripDividerData.m
	@copyright  Copyright © 2019-2023 Apple Inc. All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripDividerData
	@abstract   Implements the divider parameter value model and its API bridging.
	@discussion Introduced in FxGrip 0.1.0. The class seeds its width fraction and margins from a
	            configuration dictionary, and derives the parameter height from the margins. The
	            geometry setters push the change to the attached view. The float accessor maps to the
	            width fraction and the int accessor maps to the total parameter height for the
	            standard retrieval API.
*/

#import "FxGripDividerData.h"
#import "FxGripTypes.h"
#import <BEFoundation/FxTime.h>
#import "FxGrip_ARC.h"

// Locked makes the default keys for types (bool, int, float, etc) only settable if they are already set.
//  So the keys for the automatic var->custum->var must be set in the configuration to be usable,
//		or it must be unlocked.
/*!
	@abstract	The value model for a divider parameter: line width fraction and margins.
	@discussion	Introduced in FxGrip 0.1.0. The class holds the width fraction and margins, derives
				the parameter height, and bridges to the standard retrieval API. */
@implementation FxGripDividerData

@synthesize parameterEffect;
@synthesize parameterView;

//@synthesize percentWidth = _percentWidth;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
		_percentWidth = phi - 1.0;
		_marginTop = 7;
		_marginBottom = 12;
		_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
    }
    
    return self;
}

/*!
	@method		initWithDictionary:
	@abstract	Seeds the width fraction and margins from a configuration dictionary.
	@param		values	A dictionary that may carry width, margintop, and marginbottom entries.
	@discussion	Introduced in FxGrip 0.1.0. An absent entry keeps the default. */
- (instancetype)initWithDictionary:(NSDictionary*)values
{
	self = [self init];
	if (self != nil) {
		if (values[@"width"] != nil)
			_percentWidth = [values[@"width"] doubleValue];
		if (values[@"margintop"] != nil)
			_marginTop = [values[@"margintop"] intValue];
		if (values[@"marginbottom"] != nil)
			_marginBottom = [values[@"marginbottom"] intValue];
		_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
	}
	return self;
}

+ (instancetype)dataWithDictionary:(NSDictionary*)values
{
	return NARC_AUTORELEASE([FxGripDividerData.alloc initWithDictionary:values]);
}

#pragma mark -
#pragma mark NSSecureCoding & NSCopying

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	
	if (self != nil)
	{
		NSUInteger dataSize = 4;
		_percentWidth = *(FxGripDividerSize*)[aDecoder decodeBytesWithReturnedLength:&dataSize];
		_marginTop = *(uint16*)[aDecoder decodeBytesWithReturnedLength:&dataSize];
		_marginBottom = *(uint16*)[aDecoder decodeBytesWithReturnedLength:&dataSize];
		_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeBytes:&_percentWidth length:sizeof(FxGripDividerSize)];
	[aCoder encodeBytes:&_marginTop length:sizeof(uint16)];
	[aCoder encodeBytes:&_marginBottom length:sizeof(uint16)];
}

- (instancetype)copyWithZone:(NSZone *)zone
{
	FxGripDividerData*    newInstance = [[self.class alloc] init];
	
	newInstance.percentWidth = self.percentWidth;
	newInstance.marginTop = self.marginTop;
	newInstance.marginBottom = self.marginBottom;
	newInstance.parameterEffect = self.parameterEffect;
	newInstance.parameterView = self.parameterView;
	
	return newInstance;
}


- (BOOL)isEqual:(NSObject<NSSecureCoding, NSCopying>*)object
{
	if (self == (id)object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripDividerData.class]) {
		return NO;
	}
	FxGripDividerData*    rhs = (FxGripDividerData*)object;

	return _percentWidth == rhs.percentWidth && _marginTop == rhs.marginTop && _marginBottom == rhs.marginBottom;
}

- (NSUInteger)hash
{
	return [NSNumber numberWithDouble:_percentWidth].hash ^ ((NSUInteger)_marginTop << 16) ^ _marginBottom;
}


- (void)setPercentWidth:(FxGripDividerSize)percentWidth
{
	_percentWidth = percentWidth;
	
	if (self.parameterView != nil && [self.parameterView conformsToProtocol:@protocol(FxGripCustomViewDataDelegate)]) {
		
		[(NSView<FxGripCustomViewDataDelegate>*)self.parameterView updateFromCustomData:self];
	}
}


- (void)setMarginTop:(uint16)marginTop
{
	_marginTop = marginTop;
	_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;

	if (self.parameterView != nil && [self.parameterView conformsToProtocol:@protocol(FxGripCustomViewDataDelegate)]) {
		
		[(NSView<FxGripCustomViewDataDelegate>*)self.parameterView updateFromCustomData:self];
	}
}


- (void)setMarginBottom:(uint16)marginBottom
{
	_marginBottom = marginBottom;
	_parameterHeight = _marginTop + kFxGripBoxDividerHeight + _marginBottom;
	
	if (self.parameterView != nil && [self.parameterView conformsToProtocol:@protocol(FxGripCustomViewDataDelegate)]) {
		
		[(NSView<FxGripCustomViewDataDelegate>*)self.parameterView updateFromCustomData:self];
	}
}


- (void)setParameterHeight:(uint16)parameterHeight
{
	_parameterHeight = parameterHeight;
	// A height below the divider itself leaves no margin; unsigned subtraction would
	// wrap to 65535.
	uint16 margins = parameterHeight > kFxGripBoxDividerHeight ? parameterHeight - kFxGripBoxDividerHeight : 0;
	_marginTop = margins >> 1;
	_marginBottom = margins - _marginTop;
	
	if (self.parameterView != nil && [self.parameterView conformsToProtocol:@protocol(FxGripCustomViewDataDelegate)]) {
		
		[(NSView<FxGripCustomViewDataDelegate>*)self.parameterView updateFromCustomData:self];
	}
}


#pragma mark -
#pragma mark API Parameter Access


/*! Reads the line width fraction for the standard retrieval API. */
- (BOOL)getFloatValue:(double*)floatValue
{
	*floatValue = _percentWidth;
	
	return YES;
}

- (BOOL)setFloatValue:(double)floatValue
{
	self.percentWidth = floatValue;
	
	return YES;
}

/*! Reads the total parameter height for the standard retrieval API. */
- (BOOL)getIntValue:(int*)intValue
{
	*intValue = _parameterHeight;
	
	return YES;
}

- (BOOL)setIntValue:(int)intValue
{
	self.parameterHeight = intValue;
	
	return YES;
}


@end
