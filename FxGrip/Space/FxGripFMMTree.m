/*!
	@file       FxGripFMMTree.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMTree
	@abstract   Implements the Morton key, the stable radix sort, and the breadth-first octree build.
	@discussion Introduced in FxGrip 0.1.0. The bounding cube fixes a common edge length so every axis
	            shares one quantization. The tree grows breadth-first by a fused most-significant-digit
	            build: each subdividing cell partitions its body range by that level's three-bit octant
	            with a stable counting sort, then appends its non-empty octant children as one
	            contiguous run. A branch touches only the bits down to its own depth, so the work is
	            adaptive to the depth each region needs, children are contiguous, and the array is in
	            level order. The partition keeps equal keys in arrival order, so the build is a pure,
	            deterministic function of the input positions.
*/

#include "FxGripFMMTree.h"
#include <stdlib.h>
#include <string.h>

#pragma mark Morton key

// Spreads twenty-one low bits across every third bit of a 64-bit word: bit k moves to bit 3k.
static uint64_t FxGripFMMPart1By2(uint64_t n)
{
	n &= 0x1fffffull;
	n = (n | (n << 32)) & 0x1f00000000ffffull;
	n = (n | (n << 16)) & 0x1f0000ff0000ffull;
	n = (n | (n <<  8)) & 0x100f00f00f00f00full;
	n = (n | (n <<  4)) & 0x10c30c30c30c30c3ull;
	n = (n | (n <<  2)) & 0x1249249249249249ull;
	return n;
}

FxGripFMMKey FxGripFMMMortonEncode(uint32_t x, uint32_t y, uint32_t z)
{
	return FxGripFMMPart1By2(x) | (FxGripFMMPart1By2(y) << 1) | (FxGripFMMPart1By2(z) << 2);
}

// The octant of a key at a given level: three bits, x in the low bit, most significant level first.
static inline uint32_t FxGripFMMOctant(FxGripFMMKey key, uint32_t level)
{
	const uint32_t shift = 3u * (FXGRIP_FMM_MORTON_BITS - 1u - level);
	return (key >> shift) & 7u;
}

#pragma mark Cell array growth

static int FxGripFMMEnsureCellCapacity(FxGripFMMCell **cells, uint32_t *capacity, uint32_t needed,
									   uint64_t *allocationEvents)
{
	if (needed <= *capacity) {
		return 1;
	}
	uint32_t newCapacity = (*capacity == 0) ? 64u : *capacity;
	while (newCapacity < needed) {
		newCapacity *= 2u;
	}
	FxGripFMMCell *grown = (FxGripFMMCell *)realloc(*cells, sizeof(FxGripFMMCell) * newCapacity);
	if (grown == NULL) {
		return 0;
	}
	*cells = grown;
	*capacity = newCapacity;
	if (allocationEvents != NULL) {
		*allocationEvents += 1;
	}
	return 1;
}

#pragma mark Build

