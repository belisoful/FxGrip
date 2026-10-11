/*!
	@file       FxGripFCPXMLLibrary.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-10-10
	@header     FxGripFCPXMLLibrary
	@abstract   The `library`, `event`, and `project` elements.
	@discussion Introduced in FxGrip 0.1.0. A library holds events; an event holds clips,
	            collections, and projects; a project holds one sequence. A document may also
	            carry events or event items at the top level without a library.
*/

#ifndef FxGripFCPXMLLibrary_h
#define FxGripFCPXMLLibrary_h

#import <FxGrip/FxGripFCPXMLStoryElement.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripFCPXMLProject
	@abstract   A `project`: a named sequence.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLProject : FxGripFCPXMLElement

/*! The project name. */
@property (readwrite, copy, nullable) NSString *projectName;
/*! The Final Cut Pro assigned unique identifier. */
@property (readwrite, copy, nullable) NSString *uid;
/*! The document-local identifier. */
@property (readwrite, copy, nullable) NSString *identifier;
/*! The modification date string. */
@property (readwrite, copy, nullable) NSString *modificationDate;
/*! The sequence, or nil. */
@property (readonly, nullable) FxGripFCPXMLStoryElement *sequence;

/*! A project with a name and a sequence. */
+ (instancetype)projectWithName:(nullable NSString *)name sequence:(FxGripFCPXMLStoryElement *)sequence;
/*! Replaces the sequence. */
- (void)setSequence:(FxGripFCPXMLStoryElement *)sequence;

@end

/*!
	@class      FxGripFCPXMLEvent
	@abstract   An `event`: clips, collections, and projects.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLEvent : FxGripFCPXMLElement

/*! The event name. */
@property (readwrite, copy, nullable) NSString *eventName;
/*! The Final Cut Pro assigned unique identifier. */
@property (readwrite, copy, nullable) NSString *uid;
/*! The projects. */
@property (readonly, copy) NSArray<FxGripFCPXMLProject *> *projects;
/*! The story-element clips, excluding projects and collections. */
@property (readonly, copy) NSArray<FxGripFCPXMLStoryElement *> *clips;
/*! Every item, in document order. */
@property (readonly, copy) NSArray<FxGripFCPXMLElement *> *items;

/*! An event with a name. */
+ (instancetype)eventWithName:(nullable NSString *)name;
/*! Appends an item: a clip, collection, or project. */
- (void)addItem:(FxGripFCPXMLElement *)item;

@end

/*!
	@class      FxGripFCPXMLLibrary
	@abstract   A `library`: events and smart collections.
	@discussion Introduced in FxGrip 0.1.0.
*/
@interface FxGripFCPXMLLibrary : FxGripFCPXMLElement

/*! The library file URL string. */
@property (readwrite, copy, nullable) NSString *location;
/*! The color processing: `standard`, `wide`, or `wide-hdr`. */
@property (readwrite, copy, nullable) NSString *colorProcessing;
/*! The events. */
@property (readonly, copy) NSArray<FxGripFCPXMLEvent *> *events;

/*! The event with a name, or nil. */
- (nullable FxGripFCPXMLEvent *)eventNamed:(NSString *)name;
/*! Appends an event. */
- (void)addEvent:(FxGripFCPXMLEvent *)event;
/*! The first event, created when the library has none. */
- (FxGripFCPXMLEvent *)firstEventCreatingIfNeeded;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripFCPXMLLibrary_h */
