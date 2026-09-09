/*!
	@file       FxGripFMMTreeTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMTreeTests
	@abstract   Tests for the adaptive octree the FMM builds each step.
	@discussion Introduced in FxGrip 0.1.0. The tests confirm the Morton key is monotone per axis, the
	            radix sort is stable with an original-index tiebreak, the leaves partition the bodies
	            and respect the capacity, every cell holds at least one body, and each body lies inside
	            its leaf cube. Degenerate inputs build without error. The tree is a private core
	            component, so its header is imported by path rather than through the framework umbrella.
*/

#import <XCTest/XCTest.h>
#import "../../FxGrip/Space/FxGripFMMTree.h"

@interface FxGripFMMTreeTests : XCTestCase
@end

@implementation FxGripFMMTreeTests

#pragma mark Morton key

/*! @abstract Increasing one axis with the others fixed produces strictly increasing keys. */
- (void)testMortonMonotonePerAxis
{
	uint64_t prevX = 0, prevY = 0, prevZ = 0;
	for (uint32_t c = 1; c < 2048; c++) {
		uint64_t kx = FxGripFMMMortonEncode(c, 0, 0);
		uint64_t ky = FxGripFMMMortonEncode(0, c, 0);
		uint64_t kz = FxGripFMMMortonEncode(0, 0, c);
		XCTAssertGreaterThan(kx, prevX);
		XCTAssertGreaterThan(ky, prevY);
		XCTAssertGreaterThan(kz, prevZ);
		prevX = kx; prevY = ky; prevZ = kz;
	}
}

/*! @abstract The three axes occupy disjoint bit lanes, so their keys never share a set bit. */
- (void)testMortonAxesAreDisjointLanes
{
	uint64_t kx = FxGripFMMMortonEncode(0x1fffff, 0, 0);
	uint64_t ky = FxGripFMMMortonEncode(0, 0x1fffff, 0);
	uint64_t kz = FxGripFMMMortonEncode(0, 0, 0x1fffff);
	XCTAssertEqual(kx & ky, 0ull);
	XCTAssertEqual(kx & kz, 0ull);
	XCTAssertEqual(ky & kz, 0ull);
	XCTAssertEqual(kx | ky | kz, FxGripFMMMortonEncode(0x1fffff, 0x1fffff, 0x1fffff));
}

#pragma mark Partition and capacity

- (void)assertTree:(FxGripFMMTree *)tree partitionsBodies:(uint32_t)n
{
	XCTAssertTrue(tree != NULL);
	// The order is a permutation of 0..n-1.
	uint32_t *seen = calloc(n, sizeof(uint32_t));
	for (uint32_t i = 0; i < n; i++) {
		XCTAssertLessThan(tree->order[i], n);
		seen[tree->order[i]] += 1;
	}
	for (uint32_t i = 0; i < n; i++) {
		XCTAssertEqual(seen[i], 1u, @"body %u appears once", i);
	}
	free(seen);

	// Leaves partition the sorted range and every cell is non-empty.
	uint32_t leafSum = 0;
	for (uint32_t c = 0; c < tree->cellCount; c++) {
		FxGripFMMCell cell = tree->cells[c];
		XCTAssertGreaterThanOrEqual(cell.bodyCount, 1u, @"no empty cells");
		if (cell.childCount == 0) {
			leafSum += cell.bodyCount;
			if (cell.level < tree->maxDepth) {
				XCTAssertLessThanOrEqual(cell.bodyCount, tree->leafCapacity,
										 @"a leaf below max depth respects the capacity");
			}
		}
	}
	XCTAssertEqual(leafSum, n, @"the leaves cover every body exactly once");
}

- (void)assertTree:(FxGripFMMTree *)tree containsBodiesX:(const float *)x y:(const float *)y z:(const float *)z
{
	const float tol = tree->boxSize * 1e-4f + 1e-5f;
	for (uint32_t c = 0; c < tree->cellCount; c++) {
		FxGripFMMCell cell = tree->cells[c];
		if (cell.childCount != 0) {
			continue;
		}
		for (uint32_t k = cell.firstBody; k < cell.firstBody + cell.bodyCount; k++) {
			uint32_t b = tree->order[k];
			XCTAssertLessThanOrEqual(fabsf(x[b] - cell.centerX), cell.radius + tol);
			XCTAssertLessThanOrEqual(fabsf(y[b] - cell.centerY), cell.radius + tol);
			XCTAssertLessThanOrEqual(fabsf(z[b] - cell.centerZ), cell.radius + tol);
		}
	}
}

/*! @abstract A uniform cloud partitions into capacity-respecting leaves, each body inside its cube. */
- (void)testUniformCloudPartitionsAndContains
{
	const uint32_t n = 4000;
	float *x = malloc(sizeof(float) * n), *y = malloc(sizeof(float) * n), *z = malloc(sizeof(float) * n);
	uint32_t state = 20260908u;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u; x[i] = (float)(state >> 8) / 16777216.0f;
		state = state * 1664525u + 1013904223u; y[i] = (float)(state >> 8) / 16777216.0f;
		state = state * 1664525u + 1013904223u; z[i] = (float)(state >> 8) / 16777216.0f;
	}
	FxGripFMMTree *tree = FxGripFMMTreeBuild(n, x, y, z, 64, FXGRIP_FMM_MAX_DEPTH);
	[self assertTree:tree partitionsBodies:n];
	[self assertTree:tree containsBodiesX:x y:y z:z];
	XCTAssertLessThanOrEqual(tree->cellCount, 8u * n, @"cell count stays linear in the bodies");
	FxGripFMMTreeFree(tree);
	free(x); free(y); free(z);
}

