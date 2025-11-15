// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func parseHexMantissaAsm(s string, offset int, maxDigits int) (mantissa uint64, hexIntDigits int, hexFracDigits int, digitsParsed int, ok bool)
// Optimized hex digit parsing for ARM64
TEXT ·parseHexMantissaAsm(SB), NOSPLIT, $0-65
	MOVD s_ptr+0(FP), R0        // R0 = string pointer
	MOVD s_len+8(FP), R1        // R1 = string length
	MOVD offset+16(FP), R2      // R2 = offset
	MOVD maxDigits+24(FP), R3   // R3 = maxDigits
	
	// Check bounds
	CMP R1, R2
	BGE parse_error_hex
	CMP $0, R3
	BLE parse_error_hex
	
	// Initialize
	MOVD $0, R4                 // R4 = mantissa
	MOVD $0, R5                 // R5 = hexIntDigits
	MOVD $0, R6                 // R6 = hexFracDigits
	MOVD $0, R7                 // R7 = digitsParsed
	MOVD $0, R8                 // R8 = saw dot (0 or 1)
	
	// Calculate pointer and remaining length
	ADD R2, R0, R0              // R0 = ptr + offset
	SUB R2, R1, R1              // R1 = remaining length
	
hex_loop:
	// Check if we've reached the end or max digits
	CBZ R1, parse_done_hex
	CMP R3, R7
	BGE parse_done_hex
	
	// Load next character
	MOVBU (R0), R9
	
	// Check for decimal point
	CMP $'.', R9
	BEQ found_dot_hex
	
	// Convert hex character to value
	// If '0'-'9': digit = ch - '0'
	SUB $'0', R9, R10
	CMP $9, R10
	BLS is_digit_hex            // '0'-'9'
	
	// If 'a'-'f': digit = ch - 'a' + 10
	SUB $'a', R9, R10
	CMP $5, R10
	BHI try_upper_hex
	ADD $10, R10, R10
	B accumulate_hex
	
try_upper_hex:
	// If 'A'-'F': digit = ch - 'A' + 10
	SUB $'A', R9, R10
	CMP $5, R10
	BHI parse_done_hex          // Not a hex digit
	ADD $10, R10, R10
	B accumulate_hex
	
is_digit_hex:
	// R10 already has digit value
	
accumulate_hex:
	// mantissa = mantissa * 16 + digit
	LSL $4, R4, R4
	ADD R10, R4, R4
	
	// Increment digit counters
	ADD $1, R7, R7              // digitsParsed++
	
	// If we've seen a dot, increment hexFracDigits, else hexIntDigits
	CBNZ R8, inc_frac_hex
	ADD $1, R5, R5              // hexIntDigits++
	B next_hex
	
inc_frac_hex:
	ADD $1, R6, R6              // hexFracDigits++
	
next_hex:
	// Advance
	ADD $1, R0, R0
	SUB $1, R1, R1
	B hex_loop
	
found_dot_hex:
	// Check if we already found a dot
	CBNZ R8, parse_done_hex     // Two dots = done
	
	// Mark that we found a dot
	MOVD $1, R8
	
	// Advance past the dot (but don't count it as a digit)
	ADD $1, R0, R0
	SUB $1, R1, R1
	B hex_loop
	
parse_done_hex:
	// Check if we parsed any digits
	CBZ R7, parse_error_hex
	
	// Success
	MOVD R4, mantissa+32(FP)
	MOVD R5, hexIntDigits+40(FP)
	MOVD R6, hexFracDigits+48(FP)
	MOVD R7, digitsParsed+56(FP)
	MOVD $1, R10
	MOVB R10, ok+64(FP)
	RET
	
parse_error_hex:
	MOVD $0, R10
	MOVD R10, mantissa+32(FP)
	MOVD R10, hexIntDigits+40(FP)
	MOVD R10, hexFracDigits+48(FP)
	MOVD R10, digitsParsed+56(FP)
	MOVB R10, ok+64(FP)
	RET

