//
//  FxGripCurveData.h
//  FxGrip
//

#ifndef FxGripCurveData_h
#define FxGripCurveData_h

#import <Foundation/Foundation.h>
#import "FxGripCurveLUT.h"

/*!
	@enum       FxGripCurveDomain
	@abstract   The x-axis domain of a curve.
	@discussion Linear curves clamp x and hold their end values; circular curves (a hue
				selector) evaluate on a period-1 circle with the periodic builder, so
				the seam at x = 0/1 is C¹-continuous. Raw values are stable.
*/
typedef NS_ENUM(NSInteger, FxGripCurveDomain) {
	FxGripCurveDomainLinear		= 0,
	FxGripCurveDomainCircular	= 1,
};

/*!
	@enum       FxGripCurveRole
	@abstract   How a filter consumes the curve, which fixes its neutral shape.
	@discussion Remap curves are neutral on the diagonal. Shift curves are neutral flat
				at 0.5 (a target-hue shift of none). Half multipliers are neutral flat
				at 0.5 with the shader applying 2x. One multipliers are neutral flat at
				1.0. Raw values are stable.
*/
typedef NS_ENUM(NSInteger, FxGripCurveRole) {
	FxGripCurveRoleRemap			= 0,
	FxGripCurveRoleShift			= 1,
	FxGripCurveRoleMultiplierHalf	= 2,
	FxGripCurveRoleMultiplierOne	= 3,
};

/*!
	@class      FxGripCurveData
	@abstract   One immutable cubic curve: sorted control points with a domain and role.
	@discussion Introduced in FxGrip 1.0. Points are sanitized at creation: y clamps to
				[0, 1]; x clamps to [0, 1] in the linear domain and folds into [0, 1)
				in the circular domain; points sort by ascending x and duplicate x
				drops (first wins). Edits replace the value; there is no mutable
				variant.

				buildLUT:count: evaluates with the same Fritsch-Carlson monotone cubic
				the Metal Forge render uses (FxGripCurveLUT), choosing the periodic
				builder for the circular domain. copyCurvePointsFloat2:capacity: is the
				conversion to Metal Forge's input contract; each written pair matches
				the simd_float2 layout.
*/
@interface FxGripCurveData : NSObject <NSSecureCoding, NSCopying>

@property (readonly) FxGripCurveDomain domain;
@property (readonly) FxGripCurveRole role;
@property (readonly) NSUInteger pointCount;

/*! The point at an index, sorted by ascending x. NSZeroPoint beyond the count. */
- (CGPoint)pointAtIndex:(NSUInteger)index;

/*! The role's neutral curve: the diagonal for a remap, the flat neutral otherwise. */
+ (nonnull instancetype)identityCurveWithRole:(FxGripCurveRole)role
									   domain:(FxGripCurveDomain)domain;

+ (nullable instancetype)curveWithPoints:(const CGPoint *_Nullable)points
								   count:(NSUInteger)count
									role:(FxGripCurveRole)role
								  domain:(FxGripCurveDomain)domain;

/*! YES when the points equal the role's neutral shape. */
- (BOOL)isIdentity;

/*!
	@method     copyCurvePointsFloat2:capacity:
	@abstract   Writes the points as (x, y) float pairs.
	@discussion Introduced in FxGrip 1.0. The pair layout matches simd_float2, so the
				buffer passes straight to a Metal Forge setCurvePoints:count:forChannel:.
	@result     The number of pairs written, at most `capacity`.
*/
- (NSUInteger)copyCurvePointsFloat2:(float (*_Nonnull)[2])buffer capacity:(NSUInteger)capacity;

/*! Evaluates the curve into a LUT with the domain's builder. */
- (void)buildLUT:(float *_Nonnull)outLUT count:(NSUInteger)n;

@end

#endif /* FxGripCurveData_h */
