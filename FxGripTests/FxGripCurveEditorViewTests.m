//
//  FxGripCurveEditorViewTests.m
//  FxGripTests
//
//  Unit tests for the curve editor views: the reusable strip (FxGripCurveEditorView) and
//  the inspector composite (FxGripCurveSetEditorView).
//
//  The strip is driven with synthetic NSEvents handed straight to -mouseDown:,
//  -mouseDragged:, -mouseUp: and -keyDown:. A view with no window converts a window
//  location through an identity transform, so an event location is the view location; the
//  first test states that convention and every later interaction relies on it.
//
//  The composite's commit path reaches the host through FxGripOOBParameterAccess and
//  effect.apiManager.paramSetAPIv5, so it runs against the shared parameter-class doubles
//  with an action API added, the same harness the switch view's write uses.
//
//  AppKit is not linked into the test bundle. Its headers supply the view types, the event
//  types and the drawing signatures; every AppKit class is reached by name through a probe
//  protocol, so nothing is referenced at link time.
//

#import <XCTest/XCTest.h>
#import <objc/message.h>
#import <AppKit/AppKit.h>
#import "FxGripParameterClassTestSupport.h"
#import <FxGrip/FxGripCurveEditorView.h>
#import <FxGrip/FxGripCurveSetEditorView.h>
#import <FxGrip/FxGripEventModifiers.h>

static const FxParameterId kCurveEditorTestParameter = 91;

// The strip metrics FxGripCurveEditorView.m and FxGripCurveSetEditorView.m lay out with.
static const CGFloat kCurveTestInset = 4.0;
static const CGFloat kCurveTestStripHeight = 72.0;
static const CGFloat kCurveTestLabelHeight = 16.0;
static const CGFloat kCurveTestStripSpacing = 6.0;

#pragma mark - Probes for the geometry the implementation keeps private

@interface FxGripCurveEditorView (FxGripCurveEditorViewTests)
- (NSRect)curveBounds;
- (NSPoint)viewPointForCurvePoint:(CGPoint)point;
- (CGPoint)curvePointForViewPoint:(NSPoint)point;
@end

#pragma mark - Probes for the AppKit classes the bundle does not link

/*! NSEvent's synthetic-event factories. */
@protocol FxGripCurveTestEventFactory <NSObject>
+ (nullable id)mouseEventWithType:(NSEventType)type
						 location:(NSPoint)location
					modifierFlags:(NSEventModifierFlags)flags
						timestamp:(NSTimeInterval)time
					 windowNumber:(NSInteger)windowNumber
						  context:(nullable id)context
					  eventNumber:(NSInteger)eventNumber
					   clickCount:(NSInteger)clickCount
						 pressure:(float)pressure;
+ (nullable id)keyEventWithType:(NSEventType)type
					   location:(NSPoint)location
				  modifierFlags:(NSEventModifierFlags)flags
					  timestamp:(NSTimeInterval)time
				   windowNumber:(NSInteger)windowNumber
						context:(nullable id)context
					 characters:(NSString *)characters
	charactersIgnoringModifiers:(NSString *)unmodified
					  isARepeat:(BOOL)repeat
						keyCode:(unsigned short)code;
@end

/*! NSBitmapImageRep's offscreen backing store. */
@protocol FxGripCurveTestBitmapRep <NSObject>
- (nullable id)initWithBitmapDataPlanes:(unsigned char *_Nullable *_Nullable)planes
							 pixelsWide:(NSInteger)width
							 pixelsHigh:(NSInteger)height
						  bitsPerSample:(NSInteger)bitsPerSample
						samplesPerPixel:(NSInteger)samplesPerPixel
							   hasAlpha:(BOOL)hasAlpha
							   isPlanar:(BOOL)isPlanar
						 colorSpaceName:(NSString *)colorSpaceName
							bytesPerRow:(NSInteger)rowBytes
						   bitsPerPixel:(NSInteger)pixelBits;
@end

/*! NSGraphicsContext's offscreen context stack. */
@protocol FxGripCurveTestGraphicsContext <NSObject>
+ (nullable id)graphicsContextWithBitmapImageRep:(id)rep;
+ (void)setCurrentContext:(nullable id)context;
+ (void)saveGraphicsState;
+ (void)restoreGraphicsState;
@end

#pragma mark - Test doubles

/*! Records the curves the strip reports, in order. */
@interface FxGripCurveTestEditorDelegate : NSObject <FxGripCurveEditorDelegate>
@property (nonatomic, strong) NSMutableArray<FxGripCurveData *> *edited;
@property (nonatomic, strong) NSMutableArray<FxGripCurveData *> *committed;
@end

@implementation FxGripCurveTestEditorDelegate

- (instancetype)init
{
	self = [super init];
	if (self) {
		_edited = NSMutableArray.new;
		_committed = NSMutableArray.new;
	}
	return self;
}

- (void)curveEditorView:(FxGripCurveEditorView *)editor didEditCurve:(FxGripCurveData *)curve
{
	[self.edited addObject:curve];
}

- (void)curveEditorView:(FxGripCurveEditorView *)editor didCommitCurve:(FxGripCurveData *)curve
{
	[self.committed addObject:curve];
}

@end

/*! Stands in for the host's FxCustomParameterActionAPI_v4 the out-of-band access brackets. */
@interface FxGripCurveTestActionAPI : NSObject
@property (nonatomic, assign) CMTime currentTime;
@property (nonatomic, assign) NSUInteger startCount;
@property (nonatomic, assign) NSUInteger endCount;
@end

@implementation FxGripCurveTestActionAPI

- (instancetype)init
{
	self = [super init];
	if (self) {
		_currentTime = FxGripParamClassTestTime(30, 60);
	}
	return self;
}

- (void)startAction:(id)sender
{
	self.startCount += 1;
}

- (void)endAction:(id)sender
{
	self.endCount += 1;
}

@end

/*! Adds the action API the shared manager double does not carry. */
@interface FxGripCurveTestAPIManager : FxGripParamClassTestAPIManager
@property (nonatomic, strong) FxGripCurveTestActionAPI *customParameterActionAPIv4;
@end

@implementation FxGripCurveTestAPIManager

- (instancetype)init
{
	self = [super init];
	if (self) {
		_customParameterActionAPIv4 = [FxGripCurveTestActionAPI.alloc init];
	}
	return self;
}

@end

#pragma mark - Strip

@interface FxGripCurveEditorViewTests : XCTestCase
@property (nonatomic, strong) FxGripCurveEditorView *editor;
@property (nonatomic, strong) FxGripCurveTestEditorDelegate *recorder;
@end

@implementation FxGripCurveEditorViewTests

