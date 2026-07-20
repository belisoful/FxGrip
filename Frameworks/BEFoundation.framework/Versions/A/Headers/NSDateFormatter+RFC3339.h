/*!
 @header		NSDateFormatter+RFC3339.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Category extension for NSDateFormatter providing RFC 3339 date formatting support.
 @discussion	This header provides a category extension for NSDateFormatter that adds convenience
				methods for working with RFC 3339 formatted dates. RFC 3339 is a profile of the
				ISO 8601 standard that defines a date and time format for use in Internet protocols.
				
				The RFC 3339 format (yyyy-MM-dd'T'HH:mm:ssZZZZZ) is commonly used in web APIs,
				JSON data interchange, and other Internet-based applications where standardized
				date representation is required. This extension simplifies the creation and
				configuration of NSDateFormatter instances for RFC 3339 compliance.
				
				RFC 3339 formatting behaves as follows:
				- Uses UTC timezone (GMT+0) for consistency
				- Employs en_US_POSIX locale to avoid localization issues
				- Follows the standard yyyy-MM-dd'T'HH:mm:ssZZZZZ format
				- Parses and formats reliably across different locales and timezones
 */

#ifndef NSDateFormatterRFC3339_h
#define NSDateFormatterRFC3339_h

#import <Foundation/Foundation.h>

/*
 
 from PHP: https://www.php.net/manual/en/class.datetime.php
 public const string DateTimeInterface::ATOM = "Y-m-d\\TH:i:sP";
 public const string DateTimeInterface::COOKIE = "l, d-M-Y H:i:s T";
 public const string DateTimeInterface::ISO8601 = "Y-m-d\\TH:i:sO";
 public const string DateTimeInterface::ISO8601_EXPANDED = "X-m-d\\TH:i:sP";
 public const string DateTimeInterface::RFC822 = "D, d M y H:i:s O";
 public const string DateTimeInterface::RFC850 = "l, d-M-y H:i:s T";
 public const string DateTimeInterface::RFC1036 = "D, d M y H:i:s O";
 public const string DateTimeInterface::RFC1123 = "D, d M Y H:i:s O";
 public const string DateTimeInterface::RFC7231 = "D, d M Y H:i:s \\G\\M\\T";
 public const string DateTimeInterface::RFC2822 = "D, d M Y H:i:s O";
 public const string DateTimeInterface::RFC3339 = "Y-m-d\\TH:i:sP";
 public const string DateTimeInterface::RFC3339_EXTENDED = "Y-m-d\\TH:i:s.vP";
 public const string DateTimeInterface::RSS = "D, d M Y H:i:s O";
 public const string DateTimeInterface::W3C = "Y-m-d\\TH:i:sP";
 
 
 */

#define kBEDateFormatRFC3339		(@"yyyy-MM-dd'T'HH:mm:ssZZZZZ")

NS_ASSUME_NONNULL_BEGIN

/*!
 @category		NSDateFormatter (RFC3339)
 @abstract		Category extension for NSDateFormatter providing RFC 3339 date formatting capabilities.
 @discussion	This category adds methods to NSDateFormatter for easy creation and configuration
				of formatters that comply with RFC 3339 date format specifications. RFC 3339 is
				a standardized date and time format commonly used in web services and APIs.
				
				The category provides both a class method for creating a pre-configured formatter
				and an instance method for configuring an existing formatter to use RFC 3339
				format settings. All methods ensure proper locale, timezone, and format string
				configuration for RFC 3339 compliance.
				
				RFC 3339 format characteristics:
				- Date format: yyyy-MM-dd'T'HH:mm:ssZZZZZ  (e.g. "2025-06-23T14:45:30Z")
				- Timezone: UTC (GMT+0)
				- Locale: en_US_POSIX (prevents localization issues)
				- Compatible with ISO 8601 standard

				Conformance / parsing note: this fixed format parses a full-string, whole-second
				timestamp with an uppercase 'T' separator and a "Z"/"z" or numeric offset (e.g.
				"+00:00", "-08:00"). The zone designator is case-insensitive ('z' works), but the
				separator is a format literal and stays case-sensitive. These optional RFC 3339
				productions are NOT accepted and return nil from dateFromString::
				- fractional seconds ("2025-06-23T14:45:30.5Z") — add ".SSS" to the format if needed;
				- the §5.6 separator alternatives — a space or a lowercase 't' for the 'T'
				  ("2025-06-23 10:30:00Z", "2025-06-23t10:30:00Z");
				- a leap second (":60", e.g. "2025-06-30T23:59:60Z").
				Hours are restricted to 00-23 (no ISO 8601 "24:00") and any trailing content is rejected.
 @code
	NSDateFormatter *fmt = [NSDateFormatter rfc3339DateFormatter];
	NSString *s = [fmt stringFromDate:NSDate.date];   // "2025-06-23T14:45:30Z"
	NSDate *d = [fmt dateFromString:@"2025-06-23T14:45:30-08:00"]; // offset honored -> 22:45:30 UTC
 @endcode
 */
@interface NSDateFormatter (RFC3339)

/*!
 @method		+rfc3339DateFormatter
 @abstract		Creates and returns a new NSDateFormatter configured for RFC 3339 date formatting.
 @discussion	This class method creates a new NSDateFormatter instance and configures it with
				the proper settings for RFC 3339 date format compliance. The returned formatter
				is ready to use for parsing and formatting dates in RFC 3339 format.
				
				The formatter is configured with:
				- Date format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
				- Locale: en_US_POSIX (prevents localization issues)
				- Timezone: UTC (GMT+0)
				
				This method creates a fresh, fully configured formatter for RFC 3339 dates.
				The returned formatter can be used immediately for date parsing and formatting
				operations with no further setup.

				Performance: each call allocates and configures a fresh NSDateFormatter, which is
				relatively expensive. If you format or parse many dates, keep one formatter and reuse
				it. A configured NSDateFormatter is safe to use (format/parse) concurrently from
				multiple threads as long as its properties are not mutated.
 @result		A new NSDateFormatter instance configured for RFC 3339 date formatting.
				The formatter is autoreleased and ready for immediate use.
 @see			rfc3339Format
 */
+ (NSDateFormatter *)rfc3339DateFormatter;

/*!
 @method		-rfc3339Format
 @abstract		Configures the receiver to use RFC 3339 date formatting settings.
 @discussion	This instance method configures an existing NSDateFormatter to use RFC 3339
				date format settings. This is useful when you have an existing formatter that
				you want to reconfigure for RFC 3339 compliance, or when you want to modify
				a formatter's settings without creating a new instance.
				
				The method sets the following properties on the receiver:
				- dateFormat: "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
				- locale: en_US_POSIX locale identifier
				- timeZone: UTC timezone (GMT+0)
				
				After calling this method, the formatter will be properly configured for
				parsing and formatting RFC 3339 compliant date strings. Any previous format
				settings will be overridden.
 @see			rfc3339DateFormatter
 */
- (void)rfc3339Format;

@end

NS_ASSUME_NONNULL_END

#endif // NSDateFormatterRFC3339_h
