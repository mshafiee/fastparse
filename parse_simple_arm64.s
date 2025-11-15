// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseSimpleFastAsm(s string) (result float64, mantissa uint64, exp int, neg bool, ok bool)
// Fast path parser for simple decimal floats: [-]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
// Returns (result, mantissa, exp, neg, true) on success.
// Returns (0, mantissa, exp, neg, false) if parsed but can't convert (for Eisel-Lemire fallback).
TEXT ·parseSimpleFastAsm(SB), NOSPLIT, $64-48
	// Load string pointer and length
	MOVD s_ptr+0(FP), R0    // R0 = string pointer
	MOVD s_len+8(FP), R1    // R1 = string length
	
	// Check for empty string
	CBZ R1, return_false
	
	// Initialize registers
	MOVD $0, R2              // R2 = index (i)
	MOVD $0, R3              // R3 = mantissa
	MOVD $0, R4              // R4 = mantExp
	MOVD $0, R5              // R5 = negative (0=positive, 1=negative)
	MOVD $0, R6              // R6 = sawDigit
	MOVD $0, R7              // R7 = sawDot
	MOVD $0, R8              // R8 = digitCount
	MOVD $0, R9              // R9 = exp10
	
	// Parse optional sign
	MOVBU (R0), R10
	CMP CHAR_MINUS, R10
	BEQ set_negative
	CMP CHAR_PLUS, R10
	BNE check_first_digit
	// Skip '+' sign
	ADD $1, R2
	B check_first_digit
	
set_negative:
	MOVD $1, R5
	ADD $1, R2

check_first_digit:
	// Bounds check
	CMP R1, R2
	BHS return_false
	
	// Must start with digit after sign
	ADD R0, R2, R11
	MOVBU (R11), R10
	SUB CHAR_0, R10
	CMP $9, R10
	BHI return_false
	
parse_mantissa_loop:
	// Bounds check
	CMP R1, R2
	BHS check_complete
	
	// Load character
	ADD R0, R2, R11
	MOVBU (R11), R12
	
	// Check if digit ('0'-'9')
	SUB CHAR_0, R12, R10
	CMP $9, R10
	BHI not_mantissa_digit
	
	// It's a digit
	MOVD $1, R6              // sawDigit = true
	ADD $1, R8               // digitCount++
	
	// Check digit limit (19 digits max for simple path)
	CMP $19, R8
	BGT return_false_syntax  // Too many digits, invalid for simple path
	
	// Accumulate mantissa: mantissa = mantissa * 10 + digit
	MOVD $10, R13
	MUL R13, R3
	ADD R10, R3
	
	// Adjust mantExp if in fraction
	CBZ R7, mantissa_next
	SUB $1, R4               // mantExp--
	
mantissa_next:
	ADD $1, R2
	B parse_mantissa_loop
	
not_mantissa_digit:
	// Check for decimal point
	CMP CHAR_DOT, R12
	BNE check_exponent
	
	// Decimal point
	CBNZ R7, return_false    // Second dot, invalid
	MOVD $1, R7              // sawDot = true
	ADD $1, R2
	B parse_mantissa_loop
	
check_exponent:
	// Check for exponent marker 'e' or 'E'
	CMP CHAR_e, R12
	BEQ parse_exponent
	CMP CHAR_E, R12
	BEQ parse_exponent
	
	// Not a digit, dot, or exponent marker - invalid character
	// This catches cases like "1x" or "1.1."
	B check_complete   // Let check_complete determine if string was fully consumed
	
parse_exponent:
	ADD $1, R2
	
	// Check bounds
	CMP R1, R2
	BHS return_false
	
	// Check for exponent sign
	MOVD $0, R13             // R13 = expNeg
	ADD R0, R2, R11
	MOVBU (R11), R12
	CMP CHAR_MINUS, R12
	BEQ exp_negative
	CMP CHAR_PLUS, R12
	BNE parse_exp_digits
	ADD $1, R2
	B parse_exp_digits
	