- (void)setUp
{
	[super setUp];
	self.recorder = [FxGripCurveTestEditorDelegate.alloc init];
	self.editor = [self editorWithRole:FxGripCurveRoleRemap domain:FxGripCurveDomainLinear];
}

- (void)tearDown
{
	self.editor = nil;
	self.recorder = nil;
	[super tearDown];
}

#pragma mark Helpers

- (FxGripCurveEditorView *)editorWithRole:(FxGripCurveRole)role domain:(FxGripCurveDomain)domain
{
	FxGripCurveEditorView *editor = [FxGripCurveEditorView.alloc initWithFrame:NSMakeRect(0, 0, 100, 100)
																		 role:role
																	   domain:domain
																   background:FxGripCurveBackgroundGrid];
	editor.delegate = self.recorder;
	return editor;
}

- (Class<FxGripCurveTestEventFactory>)eventFactory
{
	Class factory = NSClassFromString(@"NSEvent");
	XCTAssertNotNil(factory, @"NSEvent must be reachable through the framework's AppKit link");
	return (Class<FxGripCurveTestEventFactory>)factory;
}

- (NSEvent *)mouseEventOfType:(NSEventType)type at:(NSPoint)location clickCount:(NSInteger)clickCount
{
	return [self mouseEventOfType:type at:location clickCount:clickCount modifierFlags:0];
}

- (NSEvent *)mouseEventOfType:(NSEventType)type at:(NSPoint)location clickCount:(NSInteger)clickCount
				modifierFlags:(NSEventModifierFlags)flags
{
	id event = [self.eventFactory mouseEventWithType:type
											location:location
									   modifierFlags:flags
										   timestamp:0
										windowNumber:0
											 context:nil
										 eventNumber:0
										  clickCount:clickCount
											pressure:1.0];
	XCTAssertNotNil(event, @"the synthetic mouse event must be built");
	return (NSEvent *)event;
}

- (NSEvent *)deleteKeyEvent
{
	NSString *characters = [NSString stringWithFormat:@"%C", (unichar)NSDeleteCharacter];
	id event = [self.eventFactory keyEventWithType:NSEventTypeKeyDown
										  location:NSZeroPoint
									 modifierFlags:0
										 timestamp:0
									  windowNumber:0
										   context:nil
										characters:characters
					   charactersIgnoringModifiers:characters
										 isARepeat:NO
										   keyCode:51];
	XCTAssertNotNil(event, @"the synthetic key event must be built");
	return (NSEvent *)event;
}

- (void)clickAt:(NSPoint)location
{
	[self.editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown at:location clickCount:1]];
}

- (void)dragTo:(NSPoint)location
{
	[self.editor mouseDragged:[self mouseEventOfType:NSEventTypeLeftMouseDragged at:location clickCount:1]];
}

- (void)dragTo:(NSPoint)location modifierFlags:(NSEventModifierFlags)flags
{
	[self.editor mouseDragged:[self mouseEventOfType:NSEventTypeLeftMouseDragged at:location clickCount:1
										modifierFlags:flags]];
}

- (void)releaseAt:(NSPoint)location
{
	[self.editor mouseUp:[self mouseEventOfType:NSEventTypeLeftMouseUp at:location clickCount:1]];
}

- (FxGripCurveData *)curveWithPoints:(const CGPoint *)points
							   count:(NSUInteger)count
								role:(FxGripCurveRole)role
							  domain:(FxGripCurveDomain)domain
{
	return [FxGripCurveData curveWithPoints:points count:count role:role domain:domain];
}

/*! A linear remap with an interior point at the center of the strip. */
- (FxGripCurveData *)threePointRemap
{
	CGPoint points[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, 0.5), CGPointMake(1.0, 1.0)};
	return [self curveWithPoints:points count:3 role:FxGripCurveRoleRemap domain:FxGripCurveDomainLinear];
}

#pragma mark Event convention

/*!
	The suite drives the strip with events that never reach a window. NSView converts a
	window location through an identity transform when it has no window and sits at its
	frame origin, so an event location is a view location.
*/
- (void)testASyntheticEventLocationArrivesInViewCoordinates
{
	[self clickAt:NSMakePoint(50, 80)];

	CGPoint expected = [self.editor curvePointForViewPoint:NSMakePoint(50, 80)];
	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].x, expected.x, 1e-9);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].y, expected.y, 1e-9);
}

#pragma mark Geometry

- (void)testTheCurveBoundsInsetTheViewBounds
{
	NSRect bounds = [self.editor curveBounds];

	XCTAssertEqualWithAccuracy(bounds.origin.x, kCurveTestInset, 1e-9);
	XCTAssertEqualWithAccuracy(bounds.origin.y, kCurveTestInset, 1e-9);
	XCTAssertEqualWithAccuracy(bounds.size.width, 100.0 - 2 * kCurveTestInset, 1e-9);
	XCTAssertEqualWithAccuracy(bounds.size.height, 100.0 - 2 * kCurveTestInset, 1e-9);
}

- (void)testTheCornersAndCenterMapOntoTheInsetRect
{
	NSPoint origin = [self.editor viewPointForCurvePoint:CGPointMake(0.0, 0.0)];
	NSPoint corner = [self.editor viewPointForCurvePoint:CGPointMake(1.0, 1.0)];
	NSPoint center = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	XCTAssertEqualWithAccuracy(origin.x, 4.0, 1e-9);
	XCTAssertEqualWithAccuracy(origin.y, 4.0, 1e-9);
	XCTAssertEqualWithAccuracy(corner.x, 96.0, 1e-9);
	XCTAssertEqualWithAccuracy(corner.y, 96.0, 1e-9);
	XCTAssertEqualWithAccuracy(center.x, 50.0, 1e-9);
	XCTAssertEqualWithAccuracy(center.y, 50.0, 1e-9);
}

- (void)testAViewPointRoundTripsBackToItsCurvePoint
{
	const CGPoint samples[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, 0.25), CGPointMake(1.0, 1.0)};

	for (NSUInteger index = 0; index < 3; index++) {
		NSPoint view = [self.editor viewPointForCurvePoint:samples[index]];
		CGPoint back = [self.editor curvePointForViewPoint:view];
		XCTAssertEqualWithAccuracy(back.x, samples[index].x, 1e-9, @"x of sample %lu", (unsigned long)index);
		XCTAssertEqualWithAccuracy(back.y, samples[index].y, 1e-9, @"y of sample %lu", (unsigned long)index);
	}
}

