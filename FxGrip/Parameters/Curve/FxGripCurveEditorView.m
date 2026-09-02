//
//  FxGripCurveEditorView.m
//  FxGrip
//

#import "FxGripCurveEditorView.h"
#import "FxGripCurveSetData.h"
#import "FxGripEventModifiers.h"
#import "FxGrip_ARC.h"

// Hit-test and drawing metrics, in view points.
static const CGFloat kFxGripCurvePointRadius = 3.5;
static const CGFloat kFxGripCurveHitRadius = 6.0;
static const CGFloat kFxGripCurveRemoveMargin = 40.0;
static const CGFloat kFxGripCurveInset = 4.0;

const CGFloat kFxGripCurveSlowDragScaleDefault = 0.1;
const CGFloat kFxGripCurveLineWidthDefault = 1.0;

// The strip base tone. A vertical gradient fades to it through transparent stops.
static const CGFloat kFxGripCurveBaseWhite = 0.16;

/*! The stroke alpha for an interior alignment line at `line` of `divisions`.
	A line's tier is the denominator of line/divisions in lowest terms: quarter and
	coarser lines are primary, eighth lines dim, sixteenth lines dimmest. */
static CGFloat fxg_gridLineAlpha(NSInteger line, NSInteger divisions)
{
	NSInteger a = line, b = divisions;
	while (b != 0) {
		NSInteger t = a % b;
		a = b;
		b = t;
	}
	NSInteger denominator = divisions / a;			// line/divisions reduced
	if (denominator >= 16) {
		return 0.03;
	}
	if (denominator >= 8) {
		return 0.06;
	}
	return 0.12;
}

#pragma mark - FxGripCurvePaint

@interface FxGripCurvePaint ()
- (instancetype)initWithKind:(FxGripCurvePaintKind)kind color:(nullable NSColor *)color;
@end

@implementation FxGripCurvePaint
{
	FxGripCurvePaintKind _kind;
	NSColor *_color;
}

+ (nonnull instancetype)nonePaint
{
	return NARC_AUTORELEASE([[self alloc] initWithKind:FxGripCurvePaintKindNone color:nil]);
}

+ (nonnull instancetype)paintWithColor:(nonnull NSColor *)color
{
	return NARC_AUTORELEASE([[self alloc] initWithKind:FxGripCurvePaintKindColor color:color]);
}

+ (nonnull instancetype)huePaint
{
	return NARC_AUTORELEASE([[self alloc] initWithKind:FxGripCurvePaintKindHue color:nil]);
}

- (instancetype)initWithKind:(FxGripCurvePaintKind)kind color:(nullable NSColor *)color
{
	self = [super init];
	if (self != nil) {
		_kind = kind;
		_color = [color copy];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_color);
	SUPER_DEALLOC();
}

- (FxGripCurvePaintKind)kind { return _kind; }
- (NSColor *)color { return _color; }
- (id)copyWithZone:(NSZone *)zone { return NARC_RETAIN(self); }   // immutable

@end

@interface FxGripCurveEditorView ()
{
	FxGripCurveRole _role;
	FxGripCurveDomain _domain;
	NSUInteger _selectedPointIndex;
	NSUInteger _menuPointIndex;
	BOOL _dragging;
	NSPoint _dragVirtualPoint;
	NSPoint _lastDragLocation;
	CGPoint _dragStartPoint;			// the point's curve value at drag start, for Shift-constrain
	NSColor *_lineColor;
	FxGripCurveLineStyle _lineStyle;
	CGFloat _lineWidth;
	FxGripCurveGridDivisions _gridDivisions;
	FxGripCurvePaint *_topPaint;
	FxGripCurvePaint *_centerPaint;
	FxGripCurvePaint *_bottomPaint;
	FxGripCurveReadoutStyle _pointReadoutStyle;
	FxGripCurveReadoutUnits _pointReadoutUnits;
	FxGripCurveReadoutTrigger _pointReadoutTrigger;
	NSUInteger _hoveredPointIndex;
	NSTrackingArea *_trackingArea;
}
@end

@implementation FxGripCurveEditorView

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
								 role:(FxGripCurveRole)role
							   domain:(FxGripCurveDomain)domain
						   background:(FxGripCurveBackground)background
{
	self = [super initWithFrame:frameRect];
	if (self != nil) {
		_role = role;
		_domain = domain;
		_background = background;
		_selectedPointIndex = NSNotFound;
		_menuPointIndex = NSNotFound;
		_hoveredPointIndex = NSNotFound;
		_gridDivisions = FxGripCurveGridDivisionsEighths;
		_slowDragScale = kFxGripCurveSlowDragScaleDefault;
		_lineWidth = kFxGripCurveLineWidthDefault;
		_curve = NARC_RETAIN([FxGripCurveData identityCurveWithRole:role domain:domain]);
	}
	return self;
}

