/*!
	@file       FxGripURLWhitelistTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripURLWhitelistTests
	@abstract   Unit tests for FxGripURLWhitelist glob translation, allow-list policy, host matching, CRUD, and coding.
	@discussion Introduced in FxGrip 0.1.0. The tests cover glob-to-regex translation, the empty and allow-all policies, bare-domain suffix matching, full-URL globbing, pattern add/remove/set operations, the default video whitelist, and the secure-coding and copy semantics.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripURLWhitelist.h>

@interface FxGripURLWhitelistTests : XCTestCase
@end

@implementation FxGripURLWhitelistTests

#pragma mark Glob → regex

/*! @abstract regexPatternForGlob: maps * to .*, ? to a single-character wildcard, escapes literal dots, and anchors the pattern. */
- (void)testGlobTranslatesWildcardsAndEscapesLiterals
{
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@"*"], @"^.*$");
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@"a?c"], @"^a.c$");
	// The dot is a regex metacharacter, so a literal domain dot must be escaped.
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@"youtube.com"], @"^youtube\\.com$");
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@""], @"^$");
}

#pragma mark Allow-list policy

/*! @abstract An empty whitelist matches no URL and does not report allowing all URLs. */
- (void)testAnEmptyWhitelistBlocksEveryURL
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc init];
	XCTAssertFalse([whitelist matchesURLString:@"https://youtube.com/watch?v=abc"]);
	XCTAssertFalse([whitelist allowsAllURLs]);
}

/*! @abstract The allow-all whitelist reports allowing all URLs and matches any URL. */
- (void)testTheStarPatternAllowsEveryURL
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist allowAllWhitelist];
	XCTAssertTrue([whitelist allowsAllURLs]);
	XCTAssertTrue([whitelist matchesURLString:@"https://anything.example/path"]);
	XCTAssertTrue([whitelist matchesURLString:@"http://10.0.0.1:8080/x"]);
}

/*! @abstract A nil URL or URL string is rejected even by the allow-all whitelist. */
- (void)testANilURLIsNeverAllowedEvenUnderStar
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist allowAllWhitelist];
	XCTAssertFalse([whitelist matchesURL:nil]);
	XCTAssertFalse([whitelist matchesURLString:nil]);
}

#pragma mark Host-suffix matching

/*! @abstract A bare domain pattern matches the domain and its subdomains. */
- (void)testABareDomainCoversItsSubdomains
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"youtube.com"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://youtube.com/watch?v=abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://www.youtube.com/watch?v=abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://music.youtube.com/"]);
}

/*! @abstract A bare domain pattern rejects hosts that only contain the domain as a substring or a label. */
- (void)testABareDomainDoesNotMatchALookAlikeHost
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"youtube.com"]];
	XCTAssertFalse([whitelist matchesURLString:@"https://eviltube.com/"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://notyoutube.com/"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://youtube.com.evil.example/"]);
}

/*! @abstract Host matching ignores case. */
- (void)testCaseInsensitiveHostMatching
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"youtube.com"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://WWW.YouTube.COM/watch"]);
}

#pragma mark Full-URL glob matching

/*! @abstract A full-URL glob constrains the scheme and path, rejecting a mismatched scheme or path. */
- (void)testAFullURLGlobMatchesSchemeAndPath
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"https://*.vimeo.com/video/*"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://player.vimeo.com/video/12345"]);
	XCTAssertFalse([whitelist matchesURLString:@"http://player.vimeo.com/video/12345"], @"http is off the pattern");
	XCTAssertFalse([whitelist matchesURLString:@"https://player.vimeo.com/user/12345"], @"the path is off the pattern");
}

/*! @abstract The ? wildcard matches exactly one character. */
- (void)testTheSingleCharacterWildcardMatchesExactlyOneCharacter
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"site?.example"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://site1.example/"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://site10.example/"], @"? is one character, not two");
}

#pragma mark CRUD

