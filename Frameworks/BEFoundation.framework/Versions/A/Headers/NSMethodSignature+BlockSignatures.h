/*!
 @header		NSMethodSignature+BlockSignatures.h
 @copyright		-© 2025 Delicense - @belisoful. All rights released.
 @date			2025-01-01
 @author		belisoful@icloud.com
 @abstract		Block-runtime structures and NSMethodSignature extensions for deriving method
				signatures from blocks.
 @discussion	This header exposes the Apple Block ABI layout (@c BlockFlags, @c Block_literal,
				@c Block_descriptor) and tools to read a block's Objective-C type-encoding signature and
				convert it into an @c NSMethodSignature. It underpins the NSObject (DynamicMethods)
				runtime injection system, which uses these signatures to build NSInvocations for
				block-backed methods.

				This header provides the following capabilities:
				- Extract a block's raw @encode signature (@c NSSignatureForBlock / @c BEBlockSignatureChar),
				  resolving both the regular and small block-descriptor layouts
				- Build an exact-match signature from a block (@c +signatureFromBlock:)
				- Build a method-ready signature that drops the leading block pointer and injects
				  @c SEL @c _cmd (@c +methodSignatureFromBlock:)
				- Low-level signature parsing utilities via @c BEMethodSignatureHelper
				- App Store compliance gating via @c BE_APPLE_TERMS_COMPLIANT (see below)

				## Block Signature Requirements
				
				Method implementation blocks must follow this format:
				```
				ReturnType (^)(id self, SEL _cmd, ...parameters)
				```
				
				The `SEL _cmd` parameter is optional. If included, the block will receive the selector
				of the method being called. If omitted, the system automatically adjusts the signature.
				
				## Limitations
				
				NSMethodSignatures cannot properly encode compiler SIMD, vector, or NEON parameter types and will fail.
				Use their base types as arrays or pointers instead for arguments.
				The `_Float16` type also produces errors for malformed Block Signatures.
				
				## Usage Example
				
				```objc
				id block = ^(id self, NSString *param) {
					return [self stringByAppendingString:param];
				};

				// The block's own (raw) signature, including the leading block pointer.
				const char *raw = NSSignatureForBlock(block);
				
				// A method-ready signature: leading block pointer dropped, SEL _cmd injected at index 1.
				NSMethodSignature *sig = [NSMethodSignature methodSignatureFromBlock:block];
				// sig.numberOfArguments == 3  (self, _cmd, param)
				```
*/

#ifndef NSMethodSignature_BlockSignature_h
#define NSMethodSignature_BlockSignature_h

#import <Foundation/Foundation.h>

@class NSBlock;

/*!
 @defined		BE_APPLE_TERMS_COMPLIANT
 @abstract		Library-wide switch gating use of non-public Apple symbols. Defaults to 1 (compliant).
 @discussion	When 1 (the default), BEFoundation references only public APIs plus direct memory reads,
				so the resulting binary contains no non-public symbol references and is safe for App
				Store submission (App Store Review Guideline 2.5.1).

				Define it to 0 — e.g. a `-DBE_APPLE_TERMS_COMPLIANT=0` compiler flag, or before importing this
				header — to permit the authoritative but non-public runtime function @c _Block_signature
				for block-signature extraction. That path resolves every block descriptor layout
				(including small descriptors) directly via the runtime; the hand-rolled reader remains
				as a fallback. Do NOT ship a binary built with @c BE_APPLE_TERMS_COMPLIANT=0 to the App Store.

 @since			1.1
 */
#ifndef BE_APPLE_TERMS_COMPLIANT
#define BE_APPLE_TERMS_COMPLIANT 1
#endif

#if !BE_APPLE_TERMS_COMPLIANT
/*  Non-public libsystem_blocks runtime function. Only declared/used when BE_APPLE_TERMS_COMPLIANT == 0, so a
    compliant build references the symbol nowhere. Weak-imported so a missing symbol falls back cleanly. */
extern const char * _Nullable _Block_signature(void * _Nonnull aBlock) __attribute__((weak_import));
#endif

#pragma mark - Block Runtime Structures

