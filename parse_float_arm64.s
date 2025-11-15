// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func ParseFloatAsm(s string) (float64, error)
//
// Scalar fast path for simple decimal floats: [-]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
// Falls back to Go for complex cases (hex, inf/nan, underscores, very long inputs).
//
// Register layout:
// R0 = s.ptr (input pointer)
// R1 = s.len (input length)
// R2 = current index
// R3 = mantissa (uint64)
// R4 = exp10 (int64)
// R5 = negative flag (0 or 1)
// R6 = saw_dot flag
// R7 = digit_count
// R8-R12 = scratch
//
// Returns:
// F0 = result (float64)
// 16(FP) = error interface type
// 24(FP) = error interface data
TEXT ·ParseFloatAsm(SB), 0, $48-32
	MOVD s_base+0(FP), R0
	MOVD s_len+8(FP), R1
	
	// Check for empty string
	CBZ  R1, fallback
	
	// Check for very long strings (> 100 chars) - fall back
	MOVD $100, R8
	CMP  R8, R1
	BGT  fallback
	
	// Check first char for special patterns
	MOVBU (R0), R8
	
	// Check for 'i', 'I', 'n', 'N' (inf/nan) - fall back
	CMP $'i', R8
	BEQ fallback
	CMP $'I', R8
	BEQ fallback
	CMP $'n', R8
	BEQ fallback
	CMP $'N', R8
	BEQ fallback
	
	// Check for hex prefix '0' followed by 'x' or 'X' - fall back
	CMP $'0', R8
	BNE check_sign
	CMP $1, R1  // need at least 2 chars
	BLE check_sign
	MOVBU 1(R0), R9
	CMP $'x', R9
	BEQ fallback
	CMP $'X', R9
	BEQ fallback
	
check_sign:
	// Initialize state
	MOVD $0, R2     // R2 = index = 0
	MOVD $0, R3     // R3 = mantissa = 0
	MOVD $0, R4     // R4 = exp10 = 0
	MOVD $0, R5     // R5 = negative = 0
	MOVD $0, R6     // R6 = saw_dot = 0
	MOVD $0, R7     // R7 = digit_count = 0
	
	// Load first character
	MOVBU (R0), R8
	
	// Handle optional sign
	CMP $'-', R8
	BEQ handle_negative
	CMP $'+', R8
	BEQ handle_positive
	B   parse_int_part
	
handle_negative:
	MOVD $1, R5     // negative = 1
	ADD  $1, R2     // index++
	ADD  $1, R0     // ptr++
	SUB  $1, R1     // len--
	CBZ  R1, fallback  // empty after sign
	B    parse_int_part
	
handle_positive:
	ADD  $1, R2     // index++
	ADD  $1, R0     // ptr++
	SUB  $1, R1     // len--
	CBZ  R1, fallback  // empty after sign
	
parse_int_part:
	// Parse integer part digits
int_loop:
	CBZ R1, finalize  // end of string
	
	MOVBU (R0), R8
	
	// Check if it's a digit
	SUB $'0', R8, R9
	CMP $9, R9
	BHI not_int_digit
	
	// It's a digit
	ADD $1, R7  // digit_count++
	
	// Check if we've exceeded 19 significant digits - fall back for precision
	CMP $19, R7
	BGT fallback
	
	// Accumulate: mantissa = mantissa * 10 + digit
	MOVD $10, R10
	MUL  R10, R3, R3
	ADD  R9, R3
	
	// Move to next char
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	B    int_loop
	
not_int_digit:
	// Check for decimal point
	CMP $'.', R8
	BEQ handle_dot
	
	// Check for exponent marker
	CMP $'e', R8
	BEQ handle_exp
	CMP $'E', R8
	BEQ handle_exp
	
	// Check for underscore - fall back (complex pattern)
	CMP $'_', R8
	BEQ fallback
	
	// Unknown character - fall back
	B fallback
	
handle_dot:
	// Ensure we haven't seen a dot before
	CBNZ R6, fallback
	MOVD $1, R6  // saw_dot = 1
	
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	CBZ  R1, finalize  // dot at end is OK
	