/*! @abstract Two tight clusters far apart produce only non-empty cells and reach several levels deep. */
- (void)testTwoBlobsMakeDeepCellsOnlyWhereBodiesAre
{
	const uint32_t perBlob = 1000, n = perBlob * 2;
	float *x = malloc(sizeof(float) * n), *y = malloc(sizeof(float) * n), *z = malloc(sizeof(float) * n);
	uint32_t state = 77u;
	for (uint32_t i = 0; i < n; i++) {
		float cx = (i < perBlob) ? 0.0f : 100.0f;
		state = state * 1664525u + 1013904223u; x[i] = cx + (float)(state >> 8) / 16777216.0f;
		state = state * 1664525u + 1013904223u; y[i] = (float)(state >> 8) / 16777216.0f;
		state = state * 1664525u + 1013904223u; z[i] = (float)(state >> 8) / 16777216.0f;
	}
	FxGripFMMTree *tree = FxGripFMMTreeBuild(n, x, y, z, 32, FXGRIP_FMM_MAX_DEPTH);
	[self assertTree:tree partitionsBodies:n];
	[self assertTree:tree containsBodiesX:x y:y z:z];
	uint32_t maxLevel = 0;
	for (uint32_t c = 0; c < tree->cellCount; c++) {
		maxLevel = tree->cells[c].level > maxLevel ? tree->cells[c].level : maxLevel;
	}
	XCTAssertGreaterThan(maxLevel, 1u, @"clusters force subdivision below the root");
	FxGripFMMTreeFree(tree);
	free(x); free(y); free(z);
}

#pragma mark Stability and degenerate inputs

/*! @abstract Coincident bodies keep their original-index order after the stable sort. */
- (void)testCoincidentBodiesKeepOriginalOrder
{
	const uint32_t n = 16;
	float x[16], y[16], z[16];
	for (uint32_t i = 0; i < n; i++) { x[i] = 3.0f; y[i] = -2.0f; z[i] = 5.0f; }
	FxGripFMMTree *tree = FxGripFMMTreeBuild(n, x, y, z, 4, FXGRIP_FMM_MAX_DEPTH);
	XCTAssertTrue(tree != NULL);
	for (uint32_t i = 0; i < n; i++) {
		XCTAssertEqual(tree->order[i], i, @"equal keys preserve input order");
	}
	// All in one octant path, so the deepest leaf holds them all at max depth.
	uint32_t leafBodies = 0;
	for (uint32_t c = 0; c < tree->cellCount; c++) {
		if (tree->cells[c].childCount == 0) { leafBodies += tree->cells[c].bodyCount; }
	}
	XCTAssertEqual(leafBodies, n);
	FxGripFMMTreeFree(tree);
}

/*! @abstract Building is deterministic: the same input yields identical order and cell counts. */
- (void)testBuildIsDeterministic
{
	const uint32_t n = 500;
	float *x = malloc(sizeof(float) * n), *y = malloc(sizeof(float) * n), *z = malloc(sizeof(float) * n);
	uint32_t state = 5u;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u; x[i] = (float)(state >> 8) / 16777216.0f;
		state = state * 1664525u + 1013904223u; y[i] = (float)(state >> 8) / 16777216.0f;
		state = state * 1664525u + 1013904223u; z[i] = (float)(state >> 8) / 16777216.0f;
	}
	FxGripFMMTree *a = FxGripFMMTreeBuild(n, x, y, z, 16, FXGRIP_FMM_MAX_DEPTH);
	FxGripFMMTree *b = FxGripFMMTreeBuild(n, x, y, z, 16, FXGRIP_FMM_MAX_DEPTH);
	XCTAssertEqual(a->cellCount, b->cellCount);
	for (uint32_t i = 0; i < n; i++) { XCTAssertEqual(a->order[i], b->order[i]); }
	FxGripFMMTreeFree(a);
	FxGripFMMTreeFree(b);
	free(x); free(y); free(z);
}

/*! @abstract One, two, and zero bodies build without error. */
- (void)testTinyAndEmptyInputs
{
	float x1[1] = {1.0f}, y1[1] = {2.0f}, z1[1] = {3.0f};
	FxGripFMMTree *one = FxGripFMMTreeBuild(1, x1, y1, z1, 64, FXGRIP_FMM_MAX_DEPTH);
	XCTAssertTrue(one != NULL);
	XCTAssertEqual(one->cellCount, 1u);
	XCTAssertEqual(one->cells[0].bodyCount, 1u);
	XCTAssertEqual(one->cells[0].childCount, 0u);
	FxGripFMMTreeFree(one);

	float x2[2] = {0.0f, 1.0f}, y2[2] = {0.0f, 1.0f}, z2[2] = {0.0f, 1.0f};
	FxGripFMMTree *two = FxGripFMMTreeBuild(2, x2, y2, z2, 1, FXGRIP_FMM_MAX_DEPTH);
	[self assertTree:two partitionsBodies:2];
	[self assertTree:two containsBodiesX:x2 y:y2 z:z2];
	FxGripFMMTreeFree(two);

	XCTAssertTrue(FxGripFMMTreeBuild(0, x2, y2, z2, 64, FXGRIP_FMM_MAX_DEPTH) == NULL);
}

@end
