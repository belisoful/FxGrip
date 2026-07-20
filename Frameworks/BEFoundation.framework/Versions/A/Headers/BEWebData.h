/*!
 @header     BEWebData.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-11-11
 @author     belisoful@icloud.com
 @abstract   Provides an NSData subclass that supports loading from data URLs.
 @discussion BEWebData extends NSData to handle RFC 2397 data URLs, automatically
			 decoding them and preserving metadata such as MIME type, charset, and
			 encoding method. Supports both class and instance creation methods,
			 NSCoding for archiving, and NSCopying for duplication.
 @see		 https://www.rfc-editor.org/rfc/rfc2397.html
 */

#ifndef BEWebData_h
#define BEWebData_h

#import <Foundation/Foundation.h>

/*!
 @var			BEDataReadingAsynchronous
 @abstract		Adds asynch url fetching of web based URLs.
 @discussion	This bit mask is possibly subject to change of bit fields in `NSDataReadingOptions`.
 				Use this variable and not any hard coded bits for reading data asynch.
 */
extern NSDataReadingOptions const BEDataReadingAsynchronous;
extern NSDataReadingOptions const BEDataReadingSynchronous;


typedef void(^BEWebDataCompletionBlock)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

/*!
 @class      BEWebData
 @abstract   NSData subclass that loads and decodes data URLs with metadata preservation.
 @discussion BEWebData supports data URLs (RFC 2397) while maintaining
			 compatibility with standard NSData loading methods. When initialized with a
			 data URL, it automatically parses and decodes the URL, storing metadata
			 properties that can be accessed later.
			 
			 The class provides the following behaviors:
			 - Automatic data URL detection and decoding
			 - Preserves MIME type, charset, and encoding information
			 - Supports both base64 and percent-encoded data URLs
			 - Falls back to standard NSData loading for regular URLs
			 - Implements NSCoding for archiving with metadata
			 - Implements NSCopying for proper duplication

			 For data URLs and file URLs the data and metadata are fully populated by the time the
			 initializer returns. For HTTP/HTTPS URLs they are filled in asynchronously by the data
			 task's completion handler — read them only after isComplete is YES (or from the
			 completion handler / a synchronous download).

			 Example usage:
			 @code
			 NSURL *dataURL = [NSURL URLWithString:@"data:text/plain;charset=utf-8;base64,SGVsbG8="];
			 BEWebData *webData = [BEWebData dataWithContentsOfURL:dataURL];
			 NSLog(@"MIME: %@, Data: %@", webData.MIMEType, webData);
			 @endcode
 */
@interface BEWebData : NSData <NSSecureCoding, NSCopying>

#pragma mark - Properties

/*!
 @property   MIMEType
 @abstract   The MIME type extracted from the data URL.
 @discussion Contains the MIME type if this instance was loaded from a data URL,
			 otherwise nil. Defaults to "text/plain" if not specified in the URL.
			 Common values include "text/html", "application/json", "image/png", etc.
 */
@property (nullable, readonly, copy) NSString *MIMEType;

/*!
 @property   charset
 @abstract   The character set extracted from the data URL.
 @discussion Contains the charset parameter if this instance was loaded from a data URL,
			 otherwise nil. Defaults to "US-ASCII" if not specified in the URL.
			 Common values include "utf-8", "iso-8859-1", "windows-1252", etc.
 */
@property (nullable, readonly, copy) NSString *charset;

/*!
 @property   stringEncoding
 @abstract   The NSStringEncoding corresponding to the charset.
 @discussion The encoding value derived from the charset parameter. Can be used
			 to convert the data to a string. Returns 0 if not loaded from a data URL.
			 Example: NSUTF8StringEncoding for "utf-8" charset.
 */
@property (readonly, assign, nonatomic) NSStringEncoding stringEncoding;

/*!
 @property   base64
 @abstract   Indicates whether the data URL used base64 encoding.
 @discussion Returns YES if the data was base64-encoded in the data URL,
			 NO if it was percent-encoded or if not loaded from a data URL.
 */
@property (readonly, getter=isBase64) BOOL base64;

/*!
 @property   complete
 @abstract   if the file data download is complete.
 @discussion tells us if and when the data is filled in or not.
 */
@property (readonly, getter=isComplete) BOOL complete;

/*!
 @property   dataTask
 @abstract   the task of the data download.
 @discussion contains the `NSURLSessionDataTask` of the task downloading the data when downloading.  nil when a fileURL or dataURL.
			Synchronous downloads are blocking, but still contain the dataTask until complete; after which its set to nil.
			For asynch download use the method with `options:error:` and add the bit `BEDataReadingAsynchronous`.
 */
@property (readonly, nullable) NSURLSessionDataTask *dataTask;

/*!
 @property   dataTaskSemaphore
 @abstract   The semaphore used to block the synchronous download path until completion.
 @discussion Created for HTTP/HTTPS downloads and signalled from the data task's completion
			handler. It is exposed for inspection only; callers should not wait on or signal it.
 */
@property (readonly, nullable) dispatch_semaphore_t dataTaskSemaphore;

/*!
 @property   dataTaskResponse
 @abstract   The NSURLResponse given by a dataTask download in the completionHandler.
 @discussion The NSURLResponse.
 */
@property (readonly, nullable) NSURLResponse *dataTaskResponse;

/*!
 @property   dataTaskError
 @abstract   Any errors in the data task download, when downloading the contents of a web URL.
 @discussion The error in the completion block of a dataTask.
 */
@property (readonly, nullable) NSError *dataTaskError;

@property (nullable, nonatomic, copy) BEWebDataCompletionBlock dataTaskCompletionHandler;

