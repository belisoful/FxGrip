//
//  FxGripGroupParameter.h
//  PlugIn
//
//  Created by Apple on 2/12/20.
//  Copyright © 2024 Belisoful All rights reserved.
//

#ifndef FxGripGroupParameter_h
#define FxGripGroupParameter_h

#import <FxParameter.h>


@interface FxGripGroupParameter : FxParameter <FxSubParameters>
{
	@protected
	NSMutableArray *_children;
}

@property (readwrite, nonatomic) BOOL flagCollapsed;

+ (nullable NSString*)parameterTypeString;
+ (FxParameterType)parameterType;
+ (BOOL)addParameter:(nonnull NSDictionary *)parameter toEffect:(nonnull id<FxTileableEffectBase>)effect;


// ***  FxGripSubParameters Implementation  ***
- (NSUInteger)count;
- (nonnull NSArray<id<FxParameter>>*)children;
- (NSUInteger)allCount;
- (nonnull NSArray<id<FxParameter>>*)allChildren;
- (id<FxParameter> _Nullable)objectAtIndexedSubscript:(NSInteger)index;
- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState *_Nonnull) enumerationState
								   objects: (id _Nonnull __unsafe_unretained [_Nullable]) stackBuffer
									 count: (NSUInteger) len;

@end

#endif
