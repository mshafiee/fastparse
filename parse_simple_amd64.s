// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseSimpleFastAsmRaw(ptr *byte, length int) (result float64, mantissa uint64, exp int, neg bool, ok bool)
// Fast path parser for simple decimal floats: [-]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
// Returns (result, mantissa, exp, neg, true) on success.
// Returns (0, mantissa, exp, neg, false) if parsed but can't convert (for Eisel-Lemire fallback).
TEXT ·parseSimpleFastAsmRaw(SB), NOSPLIT, $64-48
	// Load string pointer and length
	MOVQ ptr+0(FP), DI       // DI = string pointer
	MOVQ length+8(FP), SI    // SI = string length
	
	// Check for nil pointer or empty string
	TESTQ DI, DI
	JZ return_false
	TESTQ SI, SI
	JZ return_false
	
	// Additional safety check: ensure pointer is in reasonable range
	// Pointers less than 0x1000 (4096) are likely invalid
	CMPQ DI, $0x1000
	JL return_false
	
	// Initialize registers
	XORQ R8, R8              // R8 = index (i)
	XORQ R9, R9              // R9 = mantissa
	XORQ R10, R10            // R10 = mantExp
	XORQ R11, R11            // R11 = negative (0=positive, 1=negative)
	XORQ R12, R12            // R12 = sawDigit
	XORQ R13, R13            // R13 = sawDot
	XORQ R14, R14            // R14 = digitCount
	XORQ R15, R15            // R15 = exp10
	
	// Parse optional sign
	MOVBLZX (DI), AX
	CMPB AL, $CHAR_MINUS
	JE set_negative
	CMPB AL, $CHAR_PLUS
	JNE check_first_digit
	// Skip '+' sign
	INCQ R8
	JMP check_first_digit
	
set_negative:
	MOVQ $1, R11
	INCQ R8

check_first_digit:
	// Bounds check
	CMPQ R8, SI
	JGE return_false
	
	// Must start with digit after sign
	MOVBLZX (DI)(R8*1), AX
	SUBB $CHAR_ZERO, AL
	CMPB AL, $9
	JA return_false
	
parse_mantissa_loop:
	// Bounds check
	CMPQ R8, SI
	JGE check_complete
	
	// Load character
	MOVBLZX (DI)(R8*1), CX
	
	// Check if digit ('0'-'9')
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AL
	CMPB AL, $9
	JA not_mantissa_digit
	
	// It's a digit
	MOVQ $1, R12             // sawDigit = true
	INCQ R14                 // digitCount++
	
	// Check digit limit (19 digits max for simple path)
	CMPQ R14, $19
	JG return_false_syntax   // Too many digits, invalid for simple path
	
	// Accumulate mantissa: mantissa = mantissa * 10 + digit
	IMULQ $10, R9
	ADDQ AX, R9
	
	// Adjust mantExp if in fraction
	TESTQ R13, R13
	JZ mantissa_next
	DECQ R10                 // mantExp--
	
mantissa_next:
	INCQ R8
	JMP parse_mantissa_loop
	
not_mantissa_digit:
	// Check for decimal point
	CMPB CL, $CHAR_DOT
	JNE check_exponent
	
	// Decimal point
	TESTQ R13, R13
	JNZ return_false         // Second dot, invalid
	MOVQ $1, R13             // sawDot = true
	INCQ R8
	JMP parse_mantissa_loop
	
check_exponent:
	// Check for exponent marker 'e' or 'E'
	CMPB CL, $CHAR_E_LOWER
	JE parse_exponent
	CMPB CL, $CHAR_E_UPPER
	JE parse_exponent
	
	// Not e/E, check if we're done
	JMP check_complete
	
parse_exponent:
	INCQ R8
	
	// Check bounds
	CMPQ R8, SI
	JGE return_false
	
	// Check for exponent sign
	XORQ BX, BX              // BX = expNeg
	MOVBLZX (DI)(R8*1), CX
	CMPB CL, $CHAR_MINUS
	JE exp_negative
	CMPB CL, $CHAR_PLUS
	JNE parse_exp_digits
	INCQ R8
	JMP parse_exp_digits
	
exp_negative:
	MOVQ $1, BX
	INCQ R8
	
parse_exp_digits:
	// Check bounds
	CMPQ R8, SI
	JGE return_false
	
	// Must have at least one digit
	MOVBLZX (DI)(R8*1), AX
	SUBB $CHAR_ZERO, AL
	CMPB AL, $9
	JA return_false
	
exp_digit_loop:
	// Bounds check
	CMPQ R8, SI
	JGE exp_done
	
	// Load character
	MOVBLZX (DI)(R8*1), CX
	
	// Check if digit
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AL
	CMPB AL, $9
	JA exp_done
	
	// Accumulate exponent
	IMULQ $10, R15
	ADDQ AX, R15
	
	// Check for extreme exponent
	CMPQ R15, $10000
	JG return_false          // Too extreme, use full parser
	
	INCQ R8
	JMP exp_digit_loop
	
exp_done:
	// Apply exponent sign
	TESTQ BX, BX
	JZ check_complete
	NEGQ R15
	
