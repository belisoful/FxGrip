/*!
	@file       FxMatrix44.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-10
	@header     FxMatrix44
	@abstract   Test-only implementation of FxPlug's FxMatrix44.
	@discussion Introduced in FxGrip 0.1.0. Implements the interface Apple declares in
	            FxMatrix.h: identity, data and copy initializers, inversion with partial pivoting,
	            row-vector point transforms, transposition, secure coding, and copying.
*/

#import "FxPlugStub.h"

static const NSUInteger FxMatrix44StubElementCount = 16;

@implementation FxMatrix44

#pragma mark - Construction

- (id)init
{
	self = [super init];
	if (self != nil) {
		[self setToIdentity];
	}
	return self;
}

- (id)initWithMatrix44Data:(Matrix44Data)newMatrix
{
	self = [super init];
	if (self != nil) {
		memcpy(_mat, newMatrix, sizeof(Matrix44Data));
	}
	return self;
}

- (id)initWithColorMatrix44Data:(Matrix44Data)newMatrix
{
	return [self initWithMatrix44Data:newMatrix];
}

- (id)initWithFxMatrix:(FxMatrix44 *)newFxMatrix
{
	return [self initWithMatrix44Data:*[newFxMatrix matrix]];
}

- (instancetype)initWithInverseOfFxMatrix:(FxMatrix44 *)matrixToInvert
{
	self = [self initWithFxMatrix:matrixToInvert];
	if (self != nil && ![self invert]) {
		return nil;
	}
	return self;
}

+ (instancetype)stubMatrixWithScale:(double)scale
{
	return [self stubMatrixWithScaleX:scale scaleY:scale translationX:0.0 translationY:0.0];
}

+ (instancetype)stubMatrixWithScaleX:(double)scaleX
							  scaleY:(double)scaleY
						translationX:(double)translationX
						translationY:(double)translationY
{
	FxMatrix44 *matrix = [[self alloc] init];
	matrix->_mat[0][0] = scaleX;
	matrix->_mat[1][1] = scaleY;
	matrix->_mat[3][0] = translationX;
	matrix->_mat[3][1] = translationY;
	return matrix;
}

#pragma mark - Data

- (void)setToIdentity
{
	memset(_mat, 0, sizeof(Matrix44Data));
	for (NSUInteger index = 0; index < 4; index++) {
		_mat[index][index] = 1.0;
	}
}

- (void)setMatrix:(Matrix44Data)newMatrix
{
	memcpy(_mat, newMatrix, sizeof(Matrix44Data));
}

- (Matrix44Data *)matrix
{
	return &_mat;
}

- (void)transpose
{
	Matrix44Data transposed;
	for (NSUInteger row = 0; row < 4; row++) {
		for (NSUInteger column = 0; column < 4; column++) {
			transposed[column][row] = _mat[row][column];
		}
	}
	memcpy(_mat, transposed, sizeof(Matrix44Data));
}

#pragma mark - Inversion

- (BOOL)invert
{
	return [self invertColorMatrixWithTolerance:0.0];
}