- (void)testALinearViewPointOutsideTheStripClamps
{
	CGPoint low = [self.editor curvePointForViewPoint:NSMakePoint(-50, -50)];
	CGPoint high = [self.editor curvePointForViewPoint:NSMakePoint(300, 300)];

	XCTAssertEqualWithAccuracy(low.x, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy(low.y, 0.0, 1e-9);
	XCTAssertEqualWithAccuracy(high.x, 1.0, 1e-9);
	XCTAssertEqualWithAccuracy(high.y, 1.0, 1e-9);
}

- (void)testACircularViewPointOutsideTheStripFoldsInX
{
	FxGripCurveEditorView *circular = [self editorWithRole:FxGripCurveRoleShift
												   domain:FxGripCurveDomainCircular];

	CGPoint past = [circular curvePointForViewPoint:[circular viewPointForCurvePoint:CGPointMake(1.2, 0.5)]];
	CGPoint before = [circular curvePointForViewPoint:[circular viewPointForCurvePoint:CGPointMake(-0.25, 0.5)]];

	XCTAssertEqualWithAccuracy(past.x, 0.2, 1e-9);
	XCTAssertEqualWithAccuracy(before.x, 0.75, 1e-9);
	XCTAssertEqualWithAccuracy(past.y, 0.5, 1e-9, @"y still clamps rather than folding");
}

#pragma mark Data push

- (void)testTheStripTakesAPushedCurveDirectly
{
	FxGripCurveData *curve = [self threePointRemap];

	[self.editor updateFromCustomData:curve];

	XCTAssertEqualObjects(self.editor.curve, curve);
}

- (void)testTheStripReadsItsMappingKeyOutOfAPushedSet
{
	FxGripCurveData *curve = [self threePointRemap];
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	[set setCurve:curve forKey:@"luma"];
	self.editor.mappingKey = @"luma";

	[self.editor updateFromCustomData:set];

	XCTAssertEqualObjects(self.editor.curve, curve);
}

- (void)testAnAbsentKeyPushesTheRoleIdentity
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
																domain:FxGripCurveDomainLinear];
	self.editor.mappingKey = @"luma";
	[self.editor updateFromCustomData:[self threePointRemap]];

	[self.editor updateFromCustomData:[FxGripCurveSetData.alloc init]];

	XCTAssertEqualObjects(self.editor.curve, identity);
}

- (void)testTheStripIgnoresAValueOfAnotherClass
{
	FxGripCurveData *curve = [self threePointRemap];
	self.editor.mappingKey = @"luma";
	[self.editor updateFromCustomData:curve];

	[self.editor updateFromCustomData:nil];
	[self.editor updateFromCustomData:@"luma"];
	[self.editor updateFromCustomData:@(0.5)];
	[self.editor updateFromCustomData:(NSObject<NSSecureCoding, NSCopying> *)@{@"luma": curve}];

	XCTAssertEqualObjects(self.editor.curve, curve);
}

- (void)testANewCurveClearsASelectionBeyondItsPointCount
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:[self.editor viewPointForCurvePoint:CGPointMake(1.0, 1.0)]];
	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)2);

	self.editor.curve = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
														domain:FxGripCurveDomainLinear];

	XCTAssertEqual(self.editor.selectedPointIndex, NSNotFound);
}

- (void)testANewCurveKeepsASelectionInsideItsPointCount
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:[self.editor viewPointForCurvePoint:CGPointMake(0.0, 0.0)]];

	CGPoint points[3] = {CGPointMake(0.0, 0.2), CGPointMake(0.5, 0.4), CGPointMake(1.0, 0.9)};
	self.editor.curve = [self curveWithPoints:points count:3
										 role:FxGripCurveRoleRemap
									   domain:FxGripCurveDomainLinear];

	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)0);
}

#pragma mark Adding and selecting

- (void)testAClickAwayFromEveryPointAddsOneAtTheClickedLocation
{
	[self clickAt:NSMakePoint(50, 80)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].x, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].y, (80.0 - 4.0) / 92.0, 1e-9);
	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)1);
	XCTAssertEqual(self.recorder.edited.count, (NSUInteger)1);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)0);
}

- (void)testReleasingTheMouseCommitsTheAddedPoint
{
	[self clickAt:NSMakePoint(50, 80)];

	[self releaseAt:NSMakePoint(50, 80)];

	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.recorder.committed.lastObject, self.editor.curve);
}

- (void)testAClickOnAPointSelectsItWithoutEditing
{
	self.editor.curve = [self threePointRemap];

	[self clickAt:NSMakePoint(50, 50)];

	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)1);
	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqual(self.recorder.edited.count, (NSUInteger)0);
}

- (void)testAClickJustOutsideTheHitRadiusAddsAPoint
{
	self.editor.curve = [self threePointRemap];

	[self clickAt:NSMakePoint(58, 50)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)4);
}

#pragma mark Dragging

- (void)testDraggingAMiddlePointMovesItAndCommitsOnRelease
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:NSMakePoint(50, 50)];

	[self dragTo:NSMakePoint(60, 70)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].x, (60.0 - 4.0) / 92.0, 1e-9);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].y, (70.0 - 4.0) / 92.0, 1e-9);
	XCTAssertEqual(self.recorder.edited.count, (NSUInteger)1);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)0);

	[self dragTo:NSMakePoint(62, 72)];
	[self releaseAt:NSMakePoint(62, 72)];

	XCTAssertEqual(self.recorder.edited.count, (NSUInteger)2, @"every drag reports an edit");
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)1, @"the release is the only commit");
}

- (void)testALinearEndpointKeepsItsXWhileDragging
{
	[self clickAt:NSMakePoint(4, 4)];
	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)0);

	[self dragTo:NSMakePoint(50, 50)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:0].x, 0.0, 1e-9, @"the first point pins in x");
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:0].y, 0.5, 1e-9);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].x, 1.0, 1e-9);
}

- (void)testTheLinearLastPointPinsInXWhileDragging
{
	[self clickAt:NSMakePoint(96, 96)];
	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)1);

	[self dragTo:NSMakePoint(50, 50)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].x, 1.0, 1e-9);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:1].y, 0.5, 1e-9);
}

- (void)testACircularPointDraggedPastTheRightEdgeWrapsToTheLeft
{
	FxGripCurveEditorView *circular = [self editorWithRole:FxGripCurveRoleShift
												   domain:FxGripCurveDomainCircular];
	self.editor = circular;

	[self clickAt:NSMakePoint(96, 50)];
	XCTAssertEqual(circular.selectedPointIndex, (NSUInteger)1);

	[self dragTo:NSMakePoint(4.0 + 1.1 * 92.0, 50)];

	XCTAssertEqual(circular.curve.pointCount, (NSUInteger)2);
	XCTAssertEqualWithAccuracy([circular.curve pointAtIndex:1].x, 0.1, 1e-9, @"x = 1.1 wraps to x = 0.1");
	XCTAssertEqual(circular.selectedPointIndex, (NSUInteger)1);
}

#pragma mark Removal

