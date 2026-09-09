/*!
	@file       FxGripFMMTranslationTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMTranslationTests
	@abstract   Tests for the FMM translation operators M2M, M2L, L2L, and L2P.
	@discussion Introduced in FxGrip 0.1.0. Each operator is checked end to end against direct
	            summation. M2M shifts source moments to a parent and reproduces the parent's field.
	            M2L converts moments to a local expansion that, through L2P, reproduces the field near
	            the target. L2L shifts a local expansion to a child center without changing the field it
	            represents. The module is a private core component, so its header is imported by path.
*/

#import <XCTest/XCTest.h>
#import "../../FxGrip/Space/FxGripFMMExpansion.h"
#import <math.h>

@interface FxGripFMMTranslationTests : XCTestCase
@end

@implementation FxGripFMMTranslationTests

- (void)directFieldTx:(const float *)tx ty:(const float *)ty tz:(const float *)tz count:(uint32_t)nt
				   sx:(const float *)sx sy:(const float *)sy sz:(const float *)sz ss:(const float *)ss sn:(uint32_t)ns
				   ex:(float *)ex ey:(float *)ey ez:(float *)ez
{
	for (uint32_t i = 0; i < nt; i++) {
		double fx = 0, fy = 0, fz = 0;
		for (uint32_t j = 0; j < ns; j++) {
			double dx = sx[j]-tx[i], dy = sy[j]-ty[i], dz = sz[j]-tz[i];
			double r2 = dx*dx+dy*dy+dz*dz;
			double w = ss[j] / (r2 * sqrt(r2));
			fx += w*dx; fy += w*dy; fz += w*dz;
		}
		ex[i] = (float)fx; ey[i] = (float)fy; ez[i] = (float)fz;
	}
}

- (float)relErrorEx:(const float *)ex ey:(const float *)ey ez:(const float *)ez
				 dx:(const float *)dx dy:(const float *)dy dz:(const float *)dz count:(uint32_t)n
{
	float worst = 0;
	for (uint32_t i = 0; i < n; i++) {
		float diff = sqrtf((ex[i]-dx[i])*(ex[i]-dx[i])+(ey[i]-dy[i])*(ey[i]-dy[i])+(ez[i]-dz[i])*(ez[i]-dz[i]));
		float mag = sqrtf(dx[i]*dx[i]+dy[i]*dy[i]+dz[i]*dz[i])+1e-20f;
		worst = fmaxf(worst, diff/mag);
	}
	return worst;
}

// A small clustered source set around a center.
- (void)fillClusterSx:(float *)sx sy:(float *)sy sz:(float *)sz ss:(float *)ss count:(uint32_t)n
			   center:(const float[3])c radius:(float)rc seed:(uint32_t)seed
{
	uint32_t state = seed;
	for (uint32_t j = 0; j < n; j++) {
		state = state*1664525u+1013904223u; sx[j] = c[0] + ((float)(state>>8)/16777216.0f-0.5f)*2.0f*rc;
		state = state*1664525u+1013904223u; sy[j] = c[1] + ((float)(state>>8)/16777216.0f-0.5f)*2.0f*rc;
		state = state*1664525u+1013904223u; sz[j] = c[2] + ((float)(state>>8)/16777216.0f-0.5f)*2.0f*rc;
		ss[j] = 1.0f;
	}
}

