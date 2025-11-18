// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseUintFastAsm(s string, base int, bitSize int) (result uint64, ok bool)
// Fast path parser for simple unsigned integers in base 10 or base 16
// Returns (0, false) if pattern doesn't match or requires fallback
TEXT ·parseUintFastAsm(SB), NOSPLIT, $0-49
	// Load arguments
	MOVQ s_ptr+0(FP), DI     // DI = string pointer
	MOVQ s_len+8(FP), SI     // SI = string length
	MOVQ base+16(FP), R8     // R8 = base
	MOVQ bitSize+24(FP), R9  // R9 = bitSize
	
	// Check for empty string
	TESTQ SI, SI
	JZ return_false
	
	// Only handle base 10 and base 16 in assembly
	CMPQ R8, $10
	JE base10_handler
	CMPQ R8, $16
	JE base16_handler
	JMP return_false
	
base10_handler:
	// Initialize for base 10
	MOVQ $10, R8  // R8 = base (10)
	JMP setup_max_value
	
base16_handler:
	// Initialize for base 16
	MOVQ $16, R8  // R8 = base (16)
	
setup_max_value:
	// Determine max value based on bitSize
	MOVQ $0xFFFFFFFFFFFFFFFF, R13  // Max uint64 (default)
	
	CMPQ R9, $0
	JE max_set  // bitSize 0 means uint (64-bit)
	
	CMPQ R9, $8
	JNE check_16
	MOVQ $0xFF, R13  // Max uint8
	JMP max_set
	
check_16:
	CMPQ R9, $16
	JNE check_32
	MOVQ $0xFFFF, R13  // Max uint16
	JMP max_set
	
check_32:
	CMPQ R9, $32
	JNE check_64
	MOVQ $0xFFFFFFFF, R13  // Max uint32
	JMP max_set
	
check_64:
	CMPQ R9, $64
	JNE return_false  // Invalid bitSize
	// R13 already has max uint64
	
max_set:
	// Initialize parsing
	XORQ R10, R10   // R10 = index
	XORQ R11, R11   // R11 = value
	XORQ R12, R12   // R12 = digit count
	
	// Check for signs - assembly fast path doesn't handle signs
	// (signs are only allowed for base 0, which uses generic path)
	MOVBLZX (DI), AX
	CMPB AL, $CHAR_PLUS
	JE return_false
	CMPB AL, $CHAR_MINUS
	JE return_false
	
check_hex_prefix:
	// For base 16, allow optional 0x prefix
	CMPQ R8, $16
	JNE parse_digits
	
	// Check for 0x or 0X prefix
	CMPQ R10, SI
	JGE parse_digits
	MOVBLZX (DI)(R10*1), AX
	CMPB AX, $CHAR_ZERO
	JNE parse_digits
	
	// Have '0', check for 'x' or 'X'
	MOVQ R10, R14
	INCQ R14
	CMPQ R14, SI
	JGE parse_digits
	MOVBLZX (DI)(R14*1), BX
	CMPB BX, $'x'
	JE skip_hex_prefix
	CMPB BX, $'X'
	JNE parse_digits
	
skip_hex_prefix:
	ADDQ $2, R10  // Skip "0x"
	
parse_digits:
	// Check we have digits
	CMPQ R10, SI
	JGE check_complete
	
	// Try AVX2 batch validation for base-10 long integers (>=16 remaining bytes)
	CMPQ R8, $10
	JNE digit_loop
	MOVQ SI, BX
	SUBQ R10, BX
	CMPQ BX, $16
	JGE try_avx2_uint_digits
	
digit_loop:
	// Load character
	MOVBLZX (DI)(R10*1), CX
	
	// Convert to digit based on base
	CMPQ R8, $10
	JE parse_decimal_digit
	JMP parse_hex_digit
	
parse_decimal_digit:
	// Check if '0'-'9'
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA return_false  // Not a digit, can't handle it - fall back
	JMP digit_valid
	
parse_hex_digit:
	// Check if '0'-'9'
	MOVQ CX, AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JBE digit_valid
	
	// Check if 'a'-'f'
	MOVQ CX, AX
	SUBB $'a', AX
	CMPB AX, $5
	JBE hex_lower
	
	// Check if 'A'-'F'
	MOVQ CX, AX
	SUBB $'A', AX
	CMPB AX, $5
	JA return_false  // Not a hex digit, can't handle it - fall back
	
	// 'A'-'F': digit = ch - 'A' + 10
	ADDB $10, AX
	JMP digit_valid
	
hex_lower:
	// 'a'-'f': digit = ch - 'a' + 10
	ADDB $10, AX
	
digit_valid:
	// AX now contains the digit value
	INCQ R12  // digit count++
	
	// Save digit
	MOVQ AX, R14
	
	// Check for overflow before multiply
	// if value > maxValue/base, overflow
	MOVQ R13, AX
	XORQ DX, DX
	DIVQ R8         // AX = R13/base (maxValue/base)
	CMPQ R11, AX
	JA return_false // overflow
	
	// Multiply: value = value * base
	MOVQ R11, AX
	MULQ R8
	JC return_false  // overflow on multiply
	MOVQ AX, R11
	
	// Check if we can add digit
	MOVQ R13, AX
	SUBQ R11, AX    // AX = maxValue - value
	CMPQ R14, AX
	JA return_false // overflow on add
	
	// Add digit
	ADDQ R14, R11
	
	// Next character
	INCQ R10
	CMPQ R10, SI
	JL digit_loop
	
try_avx2_uint_digits:
	// AVX2 digit validation for base-10: check 16 bytes at once
	// Load '0' (0x30) into all bytes of XMM1
	MOVQ $0x3030303030303030, AX
	MOVQ AX, X1
	PUNPCKLQDQ X1, X1        // X1 = all 0x30
	
	// Load '9' (0x39) into all bytes of XMM2  
	MOVQ $0x3939393939393939, AX
	MOVQ AX, X2
	PUNPCKLQDQ X2, X2        // X2 = all 0x39
	
	// Check if we have at least 16 bytes left
	MOVQ SI, BX
	SUBQ R10, BX
	CMPQ BX, $16
	JL digit_loop
	
	// Load 16 bytes
	MOVOU (DI)(R10*1), X0
	
	// Check if all bytes >= '0'
	MOVOA X0, X3
	PCMPGTB X1, X3           // X3 = (X0 < '0')
	PMOVMSKB X3, AX
	TESTL AX, AX
	JNZ digit_loop           // Some byte < '0', use scalar
	
	// Check if all bytes <= '9'
	MOVOA X0, X3
	MOVOA X2, X4
	PCMPGTB X3, X4           // X4 = (X0 > '9')
	PMOVMSKB X4, AX
	TESTL AX, AX
	JNZ digit_loop           // Some byte > '9', use scalar
	
	// All 16 bytes are base-10 digits!
	// Fall through to scalar loop to accumulate them
	JMP digit_loop

check_complete:
	// Must have at least one digit
	TESTQ R12, R12
	JZ return_false
	
	// Success!
	MOVQ R11, result+32(FP)
	MOVB $1, ok+40(FP)
	RET
	
return_false:
	MOVQ $0, result+32(FP)
	MOVB $0, ok+40(FP)
	RET