frac_loop:
	CBZ R1, finalize
	
	MOVBU (R0), R8
	
	// Check if it's a digit
	SUB $'0', R8, R9
	CMP $9, R9
	BHI not_frac_digit
	
	// It's a digit
	ADD $1, R7  // digit_count++
	
	// Check for too many digits
	CMP $19, R7
	BGT fallback
	
	// Accumulate: mantissa = mantissa * 10 + digit
	MOVD $10, R10
	MUL  R10, R3, R3
	ADD  R9, R3
	
	// Decrement exp10 for fractional digit
	SUB $1, R4
	
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	B    frac_loop
	
not_frac_digit:
	// Check for exponent marker
	CMP $'e', R8
	BEQ handle_exp
	CMP $'E', R8
	BEQ handle_exp
	
	// Check for underscore
	CMP $'_', R8
	BEQ fallback
	
	// Unknown character
	B fallback
	
handle_exp:
	// Must have at least one digit before exponent
	CBZ R7, fallback
	
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	CBZ  R1, fallback  // need digits after 'e'
	
	// Parse exponent sign
	MOVBU (R0), R8
	MOVD  $0, R10   // exp_negative = 0
	
	CMP $'-', R8
	BEQ exp_negative
	CMP $'+', R8
	BEQ exp_positive
	B   parse_exp_digits
	
exp_negative:
	MOVD $1, R10
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	CBZ  R1, fallback
	B    parse_exp_digits
	
exp_positive:
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	CBZ  R1, fallback
	
parse_exp_digits:
	MOVD $0, R11  // exp_value = 0
	MOVD $0, R12  // exp_digit_count = 0
	
exp_loop:
	CBZ R1, exp_done
	
	MOVBU (R0), R8
	
	// Check if it's a digit
	SUB $'0', R8, R9
	CMP $9, R9
	BHI not_exp_digit
	
	ADD $1, R12  // exp_digit_count++
	
	// Check for overflow in exponent
	CMP $4, R12
	BGT fallback  // exponent too large
	
	// Accumulate: exp_value = exp_value * 10 + digit
	MOVD $10, R13
	MUL  R13, R11, R11
	ADD  R9, R11
	
	ADD  $1, R2
	ADD  $1, R0
	SUB  $1, R1
	B    exp_loop
	
not_exp_digit:
	// Check for underscore
	CMP $'_', R8
	BEQ fallback
	
	// Unknown character in exponent
	B fallback
	
exp_done:
	// Must have at least one exponent digit
	CBZ R12, fallback
	
	// Apply exponent sign
	CBNZ R10, exp_neg_apply
	// Positive exponent
	ADD R11, R4  // exp10 += exp_value
	B   finalize
	
exp_neg_apply:
	// Negative exponent
	SUB R11, R4  // exp10 -= exp_value
	
finalize:
	// Must have at least one digit
	CBZ R7, fallback
	
	// Call Go helper to convert decimal to float64
	// Save our registers to stack first
	MOVD R3, 8(RSP)      // mantissa
	MOVD R4, 16(RSP)     // exp10
	MOVD R5, 24(RSP)     // negative
	
	// Call convertSimpleDecimal(mantissa uint64, exp10 int64, negative uint64) (float64, uint64)
	CALL ·convertSimpleDecimal(SB)
	
	// Check error code (second return value)
	MOVD 40(RSP), R0
	CBNZ R0, fallback     // If non-zero, fall back to full parser
	
	// Success - get the result
	FMOVD 32(RSP), F0
	FMOVD F0, ret+16(FP)
	
	// Return nil error
	MOVD ·nilError(SB), R0
	MOVD R0, ret_err_type+24(FP)
	MOVD $0, ret_err_data+32(FP)
	RET
	
fallback:
	// Call full Go implementation
	MOVD s_base+0(FP), R0
	MOVD s_len+8(FP), R1
	
	MOVD R0, 8(RSP)
	MOVD R1, 16(RSP)
	
	CALL ·parseFloatFallback(SB)
	
	FMOVD 24(RSP), F0
	FMOVD F0, ret+16(FP)
	
	MOVD 32(RSP), R0
	MOVD 40(RSP), R1
	MOVD R0, ret_err_type+24(FP)
	MOVD R1, ret_err_data+32(FP)
	
	RET

