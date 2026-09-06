/*!
	@file       FxGripCurveSetEditorView.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripCurveSetEditorView
	@abstract   Implements the inspector composite that edits a curve-set value as strips.
	@discussion Introduced in FxGrip 0.1.0. Each declared mapping adds one labeled strip, stacked
	            top-down. A strip's continuous edit updates the working set; its commit lands the
	            final curve and writes the whole set to the host inside one out-of-band action.
*/

#import "FxGripCurveSetEditorView.h"
#import "FxGripOOBParameterAccess.h"
#import "FxGripTileableEffect.h"
#import "FxGrip_ARC.h"

static const CGFloat kFxGripCurveStripHeight = 72.0;
static const CGFloat kFxGripCurveLabelHeight = 16.0;
static const CGFloat kFxGripCurveStripSpacing = 6.0;

@interface FxGripCurveSetEditorView ()
{
	FxGripCurveSetData *_curveSet;
	NSMutableArray<FxGripCurveEditorView*> *_editors;
}
@end

/*!
	@abstract	The inspector composite of labeled curve strips over one curve-set value.
	@discussion	Introduced in FxGrip 0.1.0. The composite holds the working set and the child
				strips, propagating shared style settings to every strip.
*/
@implementation FxGripCurveSetEditorView

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_curveSet = NARC_RETAIN([FxGripCurveSetData.alloc init]);
		_editors = NARC_RETAIN([NSMutableArray array]);
		_slowDragScale = kFxGripCurveSlowDragScaleDefault;
		_lineWidth = kFxGripCurveLineWidthDefault;
		self.autoresizingMask = NSViewWidthSizable;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_curveSet);
	NARC_RELEASE(_editors);
	SUPER_DEALLOC();
}

- (nonnull FxGripCurveSetData *)curveSet
{
	return _curveSet;
}

- (nonnull NSArray<FxGripCurveEditorView *> *)editors
{
	return _editors;
}

- (void)setSlowDragScale:(CGFloat)scale
{
	// The strip owns the clamp; the composite stores the same clamped value it hands out.
	_slowDragScale = scale < 0.01 ? 0.01 : (scale > 1.0 ? 1.0 : scale);
	for (FxGripCurveEditorView *editor in _editors) {
		editor.slowDragScale = _slowDragScale;
	}
}

- (void)setLineWidth:(CGFloat)lineWidth
{
	// The strip owns the clamp; the composite stores the same clamped value it hands out.
	_lineWidth = lineWidth < 0.1 ? 0.1 : (lineWidth > 8.0 ? 8.0 : lineWidth);
	for (FxGripCurveEditorView *editor in _editors) {
		editor.lineWidth = _lineWidth;
	}
}

- (BOOL)isFlipped
{
	// Strips stack top-down in declaration order.
	return YES;
}

/*!
	@method		addEditorForKey:title:role:domain:background:
	@abstract	Appends one labeled curve strip for a mapping.
	@return		The created strip, configured and stacked.
	@discussion	Introduced in FxGrip 0.1.0. The strip is labeled with the localized title, bound
				to the mapping key, and seeded from the working set. The composite grows to fit. */
- (nonnull FxGripCurveEditorView *)addEditorForKey:(nonnull NSString *)key
											 title:(nonnull NSString *)title
											  role:(FxGripCurveRole)role
											domain:(FxGripCurveDomain)domain
										background:(FxGripCurveBackground)background
{
	CGFloat top = _editors.count * (kFxGripCurveLabelHeight + kFxGripCurveStripHeight + kFxGripCurveStripSpacing);
	CGFloat width = self.bounds.size.width;

	NSTextField *label = [NSTextField labelWithString:NSLocalizedString(title, title)];
	label.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
	label.frame = NSMakeRect(0, top, width, kFxGripCurveLabelHeight);
	label.autoresizingMask = NSViewWidthSizable;
	[self addSubview:label];

	FxGripCurveEditorView *editor =
		[[FxGripCurveEditorView alloc] initWithFrame:NSMakeRect(0, top + kFxGripCurveLabelHeight,
																width, kFxGripCurveStripHeight)
												role:role
											  domain:domain
										  background:background];
	editor.mappingKey = key;
	editor.delegate = self;
	editor.slowDragScale = self.slowDragScale;
	editor.lineWidth = self.lineWidth;
	editor.autoresizingMask = NSViewWidthSizable;
	[self addSubview:editor];
	NARC_RELEASE_RAW(editor);
	[_editors addObject:editor];

	CGFloat height = _editors.count * (kFxGripCurveLabelHeight + kFxGripCurveStripHeight + kFxGripCurveStripSpacing);
	[self setFrameSize:NSMakeSize(width, height)];
	[editor updateFromCustomData:_curveSet];
	return editor;
}


#pragma mark Data push

/*!
	@method		updateFromCustomData:
	@abstract	Adopts a pushed curve set as the working set and refreshes every strip.
	@discussion	Introduced in FxGrip 0.1.0. A value that is not a curve set is ignored. The value
				is copied class-preserving so the composite owns its working set. */
- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if (![value isKindOfClass:FxGripCurveSetData.class]) {
		return;
	}
	// mutableCopy on the dictionary cluster derives a plain NSMutableDictionary; the
	// class-preserving copy goes through initWithDictionary:.
	FxGripCurveSetData *copied = [[[value class] alloc] initWithDictionary:(NSDictionary*)value];
	NARC_RELEASE(_curveSet);
	_curveSet = copied;
	for (FxGripCurveEditorView *editor in _editors) {
		[editor updateFromCustomData:_curveSet];
	}
}


#pragma mark Strip edits

/*!
	@method		curveEditorView:didEditCurve:
	@abstract	Records a strip's in-progress edit into the working set.
	@discussion	Introduced in FxGrip 0.1.0. The edit updates the mapping key without writing to
				the host, so the host's undo records only the committed gesture. */
- (void)curveEditorView:(nonnull FxGripCurveEditorView *)editor didEditCurve:(nonnull FxGripCurveData *)curve
{
	if (editor.mappingKey != nil) {
		[_curveSet setCurve:curve forKey:editor.mappingKey];
	}
}

/*! The commit boundary: the gesture's final curve lands in the set and the set writes
	to the host inside one out-of-band action. */
- (void)curveEditorView:(nonnull FxGripCurveEditorView *)editor didCommitCurve:(nonnull FxGripCurveData *)curve
{
	if (editor.mappingKey != nil) {
		[_curveSet setCurve:curve forKey:editor.mappingKey];
	}

	FxGripTileableEffect *effect = (FxGripTileableEffect*)self.parameterEffect;
	if (effect == nil) {
		return;
	}
	FxGripOOBParameterAccess *__attribute__((unused)) access = [FxGripOOBParameterAccess access:effect];
	[effect.apiManager.paramSetAPIv5 setCustomParameterValue:_curveSet
												 toParameter:self.parameterID
													  atTime:access.currentTime];
}

@end
