// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseHexFastAsm(s string) (result float64, ok bool)
// Fast path parser for hex floats: [-]?0[xX][0-9a-fA-F]+\.?[0-9a-fA-F]*[pP][-+]?[0-9]+
TEXT ·parseHexFastAsm(SB), NOSPLIT, $96-25
	// Load string pointer and length
	MOVD s_base+0(FP), R0    // R0 = string pointer
	MOVD s_len+8(FP), R1     // R1 = string length
	
	// Check minimum length (need at least "0x0p0" = 5 chars)
	CMP $5, R1
	BLT return_false
	
	// Initialize
	MOVD $0, R2              // R2 = index (i)
	MOVD $0, R3              // R3 = negative
	
	// Optional sign
	MOVBU (R0), R4
	CMP CHAR_MINUS, R4
	BEQ set_negative
	CMP CHAR_PLUS, R4
	BNE check_0x_prefix
	ADD $1, R2
	B check_0x_prefix
	
set_negative:
	MOVD $1, R3
	ADD $1, R2
	
check_0x_prefix:
	// Require 0x prefix
	CMP R1, R2
	BHS return_false
	ADD R0, R2, R10
	MOVBU (R10), R4
	CMP CHAR_0, R4
	BNE return_false
	
	ADD $1, R2
	CMP R1, R2
	BHS return_false
	ADD R0, R2, R10
	MOVBU (R10), R4
	CMP CHAR_x, R4
	BEQ has_x
	CMP CHAR_X, R4
	BNE return_false
	
has_x:
	ADD $1, R2
	
	// Parse hex mantissa
	MOVD $0, R5              // R5 = mantissa
	MOVD $0, R6              // R6 = hexIntDigits
	MOVD $0, R7              // R7 = hexFracDigits
	MOVD $0, R8              // R8 = sawDot
	MOVD $0, R9              // R9 = sawDigit
	MOVD $0, R11             // R11 = digitCount
	
parse_hex_loop:
	CMP R1, R2
	BHS return_false         // Need at least one hex digit
	
	ADD R0, R2, R10
	MOVBU (R10), R12
	MOVD $0, R13             // R13 will hold the digit value
	
	// Check if '0'-'9'
	SUB CHAR_0, R12, R14
	CMP $9, R14
	BHI not_0_9
	MOVD R14, R13
	MOVD $1, R9
	B accumulate_hex
	
not_0_9:
	// Check if 'a'-'f'
	SUB CHAR_a, R12, R14
	CMP $5, R14
	BHI not_a_f
	ADD $10, R14
	MOVD R14, R13
	MOVD $1, R9
	B accumulate_hex
	
not_a_f:
	// Check if 'A'-'F'
	SUB CHAR_A, R12, R14
	CMP $5, R14
	BHI not_hex_digit
	ADD $10, R14
	MOVD R14, R13
	MOVD $1, R9
	B accumulate_hex
	
not_hex_digit:
	// Check for decimal point
	CMP CHAR_DOT, R12
	BNE check_p_marker
	CBNZ R8, return_false    // Second dot
	MOVD $1, R8
	ADD $1, R2
	B parse_hex_loop
	
accumulate_hex:
	// Collect up to 16 hex digits (64 bits)
	CMP $16, R11
	BHS skip_hex_digit
	
	LSL $4, R5
	ORR R13, R5
	
	CBZ R8, hex_int_digit
	ADD $1, R7               // hexFracDigits++
	B hex_next
	
hex_int_digit:
	ADD $1, R6               // hexIntDigits++
	
hex_next:
	ADD $1, R11
	
skip_hex_digit:
	ADD $1, R2
	B parse_hex_loop
	
check_p_marker:
	// Must have seen at least one hex digit
	CBZ R9, return_false
	
	// Require p or P
	CMP CHAR_p, R12
	BEQ parse_binary_exp
	CMP CHAR_P, R12
	BNE return_false
	
parse_binary_exp:
	ADD $1, R2
	
	// Check bounds
	CMP R1, R2
	BHS return_false
	
	// Parse binary exponent
	MOVD $0, R14             // R14 = expNeg
	ADD R0, R2, R10
	MOVBU (R10), R12
	CMP CHAR_MINUS, R12
	BEQ binary_exp_neg
	CMP CHAR_PLUS, R12
	BNE parse_binary_digits
	ADD $1, R2
	B parse_binary_digits
	
binary_exp_neg:
	MOVD $1, R14
	ADD $1, R2
	
parse_binary_digits:
	// Check bounds
	CMP R1, R2
	BHS return_false
	
	// Must have at least one digit
	ADD R0, R2, R10
	MOVBU (R10), R4
	SUB CHAR_0, R4
	CMP $9, R4
	BHI return_false
	
	MOVD $0, R15             // R15 = exp2
	
binary_digit_loop:
	CMP R1, R2
	BHS binary_exp_done
	
	ADD R0, R2, R10
	MOVBU (R10), R12
	SUB CHAR_0, R12, R4
	CMP $9, R4
	BHI binary_exp_done
	
	MOVD $10, R16
	MUL R16, R15
	ADD R4, R15
	
	// Check for extreme exponent
	MOVD $10000, R16
	CMP R16, R15
	BGT return_false
	
	ADD $1, R2
	B binary_digit_loop
	
binary_exp_done:
	// Apply exponent sign
	CBZ R14, check_hex_complete
	NEG R15, R15
	
check_hex_complete:
	// Must have consumed entire string
	CMP R1, R2
	BNE return_false
	
	// Adjust exponent for fractional hex digits
	// exp2 -= hexFracDigits * 4
	LSL $2, R7, R4           // * 4
	SUB R4, R15
	
	// Check if mantissa is zero
	CBZ R5, return_zero_hex
	
	// Use CLZ to find leading zeros
	CLZ R5, R4
	
	// Normalize: mantissa <<= shift
	LSL R4, R5
	SUB R4, R15              // Adjust exponent
	
	// Convert to float64 (simplified - full implementation would do proper rounding)
	// For now, fall back to Go for actual conversion
	B return_false
	
return_zero_hex:
	MOVD $0, R0
	SCVTFD R0, F0            // Convert integer 0 to float64 0
	CBZ R3, store_hex_zero
	FNEGD F0, F0
	
store_hex_zero:
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

