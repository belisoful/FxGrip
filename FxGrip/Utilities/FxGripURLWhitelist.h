/*!
	@file       FxGripURLWhitelist.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripURLWhitelist
	@abstract   An ordered allow-list of URL glob patterns.
	@discussion Introduced in FxGrip 0.1.0. Each pattern is a glob where ? matches one character
	            and * matches any run. A URL is allowed when a pattern matches its full absolute
	            string or a label-boundary suffix of its host, so a bare domain covers its
	            subdomains without opening a look-alike host. An empty list blocks every URL and
	            the single pattern * allows every URL. The class supports secure coding and
	            copying.
*/

#ifndef FxGripURLWhitelist_h
#define FxGripURLWhitelist_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@const      kFxGripURLWhitelistAnyCharacter
	@abstract   The glob character that matches exactly one character.
*/
extern const unichar kFxGripURLWhitelistAnyCharacter;	// '?'

/*!
	@const      kFxGripURLWhitelistAnyString
	@abstract   The glob character that matches any run of characters, including none.
*/
extern const unichar kFxGripURLWhitelistAnyString;		// '*'

/*!
	@class      FxGripURLWhitelist
	@abstract   An ordered allow-list of URL glob patterns.
	@discussion Introduced in FxGrip 0.1.0. Each pattern is a glob: `?` matches one character,
				`*` matches any run of characters, and every other character is literal. A
				pattern compiles to an anchored, case-insensitive regular expression through
				regexPatternForGlob:.

				A URL is allowed when any pattern matches its full absolute string or a
				label-boundary suffix of its host. Host-suffix matching means the pattern
				`youtube.com` allows the host `www.youtube.com` while rejecting
				`eviltube.com`, so a bare domain covers its subdomains without opening a
				look-alike host.

				The list is an allow-list: an empty list blocks every URL, and the single
				pattern `*` allows every URL. `*` is the permissive default; lock the list
				down to specific domains for security.
*/
@interface FxGripURLWhitelist : NSObject <NSSecureCoding, NSCopying>

/*! The patterns in order, unique. */
@property (nonatomic, readonly) NSArray<NSString *> *patterns;

/*! An empty whitelist. It blocks every URL until a pattern is added. */
- (instancetype)init;

/*! A whitelist seeded with the patterns, in order, dropping empties and duplicates. */
- (instancetype)initWithPatterns:(nullable NSArray<NSString *> *)patterns NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

/*! A whitelist containing only `*`, allowing every URL. */
+ (instancetype)allowAllWhitelist;

/*!
	@method     defaultVideoWhitelist
	@abstract   A whitelist seeded with common video-hosting domains.
	@discussion The domains are youtube.com, youtu.be, rumble.com, odysee.com,
				bitchute.com, brighteon.com, and gumroad.com. Each entry is a bare domain,
				so its subdomains are included.
*/
+ (instancetype)defaultVideoWhitelist;

#pragma mark CRUD

/*! Appends a pattern. Returns NO when the trimmed pattern is empty or already present. */
- (BOOL)addPattern:(nullable NSString *)pattern;

/*! Removes a pattern. Returns NO when the pattern is not present. */
- (BOOL)removePattern:(nullable NSString *)pattern;

/*! Answers whether the trimmed pattern is present. */
- (BOOL)containsPattern:(nullable NSString *)pattern;

/*! Replaces the whole list, in order, dropping empties and duplicates. */
- (void)setPatterns:(nullable NSArray<NSString *> *)patterns;

/*! Empties the list. The whitelist then blocks every URL. */
- (void)removeAllPatterns;

#pragma mark Matching

/*! Answers whether the URL is allowed by any pattern. A nil URL is not allowed. */
- (BOOL)matchesURL:(nullable NSURL *)url;

/*! Answers whether the URL string is allowed by any pattern. A nil or malformed string is not allowed. */
- (BOOL)matchesURLString:(nullable NSString *)urlString;

/*! YES when the list allows every URL, which happens only when it contains the pattern `*`. */
- (BOOL)allowsAllURLs;

#pragma mark Glob

/*!
	@method     regexPatternForGlob:
	@abstract   Translates a glob into an anchored regular-expression pattern.
	@discussion `?` becomes `.`, `*` becomes `.*`, and every other character is escaped as a
				literal. The result is anchored with `^` and `$`. Match it case-insensitively.
*/
+ (NSString *)regexPatternForGlob:(NSString *)glob;

@end

NS_ASSUME_NONNULL_END

#endif