- (void)testDraggingAPointFarOutsideTheStripRemovesIt
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:NSMakePoint(50, 50)];

	[self dragTo:NSMakePoint(50, 200)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)2);
	XCTAssertEqual(self.editor.selectedPointIndex, NSNotFound);
	XCTAssertEqual(self.recorder.edited.count, (NSUInteger)1);
}

- (void)testDraggingJustOutsideTheStripKeepsThePoint
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:NSMakePoint(50, 50)];

	[self dragTo:NSMakePoint(50, 130)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3, @"the removal margin is 40 points");
}

- (void)testATwoPointLinearCurveKeepsBothPointsWhenDraggedOutside
{
	[self clickAt:NSMakePoint(4, 4)];

	[self dragTo:NSMakePoint(50, 400)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)2, @"the linear floor is two points");
}

- (void)testTheDeleteKeyRemovesTheSelectedPointAndCommits
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:NSMakePoint(50, 50)];

	[self.editor keyDown:[self deleteKeyEvent]];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)2);
	XCTAssertEqual(self.editor.selectedPointIndex, NSNotFound);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)1);
	XCTAssertEqualObjects(self.recorder.committed.lastObject, self.editor.curve);
}

- (void)testTheDeleteKeyKeepsTheLastTwoPointsOfALinearCurve
{
	[self clickAt:NSMakePoint(4, 4)];

	[self.editor keyDown:[self deleteKeyEvent]];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)2);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)0);
}

- (void)testTheDeleteKeyWithoutASelectionChangesNothing
{
	self.editor.curve = [self threePointRemap];

	[self.editor keyDown:[self deleteKeyEvent]];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)0);
}

#pragma mark Reset

- (void)testADoubleClickResetsToTheRoleIdentityAndCommits
{
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
																domain:FxGripCurveDomainLinear];
	self.editor.curve = [self threePointRemap];

	[self.editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown
											   at:NSMakePoint(50, 80)
									   clickCount:2]];

	XCTAssertEqualObjects(self.editor.curve, identity);
	XCTAssertEqual(self.editor.selectedPointIndex, NSNotFound);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)1);
	XCTAssertEqual(self.recorder.edited.count, (NSUInteger)0);
}

- (void)testResetCurveReplacesTheCurveWithTheRoleIdentityAndCommits
{
	FxGripCurveEditorView *shift = [self editorWithRole:FxGripCurveRoleShift
												domain:FxGripCurveDomainLinear];
	CGPoint points[2] = {CGPointMake(0.0, 0.2), CGPointMake(1.0, 0.9)};
	shift.curve = [self curveWithPoints:points count:2
								   role:FxGripCurveRoleShift
								 domain:FxGripCurveDomainLinear];

	[shift resetCurve];

	XCTAssertTrue(shift.curve.isIdentity);
	XCTAssertEqualWithAccuracy([shift.curve pointAtIndex:0].y, 0.5, 1e-9);
	XCTAssertEqual(self.recorder.committed.count, (NSUInteger)1);
}

#pragma mark Modifier-click deletion

/*! Adds an interior point through the click path and clears the recorder. */
- (void)stageInteriorPointAt:(CGPoint)curvePoint
{
	[self clickAt:[self.editor viewPointForCurvePoint:curvePoint]];
	[self.editor mouseUp:[self mouseEventOfType:NSEventTypeLeftMouseUp
											 at:[self.editor viewPointForCurvePoint:curvePoint]
									 clickCount:1]];
	[self.recorder.edited removeAllObjects];
	[self.recorder.committed removeAllObjects];
}

- (void)testACommandClickOnAnInteriorPointDeletesItAndCommits
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSUInteger before = self.editor.curve.pointCount;

	NSPoint location = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];
	[self.editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown at:location clickCount:1
									modifierFlags:NSEventModifierFlagCommand]];

	XCTAssertEqual(self.editor.curve.pointCount, before - 1);
	XCTAssertEqualObjects(self.recorder.committed.lastObject, self.editor.curve);
}

- (void)testAControlClickIsLeftToTheContextMenuAndDoesNotSelect
{
	// Control-click is a contextual menu on macOS; mouseDown ignores it so only the menu responds.
	// The editor starts with no selection, and a Control-click must not create one.
	XCTAssertEqual(self.editor.selectedPointIndex, NSNotFound);
	NSUInteger before = self.editor.curve.pointCount;

	NSPoint location = [self.editor viewPointForCurvePoint:[self.editor.curve pointAtIndex:0]];
	[self.editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown at:location clickCount:1
									modifierFlags:NSEventModifierFlagControl]];

	XCTAssertEqual(self.editor.curve.pointCount, before);
	XCTAssertEqual(self.editor.selectedPointIndex, NSNotFound, @"Control-click does not select");
}

- (void)testACommandClickOnAPinnedEndpointDeletesNothing
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSUInteger before = self.editor.curve.pointCount;

	NSPoint location = [self.editor viewPointForCurvePoint:[self.editor.curve pointAtIndex:0]];
	[self.editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown at:location clickCount:1
									modifierFlags:NSEventModifierFlagCommand]];

	XCTAssertEqual(self.editor.curve.pointCount, before);
}

- (void)testACommandClickAwayFromAnyPointAddsNothing
{
	NSUInteger before = self.editor.curve.pointCount;

	NSPoint location = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.9)];
	[self.editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown at:location clickCount:1
									modifierFlags:NSEventModifierFlagCommand]];

	XCTAssertEqual(self.editor.curve.pointCount, before);
	XCTAssertEqual(self.recorder.edited.count, 0u);
}

#pragma mark Option-slowed drag

- (void)testAnOptionDragMovesThePointAtOneTenthOfMouseTravel
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSPoint start = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	[self clickAt:start];
	[self dragTo:NSMakePoint(start.x + 40.0, start.y) modifierFlags:NSEventModifierFlagOption];
	[self releaseAt:NSMakePoint(start.x + 40.0, start.y)];

	CGPoint expected = [self.editor curvePointForViewPoint:NSMakePoint(start.x + 4.0, start.y)];
	NSUInteger moved = self.editor.selectedPointIndex;
	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:moved].x, expected.x, 1e-6);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:moved].y, expected.y, 1e-6);
}

- (void)testReleasingOptionMidDragResumesFullSpeedFromThePointsPosition
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSPoint start = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	[self clickAt:start];
	[self dragTo:NSMakePoint(start.x + 40.0, start.y) modifierFlags:NSEventModifierFlagOption];
	[self dragTo:NSMakePoint(start.x + 60.0, start.y)];
	[self releaseAt:NSMakePoint(start.x + 60.0, start.y)];

	// 40 points slowed to 4, then 20 more at full speed: the point sits 24 from start.
	CGPoint expected = [self.editor curvePointForViewPoint:NSMakePoint(start.x + 24.0, start.y)];
	NSUInteger moved = self.editor.selectedPointIndex;
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:moved].x, expected.x, 1e-6);
}

