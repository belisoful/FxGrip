/*!
	@file       FxGripFCPXMLVersion.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLVersion
	@abstract   The FCPXML format version value and its string form.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLVersion.h.
*/

#import <FxGrip/FxGripFCPXMLVersion.h>
#import <FxGrip/FxGripFCPXMLSchema.h>

const FxGripFCPXMLVersion FxGripFCPXMLVersionInvalid = { -1, -1 };
const FxGripFCPXMLVersion FxGripFCPXMLVersionEarliest = { 1, 0 };

NSString *FxGripFCPXMLVersionString(FxGripFCPXMLVersion version)
{
	if (!FxGripFCPXMLVersionIsValid(version)) {
		return nil;
	}
	return [NSString stringWithFormat:@"%ld.%ld", (long)version.major, (long)version.minor];
}

FxGripFCPXMLVersion FxGripFCPXMLVersionFromString(NSString *string)
{
	if (![string isKindOfClass:NSString.class]) {
		return FxGripFCPXMLVersionInvalid;
	}
	NSArray<NSString *> *parts = [[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
								  componentsSeparatedByString:@"."];
	if (parts.count != 2) {
		return FxGripFCPXMLVersionInvalid;
	}
	NSScanner *majorScanner = [NSScanner scannerWithString:parts[0]];
	NSScanner *minorScanner = [NSScanner scannerWithString:parts[1]];
	NSInteger major = 0;
	NSInteger minor = 0;
	if (![majorScanner scanInteger:&major] || !majorScanner.isAtEnd
		|| ![minorScanner scanInteger:&minor] || !minorScanner.isAtEnd
		|| major < 0 || minor < 0) {
		return FxGripFCPXMLVersionInvalid;
	}
	return FxGripFCPXMLVersionMake(major, minor);
}

FxGripFCPXMLVersion FxGripFCPXMLVersionLatest(void)
{
	return FxGripFCPXMLVersionMake(1, FxGripFCPXMLSchemaLatestMinorVersion);
}