/*! @abstract addPattern: rejects duplicate, whitespace-only, and nil patterns. */
- (void)testAddRejectsEmptyAndDuplicatePatterns
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc init];
	XCTAssertTrue([whitelist addPattern:@"youtube.com"]);
	XCTAssertFalse([whitelist addPattern:@"youtube.com"], @"a duplicate is rejected");
	XCTAssertFalse([whitelist addPattern:@"   "], @"an empty pattern is rejected");
	XCTAssertFalse([whitelist addPattern:nil]);
	XCTAssertEqualObjects(whitelist.patterns, (@[@"youtube.com"]));
}

/*! @abstract addPattern: trims surrounding whitespace before storing and comparing. */
- (void)testAddTrimsSurroundingWhitespace
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc init];
	XCTAssertTrue([whitelist addPattern:@"  rumble.com  "]);
	XCTAssertTrue([whitelist containsPattern:@"rumble.com"]);
	XCTAssertFalse([whitelist addPattern:@"rumble.com"], @"the trimmed form already exists");
}

/*! @abstract removePattern: removes a present pattern and returns NO for an absent one, and containsPattern: reflects the change. */
- (void)testRemoveAndContains
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"a.com", @"b.com"]];
	XCTAssertTrue([whitelist containsPattern:@"a.com"]);
	XCTAssertTrue([whitelist removePattern:@"a.com"]);
	XCTAssertFalse([whitelist containsPattern:@"a.com"]);
	XCTAssertFalse([whitelist removePattern:@"a.com"], @"removing an absent pattern returns NO");
	XCTAssertEqualObjects(whitelist.patterns, (@[@"b.com"]));
}

/*! @abstract setPatterns: replaces the list in order, dropping empty and duplicate entries. */
- (void)testBulkSetReplacesInOrderDroppingEmptiesAndDuplicates
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"old.com"]];
	[whitelist setPatterns:@[@"x.com", @"  ", @"y.com", @"x.com"]];
	XCTAssertEqualObjects(whitelist.patterns, (@[@"x.com", @"y.com"]));
	XCTAssertFalse([whitelist containsPattern:@"old.com"]);
}

/*! @abstract removeAllPatterns empties the list, so no URL matches afterward. */
- (void)testRemoveAllEmptiesTheList
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"a.com", @"b.com"]];
	[whitelist removeAllPatterns];
	XCTAssertEqual(whitelist.patterns.count, 0u);
	XCTAssertFalse([whitelist matchesURLString:@"https://a.com/"]);
}

#pragma mark Default video whitelist

/*! @abstract The default video whitelist matches its seeded domains and their subdomains and rejects other hosts. */
- (void)testDefaultVideoWhitelistAllowsTheSeededDomainsAndSubdomains
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist defaultVideoWhitelist];
	XCTAssertTrue([whitelist matchesURLString:@"https://www.youtube.com/watch?v=abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://youtu.be/abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://rumble.com/v123.html"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://odysee.com/@x:1/y:2"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://www.bitchute.com/video/abc/"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://brighteon.com/abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://app.gumroad.com/l/abc"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://example.com/"]);
	XCTAssertFalse([whitelist allowsAllURLs]);
}

#pragma mark Coding & copying

/*! @abstract A secure-coding archive and unarchive preserves the patterns. */
- (void)testSecureCodingRoundTripsThePatterns
{
	FxGripURLWhitelist *original = [FxGripURLWhitelist defaultVideoWhitelist];
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:YES error:&error];
	XCTAssertNil(error);
	FxGripURLWhitelist *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:FxGripURLWhitelist.class fromData:data error:&error];
	XCTAssertNil(error);
	XCTAssertEqualObjects(original, decoded);
}

/*! @abstract A copy equals the original and holds its own patterns, so mutating the copy leaves the original unchanged. */
- (void)testCopyIsIndependent
{
	FxGripURLWhitelist *original = [FxGripURLWhitelist.alloc initWithPatterns:@[@"a.com"]];
	FxGripURLWhitelist *copy = [original copy];
	XCTAssertEqualObjects(original, copy);
	[copy addPattern:@"b.com"];
	XCTAssertNotEqualObjects(original, copy, @"mutating the copy does not affect the original");
	XCTAssertFalse([original containsPattern:@"b.com"]);
}

@end
