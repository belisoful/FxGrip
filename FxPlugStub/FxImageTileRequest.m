/*!
	@file       FxImageTileRequest.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxImageTileRequest
	@abstract   Test-only implementation of FxPlug's FxImageTileRequest.
	@discussion Introduced in FxGrip 0.1.0. Implements the interface Apple declares in
	            FxImageTileRequest.h plus value equality and secure coding.
*/

#import "FxPlugStub.h"

@implementation FxImageTileRequest

- (instancetype)initWithSource:(FxImageTileRequestSource)requestSource
						  time:(CMTime)requestTime
				includeFilters:(BOOL)includeFilters
				   parameterID:(UInt32)parameterID
{
	self = [super init];
	if (self != nil) {
		_source = requestSource;
		_requestTime = requestTime;
		_includeLeadingFilters = includeFilters;
		_parameterID = parameterID;
	}
	return self;
}

- (instancetype)init
{
	return [self initWithSource:kFxImageTileRequestSourceNone time:kCMTimeZero includeFilters:NO parameterID:0];
}

#pragma mark - Equality

- (BOOL)isEqual:(id)object
{
	if (object == self) {
		return YES;
	}
	if (![object isKindOfClass:FxImageTileRequest.class]) {
		return NO;
	}
	FxImageTileRequest *other = object;
	return self.source == other.source
		&& CMTimeCompare(self.requestTime, other.requestTime) == 0
		&& self.includeLeadingFilters == other.includeLeadingFilters
		&& self.parameterID == other.parameterID;
}

- (NSUInteger)hash
{
	return (NSUInteger)self.source ^ ((NSUInteger)self.parameterID << 8) ^ (NSUInteger)CMTimeGetSeconds(self.requestTime);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p source=%lu time=%lld/%d filters=%d parameterID=%u>",
			self.className, self, (unsigned long)self.source,
			self.requestTime.value, self.requestTime.timescale,
			self.includeLeadingFilters, self.parameterID];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:(NSInteger)self.source forKey:@"source"];
	[coder encodeInt64:self.requestTime.value forKey:@"timeValue"];
	[coder encodeInt32:self.requestTime.timescale forKey:@"timeScale"];
	[coder encodeInt32:(int32_t)self.requestTime.flags forKey:@"timeFlags"];
	[coder encodeInt64:self.requestTime.epoch forKey:@"timeEpoch"];
	[coder encodeBool:self.includeLeadingFilters forKey:@"includeLeadingFilters"];
	[coder encodeInt32:(int32_t)self.parameterID forKey:@"parameterID"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	CMTime time;
	time.value = [coder decodeInt64ForKey:@"timeValue"];
	time.timescale = [coder decodeInt32ForKey:@"timeScale"];
	time.flags = (CMTimeFlags)[coder decodeInt32ForKey:@"timeFlags"];
	time.epoch = [coder decodeInt64ForKey:@"timeEpoch"];
	return [self initWithSource:(FxImageTileRequestSource)[coder decodeIntegerForKey:@"source"]
						   time:time
				 includeFilters:[coder decodeBoolForKey:@"includeLeadingFilters"]
					parameterID:(UInt32)[coder decodeInt32ForKey:@"parameterID"]];
}

@end
