/*!
 @header     NSData+URLDownload.h
 @copyright	 -© 2025 Delicense - @belisoful. All rights released.
 @date       2025-11-11
 @author     belisoful@icloud.com
 @abstract   NSData category for convenient asynchronous downloading from URLs.
 @discussion This category provides class methods for initiating asynchronous network data
			 and file downloads using `NSURLSession`. Instead of returning the downloaded data
			 (which is impossible for an async method), these methods return a public
			 `BEDataDownloadHandler` object, which manages the underlying session task
			 and can be used to cancel, pause, resume, or track the download status.
 */

#ifndef NSData_URLDownload_h
#define NSData_URLDownload_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @typedef    NSDataProgressBlock
 @abstract   Block type for progress updates during downloads.
 @param      totalBytesReceived The total number of bytes received so far.
 @param      totalBytesExpected The total number of bytes expected, or -1 if unknown.
 */
typedef void(^NSDataProgressBlock)(int64_t totalBytesReceived, int64_t totalBytesExpected);

/*!
 @typedef    NSDataCompletionBlock
 @abstract   Block type for data download completion.
 @param      data The downloaded data.
 @param      response The URL response object containing headers and status information.
 */
typedef void(^NSDataCompletionBlock)(NSData * _Nonnull data, NSURLResponse * _Nonnull response);

/*!
 @typedef    NSTempFileCompletionBlock
 @abstract   Block type for file download completion.
 @param      tempFileLocation The URL of the temporary file containing the downloaded content.
 @param      response The URL response object containing headers and status information.
 */
typedef void(^NSTempFileCompletionBlock)(NSURL * _Nonnull tempFileLocation, NSURLResponse * _Nonnull response);

/*!
 @typedef    NSDataErrorBlock
 @abstract   Block type for error handling during downloads.
 @param      error The error that occurred.
 @param      auxiliary YES if this is a secondary error (e.g., file write error), NO for primary download errors.
 */
typedef void(^NSDataErrorBlock)(NSError * _Nonnull error, BOOL auxiliary);


#pragma mark - BEDataDownloadDelegate

/*!
 @protocol   BEDataDownloadDelegate
 @abstract   Protocol for optional delegate-based handling of download events.
 @discussion Implement the methods of this protocol to receive callbacks for download progress,
			 completion, and errors. All methods are optional. Pass the adopting object to the
			 @c ...delegate: factory methods instead of supplying completion blocks.
 @code
	// The adopting object implements only the callbacks it cares about:
	- (void)downloadDataComplete:(NSData *)data urlResponse:(NSURLResponse *)response {
		NSLog(@"received %lu bytes", (unsigned long)data.length);
	}
	- (void)downloadError:(NSError *)error auxiliary:(BOOL)auxiliary {
		NSLog(@"download error (auxiliary=%d): %@", auxiliary, error);
	}

	// ...then route a download to that delegate:
	[NSData dataDownloadWithContentsOfURL:url delegate:self];
 @endcode
 */
@protocol BEDataDownloadDelegate <NSObject>
@optional

/*!
 @method     downloadReceived:totalBytes:
 @abstract   Called periodically to report download progress.
 @param      totalBytesReceived The total number of bytes received so far.
 @param      totalBytesExpected The total number of bytes expected, or -1 if unknown.
 */
- (void)downloadReceived:(int64_t)totalBytesReceived totalBytes:(int64_t)totalBytesExpected;

/*!
 @method     downloadDataComplete:urlResponse:
 @abstract   Called when a data download task completes successfully.
 @param      data The downloaded data.
 @param      response The URL response object.
 */
- (void)downloadDataComplete:(nonnull NSData *)data urlResponse:(nonnull NSURLResponse *)response;

/*!
 @method     downloadFileComplete:urlResponse:
 @abstract   Called when a file download task completes successfully.
 @param      tempFileLocation The URL of the temporary file containing the downloaded content.
 @param      response The URL response object.
 */
- (void)downloadFileComplete:(nonnull NSURL *)tempFileLocation urlResponse:(nonnull NSURLResponse *)response;

/*!
 @method     downloadError:auxiliary:
 @abstract   Called when a download error occurs.
 @param      error The error that occurred.
 @param      auxiliary YES if this is a secondary error (e.g., file write error), NO for primary download errors.
 */
- (void)downloadError:(nonnull NSError *)error auxiliary:(BOOL)auxiliary;
@end


#pragma mark - BEDataDownloadHandler

