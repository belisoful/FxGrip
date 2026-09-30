/*!
	@file       FxGripShaderMetadata.m
	@copyright  Copyright © 2024 Belisoful All rights reserved.
	@author     belisoful
	@date       2026-09-29
	@header     FxGripShaderMetadata
	@abstract   Implements the shader metadata scanner: block discovery, JSON5 parsing, and validation.
	@discussion Introduced in FxGrip 0.1.0. The scanner locates each sentinel block, parses its body,
	            and hands the object to a private validator. The validator merges the blocks, checks
	            each parameter record, indexes the records by ID and by key, and resolves the color
	            space. The first failure stops the scan and reports the failing block's line.
*/

#import "FxGripShaderMetadata.h"
#import "FxGripParameterUtility.h"
#import "FxGripErrors.h"
#import "FxGrip_ARC.h"

NSString * const FxGripShaderMetadataErrorLineKey = @"FxGripShaderMetadataErrorLine";

static NSError *FxGripShaderMetadataError(NSInteger code, NSUInteger line, NSString *reason, NSError *underlying)
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	userInfo[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"Shader metadata at line %lu: %@", (unsigned long)line, reason];
	userInfo[NSLocalizedFailureReasonErrorKey] = reason;
	userInfo[FxGripShaderMetadataErrorLineKey] = @(line);
	if (underlying != nil) {
		userInfo[NSUnderlyingErrorKey] = underlying;
	}
	return [NSError errorWithDomain:FxGripPlugErrorDomain code:code userInfo:userInfo];
}

static NSRegularExpression *FxGripShaderBlockOpener(void)
{
	static NSRegularExpression *opener = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSString *pattern = [NSString stringWithFormat:@"^[ \\t]*/\\*!?[ \\t]*%@\\b", kFxGripShaderBlockSentinel];
		opener = NARC_RETAIN([NSRegularExpression regularExpressionWithPattern:pattern
																	   options:NSRegularExpressionAnchorsMatchLines
																		 error:NULL]);
	});
	return opener;
}

static NSRegularExpression *FxGripShaderIdentifierPattern(void)
{
	static NSRegularExpression *identifier = nil;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		identifier = NARC_RETAIN([NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z_][A-Za-z0-9_]*$"
																		  options:0
																			error:NULL]);
	});
	return identifier;
}

static NSUInteger FxGripShaderLineAtLocation(NSString *source, NSUInteger location)
{
	NSUInteger line = 1;
	NSRange search = NSMakeRange(0, location);
	NSRange found = [source rangeOfString:@"\n" options:NSLiteralSearch range:search];
	while (found.location != NSNotFound) {
		line += 1;
		search = NSMakeRange(NSMaxRange(found), location - NSMaxRange(found));
		found = [source rangeOfString:@"\n" options:NSLiteralSearch range:search];
	}
	return line;
}

