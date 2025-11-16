//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseLongDecimalFastAsm(s string) (result float64, ok bool)
// Handles long decimals (20-100 digits) without FSA overhead
// Pattern: [-]?[0-9]+\.?[0-9]* (no exponent, no underscores)
TEXT ·parseLongDecimalFastAsm(SB), NOSPLIT, $96-32
	// Load string pointer and length
	MOVD s_ptr+0(FP), R0    // R0 = string pointer
	MOVD s_len+8(FP), R1    // R1 = string length
	
	// Initialize index
	MOVD $0, R2              // R2 = index (i)
	
	// Check for sign
	MOVBU (R0), R3
	CMP CHAR_MINUS, R3
	BEQ has_negative
	CMP CHAR_PLUS, R3
	BNE parse_digits
	// Skip '+' sign
	ADD $1, R2
	MOVD $0, R4              // R4 = negative (0)
	B check_after_sign
	
has_negative:
	MOVD $1, R4              // R4 = negative (1)
	ADD $1, R2
	
check_after_sign:
	// Check bounds
	CMP R1, R2
	BHS return_false
	
	// Check next char is digit
	ADD R0, R2, R10
	MOVBU (R10), R3
	SUB CHAR_0, R3
	CMP $9, R3
	BHI return_false
	
parse_digits:
	// R4 = negative flag
	// R5 = mantissa
	// R6 = mantissaDigits
	// R7 = digitsBeforeDot
	MOVD $0, R5
	MOVD $0, R6
	MOVD $0, R7
	
	// Skip leading zeros
skip_zeros:
	CMP R1, R2
	BHS return_false
	ADD R0, R2, R10
	MOVBU (R10), R3
	CMP CHAR_0, R3
	BNE collect_integer
	ADD $1, R2
	B skip_zeros
	
collect_integer:
	// Collect digits before decimal point
	CMP R1, R2
	BHS finalize_no_dot
	
	ADD R0, R2, R10
	MOVBU (R10), R8
	SUB CHAR_0, R8, R3
	CMP $9, R3
	BHI check_dot
	
	// It's a digit
	CMP $19, R6
	BHS skip_digit
	
	MOVD $10, R9
	MUL R9, R5
	ADD R3, R5
	ADD $1, R6
	
skip_digit:
	ADD $1, R7               // digitsBeforeDot++
	ADD $1, R2
	B collect_integer
	
check_dot:
	// Check for decimal point
	CMP CHAR_DOT, R8
	BNE check_end
	ADD $1, R2
	
	// Collect digits after decimal point
collect_fraction:
	CMP R1, R2
	BHS check_end
	
	ADD R0, R2, R10
	MOVBU (R10), R8
	SUB CHAR_0, R8, R3
	CMP $9, R3
	BHI check_end
	
	// It's a digit
	CMP $19, R6
	BHS frac_skip
	
	MOVD $10, R9
	MUL R9, R5
	ADD R3, R5
	ADD $1, R6
	
frac_skip:
	ADD $1, R2
	B collect_fraction
	
finalize_no_dot:
	// No decimal point found - R6 already has correct mantissaDigits count
	// R7 has total digits before dot, which may be > 19 if we skipped some
	// Don't overwrite R6!
	
check_end:
	// Validate we consumed everything
	CMP R1, R2
	BNE return_false
	
	// Validate we have digits
	CBZ R6, return_false
	
	// Calculate exponent: digitsBeforeDot - mantissaDigits
	SUB R6, R7, R10          // exp = digitsBeforeDot - mantissaDigits
	
	// Check range
	MOVD $-308, R11
	CMP R11, R10
	BLT return_false
	MOVD $308, R11
	CMP R11, R10
	BGT return_false
	
	// Convert mantissa to float64
	CBZ R5, return_zero
	
	SCVTFD R5, F0
	
	// Apply sign
	CBZ R4, apply_power
	FNEGD F0, F0
	
apply_power:
	// Apply power of 10
	// For now, fall back to Go for complex power-of-10 multiplication
	// Full implementation would use precomputed table
	CBNZ R10, return_false   // Non-zero exponent, use Go fallback
	
	// Zero exponent, result is ready
	FMOVD F0, result+16(FP)
	MOVD $1, R0
	MOVB R0, ok+24(FP)
	RET
	
return_zero:
	MOVD $0, R0
	SCVTFD R0, F0            // Convert integer 0 to float64 0
	CBZ R4, store_zero
	FNEGD F0, F0
	
store_zero:
	FMOVD F0, result+16(FP)
	MOVD $1, R0
	MOVB R0, ok+24(FP)
	RET
	
return_false:
	MOVD $0, R0
	SCVTFD R0, F0            // Convert integer 0 to float64 0
	FMOVD F0, result+16(FP)
	MOVB R0, ok+24(FP)
	RET