/*!
 @class      BEDataDownloadHandler
 @abstract   Manages an `NSURLSessionDataTask` or `NSURLSessionDownloadTask` and conforms
			 to their respective delegate protocols. This public class is returned by the
			 asynchronous download methods in the NSData category.
 @discussion This handler object provides control over the download process through pause, cancel,
			 and resume methods. It also accumulates downloaded data for data tasks and provides
			 access to the completion state.
 @code
	// Create the handler yourself to control exactly when the task starts and stops.
	// (delayResume only takes effect on a handler you configure before the ...handler: factory call.)
	BEDataDownloadHandler *handler = [[BEDataDownloadHandler alloc] init];
	handler.delayResume = YES;   // don't auto-start
	handler.dataCompletionBlock = ^(NSData *data, NSURLResponse *response) { ... };
	handler.progressBlock = ^(int64_t got, int64_t total) { ... };

	[NSData dataDownloadWithContentsOfURL:url handler:handler];
	[handler resume];   // start it
	[handler pause];    // suspend; call -resume again to continue
	[handler cancel];   // abort for good
 @endcode
 */
@interface BEDataDownloadHandler : NSObject <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>

/*! @property task The underlying NSURLSessionTask being managed. nil until a task is
	attached by one of the download methods. */
@property (nonatomic, readonly, nullable) NSURLSessionTask *task;

/*! @property isDataTask YES if the task is an NSURLSessionDataTask. */
@property (nonatomic, readonly) BOOL isDataTask;

/*! @property isDownloadTask YES if the task is an NSURLSessionDownloadTask. */
@property (nonatomic, readonly) BOOL isDownloadTask;

/*! @property isComplete YES if the download has completed (successfully or with error). */
@property (nonatomic, readonly) BOOL isComplete;

/*!
 @property   allowBothCompletions
 @abstract   When YES, both data and file completion handlers will be called.
 @discussion For data tasks, the data will be written to a temp file and the file completion handler called.
			 For download tasks, the file will be read into memory and the data completion handler called.
			 Default is NO.

			 The temp file synthesized for a data task follows the same lifetime contract as a
			 download task's location: the URL passed to the file completion handler is valid only
			 for the duration of that callback and is deleted once it returns. Copy or move the file
			 synchronously inside the handler if you need it to persist.
 */
@property (nonatomic, assign) BOOL allowBothCompletions;

/*!
 @property   suppressCompletionWarnings
 @abstract   When YES, warnings about mismatched completion handlers are suppressed.
 @discussion Warnings are logged when a data task has a file completion handler or vice versa,
			 unless allowBothCompletions is YES. Default is NO.
 */
@property (nonatomic, assign) BOOL suppressCompletionWarnings;

/*!
 @property   receivedData
 @abstract   The mutable data buffer accumulating downloaded data (for data tasks only).
 @discussion This is only populated for NSURLSessionDataTask operations. It is nil for download tasks.
 */
@property (nonatomic, readonly, nullable) NSMutableData *receivedData;

/*!
 @property   data
 @abstract   The final downloaded data (for data tasks only).
 @discussion This is populated after successful completion. For data tasks, it's a copy of receivedData.
			 For download tasks with allowBothCompletions enabled, it's loaded from the temp file.
 */
@property (nonatomic, readonly, nullable) NSData *data;

/*! @property delegate The delegate object that receives download events. Weakly referenced. */
@property (nonatomic, nullable, weak) id<BEDataDownloadDelegate> delegate;

/*! @property progressBlock Block called periodically with download progress updates. */
@property (nonatomic, nullable, copy) NSDataProgressBlock progressBlock;

/*! @property dataCompletionBlock Block called when data download completes successfully. */
@property (nonatomic, nullable, copy) NSDataCompletionBlock dataCompletionBlock;

/*! @property tempCompletionBlock Block called when a file download completes successfully, passed the
	on-disk location. The location is valid only for the duration of the callback; move or copy it
	synchronously if you need it afterward. See @c allowBothCompletions for data-task behavior. */
@property (nonatomic, nullable, copy) NSTempFileCompletionBlock tempCompletionBlock;

/*! @property errorBlock Block called when an error occurs during download. */
@property (nonatomic, nullable, copy) NSDataErrorBlock errorBlock;

/*!
 @property   delayResume
 @abstract   When YES, the task is not automatically resumed after creation.
 @discussion Set this to YES before calling a download method if you want to manually control
			 when the download starts. You must call resume to begin the download. Default is NO.
 */
@property (nonatomic, assign) BOOL delayResume;

