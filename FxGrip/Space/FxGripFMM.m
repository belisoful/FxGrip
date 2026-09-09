/*!
	@file       FxGripFMM.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMM
	@abstract   Implements the inter-particle field core and its direct references.
	@discussion Introduced in FxGrip 0.1.0. This file holds the default parameters, the reusable
	            context, the direct O(N²) reference evaluators, and the adaptive O(N) scalar field. The
	            scalar evaluator builds the octree, runs the upward pass (P2M, M2M), a dual-tree
	            traversal that sends far pairs to local expansions (M2L) and near pairs to the exact
	            kernel (P2P), and the downward pass (L2L, L2P), then scatters the field back to input
	            order. Small sets fall back to the direct sum. The Biot-Savart evaluator reuses the
	            scalar field: the magnetic field is the curl of a vector potential whose three
	            components are Laplace potentials of the velocity components, so three scalar runs and a
	            curl assembly give it in O(N) as well.
*/

#include "FxGripFMM.h"
#include "FxGripFMMTree.h"
#include "FxGripFMMKernels.h"
#include "FxGripFMMExpansion.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <dispatch/dispatch.h>

FxGripFMMParameters FxGripFMMDefaultParameters(void)
{
	FxGripFMMParameters parameters;
	parameters.expansionOrder = 4;
	parameters.theta = 0.5f;
	parameters.leafCapacity = 64;
	parameters.directThreshold = 2048;
	parameters.softening = 1e-3f;
	parameters.maxThreads = 0;
	return parameters;
}

#pragma mark Context arena

// A grow-only bump arena. Reused across evaluations so a warm evaluation allocates nothing; the
// high-water mark exposes the peak reservation for the no-allocation test.
struct FxGripFMMContext {
	void    *base;            // bump arena for the per-call field working set
	uint64_t capacity;
	uint64_t used;
	uint64_t highWaterMark;
	uint64_t allocationEvents; // grows on any buffer reallocation

	// Persistent per-body buffers, grown monotonically so a warm same-sized call reuses them. Kept
	// out of the bump arena because the arena reallocates as it grows, which would move handed-out
	// pointers; these stand alone and never move the others when one grows.
	uint32_t     *orderBuf;
	FxGripFMMKey *sortedKeysBuf;
	FxGripFMMKey *keysBuf;
	uint32_t     *idxScratchBuf;
	uint32_t      bodyCapacity;

	FxGripFMMCell *cells;      // persistent, monotonically grown octree cell buffer
	uint32_t cellsCapacity;
	float   *biotScratch;      // persistent 4n floats: one charge + three gradient outputs
	uint32_t biotScratchFloats;
	FxGripFMMExpansionTables *tables; // cached, rebuilt only when the order changes
	uint32_t tablesOrder;
};

// Grows the Biot-Savart scratch to hold 4n floats, only when a call needs more than before.
static int FxGripFMMEnsureBiotScratch(FxGripFMMContext *c, uint32_t n)
{
	if ((uint64_t)4u * n <= c->biotScratchFloats) {
		return 1;
	}
	float *g = (float *)realloc(c->biotScratch, sizeof(float) * (size_t)4u * n);
	if (g == NULL) {
		return 0;
	}
	c->biotScratch = g;
	c->biotScratchFloats = 4u * n;
	c->allocationEvents += 1;
	return 1;
}

// Grows the persistent per-body buffers to hold n bodies, only when a call needs more than before.
static int FxGripFMMEnsureBodyBuffers(FxGripFMMContext *c, uint32_t n)
{
	if (n <= c->bodyCapacity) {
		return 1;
	}
	uint32_t *o = (uint32_t *)realloc(c->orderBuf, sizeof(uint32_t) * n);
	FxGripFMMKey *sk = (FxGripFMMKey *)realloc(c->sortedKeysBuf, sizeof(FxGripFMMKey) * n);
	FxGripFMMKey *k = (FxGripFMMKey *)realloc(c->keysBuf, sizeof(FxGripFMMKey) * n);
	uint32_t *ix = (uint32_t *)realloc(c->idxScratchBuf, sizeof(uint32_t) * n);
	if (o != NULL) { c->orderBuf = o; }
	if (sk != NULL) { c->sortedKeysBuf = sk; }
	if (k != NULL) { c->keysBuf = k; }
	if (ix != NULL) { c->idxScratchBuf = ix; }
	if (o == NULL || sk == NULL || k == NULL || ix == NULL) {
		return 0;
	}
	c->bodyCapacity = n;
	c->allocationEvents += 1;
	return 1;
}

// Reserves the bump arena to `bytes`, growing it once so later bump handouts never reallocate and so
// no pointer handed out this call can move. A warm same-sized call finds the arena already big enough.
static int FxGripFMMArenaReserve(FxGripFMMContext *c, uint64_t bytes)
{
	c->used = 0;
	if (bytes > c->capacity) {
		void *grown = realloc(c->base, bytes);
		if (grown == NULL) { return 0; }
		c->base = grown; c->capacity = bytes; c->allocationEvents += 1;
	}
	return 1;
}

// Bump-allocates 16-byte-aligned bytes from the reserved arena. Never reallocates.
static void *FxGripFMMArena(FxGripFMMContext *c, size_t bytes)
{
	uint64_t offset = (c->used + 15u) & ~(uint64_t)15u;
	c->used = offset + bytes;
	if (c->used > c->highWaterMark) { c->highWaterMark = c->used; }
	return (char *)c->base + offset;
}

