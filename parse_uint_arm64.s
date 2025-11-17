// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"
#include "constants_arm64.h"

// func parseUintFastAsm(s string, base int, bitSize int) (result uint64, ok bool)
// Fast path parser for simple unsigned integers in base 10 or base 16
// Returns (0, false) if pattern doesn't match or requires fallback
TEXT ·parseUintFastAsm(SB), NOSPLIT, $0-41
	// Load arguments
	MOVD s_base+0(FP), R0     // R0 = string pointer
	MOVD s_len+8(FP), R1      // R1 = string length
	MOVD base+16(FP), R2     // R2 = base
	MOVD bitSize+24(FP), R3  // R3 = bitSize
	
	// Check for empty string
	CBZ R1, return_false
	
	// Only handle base 10 and base 16 in assembly
	CMP $10, R2
	BEQ base10_handler
	CMP $16, R2
	BEQ base16_handler
	B return_false
	
base10_handler:
	// Initialize for base 10
	MOVD $10, R2  // R2 = base (10)
	B setup_max_value
	
base16_handler:
	// Initialize for base 16
	MOVD $16, R2  // R2 = base (16)
	
setup_max_value:
	// Determine max value based on bitSize
	MOVD $0xFFFFFFFFFFFFFFFF, R7  // Max uint64 (default)
	
	CBZ R3, max_set  // bitSize 0 means uint (64-bit)
	
	CMP $8, R3
	BNE check_16
	MOVD $0xFF, R7  // Max uint8
	B max_set
	
check_16:
	CMP $16, R3
	BNE check_32
	MOVD $0xFFFF, R7  // Max uint16
	B max_set
	
check_32:
	CMP $32, R3
	BNE check_64
	MOVD $0xFFFFFFFF, R7  // Max uint32
	B max_set
	
check_64:
	CMP $64, R3
	BNE return_false  // Invalid bitSize
	// R7 already has max uint64
	
max_set:
	// Initialize parsing
	MOVD $0, R4     // R4 = index
	MOVD $0, R5     // R5 = value
	MOVD $0, R6     // R6 = digit count
	
	// Check for signs - assembly fast path doesn't handle signs
	// (signs are only allowed for base 0, which uses generic path)
	MOVBU (R0), R8
	CMP CHAR_PLUS, R8
	BEQ return_false
	CMP CHAR_MINUS, R8
	BEQ return_false
	
check_hex_prefix:
	// For base 16, allow optional 0x prefix
	CMP $16, R2
	BNE parse_digits
	
	// Check for 0x or 0X prefix
	CMP R1, R4
	BGE parse_digits
	MOVBU (R0)(R4), R8
	CMP CHAR_0, R8
	BNE parse_digits
	
	// Have '0', check for 'x' or 'X'
	MOVD R4, R9
	ADD $1, R9
	CMP R1, R9
	BGE parse_digits
	MOVBU (R0)(R9), R10
	CMP $'x', R10
	BEQ skip_hex_prefix
	CMP $'X', R10
	BNE parse_digits
	
skip_hex_prefix:
	ADD $2, R4  // Skip "0x"
	
parse_digits:
	// Check we have digits
	CMP R1, R4
	BGE check_complete
	
digit_loop:
	// Load character
	MOVBU (R0)(R4), R8
	
	// Convert to digit based on base
	CMP $10, R2
	BEQ parse_decimal_digit
	B parse_hex_digit
	
parse_decimal_digit:
	// Check if '0'-'9'
	SUB CHAR_0, R8, R9
	CMP $9, R9
	BHI return_false  // Not a digit, can't handle it - fall back
	B digit_valid
	
parse_hex_digit:
	// Check if '0'-'9'
	SUB CHAR_0, R8, R9
	CMP $9, R9
	BLS digit_valid
	
	// Check if 'a'-'f'
	SUB $'a', R8, R9
	CMP $5, R9
	BLS hex_lower
	
	// Check if 'A'-'F'
	SUB $'A', R8, R9
	CMP $5, R9
	BHI return_false  // Not a hex digit, can't handle it - fall back
	
	// 'A'-'F': digit = ch - 'A' + 10
	ADD $10, R9
	B digit_valid
	
hex_lower:
	// 'a'-'f': digit = ch - 'a' + 10
	ADD $10, R9
	
digit_valid:
	// R9 now contains the digit value
	ADD $1, R6  // digit count++
	
	// Save digit
	MOVD R9, R10
	
	// Check for overflow before multiply
	// if value > maxValue/base, overflow
	MOVD R7, R11
	UDIV R2, R11         // R11 = maxValue/base
	CMP R11, R5
	BHI return_false     // overflow
	
	// Multiply: value = value * base
	MUL R2, R5
	
	// Check if we can add digit
	SUB R5, R7, R11      // R11 = maxValue - value
	CMP R11, R10
	BHI return_false     // overflow on add
	
	// Add digit
	ADD R10, R5
	
	// Next character
	ADD $1, R4
	CMP R1, R4
	BLT digit_loop
	
check_complete:
	// Must have at least one digit
	CBZ R6, return_false
	
	// Success!
	MOVD R5, result+32(FP)
	MOVD $1, R8
	MOVB R8, ok+40(FP)
	RET
	
return_false:
	MOVD $0, result+32(FP)
	MOVB $0, ok+40(FP)
	RET