- (nonnull instancetype)initWithFrame:(NSRect)frameRect
{
	return [self initWithFrame:frameRect
						  role:FxGripCurveRoleRemap
						domain:FxGripCurveDomainLinear
					background:FxGripCurveBackgroundGrid];
}

- (void)dealloc
{
	NARC_RELEASE(_curve);
	NARC_RELEASE(_mappingKey);
	NARC_RELEASE(_lineColor);
	NARC_RELEASE(_topPaint);
	NARC_RELEASE(_centerPaint);
	NARC_RELEASE(_bottomPaint);
	NARC_RELEASE(_trackingArea);
	SUPER_DEALLOC();
}

- (NSColor *)lineColor
{
	return _lineColor ?: [NSColor whiteColor];
}

- (void)setLineColor:(nullable NSColor *)lineColor
{
	NSColor *copied = [lineColor copy];
	NARC_RELEASE(_lineColor);
	_lineColor = copied;
	[self setNeedsDisplay:YES];
}

- (FxGripCurveLineStyle)lineStyle { return _lineStyle; }

- (void)setLineStyle:(FxGripCurveLineStyle)lineStyle
{
	_lineStyle = lineStyle;
	[self setNeedsDisplay:YES];
}

- (CGFloat)lineWidth { return _lineWidth; }

- (void)setLineWidth:(CGFloat)lineWidth
{
	_lineWidth = lineWidth < 0.1 ? 0.1 : (lineWidth > 8.0 ? 8.0 : lineWidth);
	[self setNeedsDisplay:YES];
}

- (FxGripCurveGridDivisions)gridDivisions { return _gridDivisions; }

- (void)setGridDivisions:(FxGripCurveGridDivisions)gridDivisions
{
	_gridDivisions = gridDivisions;
	[self setNeedsDisplay:YES];
}

- (FxGripCurvePaint *)topPaint { return _topPaint; }
- (FxGripCurvePaint *)centerPaint { return _centerPaint; }
- (FxGripCurvePaint *)bottomPaint { return _bottomPaint; }

- (void)setTopPaint:(nullable FxGripCurvePaint *)paint
{
	FxGripCurvePaint *copied = [paint copy];
	NARC_RELEASE(_topPaint);
	_topPaint = copied;
	[self setNeedsDisplay:YES];
}

- (void)setCenterPaint:(nullable FxGripCurvePaint *)paint
{
	FxGripCurvePaint *copied = [paint copy];
	NARC_RELEASE(_centerPaint);
	_centerPaint = copied;
	[self setNeedsDisplay:YES];
}

- (void)setBottomPaint:(nullable FxGripCurvePaint *)paint
{
	FxGripCurvePaint *copied = [paint copy];
	NARC_RELEASE(_bottomPaint);
	_bottomPaint = copied;
	[self setNeedsDisplay:YES];
}

- (FxGripCurveReadoutStyle)pointReadoutStyle { return _pointReadoutStyle; }
- (FxGripCurveReadoutUnits)pointReadoutUnits { return _pointReadoutUnits; }
- (FxGripCurveReadoutTrigger)pointReadoutTrigger { return _pointReadoutTrigger; }

- (void)setPointReadoutStyle:(FxGripCurveReadoutStyle)style
{
	_pointReadoutStyle = style;
	[self setNeedsDisplay:YES];
}

- (void)setPointReadoutUnits:(FxGripCurveReadoutUnits)units
{
	_pointReadoutUnits = units;
	[self setNeedsDisplay:YES];
}

- (void)setPointReadoutTrigger:(FxGripCurveReadoutTrigger)trigger
{
	_pointReadoutTrigger = trigger;
	_hoveredPointIndex = NSNotFound;
	[self setNeedsDisplay:YES];
}

- (NSUInteger)selectedPointIndex
{
	return _selectedPointIndex;
}

- (void)setSlowDragScale:(CGFloat)scale
{
	_slowDragScale = scale < 0.01 ? 0.01 : (scale > 1.0 ? 1.0 : scale);
}

- (void)setCurve:(nonnull FxGripCurveData *)curve
{
	if (curve == nil || curve == _curve) {
		return;
	}
	FxGripCurveData *copied = [curve copy];
	NARC_RELEASE(_curve);
	_curve = copied;
	if (_selectedPointIndex != NSNotFound && _selectedPointIndex >= _curve.pointCount) {
		_selectedPointIndex = NSNotFound;
	}
	[self setNeedsDisplay:YES];
}

- (BOOL)isFlipped
{
	// Curve space: y grows upward, matching the value axis.
	return NO;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}