static inline uint64_t FxGripFMMAlign16(uint64_t bytes) { return (bytes + 15u) & ~(uint64_t)15u; }

FxGripFMMContext *FxGripFMMContextCreate(void)
{
	FxGripFMMContext *context = (FxGripFMMContext *)calloc(1, sizeof(FxGripFMMContext));
	return context;
}

void FxGripFMMContextDestroy(FxGripFMMContext *context)
{
	if (context == NULL) {
		return;
	}
	free(context->base);
	free(context->cells);
	free(context->orderBuf);
	free(context->sortedKeysBuf);
	free(context->keysBuf);
	free(context->idxScratchBuf);
	free(context->biotScratch);
	FxGripFMMExpansionTablesDestroy(context->tables);
	free(context);
}

// Returns the context's expansion tables for `order`, rebuilding them only when the order changes.
static const FxGripFMMExpansionTables *FxGripFMMContextTables(FxGripFMMContext *context, uint32_t order)
{
	if (context->tables == NULL || context->tablesOrder != order) {
		FxGripFMMExpansionTablesDestroy(context->tables);
		context->tables = FxGripFMMExpansionTablesCreate(order);
		context->tablesOrder = order;
	}
	return context->tables;
}

uint64_t FxGripFMMContextArenaHighWaterMark(const FxGripFMMContext *context)
{
	return context != NULL ? context->highWaterMark : 0;
}

uint64_t FxGripFMMContextAllocationCount(const FxGripFMMContext *context)
{
	return context != NULL ? context->allocationEvents : 0;
}

#pragma mark Direct references

void FxGripFMMEvaluateFieldDirect(uint32_t n, float softening,
								  const float *x, const float *y, const float *z, const float *strength,
								  float *ex, float *ey, float *ez)
{
	if (n == 0 || x == NULL || y == NULL || z == NULL || strength == NULL) {
		return;
	}
	const float eps2 = softening * softening;
	for (uint32_t i = 0; i < n; i++) {
		float ax = 0.0f, ay = 0.0f, az = 0.0f;
		const float xi = x[i], yi = y[i], zi = z[i];
		for (uint32_t j = 0; j < n; j++) {
			if (j == i) {
				continue;
			}
			const float dx = x[j] - xi;
			const float dy = y[j] - yi;
			const float dz = z[j] - zi;
			const float r2 = dx * dx + dy * dy + dz * dz + eps2;
			const float inv = 1.0f / sqrtf(r2);
			const float w = strength[j] * inv * inv * inv;
			ax += w * dx;
			ay += w * dy;
			az += w * dz;
		}
		ex[i] = ax;
		ey[i] = ay;
		ez[i] = az;
	}
}

void FxGripFMMEvaluateBiotSavartDirect(uint32_t n, float softening,
									   const float *x, const float *y, const float *z, const float *strength,
									   const float *vx, const float *vy, const float *vz,
									   float *bx, float *by, float *bz)
{
	if (n == 0 || x == NULL || vx == NULL || strength == NULL) {
		return;
	}
	const float eps2 = softening * softening;
	for (uint32_t i = 0; i < n; i++) {
		float sx = 0.0f, sy = 0.0f, sz = 0.0f;
		const float xi = x[i], yi = y[i], zi = z[i];
		for (uint32_t j = 0; j < n; j++) {
			if (j == i) {
				continue;
			}
			// Separation from source j to target i.
			const float rx = xi - x[j];
			const float ry = yi - y[j];
			const float rz = zi - z[j];
			const float r2 = rx * rx + ry * ry + rz * rz + eps2;
			const float inv = 1.0f / sqrtf(r2);
			const float w = strength[j] * inv * inv * inv;
			// v_j × r.
			const float cx = vy[j] * rz - vz[j] * ry;
			const float cy = vz[j] * rx - vx[j] * rz;
			const float cz = vx[j] * ry - vy[j] * rx;
			sx += w * cx;
			sy += w * cy;
			sz += w * cz;
		}
		bx[i] = sx;
		by[i] = sy;
		bz[i] = sz;
	}
}

#pragma mark Adaptive field: upward pass, dual-tree traversal, downward pass

// Shared state for one adaptive evaluation, threaded through the recursive traversal.
typedef struct {
	const FxGripFMMTree *tree;
	const FxGripFMMExpansionTables *tables;
	uint32_t momentCount;
	float theta2;
	float eps2;
	float softening;
	float *moments;      // cellCount * momentCount, source multipoles
	float *locals;       // cellCount * momentCount, target locals
	const float *sx, *sy, *sz, *ss; // bodies in sorted order
	float *fex, *fey, *fez;         // field accumulators in sorted order
} FxGripFMMWork;