static BOOL FxGripShaderIsBoolean(id value)
{
	return [value isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL FxGripShaderIntegerValue(id value, long long *outValue)
{
	if (![value isKindOfClass:NSNumber.class] || FxGripShaderIsBoolean(value)) {
		return NO;
	}
	double number = [(NSNumber *)value doubleValue];
	if (!isfinite(number) || number != floor(number)) {
		return NO;
	}
	*outValue = [(NSNumber *)value longLongValue];
	return YES;
}

static FxParameterType FxGripShaderResolvedType(id value)
{
	if (FxGripShaderIsBoolean(value)) {
		return FxParameterType_None;
	}
	if ([value isKindOfClass:NSNumber.class]) {
		return [(NSNumber *)value intValue];
	}
	if ([value isKindOfClass:NSString.class]) {
		return [FxGripParameterUtility parameterTypeFromString:value];
	}
	return FxParameterType_None;
}

static BOOL FxGripShaderTypeIsDiscrete(FxParameterType type)
{
	switch (type) {
		case FxParameterType_Int:
		case FxParameterType_Toggle:
		case FxParameterType_Menu:
		case FxParameterType_Switch:
			return YES;
		default:
			return NO;
	}
}

static BOOL FxGripShaderTypeIsContinuous(FxParameterType type)
{
	switch (type) {
		case FxParameterType_Float:
		case FxParameterType_Percent:
		case FxParameterType_Angle:
		case FxParameterType_RGB:
		case FxParameterType_RGBA:
		case FxParameterType_Point:
			return YES;
		default:
			return NO;
	}
}

#pragma mark - Validator

/*! Merges metadata blocks and validates them, accumulating the parameter indexes. */
@interface FxGripShaderMetadataValidator : NSObject
@property (nonatomic, readonly) NSMutableDictionary<NSString *, id> *properties;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSNumber *> *propertyLines;
@property (nonatomic, readonly) NSMutableArray<NSDictionary *> *parameters;
@property (nonatomic, readonly) NSMutableArray<NSDictionary *> *allParameters;
@property (nonatomic, readonly) NSMutableDictionary<NSNumber *, NSDictionary *> *parametersByID;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSDictionary *> *parametersByKey;
@property (nonatomic, assign) FxImageColorInfo processingColorInfo;
@property (nonatomic, assign) FxGripShaderPrimaries primaries;
@end

@implementation FxGripShaderMetadataValidator

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_properties = [NSMutableDictionary new];
		_propertyLines = [NSMutableDictionary new];
		_parameters = [NSMutableArray new];
		_allParameters = [NSMutableArray new];
		_parametersByID = [NSMutableDictionary new];
		_parametersByKey = [NSMutableDictionary new];
		_processingColorInfo = kFxImageColorInfo_RGB_LINEAR;
		_primaries = FxGripShaderPrimariesHost;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_properties);
	NARC_RELEASE(_propertyLines);
	NARC_RELEASE(_parameters);
	NARC_RELEASE(_allParameters);
	NARC_RELEASE(_parametersByID);
	NARC_RELEASE(_parametersByKey);
	SUPER_DEALLOC();
}

- (nullable NSError *)addBlock:(NSDictionary<NSString *, id> *)block line:(NSUInteger)line
{
	for (NSString *name in block) {
		id value = block[name];
		if ([name isEqualToString:kFxGripShaderProperty_Parameters]) {
			NSError *failure = [self addParameterList:value toList:self.parameters line:line];
			if (failure != nil) {
				return failure;
			}
			continue;
		}
		if (self.properties[name] != nil) {
			return FxGripShaderMetadataError(kFxGripError_ShaderMetadataInvalid, line,
				[NSString stringWithFormat:@"\"%@\" is declared in more than one block.", name], nil);
		}
		self.properties[name] = value;
		self.propertyLines[name] = @(line);
	}
	return nil;
}

- (nullable NSError *)addParameterList:(id)list toList:(nullable NSMutableArray *)destination line:(NSUInteger)line
{
	if (![list isKindOfClass:NSArray.class]) {
		return FxGripShaderMetadataError(kFxGripError_ShaderMetadataInvalid, line, @"\"parameters\" must be an array.", nil);
	}
	NSUInteger index = 0;
	for (id entry in (NSArray *)list) {
		NSError *failure = [self addParameter:entry index:index line:line];
		if (failure != nil) {
			return failure;
		}
		[destination addObject:entry];
		index += 1;
	}
	return nil;
}

