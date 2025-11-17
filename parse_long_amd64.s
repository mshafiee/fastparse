// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseLongDecimalFastAsm(s string) (result float64, ok bool)
// Handles long decimals (20-100 digits) without FSA overhead
// Pattern: [-]?[0-9]+\.?[0-9]* (no exponent, no underscores)
TEXT ·parseLongDecimalFastAsm(SB), NOSPLIT, $96-33
	// Load string pointer and length
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	
	// Initialize index
	XORQ R8, R8              // R8 = index (i)
	
	// Check for sign
	MOVBLZX (DI), AX
	CMPB AX, CHAR_MINUS
	JE has_negative
	CMPB AX, CHAR_PLUS
	JNE parse_digits
	// Skip '+' sign
	INCQ R8
	XORQ R9, R9              // R9 = negative (0)
	JMP check_after_sign
	
has_negative:
	MOVQ $1, R9              // R9 = negative (1)
	INCQ R8
	
check_after_sign:
	// Check bounds
	CMPQ R8, SI
	JGE return_false
	
	// Check next char is digit
	MOVBLZX (DI)(R8*1), AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA return_false
	
parse_digits:
	// R9 = negative flag
	// R10 = mantissa
	// R11 = mantissaDigits
	// R12 = digitsBeforeDot
	XORQ R10, R10
	XORQ R11, R11
	XORQ R12, R12
	
	// Skip leading zeros
skip_zeros:
	CMPQ R8, SI
	JGE return_false
	MOVBLZX (DI)(R8*1), AX
	CMPB AX, $CHAR_ZERO
	JNE collect_integer
	INCQ R8
	JMP skip_zeros
	
collect_integer:
	// Collect digits before decimal point
	CMPQ R8, SI
	JGE finalize_no_dot
	
	MOVBLZX (DI)(R8*1), CX
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA check_dot
	
	// It's a digit
	CMPQ R11, $19
	JGE skip_digit
	
	IMULQ $10, R10
	ADDQ AX, R10
	INCQ R11
	
skip_digit:
	INCQ R12                 // digitsBeforeDot++
	INCQ R8
	JMP collect_integer
	
check_dot:
	// Check for decimal point
	CMPB CX, CHAR_DOT
	JNE check_end
	INCQ R8
	
	// Collect digits after decimal point
collect_fraction:
	CMPQ R8, SI
	JGE check_end
	
	MOVBLZX (DI)(R8*1), CX
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA check_end
	
	// It's a digit
	CMPQ R11, $19
	JGE frac_skip
	
	IMULQ $10, R10
	ADDQ AX, R10
	INCQ R11
	
frac_skip:
	INCQ R8
	JMP collect_fraction
	
finalize_no_dot:
	// No decimal point found
	MOVQ R12, R11            // mantissaDigits = digitsBeforeDot
	
check_end:
	// Validate we consumed everything
	CMPQ R8, SI
	JNE return_false
	
	// Validate we have digits
	TESTQ R11, R11
	JZ return_false
	
	// Calculate exponent: digitsBeforeDot - mantissaDigits
	MOVQ R12, AX
	SUBQ R11, AX             // exp = digitsBeforeDot - mantissaDigits
	MOVQ AX, -8(SP)          // Store exp at -8(SP)
	
	// Check range
	CMPQ AX, $-308
	JL return_false
	CMPQ AX, $308
	JG return_false
	
	// Convert mantissa to float64
	TESTQ R10, R10
	JZ return_zero
	
	CVTSQ2SD R10, X0
	
	// Apply sign
	TESTQ R9, R9
	JZ apply_power
	MOVQ $0x8000000000000000, AX
	MOVQ AX, X1
	XORPD X1, X0
	
apply_power:
	// Apply power of 10
	// For now, fall back to Go for complex power-of-10 multiplication
	// Full implementation would use precomputed table
	MOVQ -8(SP), AX
	TESTQ AX, AX
	JNZ return_false         // Non-zero exponent, use Go fallback
	
	// Zero exponent, result is ready
	MOVSD X0, result+16(FP)
	MOVB $1, ok+24(FP)
	RET
	
return_zero:
	XORPD X0, X0
	TESTQ R9, R9
	JZ store_zero
	MOVQ $0x8000000000000000, AX
	MOVQ AX, X1
	XORPD X1, X0
	
store_zero:
	MOVSD X0, result+16(FP)
	MOVB $1, ok+24(FP)
	RET
	
return_false:
	XORPD X0, X0
	MOVSD X0, result+16(FP)
	MOVB $0, ok+24(FP)
	RET