- (void)testASlowedDragFarOutsideTheStripMovesThePointInsteadOfRemovingIt
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSPoint start = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	[self clickAt:start];
	[self dragTo:NSMakePoint(start.x, start.y + 300.0) modifierFlags:NSEventModifierFlagOption];
	[self releaseAt:NSMakePoint(start.x, start.y + 300.0)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	CGPoint expected = [self.editor curvePointForViewPoint:NSMakePoint(start.x, start.y + 30.0)];
	NSUInteger moved = self.editor.selectedPointIndex;
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:moved].y, expected.y, 1e-6);
}

- (void)testTheSlowDragScaleDefaultsToOneTenth
{
	XCTAssertEqualWithAccuracy(kFxGripCurveSlowDragScaleDefault, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy(self.editor.slowDragScale, kFxGripCurveSlowDragScaleDefault, 1e-12);
}

- (void)testTheSlowDragScaleClampsIntoItsRange
{
	self.editor.slowDragScale = 5.0;
	XCTAssertEqualWithAccuracy(self.editor.slowDragScale, 1.0, 1e-12);

	self.editor.slowDragScale = 0.0;
	XCTAssertEqualWithAccuracy(self.editor.slowDragScale, 0.01, 1e-12);

	self.editor.slowDragScale = -3.0;
	XCTAssertEqualWithAccuracy(self.editor.slowDragScale, 0.01, 1e-12);

	self.editor.slowDragScale = 0.2;
	XCTAssertEqualWithAccuracy(self.editor.slowDragScale, 0.2, 1e-12);
}

- (void)testACustomSlowDragScaleGovernsTheSlowedDrag
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	self.editor.slowDragScale = 0.5;
	NSPoint start = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	[self clickAt:start];
	[self dragTo:NSMakePoint(start.x + 40.0, start.y) modifierFlags:NSEventModifierFlagOption];
	[self releaseAt:NSMakePoint(start.x + 40.0, start.y)];

	CGPoint expected = [self.editor curvePointForViewPoint:NSMakePoint(start.x + 20.0, start.y)];
	NSUInteger moved = self.editor.selectedPointIndex;
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:moved].x, expected.x, 1e-6);
}

#pragma mark Shift-constrained drag

- (void)testAShiftDragWithDominantHorizontalPinsY
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSPoint start = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	[self clickAt:start];
	[self dragTo:NSMakePoint(start.x + 40.0, start.y + 8.0) modifierFlags:NSEventModifierFlagShift];
	[self releaseAt:NSMakePoint(start.x + 40.0, start.y + 8.0)];

	CGPoint result = [self.editor.curve pointAtIndex:self.editor.selectedPointIndex];
	XCTAssertEqualWithAccuracy(result.y, 0.5, 1e-6, @"y stays at the drag start");
	XCTAssertGreaterThan(result.x, 0.5, @"x moves");
}

- (void)testAShiftDragWithDominantVerticalPinsX
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];
	NSPoint start = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];

	[self clickAt:start];
	[self dragTo:NSMakePoint(start.x + 8.0, start.y + 40.0) modifierFlags:NSEventModifierFlagShift];
	[self releaseAt:NSMakePoint(start.x + 8.0, start.y + 40.0)];

	CGPoint result = [self.editor.curve pointAtIndex:self.editor.selectedPointIndex];
	XCTAssertEqualWithAccuracy(result.x, 0.5, 1e-6, @"x stays at the drag start");
	XCTAssertGreaterThan(result.y, 0.5, @"y moves");
}

- (void)testEventModifiersMapToTheHouseConvention
{
	NSPoint p = NSMakePoint(10.0, 10.0);
	NSEvent *option  = [self mouseEventOfType:NSEventTypeLeftMouseDown at:p clickCount:1 modifierFlags:NSEventModifierFlagOption];
	NSEvent *shift   = [self mouseEventOfType:NSEventTypeLeftMouseDown at:p clickCount:1 modifierFlags:NSEventModifierFlagShift];
	NSEvent *command = [self mouseEventOfType:NSEventTypeLeftMouseDown at:p clickCount:1 modifierFlags:NSEventModifierFlagCommand];
	NSEvent *control = [self mouseEventOfType:NSEventTypeLeftMouseDown at:p clickCount:1 modifierFlags:NSEventModifierFlagControl];

	XCTAssertTrue([FxGripEventModifiers isFineDrag:option]);
	XCTAssertTrue([FxGripEventModifiers isConstrain:shift]);
	XCTAssertTrue([FxGripEventModifiers isDeleteClick:command]);
	XCTAssertTrue([FxGripEventModifiers isContextMenu:control]);
	XCTAssertFalse([FxGripEventModifiers isFineDrag:shift]);
	XCTAssertFalse([FxGripEventModifiers isDeleteClick:option]);
}

#pragma mark Context menu

- (void)testTheContextMenuOverAPointOffersDeletePoint
{
	[self stageInteriorPointAt:CGPointMake(0.5, 0.5)];

	NSPoint location = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)];
	NSMenu *menu = [self.editor menuForEvent:[self mouseEventOfType:NSEventTypeRightMouseDown
																 at:location clickCount:1]];

	XCTAssertEqualObjects([menu itemAtIndex:0].title, @"Delete Point");
	NSUInteger before = self.editor.curve.pointCount;
	((void (*)(id, SEL, id))objc_msgSend)(self.editor, [menu itemAtIndex:0].action, nil);
	XCTAssertEqual(self.editor.curve.pointCount, before - 1);
}

- (void)testTheContextMenuAwayFromPointsOffersOnlyReset
{
	NSPoint location = [self.editor viewPointForCurvePoint:CGPointMake(0.5, 0.9)];
	NSMenu *menu = [self.editor menuForEvent:[self mouseEventOfType:NSEventTypeRightMouseDown
																 at:location clickCount:1]];

	XCTAssertEqual(menu.numberOfItems, 1);
	XCTAssertEqualObjects([menu itemAtIndex:0].title, @"Reset Curve");
}

#pragma mark Drawing