// The multipole acceptance test on a cell pair, then either an M2L (well separated), a P2P (both
// leaves), or a recursion that splits the larger cell. A single ordered pass over ordered pairs
// covers every interaction once, so M2L into A's local and P2P into A's field are deterministic.
static void FxGripFMMTraverse(FxGripFMMWork *w, uint32_t ai, uint32_t bi)
{
	const FxGripFMMCell A = w->tree->cells[ai];
	const FxGripFMMCell B = w->tree->cells[bi];
	const float dx = A.centerX - B.centerX, dy = A.centerY - B.centerY, dz = A.centerZ - B.centerZ;
	const float dist2 = dx * dx + dy * dy + dz * dz;
	const float rsum = A.radius + B.radius;
	// Multipole acceptance, and a softening guard: the far field is unsoftened, so use it only when the
	// closest possible pair between the cells is beyond the softening length. Otherwise the softened
	// near field (P2P) must handle the pair, which keeps a cluster tighter than the softening finite.
	const float clearance = rsum + w->softening;
	if (rsum * rsum < w->theta2 * dist2 && dist2 > clearance * clearance) {
		FxGripFMMM2L(w->tables, B.centerX, B.centerY, B.centerZ, w->moments + (size_t)bi * w->momentCount,
					 A.centerX, A.centerY, A.centerZ, w->locals + (size_t)ai * w->momentCount);
		return;
	}
	if (A.childCount == 0 && B.childCount == 0) {
		FxGripFMMFieldP2P(w->sx + A.firstBody, w->sy + A.firstBody, w->sz + A.firstBody,
						  w->fex + A.firstBody, w->fey + A.firstBody, w->fez + A.firstBody, A.bodyCount,
						  w->sx + B.firstBody, w->sy + B.firstBody, w->sz + B.firstBody, w->ss + B.firstBody, B.bodyCount,
						  w->eps2);
		return;
	}
	if (B.childCount == 0 || (A.childCount > 0 && A.radius >= B.radius)) {
		for (uint32_t k = 0; k < A.childCount; k++) {
			FxGripFMMTraverse(w, A.firstChild + k, bi);
		}
	} else {
		for (uint32_t k = 0; k < B.childCount; k++) {
			FxGripFMMTraverse(w, ai, B.firstChild + k);
		}
	}
}

// Fills a caller-provided buffer with a frontier of target cells whose subtrees partition the bodies,
// splitting the fullest cell until there are enough tasks for the worker pool. Each frontier cell owns
// a disjoint set of target bodies, so workers rooted at them never write the same local or field slot.
// A split that would overflow the buffer stops the growth, so the count never exceeds `capacity`.
static uint32_t FxGripFMMBuildFrontier(const FxGripFMMTree *tree, uint32_t desired,
									   uint32_t *frontier, uint32_t capacity)
{
	uint32_t count = 0;
	frontier[count++] = 0; // root
	while (count < desired) {
		int64_t best = -1;
		uint32_t bestBodies = 0;
		for (uint32_t i = 0; i < count; i++) {
			const FxGripFMMCell cell = tree->cells[frontier[i]];
			if (cell.childCount > 0 && cell.bodyCount > bestBodies) {
				bestBodies = cell.bodyCount;
				best = (int64_t)i;
			}
		}
		if (best < 0 || count + tree->cells[frontier[best]].childCount > capacity) {
			break;
		}
		const FxGripFMMCell cell = tree->cells[frontier[best]];
		frontier[best] = cell.firstChild; // first child replaces the parent slot
		for (uint32_t k = 1; k < cell.childCount; k++) {
			frontier[count++] = cell.firstChild + k;
		}
	}
	return count;
}