- (nullable NSError *)addParameter:(id)entry index:(NSUInteger)index line:(NSUInteger)line
{
	if (![entry isKindOfClass:NSDictionary.class]) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"the parameter at index %lu is not an object.", (unsigned long)index]];
	}
	NSDictionary *parameter = entry;

	long long parameterID = 0;
	if (!FxGripShaderIntegerValue(parameter[kFxParameterProperty_Id], &parameterID)
		|| parameterID < 1 || parameterID > kFxGripShaderParameterIdMaximum) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"the parameter at index %lu needs an integer \"id\" from 1 through %d.",
												(unsigned long)index, kFxGripShaderParameterIdMaximum]];
	}
	NSString *label = [NSString stringWithFormat:@"parameter %lld", parameterID];
	if (self.parametersByID[@(parameterID)] != nil) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ repeats an \"id\".", label]];
	}

	FxParameterType type = FxGripShaderResolvedType(parameter[kFxParameterProperty_Type]);
	if (type == FxParameterType_None) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ needs a \"type\" that names a parameter type.", label]];
	}
	if (![parameter[kFxParameterProperty_Name] isKindOfClass:NSString.class]) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ needs a string \"name\".", label]];
	}

	NSError *failure = [self validateBindingOfParameter:parameter type:type label:label line:line];
	if (failure != nil) {
		return failure;
	}

	self.parametersByID[@(parameterID)] = parameter;
	NSString *key = parameter[kFxGripShaderProperty_Key];
	if (key != nil) {
		self.parametersByKey[key] = parameter;
	}
	[self.allParameters addObject:parameter];

	return [self addChildrenOfParameter:parameter type:type label:label line:line];
}

- (nullable NSError *)validateBindingOfParameter:(NSDictionary *)parameter
											type:(FxParameterType)type
										   label:(NSString *)label
											line:(NSUInteger)line
{
	id key = parameter[kFxGripShaderProperty_Key];
	if (key != nil) {
		if (![key isKindOfClass:NSString.class]
			|| [FxGripShaderIdentifierPattern() numberOfMatchesInString:key options:0 range:NSMakeRange(0, [(NSString *)key length])] == 0) {
			return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ has a \"key\" that is not a C identifier.", label]];
		}
		if (self.parametersByKey[key] != nil) {
			return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ repeats the \"key\" \"%@\".", label, key]];
		}
	}

	id constant = parameter[kFxGripShaderProperty_Constant];
	id allowContinuous = parameter[kFxGripShaderProperty_AllowContinuousConstant];
	if (constant != nil && !FxGripShaderIsBoolean(constant)) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ has a \"constant\" that is not a boolean.", label]];
	}
	if (allowContinuous != nil && !FxGripShaderIsBoolean(allowContinuous)) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ has an \"allowContinuousConstant\" that is not a boolean.", label]];
	}
	if (![constant boolValue]) {
		return nil;
	}
	if (key == nil) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ is a constant and needs a \"key\".", label]];
	}
	if (FxGripShaderTypeIsDiscrete(type)) {
		return nil;
	}
	if (FxGripShaderTypeIsContinuous(type)) {
		if ([allowContinuous boolValue]) {
			return nil;
		}
		return [self invalidAtLine:line reason:[NSString stringWithFormat:
			@"%@ is a continuous type and compiles a pipeline for each value as a constant. Set \"allowContinuousConstant\" to permit it.", label]];
	}
	return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ has a type that cannot be a constant.", label]];
}

- (nullable NSError *)addChildrenOfParameter:(NSDictionary *)parameter
										type:(FxParameterType)type
									   label:(NSString *)label
										line:(NSUInteger)line
{
	id children = parameter[kFxParameterProperty_GroupParameters];
	if (children == nil) {
		return nil;
	}
	if (type != FxParameterType_Group) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ nests parameters and is not a group.", label]];
	}
	// Group children must be ordered; the configuration flattener also accepts an unordered dictionary.
	if (![children isKindOfClass:NSArray.class]) {
		return [self invalidAtLine:line reason:[NSString stringWithFormat:@"%@ nests parameters in a value that is not an array.", label]];
	}
	return [self addParameterList:children toList:nil line:line];
}