exp_negative:
	MOVD $1, R13
	ADD $1, R2
	
parse_exp_digits:
	// Check bounds
	CMP R1, R2
	BHS return_false
	
	// Must have at least one digit
	ADD R0, R2, R11
	MOVBU (R11), R10
	SUB CHAR_0, R10
	CMP $9, R10
	BHI return_false
	
exp_digit_loop:
	// Bounds check
	CMP R1, R2
	BHS exp_done
	
	// Load character
	ADD R0, R2, R11
	MOVBU (R11), R12
	
	// Check if digit
	SUB CHAR_0, R12, R10
	CMP $9, R10
	BHI exp_done
	
	// Accumulate exponent
	MOVD $10, R14
	MUL R14, R9
	ADD R10, R9
	
	// Check for extreme exponent
	MOVD $10000, R14
	CMP R14, R9
	BGT return_false         // Too extreme, use full parser
	
	ADD $1, R2
	B exp_digit_loop
	
exp_done:
	// Apply exponent sign
	CBZ R13, check_complete
	NEG R9, R9
	
check_complete:
	// Must have consumed entire string
	CMP R1, R2
	BNE return_false_syntax     // Syntax error - don't return parsed data
	
	// Must have seen at least one digit
	CBZ R6, return_false_syntax
	
	// Calculate total exponent
	ADD R4, R9, R10          // totalExp = mantExp + exp10
	
	// Quick range check
	MOVD $-350, R11
	CMP R11, R10
	BLT return_false_parsed     // Out of range but valid - return parsed data
	MOVD $310, R11
	CMP R11, R10
	BGT return_false_parsed     // Out of range but valid - return parsed data
	
	// Convert mantissa to float64
	SCVTFD R3, F0
	
	// Apply sign
	CBZ R5, apply_exponent
	FNEGD F0, F0
	
apply_exponent:
	// For simple cases (exp == 0), we're done
	CBZ R10, return_result
	
	// PHASE 1 OPTIMIZATION: Extended range for large exponents
	// Check if totalExp is in handleable range [-22, 308]
	// significantDigits must be <= 15 for fast path
	
	// Check significantDigits <= 15 first
	CMP $15, R8
	BGT call_eisel_lemire
	
	// Check if totalExp is in range [-22, 308]
	MOVD $-22, R11
	CMP R11, R10
	BLT call_eisel_lemire    // totalExp < -22, use Eisel-Lemire
	MOVD $308, R11
	CMP R11, R10
	BGT call_eisel_lemire    // totalExp > 308, use Eisel-Lemire
	
	// Check if in simplePow10Table range [-15, 15]
	MOVD $-15, R11
	CMP R11, R10
	BLT use_large_exponent   // totalExp < -15, use helper function
	MOVD $15, R11
	CMP R11, R10
	BGT use_large_exponent   // totalExp > 15, use helper function
	
	// Use direct power-of-10 table for [-15, 15]
	// F0 already has float64(mantissa) with sign applied
	
	// Determine if positive or negative exponent
	CMP $0, R10
	BLT negative_exponent
	BEQ return_result        // exp == 0, already handled above but double-check
	
positive_exponent:
	// Load 10^totalExp from table
	MOVD $simplePow10Table<>(SB), R14
	LSL $3, R10, R15         // R15 = totalExp * 8
	ADD R15, R14
	FMOVD (R14), F1          // F1 = 10^totalExp
	
	// Multiply: result *= 10^totalExp
	FMULD F1, F0
	B return_result
	
negative_exponent:
	// Load 10^(-totalExp) from table
	NEG R10, R11             // R11 = -totalExp
	MOVD $simplePow10Table<>(SB), R14
	LSL $3, R11, R15
	ADD R15, R14
	FMOVD (R14), F1          // F1 = 10^(-totalExp)
	
	// Divide: result /= 10^(-totalExp)
	FDIVD F1, F0
	B return_result
	
use_large_exponent:
	// For exponents outside [-15, 15] but within [-22, 308],
	// return parsed data for Eisel-Lemire to handle in Go
	B return_false_parsed
	