void FxGripFMMEvaluateField(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
							uint32_t n,
							const float *x, const float *y, const float *z, const float *strength,
							float *ex, float *ey, float *ez)
{
	if (n == 0 || x == NULL || y == NULL || z == NULL || strength == NULL) {
		return;
	}
	const FxGripFMMParameters P = parameters != NULL ? *parameters : FxGripFMMDefaultParameters();

	// Small sets, or no context to hold the tables, take the exact direct path.
	if (context == NULL || n <= P.directThreshold) {
		FxGripFMMEvaluateFieldDirect(n, P.softening, x, y, z, strength, ex, ey, ez);
		return;
	}

	// The tree's per-body buffers and cell buffer are persistent context memory, reused across calls.
	FxGripFMMTree treeStorage;
	FxGripFMMTree *tree = &treeStorage;
	if (!FxGripFMMEnsureBodyBuffers(context, n) ||
		!FxGripFMMTreeBuildInto(tree, n, x, y, z, P.leafCapacity, FXGRIP_FMM_MAX_DEPTH,
								context->orderBuf, context->sortedKeysBuf, context->keysBuf, context->idxScratchBuf,
								&context->cells, &context->cellsCapacity, &context->allocationEvents)) {
		FxGripFMMEvaluateFieldDirect(n, P.softening, x, y, z, strength, ex, ey, ez);
		return;
	}
	const FxGripFMMExpansionTables *tables = FxGripFMMContextTables(context, P.expansionOrder);
	const uint32_t mc = FxGripFMMExpansionMomentCount(tables);
	const uint32_t cc = tree->cellCount;

	uint32_t hw = (uint32_t)sysconf(_SC_NPROCESSORS_ONLN);
	if (hw < 1u) { hw = 1u; }
	const uint32_t threads = P.maxThreads > 0u ? P.maxThreads : hw;
	const uint32_t frontierCapacity = threads * 4u + 8u;

	// Reserve the field working set in one grow so no bump handout can move an earlier pointer.
	const uint64_t bodyBytes = FxGripFMMAlign16(sizeof(float) * n);
	const uint64_t cellBytes = FxGripFMMAlign16(sizeof(float) * (size_t)cc * mc);
	const uint64_t fieldBytes = 7u * bodyBytes + 2u * cellBytes +
								FxGripFMMAlign16(sizeof(uint32_t) * frontierCapacity) + 64u;
	if (!FxGripFMMArenaReserve(context, fieldBytes)) {
		FxGripFMMEvaluateFieldDirect(n, P.softening, x, y, z, strength, ex, ey, ez);
		return;
	}
	float *sx = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *sy = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *sz = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *ss = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *fex = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *fey = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *fez = (float *)FxGripFMMArena(context, sizeof(float) * n);
	float *moments = (float *)FxGripFMMArena(context, sizeof(float) * (size_t)cc * mc);
	float *locals = (float *)FxGripFMMArena(context, sizeof(float) * (size_t)cc * mc);
	uint32_t *frontier = (uint32_t *)FxGripFMMArena(context, sizeof(uint32_t) * frontierCapacity);
	memset(fex, 0, sizeof(float) * n);
	memset(fey, 0, sizeof(float) * n);
	memset(fez, 0, sizeof(float) * n);
	memset(moments, 0, sizeof(float) * (size_t)cc * mc);
	memset(locals, 0, sizeof(float) * (size_t)cc * mc);
	for (uint32_t i = 0; i < n; i++) {
		const uint32_t o = tree->order[i];
		sx[i] = x[o]; sy[i] = y[o]; sz[i] = z[o]; ss[i] = strength[o];
	}

	// Upward pass: leaves get their multipole from P2M, internal cells from their children by M2M.
	// Reverse cell order visits children before parents, since the build appends children after.
	for (int64_t ci = (int64_t)cc - 1; ci >= 0; ci--) {
		const FxGripFMMCell cell = tree->cells[ci];
		float *M = moments + (size_t)ci * mc;
		if (cell.childCount == 0) {
			FxGripFMMP2M(tables, cell.centerX, cell.centerY, cell.centerZ,
						 sx + cell.firstBody, sy + cell.firstBody, sz + cell.firstBody, ss + cell.firstBody,
						 cell.bodyCount, M);
		} else {
			for (uint32_t k = 0; k < cell.childCount; k++) {
				const FxGripFMMCell ch = tree->cells[cell.firstChild + k];
				FxGripFMMM2M(tables, ch.centerX, ch.centerY, ch.centerZ, moments + (size_t)(cell.firstChild + k) * mc,
							 cell.centerX, cell.centerY, cell.centerZ, M);
			}
		}
	}

	// Interaction phase: far pairs to locals (M2L), near pairs to the field (P2P).
	FxGripFMMWork work;
	work.tree = tree; work.tables = tables; work.momentCount = mc;
	work.theta2 = P.theta * P.theta; work.eps2 = P.softening * P.softening; work.softening = P.softening;
	work.moments = moments; work.locals = locals;
	work.sx = sx; work.sy = sy; work.sz = sz; work.ss = ss;
	work.fex = fex; work.fey = fey; work.fez = fez;

	const uint32_t taskCount = FxGripFMMBuildFrontier(tree, threads * 4u, frontier, frontierCapacity);
	if (threads <= 1u || taskCount <= 1u) {
		for (uint32_t k = 0; k < taskCount; k++) {
			FxGripFMMTraverse(&work, frontier[k], 0);
		}
	} else {
		// Each task owns a disjoint target subtree, so the parallel writes never collide and the
		// result is identical to the sequential order for any thread count.
		FxGripFMMWork *wp = &work;
		dispatch_apply(taskCount, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t k) {
			FxGripFMMTraverse(wp, frontier[k], 0);
		});
	}

	// Downward pass: locals flow parent to child by L2L, then each leaf's local adds to its field.
	for (uint32_t ci = 0; ci < cc; ci++) {
		const FxGripFMMCell cell = tree->cells[ci];
		const float *L = locals + (size_t)ci * mc;
		if (cell.childCount == 0) {
			FxGripFMML2PField(tables, cell.centerX, cell.centerY, cell.centerZ, L,
							  sx + cell.firstBody, sy + cell.firstBody, sz + cell.firstBody,
							  fex + cell.firstBody, fey + cell.firstBody, fez + cell.firstBody, cell.bodyCount);
		} else {
			for (uint32_t k = 0; k < cell.childCount; k++) {
				const FxGripFMMCell ch = tree->cells[cell.firstChild + k];
				FxGripFMML2L(tables, cell.centerX, cell.centerY, cell.centerZ, L,
							 ch.centerX, ch.centerY, ch.centerZ, locals + (size_t)(cell.firstChild + k) * mc);
			}
		}
	}

	for (uint32_t i = 0; i < n; i++) {
		const uint32_t o = tree->order[i];
		ex[o] = fex[i]; ey[o] = fey[i]; ez[o] = fez[i];
	}
	// No frees: the arena and the persistent cell buffer are reused by the next evaluation. The tree
	// struct is on the stack, and its arrays live in the context.
}

// The magnetic field is the curl of a vector potential F whose components F_x, F_y, F_z are each a
// Laplace potential with source strength strength_j·v_{j,component}. Running the scalar field for each
// velocity component gives the gradient of that component's potential, and the curl assembles into B:
//   B_x = ∂_y F_z − ∂_z F_y,  B_y = ∂_z F_x − ∂_x F_z,  B_z = ∂_x F_y − ∂_y F_x.
#pragma mark Per-point field query

