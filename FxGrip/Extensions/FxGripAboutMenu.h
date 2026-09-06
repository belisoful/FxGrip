//
//  FxGripAboutMenu.h
//  FxGrip
//
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripAboutMenu_h
#define FxGripAboutMenu_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

extern NSString*	const _Nonnull FxGripAboutMenuExtensionKey;

/*!
	@abstract   Posted after the About menu opens a link.
	@discussion Introduced in FxGrip 1.0. The user info carries the opened URL string under
				FxGripAboutMenuLinkURLKey.
*/
extern NSNotificationName const _Nonnull FxGripAboutMenuLinkName;
extern NSString* const _Nonnull FxGripAboutMenuLinkURLKey;

#pragma mark Configuration keys

// The About menu configuration dictionary (plugin property "aboutMenu").
extern NSString* const _Nonnull FxGripAboutMenuItemsKey;			// NSArray of entry dictionaries
extern NSString* const _Nonnull FxGripAboutMenuNameKey;				// NSString, the popup parameter's name
extern NSString* const _Nonnull FxGripAboutMenuMainTextKey;			// NSString, the main About line
extern NSString* const _Nonnull FxGripAboutMenuAgreementIdKey;		// NSNumber(FxParameterId) of the agreement parameter
extern NSString* const _Nonnull FxGripAboutMenuAgreementAcceptedValueKey;	// NSNumber, value at or above which the agreement is accepted (default 1)
extern NSString* const _Nonnull FxGripAboutMenuWarningKey;			// NSArray<NSString*> of warning lines shown until the agreement is accepted
extern NSString* const _Nonnull FxGripAboutMenuWarningDialogTextKey;	// NSString shown in the warning dialog
extern NSString* const _Nonnull FxGripAboutMenuFallbackUrlKey;		// NSString appended to every link's fallback chain

// Entry dictionary keys.
extern NSString* const _Nonnull FxGripAboutEntryLabelKey;			// NSString label (localizable)
extern NSString* const _Nonnull FxGripAboutEntryKindKey;			// one of the FxGripAboutEntryKind* strings; default link
extern NSString* const _Nonnull FxGripAboutEntryUrlKey;				// NSString primary URL for a link entry
extern NSString* const _Nonnull FxGripAboutEntryFallbacksKey;		// NSArray<NSString*> of fallback URLs
extern NSString* const _Nonnull FxGripAboutEntryDisplayIdKey;		// NSNumber(FxParameterId) of a Bool that gates the entry

// Entry kinds.
extern NSString* const _Nonnull FxGripAboutEntryKindLink;			// opens a URL (default)
extern NSString* const _Nonnull FxGripAboutEntryKindSeparator;		// a divider
extern NSString* const _Nonnull FxGripAboutEntryKindText;			// a non-actionable line
extern NSString* const _Nonnull FxGripAboutEntryKindDialog;			// shows the About dialog

@interface FxGripAboutMenu : FxGripExtension


@end


@interface FxGripTileableEffect (AboutMenu)

@property (readonly, nullable) FxGripAboutMenu *aboutMenu;

/*! YES when the effect resolves an About menu configuration; the loader gates on this. */
@property (readonly) BOOL hasAboutMenu;

/*!
	@property   aboutMenuConfiguration
	@abstract   The About menu configuration dictionary.
	@discussion Introduced in FxGrip 1.0. Default is the Info.plist `aboutMenu` dictionary. A
				plugin overrides this getter to supply or replace the configuration in code.
*/
@property (readonly, nullable) NSDictionary *aboutMenuConfiguration;

/*!
	@method     aboutMenuItems:
	@abstract   The ordered About menu entries, after the subclass has a chance to change them.
	@discussion Introduced in FxGrip 1.0. `items` is the entry array resolved from
				aboutMenuConfiguration. The default returns it unchanged. A plugin overrides
				this method to extend, reorder, or replace the entries at runtime.
*/
- (nonnull NSArray<NSDictionary*> *)aboutMenuItems:(nonnull NSArray<NSDictionary*> *)items;

- (nonnull FxGripAboutMenu *)newAboutMenuExtension;

@end

#endif
