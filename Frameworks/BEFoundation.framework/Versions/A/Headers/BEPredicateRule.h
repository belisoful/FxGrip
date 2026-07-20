/*!
 @header		BEPredicateRule.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		This checks an object against an array or set of BEPredicateRule to check if the object is accepted, rejected, or NA.
*/

#ifndef BEPredicateRule_h
#define BEPredicateRule_h

#import <Foundation/Foundation.h>
#import <BEFoundation/BEPriorityExtensions.h>

extern NSInteger	const  BEPredicateRuleDefaultPriority;


/*!
 @typedef		BEPredicateRuleOutcome
 @abstract		This is the result of checking a collection (NSArray, NSSet, NSOrderedSet)
				of BEPredicateRules.
				If a rule set is not matched `BEPredicateRuleNA` is returned.
				If a rule is matched in a rule set, then its outcome is returned as
				`BEPredicateRuleAccept` (value: 1) or
				`BEPredicateRuleReject` (value: -1)
 */
typedef NSInteger BEPredicateRuleOutcome;
NS_ENUM(BEPredicateRuleOutcome) {
	BEPredicateRuleReject = -1,
	BEPredicateRuleNA = 0,
	BEPredicateRuleAccept = 1,
};





/*!
 @interface		BEPredicateRule
 @abstract		An NSPredicate paired with an outcome (accept, reject, or N/A) and a sortable priority.
 @discussion	Collect rules in an NSArray, NSSet, or NSOrderedSet and ask for the outcome of the
				highest-priority matching rule with -ruleOutcomeWithObject:. Rules are evaluated in
				ascending priority order; the first match with a non-N/A outcome wins.

				@code
				NSArray *rules = @[
					[BEPredicateRule ruleWithOutcome:BEPredicateRuleReject priorityInteger:0 format:@"age < %d", 18],
					[BEPredicateRule ruleWithOutcome:BEPredicateRuleAccept priorityInteger:10 format:@"age >= %d", 18],
				];
				BEPredicateRuleOutcome outcome = [rules ruleOutcomeWithObject:@{@"age": @21}];
				// outcome == BEPredicateRuleAccept
				@endcode
 */
@interface BEPredicateRule : NSPredicate <NSSecureCoding, NSCopying, BEPriorityItem>

/*!
 @property		predicate
 @abstract		The NSPredicate this rule evaluates.
 */
@property (readonly, nonnull) NSPredicate *predicate;

/*!
 @property		outcome
 @abstract		The outcome reported for this rule when its predicate matches.
 */
@property (readwrite, nonatomic) BEPredicateRuleOutcome outcome;


/*!
 @property		defaultItemPriority
 @abstract		The priority used when `itemPriority` is unset: `BEPredicateRuleDefaultPriority`.
 */
@property (readonly, nonatomic, nonnull) NSNumber *defaultItemPriority;

/*!
 @property		itemPriority
 @abstract		The rule's sort priority within a rule set, or `defaultItemPriority` when unset.
 @discussion	Rules are evaluated in ascending priority order. `itemPriorityInteger` and
				`itemPriorityDouble` are convenience accessors for the same underlying value.
 */
@property (readwrite, nonatomic, nullable) NSNumber *itemPriority;
@property (readwrite, nonatomic) NSInteger itemPriorityInteger;
@property (readwrite, nonatomic) double itemPriorityDouble;

/*!
 @property		isUniqueItemPriority
 @abstract		Whether `itemPriority` participates in `-isEqual:` and `-hash`. Default NO.
 @discussion	Two rules are equal only when this flag matches on both. When YES, their
				priorities must also match, which lets the same rule appear with different
				priorities in an NSSet or NSOrderedSet.
 */
@property (readwrite) BOOL isUniqueItemPriority;

+ (BOOL)supportsSecureCoding;

+ (nonnull BEPredicateRule *)ruleWithFormat:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithOutcome:(BEPredicateRuleOutcome)outcome format:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithPriority:(NSNumber * _Nonnull)priority format:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithPriorityInteger:(NSInteger)priority format:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithPriorityDouble:(double)priority format:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithOutcome:(BEPredicateRuleOutcome)outcome priority:(NSNumber * _Nonnull)priority format:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithOutcome:(BEPredicateRuleOutcome)outcome priorityInteger:(NSInteger)priority format:(NSString * _Nonnull)predicateFormat, ...;
+ (nonnull BEPredicateRule *)ruleWithOutcome:(BEPredicateRuleOutcome)outcome priorityDouble:(double)priority format:(NSString * _Nonnull)predicateFormat, ...;

// Parse predicateFormat and return an appropriate predicate
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments outcome:(BEPredicateRuleOutcome)outcome;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments priority:(NSNumber * _Nonnull)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments priorityInteger:(NSInteger)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments priorityDouble:(double)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments outcome:(BEPredicateRuleOutcome)outcome priority:(NSNumber * _Nonnull)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments outcome:(BEPredicateRuleOutcome)outcome priorityInteger:(NSInteger)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments outcome:(BEPredicateRuleOutcome)outcome priorityDouble:(double)priority;

