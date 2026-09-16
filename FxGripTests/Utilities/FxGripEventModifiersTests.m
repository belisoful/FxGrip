/*!
	@file       FxGripEventModifiersTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxGripEventModifiersTests
	@abstract   Unit tests for the FxModifierKeys mapping in FxGripEventModifiers.
	@discussion Introduced in FxGrip 0.1.0. The house standard maps Option to fine drag, Shift to
	            constrain, Command to delete-click, and Control to context menu. The tests cover the
	            FxPlug modifier-mask variants for every gesture, including combined masks.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripEventModifiers.h>

@interface FxGripEventModifiersTests : XCTestCase
@end

@implementation FxGripEventModifiersTests

/*! @abstract Option, and only Option, is the fine-drag modifier. */
- (void)testOptionIsTheFineDragModifier
{
	XCTAssertTrue([FxGripEventModifiers isFineDragForFxModifiers:kFxModifierKey_OPTION]);
	XCTAssertFalse([FxGripEventModifiers isFineDragForFxModifiers:kFxModifierKey_SHIFT]);
	XCTAssertFalse([FxGripEventModifiers isFineDragForFxModifiers:kFxModifierKey_COMMAND]);
	XCTAssertFalse([FxGripEventModifiers isFineDragForFxModifiers:kFxModifierKey_CONTROL]);
	XCTAssertFalse([FxGripEventModifiers isFineDragForFxModifiers:0]);
}

/*! @abstract Shift, and only Shift, is the constrain modifier. */
- (void)testShiftIsTheConstrainModifier
{
	XCTAssertTrue([FxGripEventModifiers isConstrainForFxModifiers:kFxModifierKey_SHIFT]);
	XCTAssertFalse([FxGripEventModifiers isConstrainForFxModifiers:kFxModifierKey_OPTION]);
	XCTAssertFalse([FxGripEventModifiers isConstrainForFxModifiers:kFxModifierKey_COMMAND]);
	XCTAssertFalse([FxGripEventModifiers isConstrainForFxModifiers:kFxModifierKey_CONTROL]);
	XCTAssertFalse([FxGripEventModifiers isConstrainForFxModifiers:0]);
}

/*! @abstract Command, and only Command, is the delete-click modifier. */
- (void)testCommandIsTheDeleteClickModifier
{
	XCTAssertTrue([FxGripEventModifiers isDeleteClickForFxModifiers:kFxModifierKey_COMMAND]);
	XCTAssertFalse([FxGripEventModifiers isDeleteClickForFxModifiers:kFxModifierKey_OPTION]);
	XCTAssertFalse([FxGripEventModifiers isDeleteClickForFxModifiers:kFxModifierKey_SHIFT]);
	XCTAssertFalse([FxGripEventModifiers isDeleteClickForFxModifiers:kFxModifierKey_CONTROL]);
	XCTAssertFalse([FxGripEventModifiers isDeleteClickForFxModifiers:0]);
}

/*! @abstract Control, and only Control, is the context-menu modifier. */
- (void)testControlIsTheContextMenuModifier
{
	XCTAssertTrue([FxGripEventModifiers isContextMenuForFxModifiers:kFxModifierKey_CONTROL]);
	XCTAssertFalse([FxGripEventModifiers isContextMenuForFxModifiers:kFxModifierKey_OPTION]);
	XCTAssertFalse([FxGripEventModifiers isContextMenuForFxModifiers:kFxModifierKey_SHIFT]);
	XCTAssertFalse([FxGripEventModifiers isContextMenuForFxModifiers:kFxModifierKey_COMMAND]);
	XCTAssertFalse([FxGripEventModifiers isContextMenuForFxModifiers:0]);
}

/*! @abstract A combined mask answers YES for every gesture whose modifier it carries. */
- (void)testACombinedMaskAnswersEachGestureItCarries
{
	FxModifierKeys mask = kFxModifierKey_CONTROL | kFxModifierKey_OPTION | kFxModifierKey_CAPS_LOCK;

	XCTAssertTrue([FxGripEventModifiers isContextMenuForFxModifiers:mask]);
	XCTAssertTrue([FxGripEventModifiers isFineDragForFxModifiers:mask]);
	XCTAssertFalse([FxGripEventModifiers isConstrainForFxModifiers:mask]);
	XCTAssertFalse([FxGripEventModifiers isDeleteClickForFxModifiers:mask]);
}

@end