- (void)testEveryBackgroundStyleDraws
{
	Class repClass = NSClassFromString(@"NSBitmapImageRep");
	Class contextClass = NSClassFromString(@"NSGraphicsContext");
	XCTAssertNotNil(repClass);
	XCTAssertNotNil(contextClass);
	Class<FxGripCurveTestGraphicsContext> context = (Class<FxGripCurveTestGraphicsContext>)contextClass;

	for (FxGripCurveBackground background = FxGripCurveBackgroundGrid;
		 background <= FxGripCurveBackgroundAlphaChecker;
		 background++) {
		@autoreleasepool {
			FxGripCurveEditorView *editor =
				[FxGripCurveEditorView.alloc initWithFrame:NSMakeRect(0, 0, 100, 60)
													  role:FxGripCurveRoleRemap
													domain:FxGripCurveDomainLinear
												background:background];
			editor.curve = [self threePointRemap];
			[editor mouseDown:[self mouseEventOfType:NSEventTypeLeftMouseDown
												  at:[editor viewPointForCurvePoint:CGPointMake(0.5, 0.5)]
										  clickCount:1]];

			id<FxGripCurveTestBitmapRep> rep = [(id<FxGripCurveTestBitmapRep>)[repClass alloc]
										    initWithBitmapDataPlanes:NULL
														  pixelsWide:100
														  pixelsHigh:60
													   bitsPerSample:8
													 samplesPerPixel:4
															hasAlpha:YES
															isPlanar:NO
													  colorSpaceName:@"NSCalibratedRGBColorSpace"
														 bytesPerRow:0
														bitsPerPixel:0];
			XCTAssertNotNil(rep, @"background %ld", (long)background);

			[context saveGraphicsState];
			[context setCurrentContext:[context graphicsContextWithBitmapImageRep:rep]];
			XCTAssertNoThrow([editor drawRect:editor.bounds], @"background %ld", (long)background);
			[context restoreGraphicsState];
		}
	}
}

#pragma mark Defects

/*! A linear curve's pinned endpoints define the domain, so neither drag-out nor the
	Delete key removes them, whatever the point count. */
- (void)testDraggingAPinnedEndpointOutsideTheStripKeepsIt
{
	self.editor.curve = [self threePointRemap];
	[self clickAt:NSMakePoint(4, 4)];
	XCTAssertEqual(self.editor.selectedPointIndex, (NSUInteger)0);

	[self dragTo:NSMakePoint(50, 200)];

	XCTAssertEqual(self.editor.curve.pointCount, (NSUInteger)3);
	XCTAssertEqualWithAccuracy([self.editor.curve pointAtIndex:0].x, 0.0, 1e-9);
}

#pragma mark Line color

- (void)testTheLineColorDefaultsToWhiteAndIsSettable
{
	Class colorClass = NSClassFromString(@"NSColor");
	XCTAssertEqualObjects(self.editor.lineColor, [colorClass whiteColor], @"defaults to white");

	NSColor *red = [colorClass redColor];
	self.editor.lineColor = red;
	XCTAssertEqualObjects(self.editor.lineColor, red, @"an arbitrary color is stored");

	self.editor.lineColor = nil;
	XCTAssertEqualObjects(self.editor.lineColor, [colorClass whiteColor], @"nil restores white");
}

- (void)testTheLineWidthDefaultsToOneAndClampsIntoItsRange
{
	XCTAssertEqualWithAccuracy(kFxGripCurveLineWidthDefault, 1.0, 1e-12);
	XCTAssertEqualWithAccuracy(self.editor.lineWidth, kFxGripCurveLineWidthDefault, 1e-12);

	self.editor.lineWidth = 3.5;
	XCTAssertEqualWithAccuracy(self.editor.lineWidth, 3.5, 1e-12);

	self.editor.lineWidth = 0.0;
	XCTAssertEqualWithAccuracy(self.editor.lineWidth, 0.1, 1e-12);

	self.editor.lineWidth = -2.0;
	XCTAssertEqualWithAccuracy(self.editor.lineWidth, 0.1, 1e-12);

	self.editor.lineWidth = 500.0;
	XCTAssertEqualWithAccuracy(self.editor.lineWidth, 8.0, 1e-12);
}

- (void)testTheLineStyleAndVerticalPaintsRoundTrip
{
	XCTAssertEqual(self.editor.lineStyle, FxGripCurveLineStyleSolid, @"defaults to solid");
	self.editor.lineStyle = FxGripCurveLineStyleHue;
	XCTAssertEqual(self.editor.lineStyle, FxGripCurveLineStyleHue);

	XCTAssertNil(self.editor.topPaint, @"no vertical paint by default");

	FxGripCurvePaint *hue = [FxGripCurvePaint huePaint];
	XCTAssertEqual(hue.kind, FxGripCurvePaintKindHue);
	XCTAssertNil(hue.color);

	NSColor *red = [NSClassFromString(@"NSColor") redColor];
	FxGripCurvePaint *colorPaint = [FxGripCurvePaint paintWithColor:red];
	XCTAssertEqual(colorPaint.kind, FxGripCurvePaintKindColor);
	XCTAssertEqualObjects(colorPaint.color, red);

	XCTAssertEqual([FxGripCurvePaint nonePaint].kind, FxGripCurvePaintKindNone);

	self.editor.topPaint = hue;
	self.editor.centerPaint = [FxGripCurvePaint nonePaint];
	self.editor.bottomPaint = colorPaint;
	XCTAssertEqual(self.editor.topPaint.kind, FxGripCurvePaintKindHue);
	XCTAssertEqual(self.editor.centerPaint.kind, FxGripCurvePaintKindNone);
	XCTAssertEqualObjects(self.editor.bottomPaint.color, red);
}

- (void)testTheReadoutPropertiesRoundTrip
{
	XCTAssertEqual(self.editor.pointReadoutStyle, FxGripCurveReadoutStyleNone, @"off by default");
	XCTAssertEqual(self.editor.pointReadoutUnits, FxGripCurveReadoutUnitsNormalized);
	XCTAssertEqual(self.editor.pointReadoutTrigger, FxGripCurveReadoutTriggerActivePoint);

	self.editor.pointReadoutStyle = FxGripCurveReadoutStyleAxis;
	self.editor.pointReadoutUnits = FxGripCurveReadoutUnitsEightBit;
	self.editor.pointReadoutTrigger = FxGripCurveReadoutTriggerActiveAndModifierHover;
	XCTAssertEqual(self.editor.pointReadoutStyle, FxGripCurveReadoutStyleAxis);
	XCTAssertEqual(self.editor.pointReadoutUnits, FxGripCurveReadoutUnitsEightBit);
	XCTAssertEqual(self.editor.pointReadoutTrigger, FxGripCurveReadoutTriggerActiveAndModifierHover);
}

@end

#pragma mark - Composite

@interface FxGripCurveSetEditorViewTests : XCTestCase
@property (nonatomic, strong) FxGripCurveSetEditorView *composite;
@property (nonatomic, strong) FxGripParamClassTestEffect *effect;
@property (nonatomic, strong) FxGripCurveTestAPIManager *apiManager;
@end

@implementation FxGripCurveSetEditorViewTests

