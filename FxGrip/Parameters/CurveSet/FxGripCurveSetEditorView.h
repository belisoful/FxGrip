//
//  FxGripCurveSetEditorView.h
//  FxGrip
//

#ifndef FxGripCurveSetEditorView_h
#define FxGripCurveSetEditorView_h

#import <AppKit/AppKit.h>
#import "FxGripCurveEditorView.h"
#import "FxGripEffectHost.h"
#import "FxGripCurveSetData.h"
#import "FxGripTypes.h"

@protocol FxTileableEffectBase;

/*!
	@class      FxGripCurveSetEditorView
	@abstract   The inspector composite: labeled curve strips over one curve-set value.
	@discussion Introduced in FxGrip 1.0. A filter's parameter class builds the
				composite by declaring each mapping (addEditorForKey:...) in FCP strip
				order, and createViewForParameterID: returns it, so one custom
				parameter carries the filter's whole curve set.

				The composite multiplexes: updateFromCustomData: hands the set to every
				child strip (each reads its mappingKey); a strip's continuous edits
				update the working set, and its commit writes the set to the host
				through an out-of-band access context, so the host's undo records the
				gesture. Storing follows the set's neutral rule: a committed identity
				removes the mapping's key.
*/
@interface FxGripCurveSetEditorView : NSView <FxGripCustomViewDataDelegate, FxGripCurveEditorDelegate>

@property (nonatomic, assign, nullable) id<FxGripEffectHost> parameterEffect;
@property (nonatomic, assign) FxParameterId parameterID;

/*! The working curve set: the last pushed value plus uncommitted edits. */
@property (nonatomic, readonly, nonnull) FxGripCurveSetData *curveSet;

/*! The child strips, in declaration order. */
@property (nonatomic, readonly, nonnull) NSArray<FxGripCurveEditorView *> *editors;

/*!
	@property   slowDragScale
	@abstract   The Control-slowed drag fraction applied to every strip.
	@discussion Setting propagates to the existing strips and to strips added later.
				Each strip clamps to [0.01, 1.0]; the getter reports the clamped value.
				Defaults to kFxGripCurveSlowDragScaleDefault.
*/
@property (nonatomic, assign) CGFloat slowDragScale;

/*!
	@method     addEditorForKey:title:role:domain:background:
	@abstract   Appends one labeled strip for a mapping.
	@result     The created strip, configured and stacked.
*/
- (nonnull FxGripCurveEditorView *)addEditorForKey:(nonnull NSString *)key
											 title:(nonnull NSString *)title
											  role:(FxGripCurveRole)role
											domain:(FxGripCurveDomain)domain
										background:(FxGripCurveBackground)background;

@end

#endif /* FxGripCurveSetEditorView_h */
