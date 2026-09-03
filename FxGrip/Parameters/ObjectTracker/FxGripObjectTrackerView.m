//
//  FxGripObjectTrackerView.m
//  FxGrip
//
//  Copyright © 2026 Belisoful All rights reserved.
//

#import "FxGripObjectTrackerView.h"
#import "FxGripObjectTrackerData.h"
#import "FxGripOOBParameterAccess.h"

static const CGFloat kRowHeight = 22.0;
static const CGFloat kRowGap = 4.0;
static const CGFloat kLabelWidth = 78.0;

@implementation FxGripObjectTrackerView
{
	NSPopUpButton *_shapePopUp;
	NSPopUpButton *_behaviorPopUp;
	NSPopUpButton *_resolutionPopUp;
	NSStepper *_smoothingStepper;
	NSTextField *_smoothingValue;
	NSTextField *_statusLabel;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_shapePopUp = [self addPopUpWithItems:@[@"Rectangle", @"Convex Quadrilateral"]
									   action:@selector(shapeChanged:)];
		_behaviorPopUp = [self addPopUpWithItems:@[@"Position", @"Position and Scale"]
										 action:@selector(behaviorChanged:)];
		_resolutionPopUp = [self addPopUpWithItems:@[@"Full", @"Half"]
										   action:@selector(resolutionChanged:)];

		_smoothingStepper = [[NSStepper alloc] initWithFrame:NSZeroRect];
		_smoothingStepper.minValue = 0;
		_smoothingStepper.maxValue = 10;
		_smoothingStepper.increment = 1;
		_smoothingStepper.valueWraps = NO;
		_smoothingStepper.target = self;
		_smoothingStepper.action = @selector(smoothingChanged:);
		[self addSubview:_smoothingStepper];

		_smoothingValue = [NSTextField labelWithString:@"0"];
		_smoothingValue.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		[self addSubview:_smoothingValue];

		_statusLabel = [NSTextField labelWithString:@"Not analyzed"];
		_statusLabel.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
		_statusLabel.textColor = NSColor.secondaryLabelColor;
		[self addSubview:_statusLabel];

		[self layoutRows];
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSPopUpButton *)addPopUpWithItems:(NSArray<NSString *> *)titles action:(SEL)action
{
	NSPopUpButton *popUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
	popUp.controlSize = NSControlSizeSmall;
	popUp.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
	NSInteger tag = 0;
	for (NSString *title in titles) {
		[popUp addItemWithTitle:title];
		popUp.lastItem.tag = tag++;
	}
	popUp.target = self;
	popUp.action = action;
	[self addSubview:popUp];
	return popUp;
}

- (void)layoutRows
{
	CGFloat width = self.bounds.size.width;
	CGFloat controlX = kLabelWidth;
	CGFloat controlWidth = MAX(60.0, width - controlX);
	NSArray<NSString *> *labels = @[@"Shape", @"Behavior", @"Resolution", @"Smoothing", @"Status"];
	NSArray<NSView *> *rowLeads = @[_shapePopUp, _behaviorPopUp, _resolutionPopUp, _smoothingStepper, _statusLabel];

	CGFloat y = 0.0;
	for (NSUInteger row = 0; row < labels.count; row++) {
		NSView *lead = rowLeads[row];
		if (lead == _smoothingStepper) {
			_smoothingStepper.frame = NSMakeRect(controlX, y, 20.0, kRowHeight);
			_smoothingValue.frame = NSMakeRect(controlX + 26.0, y + 3.0, 40.0, kRowHeight - 6.0);
		} else {
			lead.frame = NSMakeRect(controlX, y, controlWidth, kRowHeight);
		}
		y += kRowHeight + kRowGap;
	}
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[super resizeSubviewsWithOldSize:oldSize];
	[self layoutRows];
}

#pragma mark FxGripCustomViewDataDelegate

- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripObjectTrackerData.class]) {
		return;
	}
	FxGripObjectTrackerData *data = (FxGripObjectTrackerData *)value;
	[_shapePopUp selectItemWithTag:data.shape];
	[_behaviorPopUp selectItemWithTag:data.behavior];
	[_resolutionPopUp selectItemWithTag:data.resolution];
	_smoothingStepper.integerValue = data.smoothing;
	_smoothingValue.stringValue = [NSString stringWithFormat:@"%ld", (long)data.smoothing];

	NSUInteger frames = data.sampleCount;
	_statusLabel.stringValue = frames > 0
		? [NSString stringWithFormat:@"Tracked %lu frames", (unsigned long)frames]
		: @"Not analyzed";
}

#pragma mark Edits

// Reads the current value, applies one option change, and writes it back out of band. The
// copy preserves the placed region and the tracked samples.
- (void)commitChange:(void (^)(FxGripObjectTrackerData *data))mutate
{
	FxGripTileableEffect *effect = (FxGripTileableEffect *)self.parameterEffect;
	if (effect == nil) {
		return;
	}
	FxGripOOBParameterAccess *access = [FxGripOOBParameterAccess access:effect];
	CMTime time = access.currentTime;

	NSObject<NSSecureCoding, NSCopying> *value = nil;
	[effect.apiManager.paramGetAPIv6 getCustomParameterValue:&value
											   fromParameter:self.parameterID
													  atTime:time];
	FxGripObjectTrackerData *data = [value isKindOfClass:FxGripObjectTrackerData.class]
		? [(FxGripObjectTrackerData *)value copy]
		: [[FxGripObjectTrackerData alloc] init];
	mutate(data);
	[effect.apiManager.paramSetAPIv5 setCustomParameterValue:data
												 toParameter:self.parameterID
													  atTime:time];
}

- (void)shapeChanged:(id)sender
{
	NSInteger tag = _shapePopUp.selectedTag;
	[self commitChange:^(FxGripObjectTrackerData *data) { data.shape = tag; }];
}

- (void)behaviorChanged:(id)sender
{
	NSInteger tag = _behaviorPopUp.selectedTag;
	[self commitChange:^(FxGripObjectTrackerData *data) { data.behavior = tag; }];
}

- (void)resolutionChanged:(id)sender
{
	NSInteger tag = _resolutionPopUp.selectedTag;
	[self commitChange:^(FxGripObjectTrackerData *data) { data.resolution = tag; }];
}

- (void)smoothingChanged:(id)sender
{
	NSInteger smoothing = _smoothingStepper.integerValue;
	_smoothingValue.stringValue = [NSString stringWithFormat:@"%ld", (long)smoothing];
	[self commitChange:^(FxGripObjectTrackerData *data) { data.smoothing = smoothing; }];
}

@end
