/*!
	@file       FxGripFMM.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMM
	@abstract   An adaptive Fast Multipole Method for the inter-particle field, in O(N) per step.
	@discussion Introduced in FxGrip 0.1.0. SceneKit computes no particle-to-particle force. This C
	            core evaluates the field every particle exerts on every other, in linear time, so a
	            deterministic re-simulation stays affordable. It has no SceneKit or Objective-C
	            dependency; the categories that install it on a particle system live elsewhere.

	            The scalar entry point evaluates the softened Laplace field for gravity and electric
	            forces. The Biot-Savart entry point evaluates the magnetic field of moving charges. A
	            direct O(N²) reference for each has identical semantics and backs the accuracy tests.

	            Inputs are structure-of-arrays of single-precision floats. The caller folds the
	            per-receiver coupling (the gravitational constant times receiver mass, or the electric
	            constant times receiver charge) after the field is returned, so one evaluation serves
	            gravity and electric alike.
*/

#ifndef FxGripFMM_h
#define FxGripFMM_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*!
	@struct     FxGripFMMParameters
	@abstract   The knobs that trade accuracy against speed.
	@field      expansionOrder   The multipole order: 2, 4, or 6. Higher is more accurate and slower.
	@field      theta            The multipole acceptance ratio; a cell pair interacts by multipole
	                             when (rA + rB) / distance is below this. Smaller is more accurate.
	@field      leafCapacity     The particle count above which a cell subdivides (ncrit).
	@field      directThreshold  At or below this particle count the evaluation is a direct sum.
	@field      softening        The softening length ε, in world units, that bounds the near force.
	@field      maxThreads       The parallel width; 0 selects the hardware concurrency.
*/
typedef struct FxGripFMMParameters {
	uint32_t expansionOrder;
	float    theta;
	uint32_t leafCapacity;
	uint32_t directThreshold;
	float    softening;
	uint32_t maxThreads;
} FxGripFMMParameters;

/*! @abstract The default parameters: order 4, theta 0.5, leaf 64, direct threshold 2048, small
	softening, hardware concurrency. */
FxGripFMMParameters FxGripFMMDefaultParameters(void);

/*!
	@typedef    FxGripFMMContext
	@abstract   An opaque owner of the reusable scratch memory for a series of evaluations.
	@discussion Introduced in FxGrip 0.1.0. The context grows its arena as needed and reuses it across
	            evaluations, so a warm evaluation allocates nothing. It is not thread-safe; give each
	            concurrent evaluation its own context.
*/
typedef struct FxGripFMMContext FxGripFMMContext;

/*! @abstract Creates an evaluation context, or NULL on allocation failure. */
FxGripFMMContext *FxGripFMMContextCreate(void);

/*! @abstract Destroys a context and frees its arena. NULL is ignored. */
void FxGripFMMContextDestroy(FxGripFMMContext *context);

/*! @abstract The high-water mark of the context arena, in bytes. */
uint64_t FxGripFMMContextArenaHighWaterMark(const FxGripFMMContext *context);

/*! @abstract The number of arena and cell-buffer reallocations so far; unchanged across warm
	same-sized evaluations, which is the no-allocation guarantee the test checks. */
uint64_t FxGripFMMContextAllocationCount(const FxGripFMMContext *context);

/*!
	@function   FxGripFMMEvaluateField
	@abstract   Evaluates the softened Laplace field at every source point from every other.
	@discussion Introduced in FxGrip 0.1.0. Computes, for each i,
	            E_i = Σ_{j≠i} strength_j · (r_j − r_i) / (|r_j − r_i|² + ε²)^{3/2}. The self term is
	            excluded. Inputs are length n; outputs ex, ey, ez are filled by the call. Passing a
	            NULL context, a NULL array, or n = 0 is a no-op.
*/
void FxGripFMMEvaluateField(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
							uint32_t n,
							const float *x, const float *y, const float *z, const float *strength,
							float *ex, float *ey, float *ez);

/*!
	@function   FxGripFMMEvaluateBiotSavart
	@abstract   Evaluates the magnetic field of moving charges at every source point from every other.
	@discussion Introduced in FxGrip 0.1.0. Computes, for each i,
	            B_i = Σ_{j≠i} strength_j · (v_j × (r_i − r_j)) / (|r_i − r_j|² + ε²)^{3/2}. The caller
	            forms the magnetic force q_i (v_i × B_i). Inputs are length n; outputs bx, by, bz are
	            filled by the call.
*/
void FxGripFMMEvaluateBiotSavart(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
								 uint32_t n,
								 const float *x, const float *y, const float *z, const float *strength,
								 const float *vx, const float *vy, const float *vz,
								 float *bx, float *by, float *bz);