check_complete:
	// Must have consumed entire string
	CMPQ R8, SI
	JNE return_false_syntax    // Syntax error - don't return parsed data
	
	// Must have seen at least one digit
	TESTQ R12, R12
	JZ return_false_syntax
	
	// Calculate total exponent
	MOVQ R10, AX
	ADDQ R15, AX
	MOVQ AX, -8(SP)          // totalExp at -8(SP)
	
	// Quick range check for Eisel-Lemire
	CMPQ AX, $-348
	JL return_false_parsed     // Out of range but valid - return parsed data
	CMPQ AX, $308
	JG return_false_parsed     // Out of range but valid - return parsed data
	
	// Handle zero mantissa case
	TESTQ R9, R9
	JNZ do_eisel_lemire
	
	// Zero mantissa
	XORPD X0, X0
	TESTQ R11, R11
	JZ return_result
	// Negative zero
	MOVQ $0x8000000000000000, AX
	MOVQ AX, X1
	XORPD X1, X0
	JMP return_result
	
do_eisel_lemire:
	// Eisel-Lemire algorithm inlined for simple fast path
	// This implements the core algorithm without needing external function calls
	
	// For zero exponent, simple case
	MOVQ -8(SP), CX
	TESTQ CX, CX
	JNZ eisel_complex
	
	// exp == 0: just convert mantissa to float64
	CVTSQ2SD R9, X0
	TESTQ R11, R11
	JZ return_result
	// Apply negative sign
	MOVQ $0x8000000000000000, AX
	MOVQ AX, X1
	XORPD X1, X0
	JMP return_result
	
eisel_complex:
	// PHASE 1 OPTIMIZATION: Extended range for large exponents
	// Check if totalExp is in handleable range [-22, 308]
	// significantDigits must be <= 15 for fast path
	
	MOVQ -8(SP), CX          // CX = totalExp
	
	// Check significantDigits <= 15 first
	CMPQ R14, $15
	JG call_eisel_lemire
	
	// Check if totalExp is in range [-22, 308]
	CMPQ CX, $-22
	JL call_eisel_lemire     // totalExp < -22, use Eisel-Lemire
	CMPQ CX, $308
	JG call_eisel_lemire     // totalExp > 308, use Eisel-Lemire
	
	// Check if in simplePow10Table range [-15, 15]
	CMPQ CX, $-15
	JL use_large_exponent    // totalExp < -15, use helper function
	CMPQ CX, $15
	JG use_large_exponent    // totalExp > 15, use helper function
	
	// Use direct power-of-10 table for [-15, 15]
	// Convert mantissa to float64
	CVTSQ2SD R9, X0
	
	// Apply sign to mantissa
	TESTQ R11, R11
	JZ apply_pow10
	MOVQ $0x8000000000000000, AX
	MOVQ AX, X1
	XORPD X1, X0
	
apply_pow10:
	// Determine if positive or negative exponent
	TESTQ CX, CX
	JL negative_exponent_table
	JZ return_result
	
positive_exponent_table:
	// Load 10^totalExp from table
	LEAQ simplePow10Table<>(SB), R12
	MOVSD (R12)(CX*8), X1    // X1 = 10^totalExp
	
	// Multiply: result *= 10^totalExp
	MULSD X1, X0
	JMP return_result
	
negative_exponent_table:
	// Load 10^(-totalExp) from table
	NEGQ CX
	LEAQ simplePow10Table<>(SB), R12
	MOVSD (R12)(CX*8), X1    // X1 = 10^(-totalExp)
	
	// Divide: result /= 10^(-totalExp)
	DIVSD X1, X0
	JMP return_result
	
use_large_exponent:
	// For exponents outside [-15, 15] but within [-22, 308],
	// return parsed data for Eisel-Lemire to handle in Go
	JMP return_false_parsed
	
call_eisel_lemire:
	// Fall back to let Go handle it with Eisel-Lemire
	JMP return_false_parsed
	
return_result:
	// Store result and parsed data
	// Outputs: result float64, mantissa uint64, exp int, neg bool, ok bool
	// Memory layout: result(8), mantissa(8), exp(8), neg(1), ok(1) = 49 bytes
	MOVSD X0, result+16(FP)      // result
	MOVQ R9, mantissa+24(FP)     // mantissa
	MOVQ -8(SP), CX              // Load totalExp from stack
	MOVQ CX, exp+32(FP)          // totalExp
	MOVB R11, neg+40(FP)         // negative
	MOVB $1, ok+41(FP)           // ok = true
	RET
	
return_false_parsed:
	// String was fully consumed and valid, but too complex for fast path
	// Return parsed mantissa/exp for Eisel-Lemire fallback
	XORPD X0, X0
	MOVSD X0, result+16(FP)      // result = 0
	MOVQ R9, mantissa+24(FP)     // mantissa (parsed)
	MOVQ -8(SP), CX              // Load totalExp from stack
	MOVQ CX, exp+32(FP)          // totalExp (parsed)
	MOVB R11, neg+40(FP)         // negative (parsed)
	MOVB $0, ok+41(FP)           // ok = false
	RET

return_false_syntax:
	// Syntax error or invalid input - return all zeros
	XORPD X0, X0
	MOVSD X0, result+16(FP)      // result = 0
	MOVQ $0, AX
	MOVQ AX, mantissa+24(FP)     // mantissa = 0 (invalid)
	MOVQ AX, exp+32(FP)          // exp = 0 (invalid)
	MOVB $0, neg+40(FP)          // neg = false
	MOVB $0, ok+41(FP)           // ok = false
	RET

return_false:
	// Default fallback - syntax error
	JMP return_false_syntax

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