/*! @abstract M2M shifts source moments from a child center to a parent and reproduces the direct field. */
- (void)testM2MReproducesFieldFromParentCenter
{
	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(4);
	const uint32_t ns = 40, nc = FxGripFMMExpansionMomentCount(t);
	float sx[40], sy[40], sz[40], ss[40];
	float cc[3] = {0.2f, -0.1f, 0.15f}; // child center inside the cluster
	[self fillClusterSx:sx sy:sy sz:sz ss:ss count:ns center:cc radius:0.5f seed:99u];

	float *childM = calloc(nc, sizeof(float));
	FxGripFMMP2M(t, cc[0], cc[1], cc[2], sx, sy, sz, ss, ns, childM);

	// Shift to a parent center, then evaluate the parent expansion far away.
	float cp[3] = {0.0f, 0.0f, 0.0f};
	float *parentM = calloc(nc, sizeof(float));
	FxGripFMMM2M(t, cc[0], cc[1], cc[2], childM, cp[0], cp[1], cp[2], parentM);

	float tx[6], ty[6], tz[6];
	for (uint32_t i = 0; i < 6; i++) { tx[i]=5.0f+i; ty[i]=-4.0f+0.5f*i; tz[i]=3.0f-0.3f*i; }
	float ex[6]={0}, ey[6]={0}, ez[6]={0}, dx[6], dy[6], dz[6];
	FxGripFMMM2PField(t, cp[0], cp[1], cp[2], parentM, tx, ty, tz, ex, ey, ez, 6);
	[self directFieldTx:tx ty:ty tz:tz count:6 sx:sx sy:sy sz:sz ss:ss sn:ns ex:dx ey:dy ez:dz];

	XCTAssertLessThan([self relErrorEx:ex ey:ey ez:ez dx:dx dy:dy dz:dz count:6], 1e-3f);
	free(childM); free(parentM);
	FxGripFMMExpansionTablesDestroy(t);
}

/*! @abstract M2L then L2P reproduces the field of a distant cluster near the target center. */
- (void)testM2LThenL2PReproducesField
{
	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(4);
	const uint32_t ns = 50, nc = FxGripFMMExpansionMomentCount(t);
	float sx[50], sy[50], sz[50], ss[50];
	float cm[3] = {0,0,0};
	[self fillClusterSx:sx sy:sy sz:sz ss:ss count:ns center:cm radius:1.0f seed:7u];

	float *M = calloc(nc, sizeof(float));
	FxGripFMMP2M(t, cm[0], cm[1], cm[2], sx, sy, sz, ss, ns, M);

	// Local center near the targets, well separated from the source cluster.
	float cl[3] = {10.0f, 0.0f, 0.0f};
	float *L = calloc(nc, sizeof(float));
	FxGripFMMM2L(t, cm[0], cm[1], cm[2], M, cl[0], cl[1], cl[2], L);

	// Targets in a small neighborhood of the local center.
	float tx[8], ty[8], tz[8];
	for (uint32_t i = 0; i < 8; i++) {
		tx[i] = cl[0] + 0.3f*cosf((float)i);
		ty[i] = cl[1] + 0.3f*sinf((float)i);
		tz[i] = cl[2] + 0.2f*cosf((float)i*0.7f);
	}
	float ex[8]={0}, ey[8]={0}, ez[8]={0}, dx[8], dy[8], dz[8];
	FxGripFMML2PField(t, cl[0], cl[1], cl[2], L, tx, ty, tz, ex, ey, ez, 8);
	[self directFieldTx:tx ty:ty tz:tz count:8 sx:sx sy:sy sz:sz ss:ss sn:ns ex:dx ey:dy ez:dz];

	XCTAssertLessThan([self relErrorEx:ex ey:ey ez:ez dx:dx dy:dy dz:dz count:8], 2e-3f);
	free(M); free(L);
	FxGripFMMExpansionTablesDestroy(t);
}