// A built source field: the tree and multipole expansions of a set of sources, plus the sorted
// sources for the near field. Owns its memory.
struct FxGripFMMField {
	FxGripFMMTree *tree;
	const FxGripFMMExpansionTables *tables;
	uint32_t momentCount;
	uint32_t channelCount;
	uint32_t bodyCount;
	// Moments for cell ci, channel c start at (ci * channelCount + c) * momentCount; sorted strengths
	// for channel c start at ss + c * bodyCount.
	float *moments;
	// Local expansions, filled by the same dual-tree traversal the batch evaluator runs, so a query is
	// one local evaluation plus the near leaves that the multipole could not cover.
	float *locals;
	uint32_t *nearStart;  // cellCount + 1 offsets into nearCells
	uint32_t *nearCells;  // source leaves each target leaf must sum directly
	float *sx, *sy, *sz, *ss;
	float theta2;
	float eps2;
	float softening;
};

// One task's record of the leaf pairs the multipole could not accept.
typedef struct FxGripFMMPairList {
	uint32_t *pairs;   // target, source per entry
	uint32_t count;
	uint32_t capacity;
} FxGripFMMPairList;

static int FxGripFMMPairListAppend(FxGripFMMPairList *list, uint32_t target, uint32_t source)
{
	if (list->count == list->capacity) {
		const uint32_t next = list->capacity > 0u ? list->capacity * 2u : 256u;
		uint32_t *grown = (uint32_t *)realloc(list->pairs, sizeof(uint32_t) * 2u * next);
		if (grown == NULL) {
			return 0;
		}
		list->pairs = grown;
		list->capacity = next;
	}
	list->pairs[2u * list->count] = target;
	list->pairs[2u * list->count + 1u] = source;
	list->count += 1u;
	return 1;
}

// The traversal that fills the locals. It mirrors the batch evaluator's, except that a near leaf pair
// is recorded rather than summed: the targets are not known at build time, so the near sum waits for
// the query.
typedef struct {
	const FxGripFMMTree *tree;
	const FxGripFMMExpansionTables *tables;
	uint32_t momentCount;
	uint32_t channelCount;
	float theta2;
	float softening;
	const float *moments;
	float *locals;
	FxGripFMMPairList *list;
	volatile int32_t failed;
} FxGripFMMFieldBuildWork;

static void FxGripFMMFieldTraverse(FxGripFMMFieldBuildWork *w, uint32_t ai, uint32_t bi)
{
	const FxGripFMMCell A = w->tree->cells[ai];
	const FxGripFMMCell B = w->tree->cells[bi];
	const float dx = A.centerX - B.centerX, dy = A.centerY - B.centerY, dz = A.centerZ - B.centerZ;
	const float dist2 = dx * dx + dy * dy + dz * dz;
	const float rsum = A.radius + B.radius;
	const float clearance = rsum + w->softening;
	if (rsum * rsum < w->theta2 * dist2 && dist2 > clearance * clearance) {
		const uint32_t nc = w->channelCount, mc = w->momentCount;
		for (uint32_t c = 0; c < nc; c++) {
			FxGripFMMM2L(w->tables, B.centerX, B.centerY, B.centerZ,
						 w->moments + ((size_t)bi * nc + c) * mc,
						 A.centerX, A.centerY, A.centerZ,
						 w->locals + ((size_t)ai * nc + c) * mc);
		}
		return;
	}
	if (A.childCount == 0 && B.childCount == 0) {
		if (!FxGripFMMPairListAppend(w->list, ai, bi)) {
			w->failed = 1;
		}
		return;
	}
	if (B.childCount == 0 || (A.childCount > 0 && A.radius >= B.radius)) {
		for (uint32_t k = 0; k < A.childCount; k++) {
			FxGripFMMFieldTraverse(w, A.firstChild + k, bi);
		}
	} else {
		for (uint32_t k = 0; k < B.childCount; k++) {
			FxGripFMMFieldTraverse(w, ai, B.firstChild + k);
		}
	}
}

