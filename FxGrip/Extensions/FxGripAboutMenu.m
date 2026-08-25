//
//  FxGripAboutMenu.m
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#import "FxGripAboutMenu.h"

NSString*	const _Nonnull FxGripAboutMenuExtensionKey = @"FxGripAboutMenu";

@implementation FxGripAboutMenu

- (NSString*)extKey
{
	return FxGripAboutMenuExtensionKey;
}

- (void)extProcessParameters:(NSMutableArray*_Nonnull)parameters
{ /*
	return @{[NSString stringWithFormat:@"%d", SS_AboutMenu]: @{@"items": [self computeAboutMenuFrom:nil atTime:kCMTimeZero]}};
   */
}

- (NSArray*)computeAboutMenuFrom:(id<FxParameterRetrievalAPI_v6> _Nullable)paramGetAPIv6 atTime:(CMTime)time
{/*
	NSMutableArray *items = [NSMutableArray array];
	
	int agreementIndex = 0;
	if (paramGetAPIv6 != nil)
		[paramGetAPIv6 getIntValue:&agreementIndex fromParameter:SS_AboutAgreement atTime:time];
	if (agreementIndex < kAboutAgreementYesValue) {
		[items addObject:NSLocalizedString(kAboutLine1, @"About Alert Text Line 1")];
		[items addObject:NSLocalizedString(kAboutLine2, @"About Alert Text Line2")];
		[items addObject:NSLocalizedString(kAboutLine3, @"About Alert Text Line3")];
		[items addObject:@"-"];
	}
	
	BOOL toggle, topSeparator = true, bottomSeparator = false, hasTemplateItem = false, showHelpItem = true;
	NSString *string = nil;
	
	if (paramGetAPIv6 != nil) {
		[paramGetAPIv6 getStringParameterValue:&string fromParameter:SS_AboutText];
	} else {
		string = NSLocalizedString(@"ML_Upscale::Params::AboutMenu::MainItemTextValue", @"Initial main About Menu Item Text");
	}
	[items addObject:string];
	
	if (paramGetAPIv6 != nil) {
		[paramGetAPIv6 getBoolValue:&topSeparator fromParameter:SS_AboutSeparator atTime:time];
	}
	if (topSeparator) {
		[items addObject:@"-"];
	}
	
#define kAboutMenuDisplayParamKey @"displayId"
#define kAboutMenuTextParamKey @"text"
#define kAboutMenuURLParamKey @"urlId"
#define kAboutMenuFailURLParamKey @"failUrlId"
	NSArray *menuData = @[@{kAboutMenuDisplayParamKey : @(SS_Help_TemplateDisplay),
						 kAboutMenuTextParamKey : @(SS_Help_TemplateText)},
					   @{kAboutMenuDisplayParamKey : @(SS_About_TemplateDisplay),
						 kAboutMenuTextParamKey : @(SS_About_TemplateText)},
					   @{kAboutMenuDisplayParamKey : @(SS_About_EditorDisplay),
						 kAboutMenuTextParamKey : @(SS_About_EditorText)},
					   @{kAboutMenuDisplayParamKey : @(SS_Follow_AuthorDisplay),
						 kAboutMenuTextParamKey : @(SS_Follow_AuthorText)},
					   @{kAboutMenuDisplayParamKey : @(SS_Support_AuthorDisplay),
						 kAboutMenuTextParamKey : @(SS_Support_AuthorText)},
					   @{kAboutMenuDisplayParamKey : @(SS_Support2_AuthorDisplay),
						 kAboutMenuTextParamKey : @(SS_Support2_AuthorText)},
					   @{kAboutMenuDisplayParamKey : @(SS_Support3_AuthorDisplay),
						 kAboutMenuTextParamKey : @(SS_Support3_AuthorText)}];
	
	if (paramGetAPIv6 != nil) {
		for(NSDictionary *data in menuData) {
			[paramGetAPIv6 getBoolValue:&toggle fromParameter:[[data objectForKey:kAboutMenuDisplayParamKey] unsignedIntValue] atTime:time];
			if (toggle) {
				[paramGetAPIv6 getStringParameterValue:&string fromParameter:[[data objectForKey:kAboutMenuTextParamKey] unsignedIntValue]];
				[items addObject:string];
				hasTemplateItem = true;
			}
		}
		[paramGetAPIv6 getBoolValue:&bottomSeparator fromParameter:SS_MetalFxSeparator atTime:time];
	}
	
	if (bottomSeparator && (!topSeparator || hasTemplateItem)) {
		[items addObject:@"-"];
	}
	
	if (paramGetAPIv6 != nil) {
		[paramGetAPIv6 getBoolValue:&showHelpItem fromParameter:SS_MetalFxHelpDisplay atTime:time];
	}
	if (showHelpItem) {
		[items addObject:NSLocalizedString(kMetalFxHelp, @"MetalFx ML Upscale Help")];
	}
	
	[items addObject:NSLocalizedString(kMetalFxAbout, @"MetalFx ML Upscale About Text")];
	[items addObject:NSLocalizedString(kMetalFxSupportFollow, @"MetalFx ML Upscale Follow Me Text")];
	[items addObject:NSLocalizedString(kMetalFxSupport1Time, @"MetalFx ML Upscale Support 1 Time Tip")];
	[items addObject:NSLocalizedString(kMetalFxSupportMonthly, @"MetalFx ML Upscale Monthly Support")];
	
	return items; */
	return nil;
}