#pragma mark Data push

- (void)updateFromCustomData:(NSObject<NSSecureCoding,NSCopying> * _Nullable)value
{
	if ([value isKindOfClass:FxGripCurveData.class]) {
		self.curve = (FxGripCurveData*)value;
		return;
	}
	if ([value isKindOfClass:FxGripCurveSetData.class] && self.mappingKey != nil) {
		FxGripCurveData *stored = [(FxGripCurveSetData*)value curveForKey:self.mappingKey];
		self.curve = stored ?: [FxGripCurveData identityCurveWithRole:_role domain:_domain];
	}
}


#pragma mark Geometry

- (NSRect)curveBounds
{
	return NSInsetRect(self.bounds, kFxGripCurveInset, kFxGripCurveInset);
}

- (NSPoint)viewPointForCurvePoint:(CGPoint)point
{
	NSRect bounds = self.curveBounds;
	return NSMakePoint(bounds.origin.x + point.x * bounds.size.width,
					   bounds.origin.y + point.y * bounds.size.height);
}

- (CGPoint)curvePointForViewPoint:(NSPoint)point
{
	NSRect bounds = self.curveBounds;
	double x = bounds.size.width > 0 ? (point.x - bounds.origin.x) / bounds.size.width : 0.0;
	double y = bounds.size.height > 0 ? (point.y - bounds.origin.y) / bounds.size.height : 0.0;
	if (_domain == FxGripCurveDomainCircular) {
		x -= floor(x);
	} else {
		x = x < 0.0 ? 0.0 : (x > 1.0 ? 1.0 : x);
	}
	y = y < 0.0 ? 0.0 : (y > 1.0 ? 1.0 : y);
	return CGPointMake(x, y);
}

- (NSUInteger)pointIndexAtViewPoint:(NSPoint)location
{
	for (NSUInteger index = 0; index < _curve.pointCount; index++) {
		NSPoint candidate = [self viewPointForCurvePoint:[_curve pointAtIndex:index]];
		CGFloat dx = candidate.x - location.x, dy = candidate.y - location.y;
		if (dx * dx + dy * dy <= kFxGripCurveHitRadius * kFxGripCurveHitRadius) {
			return index;
		}
	}
	return NSNotFound;
}


#pragma mark Editing

- (nonnull NSMutableArray<NSValue*> *)mutablePoints
{
	NSMutableArray *points = [NSMutableArray arrayWithCapacity:_curve.pointCount];
	for (NSUInteger index = 0; index < _curve.pointCount; index++) {
		CGPoint point = [_curve pointAtIndex:index];
		[points addObject:[NSValue valueWithPoint:NSMakePoint(point.x, point.y)]];
	}
	return points;
}

- (nonnull FxGripCurveData *)curveFromPoints:(nonnull NSArray<NSValue*> *)values
{
	NSUInteger count = values.count;
	CGPoint *points = count > 0 ? malloc(count * sizeof(CGPoint)) : NULL;
	for (NSUInteger index = 0; index < count; index++) {
		NSPoint point = values[index].pointValue;
		points[index] = CGPointMake(point.x, point.y);
	}
	FxGripCurveData *curve = [FxGripCurveData curveWithPoints:points count:count role:_role domain:_domain];
	free(points);
	return curve;
}

/*! Replaces the curve, tracks the moved point's new index, and notifies. */
- (void)applyPoints:(nonnull NSArray<NSValue*> *)points trackedPoint:(CGPoint)tracked commit:(BOOL)commit
{
	FxGripCurveData *edited = [self curveFromPoints:points];
	NARC_RELEASE(_curve);
	_curve = NARC_RETAIN(edited);

	_selectedPointIndex = NSNotFound;
	for (NSUInteger index = 0; index < edited.pointCount; index++) {
		CGPoint candidate = [edited pointAtIndex:index];
		if (fabs(candidate.x - tracked.x) < 1e-9 && fabs(candidate.y - tracked.y) < 1e-9) {
			_selectedPointIndex = index;
			break;
		}
	}

	[self setNeedsDisplay:YES];
	if (commit) {
		[self.delegate curveEditorView:self didCommitCurve:_curve];
	} else {
		[self.delegate curveEditorView:self didEditCurve:_curve];
	}
}

/*! A linear curve's pinned endpoints never remove; interior points remove above the
	two-point floor, and any circular point removes above one. */
- (BOOL)isRemovablePointAtIndex:(NSUInteger)index
{
	if (index == NSNotFound) {
		return NO;
	}
	if (_domain == FxGripCurveDomainCircular) {
		return _curve.pointCount > 1;
	}
	if (index == 0 || index == _curve.pointCount - 1) {
		return NO;
	}
	return _curve.pointCount > 2;
}

