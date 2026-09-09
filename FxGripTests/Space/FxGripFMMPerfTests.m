/*!
	@file       FxGripFMMPerfTests.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-08
	@header     FxGripFMMPerfTests
	@abstract   Scaling benchmark for the adaptive field, gated and meant for a Release build.
	@discussion Introduced in FxGrip 0.1.0. Times the adaptive field across a geometric range of
	            particle counts and checks that each doubling of the count costs closer to twice the
	            time than four times, the signature of linear rather than quadratic growth. It also
	            reports the speedup over direct summation. An ordinary Debug run skips it, both because
	            it is gated on a marker file and because timings only mean something with optimization
	            on.
*/

#import <XCTest/XCTest.h>
#import <FxGrip/FxGripFMM.h>
#import <time.h>
#import <math.h>

static NSString * const FxGripFMMPerfMarkerPath = @"/tmp/fxgrip-fmm-perf";
static NSString * const FxGripFMMPerfResultPath = @"/tmp/fxgrip-fmm-perf-results.json";

@interface FxGripFMMPerfTests : XCTestCase
@end

@implementation FxGripFMMPerfTests

static double FxGripNow(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

- (void)fill:(float *)a count:(uint32_t)n seed:(uint32_t)seed span:(float)span
{
	uint32_t state = seed;
	for (uint32_t i = 0; i < n; i++) {
		state = state * 1664525u + 1013904223u;
		a[i] = ((float)(state >> 8) / 16777216.0f - 0.5f) * span;
	}
}

// Median adaptive-field time over a few runs at count n.
- (double)timeFMMForCount:(uint32_t)n context:(FxGripFMMContext *)ctx params:(const FxGripFMMParameters *)p
{
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
	float *ex = malloc(4*n), *ey = malloc(4*n), *ez = malloc(4*n);
	[self fill:x count:n seed:1 span:powf((float)n, 1.0f/3.0f)]; // keep density roughly constant
	[self fill:y count:n seed:2 span:powf((float)n, 1.0f/3.0f)];
	[self fill:z count:n seed:3 span:powf((float)n, 1.0f/3.0f)];
	for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }

	FxGripFMMEvaluateField(ctx, p, n, x, y, z, s, ex, ey, ez); // warm

	double best = INFINITY;
	for (int run = 0; run < 3; run++) {
		double t0 = FxGripNow();
		FxGripFMMEvaluateField(ctx, p, n, x, y, z, s, ex, ey, ez);
		double dt = FxGripNow() - t0;
		best = dt < best ? dt : best;
	}
	free(x); free(y); free(z); free(s); free(ex); free(ey); free(ez);
	return best;
}

/*! @abstract Doubling the particle count costs closer to twice the time than four, proving linear scaling. */
- (void)testLinearScaling
{
	if (![NSFileManager.defaultManager fileExistsAtPath:FxGripFMMPerfMarkerPath]) {
		XCTSkip("FMM perf is gated; touch %@ and run in Release to benchmark.", FxGripFMMPerfMarkerPath);
	}

	const uint32_t counts[] = { 10000, 20000, 40000, 80000, 160000 };
	const uint32_t levels = sizeof(counts) / sizeof(counts[0]);

	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.directThreshold = 256;
	FxGripFMMContext *ctx = FxGripFMMContextCreate();

	double times[8];
	NSMutableArray *rows = [NSMutableArray array];
	for (uint32_t i = 0; i < levels; i++) {
		times[i] = [self timeFMMForCount:counts[i] context:ctx params:&p];
		[rows addObject:@{ @"n": @(counts[i]),
						   @"seconds": @(times[i]),
						   @"usPerParticle": @(times[i] / counts[i] * 1e6) }];
	}

	NSMutableArray *ratios = [NSMutableArray array];
	double worstRatio = 0;
	for (uint32_t i = 1; i < levels; i++) {
		double r = times[i] / times[i-1];
		[ratios addObject:@(r)];
		worstRatio = r > worstRatio ? r : worstRatio;
	}

	// Speedup over direct at a mid size.
	double directTime = 0;
	{
		const uint32_t n = 20000;
		float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n), *s = malloc(4*n);
		float *ex = malloc(4*n), *ey = malloc(4*n), *ez = malloc(4*n);
		[self fill:x count:n seed:1 span:30.0f];
		[self fill:y count:n seed:2 span:30.0f];
		[self fill:z count:n seed:3 span:30.0f];
		for (uint32_t i = 0; i < n; i++) { s[i] = 1.0f; }
		double t0 = FxGripNow();
		FxGripFMMEvaluateFieldDirect(n, p.softening, x, y, z, s, ex, ey, ez);
		directTime = FxGripNow() - t0;
		free(x); free(y); free(z); free(s); free(ex); free(ey); free(ez);
	}

	NSDictionary *findings = @{
		@"points": rows,
		@"doublingRatios": ratios,
		@"worstDoublingRatio": @(worstRatio),
		@"direct20k_seconds": @(directTime),
		@"fmm20k_seconds": @(times[1]),
		@"speedupAt20k": @(directTime / times[1]),
	};
	NSData *json = [NSJSONSerialization dataWithJSONObject:findings options:NSJSONWritingPrettyPrinted error:NULL];
	[json writeToFile:FxGripFMMPerfResultPath atomically:YES];
	NSLog(@"FMM perf: %@", findings);

	FxGripFMMContextDestroy(ctx);

	// O(N) doubles the time; O(N^2) quadruples it. A worst doubling below 3.0 is decisively linear.
	XCTAssertLessThan(worstRatio, 3.0, @"each doubling of N stays sub-quadratic");
	// The whole 16x span should cost far less than the 256x a quadratic method would.
	XCTAssertLessThan(times[levels-1] / times[0], 48.0, @"16x more particles costs under 48x the time");
}

