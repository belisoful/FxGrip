/*!
	@file       FxGripFCPXMLPasteboard.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLPasteboard
	@abstract   Reads and writes FCPXML documents on a pasteboard and in drag sessions.
	@discussion Introduced in FxGrip 0.1.0. A written document carries Final Cut Pro's FCPXML
	            type (`com.apple.finalcutpro.xml`) and plain text. A read accepts the FCPXML
	            type, a `.fcpxml` or `.fcpxmld` file URL, or a string that parses as FCPXML. A
	            workflow extension uses this to accept drops from, and start drags into, Final
	            Cut Pro.
*/

#ifndef FxGripFCPXMLPasteboard_h
#define FxGripFCPXMLPasteboard_h

#import <AppKit/AppKit.h>
#import <FxGrip/FxGripFCPXMLDocument.h>

NS_ASSUME_NONNULL_BEGIN

/*! The pasteboard type for FCPXML content: `com.apple.finalcutpro.xml`. */
FOUNDATION_EXPORT NSPasteboardType const FxGripFCPXMLPasteboardType;

/*!
	@class      FxGripFCPXMLPasteboard
	@abstract   The FCPXML pasteboard helpers.
	@discussion Introduced in FxGrip 0.1.0. Every method is a pure class method.
*/
@interface FxGripFCPXMLPasteboard : NSObject

/*! The types a document may be read from: the FCPXML type, file URLs, and strings. */
+ (NSArray<NSPasteboardType> *)readableTypes;

/*! A pasteboard item carrying a document as FCPXML and as plain text. */
+ (NSPasteboardItem *)pasteboardItemForDocument:(FxGripFCPXMLDocument *)document;

/*! Clears a pasteboard and writes a document to it. */
+ (BOOL)writeDocument:(nullable FxGripFCPXMLDocument *)document toPasteboard:(nullable NSPasteboard *)pasteboard;

/*! YES when a pasteboard holds a readable type. */
+ (BOOL)pasteboardHasDocument:(NSPasteboard *)pasteboard;

/*!
	@method     documentFromPasteboard:error:
	@abstract   The first document a pasteboard holds.
	@discussion Tries the FCPXML type, then `.fcpxml` and `.fcpxmld` file URLs, then a string.
*/
+ (nullable FxGripFCPXMLDocument *)documentFromPasteboard:(NSPasteboard *)pasteboard error:(NSError * _Nullable * _Nullable)error;

/*! The document a dragging session carries, through its pasteboard. */
+ (nullable FxGripFCPXMLDocument *)documentFromDraggingInfo:(id<NSDraggingInfo>)draggingInfo error:(NSError * _Nullable * _Nullable)error;

/*!
	@method     writeDocument:toTemporaryFileNamed:error:
	@abstract   Writes a document to a `.fcpxml` file in a temporary folder.
	@discussion The file URL is what a drag session or a Final Cut Pro import takes.
*/
+ (nullable NSURL *)writeDocument:(FxGripFCPXMLDocument *)document toTemporaryFileNamed:(nullable NSString *)name
							error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLPasteboard_h */
