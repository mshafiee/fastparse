// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseIntNEON(s string, bitSize int) (result int64, ok bool)
// Optimized integer parser for ARM64
// Uses efficient scalar operations with MADD instruction
TEXT ·parseIntNEON(SB), NOSPLIT, $0-33
	// Load arguments
	MOVD s_base+0(FP), R0    // R0 = string pointer
	MOVD s_len+8(FP), R1     // R1 = string length
	MOVD bitSize+16(FP), R2 // R2 = bitSize
	
	// Check for empty string
	CBZ R1, return_false
	
	// Validate bitSize (must be 32 or 64)
	CMP $32, R2
	BEQ bitsize_ok
	CMP $64, R2
	BNE return_false
	
bitsize_ok:
	// Initialize registers
	MOVD $0, R3              // R3 = index
	MOVD $0, R4              // R4 = value (accumulator)
	MOVD $0, R5              // R5 = negative flag
	
	// Parse optional sign
	MOVBU (R0), R8
	CMP CHAR_MINUS, R8
	BEQ set_negative
	CMP CHAR_PLUS, R8
	BEQ skip_sign
	B start_parse
	
set_negative:
	MOVD $1, R5
	ADD $1, R3
	B check_after_sign
	
skip_sign:
	ADD $1, R3
	
check_after_sign:
	CMP R1, R3
	BGE return_false
	
start_parse:
	// Calculate remaining length
	SUB R3, R1, R6           // R6 = remaining length
	
process_8_digits:
	// Process 8 digits at a time using optimized scalar
	CMP $8, R6
	BLT process_4
	
	// Load 8 bytes
	MOVD (R0)(R3), R10
	
	// Subtract '0' from all bytes
	MOVD $0x3030303030303030, R11
	SUB R11, R10             // R10 = bytes - '0'
	
	// Validate all 8 bytes are <= 9 using parallel byte test
	MOVD R10, R12
	MOVD $0xF6F6F6F6F6F6F6F6, R13  // 0xF6 = -10 in uint8
	ADD R13, R12
	MOVD $0x8080808080808080, R13
	AND R13, R12
	CBNZ R12, process_4      // Some byte out of range
	
	// All 8 digits are valid
	
	// Multiply current value by 100000000 (10^8)
	MOVD $100000000, R11
	MUL R11, R4
	// Note: overflow checking will be done after accumulation
	
	// Extract each digit and build the 8-digit number
	// Use optimized multiply-add sequence
	// digit7 * 10000000 + digit6 * 1000000 + ... + digit0
	
	// Extract digit 7 (MSB)
	LSR $56, R10, R12
	AND $0xFF, R12
	MOVD $10000000, R13
	MADD R13, R12, R4, R4    // R4 = R4 + R12 * R13
	
	// Extract digit 6
	LSR $48, R10, R12
	AND $0xFF, R12
	MOVD $1000000, R13
	MADD R13, R12, R4, R4
	
	// Extract digit 5
	LSR $40, R10, R12
	AND $0xFF, R12
	MOVD $100000, R13
	MADD R13, R12, R4, R4
	
	// Extract digit 4
	LSR $32, R10, R12
	AND $0xFF, R12
	MOVD $10000, R13
	MADD R13, R12, R4, R4
	
	// Extract digit 3
	LSR $24, R10, R12
	AND $0xFF, R12
	MOVD $1000, R13
	MADD R13, R12, R4, R4
	
	// Extract digit 2
	LSR $16, R10, R12
	AND $0xFF, R12
	MOVD $100, R13
	MADD R13, R12, R4, R4
	
	// Extract digit 1
	LSR $8, R10, R12
	AND $0xFF, R12
	MOVD $10, R13
	MADD R13, R12, R4, R4
	
	// Extract digit 0 (LSB)
	AND $0xFF, R10, R12
	ADD R12, R4
	
	// Check for overflow against max value
	CMP $32, R2
	BEQ check_max_32_8
	MOVD $0x7FFFFFFFFFFFFFFF, R12
	CMP R12, R4
	BHI return_false
	B continue_8
	
check_max_32_8:
	MOVD $0x7FFFFFFF, R12
	CMP R12, R4
	BHI return_false
	
continue_8:
	ADD $8, R3
	SUB $8, R6
	CMP $8, R6
	BGE process_8_digits
	
process_4:
	// Process 4 digits at a time
	CMP $4, R6
	BLT scalar_loop
	
	// Load 4 bytes
	MOVWU (R0)(R3), R10      // R10 = 4 ASCII bytes
	
	// Subtract '0' from each byte
	MOVD $0x30303030, R11
	SUB R11, R10             // R10 = bytes - '0'
	
	// Validate all 4 bytes are <= 9
	// Check using parallel byte comparison
	MOVD R10, R12
	MOVD $0xF6F6F6F6, R11    // 0xF6 = 246 = -10 in uint8
	ADD R11, R12
	MOVD $0x80808080, R11
	AND R11, R12
	CBNZ R12, scalar_loop    // Some byte out of range
	
	// Extract 4 digits
	MOVD $10000, R11
	MUL R11, R4
	
	// digit3 * 1000 + digit2 * 100 + digit1 * 10 + digit0
	LSR $24, R10, R12
	MOVD $1000, R13
	MADD R13, R12, R4, R4
	
	LSR $16, R10, R12
	AND $0xFF, R12
	MOVD $100, R13
	MADD R13, R12, R4, R4
	
	LSR $8, R10, R12
	AND $0xFF, R12
	MOVD $10, R13
	MADD R13, R12, R4, R4
	
	AND $0xFF, R10, R12
	ADD R12, R4
	
	ADD $4, R3
	SUB $4, R6
	
scalar_loop:
	// Process remaining digits one at a time
	CBZ R6, check_complete
	
	MOVBU (R0)(R3), R8
	SUB CHAR_0, R8, R9
	CMP $9, R9
	BHI check_complete
	
	// Multiply value by 10 and add digit
	MOVD $10, R10
	MOVD R4, R11
	MUL R10, R11, R4
	ADD R9, R4
	
	// Check overflow against max value
	CMP $32, R2
	BEQ check_scalar_32
	MOVD $0x7FFFFFFFFFFFFFFF, R12
	CMP R12, R4
	BHI return_false
	B continue_scalar
	
check_scalar_32:
	MOVD $0x7FFFFFFF, R12
	CMP R12, R4
	BHI return_false
	
continue_scalar:
	ADD $1, R3
	SUB $1, R6
	B scalar_loop
	
check_complete:
	// Must have consumed entire string
	CMP R1, R3
	BNE return_false
	
	// Apply sign if negative
	CBZ R5, return_result
	NEG R4, R4
	
	// Check int32 negative range
	CMP $32, R2
	BNE return_result
	MOVD $0xFFFFFFFF80000000, R12  // -2147483648
	CMP R12, R4
	BLT return_false
	
return_result:
	MOVD R4, result+24(FP)
	MOVD $1, R8
	MOVB R8, ok+32(FP)
	RET
	
return_false:
	MOVD $0, result+24(FP)
	MOVD $0, R8
	MOVB R8, ok+32(FP)
	RET

