/*!
	@file       FxGripFMMTree.h
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMTree
	@abstract   The adaptive octree the Fast Multipole Method builds over the particles each step.
	@discussion Introduced in FxGrip 0.1.0. This is a private core header, not part of the framework
	            API. It quantizes the particles to 21-bit-per-axis Morton keys, sorts them with a
	            stable radix sort, and builds an adaptive octree in breadth-first order so a cell's
	            children are contiguous and each level is a contiguous run. A cell subdivides when it
	            holds more than the leaf capacity and its level is below the maximum depth. Empty
	            octants create no cell, so every cell holds at least one body and the leaves partition
	            the particles.

	            The build is a pure function of the input positions: the key order, the sort (stable,
	            with an original-index tiebreak), and the traversal are deterministic, which the method
	            relies on for reproducible results.
*/

#ifndef FxGripFMMTree_h
#define FxGripFMMTree_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*! The number of Morton bits per axis, and the resulting maximum octree depth. Twenty-one bits pack
	a three-axis key into a 63-bit word, so the tree resolves the domain to 2^21 cells per axis. That
	depth keeps the leaves small under the clustering that a mutual-attraction force produces, where a
	shallower key would bottom out and leave an oversized leaf with an O(m²) near field. Ten bits in a
	32-bit word is a compile-time alternative for a uniform distribution. */
#define FXGRIP_FMM_MORTON_BITS 21
#define FXGRIP_FMM_MAX_DEPTH   FXGRIP_FMM_MORTON_BITS

/*! The Morton key type. A 63-bit key fits a 64-bit word; a 30-bit key fits a 32-bit word. */
typedef uint64_t FxGripFMMKey;

/*!
	@struct     FxGripFMMCell
	@abstract   One node of the octree.
	@field      firstBody   Index into the sorted body arrays of this cell's first body.
	@field      bodyCount   Number of bodies in this cell.
	@field      firstChild  Index into the cell array of this cell's first child; valid when childCount > 0.
	@field      childCount  Number of children; 0 marks a leaf.
	@field      level       Depth from the root, which is level 0.
	@field      centerX/Y/Z Center of the cell's cube in world space.
	@field      radius      Half-width of the cell's cube.
*/
typedef struct FxGripFMMCell {
	uint32_t firstBody;
	uint32_t bodyCount;
	uint32_t firstChild;
	uint32_t childCount;
	uint32_t level;
	float    centerX;
	float    centerY;
	float    centerZ;
	float    radius;
} FxGripFMMCell;

/*!
	@struct     FxGripFMMTree
	@abstract   A built octree with its sorted body order.
	@field      bodyCount   Number of bodies.
	@field      order       Permutation from sorted position to original body index, length bodyCount.
	@field      sortedKeys  Morton key of each body in sorted order, length bodyCount.
	@field      cells       Cell array in breadth-first order; the root is cells[0].
	@field      cellCount   Number of cells.
	@field      leafCapacity, maxDepth  The build parameters used.
	@field      boxMinX/Y/Z, boxSize    The bounding cube: min corner and edge length.
*/
typedef struct FxGripFMMTree {
	uint32_t       bodyCount;
	uint32_t      *order;
	FxGripFMMKey  *sortedKeys;
	FxGripFMMCell *cells;
	uint32_t       cellCount;
	uint32_t       leafCapacity;
	uint32_t       maxDepth;
	float          boxMinX;
	float          boxMinY;
	float          boxMinZ;
	float          boxSize;
	int            ownsMemory;    // 1 when order/sortedKeys/cells were malloc'd by FxGripFMMTreeBuild
} FxGripFMMTree;

/*! @abstract Interleaves three coordinates of FXGRIP_FMM_MORTON_BITS bits into a Morton key (x in the
	low bit of each triple). */
FxGripFMMKey FxGripFMMMortonEncode(uint32_t x, uint32_t y, uint32_t z);

/*!
	@function   FxGripFMMTreeBuild
	@abstract   Builds the adaptive octree over the given positions.
	@param      n             Number of bodies.
	@param      x             Body x coordinates, length n.
	@param      y             Body y coordinates, length n.
	@param      z             Body z coordinates, length n.
	@param      leafCapacity  Bodies above which a cell subdivides; clamped to at least 1.
	@param      maxDepth      Maximum depth; clamped to FXGRIP_FMM_MAX_DEPTH.
	@result     A heap-allocated tree, or NULL for n = 0 or allocation failure. Free with
	            FxGripFMMTreeFree.
*/
FxGripFMMTree *FxGripFMMTreeBuild(uint32_t n, const float *x, const float *y, const float *z,
								  uint32_t leafCapacity, uint32_t maxDepth);

/*!
	@function   FxGripFMMTreeBuildInto
	@abstract   Builds the tree into caller-provided buffers, for an arena that reuses memory.
	@discussion Introduced in FxGrip 0.1.0. `order`, `sortedKeys`, `keys`, and `idxScratch` must each
	            hold at least n entries; `keys` and `idxScratch` are scratch. `cells`/`cellsCapacity`
	            is a growable cell buffer, reallocated only when the build needs more cells than it
	            holds; `allocationEvents` is incremented on each such growth so a caller can detect a
	            reuse miss. Fills `tree` (pointers, counts, box) with ownsMemory left 0. Returns 1 on
	            success, 0 on allocation failure.
*/
int FxGripFMMTreeBuildInto(FxGripFMMTree *tree, uint32_t n, const float *x, const float *y, const float *z,
						   uint32_t leafCapacity, uint32_t maxDepth,
						   uint32_t *order, FxGripFMMKey *sortedKeys, FxGripFMMKey *keys, uint32_t *idxScratch,
						   FxGripFMMCell **cells, uint32_t *cellsCapacity, uint64_t *allocationEvents);

/*! @abstract Frees a tree and its arrays. NULL is ignored. Arrays are freed only when ownsMemory is set. */
void FxGripFMMTreeFree(FxGripFMMTree *tree);

#ifdef __cplusplus
}
#endif

#endif /* FxGripFMMTree_h */