// Runs the dual-tree traversal to fill every cell's local expansion and record the near leaf pairs,
// then flows the locals down by L2L. A query then costs one L2P plus its leaf's near sum, instead of a
// walk from the root. Returns 0 when the far field could not be built.
static int FxGripFMMFieldFillLocals(FxGripFMMField *field, const FxGripFMMParameters *P)
{
	const uint32_t cc = field->tree->cellCount;
	const uint32_t nc = field->channelCount;
	const uint32_t mc = field->momentCount;

	field->locals = (float *)calloc((size_t)cc * nc * mc, sizeof(float));
	field->nearStart = (uint32_t *)calloc((size_t)cc + 1u, sizeof(uint32_t));
	if (field->locals == NULL || field->nearStart == NULL) {
		return 0;
	}

	uint32_t hw = (uint32_t)sysconf(_SC_NPROCESSORS_ONLN);
	if (hw < 1u) { hw = 1u; }
	const uint32_t threads = P->maxThreads > 0u ? P->maxThreads : hw;
	const uint32_t frontierCapacity = threads * 4u + 8u;
	uint32_t *frontier = (uint32_t *)malloc(sizeof(uint32_t) * frontierCapacity);
	if (frontier == NULL) {
		return 0;
	}
	const uint32_t taskCount = FxGripFMMBuildFrontier(field->tree, threads * 4u, frontier, frontierCapacity);
	FxGripFMMPairList *lists = (FxGripFMMPairList *)calloc(taskCount, sizeof(FxGripFMMPairList));
	FxGripFMMFieldBuildWork *works = (FxGripFMMFieldBuildWork *)calloc(taskCount, sizeof(FxGripFMMFieldBuildWork));
	if (lists == NULL || works == NULL) {
		free(frontier); free(lists); free(works);
		return 0;
	}
	for (uint32_t k = 0; k < taskCount; k++) {
		works[k].tree = field->tree;
		works[k].tables = field->tables;
		works[k].momentCount = mc;
		works[k].channelCount = nc;
		works[k].theta2 = field->theta2;
		works[k].softening = field->softening;
		works[k].moments = field->moments;
		works[k].locals = field->locals;
		works[k].list = &lists[k];
	}
	// Each task owns a disjoint target subtree, so the parallel writes never collide and the recorded
	// pairs are the same for any thread count.
	if (threads <= 1u || taskCount <= 1u) {
		for (uint32_t k = 0; k < taskCount; k++) {
			FxGripFMMFieldTraverse(&works[k], frontier[k], 0);
		}
	} else {
		FxGripFMMFieldBuildWork *wp = works;
		dispatch_apply(taskCount, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t k) {
			FxGripFMMFieldTraverse(&wp[k], frontier[k], 0);
		});
	}
	free(frontier);

	int failed = 0;
	uint64_t total = 0;
	for (uint32_t k = 0; k < taskCount; k++) {
		failed = failed || works[k].failed;
		total += lists[k].count;
	}
	if (!failed) {
		// Counting sort by target cell, over the tasks in order, so the near list of a cell is in a
		// fixed order and the near sum reproduces.
		for (uint32_t k = 0; k < taskCount; k++) {
			for (uint32_t i = 0; i < lists[k].count; i++) {
				field->nearStart[lists[k].pairs[2u * i] + 1u] += 1u;
			}
		}
		for (uint32_t ci = 0; ci < cc; ci++) {
			field->nearStart[ci + 1u] += field->nearStart[ci];
		}
		field->nearCells = (uint32_t *)malloc(sizeof(uint32_t) * (total > 0 ? total : 1));
		uint32_t *cursor = (uint32_t *)malloc(sizeof(uint32_t) * ((size_t)cc + 1u));
		if (field->nearCells == NULL || cursor == NULL) {
			failed = 1;
			free(cursor);
		} else {
			memcpy(cursor, field->nearStart, sizeof(uint32_t) * ((size_t)cc + 1u));
			for (uint32_t k = 0; k < taskCount; k++) {
				for (uint32_t i = 0; i < lists[k].count; i++) {
					const uint32_t target = lists[k].pairs[2u * i];
					field->nearCells[cursor[target]++] = lists[k].pairs[2u * i + 1u];
				}
			}
			free(cursor);
		}
	}
	for (uint32_t k = 0; k < taskCount; k++) {
		free(lists[k].pairs);
	}
	free(lists);
	free(works);
	if (failed) {
		return 0;
	}

	// Downward pass: a parent's local flows to its children, so a leaf's local carries the whole far
	// field at that leaf.
	for (uint32_t ci = 0; ci < cc; ci++) {
		const FxGripFMMCell cell = field->tree->cells[ci];
		if (cell.childCount == 0) {
			continue;
		}
		for (uint32_t k = 0; k < cell.childCount; k++) {
			const FxGripFMMCell ch = field->tree->cells[cell.firstChild + k];
			for (uint32_t c = 0; c < nc; c++) {
				FxGripFMML2L(field->tables, cell.centerX, cell.centerY, cell.centerZ,
							 field->locals + ((size_t)ci * nc + c) * mc,
							 ch.centerX, ch.centerY, ch.centerZ,
							 field->locals + ((size_t)(cell.firstChild + k) * nc + c) * mc);
			}
		}
	}
	return 1;
}

FxGripFMMField *FxGripFMMFieldBuild(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
									uint32_t n, const float *x, const float *y, const float *z, const float *strength)
{
	const float *channels[1] = { strength };
	return FxGripFMMFieldBuildChannels(context, parameters, n, x, y, z, channels, 1);
}