/*!
 @enum			BlockFlags
 @abstract		Flags in a block's @c flags field describing its characteristics and capabilities.
 @discussion	These mirror the Apple Block ABI (libclosure @c Block_private.h). The low 16 bits are
				runtime bookkeeping (a deallocating bit plus an inline reference count); the high bits
				are set by the compiler and describe the descriptor layout and block kind. They are
				exposed here for low-level block introspection.

				Runtime (set/cleared by the block runtime at run time):
 @constant		BLOCK_DEALLOCATING			Bit 0: the block is currently being deallocated.
 @constant		BLOCK_REFCOUNT_MASK			Bits 1-15: mask for the inline retain count.
 @constant		BLOCK_NEEDS_FREE			The block is heap-allocated and must be freed.
 @constant		BLOCK_IS_GC					Garbage-collection managed (obsolete; GC is removed).

				Compiler (emitted into the block literal at compile time):
 @constant		BLOCK_INLINE_LAYOUT_STRING	The extended layout field holds an inline string, not a pointer.
 @constant		BLOCK_SMALL_DESCRIPTOR		The descriptor uses the compact form: 32-bit @em relative
											fields instead of pointers (see @c Block_descriptor). Affects
											how the signature is located.
 @constant		BLOCK_IS_NOESCAPE			The block is @c __attribute__((noescape)).
 @constant		BLOCK_HAS_COPY_DISPOSE		The descriptor carries copy and dispose helper functions.
 @constant		BLOCK_HAS_CTOR				The copy/dispose helpers contain C++ constructors/destructors.
 @constant		BLOCK_IS_GLOBAL				A global block allocated in static storage.
 @constant		BLOCK_USE_STRET				The block returns a struct via an sret pointer
											(only meaningful when BLOCK_HAS_SIGNATURE is also set).
 @constant		BLOCK_HAS_SIGNATURE			The descriptor carries an Objective-C type-encoding signature.
 @constant		BLOCK_HAS_EXTENDED_LAYOUT	The descriptor carries an extended GC/ARC layout string.
 */
typedef enum {
	// Runtime flags (low 16 bits).
	BLOCK_DEALLOCATING =         (0x0001),
	BLOCK_REFCOUNT_MASK =        (0xfffe),
	// Compiler flags.
	BLOCK_INLINE_LAYOUT_STRING = (1 << 21),
	BLOCK_SMALL_DESCRIPTOR =     (1 << 22),
	BLOCK_IS_NOESCAPE =          (1 << 23),
	BLOCK_NEEDS_FREE =           (1 << 24),
	BLOCK_HAS_COPY_DISPOSE =     (1 << 25),
	BLOCK_HAS_CTOR =             (1 << 26),
	BLOCK_IS_GC =                (1 << 27),
	BLOCK_IS_GLOBAL =            (1 << 28),
	BLOCK_USE_STRET =            (1 << 29),
	BLOCK_HAS_SIGNATURE =        (1 << 30),
	BLOCK_HAS_EXTENDED_LAYOUT =  (1 << 31),
} BlockFlags;

/*!
 @struct		Block_descriptor
 @abstract		Describes the layout and capabilities of a block (the regular, pointer-sized form).
 @discussion	This structure models the regular block descriptor: a fixed @c reserved / @c size
				header followed optionally by copy/dispose helpers (when @c BLOCK_HAS_COPY_DISPOSE is
				set) and a type signature (when @c BLOCK_HAS_SIGNATURE is set).

				When @c BLOCK_SMALL_DESCRIPTOR is set the descriptor instead uses a compact form: a
				32-bit @c size and 32-bit @em relative offsets in place of the pointers below. This
				struct does not model that form — use @c NSSignatureForBlock (or
				@c BEMethodSignatureHelper) which resolves both layouts.
 @field			reserved		Reserved field, typically NULL.
 @field			size			Size of the block in bytes.
 @field			copy_helper		Optional copy helper function (if BLOCK_HAS_COPY_DISPOSE is set).
 @field			dispose_helper	Optional dispose helper function (if BLOCK_HAS_COPY_DISPOSE is set).
 @field			signature		Optional type signature (if BLOCK_HAS_SIGNATURE is set).
 */