/*!
	@method     -clickResetAboutMenu
	@discussion This method is called to Reset the About Menu and disable the Menu Refresh Button.
 */
- (void) clickResetAboutMenu
{
	/*
	id<FxDynamicParameterAPI_v3> dynamicParamAPIv3 = self.apiManager.dynamicParamAPIv3;
	if (!dynamicParamAPIv3) {
		return;
	}
	CMTime time = {0, 1000, kCMTimeFlags_Valid | kCMTimeFlags_ImpliedValueFlagsMask, 0};
	
	// Redo the About Menu
	[dynamicParamAPIv3 setPopupMenuParameter:SS_AboutMenu entries:[self computeAboutMenuFrom:self.apiManager.paramGetAPIv6 atTime:time] defaultValue:0];
	
	// disable the "Refresh About Menu Button"
	id<FxParameterSettingAPI_v6> paramSetAPIv6 = self.apiManager.paramSetAPIv6;
	if (!paramSetAPIv6) {
		return;
	}
	[paramSetAPIv6 addFlags:kFxParameterFlag_DISABLED toParameter:SS_AboutRefresh];
	 */
}


- (void)clickAboutMenu:(unsigned int)selectionIndex paramAPIv6:(id<FxParameterRetrievalAPI_v6>)paramGetAPIv6 atTime:(CMTime)time
{
	/*
	#if kDebugPluginCalls
	NSLog(@"******  %s(%llu)::clickAboutMenu >>", __func__, self.apiManager.sessionID);
	#endif
	
#define kClickWarningText @"self://publishAboutDialog"
	NSString *urlString = nil, *fallbackUrlString = nil;
	
	int agreementIndex = 0;
	[paramGetAPIv6 getIntValue:&agreementIndex fromParameter:SS_AboutAgreement atTime:time];
	if (agreementIndex < kAboutAgreementYesValue) {
		if(selectionIndex <= 3) {
			urlString = kClickWarningText;
			goto linkAction;
		} else {
			selectionIndex -= 4;
		}
	}
	
	BOOL toggle = false, topSeparator = false, hasTemplateItem = false;
	
	// Main Text
	if (selectionIndex == 0) {
		// selected main text, do nothing.
		return;
	}
	selectionIndex -= 1;
	
	[paramGetAPIv6 getBoolValue:&topSeparator fromParameter:SS_AboutSeparator atTime:time];
	if (topSeparator) {
		selectionIndex -= 1;
	}
	
#define kAboutMenuDisplayParamKey @"displayId"
#define kAboutMenuURLParamKey @"urlId"
#define kAboutMenuFailURLParamKey @"failUrlId"
	NSArray *items = @[@{kAboutMenuDisplayParamKey : @(SS_Help_TemplateDisplay),
							 kAboutMenuURLParamKey : @(SS_Help_TemplateUrl),
						 kAboutMenuFailURLParamKey : @(SS_Help_TemplateFailUrl)},
					   @{kAboutMenuDisplayParamKey : @(SS_About_TemplateDisplay),
							 kAboutMenuURLParamKey : @(SS_About_TemplateUrl),
						 kAboutMenuFailURLParamKey : @(SS_About_TemplateFailUrl)},
					   @{kAboutMenuDisplayParamKey : @(SS_About_EditorDisplay),
							 kAboutMenuURLParamKey : @(SS_About_EditorUrl),
						 kAboutMenuFailURLParamKey : @(SS_About_EditorFailUrl)},
					   @{kAboutMenuDisplayParamKey : @(SS_Follow_AuthorDisplay),
							 kAboutMenuURLParamKey : @(SS_Follow_AuthorUrl),
						 kAboutMenuFailURLParamKey : @(SS_Follow_AuthorFailUrl)},
					   @{kAboutMenuDisplayParamKey : @(SS_Support_AuthorDisplay),
							 kAboutMenuURLParamKey : @(SS_Support_AuthorUrl),
						 kAboutMenuFailURLParamKey : @(SS_Support_AuthorFailUrl)},
					   @{kAboutMenuDisplayParamKey : @(SS_Support2_AuthorDisplay),
							 kAboutMenuURLParamKey : @(SS_Support2_AuthorUrl),
						 kAboutMenuFailURLParamKey : @(SS_Support2_AuthorFailUrl)},
					   @{kAboutMenuDisplayParamKey : @(SS_Support3_AuthorDisplay),
							 kAboutMenuURLParamKey : @(SS_Support3_AuthorUrl),
						 kAboutMenuFailURLParamKey : @(SS_Support3_AuthorFailUrl)}];
	
	for (NSDictionary *menuItem in items) {
		[paramGetAPIv6 getBoolValue:&toggle fromParameter:[[menuItem objectForKey:kAboutMenuDisplayParamKey] unsignedIntValue] atTime:time];
		if (toggle) {
			hasTemplateItem = true;
			if (selectionIndex == 0) {
				NSString *failUrl = nil;
				[paramGetAPIv6 getStringParameterValue:&urlString fromParameter:[[menuItem objectForKey:kAboutMenuURLParamKey] unsignedIntValue]];
				[paramGetAPIv6 getStringParameterValue:&failUrl fromParameter:[[menuItem objectForKey:kAboutMenuFailURLParamKey] unsignedIntValue]];
				if (failUrl && [failUrl length]) {
					fallbackUrlString = failUrl;
				}
				goto linkAction;
			} else {
				selectionIndex -= 1;
			}
		}
	}
	
	[paramGetAPIv6 getBoolValue:&toggle fromParameter:SS_MetalFxSeparator atTime:time];
	if (toggle && (!topSeparator || hasTemplateItem)) {
		// There's a bottom separator when on with
		//		1) No top separator
		//		2) Top separator and items
		selectionIndex -= 1;
	}
	
	[paramGetAPIv6 getBoolValue:&toggle fromParameter:SS_MetalFxHelpDisplay atTime:time];
	if (toggle) {
		if (selectionIndex == 0) {
			urlString = @"help://Main";
			goto linkAction;
		} else {
			selectionIndex -= 1;
		}
	}
	switch(selectionIndex) {
		case 0: // MetalFx Plugin About
			urlString = kMetalFxMLUpscaleUrl_About;
			break;
		case 1: // Follow
			urlString = kMetalFxMLUpscaleUrl_YouTube_Follow;
			break;
		case 2: // One time tip
			urlString = kMetalFxMLUpscaleUrl_Odysee;
			break;
		case 3: // Monthly Support
			urlString = kMetalFxMLUpscaleUrl_YouTubeJoin;
			break;
	}
	
linkAction:
	if (urlString && [urlString isEqualTo:kClickWarningText]) {
		//Dialog
		
		NSLog(@"%s(%llu) -> Display Error Dialog Box", __func__, self.apiManager.sessionID);
	} else {
		__block NSMutableArray *urls = [[NSMutableArray array] retain];
		__block int urlIndex = 0;
		if (urlString && [urlString length])
			[urls addObject:urlString];
		if (fallbackUrlString && [fallbackUrlString length])
			[urls addObject:fallbackUrlString];
		fallbackUrlString = nil;
		[paramGetAPIv6 getStringParameterValue:&fallbackUrlString fromParameter:SS_AboutFallbackUrl];
		if (fallbackUrlString && [fallbackUrlString length])
			[urls addObject:fallbackUrlString];
		
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration];
		config.promptsUserIfNeeded = NO;
		void __block (^blockRecursion)(NSRunningApplication*, NSError*);
		void (^completionBlock)(NSRunningApplication*, NSError*) = ^(NSRunningApplication *app, NSError *error) {
				BOOL success = (error == nil);
				if (!success && urlIndex < [urls count]) {
					NSLog(@"****** %s(%llu) Tried to open URL but got error: %@", __func__, self.apiManager.sessionID, error);
					NSURL *url = nil;
					do {
						NSString *str = [urls objectAtIndex:urlIndex++];
						url = [NSURL URLWithString:str];
					} while (!url && urlIndex < [urls count]);
					if (url) {
						[workspace openURL:url configuration:config completionHandler:blockRecursion];
						error = nil;
					}
				}
				if (error) {
					NSBeep();
					NSLog(@"%s(%llu) Open URL Fallback Failure:  %@", __func__, self.apiManager.sessionID, error);
					blockRecursion = nil;
				}
				if (success) {
					blockRecursion = nil;
				}
			};
		blockRecursion = [completionBlock copy];
		NSURL *url = nil;
		do {
			NSString *str = urls.firstObject;
			[urls removeObjectAtIndex:0];
			url = [NSURL URLWithString:str];
		} while (!url && [urls count]);
		if (url)
			[workspace openURL:url configuration:config completionHandler:completionBlock];
	 
	 	[self broadcastName:kAboutMenuBroadcastLink userInfo:@{kAboutMenuBroadcastLinkURL: @(url)}];
	}
	#if kDebugPluginCalls
	NSLog(@"******  %s(%llu)::clickAboutMenu <<", __func__, self.apiManager.sessionID);
   #endif
	*/
}


@end