#pragma mark Per-point query

// Median seconds per query over `queries` target points, for a field of `channelCount` channels built
// over n sources. Build time is reported separately, since a step pays it once and the query cost per
// particle.
- (void)timeFieldQueryForCount:(uint32_t)n
				  channelCount:(uint32_t)channelCount
					   context:(FxGripFMMContext *)ctx
						params:(const FxGripFMMParameters *)p
					 buildTime:(double *)outBuild
					 queryTime:(double *)outQuery
{
	const float span = powf((float)n, 1.0f / 3.0f);
	float *x = malloc(4*n), *y = malloc(4*n), *z = malloc(4*n);
	[self fill:x count:n seed:1 span:span];
	[self fill:y count:n seed:2 span:span];
	[self fill:z count:n seed:3 span:span];
	float *channels[4];
	const float *strengths[4];
	for (uint32_t c = 0; c < channelCount; c++) {
		channels[c] = malloc(4*n);
		[self fill:channels[c] count:n seed:11 + c span:2.0f];
		strengths[c] = channels[c];
	}

	double bestBuild = INFINITY;
	FxGripFMMField *field = NULL;
	for (int run = 0; run < 3; run++) {
		FxGripFMMFieldDestroy(field);
		double t0 = FxGripNow();
		field = FxGripFMMFieldBuildChannels(ctx, p, n, x, y, z, strengths, channelCount);
		bestBuild = fmin(bestBuild, FxGripNow() - t0);
	}

	const uint32_t queries = n;
	float ex[4], ey[4], ez[4];
	FxGripFMMFieldEvaluateChannelsAt(field, x[0], y[0], z[0], ex, ey, ez); // warm
	double bestQuery = INFINITY;
	for (int run = 0; run < 3; run++) {
		double t0 = FxGripNow();
		for (uint32_t i = 0; i < queries; i++) {
			FxGripFMMFieldEvaluateChannelsAt(field, x[i], y[i], z[i], ex, ey, ez);
		}
		bestQuery = fmin(bestQuery, (FxGripNow() - t0) / (double)queries);
	}

	FxGripFMMFieldDestroy(field);
	free(x); free(y); free(z);
	for (uint32_t c = 0; c < channelCount; c++) {
		free(channels[c]);
	}
	*outBuild = bestBuild;
	*outQuery = bestQuery;
}

