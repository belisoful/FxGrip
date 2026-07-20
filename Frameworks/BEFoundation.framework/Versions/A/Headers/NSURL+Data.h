/*!
 @header     NSURL+Data.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-11-11
 @author     belisoful@icloud.com
 @abstract   Provides convenience methods for creating and parsing data URLs.
 @discussion This category on `NSURL` simplifies working with RFC 2397 data URLs,
			 providing methods to encode binary data or text into data URLs and
			 decode data URLs back into their original content. Supports MIME types,
			 character sets, and base64 encoding.
 @see		 https://www.rfc-editor.org/rfc/rfc2397.html
*/

#ifndef NSURL_Data_h
#define NSURL_Data_h

#import <Foundation/Foundation.h>

/*!
 @const      BEURLDataScheme
 @abstract   The "data" URL scheme (RFC 2397).
 @discussion Compare against a URL's scheme to identify data URLs, or use the `isDataURL` property.
*/
FOUNDATION_EXPORT NSString * _Nonnull const BEURLDataScheme;
/*!
 @enum       NSURLBase64Type
 @abstract   Specifies whether to use base64 encoding for data URLs.
 @constant   NSURLBase64Type_Auto Automatically determines encoding based on content type.
 @constant   NSURLBase64Type_No Forces percent-encoding (URL encoding).
 @constant   NSURLBase64Type_Yes Forces base64 encoding.
*/
typedef NS_ENUM(NSInteger, NSURLBase64Type) {
	NSURLBase64Type_Auto	= -1,
	NSURLBase64Type_No		=  0,
	NSURLBase64Type_Yes		=  1
};


FOUNDATION_EXPORT NSString * _Nonnull const BEURL_DefaultTextMimeType;
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_DefaultDataMimeType;


FOUNDATION_EXPORT NSString * _Nonnull const BEURL_DefaultCharset;// "US-ASCII"  Pure 7-bit ASCII
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_LatinCharSet_1;// "iso-8859-1"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_LatinCharSet_2;// "iso-8859-2"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_Windows1250;// "windows-1250"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_Windows1251;// "windows-1251"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_Windows1252;// "windows-1252"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_Windows1253;// "windows-1253"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_Windows1254;// "windows-1254"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_UTF8CharSet;// "utf-8"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_UTF16CharSet;// "utf-16"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_UTF32CharSet;// "utf-32"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_EUC_JP;// "EUC-JP"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_Shift_JIS;// "Shift_JIS"
FOUNDATION_EXPORT NSString * _Nonnull const BEURL_ISO_2022_JP;// "ISO-2022-JP"

/*!
 @category   NSURL (DataConstructors)
 @abstract   Provides class and instance methods for creating data URLs.
 @discussion This category offers multiple convenience methods for constructing data URLs
			 from NSData objects, with optional MIME type, charset, and encoding parameters.
			 Data URLs follow RFC 2397 format: data:[<mediatype>][;charset=<charset>][;base64],<data>
 @code
	// Base64 PNG data URL (auto-selects base64 for binary content):
	NSData *png = [NSData dataWithContentsOfFile:iconPath];
	NSURL *url = [NSURL dataURLWithData:png mimeType:@"image/png"];
	// -> data:image/png;base64,iVBORw0KGgo...

	// UTF-8 text, percent-encoded:
	NSData *text = [@"Hello, world" dataUsingEncoding:NSUTF8StringEncoding];
	NSURL *textURL = [NSURL dataURLWithData:text mimeType:@"text/plain" charset:BEURL_UTF8CharSet isBase64:NSURLBase64Type_No];
	// -> data:text/plain;charset=utf-8,Hello%2C%20world

	// Create a data URL, then read its decoded bytes back.
	NSURL *roundTrip = [NSURL dataURLWithData:png mimeType:@"image/png"];
	NSData *decoded = roundTrip.decodedData;       // equals png
 @endcode
*/
@interface NSURL (DataConstructors)