/*!
 @property   sessionConfiguration
 @abstract   The configuration used to create the download's @c NSURLSession.
 @discussion Set this before initiating the download (e.g. on a handler passed to one of the
			 @c ...handler: methods) to control timeouts, headers, caching policy, or the
			 @c protocolClasses used for the request. When nil,
			 @c [NSURLSessionConfiguration defaultSessionConfiguration] is used.
 */
@property (nonatomic, nullable, copy) NSURLSessionConfiguration *sessionConfiguration;

/*!
 @method     pause
 @abstract   Suspends the associated session task. The download can be resumed later.
 @discussion Only effective if the task is currently running. Has no effect on completed or cancelled tasks.
 */
- (void)pause;

/*!
 @method     cancel
 @abstract   Cancels the associated session task.
 @discussion The task cannot be resumed after cancellation.
 */
- (void)cancel;

/*!
 @method     resume
 @abstract   Resumes the associated session task.
 @discussion Only needed if delayResume was YES at creation time, or if the task was previously paused.
 */
- (void)resume;

@end


#pragma mark - NSData (URLDownload)

/*!
 @category   NSData (URLDownload)
 @abstract   Extension methods for asynchronous URL downloading.
 @discussion This category adds class methods to NSData for initiating asynchronous downloads
			 of both in-memory data and files. All methods return a BEDataDownloadHandler for
			 controlling the download process.
 @code
	NSURL *url = [NSURL URLWithString:@"https://example.com/large.bin"];

	// In-memory data download:
	[NSData dataDownloadWithContentsOfURL:url
							   completion:^(NSData *data, NSURLResponse *response) {
		NSLog(@"got %lu bytes", (unsigned long)data.length);
	} error:^(NSError *error, BOOL auxiliary) {
		NSLog(@"download failed: %@", error);
	}];

	// File download to a temp location (valid only inside the callback — move it to keep it):
	[NSData downloadFileWithURL:url completion:^(NSURL *tempFileLocation, NSURLResponse *response) {
		[NSFileManager.defaultManager moveItemAtURL:tempFileLocation toURL:finalURL error:NULL];
	} error:nil];
 @endcode
 */
@interface NSData (URLDownload)

/*!
 @property   downloadHandler
 @abstract   A property to associate a download handler with a data object via associated objects.
 @discussion This property uses Objective-C associated objects to track the handler that created
			 or is managing this data. Primarily used internally but exposed for advanced use cases.
 */
@property (nullable, nonatomic) BEDataDownloadHandler *downloadHandler;

/*!
 @property   defaultSessionConfiguration
 @abstract   A process-wide default configuration applied to every download that doesn't supply its own.
 @discussion Set this once (e.g. at app launch) to apply app-wide timeouts, headers, caching policy,
			 or @c protocolClasses to all downloads created by these methods. The configuration used for
			 a given download resolves in order: the handler's @c sessionConfiguration, then this default,
			 then @c [NSURLSessionConfiguration defaultSessionConfiguration]. The value is copied on set.
 */
@property (class, nonatomic, nullable, copy) NSURLSessionConfiguration *defaultSessionConfiguration;

#pragma mark - Data Download (Data Task)

/*!
 @method     dataDownloadWithContentsOfURL:completion:error:
 @abstract   Asynchronously downloads content from a URL as NSData.
 @param      url The URL to download data from.
 @param      completionBlock The block to be executed on successful download of the data.
 @param      errorBlock The block to be executed on failure. May be nil.
 @return     A reference to the @c BEDataDownloadHandler managing the task,
			 or @c nil if the URL is invalid. The handler can be used to cancel, pause, or resume the task.
 @discussion The download begins immediately unless delayResume is set on the returned handler
			 before the method returns.
 */
+ (nullable BEDataDownloadHandler *)dataDownloadWithContentsOfURL:(nonnull NSURL *)url
													   completion:(nonnull NSDataCompletionBlock)completionBlock
															error:(nullable NSDataErrorBlock)errorBlock;

/*!
 @method     dataDownloadWithContentsOfURL:completion:error:progress:
 @abstract   Asynchronously downloads content from a URL as NSData, with progress tracking.
 @param      url The URL to download data from.
 @param      completionBlock The block to be executed on successful download of the data.
 @param      errorBlock The block to be executed on failure. May be nil.
 @param      progressBlock The block to be executed to update download progress. May be nil.
 @return     A reference to the @c BEDataDownloadHandler managing the task,
			 or @c nil if the URL is invalid.
 @discussion The progress block is called periodically as data is received. For unknown content lengths,
			 totalBytesExpected will be -1.
 */
+ (nullable BEDataDownloadHandler *)dataDownloadWithContentsOfURL:(nonnull NSURL *)url
													   completion:(nonnull NSDataCompletionBlock)completionBlock
															error:(nullable NSDataErrorBlock)errorBlock
														 progress:(nullable NSDataProgressBlock)progressBlock;