/*! The first and last point of a linear curve pin in x, so the domain stays covered. */
- (CGPoint)constrainPoint:(CGPoint)point atIndex:(NSUInteger)index
{
	if (_domain == FxGripCurveDomainLinear && _curve.pointCount >= 2) {
		if (index == 0) {
			point.x = [_curve pointAtIndex:0].x;
		} else if (index == _curve.pointCount - 1) {
			point.x = [_curve pointAtIndex:_curve.pointCount - 1].x;
		}
	}
	return point;
}

- (void)removePointAtIndex:(NSUInteger)index
{
	if (![self isRemovablePointAtIndex:index]) {
		return;
	}
	NSMutableArray *points = [self mutablePoints];
	[points removeObjectAtIndex:index];
	_selectedPointIndex = NSNotFound;
	[self applyPoints:points trackedPoint:CGPointMake(-1, -1) commit:YES];
}

- (void)resetCurve
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:_role domain:_domain];
	NARC_RELEASE(_curve);
	_curve = NARC_RETAIN(identity);
	_selectedPointIndex = NSNotFound;
	[self setNeedsDisplay:YES];
	[self.delegate curveEditorView:self didCommitCurve:_curve];
}


#pragma mark Mouse

- (void)mouseDown:(NSEvent *)event
{
	// Control-click is a contextual menu on macOS; AppKit routes it through menuForEvent:.
	if ([FxGripEventModifiers isContextMenu:event]) {
		return;
	}

	[self.window makeFirstResponder:self];
	NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];

	if (event.clickCount == 2) {
		[self resetCurve];
		return;
	}

	NSUInteger hit = [self pointIndexAtViewPoint:location];
	_dragVirtualPoint = location;
	_lastDragLocation = location;

	// A Command-click deletes instead of selecting or adding; the Delete key and the context
	// menu's Delete Point item offer the same removal.
	if ([FxGripEventModifiers isDeleteClick:event]) {
		if (hit != NSNotFound) {
			[self removePointAtIndex:hit];
		}
		return;
	}

	if (hit != NSNotFound) {
		_selectedPointIndex = hit;
		_dragStartPoint = [_curve pointAtIndex:hit];
		_dragging = YES;
		[self setNeedsDisplay:YES];
		return;
	}

	// A click away from any point adds one on the curve at that x.
	CGPoint added = [self curvePointForViewPoint:location];
	_dragStartPoint = added;
	NSMutableArray *points = [self mutablePoints];
	[points addObject:[NSValue valueWithPoint:NSMakePoint(added.x, added.y)]];
	_dragging = YES;
	[self applyPoints:points trackedPoint:added commit:NO];
}

- (void)mouseDragged:(NSEvent *)event
{
	if (!_dragging || _selectedPointIndex == NSNotFound) {
		return;
	}
	NSPoint mouse = [self convertPoint:event.locationInWindow fromView:nil];

	// Holding Option slows the drag to a fraction of mouse travel for fine positioning. Each
	// event's delta accumulates, scaled, into a virtual location, so pressing or releasing Option
	// mid-drag never jumps the point; without the modifier the virtual location equals the mouse
	// location.
	CGFloat scale = [FxGripEventModifiers isFineDrag:event] ? self.slowDragScale : 1.0;
	_dragVirtualPoint.x += (mouse.x - _lastDragLocation.x) * scale;
	_dragVirtualPoint.y += (mouse.y - _lastDragLocation.y) * scale;
	_lastDragLocation = mouse;
	NSPoint location = _dragVirtualPoint;

	// Dragging far outside the strip removes the point; the virtual location keeps a
	// long slowed drag a move. A linear curve's pinned endpoints define the domain
	// and never remove, whatever the count.
	NSRect removalRect = NSInsetRect(self.bounds, -kFxGripCurveRemoveMargin, -kFxGripCurveRemoveMargin);
	BOOL removable = [self isRemovablePointAtIndex:_selectedPointIndex];
	if (removable && !NSPointInRect(location, removalRect)) {
		NSMutableArray *points = [self mutablePoints];
		[points removeObjectAtIndex:_selectedPointIndex];
		_selectedPointIndex = NSNotFound;
		[self applyPoints:points trackedPoint:CGPointMake(-1, -1) commit:NO];
		return;
	}

	CGPoint raw = [self curvePointForViewPoint:location];
	// Holding Shift constrains the point to horizontal or vertical from where the drag began,
	// whichever axis has moved farther.
	if ([FxGripEventModifiers isConstrain:event]) {
		if (fabs(raw.x - _dragStartPoint.x) >= fabs(raw.y - _dragStartPoint.y)) {
			raw.y = _dragStartPoint.y;
		} else {
			raw.x = _dragStartPoint.x;
		}
	}
	CGPoint moved = [self constrainPoint:raw atIndex:_selectedPointIndex];
	NSMutableArray *points = [self mutablePoints];
	if (_selectedPointIndex < points.count) {
		points[_selectedPointIndex] = [NSValue valueWithPoint:NSMakePoint(moved.x, moved.y)];
	} else {
		[points addObject:[NSValue valueWithPoint:NSMakePoint(moved.x, moved.y)]];
	}
	[self applyPoints:points trackedPoint:moved commit:NO];
}

