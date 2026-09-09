/*!
	@file       FxGripFMMExpansion.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMExpansion
	@abstract   The Cartesian multipole machinery of the Fast Multipole Method.
	@discussion Introduced in FxGrip 0.1.0. A private core header, not part of the framework API. The
	            far field is a Taylor expansion of the Laplace potential φ(t) = Σ_j s_j / |t − r_j| in
	            Cartesian multi-indices. The single primitive everything rests on is the set of
	            Cartesian derivatives of 1/r up to a given order, which this module builds once by
	            symbolic differentiation and evaluates at a vector.

	            The potential and its multipole form:
	              M_α = Σ_j s_j (r_j − c)^α / α!                                   (P2M)
	              φ(t) = Σ_{|α|≤P} (−1)^{|α|} M_α (D^α g)(t − c),   g = 1/r
	            and the field is the gradient, E(t) = ∇φ(t), so
	              E_i(t) = Σ_{|α|≤P} (−1)^{|α|} M_α (D^{α+e_i} g)(t − c).           (M2P)

	            Moments run to order P; the field evaluation needs derivatives to order P+1. Later
	            translation operators (M2M, M2L, L2L, L2P) reuse the same derivative tensor and
	            multi-index tables.
*/

#ifndef FxGripFMMExpansion_h
#define FxGripFMMExpansion_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*! The number of Cartesian multi-indices with |α| ≤ order: (order+1)(order+2)(order+3)/6. */
uint32_t FxGripFMMTermCount(uint32_t order);

/*!
	@typedef    FxGripFMMExpansionTables
	@abstract   Read-only tables for a fixed moment order: multi-index lists, inverse factorials, and
	            the symbolic derivative terms of 1/r.
	@discussion Introduced in FxGrip 0.1.0. Built once and shared read-only, so it is safe to use from
	            several threads at once.
*/
typedef struct FxGripFMMExpansionTables FxGripFMMExpansionTables;

/*! @abstract Builds the tables for moment order P (the field uses derivatives to order P+1). */
FxGripFMMExpansionTables *FxGripFMMExpansionTablesCreate(uint32_t order);

/*! @abstract Frees the tables. NULL is ignored. */
void FxGripFMMExpansionTablesDestroy(FxGripFMMExpansionTables *tables);

/*! @abstract The moment order P the tables were built for. */
uint32_t FxGripFMMExpansionOrder(const FxGripFMMExpansionTables *tables);

/*! @abstract The number of moment coefficients, FxGripFMMTermCount(P). */
uint32_t FxGripFMMExpansionMomentCount(const FxGripFMMExpansionTables *tables);

/*! @abstract The number of derivative coefficients, FxGripFMMTermCount(2P), which is the length an
	FxGripFMMEvalDerivatives output buffer needs. */
uint32_t FxGripFMMExpansionDerivativeCount(const FxGripFMMExpansionTables *tables);

/*!
	@function   FxGripFMMP2M
	@abstract   Accumulates the multipole moments of a source range about a center.
	@discussion Introduced in FxGrip 0.1.0. Adds s_j (r_j − c)^α / α! into moments[α] for every source.
	            Moments are accumulated, so several ranges may contribute to one expansion.
	@param      moments  Output array of length FxGripFMMExpansionMomentCount, added into.
*/
void FxGripFMMP2M(const FxGripFMMExpansionTables *tables,
				  float cx, float cy, float cz,
				  const float *sx, const float *sy, const float *sz, const float *ss, uint32_t ns,
				  float *moments);

/*!
	@function   FxGripFMMM2PField
	@abstract   Evaluates the field of a multipole expansion at target points, accumulating.
	@discussion Introduced in FxGrip 0.1.0. Adds E_i(t) = Σ_α (−1)^{|α|} moments[α] (D^{α+e_i} g)(t − c)
	            into (ex, ey, ez) for each target. Valid where the target is outside the expansion's
	            cluster, so t ≠ c.
*/
void FxGripFMMM2PField(const FxGripFMMExpansionTables *tables,
					   float cx, float cy, float cz, const float *moments,
					   const float *tx, const float *ty, const float *tz,
					   float *ex, float *ey, float *ez, uint32_t nt);

/*!
	@function   FxGripFMMEvalDerivatives
	@abstract   Fills the Cartesian derivatives of 1/r up to the table's derivative order at a vector.
	@discussion Introduced in FxGrip 0.1.0. For testing and for the translation operators. `out` has
	            length FxGripFMMExpansionDerivativeCount, and is indexed by the same multi-index order
	            the moments use, extended to the derivative order. Requires (ux, uy, uz) ≠ 0.
*/
void FxGripFMMEvalDerivatives(const FxGripFMMExpansionTables *tables,
							  float ux, float uy, float uz, float *out);

/*! @abstract The derivative-table index of a multi-index (a, b, c), or -1 if |a+b+c| exceeds 2P. */
int32_t FxGripFMMDerivativeIndex(const FxGripFMMExpansionTables *tables, uint32_t a, uint32_t b, uint32_t c);

/*!
	@function   FxGripFMMM2M
	@abstract   Translates a child's multipole moments to a parent center, accumulating.
	@discussion Introduced in FxGrip 0.1.0. Adds Σ_{γ≤α} child[γ] (c_c − c_p)^{α−γ} / (α−γ)! into
	            parent[α], so several children shift into one parent expansion.
*/
void FxGripFMMM2M(const FxGripFMMExpansionTables *tables,
				  float ccx, float ccy, float ccz, const float *childMoments,
				  float cpx, float cpy, float cpz, float *parentMoments);

/*!
	@function   FxGripFMMM2L
	@abstract   Converts a multipole expansion to a local expansion about a target center, accumulating.
	@discussion Introduced in FxGrip 0.1.0. Adds (1/β!) Σ_α (−1)^{|α|} moments[α] (D^{α+β} g)(c_L − c_M)
	            into local[β]. Valid where the source and target cells are well separated, so
	            c_L ≠ c_M.
*/
void FxGripFMMM2L(const FxGripFMMExpansionTables *tables,
				  float cmx, float cmy, float cmz, const float *moments,
				  float clx, float cly, float clz, float *local);

/*!
	@function   FxGripFMML2L
	@abstract   Translates a parent local expansion to a child center, accumulating.
	@discussion Introduced in FxGrip 0.1.0. Adds Σ_{β≥δ} parent[β] C(β,δ) (c_c − c_p)^{β−δ} into
	            child[δ].
*/
void FxGripFMML2L(const FxGripFMMExpansionTables *tables,
				  float cpx, float cpy, float cpz, const float *parentLocal,
				  float ccx, float ccy, float ccz, float *childLocal);

/*!
	@function   FxGripFMML2PField
	@abstract   Evaluates the field of a local expansion at target points, accumulating.
	@discussion Introduced in FxGrip 0.1.0. Adds E_i(t) = Σ_β local[β] β_i (t − c_L)^{β−e_i} into
	            (ex, ey, ez) for each target.
*/
void FxGripFMML2PField(const FxGripFMMExpansionTables *tables,
					   float clx, float cly, float clz, const float *local,
					   const float *tx, const float *ty, const float *tz,
					   float *ex, float *ey, float *ez, uint32_t nt);

#ifdef __cplusplus
}
#endif

#endif /* FxGripFMMExpansion_h */