/*! Gauss-Jordan elimination with partial pivoting; a pivot at or below the tolerance fails. */
- (BOOL)invertColorMatrixWithTolerance:(double)tolerance
{
	Matrix44Data work;
	Matrix44Data inverse;
	memcpy(work, _mat, sizeof(Matrix44Data));
	memset(inverse, 0, sizeof(Matrix44Data));
	for (NSUInteger index = 0; index < 4; index++) {
		inverse[index][index] = 1.0;
	}

	for (NSUInteger column = 0; column < 4; column++) {
		NSUInteger pivotRow = column;
		for (NSUInteger row = column + 1; row < 4; row++) {
			if (fabs(work[row][column]) > fabs(work[pivotRow][column])) {
				pivotRow = row;
			}
		}
		if (fabs(work[pivotRow][column]) <= tolerance) {
			return NO;
		}
		if (pivotRow != column) {
			for (NSUInteger swapColumn = 0; swapColumn < 4; swapColumn++) {
				double workValue = work[column][swapColumn];
				work[column][swapColumn] = work[pivotRow][swapColumn];
				work[pivotRow][swapColumn] = workValue;

				double inverseValue = inverse[column][swapColumn];
				inverse[column][swapColumn] = inverse[pivotRow][swapColumn];
				inverse[pivotRow][swapColumn] = inverseValue;
			}
		}

		double pivot = work[column][column];
		for (NSUInteger scaleColumn = 0; scaleColumn < 4; scaleColumn++) {
			work[column][scaleColumn] /= pivot;
			inverse[column][scaleColumn] /= pivot;
		}

		for (NSUInteger row = 0; row < 4; row++) {
			if (row == column) {
				continue;
			}
			double factor = work[row][column];
			if (factor == 0.0) {
				continue;
			}
			for (NSUInteger eliminateColumn = 0; eliminateColumn < 4; eliminateColumn++) {
				work[row][eliminateColumn] -= factor * work[column][eliminateColumn];
				inverse[row][eliminateColumn] -= factor * inverse[column][eliminateColumn];
			}
		}
	}

	memcpy(_mat, inverse, sizeof(Matrix44Data));
	return YES;
}

#pragma mark - Transforms

- (FxPoint2D)transform2DPoint:(FxPoint2D)inPoint
{
	FxPoint3D result = [self transform3DPoint:(FxPoint3D){ inPoint.x, inPoint.y, 0.0 }];
	return (FxPoint2D){ result.x, result.y };
}

- (FxPoint3D)transform3DPoint:(FxPoint3D)inPoint
{
	double input[4] = { inPoint.x, inPoint.y, inPoint.z, 1.0 };
	double output[4] = { 0.0, 0.0, 0.0, 0.0 };
	for (NSUInteger column = 0; column < 4; column++) {
		for (NSUInteger row = 0; row < 4; row++) {
			output[column] += input[row] * _mat[row][column];
		}
	}
	if (output[3] != 0.0 && output[3] != 1.0) {
		output[0] /= output[3];
		output[1] /= output[3];
		output[2] /= output[3];
	}
	return (FxPoint3D){ output[0], output[1], output[2] };
}

#pragma mark - Equality

- (BOOL)isEqualToMatrix:(FxMatrix44 *)other
{
	if (other == nil) {
		return NO;
	}
	return memcmp(_mat, other->_mat, sizeof(Matrix44Data)) == 0;
}

- (BOOL)isEqual:(id)object
{
	if (object == self) {
		return YES;
	}
	if (![object isKindOfClass:FxMatrix44.class]) {
		return NO;
	}
	return [self isEqualToMatrix:object];
}

- (NSUInteger)hash
{
	NSUInteger hash = 17;
	const double *values = &_mat[0][0];
	for (NSUInteger index = 0; index < FxMatrix44StubElementCount; index++) {
		hash = hash * 31 + [@(values[index]) hash];
	}
	return hash;
}

- (NSString *)description
{
	NSMutableString *description = [NSMutableString stringWithFormat:@"<%@ %p", self.className, self];
	for (NSUInteger row = 0; row < 4; row++) {
		[description appendFormat:@" [%g %g %g %g]", _mat[row][0], _mat[row][1], _mat[row][2], _mat[row][3]];
	}
	[description appendString:@">"];
	return description;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	return [[self.class allocWithZone:zone] initWithMatrix44Data:_mat];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBytes:(const uint8_t *)_mat length:sizeof(Matrix44Data) forKey:@"mat"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	NSUInteger length = 0;
	const uint8_t *bytes = [coder decodeBytesForKey:@"mat" returnedLength:&length];
	if (bytes == NULL || length != sizeof(Matrix44Data)) {
		return nil;
	}
	Matrix44Data data;
	memcpy(data, bytes, sizeof(Matrix44Data));
	return [self initWithMatrix44Data:data];
}

@end