- (void)mouseUp:(NSEvent *)event
{
	if (_dragging) {
		_dragging = NO;
		[self.delegate curveEditorView:self didCommitCurve:_curve];
	}
}

#pragma mark Hover

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	if (_trackingArea != nil) {
		[self removeTrackingArea:_trackingArea];
		NARC_RELEASE(_trackingArea);
		_trackingArea = nil;
	}
	NSTrackingAreaOptions options = NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited
		| NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect;
	_trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
	[self addTrackingArea:_trackingArea];
}

- (void)mouseMoved:(NSEvent *)event
{
	if (_pointReadoutTrigger == FxGripCurveReadoutTriggerActivePoint) {
		return;
	}
	// Command-hover reveals in the modifier-gated mode; without Command the hover readout clears.
	if (_pointReadoutTrigger == FxGripCurveReadoutTriggerActiveAndModifierHover
		&& ![FxGripEventModifiers isDeleteClick:event]) {
		[self setHoveredPointIndex:NSNotFound];
		return;
	}
	NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
	[self setHoveredPointIndex:[self pointIndexAtViewPoint:location]];
}

- (void)mouseExited:(NSEvent *)event
{
	[self setHoveredPointIndex:NSNotFound];
}

- (void)setHoveredPointIndex:(NSUInteger)index
{
	if (index != _hoveredPointIndex) {
		_hoveredPointIndex = index;
		[self setNeedsDisplay:YES];
	}
}


#pragma mark Keyboard

- (void)keyDown:(NSEvent *)event
{
	unichar key = event.charactersIgnoringModifiers.length > 0
		? [event.charactersIgnoringModifiers characterAtIndex:0] : 0;
	if ((key == NSDeleteCharacter || key == NSDeleteFunctionKey)
		&& [self isRemovablePointAtIndex:_selectedPointIndex]) {
		[self removePointAtIndex:_selectedPointIndex];
		return;
	}
	[super keyDown:event];
}


#pragma mark Menu

- (NSMenu *)menuForEvent:(NSEvent *)event
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];

	NSPoint location = [self convertPoint:event.locationInWindow fromView:nil];
	_menuPointIndex = [self pointIndexAtViewPoint:location];
	if (_menuPointIndex != NSNotFound) {
		NSMenuItem *deletePoint = [menu addItemWithTitle:NSLocalizedString(@"Delete Point", @"Delete Point")
												  action:@selector(fxDeleteMenuPoint:)
										   keyEquivalent:@""];
		deletePoint.target = self;
		deletePoint.enabled = [self isRemovablePointAtIndex:_menuPointIndex];
		[menu addItem:NSMenuItem.separatorItem];
	}

	NSMenuItem *reset = [menu addItemWithTitle:NSLocalizedString(@"Reset Curve", @"Reset Curve")
										action:@selector(fxResetCurve:)
								 keyEquivalent:@""];
	reset.target = self;
	return NARC_AUTORELEASE(menu);
}

- (void)fxDeleteMenuPoint:(nullable id)sender
{
	[self removePointAtIndex:_menuPointIndex];
	_menuPointIndex = NSNotFound;
}

- (void)fxResetCurve:(nullable id)sender
{
	[self resetCurve];
}


#pragma mark Drawing

/*! The background color at a horizontal fraction, per the background style. */
- (NSColor *)backgroundColorAtFraction:(CGFloat)fraction
{
	switch (_background) {
		case FxGripCurveBackgroundHueSpectrum:
			return [NSColor colorWithCalibratedHue:fraction saturation:1.0 brightness:1.0 alpha:1.0];
		case FxGripCurveBackgroundLumaRamp:
			return [NSColor colorWithCalibratedWhite:fraction alpha:1.0];
		case FxGripCurveBackgroundSaturationRamp:
			return [NSColor colorWithCalibratedHue:0.0 saturation:fraction brightness:1.0 alpha:1.0];
		case FxGripCurveBackgroundRedRamp:
			return [NSColor colorWithCalibratedRed:fraction green:0.0 blue:0.0 alpha:1.0];
		case FxGripCurveBackgroundGreenRamp:
			return [NSColor colorWithCalibratedRed:0.0 green:fraction blue:0.0 alpha:1.0];
		case FxGripCurveBackgroundBlueRamp:
			return [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:fraction alpha:1.0];
		default:
			return nil;
	}
}

