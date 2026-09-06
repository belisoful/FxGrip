/*!
	@file       FxGripWindow.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripWindow
	@abstract   Implements the single host-window management extension.
	@discussion Introduced in FxGrip 0.1.0. The extension requests the host window through the highest
	            FxRemoteWindowAPI version available, falling back to an earlier version's behavior
	            when a later one is not vended. The host reply arrives asynchronously; state changes
	            and the completion run on the reply's thread.
*/

#import "FxGripWindow.h"
#import "FxGripTileableEffect.h"
#import "FxGripTileableEffect+Extensions.h"
#import "FxGripAPIAccessing.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

NSString * const FxGripWindowExtensionKey = @"FxGripWindow";

/*!
	@abstract	The extension that manages the plug-in's one host window.
	@discussion	Introduced in FxGrip 0.1.0. The extension owns the parent view, the content view, and
				the presented state.
*/
@implementation FxGripWindow
{
	NSView *_windowParentView;
	NSView *_contentView;
	BOOL _windowPresented;
}

- (NSString *)extKey
{
	return FxGripWindowExtensionKey;
}

- (void)dealloc
{
	NARC_RELEASE(_windowParentView);
	NARC_RELEASE(_contentView);
	SUPER_DEALLOC();
}

#pragma mark State

- (NSView *)windowParentView
{
	return _windowParentView;
}

- (BOOL)isWindowPresented
{
	return _windowPresented;
}

- (NSView *)contentView
{
	return _contentView;
}

- (void)setContentView:(nullable NSView *)contentView
{
	if (_contentView == contentView) {
		return;
	}
	[_contentView removeFromSuperview];
	NARC_RELEASE(_contentView);
	_contentView = NARC_RETAIN(contentView);
	if (_windowPresented && _windowParentView != nil) {
		[self installContentView];
	}
}

/*! Fills the host's parent view with the content view. */
- (void)installContentView
{
	if (_contentView == nil || _windowParentView == nil) {
		return;
	}
	_contentView.frame = _windowParentView.bounds;
	_contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	if (_contentView.superview != _windowParentView) {
		[_windowParentView addSubview:_contentView];
	}
}

#pragma mark Presentation

/*! The host's window reply: records the parent, installs the content, and runs the completion. */
- (void)acceptParentView:(nullable NSView *)parentView
				   error:(nullable NSError *)error
			  completion:(void (^ _Nullable)(NSView * _Nullable, NSError * _Nullable))completion
{
	NSView *retained = NARC_RETAIN(parentView);
	NARC_RELEASE(_windowParentView);
	_windowParentView = retained;
	_windowPresented = (parentView != nil);
	if (_windowPresented) {
		[self installContentView];
	}
	if (completion != NULL) {
		completion(parentView, error);
	}
}

- (nullable NSError *)noWindowAPIError
{
	return [NSError errorWithDomain:FxGripPlugErrorDomain
							   code:kFxGripError_WindowAPIUnavailable
						   userInfo:@{ NSLocalizedDescriptionKey:
										   @"the host does not vend FxRemoteWindowAPI" }];
}

/*! @abstract Requests a fixed-size host window through FxRemoteWindowAPI and installs the content on arrival. */
- (void)presentWindowOfSize:(CGSize)contentSize
				 completion:(void (^ _Nullable)(NSView * _Nullable, NSError * _Nullable))completion
{
	id<FxRemoteWindowAPI> api = self.effect.apiManager.remoteWindowAPIv1;
	if (api == nil) {
		[self acceptParentView:nil error:[self noWindowAPIError] completion:completion];
		return;
	}
	[api remoteWindowOfSize:contentSize
					  reply:^(NSView *parentView, NSError *error) {
		[self acceptParentView:parentView error:error completion:completion];
	}];
}

/*! @abstract Requests a resizable host window through FxRemoteWindowAPI_v2, or falls back to a fixed size. */
- (void)presentWindowWithMinimumSize:(CGSize)minContentSize
						 maximumSize:(CGSize)maxContentSize
						  completion:(void (^ _Nullable)(NSView * _Nullable, NSError * _Nullable))completion
{
	id<FxRemoteWindowAPI_v2> api = self.effect.apiManager.remoteWindowAPIv2;
	if (api == nil) {
		[self presentWindowOfSize:minContentSize completion:completion];
		return;
	}
	[api remoteWindowWithMinimumSize:minContentSize
						 maximumSize:maxContentSize
							   reply:^(NSView *parentView, NSError *error) {
		[self acceptParentView:parentView error:error completion:completion];
	}];
}

/*! @abstract Clears state and asks the host to close the window through FxRemoteWindowAPI_v3; returns whether the request was made. */
- (BOOL)closeWindow
{
	id<FxRemoteWindowAPI_v3> api = self.effect.apiManager.remoteWindowAPIv3;
	[self noteWindowClosed];
	if (api == nil) {
		return NO;
	}
	[api closeRemoteWindow];
	return YES;
}

/*! @abstract Removes the content view and clears the presented state after the user closes the window. */
- (void)noteWindowClosed
{
	[_contentView removeFromSuperview];
	NARC_RELEASE(_windowParentView);
	_windowParentView = nil;
	_windowPresented = NO;
}

@end


/*!
	@abstract	The effect-side accessors for the window extension.
	@discussion	Introduced in FxGrip 0.1.0. windowExtension resolves the loaded extension.
*/
@implementation FxGripTileableEffect (Window)

- (nullable FxGripWindow *)windowExtension
{
	return (FxGripWindow *)[self extensionForClass:FxGripWindow.class];
}

- (BOOL)hasWindowExtension
{
	return [self extensionForClass:FxGripWindow.class] != nil;
}

- (nonnull FxGripWindow *)newWindowExtension
{
	return [FxGripWindow.alloc init];
}

@end
