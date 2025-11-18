// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseHexFastAsm(s string) (result float64, ok bool)
// Fast path parser for hex floats: [-]?0[xX][0-9a-fA-F]+\.?[0-9a-fA-F]*[pP][-+]?[0-9]+
TEXT ·parseHexFastAsm(SB), NOSPLIT, $96-33
	// Load string pointer and length
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	
	// Check minimum length (need at least "0x0p0" = 5 chars)
	CMPQ SI, $5
	JL return_false
	
	// Initialize
	XORQ R8, R8              // R8 = index (i)
	XORQ R9, R9              // R9 = negative
	
	// Optional sign
	MOVBLZX (DI), AX
	CMPB AL, $CHAR_MINUS
	JE set_negative
	CMPB AL, $CHAR_PLUS
	JNE check_0x_prefix
	INCQ R8
	JMP check_0x_prefix
	
set_negative:
	MOVQ $1, R9
	INCQ R8
	
check_0x_prefix:
	// Require 0x prefix
	CMPQ R8, SI
	JGE return_false
	MOVBLZX (DI)(R8*1), AX
	CMPB AX, $CHAR_ZERO
	JNE return_false
	
	INCQ R8
	CMPQ R8, SI
	JGE return_false
	MOVBLZX (DI)(R8*1), AX
	CMPB AX, $CHAR_X_LOWER
	JE has_x
	CMPB AX, $CHAR_X_UPPER
	JNE return_false
	
has_x:
	INCQ R8
	
	// Parse hex mantissa
	XORQ R10, R10            // R10 = mantissa
	XORQ R11, R11            // R11 = hexIntDigits
	XORQ R12, R12            // R12 = hexFracDigits
	XORQ R13, R13            // R13 = sawDot
	XORQ R14, R14            // R14 = sawDigit
	XORQ R15, R15            // R15 = digitCount
	
parse_hex_loop:
	CMPQ R8, SI
	JGE return_false         // Need at least one hex digit
	
	MOVBLZX (DI)(R8*1), CX
	XORQ AX, AX              // AX will hold the digit value
	
	// Check if '0'-'9'
	MOVQ CX, BX
	SUBB $CHAR_ZERO, BX
	CMPB BX, $9
	JA not_0_9
	MOVQ BX, AX
	MOVQ $1, R14
	JMP accumulate_hex
	
not_0_9:
	// Check if 'a'-'f'
	MOVQ CX, BX
	SUBB $CHAR_A_LOWER, BX
	CMPB BX, $5
	JA not_a_f
	ADDQ $10, BX
	MOVQ BX, AX
	MOVQ $1, R14
	JMP accumulate_hex
	
not_a_f:
	// Check if 'A'-'F'
	MOVQ CX, BX
	SUBB $CHAR_A_UPPER, BX
	CMPB BX, $5
	JA not_hex_digit
	ADDQ $10, BX
	MOVQ BX, AX
	MOVQ $1, R14
	JMP accumulate_hex
	
not_hex_digit:
	// Check for decimal point
	CMPB CL, $CHAR_DOT
	JNE check_p_marker
	TESTQ R13, R13
	JNZ return_false         // Second dot
	MOVQ $1, R13
	INCQ R8
	JMP parse_hex_loop
	
accumulate_hex:
	// Collect up to 16 hex digits (64 bits)
	CMPQ R15, $16
	JGE skip_hex_digit
	
	SHLQ $4, R10
	ORQ AX, R10
	
	TESTQ R13, R13
	JZ hex_int_digit
	INCQ R12                 // hexFracDigits++
	JMP hex_next
	
hex_int_digit:
	INCQ R11                 // hexIntDigits++
	
hex_next:
	INCQ R15
	
skip_hex_digit:
	INCQ R8
	JMP parse_hex_loop
	
check_p_marker:
	// Must have seen at least one hex digit
	TESTQ R14, R14
	JZ return_false
	
	// Require p or P
	CMPB CX, $CHAR_P_LOWER
	JE parse_binary_exp
	CMPB CX, $CHAR_P_UPPER
	JNE return_false
	
parse_binary_exp:
	INCQ R8
	
	// Check bounds
	CMPQ R8, SI
	JGE return_false
	
	// Parse binary exponent
	XORQ BX, BX              // BX = expNeg
	MOVBLZX (DI)(R8*1), CX
	CMPB CL, $CHAR_MINUS
	JE binary_exp_neg
	CMPB CL, $CHAR_PLUS
	JNE parse_binary_digits
	INCQ R8
	JMP parse_binary_digits
	
binary_exp_neg:
	MOVQ $1, BX
	INCQ R8
	
parse_binary_digits:
	// Check bounds
	CMPQ R8, SI
	JGE return_false
	
	// Must have at least one digit
	MOVBLZX (DI)(R8*1), AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA return_false
	
	XORQ R14, R14            // R14 = exp2
	
binary_digit_loop:
	CMPQ R8, SI
	JGE binary_exp_done
	
	MOVBLZX (DI)(R8*1), CX
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA binary_exp_done
	
	IMULQ $10, R14
	ADDQ AX, R14
	
	// Check for extreme exponent
	CMPQ R14, $10000
	JG return_false
	
	INCQ R8
	JMP binary_digit_loop
	
binary_exp_done:
	// Apply exponent sign
	TESTQ BX, BX
	JZ check_hex_complete
	NEGQ R14
	
check_hex_complete:
	// Must have consumed entire string
	CMPQ R8, SI
	JNE return_false
	
	// Adjust exponent for fractional hex digits
	// exp2 -= hexFracDigits * 4
	MOVQ R12, AX
	SHLQ $2, AX              // * 4
	SUBQ AX, R14
	
	// Check if mantissa is zero
	TESTQ R10, R10
	JZ return_zero_hex
	
	// Use BSR to find leading bit (similar to CLZ)
	BSRQ R10, AX             // Find position of highest set bit
	MOVQ $63, CX
	SUBQ AX, CX              // CX = leading zeros
	
	// Normalize: mantissa <<= shift
	SHLQ CL, R10
	SUBQ CX, R14             // Adjust exponent
	
	// Convert to float64 (simplified - full implementation would do proper rounding)
	// For now, fall back to Go for actual conversion
	JMP return_false
	
return_zero_hex:
	XORPD X0, X0
	TESTQ R9, R9
	JZ store_hex_zero
	MOVQ $0x8000000000000000, AX
	MOVQ AX, X1
	XORPD X1, X0
	
store_hex_zero:
	MOVSD X0, result+16(FP)
	MOVB $1, ok+24(FP)
	RET
	
return_false:
	XORPD X0, X0
	MOVSD X0, result+16(FP)
	MOVB $0, ok+24(FP)
	RET