typedef struct Block_descriptor {
	unsigned long int reserved;
	unsigned long int size;
	union {
		struct {
			void (* _Nonnull copy_helper)(void * _Nonnull dst, void * _Nonnull src);
			void (* _Nonnull dispose_helper)(void * _Nonnull src);
			const char * _Nonnull signature;
		} copy_dispose;
		const char * _Nonnull signature;
	};
} Block_descriptor;

/*!
 @struct		Block_literal
 @abstract		The runtime representation of a block object.
 @discussion	This structure defines the memory layout of a block as it exists at runtime.
				It contains the block's class pointer, flags, implementation function, and descriptor.
 @field			isa			Class pointer, typically &_NSConcreteStackBlock or &_NSConcreteGlobalBlock.
 @field			flags		Block flags indicating capabilities and characteristics.
 @field			reserved	Reserved field for alignment.
 @field			invoke		Function pointer to the block's implementation.
 @field			descriptor	Pointer to the block's descriptor structure.
 */
typedef struct Block_literal {
	void * _Nonnull isa;
	int flags;
	int reserved;
	void (*_Nonnull invoke)(struct Block_literal * _Nonnull);
	Block_descriptor * _Nonnull descriptor;
} Block_literal;

/*!
 @function		BEBlockSignatureChar
 @abstract		Extracts the Objective-C type-encoding signature C string from a block, or NULL if it has none.
 @param			block	The block literal to examine (cast to a const void *).
 @discussion	Resolves the signature for both descriptor layouts:
				- Regular descriptor: the signature is an absolute pointer located after the
				  reserved/size header and (if present) the copy/dispose helpers.
				- Small descriptor (@c BLOCK_SMALL_DESCRIPTOR): the descriptor stores 32-bit @em relative
				  offsets; the signature offset immediately follows the 32-bit @c size, and the signature
				  is recovered as @c fieldAddress + @c relativeOffset.
				Returns NULL when @c BLOCK_HAS_SIGNATURE is not set.

				The regular-descriptor path matches this platform's runtime @c _Block_signature exactly.
				The small-descriptor path is defensive; its offset arithmetic is covered by synthetic-block
				tests, but no current Apple toolchain emits small descriptors. See the implementation note.
 */
static inline const char * _Nullable BEBlockSignatureChar(const void * _Nonnull block)
{
	const Block_literal *literal = (const Block_literal *)block;
	if (!(literal->flags & BLOCK_HAS_SIGNATURE)) {
		return NULL;
	}
#if !BE_APPLE_TERMS_COMPLIANT
	// Opted out of strict compliance: use the runtime's own extractor, which authoritatively resolves
	// every descriptor layout. Weak-imported, so fall through to the hand-rolled reader if it is absent.
	if (_Block_signature != NULL) {
		return _Block_signature((void *)block);
	}
#endif
	if (literal->flags & BLOCK_SMALL_DESCRIPTOR) {
		// Compact descriptor (libclosure Block_descriptor_small): {uint32_t size; int32_t signature;
		// int32_t layout;}, with the optional copy/dispose helper offsets appended after layout when
		// BLOCK_HAS_COPY_DISPOSE is set. A relative field stores (target - &field), so the target is
		// recovered by adding the offset back to the field's own address; the runtime treats a zero
		// offset as no signature.
		// NOTE: defensive. No current Apple toolchain emits BLOCK_SMALL_DESCRIPTOR for Objective-C
		// blocks, and this platform's libsystem_blocks _Block_signature has no small-descriptor branch
		// (it reads an absolute pointer at descriptor +16/+32), so this branch is unreachable through a
		// compiler-produced block here. The field arithmetic (positive, negative, and zero relative
		// offsets) is pinned by synthetic-block tests in NSMethodSignature+BlockSignaturesTests.m; the
		// layout itself stays unvalidated against a real toolchain-emitted small descriptor until one
		// exists. Re-validate before relying on it on any toolchain that begins emitting them.
		const uint8_t *cursor = (const uint8_t *)literal->descriptor;
		cursor += sizeof(uint32_t); // the signature's relative offset immediately follows the 32-bit size
		int32_t relativeOffset;
		memcpy(&relativeOffset, cursor, sizeof(relativeOffset));
		if (relativeOffset == 0) {
			return NULL;
		}
		return (const char *)(cursor + relativeOffset);
	}
	// Regular descriptor: absolute pointer, after the helpers when present.
	if (literal->flags & BLOCK_HAS_COPY_DISPOSE) {
		return literal->descriptor->copy_dispose.signature;
	}
	return literal->descriptor->signature;
}