+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList outcome:(BEPredicateRuleOutcome)outcome;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList priority:(NSNumber * _Nonnull)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList priorityInteger:(NSInteger)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList priorityDouble:(double)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList outcome:(BEPredicateRuleOutcome)outcome priority:(NSNumber * _Nonnull)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList outcome:(BEPredicateRuleOutcome)outcome priorityInteger:(NSInteger)priority;
+ (nonnull BEPredicateRule *)ruleWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList outcome:(BEPredicateRuleOutcome)outcome priorityDouble:(double)priority;

+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value;    // return predicates that always evaluate to true/false
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value outcome:(BEPredicateRuleOutcome)outcome;    // return predicates that always evaluate to true/false
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value priority:(NSNumber * _Nonnull)priority;
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value priorityInteger:(NSInteger)priority;
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value priorityDouble:(double)priority;
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value outcome:(BEPredicateRuleOutcome)outcome priority:(NSNumber * _Nonnull)priority;
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value outcome:(BEPredicateRuleOutcome)outcome priorityInteger:(NSInteger)priority;
+ (nonnull BEPredicateRule *)ruleWithValue:(BOOL)value outcome:(BEPredicateRuleOutcome)outcome priorityDouble:(double)priority;

+ (nonnull BEPredicateRule*)ruleWithBlock:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithOutcome:(BEPredicateRuleOutcome)outcome block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithPriority:(NSNumber * _Nonnull)priority block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithPriorityInteger:(NSInteger)priority block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithPriorityDouble:(double)priority block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithOutcome:(BEPredicateRuleOutcome)outcome priority:(NSNumber * _Nonnull)priority block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithOutcome:(BEPredicateRuleOutcome)outcome priorityInteger:(NSInteger)priority block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));
+ (nonnull BEPredicateRule*)ruleWithOutcome:(BEPredicateRuleOutcome)outcome priorityDouble:(double)priority block:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block API_AVAILABLE(macos(10.6), ios(4.0), watchos(2.0), tvos(9.0));


// NSPredicate methods unavailable
+ (nonnull NSPredicate *)predicateWithFormat:(nonnull NSString *)predicateFormat argumentArray:(nullable NSArray *)arguments NS_UNAVAILABLE;
+ (nonnull NSPredicate *)predicateWithFormat:(nonnull NSString *)predicateFormat, ... NS_UNAVAILABLE;
+ (nonnull NSPredicate *)predicateWithFormat:(nonnull NSString *)predicateFormat arguments:(va_list)argList NS_UNAVAILABLE;

+ (nullable NSPredicate *)predicateFromMetadataQueryString:(nonnull NSString *)queryString NS_UNAVAILABLE;

+ (nonnull NSPredicate *)predicateWithValue:(BOOL)value NS_UNAVAILABLE;    // return predicates that always evaluate to true/false

+ (nonnull NSPredicate*)predicateWithBlock:(BOOL (^ _Nonnull)(id _Nullable evaluatedObject, NSDictionary<NSString *, id> * _Nullable bindings))block NS_UNAVAILABLE;
// end NSPredicate methods unavailable

/*!
 @property		predicateFormat
 @abstract		The format string of the wrapped predicate.
 */
@property (readonly, nonatomic, copy, nonnull) NSString *predicateFormat;

- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate;

- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate outcome:(BEPredicateRuleOutcome)outcome;

- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate priority:(NSNumber * _Nonnull)priority;
- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate priorityInteger:(NSInteger)priority;
- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate priorityDouble:(double)priority;

- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate outcome:(BEPredicateRuleOutcome)outcome priority:(NSNumber * _Nonnull)priority;
- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate outcome:(BEPredicateRuleOutcome)outcome priorityInteger:(NSInteger)priority;
- (nullable instancetype)initWithPredicate:(NSPredicate * _Nonnull)predicate outcome:(BEPredicateRuleOutcome)outcome priorityDouble:(double)priority;

- (nullable instancetype)initWithCoder:(NSCoder * _Nonnull)coder;

- (void)encodeWithCoder:(NSCoder * _Nonnull)coder;

- (void)substitutePredicateVariables:(NSDictionary<NSString *, id> * _Nullable)variables;     // substitute constant values for variables
- (nonnull instancetype)ruleWithSubstitutionVariables:(NSDictionary<NSString *, id> * _Nullable)variables;

- (nonnull id)copyWithZone:(nullable NSZone *)zone;

- (BOOL)evaluateWithObject:(nullable id)object;    // evaluate a predicate against a single object

- (BOOL)evaluateWithObject:(nullable id)object substitutionVariables:(nullable NSDictionary<NSString *, id> *)bindings API_AVAILABLE(macos(10.5), ios(3.0), watchos(2.0), tvos(9.0)); // single pass evaluation substituting variables from the bindings dictionary for any variable expressions encountered

- (void)allowEvaluation API_AVAILABLE(macos(10.9), ios(7.0), watchos(2.0), tvos(9.0)); // Force a predicate which was securely decoded to allow evaluation

@end



/*!
 @category		BEPredicateRuleSupport
 @abstract		This implements a Rule set of `BEPredicateRule` where it orders the
				rules, and matches to the first (lowest) priority rule and
				returns the `BEPredicateRuleOutcome` of its outcome.
				If no rule is matched, `BEPredicateRuleNA` is returned.
 */
