/*!
	@file       FxGripFCPXMLVersion.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLVersion
	@abstract   The FCPXML format version value and its string form.
	@discussion Introduced in FxGrip 0.1.0. Final Cut Pro versions the interchange format as
	            `major.minor`, from 1.0 (Final Cut Pro 10.0) through 1.14. The `fcpxml` root
	            element carries the version attribute, and each version has its own DTD. The
	            functions here compare and convert versions; ``FxGripFCPXMLSchema`` answers which
	            elements and attributes a version supports.
*/

#ifndef FxGripFCPXMLVersion_h
#define FxGripFCPXMLVersion_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@struct     FxGripFCPXMLVersion
	@abstract   An FCPXML format version.
	@discussion Introduced in FxGrip 0.1.0. A negative component marks the invalid version.
*/
typedef struct FxGripFCPXMLVersion {
	NSInteger major;
	NSInteger minor;
} FxGripFCPXMLVersion;

/*! The invalid version, which no document carries. */
FOUNDATION_EXPORT const FxGripFCPXMLVersion FxGripFCPXMLVersionInvalid;

/*! The earliest version, 1.0. */
FOUNDATION_EXPORT const FxGripFCPXMLVersion FxGripFCPXMLVersionEarliest;

/*! Builds a version from its components. */
NS_INLINE FxGripFCPXMLVersion FxGripFCPXMLVersionMake(NSInteger major, NSInteger minor)
{
	FxGripFCPXMLVersion version = { major, minor };
	return version;
}

/*! YES when both components are zero or greater. */
NS_INLINE BOOL FxGripFCPXMLVersionIsValid(FxGripFCPXMLVersion version)
{
	return version.major >= 0 && version.minor >= 0;
}

/*! Compares two versions by major, then minor. */
NS_INLINE NSComparisonResult FxGripFCPXMLVersionCompare(FxGripFCPXMLVersion lhs, FxGripFCPXMLVersion rhs)
{
	if (lhs.major != rhs.major) {
		return lhs.major < rhs.major ? NSOrderedAscending : NSOrderedDescending;
	}
	if (lhs.minor != rhs.minor) {
		return lhs.minor < rhs.minor ? NSOrderedAscending : NSOrderedDescending;
	}
	return NSOrderedSame;
}

/*! YES when the components are equal. */
NS_INLINE BOOL FxGripFCPXMLVersionEqual(FxGripFCPXMLVersion lhs, FxGripFCPXMLVersion rhs)
{
	return lhs.major == rhs.major && lhs.minor == rhs.minor;
}

/*! The `major.minor` string, or nil for the invalid version. */
FOUNDATION_EXPORT NSString * _Nullable FxGripFCPXMLVersionString(FxGripFCPXMLVersion version);

/*! The version a `major.minor` string names, or the invalid version. */
FOUNDATION_EXPORT FxGripFCPXMLVersion FxGripFCPXMLVersionFromString(NSString * _Nullable string);

/*! The newest version the schema table knows. */
FOUNDATION_EXPORT FxGripFCPXMLVersion FxGripFCPXMLVersionLatest(void);

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLVersion_h */
