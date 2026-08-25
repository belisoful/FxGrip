//
//  FxGripURLWhitelistTests.m
//  FxGripTests
//

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripURLWhitelist.h>

@interface FxGripURLWhitelistTests : XCTestCase
@end

@implementation FxGripURLWhitelistTests

#pragma mark Glob → regex

- (void)testGlobTranslatesWildcardsAndEscapesLiterals
{
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@"*"], @"^.*$");
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@"a?c"], @"^a.c$");
	// The dot is a regex metacharacter, so a literal domain dot must be escaped.
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@"youtube.com"], @"^youtube\\.com$");
	XCTAssertEqualObjects([FxGripURLWhitelist regexPatternForGlob:@""], @"^$");
}

#pragma mark Allow-list policy

- (void)testAnEmptyWhitelistBlocksEveryURL
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc init];
	XCTAssertFalse([whitelist matchesURLString:@"https://youtube.com/watch?v=abc"]);
	XCTAssertFalse([whitelist allowsAllURLs]);
}

- (void)testTheStarPatternAllowsEveryURL
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist allowAllWhitelist];
	XCTAssertTrue([whitelist allowsAllURLs]);
	XCTAssertTrue([whitelist matchesURLString:@"https://anything.example/path"]);
	XCTAssertTrue([whitelist matchesURLString:@"http://10.0.0.1:8080/x"]);
}

- (void)testANilURLIsNeverAllowedEvenUnderStar
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist allowAllWhitelist];
	XCTAssertFalse([whitelist matchesURL:nil]);
	XCTAssertFalse([whitelist matchesURLString:nil]);
}

#pragma mark Host-suffix matching

- (void)testABareDomainCoversItsSubdomains
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"youtube.com"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://youtube.com/watch?v=abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://www.youtube.com/watch?v=abc"]);
	XCTAssertTrue([whitelist matchesURLString:@"https://music.youtube.com/"]);
}

- (void)testABareDomainDoesNotMatchALookAlikeHost
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"youtube.com"]];
	XCTAssertFalse([whitelist matchesURLString:@"https://eviltube.com/"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://notyoutube.com/"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://youtube.com.evil.example/"]);
}

- (void)testCaseInsensitiveHostMatching
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"youtube.com"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://WWW.YouTube.COM/watch"]);
}

#pragma mark Full-URL glob matching

- (void)testAFullURLGlobMatchesSchemeAndPath
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"https://*.vimeo.com/video/*"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://player.vimeo.com/video/12345"]);
	XCTAssertFalse([whitelist matchesURLString:@"http://player.vimeo.com/video/12345"], @"http is off the pattern");
	XCTAssertFalse([whitelist matchesURLString:@"https://player.vimeo.com/user/12345"], @"the path is off the pattern");
}

- (void)testTheSingleCharacterWildcardMatchesExactlyOneCharacter
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"site?.example"]];
	XCTAssertTrue([whitelist matchesURLString:@"https://site1.example/"]);
	XCTAssertFalse([whitelist matchesURLString:@"https://site10.example/"], @"? is one character, not two");
}

#pragma mark CRUD

- (void)testAddRejectsEmptyAndDuplicatePatterns
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc init];
	XCTAssertTrue([whitelist addPattern:@"youtube.com"]);
	XCTAssertFalse([whitelist addPattern:@"youtube.com"], @"a duplicate is rejected");
	XCTAssertFalse([whitelist addPattern:@"   "], @"an empty pattern is rejected");
	XCTAssertFalse([whitelist addPattern:nil]);
	XCTAssertEqualObjects(whitelist.patterns, (@[@"youtube.com"]));
}

- (void)testAddTrimsSurroundingWhitespace
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc init];
	XCTAssertTrue([whitelist addPattern:@"  rumble.com  "]);
	XCTAssertTrue([whitelist containsPattern:@"rumble.com"]);
	XCTAssertFalse([whitelist addPattern:@"rumble.com"], @"the trimmed form already exists");
}

- (void)testRemoveAndContains
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"a.com", @"b.com"]];
	XCTAssertTrue([whitelist containsPattern:@"a.com"]);
	XCTAssertTrue([whitelist removePattern:@"a.com"]);
	XCTAssertFalse([whitelist containsPattern:@"a.com"]);
	XCTAssertFalse([whitelist removePattern:@"a.com"], @"removing an absent pattern returns NO");
	XCTAssertEqualObjects(whitelist.patterns, (@[@"b.com"]));
}

- (void)testBulkSetReplacesInOrderDroppingEmptiesAndDuplicates
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"old.com"]];
	[whitelist setPatterns:@[@"x.com", @"  ", @"y.com", @"x.com"]];
	XCTAssertEqualObjects(whitelist.patterns, (@[@"x.com", @"y.com"]));
	XCTAssertFalse([whitelist containsPattern:@"old.com"]);
}

- (void)testRemoveAllEmptiesTheList
{
	FxGripURLWhitelist *whitelist = [FxGripURLWhitelist.alloc initWithPatterns:@[@"a.com", @"b.com"]];
	[whitelist removeAllPatterns];
	XCTAssertEqual(whitelist.patterns.count, 0u);
	XCTAssertFalse([whitelist matchesURLString:@"https://a.com/"]);
}

#pragma mark Default video whitelist

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