int FxGripFMMTreeBuildInto(FxGripFMMTree *tree, uint32_t n, const float *x, const float *y, const float *z,
						   uint32_t leafCapacity, uint32_t maxDepth,
						   uint32_t *order, FxGripFMMKey *sortedKeys, FxGripFMMKey *keys, uint32_t *scratch,
						   FxGripFMMCell **cells, uint32_t *capacity, uint64_t *allocationEvents)
{
	if (n == 0 || x == NULL || y == NULL || z == NULL) {
		return 0;
	}
	if (leafCapacity < 1u) {
		leafCapacity = 1u;
	}
	if (maxDepth > FXGRIP_FMM_MAX_DEPTH) {
		maxDepth = FXGRIP_FMM_MAX_DEPTH;
	}
	tree->bodyCount = n;
	tree->leafCapacity = leafCapacity;
	tree->maxDepth = maxDepth;
	tree->order = order;
	tree->sortedKeys = sortedKeys;
	tree->ownsMemory = 0;

	// Bounding cube: min per axis, one shared edge length so the domain is a cube.
	float minX = x[0], minY = y[0], minZ = z[0];
	float maxX = x[0], maxY = y[0], maxZ = z[0];
	for (uint32_t i = 1; i < n; i++) {
		minX = x[i] < minX ? x[i] : minX; maxX = x[i] > maxX ? x[i] : maxX;
		minY = y[i] < minY ? y[i] : minY; maxY = y[i] > maxY ? y[i] : maxY;
		minZ = z[i] < minZ ? z[i] : minZ; maxZ = z[i] > maxZ ? z[i] : maxZ;
	}
	float size = maxX - minX;
	if (maxY - minY > size) { size = maxY - minY; }
	if (maxZ - minZ > size) { size = maxZ - minZ; }
	if (!(size > 0.0f)) {
		size = 1.0f; // all coincident, or a single body
	}
	tree->boxMinX = minX; tree->boxMinY = minY; tree->boxMinZ = minZ; tree->boxSize = size;

	const float scale = (float)(1u << FXGRIP_FMM_MORTON_BITS) / size;
	const uint32_t maxCoord = (1u << FXGRIP_FMM_MORTON_BITS) - 1u;
	for (uint32_t i = 0; i < n; i++) {
		int32_t qx = (int32_t)((x[i] - minX) * scale);
		int32_t qy = (int32_t)((y[i] - minY) * scale);
		int32_t qz = (int32_t)((z[i] - minZ) * scale);
		if (qx < 0) { qx = 0; } else if ((uint32_t)qx > maxCoord) { qx = (int32_t)maxCoord; }
		if (qy < 0) { qy = 0; } else if ((uint32_t)qy > maxCoord) { qy = (int32_t)maxCoord; }
		if (qz < 0) { qz = 0; } else if ((uint32_t)qz > maxCoord) { qz = (int32_t)maxCoord; }
		keys[i] = FxGripFMMMortonEncode((uint32_t)qx, (uint32_t)qy, (uint32_t)qz);
		order[i] = i;
	}

	// Breadth-first, most-significant-digit build over the cell array itself: process head, partition
	// its range by the level's octant, append children at the tail.
	uint32_t count = 0;
	if (!FxGripFMMEnsureCellCapacity(cells, capacity, 1u, allocationEvents)) {
		return 0;
	}
	FxGripFMMCell *cellArray = *cells;
	const float half = size * 0.5f;
	cellArray[0].firstBody = 0;
	cellArray[0].bodyCount = n;
	cellArray[0].firstChild = 0;
	cellArray[0].childCount = 0;
	cellArray[0].level = 0;
	cellArray[0].centerX = minX + half;
	cellArray[0].centerY = minY + half;
	cellArray[0].centerZ = minZ + half;
	cellArray[0].radius = half;
	count = 1;

	for (uint32_t head = 0; head < count; head++) {
		const uint32_t lo = cellArray[head].firstBody;
		const uint32_t hi = lo + cellArray[head].bodyCount;
		const uint32_t level = cellArray[head].level;
		if (cellArray[head].bodyCount <= leafCapacity || level >= maxDepth) {
			continue; // leaf
		}
		const float cx = cellArray[head].centerX, cy = cellArray[head].centerY, cz = cellArray[head].centerZ;
		const float childRadius = cellArray[head].radius * 0.5f;

		// Stable counting sort of this range by the level's octant: tally, place into scratch in
		// ascending octant order preserving arrival order, then copy back.
		uint32_t octantCount[8] = {0, 0, 0, 0, 0, 0, 0, 0};
		for (uint32_t k = lo; k < hi; k++) {
			octantCount[FxGripFMMOctant(keys[order[k]], level)] += 1;
		}
		uint32_t place[8];
		uint32_t running = lo;
		for (uint32_t o = 0; o < 8u; o++) {
			place[o] = running;
			running += octantCount[o];
		}
		for (uint32_t k = lo; k < hi; k++) {
			const uint32_t o = FxGripFMMOctant(keys[order[k]], level);
			scratch[place[o]++] = order[k];
		}
		memcpy(order + lo, scratch + lo, sizeof(uint32_t) * (hi - lo));

		const uint32_t firstChild = count;
		uint32_t childCount = 0;
		uint32_t childStart = lo;
		for (uint32_t o = 0; o < 8u; o++) {
			if (octantCount[o] == 0) {
				continue;
			}
			if (!FxGripFMMEnsureCellCapacity(cells, capacity, count + 1u, allocationEvents)) {
				return 0;
			}
			cellArray = *cells; // may have moved on growth
			cellArray[count].firstBody = childStart;
			cellArray[count].bodyCount = octantCount[o];
			cellArray[count].firstChild = 0;
			cellArray[count].childCount = 0;
			cellArray[count].level = level + 1u;
			cellArray[count].centerX = cx + ((o & 1u) ? childRadius : -childRadius);
			cellArray[count].centerY = cy + ((o & 2u) ? childRadius : -childRadius);
			cellArray[count].centerZ = cz + ((o & 4u) ? childRadius : -childRadius);
			cellArray[count].radius = childRadius;
			count++;
			childCount++;
			childStart += octantCount[o];
		}
		cellArray = *cells;
		cellArray[head].firstChild = firstChild;
		cellArray[head].childCount = childCount;
	}

	for (uint32_t i = 0; i < n; i++) {
		sortedKeys[i] = keys[order[i]];
	}

	tree->cells = *cells;
	tree->cellCount = count;
	return 1;
}

FxGripFMMTree *FxGripFMMTreeBuild(uint32_t n, const float *x, const float *y, const float *z,
								  uint32_t leafCapacity, uint32_t maxDepth)
{
	if (n == 0 || x == NULL || y == NULL || z == NULL) {
		return NULL;
	}
	FxGripFMMTree *tree = (FxGripFMMTree *)calloc(1, sizeof(FxGripFMMTree));
	uint32_t *order = (uint32_t *)malloc(sizeof(uint32_t) * n);
	FxGripFMMKey *sortedKeys = (FxGripFMMKey *)malloc(sizeof(FxGripFMMKey) * n);
	FxGripFMMKey *keys = (FxGripFMMKey *)malloc(sizeof(FxGripFMMKey) * n);
	uint32_t *scratch = (uint32_t *)malloc(sizeof(uint32_t) * n);
	FxGripFMMCell *cells = NULL;
	uint32_t capacity = 0;
	if (tree == NULL || order == NULL || sortedKeys == NULL || keys == NULL || scratch == NULL ||
		!FxGripFMMTreeBuildInto(tree, n, x, y, z, leafCapacity, maxDepth, order, sortedKeys, keys, scratch,
								&cells, &capacity, NULL)) {
		free(order); free(sortedKeys); free(cells); free(tree);
		free(keys); free(scratch);
		return NULL;
	}
	free(keys);
	free(scratch);
	tree->ownsMemory = 1; // owns order, sortedKeys, and cells
	return tree;
}

void FxGripFMMTreeFree(FxGripFMMTree *tree)
{
	if (tree == NULL) {
		return;
	}
	if (tree->ownsMemory) {
		free(tree->order);
		free(tree->sortedKeys);
		free(tree->cells);
	}
	free(tree);
}