/*! YES when a vertical gradient stop is set, which overrides the horizontal `background`. */
- (BOOL)hasVerticalPaints
{
	return _topPaint != nil || _centerPaint != nil || _bottomPaint != nil;
}

/*! The color a stop contributes at a horizontal fraction. None fades to the base (base tone at zero
	alpha, so the fade carries no color cast); a color and a hue draw at near-full alpha. */
- (NSColor *)colorForPaint:(nullable FxGripCurvePaint *)paint atFraction:(CGFloat)fraction
{
	if (paint == nil || paint.kind == FxGripCurvePaintKindNone) {
		return [NSColor colorWithCalibratedWhite:kFxGripCurveBaseWhite alpha:0.0];
	}
	if (paint.kind == FxGripCurvePaintKindHue) {
		return [NSColor colorWithCalibratedHue:fraction saturation:1.0 brightness:1.0 alpha:0.9];
	}
	return [paint.color colorWithAlphaComponent:0.9];
}

/*! Draws the top/center/bottom stops as a vertical gradient. A hue stop varies across x, so the
	strip is rendered in vertical bands, each with its own gradient. */
- (void)drawVerticalGradientInRect:(NSRect)bounds
{
	const int bands = 96;
	CGFloat bandWidth = bounds.size.width / bands;
	for (int band = 0; band < bands; band++) {
		CGFloat fraction = (bands > 1) ? (CGFloat)band / (bands - 1) : 0.0;

		NSMutableArray<NSColor *> *colors = [NSMutableArray arrayWithCapacity:3];
		CGFloat locations[3];
		NSUInteger count = 0;
		if (_bottomPaint != nil) {
			[colors addObject:[self colorForPaint:_bottomPaint atFraction:fraction]];
			locations[count++] = 0.0;
		}
		if (_centerPaint != nil) {
			[colors addObject:[self colorForPaint:_centerPaint atFraction:fraction]];
			locations[count++] = 0.5;
		}
		if (_topPaint != nil) {
			[colors addObject:[self colorForPaint:_topPaint atFraction:fraction]];
			locations[count++] = 1.0;
		}

		NSRect bandRect = NSMakeRect(bounds.origin.x + band * bandWidth, bounds.origin.y,
									 bandWidth + 1.0, bounds.size.height);
		if (count >= 2) {
			NSGradient *gradient = [[NSGradient alloc] initWithColors:colors
														  atLocations:locations
														   colorSpace:[NSColorSpace genericRGBColorSpace]];
			[gradient drawInRect:bandRect angle:90.0];
			NARC_RELEASE(gradient);
		} else if (count == 1) {
			[colors[0] setFill];
			NSRectFillUsingOperation(bandRect, NSCompositingOperationSourceOver);
		}
	}
}