#pragma mark - Class Methods

/*!
 @property   defaultSessionConfiguration
 @abstract   The session configuration used for @c http / @c https loads.
 @discussion When @c nil (the default), loads use @c +[NSURLSession sharedSession]. Set a
			 configuration to route loads through a custom @c NSURLSession, for example to
			 inject a mock @c NSURLProtocol in tests.
 @note       Introduced in 1.1.
 */
@property (class, nullable, copy) NSURLSessionConfiguration *defaultSessionConfiguration;

/*!
 @method     isDataURL:
 @abstract   Checks if a URL uses the "data:" scheme.
 @param      url The URL to check.
 @discussion Convenience class method to test whether a URL is a data URL
			 without creating an instance. Case-insensitive comparison.
 @return     YES if the URL scheme is "data", NO otherwise or if url is nil.
 */
+ (BOOL)isDataURL:(nonnull NSURL*)url;

/*!
 @method     dataWithContentsOfURL:
 @abstract   Creates a new BEWebData instance from a URL.
 @param      url The URL to load data from (supports data URLs and regular URLs).
 @discussion If url is a data URL, parses and decodes it, storing metadata.
			 If url is a regular URL (http, file, etc.), loads data normally.
			 This is the recommended convenience constructor.
 @return     A new autoreleased BEWebData instance, or nil if loading fails.
 */
+ (nullable instancetype)dataWithContentsOfURL:(nonnull NSURL *)url;

/*!
 @method     dataWithContentsOfURL:options:error:
 @abstract   Creates a new BEWebData instance from a URL with options and error reporting.
 @param      url The URL to load data from.
 @param      options Reading options (NSDataReadingOptions). Only applies to regular URLs;
					 ignored for data URLs.
 @param      error Pointer to an NSError pointer to receive error information if loading fails.
 @discussion Provides full control over loading with error reporting. For data URLs,
			 the options parameter is ignored. For regular URLs, options are passed
			 to the standard NSData loading mechanism.
 @return     A new autoreleased BEWebData instance, or nil if loading fails (with error set).
 */
+ (nullable instancetype)dataWithContentsOfURL:(nonnull NSURL *)url
									   options:(NSDataReadingOptions)options
										 error:(NSError * _Nullable * _Nullable)error;

/*!
 @method     decodeDataURL:MIMEType:charset:encoding:base64:
 @abstract   Decodes a data URL and extracts its metadata and payload.
 @param      url The data URL to decode.
 @param      outMIMEType Pointer to receive the MIME type (may be NULL if not needed).
 @param      outCharset Pointer to receive the charset (may be NULL if not needed).
 @param      outEncoding Pointer to receive the NSStringEncoding (may be NULL if not needed).
 @param      outBase64 Pointer to receive the base64 flag (may be NULL if not needed).
 @discussion This class method provides low-level access to data URL decoding without
			 creating a BEWebData instance. Useful when you only need the decoded data
			 or specific metadata values.
			 
			 Parsing follows RFC 2397 format:
			 data:[<mediatype>][;charset=<charset>][;base64],<data>
			 
			 Default values when not specified:
			 - MIME type: "text/plain"
			 - Charset: "US-ASCII"
			 - Base64: NO (percent-encoding)
			 
			 All output parameters are optional (can be NULL).
 @return     The decoded NSData, or nil if the URL is not a data URL or parsing fails.
 */
+ (nullable NSData *)decodeDataURL:(nonnull NSURL *)url
						  MIMEType:(NSString * _Nullable __autoreleasing * _Nullable)outMIMEType
						   charset:(NSString * _Nullable __autoreleasing * _Nullable)outCharset
						  encoding:(NSStringEncoding * _Nullable)outEncoding
							base64:(BOOL * _Nullable)outBase64;

#pragma mark - Instance Methods

/*!
 @method     initWithContentsOfURL:
 @abstract   Initializes a BEWebData instance from a URL.
 @param      url The URL to load data from (supports data URLs and regular URLs).
 @discussion Designated initializer. If url is a data URL, parses and decodes it.
			 If url is a regular URL, loads data using standard NSData methods.
 @return     An initialized BEWebData instance, or nil if loading fails.
 */
- (nullable instancetype)initWithContentsOfURL:(nonnull NSURL *)url;

/*!
 @method     initWithContentsOfURL:options:error:
 @abstract   Initializes a BEWebData instance from a URL with options and error reporting.
 @param      url The URL to load data from.
 @param      options Reading options (only applies to regular URLs).
 @param      error Pointer to receive error information if loading fails.
 @discussion For data URLs, decodes the URL and populates metadata properties synchronously.
			 For file URLs, loads with the specified options synchronously.

			 For http/https URLs the load runs on an NSURLSession data task:
			 - By default (synchronous) this initializer BLOCKS the calling thread until the
			   network request completes. Do not call it on the main thread for remote URLs.
			   The wait is bounded only by the session's request timeout.
			 - Pass @c BEDataReadingAsynchronous in @c options to return immediately with the
			   task in flight. The instance is non-nil but empty until the download finishes;
			   read @c bytes / @c length / @c MIMEType / @c charset only after @c isComplete is
			   YES, or set @c dataTaskCompletionHandler to be notified on completion.
 @return     An initialized BEWebData instance, or nil if loading fails (with error set).
			 For an asynchronous http/https load the instance is returned before completion.
 */
- (nullable instancetype)initWithContentsOfURL:(nonnull NSURL *)url
									   options:(NSDataReadingOptions)options
										 error:(NSError * _Nullable * _Nullable)error;

@end

#endif // !BEWebData_h