- (nullable NSError *)finish
{
	NSError *failure = [self validateVersion];
	if (failure != nil) {
		return failure;
	}
	failure = [self validateColorSpace];
	if (failure != nil) {
		return failure;
	}
	if (self.parameters.count > 0) {
		self.properties[kFxGripShaderProperty_Parameters] = self.parameters.copy;
	}
	return nil;
}

- (nullable NSError *)validateVersion
{
	id version = self.properties[kFxGripShaderProperty_Version];
	if (version == nil) {
		return nil;
	}
	long long number = 0;
	if (!FxGripShaderIntegerValue(version, &number) || number < 1 || number > kFxGripShaderMetadataVersion) {
		return [self invalidAtLine:[self lineOfProperty:kFxGripShaderProperty_Version]
							reason:[NSString stringWithFormat:@"\"version\" must be an integer from 1 through %d.", kFxGripShaderMetadataVersion]];
	}
	return nil;
}

- (nullable NSError *)validateColorSpace
{
	id colorSpace = self.properties[kFxGripShaderProperty_ColorSpace];
	if (colorSpace == nil) {
		return nil;
	}
	NSUInteger line = [self lineOfProperty:kFxGripShaderProperty_ColorSpace];
	if (![colorSpace isKindOfClass:NSDictionary.class]) {
		return [self invalidAtLine:line reason:@"\"colorSpace\" must be an object."];
	}
	for (NSString *name in (NSDictionary *)colorSpace) {
		if (![name isEqualToString:kFxGripShaderProperty_Transfer] && ![name isEqualToString:kFxGripShaderProperty_Primaries]) {
			return [self invalidAtLine:line reason:[NSString stringWithFormat:@"\"colorSpace\" has the unknown key \"%@\".", name]];
		}
	}

	NSDictionary<NSString *, NSNumber *> *transfers = @{
		kFxGripShaderTransfer_Linear: @(kFxImageColorInfo_RGB_LINEAR),
		kFxGripShaderTransfer_Gamma: @(kFxImageColorInfo_RGB_GAMMA_VIDEO),
	};
	id transfer = colorSpace[kFxGripShaderProperty_Transfer];
	if (transfer != nil) {
		NSNumber *colorInfo = [transfer isKindOfClass:NSString.class] ? transfers[transfer] : nil;
		if (colorInfo == nil) {
			return [self invalidAtLine:line reason:@"\"transfer\" must be \"linear\" or \"gamma\"."];
		}
		self.processingColorInfo = colorInfo.unsignedIntegerValue;
	}

	NSDictionary<NSString *, NSNumber *> *primarySets = @{
		kFxGripShaderPrimaries_Host: @(FxGripShaderPrimariesHost),
		kFxGripShaderPrimaries_Rec709: @(FxGripShaderPrimariesRec709),
		kFxGripShaderPrimaries_Rec2020: @(FxGripShaderPrimariesRec2020),
	};
	id primaries = colorSpace[kFxGripShaderProperty_Primaries];
	if (primaries != nil) {
		NSNumber *primarySet = [primaries isKindOfClass:NSString.class] ? primarySets[primaries] : nil;
		if (primarySet == nil) {
			return [self invalidAtLine:line reason:@"\"primaries\" must be \"host\", \"rec709\", or \"rec2020\"."];
		}
		self.primaries = primarySet.integerValue;
	}
	return nil;
}

- (NSUInteger)lineOfProperty:(NSString *)name
{
	return self.propertyLines[name].unsignedIntegerValue;
}

- (NSError *)invalidAtLine:(NSUInteger)line reason:(NSString *)reason
{
	return FxGripShaderMetadataError(kFxGripError_ShaderMetadataInvalid, line, reason, nil);
}

@end

#pragma mark - Metadata

/*!
	@abstract	The parsed and validated metadata blocks of one shader source.
	@discussion	Introduced in FxGrip 0.1.0. The metadata is immutable once scanned.
*/
@implementation FxGripShaderMetadata
{
	NSDictionary<NSNumber *, NSDictionary *> *_parametersByID;
	NSDictionary<NSString *, NSDictionary *> *_parametersByKey;
}