- (void)setUp
{
	[super setUp];
	self.effect = [FxGripParamClassTestEffect.alloc init];
	self.apiManager = [FxGripCurveTestAPIManager.alloc init];
	self.effect.apiManager = (FxGripParamClassTestAPIManager *)self.apiManager;
	self.composite = [FxGripCurveSetEditorView.alloc initWithFrame:NSMakeRect(0, 0, 200, 10)];
	self.composite.parameterID = kCurveEditorTestParameter;
}

- (void)tearDown
{
	self.composite = nil;
	self.effect = nil;
	self.apiManager = nil;
	[super tearDown];
}

#pragma mark Helpers

- (FxGripCurveData *)remapCurveWithMidY:(CGFloat)midY
{
	CGPoint points[3] = {CGPointMake(0.0, 0.0), CGPointMake(0.5, midY), CGPointMake(1.0, 1.0)};
	return [FxGripCurveData curveWithPoints:points count:3
									   role:FxGripCurveRoleRemap
									 domain:FxGripCurveDomainLinear];
}

- (FxGripCurveEditorView *)addLumaEditor
{
	return [self.composite addEditorForKey:@"luma"
									 title:@"Luma"
									  role:FxGripCurveRoleRemap
									domain:FxGripCurveDomainLinear
								background:FxGripCurveBackgroundLumaRamp];
}

- (FxGripCurveEditorView *)addHueEditor
{
	return [self.composite addEditorForKey:@"hueVsHue"
									 title:@"Hue vs Hue"
									  role:FxGripCurveRoleShift
									domain:FxGripCurveDomainCircular
								background:FxGripCurveBackgroundHueSpectrum];
}

- (void)attachEffect
{
	self.composite.parameterEffect = (id)self.effect;
}

- (NSDictionary *)lastWrite
{
	return self.apiManager.paramSetAPIv5.lastWrite;
}

#pragma mark Stacking

- (void)testAddingEditorsStacksThemAndGrowsTheFrame
{
	const CGFloat step = kCurveTestLabelHeight + kCurveTestStripHeight + kCurveTestStripSpacing;

	FxGripCurveEditorView *luma = [self addLumaEditor];
	XCTAssertEqualWithAccuracy(self.composite.frame.size.height, step, 1e-9);

	FxGripCurveEditorView *hue = [self addHueEditor];

	XCTAssertEqualWithAccuracy(self.composite.frame.size.height, 2 * step, 1e-9);
	XCTAssertEqualObjects(self.composite.editors, (@[luma, hue]));
	XCTAssertEqualWithAccuracy(luma.frame.origin.y, kCurveTestLabelHeight, 1e-9);
	XCTAssertEqualWithAccuracy(hue.frame.origin.y, step + kCurveTestLabelHeight, 1e-9);
	XCTAssertEqualWithAccuracy(luma.frame.size.height, kCurveTestStripHeight, 1e-9);
	XCTAssertEqualWithAccuracy(luma.frame.size.width, 200.0, 1e-9);
}

- (void)testTheCompositeStacksItsStripsTopDown
{
	XCTAssertTrue(self.composite.isFlipped);
}

- (void)testTheCompositeSlowDragScaleReachesExistingAndFutureStrips
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	self.composite.slowDragScale = 0.05;
	FxGripCurveEditorView *hue = [self addHueEditor];

	XCTAssertEqualWithAccuracy(self.composite.slowDragScale, 0.05, 1e-12);
	XCTAssertEqualWithAccuracy(luma.slowDragScale, 0.05, 1e-12);
	XCTAssertEqualWithAccuracy(hue.slowDragScale, 0.05, 1e-12);
}

- (void)testTheCompositeLineWidthReachesExistingAndFutureStrips
{
	XCTAssertEqualWithAccuracy(self.composite.lineWidth, kFxGripCurveLineWidthDefault, 1e-12);

	FxGripCurveEditorView *luma = [self addLumaEditor];
	self.composite.lineWidth = 2.5;
	FxGripCurveEditorView *hue = [self addHueEditor];

	XCTAssertEqualWithAccuracy(self.composite.lineWidth, 2.5, 1e-12);
	XCTAssertEqualWithAccuracy(luma.lineWidth, 2.5, 1e-12);
	XCTAssertEqualWithAccuracy(hue.lineWidth, 2.5, 1e-12);

	self.composite.lineWidth = 0.0;
	XCTAssertEqualWithAccuracy(self.composite.lineWidth, 0.1, 1e-12);
	XCTAssertEqualWithAccuracy(luma.lineWidth, 0.1, 1e-12);

	self.composite.lineWidth = 500.0;
	XCTAssertEqualWithAccuracy(self.composite.lineWidth, 8.0, 1e-12);
	XCTAssertEqualWithAccuracy(luma.lineWidth, 8.0, 1e-12);
}

- (void)testAddingAnEditorWiresItsMappingKeyAndDelegate
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	FxGripCurveEditorView *hue = [self addHueEditor];

	XCTAssertEqualObjects(luma.mappingKey, @"luma");
	XCTAssertEqualObjects(hue.mappingKey, @"hueVsHue");
	XCTAssertEqualObjects((id)luma.delegate, self.composite);
	XCTAssertEqualObjects((id)hue.delegate, self.composite);
	XCTAssertEqual(luma.background, FxGripCurveBackgroundLumaRamp);
	XCTAssertEqual(hue.background, FxGripCurveBackgroundHueSpectrum);
}

- (void)testAddingAnEditorAddsALabelAboveTheStrip
{
	Class textFieldClass = NSClassFromString(@"NSTextField");
	XCTAssertNotNil(textFieldClass);

	FxGripCurveEditorView *luma = [self addLumaEditor];

	XCTAssertEqual(self.composite.subviews.count, (NSUInteger)2);
	XCTAssertTrue([self.composite.subviews[0] isKindOfClass:textFieldClass]);
	XCTAssertEqualObjects(self.composite.subviews[1], luma);
	XCTAssertEqualObjects([self.composite.subviews[0] valueForKey:@"stringValue"], @"Luma");
}

- (void)testAddingAnEditorSeedsItFromTheWorkingSet
{
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	[set setCurve:curve forKey:@"luma"];
	[self.composite updateFromCustomData:set];

	FxGripCurveEditorView *luma = [self addLumaEditor];

	XCTAssertEqualObjects(luma.curve, curve);
}

#pragma mark Data push

- (void)testAPushedSetReachesEveryChildEditor
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	FxGripCurveEditorView *hue = [self addHueEditor];
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	[set setCurve:curve forKey:@"luma"];

	[self.composite updateFromCustomData:set];

	XCTAssertEqualObjects(luma.curve, curve);
	XCTAssertEqualObjects(hue.curve, [FxGripCurveData identityCurveWithRole:FxGripCurveRoleShift
																	 domain:FxGripCurveDomainCircular],
						  @"an absent key shows the mapping's neutral curve");
}