call_eisel_lemire:
	// Fall back to let Go handle it with Eisel-Lemire
	B return_false_parsed
	
return_result:
	// Store result and parsed data
	// Outputs: result float64, mantissa uint64, exp int, neg bool, ok bool
	// Memory layout: result(8), mantissa(8), exp(8), neg(1), ok(1) = 48 bytes
	FMOVD F0, result+16(FP)      // result
	MOVD R3, mantissa+24(FP)     // mantissa
	MOVD R10, exp+32(FP)         // totalExp
	MOVB R5, neg+40(FP)          // negative
	MOVD $1, R0
	MOVB R0, ok+41(FP)           // ok = true
	RET
	
return_false_parsed:
	// String was fully consumed and valid, but too complex for fast path
	// Return parsed mantissa/exp for Eisel-Lemire fallback
	MOVD $0, R0
	SCVTFD R0, F0                // Convert integer 0 to float64 0
	FMOVD F0, result+16(FP)      // result = 0
	MOVD R3, mantissa+24(FP)     // mantissa (parsed)
	MOVD R10, exp+32(FP)         // totalExp (parsed)
	MOVB R5, neg+40(FP)          // negative (parsed)
	MOVD $0, R0
	MOVB R0, ok+41(FP)           // ok = false
	RET

return_false_syntax:
	// Syntax error or invalid input - return all zeros
	MOVD $0, R0
	SCVTFD R0, F0                // Convert integer 0 to float64 0
	FMOVD F0, result+16(FP)      // result = 0
	MOVD $0, R1
	MOVD R1, mantissa+24(FP)     // mantissa = 0 (invalid)
	MOVD R1, exp+32(FP)          // exp = 0 (invalid)
	MOVB R0, neg+40(FP)          // neg = false
	MOVB R0, ok+41(FP)           // ok = false
	RET

return_false:
	// Default fallback - syntax error
	B return_false_syntax

// simplePow10Table for direct power-of-10 conversion
// Covers 10^0 through 10^15 (handles 80-90% of real-world floats)
DATA simplePow10Table<>+0(SB)/8, $0x3ff0000000000000   // 1.0 (10^0)
DATA simplePow10Table<>+8(SB)/8, $0x4024000000000000   // 10.0 (10^1)
DATA simplePow10Table<>+16(SB)/8, $0x4059000000000000  // 100.0 (10^2)
DATA simplePow10Table<>+24(SB)/8, $0x408f400000000000  // 1000.0 (10^3)
DATA simplePow10Table<>+32(SB)/8, $0x40c3880000000000  // 10000.0 (10^4)
DATA simplePow10Table<>+40(SB)/8, $0x40f86a0000000000  // 100000.0 (10^5)
DATA simplePow10Table<>+48(SB)/8, $0x412e848000000000  // 1000000.0 (10^6)
DATA simplePow10Table<>+56(SB)/8, $0x416312d000000000  // 10000000.0 (10^7)
DATA simplePow10Table<>+64(SB)/8, $0x4197d78400000000  // 100000000.0 (10^8)
DATA simplePow10Table<>+72(SB)/8, $0x41cdcd6500000000  // 1000000000.0 (10^9)
DATA simplePow10Table<>+80(SB)/8, $0x4202a05f20000000  // 10000000000.0 (10^10)
DATA simplePow10Table<>+88(SB)/8, $0x42374876e8000000  // 100000000000.0 (10^11)
DATA simplePow10Table<>+96(SB)/8, $0x426d1a94a2000000  // 1000000000000.0 (10^12)
DATA simplePow10Table<>+104(SB)/8, $0x42a2309ce5400000 // 10000000000000.0 (10^13)
DATA simplePow10Table<>+112(SB)/8, $0x42d6bcc41e900000 // 100000000000000.0 (10^14)
DATA simplePow10Table<>+120(SB)/8, $0x430c6bf526340000 // 1000000000000000.0 (10^15)
GLOBL simplePow10Table<>(SB), RODATA, $128