+ (nullable instancetype)metadataWithSource:(NSString *)source error:(NSError * _Nullable *)error
{
	FxGripShaderMetadataValidator *validator = NARC_AUTORELEASE([FxGripShaderMetadataValidator new]);
	NSUInteger blockCount = 0;
	NSError *failure = nil;

	NSUInteger searchStart = 0;
	while (failure == nil && searchStart < source.length) {
		NSTextCheckingResult *opener = [FxGripShaderBlockOpener() firstMatchInString:source options:0
																			 range:NSMakeRange(searchStart, source.length - searchStart)];
		if (opener == nil) {
			break;
		}
		NSUInteger line = FxGripShaderLineAtLocation(source, opener.range.location);
		NSUInteger bodyStart = NSMaxRange(opener.range);
		NSRange close = [source rangeOfString:@"*/" options:NSLiteralSearch range:NSMakeRange(bodyStart, source.length - bodyStart)];
		if (close.location == NSNotFound) {
			failure = FxGripShaderMetadataError(kFxGripError_ShaderMetadataMalformed, line, @"the block has no comment close.", nil);
			break;
		}
		NSString *body = [source substringWithRange:NSMakeRange(bodyStart, close.location - bodyStart)];
		NSDictionary *block = [self blockFromBody:body line:line error:&failure];
		if (block != nil) {
			failure = [validator addBlock:block line:line];
			blockCount += 1;
		}
		searchStart = NSMaxRange(close);
	}

	if (failure == nil) {
		failure = [validator finish];
	}
	if (failure != nil) {
		if (error != NULL) {
			*error = failure;
		}
		return nil;
	}
	return NARC_AUTORELEASE([[self alloc] initWithValidator:validator blockCount:blockCount]);
}

+ (nullable instancetype)metadataWithContentsOfURL:(NSURL *)url error:(NSError * _Nullable *)error
{
	NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
	if (source == nil) {
		return nil;
	}
	return [self metadataWithSource:source error:error];
}

+ (nullable NSDictionary *)blockFromBody:(NSString *)body line:(NSUInteger)line error:(NSError **)error
{
	NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
	NSError *parseError = nil;
	id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingJSON5Allowed error:&parseError];
	if (object == nil) {
		*error = FxGripShaderMetadataError(kFxGripError_ShaderMetadataMalformed, line, @"the block is not valid JSON5.", parseError);
		return nil;
	}
	if (![object isKindOfClass:NSDictionary.class]) {
		*error = FxGripShaderMetadataError(kFxGripError_ShaderMetadataMalformed, line, @"the block is not a JSON object.", nil);
		return nil;
	}
	return object;
}

- (instancetype)initWithValidator:(FxGripShaderMetadataValidator *)validator blockCount:(NSUInteger)blockCount
{
	self = [super init];
	if (self != nil) {
		_parameters = [validator.parameters copy];
		_allParameters = [validator.allParameters copy];
		_properties = [validator.properties copy];
		_parametersByID = [validator.parametersByID copy];
		_parametersByKey = [validator.parametersByKey copy];
		_blockCount = blockCount;
		_processingColorInfo = validator.processingColorInfo;
		_primaries = validator.primaries;
	}
	return self;
}

- (void)dealloc
{
	NARC_RELEASE(_parameters);
	NARC_RELEASE(_allParameters);
	NARC_RELEASE(_properties);
	NARC_RELEASE(_parametersByID);
	NARC_RELEASE(_parametersByKey);
	SUPER_DEALLOC();
}

- (nullable NSDictionary<NSString *, id> *)parameterForKey:(NSString *)key
{
	return _parametersByKey[key];
}

- (nullable NSDictionary<NSString *, id> *)parameterWithID:(FxParameterId)parameterID
{
	return _parametersByID[@(parameterID)];
}

@end