/*!
 @method     dataURLWithData:
 @abstract   Creates a data URL from the provided data using default parameters.
 @param      data The binary data to encode in the URL.
 @discussion Uses automatic encoding selection and defaults to "application/octet-stream" MIME type.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data;

/*!
 @method     dataURLWithData:isBase64:
 @abstract   Creates a data URL with explicit base64 encoding control.
 @param      data The binary data to encode in the URL.
 @param      base64Type Whether to use base64 encoding, percent-encoding, or auto-detect.
 @discussion When set to auto, the encoding is chosen based on the MIME type.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     dataURLWithData:charset:
 @abstract   Creates a data URL with a specified character set.
 @param      data The binary data to encode in the URL.
 @param      charset The character set name (e.g., "utf-8", "iso-8859-1").
 @discussion Implies text content and sets MIME type to "text/plain" if not specified.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data charset:(nullable NSString *)charset;

/*!
 @method     dataURLWithData:charset:isBase64:
 @abstract   Creates a data URL with charset and encoding control.
 @param      data The binary data to encode in the URL.
 @param      charset The character set name.
 @param      base64Type The encoding method to use.
 @discussion Combines charset specification with explicit encoding control.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data charset:(nullable NSString *)charset isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     dataURLWithData:mimeType:
 @abstract   Creates a data URL with a specified MIME type.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type (e.g., "image/png", "text/html").
 @discussion Automatically selects appropriate encoding and charset based on MIME type.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType;

/*!
 @method     dataURLWithData:mimeType:charset:
 @abstract   Creates a data URL with MIME type and charset.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type.
 @param      charset The character set name.
 @discussion Provides full control over content type specification.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType charset:(nullable NSString *)charset;

/*!
 @method     dataURLWithData:mimeType:isBase64:
 @abstract   Creates a data URL with MIME type and encoding control.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type.
 @param      base64Type The encoding method to use.
 @discussion Allows explicit encoding choice with MIME type specification.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil`.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     dataURLWithData:mimeType:charset:isBase64:
 @abstract   Creates a data URL with full control over all parameters.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type (defaults to "application/octet-stream" or "text/plain").
 @param      charset The character set name (e.g., "utf-8").
 @param      base64Type The encoding method (auto, base64, or percent-encoding).
 @discussion This is the master creation method that all other constructors call.
			 Provides complete control over data URL generation.
 @return     A new `NSURL` object containing the data URL, or `nil` if data is `nil` or encoding fails.
*/
+ (nullable NSURL *)dataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType charset:(nullable NSString *)charset isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     initDataURLWithData:
 @abstract   Initializes a data URL from the provided data using default parameters.
 @param      data The binary data to encode in the URL.
 @discussion Instance method equivalent of `dataURLWithData:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data;

/*!
 @method     initDataURLWithData:isBase64:
 @abstract   Initializes a data URL with explicit base64 encoding control.
 @param      data The binary data to encode in the URL.
 @param      base64Type Whether to use base64 encoding, percent-encoding, or auto-detect.
 @discussion Instance method equivalent of `dataURLWithData:isBase64:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     initDataURLWithData:charset:
 @abstract   Initializes a data URL with a specified character set.
 @param      data The binary data to encode in the URL.
 @param      charset The character set name.
 @discussion Instance method equivalent of `dataURLWithData:charset:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data charset:(nullable NSString *)charset;

/*!
 @method     initDataURLWithData:charset:isBase64:
 @abstract   Initializes a data URL with charset and encoding control.
 @param      data The binary data to encode in the URL.
 @param      charset The character set name.
 @param      base64Type The encoding method to use.
 @discussion Instance method equivalent of `dataURLWithData:charset:isBase64:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data charset:(nullable NSString *)charset isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     initDataURLWithData:mimeType:
 @abstract   Initializes a data URL with a specified MIME type.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type.
 @discussion Instance method equivalent of `dataURLWithData:mimeType:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType;

/*!
 @method     initDataURLWithData:mimeType:charset:
 @abstract   Initializes a data URL with MIME type and charset.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type.
 @param      charset The character set name.
 @discussion Instance method equivalent of `dataURLWithData:mimeType:charset:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType charset:(nullable NSString *)charset;

/*!
 @method     initDataURLWithData:mimeType:isBase64:
 @abstract   Initializes a data URL with MIME type and encoding control.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type.
 @param      base64Type The encoding method to use.
 @discussion Instance method equivalent of `dataURLWithData:mimeType:isBase64:`.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     initDataURLWithData:mimeType:charset:isBase64:
 @abstract   Initializes a data URL with full control over all parameters.
 @param      data The binary data to encode in the URL.
 @param      mimeType The MIME type.
 @param      charset The character set name.
 @param      base64Type The encoding method.
 @discussion Master initialization method for creating data URLs.
 @return     An initialized `NSURL` object, or `nil` if initialization fails.
*/
- (nullable NSURL *)initDataURLWithData:(nonnull NSData *)data mimeType:(nullable NSString *)mimeType charset:(nullable NSString *)charset isBase64:(NSURLBase64Type)base64Type;

/*!
 @method     charSetForDataMimeType:
 @abstract   Returns the default charset for a given MIME type.
 @param      mimeType The MIME type.
 @discussion Provides sensible defaults:
			 - Plain text types (text/plain, text/uri-list, text/enriched): US-ASCII
			 - Other text/- types: UTF-8
			 - JSON, XML, JavaScript: UTF-8
			 - Other types: nil (no charset)
 @return     The default charset name, or nil if not applicable.
*/
+ (nullable NSString *)charSetForDataMimeType:(nonnull NSString*)mimeType;

@end


/*!
 @category   NSURL (Data)
 @abstract   Provides methods for parsing and extracting data from data URLs.
 @discussion This category adds properties and methods to decode data URLs, extract
			 metadata (MIME type, charset, encoding), and retrieve the original data
			 or string content. All properties use lazy evaluation and caching.
 @code
	NSURL *url = [NSURL URLWithString:@"data:text/plain;charset=utf-8;base64,SGVsbG8="];
	if (url.isDataURL) {
		NSString *mime = url.dataMIMEType;     // @"text/plain"
		BOOL isB64    = url.isBase64;          // YES
		NSData *bytes = url.decodedData;        // <48656c6c 6f>
		NSString *str = url.decodedString;      // @"Hello" (decoded using stringEncoding)
	}
 @endcode
*/
@interface NSURL (Data)

