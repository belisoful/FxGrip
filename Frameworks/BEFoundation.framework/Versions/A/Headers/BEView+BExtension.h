/*!
 @header     BEView+BExtension.h
 @copyright  -© 2025 Delicense - @belisoful. All rights released.
 @author     belisoful@icloud.com
 @abstract   Auto Layout convenience for @c BEView (@c NSView on macOS, @c UIView on iOS).
 @discussion Pinning, centering, and sizing a view with Auto Layout is 5–10 lines of anchor
             boilerplate each, and forgetting @c translatesAutoresizingMaskIntoConstraints = NO
             is a perennial gotcha. These helpers do both: each clears that flag automatically,
             activates the constraints it creates, and returns them so the caller can later
             deactivate or animate them. @c NSLayoutAnchor and @c UILayoutAnchor are the same
             API, so a single implementation serves both platforms.

             @code
             // Pin a content view to its superview, then center a badge inside it.
             [contentView pinEdgesToSuperview];
             NSArray<NSLayoutConstraint *> *centering = [badge centerInSuperview];
             @endcode
 */

#ifndef BEView_BExtension_h
#define BEView_BExtension_h

#import <Foundation/Foundation.h>
#import <BEFoundation/BEPlatformTypes.h>

NS_ASSUME_NONNULL_BEGIN

@interface BEView (BExtension)

/*!
 @method     pinEdgesToSuperview
 @abstract   Pins the receiver's four edges to its superview's edges.
 @return     The four activated constraints (top, leading, bottom, trailing), or an empty array
             if the receiver has no superview.
 */
- (NSArray<NSLayoutConstraint *> *)pinEdgesToSuperview;

/*!
 @method     pinEdgesToSuperviewWithInsets:
 @abstract   Pins the receiver's four edges to its superview's edges with the given insets.
 @param      insets Distances from the superview edges. @c left maps to the leading edge and
                    @c right to the trailing edge (so this respects right-to-left layout).
 @return     The four activated constraints, or an empty array if the receiver has no superview.
 */
- (NSArray<NSLayoutConstraint *> *)pinEdgesToSuperviewWithInsets:(BEEdgeInsets)insets;

/*!
 @method     pinEdgesToView:insets:
 @abstract   Pins the receiver's four edges to another view's edges with the given insets.
 @param      view   The view to pin to (typically an ancestor or sibling in the same hierarchy).
 @param      insets Distances from @c view's edges (@c left → leading, @c right → trailing).
 @return     The four activated constraints, or an empty array if @c view is nil.
 */
- (NSArray<NSLayoutConstraint *> *)pinEdgesToView:(BEView *)view insets:(BEEdgeInsets)insets;

/*!
 @method     centerInSuperview
 @abstract   Centers the receiver horizontally and vertically within its superview.
 @return     The two activated constraints (centerX, centerY), or an empty array if the receiver
             has no superview.
 */
- (NSArray<NSLayoutConstraint *> *)centerInSuperview;

/*!
 @method     constrainToSize:
 @abstract   Constrains the receiver to a fixed width and height.
 @param      size The fixed size.
 @return     The two activated constraints (width, height).
 */
- (NSArray<NSLayoutConstraint *> *)constrainToSize:(CGSize)size;

/*!
 @method     constrainToWidth:height:
 @abstract   Constrains the receiver to a fixed width and height.
 @return     The two activated constraints (width, height).
 */
- (NSArray<NSLayoutConstraint *> *)constrainToWidth:(CGFloat)width height:(CGFloat)height;

@end

NS_ASSUME_NONNULL_END

#endif // !BEView_BExtension_h