/*!
	@typedef    FxGripFMMField
	@abstract   A built source field that can be evaluated at arbitrary target points.
	@discussion Introduced in FxGrip 0.1.0. `FxGripFMMEvaluateField` evaluates the field at the source
	            points themselves. A physics field, by contrast, is asked for the force at one target at
	            a time, so it needs the source expansion built once and then queried per point. This
	            handle holds the tree, the multipole expansions, and the local expansions of a set of
	            sources; evaluate it at any point, in any order.

	            The build runs the same dual-tree traversal as the batch evaluator, so every leaf ends
	            up with the local expansion of the whole far field and a list of the near leaves the
	            multipole could not cover. A query is then one local evaluation plus that leaf's near
	            sum, at the same accuracy as the batch evaluator. A point outside the tree, or in an
	            octant that holds no sources, falls back to a walk from the root.
*/
typedef struct FxGripFMMField FxGripFMMField;

/*! @abstract Builds the source field: the tree and multipole expansions of the given sources. Returns
	NULL for n = 0, a NULL context, or allocation failure. Free with FxGripFMMFieldDestroy. */
FxGripFMMField *FxGripFMMFieldBuild(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
									uint32_t n, const float *x, const float *y, const float *z, const float *strength);

/*!
	@function   FxGripFMMFieldBuildChannels
	@abstract   Builds one source field carrying several independent strength channels.
	@param      context       The context whose scratch memory and expansion tables the build uses.
	@param      parameters    The accuracy and layout knobs; NULL takes the defaults.
	@param      n             The number of sources.
	@param      x             The source x coordinates, length n.
	@param      y             The source y coordinates, length n.
	@param      z             The source z coordinates, length n.
	@param      strengths     An array of `channelCount` pointers, each to `n` source strengths.
	@param      channelCount  The number of strength channels, at least 1.
	@result     A built field, or NULL for n = 0, a NULL argument, or allocation failure.
	@discussion Introduced in FxGrip 0.1.0. Several fields over the same source positions share one
	            tree and one traversal: the positions decide the tree, and only the strengths differ.
	            The magnetic force needs the curl of a vector potential, which is three channels over
	            the velocity-weighted charge, and it costs one tree rather than three. Sharing saves the
	            tree and the traversal; the expansion work still scales with the channel count.
	            Evaluate with `FxGripFMMFieldEvaluateChannelsAt`.
*/
FxGripFMMField *FxGripFMMFieldBuildChannels(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
											uint32_t n, const float *x, const float *y, const float *z,
											const float *const *strengths, uint32_t channelCount);

/*! @abstract The number of strength channels a built field carries. */
uint32_t FxGripFMMFieldChannelCount(const FxGripFMMField *field);

/*! @abstract Evaluates the softened Laplace field at one target point, overwriting (ex, ey, ez). */
void FxGripFMMFieldEvaluateAt(const FxGripFMMField *field, float tx, float ty, float tz,
							  float *ex, float *ey, float *ez);

/*!
	@function   FxGripFMMFieldEvaluateChannelsAt
	@abstract   Evaluates every channel of a built field at one target point in a single tree walk.
	@discussion Introduced in FxGrip 0.1.0. `ex`, `ey`, and `ez` are arrays of `FxGripFMMFieldChannelCount`
	            elements, overwritten by the call. The acceptance test depends only on the positions, so
	            one walk serves every channel.
*/
void FxGripFMMFieldEvaluateChannelsAt(const FxGripFMMField *field, float tx, float ty, float tz,
									  float *ex, float *ey, float *ez);

/*! @abstract Frees a built field. NULL is ignored. */
void FxGripFMMFieldDestroy(FxGripFMMField *field);

/*! @abstract The direct O(N²) reference for FxGripFMMEvaluateField, for tests. */
void FxGripFMMEvaluateFieldDirect(uint32_t n, float softening,
								  const float *x, const float *y, const float *z, const float *strength,
								  float *ex, float *ey, float *ez);

/*! @abstract The direct O(N²) reference for FxGripFMMEvaluateBiotSavart, for tests. */
void FxGripFMMEvaluateBiotSavartDirect(uint32_t n, float softening,
									   const float *x, const float *y, const float *z, const float *strength,
									   const float *vx, const float *vy, const float *vz,
									   float *bx, float *by, float *bz);

#ifdef __cplusplus
}
#endif

#endif /* FxGripFMM_h */
