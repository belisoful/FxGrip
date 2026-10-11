/*!
	@file       FxGripWorkflowViewController.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripWorkflowViewController
	@abstract   The principal view controller base for a Final Cut Pro workflow extension.
	@discussion Introduced in FxGrip 0.1.0. See FxGripWorkflowViewController.h.
*/

#import <FxGripWorkflow/FxGripWorkflowViewController.h>
#import <FxGrip/FxGripFCPXMLPasteboard.h>
#import <FxGrip/FxGripFinalCutPro.h>
#import <Security/Security.h>

NSString *const FxGripWorkflowPrincipalViewControllerClassKey = @"ProExtensionPrincipalViewControllerClass";
NSString *const FxGripWorkflowExtensionAttributesKey = @"ProExtensionAttributes";
NSString *const FxGripWorkflowContentViewMinimumWidthKey = @"ContentViewMinimumWidth";
NSString *const FxGripWorkflowContentViewMinimumHeightKey = @"ContentViewMinimumHeight";

#pragma mark - Drop view

@implementation FxGripWorkflowDropView

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		[self commonSetup];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		[self commonSetup];
	}
	return self;
}

- (void)commonSetup
{
	_dropOperation = NSDragOperationCopy;
	[self registerForDraggedTypes:FxGripFCPXMLPasteboard.readableTypes];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	return [FxGripFCPXMLPasteboard pasteboardHasDocument:sender.draggingPasteboard] ? self.dropOperation : NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
	return [self draggingEntered:sender];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
	return [FxGripFCPXMLPasteboard pasteboardHasDocument:sender.draggingPasteboard];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	FxGripFCPXMLDocument *document = [FxGripFCPXMLPasteboard documentFromDraggingInfo:sender error:NULL];
	if (document == nil) {
		return NO;
	}
	if (self.documentHandler) {
		self.documentHandler(document);
	}
	return YES;
}

@end

#pragma mark - View controller

@interface FxGripWorkflowViewController ()
@property (readwrite, nullable, strong, nonatomic) FxGripWorkflowClient *client;
@property (readwrite, strong, nonatomic) FxGripFinalCutHost *host;
@property (assign) BOOL clientResolved;
@end

@implementation FxGripWorkflowViewController

+ (NSString *)extensionPointIdentifier
{
	return FxGripFinalCutProWorkflowExtensionPointIdentifier;
}

#pragma mark Configuration

+ (nullable NSDictionary *)entitlementsOfBundle:(NSBundle *)bundle
{
	if (bundle != NSBundle.mainBundle) {
		return nil;
	}
	SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
	if (task == NULL) {
		return nil;
	}
	NSMutableDictionary *entitlements = [NSMutableDictionary dictionary];
	for (NSString *name in @[@"com.apple.security.app-sandbox", @"com.apple.security.automation.apple-events",
							 @"com.apple.security.scripting-targets", @"com.apple.security.application-groups"]) {
		CFTypeRef value = SecTaskCopyValueForEntitlement(task, (__bridge CFStringRef)name, NULL);
		if (value != NULL) {
			entitlements[name] = (__bridge_transfer id)value;
		}
	}
	CFRelease(task);
	return entitlements;
}

+ (NSArray<NSString *> *)configurationProblemsForBundle:(NSBundle *)bundle
{
	return [self configurationProblemsForInfoDictionary:bundle.infoDictionary entitlements:[self entitlementsOfBundle:bundle]];
}

