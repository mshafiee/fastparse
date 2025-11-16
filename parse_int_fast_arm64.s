//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseIntFastAsm(s string, bitSize int) (result int64, ok bool)
// Fast path parser for simple integers: [-+]?[0-9]+
// Returns (0, false) if pattern doesn't match or requires fallback
TEXT ·parseIntFastAsm(SB), NOSPLIT, $0-41
	// Load arguments
	MOVD s_ptr+0(FP), R0    // R0 = string pointer
	MOVD s_len+8(FP), R1    // R1 = string length
	MOVD bitSize+16(FP), R2 // R2 = bitSize
	
	// Check for empty string
	CBZ R1, return_false
	
	// Validate bitSize (must be 32 or 64)
	CMP $32, R2
	BEQ bitsize_ok
	CMP $64, R2
	BNE return_false
	
bitsize_ok:
	// Initialize registers
	MOVD $0, R3              // R3 = index (i)
	MOVD $0, R4              // R4 = value
	MOVD $0, R5              // R5 = negative (0=positive, 1=negative)
	MOVD $0, R6              // R6 = digit count
	
	// Determine max value based on bitSize
	MOVD $0x7FFFFFFFFFFFFFFF, R7  // Max int64
	CMP $32, R2
	BNE set_max64
	MOVD $0x7FFFFFFF, R7          // Max int32
	
set_max64:
	// Parse optional sign
	MOVBU (R0), R8
	CMP CHAR_MINUS, R8
	BEQ set_negative
	CMP CHAR_PLUS, R8
	BEQ skip_sign
	B parse_digits
	
set_negative:
	MOVD $1, R5
	ADD $1, R3
	B check_after_sign
	
skip_sign:
	ADD $1, R3
	
check_after_sign:
	// Check bounds
	CMP R1, R3
	BGE return_false
	
parse_digits:
	// Must have at least one digit
	CMP R1, R3
	BGE check_complete
	
	// Load character
	MOVBU (R0)(R3), R8
	
	// Check if digit
	SUB CHAR_0, R8, R9
	CMP $9, R9
	BHI check_complete  // Not a digit, check if we're done
	
digit_loop:
	// It's a digit (R9 contains digit value 0-9)
	ADD $1, R6  // digitCount++
	
	// Save the digit value
	MOVD R9, R10  // R10 = digit
	
	// Check for overflow before multiply
	// if value > maxValue/10, overflow
	MOVD R7, R11
	MOVD $10, R12
	UDIV R12, R11  // R11 = maxValue/10
	CMP R11, R4
	BHI return_false // value > maxValue/10, overflow
	
	// Accumulate: value = value * 10 + digit
	MOVD $10, R12
	MUL R12, R4
	ADD R10, R4   // Add digit
	
	// Check if new value exceeds max
	CMP R7, R4
	BHI check_min_negative
	
continue_loop:
	// Next character
	ADD $1, R3
	CMP R1, R3
	BGE check_complete
	
	// Load next character
	MOVBU (R0)(R3), R8
	SUB CHAR_0, R8, R9
	CMP $9, R9
	BHI check_complete
	B digit_loop
	
check_min_negative:
	// Special case: check for minimum negative value
	// For int64: -9223372036854775808 (value = 9223372036854775808)
	// For int32: -2147483648 (value = 2147483648)
	CBZ R5, return_false  // Positive overflow
	
	// Check if this is exactly maxValue + 1
	ADD $1, R7, R11
	CMP R11, R4
	BNE return_false
	
	// This is the minimum negative value
	// Continue to make sure we consume all digits
	ADD $1, R3
	CMP R1, R3
	BGE return_min_negative
	
	// Check if there are more digits (would be overflow)
	MOVBU (R0)(R3), R8
	SUB CHAR_0, R8, R9
	CMP $9, R9
	BLS return_false  // More digits = overflow
	
	// Not a digit, we're done
	B return_min_negative
	
check_complete:
	// Must have consumed entire string
	CMP R1, R3
	BNE return_false
	
	// Must have at least one digit
	CBZ R6, return_false
	
	// Apply sign
	CBZ R5, return_result
	NEG R4, R4
	
return_result:
	// Store result
	MOVD R4, result+24(FP)
	MOVD $1, R8
	MOVB R8, ok+32(FP)
	RET
	
return_min_negative:
	// Return minimum negative value
	NEG R4, R4
	MOVD R4, result+24(FP)
	MOVD $1, R8
	MOVB R8, ok+32(FP)
	RET
	
return_false:
	// Store zero result and false
	MOVD $0, result+24(FP)
	MOVD $0, R8
	MOVB R8, ok+32(FP)
	RET