@interface NSArray (BEPredicateRuleSupport)

/*!
 @method		-ruleOutcomeWithObject:
 @abstract		This loops through the internal BEPredicateRule elements (non-BEPredicateRule elements are ignored)
 				in priority order (lowest first) and returns the outcome of the first matching.
 @param		object	The object to test against the predicates.
 @result		Returns `BEPredicateRuleOutcome` based on the object matching
 				a rule, it's outcome, and if there is no match.
 */
- (BEPredicateRuleOutcome)ruleOutcomeWithObject:(nullable id)object;

/*!
 @method		-ruleOutcomeWithObject:
 @abstract		This loops through the internal BEPredicateRule elements (non-BEPredicateRule elements are ignored)
				in priority order (lowest first) and returns the outcome of the first matching.
 @param		object		The object to test against the predicates.
 @param		bindings	The bindings to replace any variable expressions. Every variable
 				in every `NSPredicate`/`BEPredicateRule`
 @result		Returns `BEPredicateRuleOutcome` based on the object matching
				a rule, it's outcome, and if there is no match.
 */
- (BEPredicateRuleOutcome)ruleOutcomeWithObject:(nullable id)object substitutionVariables:(nullable NSDictionary<NSString *, id> *)bindings API_AVAILABLE(macos(10.5), ios(3.0), watchos(2.0), tvos(9.0)); // single pass evaluation substituting variables from the bindings dictionary for any variable expressions encountered
@end



/*!
 @category		BEPredicateRuleSupport
 @abstract		This implements a Rule set of `BEPredicateRule` where it orders the
				rules, and matches to the first (lowest) priority rule and
				returns the `BEPredicateRuleOutcome` of its outcome.
				If no rule is matched, `BEPredicateRuleNA` is returned.
 */
@interface NSSet (BEPredicateRuleSupport)

/*!
 @method		-ruleOutcomeWithObject:
 @abstract		This loops through the internal BEPredicateRule elements (non-BEPredicateRule elements are ignored)
				in priority order (lowest first) and returns the outcome of the first matching.
 @param		object	The object to test against the predicates.
 @result		Returns `BEPredicateRuleOutcome` based on the object matching
				a rule, it's outcome, and if there is no match.
 */
- (BEPredicateRuleOutcome)ruleOutcomeWithObject:(nullable id)object;

/*!
 @method		-ruleOutcomeWithObject:
 @abstract		This loops through the internal BEPredicateRule elements (non-BEPredicateRule elements are ignored)
				in priority order (lowest first) and returns the outcome of the first matching.
 @param		object		The object to test against the predicates.
 @param		bindings	The bindings to replace any variable expressions. Every variable
				in every `NSPredicate`/`BEPredicateRule`
 @result		Returns `BEPredicateRuleOutcome` based on the object matching
				a rule, it's outcome, and if there is no match.
 */
- (BEPredicateRuleOutcome)ruleOutcomeWithObject:(nullable id)object substitutionVariables:(nullable NSDictionary<NSString *, id> *)bindings API_AVAILABLE(macos(10.5), ios(3.0), watchos(2.0), tvos(9.0)); // single pass evaluation substituting variables from the bindings dictionary for any variable expressions encountered
@end



/*!
 @category		BEPredicateRuleSupport
 @abstract		This implements a Rule set of `BEPredicateRule` where it orders the
 				rules, and matches to the first (lowest) priority rule and
				returns the `BEPredicateRuleOutcome` of its outcome.
				If no rule is matched, `BEPredicateRuleNA` is returned.
 */
@interface NSOrderedSet (BEPredicateRuleSupport)

/*!
 @method		-ruleOutcomeWithObject:
 @abstract		This loops through the internal BEPredicateRule elements (non-BEPredicateRule elements are ignored)
				in priority order (lowest first) and returns the outcome of the first matching.
 @param		object	The object to test against the predicates.
 @result		Returns `BEPredicateRuleOutcome` based on the object matching
				a rule, it's outcome, and if there is no match.
 */
- (BEPredicateRuleOutcome)ruleOutcomeWithObject:(nullable id)object;

/*!
 @method		-ruleOutcomeWithObject:
 @abstract		This loops through the internal BEPredicateRule elements (non-BEPredicateRule elements are ignored)
				in priority order (lowest first) and returns the outcome of the first matching.
 @param		object		The object to test against the predicates.
 @param		bindings	The bindings to replace any variable expressions. Every variable
				in every `NSPredicate`/`BEPredicateRule`
 @result		Returns `BEPredicateRuleOutcome` based on the object matching
				a rule, it's outcome, and if there is no match.
 */
- (BEPredicateRuleOutcome)ruleOutcomeWithObject:(nullable id)object substitutionVariables:(nullable NSDictionary<NSString *, id> *)bindings API_AVAILABLE(macos(10.5), ios(3.0), watchos(2.0), tvos(9.0)); // single pass evaluation substituting variables from the bindings dictionary for any variable expressions encountered

@end

#endif	//	BEPredicateRule_h