+ (NSArray<NSString *> *)configurationProblemsForInfoDictionary:(NSDictionary *)info entitlements:(NSDictionary *)entitlements
{
	NSMutableArray<NSString *> *problems = [NSMutableArray array];
	NSDictionary *extension = info[@"NSExtension"];
	if (![extension isKindOfClass:NSDictionary.class]) {
		[problems addObject:@"The Info.plist has no NSExtension dictionary."];
		extension = @{};
	}
	NSString *point = extension[@"NSExtensionPointIdentifier"];
	if (![point isEqualToString:self.extensionPointIdentifier]) {
		[problems addObject:[NSString stringWithFormat:@"NSExtensionPointIdentifier is '%@', not '%@'.",
							 [point isKindOfClass:NSString.class] ? point : @"", self.extensionPointIdentifier]];
	}
	NSString *principal = extension[FxGripWorkflowPrincipalViewControllerClassKey];
	if (![principal isKindOfClass:NSString.class] || principal.length == 0) {
		[problems addObject:[NSString stringWithFormat:@"%@ names no class.", FxGripWorkflowPrincipalViewControllerClassKey]];
	} else if (NSClassFromString(principal) == nil) {
		[problems addObject:[NSString stringWithFormat:@"%@ names '%@', which is not a loaded class.",
							 FxGripWorkflowPrincipalViewControllerClassKey, principal]];
	} else if (![NSClassFromString(principal) isSubclassOfClass:NSViewController.class]) {
		[problems addObject:[NSString stringWithFormat:@"%@ names '%@', which is not an NSViewController.",
							 FxGripWorkflowPrincipalViewControllerClassKey, principal]];
	}
	NSDictionary *attributes = extension[FxGripWorkflowExtensionAttributesKey];
	if (![attributes isKindOfClass:NSDictionary.class]) {
		[problems addObject:[NSString stringWithFormat:@"%@ is missing; Final Cut Pro needs the content view minimums.",
							 FxGripWorkflowExtensionAttributesKey]];
	} else {
		for (NSString *key in @[FxGripWorkflowContentViewMinimumWidthKey, FxGripWorkflowContentViewMinimumHeightKey]) {
			id value = attributes[key];
			if (![value isKindOfClass:NSNumber.class] || [value doubleValue] <= 0) {
				[problems addObject:[NSString stringWithFormat:@"%@.%@ is not a positive number.", FxGripWorkflowExtensionAttributesKey, key]];
			}
		}
	}
	if (entitlements == nil) {
		return problems;
	}
	id sandbox = entitlements[@"com.apple.security.app-sandbox"];
	if (![sandbox isKindOfClass:NSNumber.class] || ![sandbox boolValue]) {
		[problems addObject:@"com.apple.security.app-sandbox is off; an app extension must be sandboxed."];
	}
	id automation = entitlements[@"com.apple.security.automation.apple-events"];
	if (![automation isKindOfClass:NSNumber.class] || ![automation boolValue]) {
		[problems addObject:@"com.apple.security.automation.apple-events is off; library inspection needs it."];
	}
	id targets = entitlements[@"com.apple.security.scripting-targets"];
	BOOL covered = NO;
	if ([targets isKindOfClass:NSDictionary.class]) {
		for (NSString *bundleIdentifier in FxGripFinalCutPro.bundleIdentifiers) {
			id groups = targets[bundleIdentifier];
			covered |= [groups isKindOfClass:NSArray.class] && [groups containsObject:FxGripFinalCutProLibraryInspectionAccessGroup];
		}
	}
	if (!covered) {
		[problems addObject:[NSString stringWithFormat:@"com.apple.security.scripting-targets lacks %@ for Final Cut Pro; library inspection needs it.",
							 FxGripFinalCutProLibraryInspectionAccessGroup]];
	}
	id groups = entitlements[@"com.apple.security.application-groups"];
	if (![groups isKindOfClass:NSArray.class] || [groups count] == 0) {
		[problems addObject:@"com.apple.security.application-groups is empty; the plug-in mailbox needs a shared App Group."];
	}
	return problems;
}

#pragma mark Clients

- (FxGripWorkflowClient *)client
{
	if (!self.clientResolved) {
		self.clientResolved = YES;
		_client = FxGripWorkflowClient.sharedClient;
	}
	return _client;
}

- (FxGripFinalCutHost *)host
{
	if (_host == nil) {
		_host = FxGripFinalCutHost.sharedHost;
	}
	return _host;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	[self startWorkflowClient];
}

- (void)startWorkflowClient
{
	FxGripWorkflowClient *client = self.client;
	__weak FxGripWorkflowViewController *weakSelf = self;
	client.changeHandler = ^(FxGripWorkflowClient *changed) {
		[weakSelf workflowClientDidChange];
	};
	[client start];
}

- (void)stopWorkflowClient
{
	[self.client stop];
}

- (void)dealloc
{
	[_client stop];
}

#pragma mark Override points

- (void)workflowDidReceiveDocument:(FxGripFCPXMLDocument *)document
{
}

- (void)workflowClientDidChange
{
}

#pragma mark Drag and drop

- (void)registerForFCPXMLDropsOnView:(FxGripWorkflowDropView *)view
{
	__weak FxGripWorkflowViewController *weakSelf = self;
	view.documentHandler = ^(FxGripFCPXMLDocument *document) {
		[weakSelf workflowDidReceiveDocument:document];
	};
}

- (NSDraggingItem *)draggingItemForDocument:(FxGripFCPXMLDocument *)document inView:(NSView *)view image:(NSImage *)image
{
	NSPasteboardItem *item = [FxGripFCPXMLPasteboard pasteboardItemForDocument:document];
	NSDraggingItem *draggingItem = [[NSDraggingItem alloc] initWithPasteboardWriter:item];
	NSImage *dragImage = image ?: [NSImage imageNamed:NSImageNameMultipleDocuments];
	NSRect frame = NSMakeRect(0, 0, dragImage.size.width, dragImage.size.height);
	if (view != nil) {
		frame.origin = NSMakePoint(NSMidX(view.bounds) - frame.size.width / 2, NSMidY(view.bounds) - frame.size.height / 2);
	}
	[draggingItem setDraggingFrame:frame contents:dragImage];
	return draggingItem;
}

- (void)sendDocumentToFinalCutPro:(FxGripFCPXMLDocument *)document named:(NSString *)name completion:(void (^)(NSError *))completion
{
	[self.host importDocument:document named:name completion:completion];
}

@end
