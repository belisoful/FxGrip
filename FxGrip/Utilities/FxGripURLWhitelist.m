//
//  FxGripURLWhitelist.m
//  FxGrip
//

#import "FxGripURLWhitelist.h"
#import "FxGrip_ARC.h"

const unichar kFxGripURLWhitelistAnyCharacter = '?';
const unichar kFxGripURLWhitelistAnyString = '*';

@implementation FxGripURLWhitelist
{
	NSMutableArray<NSString *> *_patterns;
	// Compiled regex per pattern, built on demand and dropped when the list changes.
	NSMutableDictionary<NSString *, NSRegularExpression *> *_compiled;
}

- (instancetype)init
{
	return [self initWithPatterns:nil];
}

- (instancetype)initWithPatterns:(nullable NSArray<NSString *> *)patterns
{
	self = [super init];
	if (self != nil) {
		_patterns = [NSMutableArray array];
		_compiled = [NSMutableDictionary dictionary];
		[self setPatterns:patterns];
	}
	return self;
}

+ (instancetype)allowAllWhitelist
{
	return [[self alloc] initWithPatterns:@[@"*"]];
}

+ (instancetype)defaultVideoWhitelist
{
	// @todo: add other common host websites
	return [[self alloc] initWithPatterns:@[
		@"youtube.com", @"youtu.be", @"rumble.com", @"odysee.com",
		@"bitchute.com", @"brighteon.com", @"gumroad.com",
	]];
}

#pragma mark - Normalization

/*! Trims surrounding whitespace; returns nil for an empty result. */
+ (nullable NSString *)normalizedPattern:(nullable NSString *)pattern
{
	if (![pattern isKindOfClass:NSString.class]) {
		return nil;
	}
	NSString *trimmed = [pattern stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	return trimmed.length ? trimmed : nil;
}

#pragma mark - Accessors

- (NSArray<NSString *> *)patterns
{
	return [_patterns copy];
}

- (void)setPatterns:(nullable NSArray<NSString *> *)patterns
{
	[_patterns removeAllObjects];
	[_compiled removeAllObjects];
	for (NSString *pattern in patterns) {
		NSString *normalized = [self.class normalizedPattern:pattern];
		if (normalized && ![_patterns containsObject:normalized]) {
			[_patterns addObject:normalized];
		}
	}
}

- (BOOL)addPattern:(nullable NSString *)pattern
{
	NSString *normalized = [self.class normalizedPattern:pattern];
	if (!normalized || [_patterns containsObject:normalized]) {
		return NO;
	}
	[_patterns addObject:normalized];
	return YES;
}

- (BOOL)removePattern:(nullable NSString *)pattern
{
	NSString *normalized = [self.class normalizedPattern:pattern];
	if (!normalized || ![_patterns containsObject:normalized]) {
		return NO;
	}
	[_patterns removeObject:normalized];
	[_compiled removeObjectForKey:normalized];
	return YES;
}

- (BOOL)containsPattern:(nullable NSString *)pattern
{
	NSString *normalized = [self.class normalizedPattern:pattern];
	return normalized != nil && [_patterns containsObject:normalized];
}

- (void)removeAllPatterns
{
	[_patterns removeAllObjects];
	[_compiled removeAllObjects];
}

- (BOOL)allowsAllURLs
{
	return [_patterns containsObject:@"*"];
}

#pragma mark - Glob

+ (NSString *)regexPatternForGlob:(NSString *)glob
{
	NSMutableString *regex = [NSMutableString stringWithString:@"^"];
	NSUInteger length = glob.length;
	for (NSUInteger i = 0; i < length; i++) {
		unichar c = [glob characterAtIndex:i];
		if (c == kFxGripURLWhitelistAnyString) {
			[regex appendString:@".*"];
		} else if (c == kFxGripURLWhitelistAnyCharacter) {
			[regex appendString:@"."];
		} else {
			[regex appendString:[NSRegularExpression escapedPatternForString:
				[NSString stringWithCharacters:&c length:1]]];
		}
	}
	[regex appendString:@"$"];
	return regex;
}

- (nullable NSRegularExpression *)regexForPattern:(NSString *)pattern
{
	NSRegularExpression *regex = _compiled[pattern];
	if (regex == nil) {
		NSString *source = [self.class regexPatternForGlob:pattern];
		regex = [NSRegularExpression regularExpressionWithPattern:source
														 options:NSRegularExpressionCaseInsensitive
														   error:NULL];
		if (regex != nil) {
			_compiled[pattern] = regex;
		}
	}
	return regex;
}

static BOOL FxGripRegexMatchesWholeString(NSRegularExpression *regex, NSString *string)
{
	if (string.length == 0) {
		// An empty candidate matches only a pattern that allows an empty run.
		return [regex firstMatchInString:string options:0 range:NSMakeRange(0, 0)] != nil;
	}
	NSRange whole = NSMakeRange(0, string.length);
	NSTextCheckingResult *match = [regex firstMatchInString:string options:0 range:whole];
	return match != nil && NSEqualRanges(match.range, whole);
}

#pragma mark - Matching

- (BOOL)matchesURL:(nullable NSURL *)url
{
	if (url == nil) {
		return NO;
	}
	NSString *absolute = url.absoluteString ?: @"";
	NSString *host = url.host ?: @"";

	// The label-boundary suffixes of the host let a bare domain cover its subdomains
	// without matching a look-alike host: www.youtube.com yields www.youtube.com,
	// youtube.com, com.
	NSMutableArray<NSString *> *hostSuffixes = [NSMutableArray array];
	if (host.length) {
		NSArray<NSString *> *labels = [host componentsSeparatedByString:@"."];
		for (NSUInteger i = 0; i < labels.count; i++) {
			NSRange range = NSMakeRange(i, labels.count - i);
			[hostSuffixes addObject:[[labels subarrayWithRange:range] componentsJoinedByString:@"."]];
		}
	}

	for (NSString *pattern in _patterns) {
		NSRegularExpression *regex = [self regexForPattern:pattern];
		if (regex == nil) {
			continue;
		}
		if (FxGripRegexMatchesWholeString(regex, absolute)) {
			return YES;
		}
		for (NSString *suffix in hostSuffixes) {
			if (FxGripRegexMatchesWholeString(regex, suffix)) {
				return YES;
			}
		}
	}
	return NO;
}

- (BOOL)matchesURLString:(nullable NSString *)urlString
{
	if (![urlString isKindOfClass:NSString.class] || urlString.length == 0) {
		return NO;
	}
	return [self matchesURL:[NSURL URLWithString:urlString]];
}

#pragma mark - NSSecureCoding & NSCopying

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	NSArray<NSString *> *decoded = [coder decodeObjectOfClasses:
		[NSSet setWithObjects:NSArray.class, NSString.class, nil] forKey:@"patterns"];
	return [self initWithPatterns:decoded];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_patterns forKey:@"patterns"];
}

- (instancetype)copyWithZone:(nullable NSZone *)zone
{
	return [[self.class alloc] initWithPatterns:_patterns];
}

- (BOOL)isEqual:(id)object
{
	if (self == object) {
		return YES;
	}
	if (![object isKindOfClass:FxGripURLWhitelist.class]) {
		return NO;
	}
	return [_patterns isEqualToArray:((FxGripURLWhitelist *)object)->_patterns];
}

- (NSUInteger)hash
{
	return _patterns.hash;
}

@end