/*! @abstract L2L shifts a local expansion to a child center without changing the field it represents. */
- (void)testL2LPreservesField
{
	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(4);
	const uint32_t ns = 50, nc = FxGripFMMExpansionMomentCount(t);
	float sx[50], sy[50], sz[50], ss[50];
	float cm[3] = {0,0,0};
	[self fillClusterSx:sx sy:sy sz:sz ss:ss count:ns center:cm radius:1.0f seed:31u];
	float *M = calloc(nc, sizeof(float));
	FxGripFMMP2M(t, cm[0], cm[1], cm[2], sx, sy, sz, ss, ns, M);

	float cp[3] = {10.0f, 1.0f, -1.0f};
	float *Lp = calloc(nc, sizeof(float));
	FxGripFMMM2L(t, cm[0], cm[1], cm[2], M, cp[0], cp[1], cp[2], Lp);

	// Shift the local expansion to a child center a small step away.
	float cc[3] = {10.2f, 1.1f, -0.9f};
	float *Lc = calloc(nc, sizeof(float));
	FxGripFMML2L(t, cp[0], cp[1], cp[2], Lp, cc[0], cc[1], cc[2], Lc);

	// Both expansions must give the same field at a shared point near both centers.
	float tx = 10.1f, ty = 1.05f, tz = -0.95f;
	float ep[3]={0,0,0}, ec[3]={0,0,0};
	FxGripFMML2PField(t, cp[0],cp[1],cp[2], Lp, &tx,&ty,&tz, &ep[0],&ep[1],&ep[2], 1);
	FxGripFMML2PField(t, cc[0],cc[1],cc[2], Lc, &tx,&ty,&tz, &ec[0],&ec[1],&ec[2], 1);

	float diff = sqrtf((ep[0]-ec[0])*(ep[0]-ec[0])+(ep[1]-ec[1])*(ep[1]-ec[1])+(ep[2]-ec[2])*(ep[2]-ec[2]));
	float mag = sqrtf(ep[0]*ep[0]+ep[1]*ep[1]+ep[2]*ep[2])+1e-20f;
	XCTAssertLessThan(diff/mag, 1e-4f, @"L2L preserves the represented field");
	free(M); free(Lp); free(Lc);
	FxGripFMMExpansionTablesDestroy(t);
}

/*! @abstract The full chain P2M→M2M→M2L→L2L→L2P reproduces a distant cluster's field. */
- (void)testFullChainReproducesField
{
	FxGripFMMExpansionTables *t = FxGripFMMExpansionTablesCreate(4);
	const uint32_t ns = 60, nc = FxGripFMMExpansionMomentCount(t);
	float sx[60], sy[60], sz[60], ss[60];
	float leaf[3] = {0.3f, 0.2f, -0.2f};
	[self fillClusterSx:sx sy:sy sz:sz ss:ss count:ns center:leaf radius:0.4f seed:5u];

	// Source side: P2M at a leaf center, M2M up to the source cell center.
	float *leafM = calloc(nc, sizeof(float));
	FxGripFMMP2M(t, leaf[0], leaf[1], leaf[2], sx, sy, sz, ss, ns, leafM);
	float srcCenter[3] = {0,0,0};
	float *srcM = calloc(nc, sizeof(float));
	FxGripFMMM2M(t, leaf[0], leaf[1], leaf[2], leafM, srcCenter[0], srcCenter[1], srcCenter[2], srcM);

	// Target side: M2L to a local center, L2L down to a child near the targets.
	float locCenter[3] = {12.0f, 2.0f, 1.0f};
	float *locL = calloc(nc, sizeof(float));
	FxGripFMMM2L(t, srcCenter[0],srcCenter[1],srcCenter[2], srcM, locCenter[0],locCenter[1],locCenter[2], locL);
	float childCenter[3] = {12.1f, 1.9f, 1.05f};
	float *childL = calloc(nc, sizeof(float));
	FxGripFMML2L(t, locCenter[0],locCenter[1],locCenter[2], locL, childCenter[0],childCenter[1],childCenter[2], childL);

	float tx[6], ty[6], tz[6];
	for (uint32_t i = 0; i < 6; i++) {
		tx[i]=childCenter[0]+0.1f*cosf((float)i); ty[i]=childCenter[1]+0.1f*sinf((float)i); tz[i]=childCenter[2]+0.05f*cosf((float)i);
	}
	float ex[6]={0}, ey[6]={0}, ez[6]={0}, dx[6], dy[6], dz[6];
	FxGripFMML2PField(t, childCenter[0],childCenter[1],childCenter[2], childL, tx, ty, tz, ex, ey, ez, 6);
	[self directFieldTx:tx ty:ty tz:tz count:6 sx:sx sy:sy sz:sz ss:ss sn:ns ex:dx ey:dy ez:dz];

	XCTAssertLessThan([self relErrorEx:ex ey:ey ez:ez dx:dx dy:dy dz:dz count:6], 3e-3f);
	free(leafM); free(srcM); free(locL); free(childL);
	FxGripFMMExpansionTablesDestroy(t);
}

@end