- (void)drawBackgroundInRect:(NSRect)bounds
{
	[[NSColor colorWithCalibratedWhite:kFxGripCurveBaseWhite alpha:1.0] setFill];
	NSRectFill(self.bounds);

	if ([self hasVerticalPaints]) {
		[self drawVerticalGradientInRect:bounds];
		return;
	}

	if (_background == FxGripCurveBackgroundAlphaChecker) {
		const CGFloat square = 6.0;
		[[NSColor colorWithCalibratedWhite:0.35 alpha:1.0] setFill];
		for (CGFloat y = bounds.origin.y; y < NSMaxY(bounds); y += square) {
			for (CGFloat x = bounds.origin.x; x < NSMaxX(bounds); x += square * 2) {
				CGFloat offset = fmod((y - bounds.origin.y) / square, 2.0) >= 1.0 ? square : 0.0;
				NSRectFill(NSMakeRect(x + offset, y, square, MIN(square, NSMaxY(bounds) - y)));
			}
		}
		return;
	}

	NSColor *leftColor = [self backgroundColorAtFraction:0.0];
	if (leftColor == nil) {
		return;
	}
	const int bands = 64;
	CGFloat bandWidth = bounds.size.width / bands;
	for (int band = 0; band < bands; band++) {
		[[[self backgroundColorAtFraction:(CGFloat)band / (bands - 1)]
			colorWithAlphaComponent:0.55] setFill];
		NSRectFillUsingOperation(NSMakeRect(bounds.origin.x + band * bandWidth, bounds.origin.y,
											bandWidth + 1.0, bounds.size.height),
								 NSCompositingOperationSourceOver);
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect bounds = self.curveBounds;
	[self drawBackgroundInRect:bounds];

	// Alignment grid: quarter lines at full weight, finer lines dimmer per tier.
	const NSInteger divisions = _gridDivisions;
	for (NSInteger line = 1; line < divisions; line++) {
		[[NSColor colorWithCalibratedWhite:1.0
									 alpha:fxg_gridLineAlpha(line, divisions)] setStroke];
		CGFloat x = bounds.origin.x + bounds.size.width * line / divisions;
		CGFloat y = bounds.origin.y + bounds.size.height * line / divisions;
		[NSBezierPath strokeLineFromPoint:NSMakePoint(x, bounds.origin.y)
								  toPoint:NSMakePoint(x, NSMaxY(bounds))];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(bounds.origin.x, y)
								  toPoint:NSMakePoint(NSMaxX(bounds), y)];
	}

	// The curve, evaluated with the render's builder at view resolution.
	NSUInteger sampleCount = MAX((NSUInteger)bounds.size.width, (NSUInteger)8);
	float *lut = malloc(sampleCount * sizeof(float));
	[_curve buildLUT:lut count:sampleCount];

	NSPoint *points = malloc(sampleCount * sizeof(NSPoint));
	for (NSUInteger sample = 0; sample < sampleCount; sample++) {
		CGFloat fraction = (CGFloat)sample / (sampleCount - 1);
		points[sample] = [self viewPointForCurvePoint:CGPointMake(fraction, lut[sample])];
	}
	free(lut);

	if (_lineStyle == FxGripCurveLineStyleHue) {
		// One short segment per sample, colored by the hue at its x, so the line is a rainbow.
		for (NSUInteger sample = 1; sample < sampleCount; sample++) {
			CGFloat fraction = (CGFloat)sample / (sampleCount - 1);
			NSBezierPath *segment = [NSBezierPath bezierPath];
			segment.lineWidth = _lineWidth;
			[segment moveToPoint:points[sample - 1]];
			[segment lineToPoint:points[sample]];
			[[NSColor colorWithCalibratedHue:fraction saturation:1.0 brightness:1.0 alpha:1.0] setStroke];
			[segment stroke];
		}
	} else {
		NSBezierPath *path = [NSBezierPath bezierPath];
		path.lineWidth = _lineWidth;
		[path moveToPoint:points[0]];
		for (NSUInteger sample = 1; sample < sampleCount; sample++) {
			[path lineToPoint:points[sample]];
		}
		[self.lineColor setStroke];
		[path stroke];
	}
	free(points);

	// Control points; the selected one fills with the accent color.
	for (NSUInteger index = 0; index < _curve.pointCount; index++) {
		NSPoint center = [self viewPointForCurvePoint:[_curve pointAtIndex:index]];
		NSRect knob = NSMakeRect(center.x - kFxGripCurvePointRadius,
								 center.y - kFxGripCurvePointRadius,
								 kFxGripCurvePointRadius * 2, kFxGripCurvePointRadius * 2);
		NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:knob];
		if (index == _selectedPointIndex) {
			[[NSColor controlAccentColor] setFill];
		} else {
			[[NSColor whiteColor] setFill];
		}
		[dot fill];
	}

	[self drawReadoutInBounds:bounds];
}

#pragma mark Readout

/*! The value component in the configured units. isX distinguishes the degrees unit of a circular x. */
- (NSString *)readoutComponent:(CGFloat)value axisX:(BOOL)isX
{
	switch (_pointReadoutUnits) {
		case FxGripCurveReadoutUnitsEightBit:
			return [NSString stringWithFormat:@"%d", (int)lround(value * 255.0)];
		case FxGripCurveReadoutUnitsPercent:
			return [NSString stringWithFormat:@"%.0f%%", value * 100.0];
		case FxGripCurveReadoutUnitsDomainAware:
			if (isX && _domain == FxGripCurveDomainCircular) {
				return [NSString stringWithFormat:@"%.0f°", value * 360.0];
			}
			return [NSString stringWithFormat:@"%d", (int)lround(value * 255.0)];
		case FxGripCurveReadoutUnitsNormalized:
		default:
			return [NSString stringWithFormat:@"%.2f", value];
	}
}

- (NSString *)readoutStringForCurvePoint:(CGPoint)point
{
	return [NSString stringWithFormat:@"%@, %@",
			[self readoutComponent:point.x axisX:YES], [self readoutComponent:point.y axisX:NO]];
}

- (NSDictionary *)readoutTextAttributes
{
	return @{ NSFontAttributeName: [NSFont systemFontOfSize:9.5],
			  NSForegroundColorAttributeName: [NSColor whiteColor] };
}