/*!
 @defined		NSSignatureForBlock
 @abstract		Macro to extract the type signature from a block.
 @param			block	The block object to examine.
 @discussion	Safely extracts the type signature from a block if it has one, handling blocks with
				and without copy/dispose helpers and both the regular and small descriptor layouts.
 @return		A C string containing the block's type signature, or NULL if no signature is available.
 */
#define NSSignatureForBlock(block) (BEBlockSignatureChar((__bridge const void *)(block)))

#pragma mark - Method Signature Parsing

/*!
 @enum			BEMethodSignatureParseFlags
 @abstract		Flags that control how block signatures are parsed and converted to method signatures.
 @discussion	These flags determine how the block signature parser handles various aspects of
				signature conversion, including block parameter retention and selector handling.
 @constant		BENoMethodSignatureFlag		No special parsing flags.
 @constant		BEKeepBlockArgumentFlag		Keep the block argument in the parsed signature.
 @constant		BERequireSelectorFlag		Require a selector argument in the method signature.
 @constant		BEReplicateSelectorFlag		Replicate the selector argument in the signature.
 */
typedef NS_ENUM(NSInteger, BEMethodSignatureParseFlags) {
	BENoMethodSignatureFlag = 0,
	BEKeepBlockArgumentFlag = (1 << 0),
	BERequireSelectorFlag = (1 << 1),
	BEReplicateSelectorFlag = (1 << 2),
};

#pragma mark - NSMethodSignature Block Extensions

/*!
 @category		NSMethodSignature (BlockMethods)
 @abstract		Extensions to NSMethodSignature for working with blocks.
 @discussion	This category provides methods for creating method signatures from blocks
				and utilities for working with method signature data.
 */
@interface NSMethodSignature (BlockSignatures)

/*!
 @method		signatureFromBlock:
 @abstract		Creates a method signature directly from a block's signature.
 @param			block	The block to extract the signature from.
 @return		An NSMethodSignature object, or nil if the block has no signature.
 @discussion	This method creates a method signature from the block's signature.
				The leading block pointer argument is dropped, so self is the first parameter (index 0),
				followed by the block's remaining parameters. No SEL `_cmd` is inserted.
 */
+ (nullable NSMethodSignature *)signatureFromBlock:(nonnull id)block;

/*!
 @method		methodSignatureFromBlock:
 @abstract		Creates a method signature suitable for dynamic method implementation from a block.
 @param			block	The block to convert to a method signature.
 @return		An NSMethodSignature object suitable for method implementation, or nil if conversion fails.
 @discussion	This method transforms a block signature into a proper method signature by:
				- Removing the initial block pointer parameter
				- Keeping self as the first parameter
				- Adding SEL _cmd as the second parameter if not already present
				
				The resulting signature can be used with class_addMethod or similar runtime functions.
 */
+ (nullable NSMethodSignature *)methodSignatureFromBlock:(nonnull id)block;

/*!
 @property		methodReturnTypeString
 @abstract		The method's return type as a string.
 @return		An NSString containing the encoded return type.
 @discussion	This property returns the return type as a string
				rather than a C string. Useful for debugging and introspection.
 */
@property (readonly, nonnull) NSString *methodReturnTypeString;

/*!
 @method		getArgumentTypeStringAtIndex:
 @abstract		Returns the type of the argument at the specified index as a string.
 @param			idx		The index of the argument to examine.
 @return		An NSString containing the encoded argument type.
 @discussion	This method converts the C string argument type to an NSString for easier
				handling and comparison. The index follows the same conventions as
				getArgumentTypeAtIndex:.
 */