/*!
 @property   dataURL
 @abstract   Indicates whether this URL uses the "data:" scheme.
 @discussion Returns `YES` if the URL scheme is "data", `NO` otherwise.
			 Result is cached using associated objects for performance.
*/
@property (readonly, getter=isDataURL) BOOL		dataURL;

/*!
 @property   dataMIMEType
 @abstract   The MIME type specified in the data URL.
 @discussion Extracts and returns the MIME type from the data URL metadata.
			 Defaults to "text/plain" if not specified. Returns `nil` for non-data URLs.
*/
@property (nullable, readonly, copy) NSString	*dataMIMEType;

/*!
 @property   dataCharset
 @abstract   The character set specified in the data URL.
 @discussion Extracts and returns the charset from the data URL metadata.
			 Defaults to "US-ASCII" if not specified. Returns `nil` for non-data URLs.
*/
@property (nullable, readonly, copy) NSString	*dataCharset;

/*!
 @property   stringEncoding
 @abstract   The `NSStringEncoding` corresponding to the data URL's charset.
 @discussion Converts the charset parameter to an appropriate NSStringEncoding value.
			 Returns 0 for non-data URLs or unrecognized charsets.
*/
@property (readonly) NSStringEncoding			stringEncoding;

/*!
 @property   base64
 @abstract   Indicates whether the data URL uses base64 encoding.
 @discussion Returns `YES` if the ";base64" parameter is present, `NO` otherwise.
			 For non-data URLs, always returns `NO`.
*/
@property (readonly, getter=isBase64) BOOL		base64;

/*!
 @property   dataString
 @abstract   The raw encoded data portion of the data URL.
 @discussion Returns the string after the comma separator, which contains either
			 base64-encoded or percent-encoded data. Returns `nil` for invalid or non-data URLs.
*/
@property (nullable, readonly) NSString			*dataString;

/*!
 @property   decodedData
 @abstract   The decoded binary data from the data URL.
 @discussion Base64 content is base64-decoded. Percent-encoded content is decoded byte-wise,
			 so the result carries the payload bytes in the URL's declared charset.
			 Returns `nil` if decoding fails or for non-data URLs.
*/
@property (nullable, readonly) NSData			*decodedData;

/*!
 @property   decodedString
 @abstract   The decoded string content from the data URL.
 @discussion Interprets `decodedData` using the URL's declared charset. When the charset is
			 absent or its interpretation fails, the bytes are interpreted as UTF-8.
			 Returns `nil` if decoding fails or for non-data URLs.
*/
@property (nullable, readonly) NSString			*decodedString;

/*!
 @method     isDataURL
 @abstract   Instance method to check if this URL uses the "data:" scheme.
 @discussion Checks whether the URL scheme matches "data" (case-insensitive).
			 Results are cached using associated objects.
 @return     `YES` if this is a data URL, `NO` otherwise.
*/
- (BOOL)isDataURL;

/*!
 @method     isDataURL:
 @abstract   Class method to check if a given URL uses the "data:" scheme.
 @param      url The URL to check.
 @discussion Convenience method to test any URL without requiring an instance.
 @return     `YES` if the URL is a data URL, `NO` otherwise or if url is `nil`.
*/
+ (BOOL)isDataURL:(nonnull NSURL*)url;

/*!
 @method     isBase64
 @abstract   Checks whether the data URL uses base64 encoding.
 @discussion Parses the data URL metadata to determine if ";base64" is present.
 @return     `YES` if base64-encoded, `NO` otherwise or for non-data URLs.
*/
- (BOOL)isBase64;

/*!
 @method     stringEncodingFromCharset:
 @abstract   Converts a charset name to an `NSStringEncoding`.
 @param      charset The charset name (e.g., "utf-8", "iso-8859-1", "windows-1252").
 @discussion Maps common charset names to their corresponding NSStringEncoding values.
			 Supports UTF-8, ASCII, Latin1/2, Windows code pages, Japanese encodings, etc.
 @return     The corresponding `NSStringEncoding`, or `NSASCIIStringEncoding` if unrecognized.
*/
+ (NSStringEncoding)stringEncodingFromCharset:(nullable NSString*)charset;


/*!
 @method     charsetFromStringEncoding:
 @abstract   Converts a `NSStringEncoding` to a charset
 @param      stringEncoding The `NSStringEncoding` string encoding
 @discussion Maps common `NSStringEncoding` values to their corresponding charset names.
			 Supports UTF-8, ASCII, Latin1/2, Windows code pages, Japanese encodings, etc.
 @return     The corresponding charset name, or `nil` if unrecognized.
*/
+ (nullable NSString*)charsetFromStringEncoding:(NSStringEncoding)stringEncoding;
@end

#endif // !NSURL_Data_h