/*! The point the readout describes: the selected (or dragged) point, else a hovered point. */
- (NSUInteger)readoutPointIndex
{
	if (_selectedPointIndex != NSNotFound) {
		return _selectedPointIndex;
	}
	return _hoveredPointIndex;
}

/*! Fills a rounded chip and draws the text in it. */
- (void)drawReadoutChip:(NSString *)text inRect:(NSRect)chip attributes:(NSDictionary *)attributes
{
	NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:chip xRadius:4.0 yRadius:4.0];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.72] setFill];
	[background fill];
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setStroke];
	[background stroke];
	[text drawAtPoint:NSMakePoint(chip.origin.x + 5.0, chip.origin.y + 3.0) withAttributes:attributes];
}

- (NSRect)readoutChipRectForText:(NSString *)text near:(NSPoint)at inBounds:(NSRect)bounds
{
	NSSize size = [text sizeWithAttributes:[self readoutTextAttributes]];
	NSRect chip = NSMakeRect(at.x + 9.0, at.y + 9.0, size.width + 10.0, size.height + 6.0);
	if (NSMaxX(chip) > NSMaxX(bounds)) {
		chip.origin.x = at.x - 9.0 - chip.size.width;
	}
	chip.origin.x = MAX(bounds.origin.x, chip.origin.x);
	if (NSMaxY(chip) > NSMaxY(bounds)) {
		chip.origin.y = at.y - 9.0 - chip.size.height;
	}
	chip.origin.y = MAX(bounds.origin.y, chip.origin.y);
	return chip;
}

- (void)drawReadoutInBounds:(NSRect)bounds
{
	if (_pointReadoutStyle == FxGripCurveReadoutStyleNone) {
		self.toolTip = nil;
		return;
	}
	NSUInteger index = [self readoutPointIndex];
	if (index == NSNotFound || index >= _curve.pointCount) {
		if (_pointReadoutStyle == FxGripCurveReadoutStyleSystemTooltip) {
			self.toolTip = nil;
		}
		return;
	}

	CGPoint curvePoint = [_curve pointAtIndex:index];
	NSString *text = [self readoutStringForCurvePoint:curvePoint];
	NSPoint at = [self viewPointForCurvePoint:curvePoint];
	NSDictionary *attributes = [self readoutTextAttributes];

	switch (_pointReadoutStyle) {
		case FxGripCurveReadoutStyleFloatingChip: {
			[self drawReadoutChip:text inRect:[self readoutChipRectForText:text near:at inBounds:bounds]
					   attributes:attributes];
			break;
		}
		case FxGripCurveReadoutStyleAxis: {
			NSBezierPath *guide = [NSBezierPath bezierPath];
			guide.lineWidth = 1.0;
			CGFloat dash[2] = { 2.0, 2.0 };
			[guide setLineDash:dash count:2 phase:0.0];
			[guide moveToPoint:NSMakePoint(at.x, bounds.origin.y)];
			[guide lineToPoint:at];
			[guide moveToPoint:NSMakePoint(bounds.origin.x, at.y)];
			[guide lineToPoint:at];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] setStroke];
			[guide stroke];

			NSString *xText = [self readoutComponent:curvePoint.x axisX:YES];
			NSString *yText = [self readoutComponent:curvePoint.y axisX:NO];
			NSSize xSize = [xText sizeWithAttributes:attributes];
			CGFloat xOrigin = MIN(MAX(bounds.origin.x, at.x - xSize.width / 2.0 - 5.0),
								  NSMaxX(bounds) - xSize.width - 10.0);
			[self drawReadoutChip:xText
						   inRect:NSMakeRect(xOrigin, bounds.origin.y + 1.0, xSize.width + 10.0, xSize.height + 6.0)
					   attributes:attributes];
			NSSize ySize = [yText sizeWithAttributes:attributes];
			CGFloat yOrigin = MIN(MAX(bounds.origin.y, at.y - ySize.height / 2.0 - 3.0),
								  NSMaxY(bounds) - ySize.height - 6.0);
			[self drawReadoutChip:yText
						   inRect:NSMakeRect(bounds.origin.x + 1.0, yOrigin, ySize.width + 10.0, ySize.height + 6.0)
					   attributes:attributes];
			break;
		}
		case FxGripCurveReadoutStyleCorner: {
			NSSize size = [text sizeWithAttributes:attributes];
			NSRect chip = NSMakeRect(bounds.origin.x + 4.0, NSMaxY(bounds) - size.height - 10.0,
									 size.width + 10.0, size.height + 6.0);
			[self drawReadoutChip:text inRect:chip attributes:attributes];
			break;
		}
		case FxGripCurveReadoutStyleSystemTooltip:
			self.toolTip = text;
			break;
		default:
			break;
	}
}

@end