- (nonnull NSString *)getArgumentTypeStringAtIndex:(NSUInteger)idx;

/*!
 @method		getArgumentSizeAtIndex:
 @abstract		Returns the size in bytes of the argument at the specified index.
 @param			idx		The index of the argument to examine.
 @return		The size of the argument in bytes.
 @discussion	This method provides the size of arguments based on their encoded types.
				It's useful for memory allocation and argument copying operations.
				Returns 0 for unknown or invalid types.
 */
- (NSUInteger)getArgumentSizeAtIndex:(NSUInteger)idx;

@end




#pragma mark - Method Signature Helper

/*!
 @class			BEMethodSignatureHelper
 @abstract		Utility class for parsing and manipulating method signatures.
 @discussion	This class provides low-level utilities for working with block signatures,
				parsing type encodings, and converting between different signature formats.
				It handles the complex task of transforming block signatures into method
				signatures suitable for runtime use.
 */
@interface BEMethodSignatureHelper : NSObject

/*!
 @method		rawBlockSignatureChar:
 @abstract		Extracts the raw type signature from a block as a C string.
 @param			block	The block to examine.
 @return		A C string containing the block's type signature, or NULL if unavailable.
 @discussion	This method directly accesses the block's internal structure to retrieve
				its type signature. The signature includes all parameters, with the block
				pointer as the first parameter and self as the second.
 */
+ (nullable const char *)rawBlockSignatureChar:(nonnull id)block;

/*!
 @method		rawBlockSignatureString:
 @abstract		Extracts the raw type signature from a block as an NSString.
 @param			block	The block to examine.
 @return		An NSString containing the block's type signature, or nil if unavailable.
 @discussion	This method provides the same functionality as rawBlockSignatureChar:
				but returns an NSString for easier handling in Objective-C code.
 */
+ (nullable NSString *)rawBlockSignatureString:(nonnull id)block;

/*!
 @method		blockSignatureString:
 @abstract		Returns a processed block signature string suitable for NSMethodSignature.
 @param			block	The block to process.
 @return		A processed signature string, or nil if processing fails.
 @discussion	This method takes a block's raw signature and processes it to create
				a signature string that can be used with NSMethodSignature. It handles
				the removal of the block parameter and other necessary transformations.
 */
+ (nullable NSString *)blockSignatureString:(nonnull id)block;

/*!
 @method		parseBlockSignature:parseFlags:
 @abstract		Parses a block signature string with specified parsing options.
 @param			signature	The raw signature string to parse.
 @param			flags		Flags controlling the parsing behavior.
 @return		A parsed signature string, or nil if parsing fails.
 @discussion	This method performs the complex task of parsing and transforming block
				signatures. It handles parameter removal, selector injection, and other
				transformations needed to convert block signatures to method signatures.
 */
+ (nullable NSString *)parseBlockSignature:(nonnull const char *)signature parseFlags:(BEMethodSignatureParseFlags)flags;

/*!
 @method		parseTypeAtPointer:
 @abstract		Parses a single type encoding from a signature string.
 @param			pointer	Pointer to the position in the signature string (updated during parsing).
 @return		The parsed type as an NSString, or nil if parsing fails.
 @discussion	This method parses a single type encoding from an Objective-C type signature.
				It handles complex types including structures, unions, arrays, and pointers.
				The pointer parameter is updated to point to the next unparsed character.
 */
+ (nullable NSString *)parseTypeAtPointer:(const char * _Nonnull * _Nonnull)pointer;

/*!
 @method		parseNumberAtPointer:
 @abstract		Parses a number from a signature string.
 @param			pointer	Pointer to the position in the signature string (updated during parsing).
 @return		The parsed number as an NSInteger.
 @discussion	This method parses numeric values from type signatures, such as array sizes,
				structure offsets, and frame sizes. The pointer parameter is updated to
				point to the next unparsed character.
 */
+ (NSInteger)parseNumberAtPointer:(const char * _Nonnull * _Nonnull)pointer;

@end


#endif	//	NSMethodSignature_BlockSignature_h