- (void)testTheWorkingSetIsAClassPreservingCopyOfThePushedSet
{
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	[set setCurve:curve forKey:@"luma"];

	[self.composite updateFromCustomData:set];

	XCTAssertEqualObjects(NSStringFromClass(self.composite.curveSet.class), @"FxGripCurveSetData");
	XCTAssertNotEqual(self.composite.curveSet, set, @"the working set is its own instance");
	XCTAssertEqualObjects([self.composite.curveSet curveForKey:@"luma"], curve);
}

- (void)testTheWorkingSetIsIndependentOfThePushedInstance
{
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	[set setCurve:curve forKey:@"luma"];
	[self.composite updateFromCustomData:set];

	[set setCurve:nil forKey:@"luma"];
	[set setCurve:[self remapCurveWithMidY:0.2] forKey:@"red"];

	XCTAssertEqualObjects([self.composite.curveSet curveForKey:@"luma"], curve);
	XCTAssertNil([self.composite.curveSet curveForKey:@"red"]);
}

- (void)testTheCompositeIgnoresAValueOfAnotherClass
{
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];
	FxGripCurveSetData *set = [FxGripCurveSetData.alloc init];
	[set setCurve:curve forKey:@"luma"];
	[self.composite updateFromCustomData:set];

	[self.composite updateFromCustomData:nil];
	[self.composite updateFromCustomData:@"luma"];
	[self.composite updateFromCustomData:curve];

	XCTAssertEqualObjects([self.composite.curveSet curveForKey:@"luma"], curve);
}

#pragma mark Strip edits

- (void)testAChildEditUpdatesTheWorkingSetWithoutWriting
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	[self attachEffect];
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];

	@autoreleasepool {
		[self.composite curveEditorView:luma didEditCurve:curve];
	}

	XCTAssertEqualObjects([self.composite.curveSet curveForKey:@"luma"], curve);
	XCTAssertEqualObjects(self.apiManager.paramSetAPIv5.writes, @[]);
	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.startCount, (NSUInteger)0);
}

- (void)testAChildCommitWritesTheSetInsideOneActionBracket
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	[self attachEffect];
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];

	@autoreleasepool {
		[self.composite curveEditorView:luma didCommitCurve:curve];
	}

	NSDictionary *write = self.lastWrite;
	XCTAssertEqual(self.apiManager.paramSetAPIv5.writes.count, (NSUInteger)1);
	XCTAssertEqualObjects(write[@"accessor"], @"custom");
	XCTAssertEqualObjects(write[@"id"], @(kCurveEditorTestParameter));
	XCTAssertEqualObjects(write[@"timevalue"], @30);
	XCTAssertTrue([write[@"value"] isKindOfClass:FxGripCurveSetData.class]);
	XCTAssertEqualObjects([(FxGripCurveSetData *)write[@"value"] curveForKey:@"luma"], curve);
	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.startCount, (NSUInteger)1);
	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.endCount, (NSUInteger)1);
}

- (void)testACommitKeepsTheCurvesTheOtherStripsOwn
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	FxGripCurveEditorView *hue = [self addHueEditor];
	[self attachEffect];
	CGPoint points[3] = {CGPointMake(0.1, 0.3), CGPointMake(0.5, 0.8), CGPointMake(0.9, 0.4)};
	FxGripCurveData *hueCurve = [FxGripCurveData curveWithPoints:points count:3
															role:FxGripCurveRoleShift
														  domain:FxGripCurveDomainCircular];

	@autoreleasepool {
		[self.composite curveEditorView:hue didCommitCurve:hueCurve];
		[self.composite curveEditorView:luma didCommitCurve:[self remapCurveWithMidY:0.8]];
	}

	XCTAssertEqualObjects([(FxGripCurveSetData *)self.lastWrite[@"value"] curveForKey:@"hueVsHue"], hueCurve);
	XCTAssertEqualObjects([(FxGripCurveSetData *)self.lastWrite[@"value"] curveKeys], (@[@"hueVsHue", @"luma"]));
}

- (void)testACommittedIdentityRemovesTheKeyFromTheWrittenSet
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	[self attachEffect];
	FxGripCurveData *identity = [FxGripCurveData identityCurveWithRole:FxGripCurveRoleRemap
																domain:FxGripCurveDomainLinear];

	@autoreleasepool {
		[self.composite curveEditorView:luma didCommitCurve:[self remapCurveWithMidY:0.8]];
		[self.composite curveEditorView:luma didCommitCurve:identity];
	}

	XCTAssertNil([(FxGripCurveSetData *)self.lastWrite[@"value"] curveForKey:@"luma"]);
	XCTAssertNil([self.composite.curveSet curveForKey:@"luma"]);
	XCTAssertEqual(self.apiManager.paramSetAPIv5.writes.count, (NSUInteger)2);
}

- (void)testAStripResetCommitsTheRoleIdentityThroughTheComposite
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	[self attachEffect];

	@autoreleasepool {
		[self.composite curveEditorView:luma didEditCurve:[self remapCurveWithMidY:0.8]];
		[luma resetCurve];
	}

	XCTAssertTrue(luma.curve.isIdentity);
	XCTAssertNil([(FxGripCurveSetData *)self.lastWrite[@"value"] curveForKey:@"luma"]);
	XCTAssertEqual(self.apiManager.paramSetAPIv5.writes.count, (NSUInteger)1);
}

- (void)testACommitWithoutAnEffectWritesNothing
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	FxGripCurveData *curve = [self remapCurveWithMidY:0.8];

	@autoreleasepool {
		XCTAssertNoThrow([self.composite curveEditorView:luma didCommitCurve:curve]);
	}

	XCTAssertEqualObjects([self.composite.curveSet curveForKey:@"luma"], curve);
	XCTAssertEqualObjects(self.apiManager.paramSetAPIv5.writes, @[]);
	XCTAssertEqual(self.apiManager.customParameterActionAPIv4.startCount, (NSUInteger)0);
}

- (void)testAnEditFromAStripWithoutAMappingKeyChangesNothing
{
	FxGripCurveEditorView *luma = [self addLumaEditor];
	luma.mappingKey = nil;
	[self attachEffect];

	@autoreleasepool {
		[self.composite curveEditorView:luma didCommitCurve:[self remapCurveWithMidY:0.8]];
	}

	XCTAssertEqualObjects(self.composite.curveSet.curveKeys, @[]);
	XCTAssertEqual(self.apiManager.paramSetAPIv5.writes.count, (NSUInteger)1,
				   @"the set still writes; it simply carries no curve");
}

@end