/*!
 @method     dataDownloadWithContentsOfURL:delegate:
 @abstract   Asynchronously downloads content from a URL as NSData, using a delegate.
 @param      url The URL to download data from.
 @param      delegate The object that will receive the download events. May be nil.
 @return     A reference to the @c BEDataDownloadHandler managing the task,
			 or @c nil if the URL is invalid.
 @discussion Use this method when you prefer delegate callbacks over blocks.
 */
+ (nullable BEDataDownloadHandler *)dataDownloadWithContentsOfURL:(nonnull NSURL *)url
														 delegate:(nullable id<BEDataDownloadDelegate>)delegate;

/*!
 @method     dataDownloadWithContentsOfURL:handler:
 @abstract   Starts an `NSURLSessionDataTask` using a pre-configured handler.
 @param      url The URL to download data from.
 @param      handler The pre-configured @c BEDataDownloadHandler instance. May be nil.
 @return     The created @c NSURLSessionDataTask, which is also set on the handler,
			 or @c nil if the URL or handler is invalid.
 @discussion This is a lower-level method for advanced use cases where you want to configure
			 the handler before starting the download.
 */
+ (nullable NSURLSessionDataTask *)dataDownloadWithContentsOfURL:(nonnull NSURL *)url
														 handler:(nullable BEDataDownloadHandler *)handler;


#pragma mark - File Download (Download Task)

/*!
 @method     downloadFileWithURL:completion:error:
 @abstract   Asynchronously downloads content from a URL to a temporary file.
 @param      url The URL to download the file from.
 @param      completionBlock The block to be executed on successful download of the file (provides temp file URL).
 @param      errorBlock The block to be executed on failure. May be nil.
 @return     A reference to the @c BEDataDownloadHandler managing the task,
			 or @c nil if the URL is invalid.
 @discussion The downloaded file is placed in a temporary location. You are responsible for
			 moving or copying it if you need to preserve it beyond the current session.
 */
+ (nullable BEDataDownloadHandler *)downloadFileWithURL:(nonnull NSURL *)url
											 completion:(nonnull NSTempFileCompletionBlock)completionBlock
												  error:(nullable NSDataErrorBlock)errorBlock;

/*!
 @method     downloadFileWithURL:completion:error:progress:
 @abstract   Asynchronously downloads content from a URL to a temporary file, with progress tracking.
 @param      url The URL to download the file from.
 @param      completionBlock The block to be executed on successful download of the file.
 @param      errorBlock The block to be executed on failure. May be nil.
 @param      progressBlock The block to be executed to update download progress. May be nil.
 @return     A reference to the @c BEDataDownloadHandler managing the task,
			 or @c nil if the URL is invalid.
 @discussion The progress block is called periodically as the file is downloaded.
 */
+ (nullable BEDataDownloadHandler *)downloadFileWithURL:(nonnull NSURL *)url
											 completion:(nonnull NSTempFileCompletionBlock)completionBlock
												  error:(nullable NSDataErrorBlock)errorBlock
											   progress:(nullable NSDataProgressBlock)progressBlock;

/*!
 @method     downloadFileWithURL:delegate:
 @abstract   Asynchronously downloads content from a URL to a temporary file, using a delegate.
 @param      url The URL to download the file from.
 @param      delegate The object that will receive the download events. May be nil.
 @return     A reference to the @c BEDataDownloadHandler managing the task,
			 or @c nil if the URL is invalid.
 @discussion Use this method when you prefer delegate callbacks over blocks.
 */
+ (nullable BEDataDownloadHandler *)downloadFileWithURL:(nonnull NSURL *)url
											   delegate:(nullable id<BEDataDownloadDelegate>)delegate;

/*!
 @method     downloadFileWithURL:handler:
 @abstract   Starts an `NSURLSessionDownloadTask` using a pre-configured handler.
 @param      url The URL to download data from.
 @param      handler The pre-configured @c BEDataDownloadHandler instance. May be nil.
 @return     The created @c NSURLSessionDownloadTask, which is also set on the handler,
			 or @c nil if the URL or handler is invalid.
 @discussion This is a lower-level method for advanced use cases where you want to configure
			 the handler before starting the download.
 */
+ (nullable NSURLSessionDownloadTask *)downloadFileWithURL:(nonnull NSURL *)url
												   handler:(nullable BEDataDownloadHandler *)handler;
@end


NS_ASSUME_NONNULL_END

#endif // !NSData_URLDownload_h