FxGripFMMField *FxGripFMMFieldBuildChannels(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
											uint32_t n, const float *x, const float *y, const float *z,
											const float *const *strengths, uint32_t channelCount)
{
	if (n == 0 || channelCount == 0 || context == NULL || x == NULL || y == NULL || z == NULL || strengths == NULL) {
		return NULL;
	}
	for (uint32_t c = 0; c < channelCount; c++) {
		if (strengths[c] == NULL) {
			return NULL;
		}
	}
	const FxGripFMMParameters P = parameters != NULL ? *parameters : FxGripFMMDefaultParameters();
	FxGripFMMField *field = (FxGripFMMField *)calloc(1, sizeof(FxGripFMMField));
	if (field == NULL) {
		return NULL;
	}
	field->tree = FxGripFMMTreeBuild(n, x, y, z, P.leafCapacity, FXGRIP_FMM_MAX_DEPTH);
	field->tables = FxGripFMMContextTables(context, P.expansionOrder);
	if (field->tree == NULL || field->tables == NULL) {
		FxGripFMMFieldDestroy(field);
		return NULL;
	}
	const uint32_t mc = FxGripFMMExpansionMomentCount(field->tables);
	const uint32_t cc = field->tree->cellCount;
	field->momentCount = mc;
	field->channelCount = channelCount;
	field->bodyCount = n;
	field->theta2 = P.theta * P.theta;
	field->eps2 = P.softening * P.softening;
	field->softening = P.softening;
	field->sx = (float *)malloc(sizeof(float) * n);
	field->sy = (float *)malloc(sizeof(float) * n);
	field->sz = (float *)malloc(sizeof(float) * n);
	field->ss = (float *)malloc(sizeof(float) * (size_t)n * channelCount);
	field->moments = (float *)calloc((size_t)cc * channelCount * mc, sizeof(float));
	if (field->sx == NULL || field->sy == NULL || field->sz == NULL || field->ss == NULL || field->moments == NULL) {
		FxGripFMMFieldDestroy(field);
		return NULL;
	}
	for (uint32_t i = 0; i < n; i++) {
		const uint32_t o = field->tree->order[i];
		field->sx[i] = x[o]; field->sy[i] = y[o]; field->sz[i] = z[o];
		for (uint32_t c = 0; c < channelCount; c++) {
			field->ss[(size_t)c * n + i] = strengths[c][o];
		}
	}
	// Upward pass: leaves by P2M, internal cells by M2M from children (children come after parents).
	for (int64_t ci = (int64_t)cc - 1; ci >= 0; ci--) {
		const FxGripFMMCell cell = field->tree->cells[ci];
		for (uint32_t c = 0; c < channelCount; c++) {
			float *M = field->moments + ((size_t)ci * channelCount + c) * mc;
			if (cell.childCount == 0) {
				FxGripFMMP2M(field->tables, cell.centerX, cell.centerY, cell.centerZ,
							 field->sx + cell.firstBody, field->sy + cell.firstBody, field->sz + cell.firstBody,
							 field->ss + (size_t)c * n + cell.firstBody, cell.bodyCount, M);
			} else {
				for (uint32_t k = 0; k < cell.childCount; k++) {
					const FxGripFMMCell ch = field->tree->cells[cell.firstChild + k];
					FxGripFMMM2M(field->tables, ch.centerX, ch.centerY, ch.centerZ,
								 field->moments + ((size_t)(cell.firstChild + k) * channelCount + c) * mc,
								 cell.centerX, cell.centerY, cell.centerZ, M);
				}
			}
		}
	}

	if (!FxGripFMMFieldFillLocals(field, &P)) {
		// The far field is unavailable, so a query falls back to the single-target walk.
		free(field->locals); field->locals = NULL;
		free(field->nearStart); field->nearStart = NULL;
		free(field->nearCells); field->nearCells = NULL;
	}
	return field;
}

uint32_t FxGripFMMFieldChannelCount(const FxGripFMMField *field)
{
	return field != NULL ? field->channelCount : 0u;
}

// Walks the tree for one target point: a well-separated cell contributes its multipole, a near leaf
// contributes its sources directly, and anything else is split. The acceptance test reads only the
// positions, so every channel rides the one walk.
static void FxGripFMMFieldWalk(const FxGripFMMField *f, uint32_t ci, float tx, float ty, float tz,
							   float *ex, float *ey, float *ez)
{
	const FxGripFMMCell cell = f->tree->cells[ci];
	const float dx = cell.centerX - tx, dy = cell.centerY - ty, dz = cell.centerZ - tz;
	const float dist2 = dx * dx + dy * dy + dz * dz;
	const float clearance = cell.radius + f->softening;
	const uint32_t nc = f->channelCount;
	if (cell.radius * cell.radius < f->theta2 * dist2 && dist2 > clearance * clearance) {
		for (uint32_t c = 0; c < nc; c++) {
			FxGripFMMM2PField(f->tables, cell.centerX, cell.centerY, cell.centerZ,
							  f->moments + ((size_t)ci * nc + c) * f->momentCount,
							  &tx, &ty, &tz, &ex[c], &ey[c], &ez[c], 1);
		}
		return;
	}
	if (cell.childCount == 0) {
		for (uint32_t c = 0; c < nc; c++) {
			FxGripFMMFieldP2P(&tx, &ty, &tz, &ex[c], &ey[c], &ez[c], 1,
							  f->sx + cell.firstBody, f->sy + cell.firstBody, f->sz + cell.firstBody,
							  f->ss + (size_t)c * f->bodyCount + cell.firstBody,
							  cell.bodyCount, f->eps2);
		}
		return;
	}
	for (uint32_t k = 0; k < cell.childCount; k++) {
		FxGripFMMFieldWalk(f, cell.firstChild + k, tx, ty, tz, ex, ey, ez);
	}
}

// The leaf whose cube contains the point, or UINT32_MAX when the point is outside the tree or falls in
// an octant that holds no sources. Empty octants are not built, so a point there has no leaf and the
// caller falls back to the walk.
static uint32_t FxGripFMMFieldLeafContaining(const FxGripFMMField *f, float tx, float ty, float tz)
{
	const FxGripFMMCell root = f->tree->cells[0];
	if (fabsf(tx - root.centerX) > root.radius ||
		fabsf(ty - root.centerY) > root.radius ||
		fabsf(tz - root.centerZ) > root.radius) {
		return UINT32_MAX;
	}
	uint32_t ci = 0;
	while (f->tree->cells[ci].childCount > 0) {
		const FxGripFMMCell cell = f->tree->cells[ci];
		uint32_t next = UINT32_MAX;
		for (uint32_t k = 0; k < cell.childCount; k++) {
			const uint32_t candidate = cell.firstChild + k;
			const FxGripFMMCell child = f->tree->cells[candidate];
			if (fabsf(tx - child.centerX) <= child.radius &&
				fabsf(ty - child.centerY) <= child.radius &&
				fabsf(tz - child.centerZ) <= child.radius) {
				next = candidate;
				break;
			}
		}
		if (next == UINT32_MAX) {
			return UINT32_MAX;
		}
		ci = next;
	}
	return ci;
}

