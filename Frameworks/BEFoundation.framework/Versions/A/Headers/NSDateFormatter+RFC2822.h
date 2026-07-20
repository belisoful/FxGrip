/*!
 @header		NSDateFormatter+RFC2822.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Category extension for NSDateFormatter providing RFC 2822 date formatting support.
 @discussion	This header provides a category extension for NSDateFormatter that adds convenience
				methods for working with RFC 2822 formatted dates. RFC 2822 (Internet Message Format)
				defines the date format used in email headers, derived from RFC 822. HTTP and RSS
				use a near-identical format. It is unrelated to ISO 8601; for ISO 8601 / Internet
				timestamps use the RFC 3339 category instead.

				The RFC 2822 format (EEE, dd MMM yyyy HH:mm:ss Z) is commonly used in email, HTTP
				date headers, and RSS feeds. This extension simplifies the creation and configuration
				of NSDateFormatter instances for RFC 2822 compliance.

				RFC 2822 formatting in this extension:
				- Uses UTC timezone (GMT+0) for consistency
				- Employs en_US_POSIX locale so the English weekday/month names RFC 2822 requires are used
				- Follows the standard EEE, dd MMM yyyy HH:mm:ss Z format
				- Parses and formats consistently across locales and timezones
 */

#ifndef NSDateFormatterRFC2822_h
#define NSDateFormatterRFC2822_h

#import <Foundation/Foundation.h>

#define kBEDateFormatRFC2822		(@"EEE, dd MMM yyyy HH:mm:ss Z")

NS_ASSUME_NONNULL_BEGIN

/*!
 @category		NSDateFormatter (RFC2822)
 @abstract		Category extension for NSDateFormatter providing RFC 2822 date formatting capabilities.
 @discussion	This category adds methods to NSDateFormatter for easy creation and configuration
				of formatters that comply with RFC 2822 date format specifications. RFC 2822 is
				a standardized date and time format commonly used in web services and APIs.
				
				The category provides both a class method for creating a pre-configured formatter
				and an instance method for configuring an existing formatter to use RFC 2822
				format settings. All methods ensure proper locale, timezone, and format string
				configuration for RFC 2822 compliance.
				
				RFC 2822 format characteristics:
				- Date format: EEE, dd MMM yyyy HH:mm:ss Z  (e.g. "Mon, 23 Jun 2025 14:45:30 +0000")
				- Timezone: UTC (GMT+0)
				- Locale: en_US_POSIX (prevents localization issues)

				Parsing note: this fixed format requires the leading weekday and a numeric zone offset.
				A string without the weekday ("23 Jun 2025 …") or with an obsolete alphabetic zone
				("… GMT"/"… EST") will not parse and dateFromString: returns nil. The weekday must be
				present but is NOT validated against the date — an inconsistent weekday (e.g. "Tue" for
				a Monday) is silently accepted, with the day/month/year fields determining the instant.
				Comments / folding whitespace (CFWS) are not supported either: a real email header such
				as "… +0000 (UTC)" will not parse, so strip any trailing comment before parsing.
 @code
	NSDateFormatter *fmt = [NSDateFormatter rfc2822DateFormatter];
	NSString *s = [fmt stringFromDate:NSDate.date];   // "Mon, 23 Jun 2025 14:45:30 +0000"
	NSDate *d = [fmt dateFromString:@"Mon, 23 Jun 2025 14:45:30 -0800"]; // offset honored -> 22:45:30 UTC
 @endcode

 @since 1.1
 */
@interface NSDateFormatter (RFC2822)

/*!
 @method		+rfc2822DateFormatter
 @abstract		Creates and returns a new NSDateFormatter configured for RFC 2822 date formatting.
 @discussion	This class method creates a new NSDateFormatter instance and configures it with
				the proper settings for RFC 2822 date format compliance. The returned formatter
				is ready to use for parsing and formatting dates in RFC 2822 format.
				
				The formatter is configured with:
				- Date format: "EEE, dd MMM yyyy HH:mm:ss Z"
				- Locale: en_US_POSIX (prevents localization issues)
				- Timezone: UTC (GMT+0)

				Performance: each call allocates and configures a fresh NSDateFormatter, which is
				relatively expensive. If you format or parse many dates, keep one formatter and reuse
				it. A configured NSDateFormatter is safe to use (format/parse) concurrently from
				multiple threads as long as its properties are not mutated.
 @result		A new NSDateFormatter instance configured for RFC 2822 date formatting.
				The formatter is autoreleased and ready for immediate use.
 @see			rfc2822Format
 */
+ (NSDateFormatter *)rfc2822DateFormatter;

/*!
 @method		-rfc2822Format
 @abstract		Configures the receiver to use RFC 2822 date formatting settings.
 @discussion	This instance method configures an existing NSDateFormatter to use RFC 2822
				date format settings. This is useful when you have an existing formatter that
				you want to reconfigure for RFC 2822 compliance, or when you want to modify
				a formatter's settings without creating a new instance.
				
				The method sets the following properties on the receiver:
				- dateFormat: "EEE, dd MMM yyyy HH:mm:ss Z"
				- locale: en_US_POSIX locale identifier
				- timeZone: UTC timezone (GMT+0)
				
				After calling this method, the formatter will be properly configured for
				parsing and formatting RFC 2822 compliant date strings. Any previous format
				settings will be overridden.
 @see			rfc2822DateFormatter
 */
- (void)rfc2822Format;

@end

NS_ASSUME_NONNULL_END

#endif // NSDateFormatterRFC2822_h
