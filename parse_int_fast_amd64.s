//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseIntFastAsm(s string, bitSize int) (result int64, ok bool)
// Fast path parser for simple integers: [-+]?[0-9]+
// Returns (0, false) if pattern doesn't match or requires fallback
TEXT ·parseIntFastAsm(SB), NOSPLIT, $0-41
	// Load string pointer and length
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	MOVQ bitSize+16(FP), R8 // R8 = bitSize
	
	// Check for empty string
	TESTQ SI, SI
	JZ return_false
	
	// Validate bitSize (must be 32 or 64)
	CMPQ R8, $32
	JE bitsize_ok
	CMPQ R8, $64
	JNE return_false
	
bitsize_ok:
	// Initialize registers
	XORQ R9, R9              // R9 = index (i)
	XORQ R10, R10            // R10 = value
	XORQ R11, R11            // R11 = negative (0=positive, 1=negative)
	XORQ R12, R12            // R12 = digit count
	
	// Determine max value based on bitSize
	MOVQ $0x7FFFFFFFFFFFFFFF, R13  // Max int64
	CMPQ R8, $32
	JNE set_max64
	MOVQ $0x7FFFFFFF, R13          // Max int32
	
set_max64:
	// Parse optional sign
	MOVBLZX (DI), AX
	CMPB AX, CHAR_MINUS
	JE set_negative
	CMPB AX, CHAR_PLUS
	JE skip_sign
	JMP parse_digits
	
set_negative:
	MOVQ $1, R11
	INCQ R9
	JMP check_after_sign
	
skip_sign:
	INCQ R9
	
check_after_sign:
	// Check bounds
	CMPQ R9, SI
	JGE return_false
	
parse_digits:
	// Must have at least one digit
	CMPQ R9, SI
	JGE check_complete
	
	// Try AVX2 batch validation for longer strings (>=16 remaining bytes)
	MOVQ SI, BX
	SUBQ R9, BX
	CMPQ BX, $16
	JGE try_avx2_int_digits
	
	// Load character
	MOVBLZX (DI)(R9*1), CX
	
	// Check if digit
	MOVQ CX, AX
	SUBB CHAR_0, AX
	CMPB AX, $9
	JA check_complete  // Not a digit, check if we're done
	
digit_loop:
	// It's a digit (AX contains digit value 0-9)
	INCQ R12  // digitCount++
	
	// Save the digit value
	MOVQ AX, R14  // R14 = digit
	
	// Check for overflow before multiply
	// if value > maxValue/10, overflow
	MOVQ R13, AX
	XORQ DX, DX
	MOVQ $10, BX
	DIVQ BX         // AX = R13/10 (maxValue/10)
	CMPQ R10, AX
	JA return_false // value > maxValue/10, overflow
	
	// Accumulate: value = value * 10 + digit
	IMULQ $10, R10
	ADDQ R14, R10   // Add digit
	
	// Check if new value exceeds max
	CMPQ R10, R13
	JA check_min_negative
	
continue_loop:
	// Next character
	INCQ R9
	CMPQ R9, SI
	JGE check_complete
	
	// Load next character
	MOVBLZX (DI)(R9*1), CX
	MOVQ CX, AX
	SUBB CHAR_0, AX
	CMPB AX, $9
	JA check_complete
	JMP digit_loop
	
check_min_negative:
	// Special case: check for minimum negative value
	// For int64: -9223372036854775808 (value = 9223372036854775808)
	// For int32: -2147483648 (value = 2147483648)
	TESTQ R11, R11
	JZ return_false  // Positive overflow
	
	// Check if this is exactly maxValue + 1
	MOVQ R13, BX
	INCQ BX
	CMPQ R10, BX
	JNE return_false
	
	// This is the minimum negative value
	// Continue to make sure we consume all digits
	INCQ R9
	CMPQ R9, SI
	JGE return_min_negative
	
	// Check if there are more digits (would be overflow)
	MOVBLZX (DI)(R9*1), CX
	MOVQ CX, AX
	SUBB CHAR_0, AX
	CMPB AX, $9
	JBE return_false  // More digits = overflow
	
	// Not a digit, we're done
	JMP return_min_negative
	
try_avx2_int_digits:
	// AVX2 digit validation: check 16 bytes at once
	// This helps for very long integers (18-20 digits)
	// Load '0' (0x30) into all bytes of XMM1
	MOVQ $0x3030303030303030, AX
	MOVQ AX, X1
	PUNPCKLQDQ X1, X1        // X1 = all 0x30
	
	// Load '9' (0x39) into all bytes of XMM2  
	MOVQ $0x3939393939393939, AX
	MOVQ AX, X2
	PUNPCKLQDQ X2, X2        // X2 = all 0x39
	
	// Check if we have at least 16 bytes left
	MOVQ SI, BX
	SUBQ R9, BX
	CMPQ BX, $16
	JL digit_scalar_fallback
	
	// Load 16 bytes
	MOVOU (DI)(R9*1), X0
	
	// Check if all bytes >= '0'
	MOVOA X0, X3
	PCMPGTB X1, X3           // X3 = (X0 < '0')
	PMOVMSKB X3, AX
	TESTL AX, AX
	JNZ digit_scalar_fallback // Some byte < '0', use scalar
	
	// Check if all bytes <= '9'
	MOVOA X0, X3
	MOVOA X2, X4
	PCMPGTB X3, X4           // X4 = (X0 > '9')
	PMOVMSKB X4, AX
	TESTL AX, AX
	JNZ digit_scalar_fallback // Some byte > '9', use scalar
	
	// All 16 bytes are digits!
	// Fall through to scalar loop to accumulate them
	// (SIMD accumulation is complex for base-10 integers)

digit_scalar_fallback:
	// Load character for scalar processing
	MOVBLZX (DI)(R9*1), CX
	MOVQ CX, AX
	SUBB CHAR_0, AX
	CMPB AX, $9
	JA check_complete  // Not a digit
	JMP digit_loop

check_complete:
	// Must have consumed entire string
	CMPQ R9, SI
	JNE return_false
	
	// Must have at least one digit
	TESTQ R12, R12
	JZ return_false
	
	// Apply sign
	TESTQ R11, R11
	JZ return_result
	NEGQ R10
	
return_result:
	// Store result
	MOVQ R10, result+24(FP)
	MOVB $1, ok+32(FP)
	RET
	
return_min_negative:
	// Return minimum negative value
	MOVQ R10, AX
	NEGQ AX
	MOVQ AX, result+24(FP)
	MOVB $1, ok+32(FP)
	RET
	
return_false:
	// Store zero result and false
	MOVQ $0, result+24(FP)
	MOVB $0, ok+32(FP)
	RET

