// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseDirectFloatAsm(s string) (result float64, ok bool)
// Ultra-fast direct conversion for common float patterns
// Handles: integers, simple decimals (≤8 digits), small exponents (≤15)
TEXT ·parseDirectFloatAsm(SB), NOSPLIT, $64-33
	// Load string pointer and length
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	
	// Quick reject: empty or too long
	TESTQ SI, SI
	JZ return_false
	CMPQ SI, $16
	JG return_false
	
	// Initialize registers
	XORQ R8, R8              // R8 = index
	XORQ R9, R9              // R9 = intPart
	XORQ R10, R10            // R10 = negative flag
	XORQ R11, R11            // R11 = intDigits
	
	// Parse optional sign
	MOVBLZX (DI), AX
	CMPB AX, CHAR_MINUS
	JE set_negative
	CMPB AX, CHAR_PLUS
	JNE check_first_digit
	INCQ R8
	JMP check_first_digit
	
set_negative:
	MOVQ $1, R10
	INCQ R8
	
check_first_digit:
	// Bounds check
	CMPQ R8, SI
	JGE return_false
	
	// Must start with digit
	MOVBLZX (DI)(R8*1), AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA return_false
	
	// Parse integer part
parse_int_loop:
	CMPQ R8, SI
	JGE int_only_fast_path  // Pure integer, no decimal/exp
	
	MOVBLZX (DI)(R8*1), CX
	
	// Check if digit
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA not_int_digit
	
	// Limit to 8 digits for direct conversion
	CMPQ R11, $8
	JGE return_false
	
	// Accumulate: intPart = intPart * 10 + digit
	IMULQ $10, R9
	ADDQ AX, R9
	INCQ R11
	INCQ R8
	JMP parse_int_loop
	
not_int_digit:
	// Any non-digit character - fall back to parseSimpleFast
	// which has Eisel-Lemire inlined for correct rounding
	JMP return_false
	
int_only_fast_path:
	// Pure integer: convert to float64
	CVTSQ2SD R9, X0          // X0 = float64(intPart)
	
	// Apply sign if negative
	TESTQ R10, R10
	JZ store_result
	
	// Negate
	MOVSD CONST_NEG_ZERO<>(SB), X1
	XORPD X1, X0
	JMP store_result
	
store_result:
	// Store result
	MOVSD X0, result+16(FP)
	MOVB $1, ok+24(FP)
	RET
	
return_false:
	// Return (0, false)
	XORPD X0, X0
	MOVSD X0, result+16(FP)
	MOVB $0, ok+24(FP)
	RET

// Power of 10 table for direct computation
// Covers 10^0 through 10^15
DATA pow10_table<>+0(SB)/8, $0x3ff0000000000000   // 1.0
DATA pow10_table<>+8(SB)/8, $0x4024000000000000   // 10.0
DATA pow10_table<>+16(SB)/8, $0x4059000000000000  // 100.0
DATA pow10_table<>+24(SB)/8, $0x408f400000000000  // 1000.0
DATA pow10_table<>+32(SB)/8, $0x40c3880000000000  // 10000.0
DATA pow10_table<>+40(SB)/8, $0x40f86a0000000000  // 100000.0
DATA pow10_table<>+48(SB)/8, $0x412e848000000000  // 1000000.0
DATA pow10_table<>+56(SB)/8, $0x416312d000000000  // 10000000.0
DATA pow10_table<>+64(SB)/8, $0x4197d78400000000  // 100000000.0
DATA pow10_table<>+72(SB)/8, $0x41cdcd6500000000  // 1000000000.0
DATA pow10_table<>+80(SB)/8, $0x4202a05f20000000  // 10000000000.0
DATA pow10_table<>+88(SB)/8, $0x42374876e8000000  // 100000000000.0
DATA pow10_table<>+96(SB)/8, $0x426d1a94a2000000  // 1000000000000.0
DATA pow10_table<>+104(SB)/8, $0x42a2309ce5400000 // 10000000000000.0
DATA pow10_table<>+112(SB)/8, $0x42d6bcc41e900000 // 100000000000000.0
DATA pow10_table<>+120(SB)/8, $0x430c6bf526340000 // 1000000000000000.0
GLOBL pow10_table<>(SB), RODATA, $128

// Constant for negation
DATA CONST_NEG_ZERO<>+0(SB)/8, $0x8000000000000000
GLOBL CONST_NEG_ZERO<>(SB), RODATA, $8

