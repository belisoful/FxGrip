/*!
	@file       FxGripWorkflowViewControllerTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowViewControllerTests
	@abstract   Tests the workflow view controller base and the FCPXML drop view.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the configuration checks over Info.plist and
	            entitlement dictionaries, the drop view's pasteboard handling, the dragging item, the
	            client wiring, and the override points.
*/

#import <XCTest/XCTest.h>
#import <FxGripWorkflow/FxGripWorkflow.h>
#import <FxGrip/FxGripFCPXMLPasteboard.h>
#import <FxGrip/FxGripFCPXMLStoryElement.h>

@interface FxGripWorkflowTestController : FxGripWorkflowViewController
@property (nonatomic, strong) NSMutableArray<FxGripFCPXMLDocument *> *received;
@property (nonatomic, assign) NSUInteger changes;
@end

@implementation FxGripWorkflowTestController
- (void)loadView { self.view = [[FxGripWorkflowDropView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)]; }
- (void)workflowDidReceiveDocument:(FxGripFCPXMLDocument *)document
{
	if (self.received == nil) { self.received = NSMutableArray.new; }
	[self.received addObject:document];
}
- (void)workflowClientDidChange { self.changes += 1; }
@end

/*! A dragging info over a private pasteboard. */
@interface FxGripWorkflowTestDraggingInfo : NSObject <NSDraggingInfo>
@property (nonatomic, strong) NSPasteboard *pasteboard;
@end
@implementation FxGripWorkflowTestDraggingInfo
// NSDraggingInfo still requires the two deprecated image accessors.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (NSPoint)draggedImageLocation { return NSZeroPoint; }
- (NSImage *)draggedImage { return nil; }
- (NSArray<NSURL *> *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination { return @[]; }
#pragma clang diagnostic pop
- (NSPasteboard *)draggingPasteboard { return self.pasteboard; }
- (NSWindow *)draggingDestinationWindow { return nil; }
- (NSDragOperation)draggingSourceOperationMask { return NSDragOperationCopy; }
- (NSPoint)draggingLocation { return NSZeroPoint; }
- (id)draggingSource { return nil; }
- (NSInteger)draggingSequenceNumber { return 1; }
- (NSInteger)numberOfValidItemsForDrop { return 1; }
- (void)setNumberOfValidItemsForDrop:(NSInteger)number {}
- (NSDraggingFormation)draggingFormation { return NSDraggingFormationDefault; }
- (void)setDraggingFormation:(NSDraggingFormation)formation {}
- (BOOL)animatesToDestination { return NO; }
- (void)setAnimatesToDestination:(BOOL)flag {}
- (NSSpringLoadingHighlight)springLoadingHighlight { return NSSpringLoadingHighlightNone; }
- (void)resetSpringLoading {}
- (void)slideDraggedImageTo:(NSPoint)point {}
- (void)enumerateDraggingItemsWithOptions:(NSDraggingItemEnumerationOptions)options forView:(NSView *)view
								  classes:(NSArray<Class> *)classes searchOptions:(NSDictionary *)options2
							   usingBlock:(void (^)(NSDraggingItem *, NSInteger, BOOL *))block {}
@end

@interface FxGripWorkflowViewControllerTests : XCTestCase
@end

@implementation FxGripWorkflowViewControllerTests

- (NSDictionary *)validInfo
{
	return @{@"NSExtension": @{
		@"NSExtensionPointIdentifier": @"com.apple.FinalCut.WorkflowExtension",
		@"ProExtensionPrincipalViewControllerClass": @"FxGripWorkflowTestController",
		@"ProExtensionAttributes": @{@"ContentViewMinimumWidth": @370, @"ContentViewMinimumHeight": @400},
	}};
}

- (NSDictionary *)validEntitlements
{
	return @{
		@"com.apple.security.app-sandbox": @YES,
		@"com.apple.security.automation.apple-events": @YES,
		@"com.apple.security.scripting-targets": @{@"com.apple.FinalCut": @[@"com.apple.FinalCut.library.inspection"]},
		@"com.apple.security.application-groups": @[@"group.com.example.grip"],
	};
}

- (void)testConfigurationPassesForAValidBundle
{
	XCTAssertEqualObjects(FxGripWorkflowViewController.extensionPointIdentifier, @"com.apple.FinalCut.WorkflowExtension");
	XCTAssertEqualObjects([FxGripWorkflowViewController configurationProblemsForInfoDictionary:self.validInfo entitlements:self.validEntitlements], @[]);
	XCTAssertEqualObjects([FxGripWorkflowViewController configurationProblemsForInfoDictionary:self.validInfo entitlements:nil], @[],
						  @"nil entitlements skip the entitlement checks");
}

- (void)testConfigurationReportsEachProblem
{
	NSArray<NSString *> *problems = [FxGripWorkflowViewController configurationProblemsForInfoDictionary:@{} entitlements:@{}];
	XCTAssertEqual(problems.count, (NSUInteger)8, @"%@", problems);
	XCTAssertTrue([problems[0] containsString:@"no NSExtension"]);
	XCTAssertTrue([problems[1] containsString:@"NSExtensionPointIdentifier"]);
	XCTAssertTrue([problems[2] containsString:@"names no class"]);
	XCTAssertTrue([problems[3] containsString:@"ProExtensionAttributes is missing"]);
	XCTAssertTrue([problems[4] containsString:@"app-sandbox is off"]);
	XCTAssertTrue([problems[5] containsString:@"apple-events is off"]);
	XCTAssertTrue([problems[6] containsString:@"scripting-targets lacks"]);
	XCTAssertTrue([problems[7] containsString:@"application-groups is empty"]);

	NSDictionary *wrongClass = @{@"NSExtension": @{
		@"NSExtensionPointIdentifier": @"com.apple.FinalCut.WorkflowExtension",
		@"ProExtensionPrincipalViewControllerClass": @"NSObject",
		@"ProExtensionAttributes": @{@"ContentViewMinimumWidth": @0, @"ContentViewMinimumHeight": @"tall"},
	}};
	problems = [FxGripWorkflowViewController configurationProblemsForInfoDictionary:wrongClass entitlements:nil];
	XCTAssertEqual(problems.count, (NSUInteger)3, @"%@", problems);
	XCTAssertTrue([problems[0] containsString:@"not an NSViewController"]);
	XCTAssertTrue([problems[1] containsString:@"ContentViewMinimumWidth"]);
	XCTAssertTrue([problems[2] containsString:@"ContentViewMinimumHeight"]);

	NSDictionary *unknownClass = @{@"NSExtension": @{
		@"NSExtensionPointIdentifier": @"com.apple.FinalCut.WorkflowExtension",
		@"ProExtensionPrincipalViewControllerClass": @"NoSuchController",
		@"ProExtensionAttributes": @{@"ContentViewMinimumWidth": @1, @"ContentViewMinimumHeight": @1},
	}};
	XCTAssertTrue([[FxGripWorkflowViewController configurationProblemsForInfoDictionary:unknownClass entitlements:nil].firstObject
				   containsString:@"not a loaded class"]);
	XCTAssertTrue([FxGripWorkflowViewController configurationProblemsForBundle:NSBundle.mainBundle].count > 0,
				  @"the test host is not a workflow extension");
}

- (void)testDropViewAcceptsFCPXMLAndForwardsToTheController
{
	FxGripWorkflowTestController *controller = [[FxGripWorkflowTestController alloc] init];
	FxGripWorkflowDropView *view = (FxGripWorkflowDropView *)controller.view;
	XCTAssertTrue([view isKindOfClass:FxGripWorkflowDropView.class]);
	XCTAssertEqual(view.dropOperation, NSDragOperationCopy);
	XCTAssertTrue([view.registeredDraggedTypes containsObject:FxGripFCPXMLPasteboardType]);
	[controller registerForFCPXMLDropsOnView:view];

	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	[[document.libraryCreatingIfNeeded firstEventCreatingIfNeeded] addItem:[FxGripFCPXMLStoryElement clipWithName:@"C" duration:CMTimeMake(1, 1)]];
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
	[FxGripFCPXMLPasteboard writeDocument:document toPasteboard:pasteboard];
	FxGripWorkflowTestDraggingInfo *info = [[FxGripWorkflowTestDraggingInfo alloc] init];
	info.pasteboard = pasteboard;
	XCTAssertEqual([view draggingEntered:info], NSDragOperationCopy);
	XCTAssertEqual([view draggingUpdated:info], NSDragOperationCopy);
	XCTAssertTrue([view prepareForDragOperation:info]);
	XCTAssertTrue([view performDragOperation:info]);
	XCTAssertEqual(controller.received.count, (NSUInteger)1);
	XCTAssertEqualObjects(controller.received.firstObject.XMLString, document.XMLString);

	[pasteboard clearContents];
	[pasteboard setString:@"plain" forType:NSPasteboardTypeString];
	XCTAssertEqual([view draggingEntered:info], NSDragOperationCopy, @"a string may still parse");
	XCTAssertFalse([view performDragOperation:info]);
	[pasteboard clearContents];
	[pasteboard setData:[NSData data] forType:@"com.example.other"];
	XCTAssertEqual([view draggingEntered:info], NSDragOperationNone);
	XCTAssertFalse([view prepareForDragOperation:info]);
	[pasteboard releaseGlobally];
}

- (void)testDraggingItemAndClientWiring
{
	FxGripWorkflowTestController *controller = [[FxGripWorkflowTestController alloc] init];
	FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] init];
	NSDraggingItem *item = [controller draggingItemForDocument:document inView:controller.view image:nil];
	XCTAssertNotNil(item);
	XCTAssertTrue(item.draggingFrame.size.width > 0);
	XCTAssertNil(controller.client, @"the test process has no App Group");
	XCTAssertNotNil(controller.host);
	XCTAssertEqual(controller.host, FxGripFinalCutHost.sharedHost);
	[controller startWorkflowClient];
	[controller stopWorkflowClient];
	[controller workflowClientDidChange];
	XCTAssertEqual(controller.changes, (NSUInteger)1);
	FxGripWorkflowViewController *base = [[FxGripWorkflowViewController alloc] init];
	XCTAssertNoThrow([base workflowDidReceiveDocument:document]);
	XCTAssertNoThrow([base workflowClientDidChange]);
	XCTAssertEqualObjects(FxGripWorkflowPrincipalViewControllerClassKey, @"ProExtensionPrincipalViewControllerClass");
	XCTAssertEqualObjects(FxGripWorkflowExtensionAttributesKey, @"ProExtensionAttributes");
}

@end
