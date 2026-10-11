/*!
	@file       FxGripFCPXMLPasteboard.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLPasteboard
	@abstract   Reads and writes FCPXML documents on a pasteboard and in drag sessions.
	@discussion Introduced in FxGrip 0.1.0. See FxGripFCPXMLPasteboard.h.
*/

#import <FxGrip/FxGripFCPXMLPasteboard.h>
#import <FxGrip/FxGripFinalCutPro.h>

NSPasteboardType const FxGripFCPXMLPasteboardType = @"com.apple.finalcutpro.xml";

@implementation FxGripFCPXMLPasteboard

+ (NSArray<NSPasteboardType> *)readableTypes
{
	return @[FxGripFCPXMLPasteboardType, NSPasteboardTypeFileURL, NSPasteboardTypeString];
}

+ (NSPasteboardItem *)pasteboardItemForDocument:(FxGripFCPXMLDocument *)document
{
	NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
	NSData *data = document.XMLData;
	[item setData:data forType:FxGripFCPXMLPasteboardType];
	[item setString:document.XMLString forType:NSPasteboardTypeString];
	return item;
}

+ (BOOL)writeDocument:(FxGripFCPXMLDocument *)document toPasteboard:(NSPasteboard *)pasteboard
{
	if (document == nil || pasteboard == nil) {
		return NO;
	}
	[pasteboard clearContents];
	return [pasteboard writeObjects:@[[self pasteboardItemForDocument:document]]];
}

+ (BOOL)pasteboardHasDocument:(NSPasteboard *)pasteboard
{
	return [pasteboard availableTypeFromArray:self.readableTypes] != nil;
}

+ (FxGripFCPXMLDocument *)documentFromPasteboard:(NSPasteboard *)pasteboard error:(NSError **)error
{
	NSError *lastError = nil;
	NSData *data = [pasteboard dataForType:FxGripFCPXMLPasteboardType];
	if (data != nil) {
		FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] initWithData:data error:&lastError];
		if (document != nil) {
			return document;
		}
	}
	NSArray<NSURL *> *urls = [pasteboard readObjectsForClasses:@[NSURL.class]
													   options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	for (NSURL *url in urls) {
		NSString *extension = url.pathExtension.lowercaseString;
		if ([extension isEqualToString:FxGripFCPXMLFileExtension] || [extension isEqualToString:FxGripFCPXMLBundleExtension]) {
			FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] initWithContentsOfURL:url error:&lastError];
			if (document != nil) {
				return document;
			}
		}
	}
	NSString *string = [pasteboard stringForType:NSPasteboardTypeString];
	if ([string containsString:@"<fcpxml"]) {
		FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] initWithXMLString:string error:&lastError];
		if (document != nil) {
			return document;
		}
	}
	if (error) {
		*error = lastError;
	}
	return nil;
}

+ (FxGripFCPXMLDocument *)documentFromDraggingInfo:(id<NSDraggingInfo>)draggingInfo error:(NSError **)error
{
	return [self documentFromPasteboard:draggingInfo.draggingPasteboard error:error];
}

+ (NSURL *)writeDocument:(FxGripFCPXMLDocument *)document toTemporaryFileNamed:(NSString *)name error:(NSError **)error
{
	NSString *fileName = name.length > 0 ? name : @"FxGrip";
	if (![fileName.pathExtension.lowercaseString isEqualToString:FxGripFCPXMLFileExtension]) {
		fileName = [fileName stringByAppendingPathExtension:FxGripFCPXMLFileExtension];
	}
	NSURL *folder = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
	folder = [folder URLByAppendingPathComponent:[NSString stringWithFormat:@"FxGripFCPXML-%@", NSUUID.UUID.UUIDString]
									 isDirectory:YES];
	if (![NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:error]) {
		return nil;
	}
	NSURL *fileURL = [folder URLByAppendingPathComponent:fileName];
	return [document writeToURL:fileURL error:error] ? fileURL : nil;
}

@end