void FxGripFMMFieldEvaluateChannelsAt(const FxGripFMMField *field, float tx, float ty, float tz,
									  float *ex, float *ey, float *ez)
{
	if (field == NULL) {
		return;
	}
	const uint32_t nc = field->channelCount;
	for (uint32_t c = 0; c < nc; c++) {
		ex[c] = 0.0f; ey[c] = 0.0f; ez[c] = 0.0f;
	}
	const uint32_t leaf = field->locals != NULL ? FxGripFMMFieldLeafContaining(field, tx, ty, tz) : UINT32_MAX;
	if (leaf == UINT32_MAX) {
		FxGripFMMFieldWalk(field, 0, tx, ty, tz, ex, ey, ez);
		return;
	}
	const FxGripFMMCell L = field->tree->cells[leaf];
	const uint32_t mc = field->momentCount;
	for (uint32_t c = 0; c < nc; c++) {
		FxGripFMML2PField(field->tables, L.centerX, L.centerY, L.centerZ,
						  field->locals + ((size_t)leaf * nc + c) * mc,
						  &tx, &ty, &tz, &ex[c], &ey[c], &ez[c], 1);
	}
	for (uint32_t e = field->nearStart[leaf]; e < field->nearStart[leaf + 1u]; e++) {
		const FxGripFMMCell S = field->tree->cells[field->nearCells[e]];
		for (uint32_t c = 0; c < nc; c++) {
			FxGripFMMFieldP2P(&tx, &ty, &tz, &ex[c], &ey[c], &ez[c], 1,
							  field->sx + S.firstBody, field->sy + S.firstBody, field->sz + S.firstBody,
							  field->ss + (size_t)c * field->bodyCount + S.firstBody,
							  S.bodyCount, field->eps2);
		}
	}
}

void FxGripFMMFieldEvaluateAt(const FxGripFMMField *field, float tx, float ty, float tz,
							  float *ex, float *ey, float *ez)
{
	*ex = 0.0f; *ey = 0.0f; *ez = 0.0f;
	if (field == NULL || field->channelCount != 1) {
		return;
	}
	FxGripFMMFieldEvaluateChannelsAt(field, tx, ty, tz, ex, ey, ez);
}

void FxGripFMMFieldDestroy(FxGripFMMField *field)
{
	if (field == NULL) {
		return;
	}
	FxGripFMMTreeFree(field->tree);
	free(field->sx); free(field->sy); free(field->sz); free(field->ss);
	free(field->moments);
	free(field->locals);
	free(field->nearStart);
	free(field->nearCells);
	free(field);
}

void FxGripFMMEvaluateBiotSavart(FxGripFMMContext *context, const FxGripFMMParameters *parameters,
								 uint32_t n,
								 const float *x, const float *y, const float *z, const float *strength,
								 const float *vx, const float *vy, const float *vz,
								 float *bx, float *by, float *bz)
{
	if (n == 0 || x == NULL || vx == NULL || strength == NULL) {
		return;
	}
	const FxGripFMMParameters P = parameters != NULL ? *parameters : FxGripFMMDefaultParameters();
	if (context == NULL || n <= P.directThreshold) {
		FxGripFMMEvaluateBiotSavartDirect(n, P.softening, x, y, z, strength, vx, vy, vz, bx, by, bz);
		return;
	}
	if (!FxGripFMMEnsureBiotScratch(context, n)) {
		FxGripFMMEvaluateBiotSavartDirect(n, P.softening, x, y, z, strength, vx, vy, vz, bx, by, bz);
		return;
	}
	float *charge = context->biotScratch;
	float *gx = charge + n;
	float *gy = gx + n;
	float *gz = gy + n;

	for (uint32_t i = 0; i < n; i++) { bx[i] = 0.0f; by[i] = 0.0f; bz[i] = 0.0f; }

	const float *vel[3] = { vx, vy, vz };
	for (uint32_t comp = 0; comp < 3u; comp++) {
		for (uint32_t i = 0; i < n; i++) {
			charge[i] = strength[i] * vel[comp][i];
		}
		// gx,gy,gz receive the gradient of the potential built from this velocity component: G^comp.
		FxGripFMMEvaluateField(context, &P, n, x, y, z, charge, gx, gy, gz);
		for (uint32_t i = 0; i < n; i++) {
			if (comp == 0) {        // G^x contributes to B_y (+∂_z) and B_z (−∂_y)
				by[i] += gz[i];
				bz[i] -= gy[i];
			} else if (comp == 1) { // G^y contributes to B_x (−∂_z) and B_z (+∂_x)
				bx[i] -= gz[i];
				bz[i] += gx[i];
			} else {                // G^z contributes to B_x (+∂_y) and B_y (−∂_x)
				bx[i] += gy[i];
				by[i] -= gx[i];
			}
		}
	}
}
