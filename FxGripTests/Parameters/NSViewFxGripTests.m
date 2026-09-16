/*!
	@file       NSViewFxGripTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     NSViewFxGripTests
	@abstract   Tests the category that tags an NSView with the parameter it presents.
	@discussion Introduced in FxGrip 0.1.0. The tests cover the unset default, the round trip through
	            the associated object, the independence of two views, and the reassignment of a tag.
*/

#import <XCTest/XCTest.h>
#import <AppKit/AppKit.h>
#import <FxGrip/FxGripTypes.h>
#import <FxGrip/NSView+FxGrip.h>

@interface NSViewFxGripTests : XCTestCase
@end

@implementation NSViewFxGripTests

/*! @abstract A view with no assigned parameter reads the none identifier. */
- (void)testAnUntaggedViewReadsTheNoneIdentifier
{
	NSView *view = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 10, 10)];

	XCTAssertEqual(view.parameterID, (FxParameterId)kFxParameterId_None);
}

/*! @abstract An assigned parameter identifier round-trips through the view. */
- (void)testAnAssignedIdentifierRoundTrips
{
	NSView *view = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 10, 10)];

	view.parameterID = 37;

	XCTAssertEqual(view.parameterID, (FxParameterId)37);
}

/*! @abstract Reassigning replaces the identifier the view carries. */
- (void)testReassigningReplacesTheIdentifier
{
	NSView *view = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 10, 10)];
	view.parameterID = 37;

	view.parameterID = 41;

	XCTAssertEqual(view.parameterID, (FxParameterId)41);
}

/*! @abstract Each view carries its own identifier, so tagging one leaves another untagged. */
- (void)testEachViewCarriesItsOwnIdentifier
{
	NSView *tagged = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 10, 10)];
	NSView *untagged = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 10, 10)];

	tagged.parameterID = 55;

	XCTAssertEqual(tagged.parameterID, (FxParameterId)55);
	XCTAssertEqual(untagged.parameterID, (FxParameterId)kFxParameterId_None);
}

@end