/*!
	@abstract	Benchmarks the per-point query the physics field facade uses, and the saving from
				carrying several strength channels on one tree.
	@discussion The facade pays one build per step and one query per particle. Sharing a tree across
				channels saves the tree and the traversal bookkeeping, not the kernel work, which
				scales with the channel count; the report records both so the trade is visible. The
				expansion order is the accuracy tier's speed dial, so the sweep shows what a tier
				costs.
*/
- (void)testPerPointQueryCost
{
	if (![NSFileManager.defaultManager fileExistsAtPath:FxGripFMMPerfMarkerPath]) {
		XCTSkip("FMM perf benchmark is gated; touch %@ to run it.", FxGripFMMPerfMarkerPath);
	}
	FxGripFMMParameters p = FxGripFMMDefaultParameters();
	p.expansionOrder = 4;
	FxGripFMMContext *ctx = FxGripFMMContextCreate();

	NSMutableArray *rows = [NSMutableArray array];
	const uint32_t counts[] = { 5000u, 20000u, 80000u };
	double oneChannelQueryAt20k = 0.0, fourChannelQueryAt20k = 0.0;
	for (int i = 0; i < 3; i++) {
		const uint32_t n = counts[i];
		double build1 = 0.0, query1 = 0.0, build4 = 0.0, query4 = 0.0;
		[self timeFieldQueryForCount:n channelCount:1 context:ctx params:&p buildTime:&build1 queryTime:&query1];
		[self timeFieldQueryForCount:n channelCount:4 context:ctx params:&p buildTime:&build4 queryTime:&query4];
		if (n == 20000u) {
			oneChannelQueryAt20k = query1;
			fourChannelQueryAt20k = query4;
		}
		[rows addObject:@{ @"n": @(n),
						   @"build1_ms": @(build1 * 1e3),
						   @"query1_us": @(query1 * 1e6),
						   @"build4_ms": @(build4 * 1e3),
						   @"query4_us": @(query4 * 1e6),
						   @"stepCost1_us_per_particle": @((build1 / (double)n + query1) * 1e6),
						   @"stepCost4_us_per_particle": @((build4 / (double)n + query4) * 1e6),
						   @"fourChannelVsFourWalks": @(query4 / (4.0 * query1)) }];
	}
	FxGripFMMContextDestroy(ctx);

	NSDictionary *report = @{ @"perPointQuery": rows };
	[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL]
		writeToFile:@"/tmp/fxgrip-fmm-query-results.json" atomically:YES];
	NSLog(@"per-point query benchmark: %@", report);

	// Channels share the tree and the walk but not the kernel work, so four channels cost close to
	// four single-channel queries and must not cost more.
	XCTAssertLessThan(fourChannelQueryAt20k, 4.2 * oneChannelQueryAt20k,
					  @"channel count scales the kernel work and nothing worse");
}

/*!
	@abstract	Reports what each accuracy tier costs, since the expansion order is the dial a plugin
				actually turns.
*/
- (void)testExpansionOrderCost
{
	if (![NSFileManager.defaultManager fileExistsAtPath:FxGripFMMPerfMarkerPath]) {
		XCTSkip("FMM perf benchmark is gated; touch %@ to run it.", FxGripFMMPerfMarkerPath);
	}
	FxGripFMMContext *ctx = FxGripFMMContextCreate();
	NSMutableArray *rows = [NSMutableArray array];
	const uint32_t orders[] = { 2u, 4u, 6u };
	const uint32_t n = 20000u;
	for (int i = 0; i < 3; i++) {
		FxGripFMMParameters p = FxGripFMMDefaultParameters();
		p.expansionOrder = orders[i];
		p.theta = orders[i] == 2u ? 0.7f : (orders[i] == 4u ? 0.5f : 0.4f);
		double build = 0.0, query = 0.0;
		[self timeFieldQueryForCount:n channelCount:1 context:ctx params:&p buildTime:&build queryTime:&query];
		double batch = [self timeFMMForCount:n context:ctx params:&p];
		[rows addObject:@{ @"order": @(orders[i]),
						   @"theta": @(p.theta),
						   @"fieldBuild_ms": @(build * 1e3),
						   @"fieldQuery_us": @(query * 1e6),
						   @"fieldStep_us_per_particle": @((build / (double)n + query) * 1e6),
						   @"batch_us_per_particle": @(batch / (double)n * 1e6) }];
	}
	FxGripFMMContextDestroy(ctx);
	NSDictionary *report = @{ @"expansionOrder": rows };
	[[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL]
		writeToFile:@"/tmp/fxgrip-fmm-order-results.json" atomically:YES];
	NSLog(@"expansion order benchmark: %@", report);
	XCTAssertEqual(rows.count, 3u);
}

@end
