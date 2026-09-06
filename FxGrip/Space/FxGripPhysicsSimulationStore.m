/*!
	@file       FxGripPhysicsSimulationStore.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-06
	@header     FxGripPhysicsSimulationStore
	@abstract   Implements the in-memory and FxGripFrameData-backed physics simulation stores.
	@discussion Introduced in FxGrip 0.1.0. The memory store guards a step dictionary with a lock and
	            discards steps when its signature changes. The frame-data store maps each step to a
	            record in an FxGripFrameData and keeps the signature under a reserved key, so the bake
	            persists with the document.
*/

#import "FxGripPhysicsSimulationStore.h"
#import "FxGripFrameData.h"
#import "FxGrip_ARC.h"

static NSString * const FxGripPhysicsStoreSignatureKey = @"__physicsSignature";

#pragma mark - Memory store

/*!
	@abstract	A thread-safe in-memory step store; the session cache that does not persist.
	@discussion	Introduced in FxGrip 0.1.0. A lock guards the step dictionary and the stored signature.
*/
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

/*! @abstract The stored body transforms at a step index, or nil on a miss. */
- (nullable NSDictionary<NSString *, NSData *> *)transformsForStep:(NSInteger)stepIndex
{
	[_lock lock];
	NSDictionary<NSString *, NSData *> *transforms = _steps[@(stepIndex)];
	[_lock unlock];
	return transforms;
}

/*! @abstract Stores the body transforms at a step index; an empty map is ignored. */
- (void)setTransforms:(NSDictionary<NSString *, NSData *> *)transforms forStep:(NSInteger)stepIndex
{
	if (transforms.count == 0) {
		return;
	}
	[_lock lock];
	_steps[@(stepIndex)] = [transforms copy];
	[_lock unlock];
}

/*! @abstract Removes every stored step. */
- (void)invalidate
{
	[_lock lock];
	[_steps removeAllObjects];
	[_lock unlock];
}

/*! @abstract Clears the store when `signature` differs from the stored one, then records `signature`. */
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

/*!
	@abstract	A step store backed by an FxGripFrameData, so the bake persists with the host document.
	@discussion	Introduced in FxGrip 0.1.0. Each step maps to a frame-data record; the signature lives
				under a reserved key.
*/
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

/*! @abstract The stored transforms at a step index, read from the matching frame-data record; nil on a miss or a non-dictionary record. */
- (nullable NSDictionary<NSString *, NSData *> *)transformsForStep:(NSInteger)stepIndex
{
	NSObject<NSSecureCoding, NSCopying> *record = [_frameData recordAtIndex:stepIndex];
	return [record isKindOfClass:NSDictionary.class] ? (NSDictionary<NSString *, NSData *> *)record : nil;
}

/*! @abstract Stores the transforms as the frame-data record at a step index; an empty map is ignored. */
- (void)setTransforms:(NSDictionary<NSString *, NSData *> *)transforms forStep:(NSInteger)stepIndex
{
	if (transforms.count == 0) {
		return;
	}
	[_frameData setRecord:[transforms copy] atIndex:stepIndex];
}

/*! @abstract Removes every stored step record from the frame data. */
- (void)invalidate
{
	for (NSNumber *index in [_frameData.frameIndexes copy]) {
		[_frameData removeRecordAtIndex:index.integerValue];
	}
}

/*! @abstract Clears the records when `signature` differs from the stored one, then records `signature`. */
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
