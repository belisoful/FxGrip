//
//  FxGripPhysicsSimulationStore.m
//  FxGrip
//

#import "FxGripPhysicsSimulationStore.h"
#import "FxGripFrameData.h"
#import "FxGrip_ARC.h"

static NSString * const FxGripPhysicsStoreSignatureKey = @"__physicsSignature";

#pragma mark - Memory store

@implementation FxGripPhysicsMemoryStore
{
	NSLock *_lock;
	NSMutableDictionary<NSNumber *, NSDictionary<NSString *, NSData *> *> *_steps;
	NSString *_signature;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_lock = [[NSLock alloc] init];
		_steps = [NSMutableDictionary dictionary];
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_lock);
	NARC_RELEASE(_steps);
	NARC_RELEASE(_signature);
	SUPER_DEALLOC();
}

- (nullable NSDictionary<NSString *, NSData *> *)transformsForStep:(NSInteger)stepIndex
{
	[_lock lock];
	NSDictionary<NSString *, NSData *> *transforms = _steps[@(stepIndex)];
	[_lock unlock];
	return transforms;
}

- (void)setTransforms:(NSDictionary<NSString *, NSData *> *)transforms forStep:(NSInteger)stepIndex
{
	if (transforms.count == 0) {
		return;
	}
	[_lock lock];
	_steps[@(stepIndex)] = [transforms copy];
	[_lock unlock];
}

- (void)invalidate
{
	[_lock lock];
	[_steps removeAllObjects];
	[_lock unlock];
}

- (void)invalidateIfSignatureChanged:(NSString *)signature
{
	[_lock lock];
	if (_signature == nil || ![_signature isEqualToString:signature]) {
		[_steps removeAllObjects];
		NARC_RELEASE(_signature);
		_signature = [signature copy];
	}
	[_lock unlock];
}

@end

#pragma mark - FrameData store

@implementation FxGripPhysicsFrameDataStore

- (instancetype)initWithFrameData:(FxGripFrameData *)frameData
{
	self = [super init];
	if (self != nil) {
		_frameData = NARC_RETAIN(frameData);
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_frameData);
	SUPER_DEALLOC();
}

- (nullable NSDictionary<NSString *, NSData *> *)transformsForStep:(NSInteger)stepIndex
{
	NSObject<NSSecureCoding, NSCopying> *record = [_frameData recordAtIndex:stepIndex];
	return [record isKindOfClass:NSDictionary.class] ? (NSDictionary<NSString *, NSData *> *)record : nil;
}

- (void)setTransforms:(NSDictionary<NSString *, NSData *> *)transforms forStep:(NSInteger)stepIndex
{
	if (transforms.count == 0) {
		return;
	}
	[_frameData setRecord:[transforms copy] atIndex:stepIndex];
}

- (void)invalidate
{
	for (NSNumber *index in [_frameData.frameIndexes copy]) {
		[_frameData removeRecordAtIndex:index.integerValue];
	}
}

- (void)invalidateIfSignatureChanged:(NSString *)signature
{
	NSString *stored = [_frameData objectForKey:FxGripPhysicsStoreSignatureKey];
	if (stored != nil && [stored isEqualToString:signature]) {
		return;
	}
	[self invalidate];
	[_frameData setObject:signature forKey:FxGripPhysicsStoreSignatureKey];
}

@end
