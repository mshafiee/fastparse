// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseDirectFloatAsm(s string) (result float64, ok bool)
// Ultra-fast direct conversion for common float patterns
// Handles: integers, simple decimals (≤8 digits), small exponents (≤15)
TEXT ·parseDirectFloatAsm(SB), NOSPLIT, $64-25
	// Load string pointer and length
	MOVD s_base+0(FP), R0    // R0 = string pointer
	MOVD s_len+8(FP), R1     // R1 = string length
	
	// Quick reject: empty or too long
	CBZ R1, return_false
	CMP $16, R1
	BGT return_false
	
	// Initialize registers
	MOVD $0, R2              // R2 = index
	MOVD $0, R3              // R3 = intPart
	MOVD $0, R4              // R4 = negative flag
	MOVD $0, R5              // R5 = intDigits
	
	// Parse optional sign
	MOVBU (R0), R10
	CMP CHAR_MINUS, R10
	BEQ set_negative
	CMP CHAR_PLUS, R10
	BNE check_first_digit
	ADD $1, R2
	B check_first_digit
	
set_negative:
	MOVD $1, R4
	ADD $1, R2
	
check_first_digit:
	// Bounds check
	CMP R1, R2
	BHS return_false
	
	// Must start with digit
	ADD R0, R2, R11
	MOVBU (R11), R10
	SUB CHAR_0, R10
	CMP $9, R10
	BHI return_false
	
	// Parse integer part
parse_int_loop:
	CMP R1, R2
	BHS int_only_fast_path  // Pure integer, no decimal/exp
	
	ADD R0, R2, R11
	MOVBU (R11), R12
	
	// Check if digit
	SUB CHAR_0, R12, R10
	CMP $9, R10
	BHI not_int_digit
	
	// Limit to 8 digits for direct conversion
	CMP $8, R5
	BHS return_false
	
	// Accumulate: intPart = intPart * 10 + digit
	MOVD $10, R13
	MUL R13, R3
	ADD R10, R3
	ADD $1, R5
	ADD $1, R2
	B parse_int_loop
	
not_int_digit:
	// Any non-digit character - fall back to parseSimpleFast
	// which has Eisel-Lemire inlined for correct rounding
	B return_false
	
int_only_fast_path:
	// Pure integer: convert to float64
	SCVTFD R3, F0            // F0 = float64(intPart)
	
	// Apply sign if negative
	CBZ R4, store_result
	
	// Negate
	FNEGD F0, F0
	B store_result
	
store_result:
	// Store result
	FMOVD F0, result+16(FP)
	MOVD $1, R10
	MOVB R10, ok+24(FP)
	RET
	
return_false:
	// Return (0, false)
	FMOVD ZR, F0
	FMOVD F0, result+16(FP)
	MOVB ZR, ok+24(FP)
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

