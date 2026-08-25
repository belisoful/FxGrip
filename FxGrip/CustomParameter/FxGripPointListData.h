//
//  FxGripPointListData.h
//  FxGrip
//

#ifndef FxGripPointListData_h
#define FxGripPointListData_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
	@class      FxGripPointListData
	@abstract   An immutable ordered list of object-space points with a closed flag.
	@discussion Introduced in FxGrip 1.0. Backs an editable on-screen polygon whose vertex
				count changes at runtime, which a fixed set of point parameters cannot
				express. The whole list is stored in one custom-data parameter. Points hold
				object-space coordinates, matching the point parameters the other OSC parts
				read. Edits return a new instance; there is no mutable variant.
*/
@interface FxGripPointListData : NSObject <NSSecureCoding, NSCopying>

/*! The number of points. */
@property (readonly) NSUInteger count;

/*! YES closes the chain's last point back to the first. */
@property (readonly) BOOL closed;

/*! The point at an index, or CGPointZero when the index is out of range. */
- (CGPoint)pointAtIndex:(NSUInteger)index;

+ (instancetype)emptyPointListClosed:(BOOL)closed;

+ (instancetype)pointListWithPoints:(nullable const CGPoint *)points
							  count:(NSUInteger)count
							 closed:(BOOL)closed;

/*! A new list with point inserted at index, clamped to [0, count]. */
- (instancetype)byInsertingPoint:(CGPoint)point atIndex:(NSUInteger)index;

/*! A new list with the point at index removed. Returns self when the index is out of range. */
- (instancetype)byRemovingPointAtIndex:(NSUInteger)index;

/*! A new list with the point at index replaced. Returns self when the index is out of range. */
- (instancetype)byReplacingPointAtIndex:(NSUInteger)index withPoint:(CGPoint)point;

/*! A new list with every point offset by delta. */
- (instancetype)byTranslatingBy:(CGPoint)delta;

/*! Writes the points into buffer, at most capacity, and returns the number written. */
- (NSUInteger)copyPointsToBuffer:(CGPoint *)buffer capacity:(NSUInteger)capacity;

@end

NS_ASSUME_NONNULL_END

#endif /* FxGripPointListData_h */
