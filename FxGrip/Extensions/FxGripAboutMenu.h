/*!
	@file       FxGripAboutMenu.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripAboutMenu
	@abstract   The extension that builds a plugin's About popup menu from a configuration dictionary.
	@discussion Introduced in FxGrip 0.1.0. The extension registers a hidden popup parameter whose rows
	            come from the effect's "aboutMenu" configuration. Each row is a link, a separator, a
	            text line, or the About dialog. A link row opens the first reachable URL from an
	            ordered fallback chain and posts FxGripAboutMenuLinkName. An agreement parameter
	            gates the warning rows, and a per-entry display parameter gates an individual row.
	            The extension rebuilds the popup when a gating parameter changes.
*/

#ifndef FxGripAboutMenu_h
#define FxGripAboutMenu_h

#import "FxGripExtension.h"
#import "FxGripTileableEffect.h"

/*! The registry key under which the effect stores the About menu extension. */
extern NSString*	const _Nonnull FxGripAboutMenuExtensionKey;

/*!
	@abstract   Posted after the About menu opens a link.
	@discussion Introduced in FxGrip 0.1.0. The user info carries the opened URL string under
				FxGripAboutMenuLinkURLKey.
*/
extern NSNotificationName const _Nonnull FxGripAboutMenuLinkName;
/*! The opened URL string, carried in the FxGripAboutMenuLinkName user info. */
extern NSString* const _Nonnull FxGripAboutMenuLinkURLKey;

#pragma mark Configuration keys

// The About menu configuration dictionary (plugin property "aboutMenu").
/*! The array of entry dictionaries the menu presents. */
extern NSString* const _Nonnull FxGripAboutMenuItemsKey;			// NSArray of entry dictionaries
/*! The popup parameter's name. */
extern NSString* const _Nonnull FxGripAboutMenuNameKey;				// NSString, the popup parameter's name
/*! The main About line shown above the entries. */
extern NSString* const _Nonnull FxGripAboutMenuMainTextKey;			// NSString, the main About line
/*! The parameter ID of the agreement parameter that gates the warning rows. */
extern NSString* const _Nonnull FxGripAboutMenuAgreementIdKey;		// NSNumber(FxParameterId) of the agreement parameter
/*! The value at or above which the agreement is accepted; default 1. */
extern NSString* const _Nonnull FxGripAboutMenuAgreementAcceptedValueKey;	// NSNumber, value at or above which the agreement is accepted (default 1)
/*! The warning lines shown until the agreement is accepted. */
extern NSString* const _Nonnull FxGripAboutMenuWarningKey;			// NSArray<NSString*> of warning lines shown until the agreement is accepted
/*! The text shown in the warning dialog. */
extern NSString* const _Nonnull FxGripAboutMenuWarningDialogTextKey;	// NSString shown in the warning dialog
/*! A URL appended to every link's fallback chain. */
extern NSString* const _Nonnull FxGripAboutMenuFallbackUrlKey;		// NSString appended to every link's fallback chain

// Entry dictionary keys.
/*! The entry's label; localizable. */
extern NSString* const _Nonnull FxGripAboutEntryLabelKey;			// NSString label (localizable)
/*! The entry's kind, one of the FxGripAboutEntryKind* strings; default is link. */
extern NSString* const _Nonnull FxGripAboutEntryKindKey;			// one of the FxGripAboutEntryKind* strings; default link
/*! The primary URL for a link entry. */
extern NSString* const _Nonnull FxGripAboutEntryUrlKey;				// NSString primary URL for a link entry
/*! The ordered fallback URLs tried when the primary URL fails. */
extern NSString* const _Nonnull FxGripAboutEntryFallbacksKey;		// NSArray<NSString*> of fallback URLs
/*! The parameter ID of a Bool parameter that gates the entry's display. */
extern NSString* const _Nonnull FxGripAboutEntryDisplayIdKey;		// NSNumber(FxParameterId) of a Bool that gates the entry

// Entry kinds.
/*! An entry that opens a URL; the default kind. */
extern NSString* const _Nonnull FxGripAboutEntryKindLink;			// opens a URL (default)
/*! An entry that renders as a divider. */
extern NSString* const _Nonnull FxGripAboutEntryKindSeparator;		// a divider
/*! An entry that renders as a non-actionable line. */
extern NSString* const _Nonnull FxGripAboutEntryKindText;			// a non-actionable line
/*! An entry that shows the About dialog. */
extern NSString* const _Nonnull FxGripAboutEntryKindDialog;			// shows the About dialog

/*!
	@class		FxGripAboutMenu
	@abstract	The extension that presents a plugin's About popup menu.
	@discussion	Introduced in FxGrip 0.1.0. The extension registers the popup parameter, resolves its
				rows from the effect's About menu configuration, and dispatches the row the user
				selects to a link, dialog, or no-op action.
*/
@interface FxGripAboutMenu : FxGripExtension


@end


/*!
	@abstract	The effect-side accessors that resolve and install the About menu extension.
	@discussion	Introduced in FxGrip 0.1.0. aboutMenuConfiguration reads the plugin's "aboutMenu"
				property, and the loader installs the extension when hasAboutMenu is YES.
*/
@interface FxGripTileableEffect (AboutMenu)

/*! The installed About menu extension, or nil when none is installed. */
@property (readonly, nullable) FxGripAboutMenu *aboutMenu;

/*! YES when the effect resolves an About menu configuration; the loader gates on this. */
@property (readonly) BOOL hasAboutMenu;

/*!
	@property   aboutMenuConfiguration
	@abstract   The About menu configuration dictionary.
	@discussion Introduced in FxGrip 0.1.0. Default is the Info.plist `aboutMenu` dictionary. A
				plugin overrides this getter to supply or replace the configuration in code.
*/
@property (readonly, nullable) NSDictionary *aboutMenuConfiguration;

/*!
	@method     aboutMenuItems:
	@abstract   The ordered About menu entries, after the subclass has a chance to change them.
	@discussion Introduced in FxGrip 0.1.0. `items` is the entry array resolved from
				aboutMenuConfiguration. The default returns it unchanged. A plugin overrides
				this method to extend, reorder, or replace the entries at runtime.
*/
- (nonnull NSArray<NSDictionary*> *)aboutMenuItems:(nonnull NSArray<NSDictionary*> *)items;

/*!
	@method		newAboutMenuExtension
	@abstract	Creates the About menu extension instance for this effect.
	@return		A new extension the loader installs.
	@discussion	Introduced in FxGrip 0.1.0. A subclass overrides this to supply a custom subclass. */
- (nonnull FxGripAboutMenu *)newAboutMenuExtension;

@end

#endif
