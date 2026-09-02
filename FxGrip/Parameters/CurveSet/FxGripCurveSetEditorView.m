//
//  FxGripCurveSetEditorView.m
//  FxGrip
//

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
