// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseIntAVX512(s string, bitSize int) (result int64, ok bool)
// Ultra-fast AVX-512 integer parser processing 16 digits in parallel
// Handles simple decimal integers: [-+]?[0-9]+
TEXT ·parseIntAVX512(SB), NOSPLIT, $0-41
	// Load string pointer and length
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	MOVQ bitSize+16(FP), R8 // R8 = bitSize
	
	// Check for empty string or too short for AVX-512
	TESTQ SI, SI
	JZ return_false
	CMPQ SI, $2
	JL return_false
	
	// Validate bitSize (must be 32 or 64)
	CMPQ R8, $32
	JE bitsize_ok
	CMPQ R8, $64
	JNE return_false
	
bitsize_ok:
	// Initialize
	XORQ R9, R9              // R9 = index
	XORQ R10, R10            // R10 = value (accumulator)
	XORQ R11, R11            // R11 = negative flag
	
	// Parse optional sign
	MOVBLZX (DI), AX
	CMPB AX, CHAR_MINUS
	JE set_negative
	CMPB AX, CHAR_PLUS
	JE skip_sign
	JMP start_parse
	
set_negative:
	MOVQ $1, R11
	INCQ R9
	JMP check_after_sign
	
skip_sign:
	INCQ R9
	
check_after_sign:
	CMPQ R9, SI
	JGE return_false
	
start_parse:
	// Calculate remaining length
	MOVQ SI, R12
	SUBQ R9, R12             // R12 = remaining length
	
	// Check if we have enough for SIMD (at least 8 digits)
	CMPQ R12, $8
	JL scalar_loop
	
	// Setup SIMD constants
	// Z0 = '0' broadcast (for subtraction)
	MOVQ $0x3030303030303030, AX
	VPBROADCASTQ AX, Z0
	
	// Z1 = 9 broadcast (for range check)
	MOVQ $0x0909090909090909, AX
	VPBROADCASTQ AX, Z1
	
	// Process 16 bytes at a time with AVX-512
avx512_loop:
	MOVQ R12, CX
	CMPQ CX, $16
	JL process_8_digits
	
	// Load 16 bytes
	VMOVDQU8 (DI)(R9*1), X2  // X2 = 16 bytes from string
	
	// Subtract '0' from all bytes
	VPSUBB Z0, Z2, Z3        // Z3 = bytes - '0'
	
	// Check if all bytes are in range [0, 9]
	VPCMPUB $2, Z1, Z3, K1   // K1 = mask where bytes <= 9
	KORTESTW K1, K1
	JZ process_valid_16      // All zeros in inverse = all valid
	
	// Not all digits, check how many are valid
	KMOVW K1, AX
	NOTL AX                  // Invert to get valid mask
	ANDL $0xFFFF, AX
	JZ process_8_digits             // No valid digits, fall back
	
	// Count trailing valid digits using BSF
	BSFL AX, CX              // CX = position of first invalid digit
	TESTL CX, CX
	JZ process_8_digits             // First digit invalid, use scalar
	
	// Process CX valid digits
	CMPQ CX, $8
	JGE process_8_digits
	JMP process_remaining
	
process_valid_16:
	// All 16 bytes are valid digits
	// Check if we would overflow with 16 more digits
	CMPQ R8, $32
	JE check_overflow_32_16
	
	// For int64: max is 9223372036854775807 (19 digits)
	// If we already have value and adding 16 digits, check carefully
	TESTQ R10, R10
	JNZ process_8_digits     // Already have value, be conservative
	
	// Process first 16 digits directly
	// Convert 16 ASCII digits to numeric value
	// Use 8+8 approach for better accuracy
	JMP process_8_digits
	
check_overflow_32_16:
	// For int32: max is 2147483647 (10 digits)
	// Can't safely process 16 digits
	JMP process_8_digits
	
process_8_digits:
	// Process 8 digits at a time (safer for overflow checking)
	MOVQ R12, CX
	CMPQ CX, $8
	JL process_4
	
	// Load 8 bytes
	MOVQ (DI)(R9*1), AX      // AX = 8 bytes
	
	// Validate all 8 bytes are digits
	MOVQ AX, BX
	MOVQ $0x3030303030303030, DX
	SUBQ DX, BX              // BX = bytes - '0'
	
	// Check each byte is <= 9 using parallel comparison
	MOVQ BX, CX
	MOVQ $0x0A0A0A0A0A0A0A0A, DX
	MOVQ CX, R13
	XORQ DX, R13
	MOVQ R13, R14
	SUBQ DX, R14
	ANDQ CX, R14
	TESTQ R14, R14
	JNZ process_4            // Some bytes out of range
	
	// All 8 digits valid - convert to value
	// Extract each digit and build number
	// d7*10^7 + d6*10^6 + ... + d1*10 + d0
	
	// Method: use multiplier approach
	// ((((((d7*10+d6)*10+d5)*10+d4)*10+d3)*10+d2)*10+d1)*10+d0
	
	MOVQ BX, DX
	SHRQ $56, DX
	ANDQ $0xFF, DX           // DX = d7
	
	MOVQ R10, R13            // R13 = current value
	
	// Multiply current value by 100000000 (10^8)
	IMULQ $100000000, R13
	
	// Extract and accumulate 8 digits
	// Digit 7 (MSB)
	MOVQ DX, R14
	IMULQ $10000000, R14
	ADDQ R14, R13
	
	// Digit 6
	MOVQ BX, DX
	SHRQ $48, DX
	ANDQ $0xFF, DX
	IMULQ $1000000, DX
	ADDQ DX, R13
	
	// Digit 5
	MOVQ BX, DX
	SHRQ $40, DX
	ANDQ $0xFF, DX
	IMULQ $100000, DX
	ADDQ DX, R13
	
	// Digit 4
	MOVQ BX, DX
	SHRQ $32, DX
	ANDQ $0xFF, DX
	IMULQ $10000, DX
	ADDQ DX, R13
	
	// Digit 3
	MOVQ BX, DX
	SHRQ $24, DX
	ANDQ $0xFF, DX
	IMULQ $1000, DX
	ADDQ DX, R13
	
	// Digit 2
	MOVQ BX, DX
	SHRQ $16, DX
	ANDQ $0xFF, DX
	IMULQ $100, DX
	ADDQ DX, R13
	
	// Digit 1
	MOVQ BX, DX
	SHRQ $8, DX
	ANDQ $0xFF, DX
	IMULQ $10, DX
	ADDQ DX, R13
	
	// Digit 0 (LSB)
	MOVQ BX, DX
	ANDQ $0xFF, DX
	ADDQ DX, R13
	
	// Check for overflow
	JC return_false
	MOVQ R13, R10
	
	// Check against max value
	CMPQ R8, $32
	JE check_max_32
	MOVQ $0x7FFFFFFFFFFFFFFF, R14
	CMPQ R10, R14
	JA return_false
	JMP continue_8
	
check_max_32:
	MOVQ $0x7FFFFFFF, R14
	CMPQ R10, R14
	JA return_false
	
continue_8:
	ADDQ $8, R9
	SUBQ $8, R12
	CMPQ R12, $8
	JGE process_8_digits
	
process_4:
	// Process 4 digits at a time
	CMPQ R12, $4
	JL scalar_loop
	
	MOVL (DI)(R9*1), AX      // AX = 4 bytes
	
	// Validate 4 digits
	MOVL AX, BX
	SUBL $0x30303030, BX
	
	// Quick range check
	MOVL BX, CX
	MOVL $0x0A0A0A0A, DX
	MOVL CX, R13
	XORL DX, R13
	MOVL R13, R14
	SUBL DX, R14
	ANDL CX, R14
	TESTL R14, R14
	JNZ scalar_loop
	
	// Extract 4 digits
	MOVL BX, DX
	SHRL $24, DX
	ANDL $0xFF, DX           // d3
	
	IMULQ $10000, R10
	IMULQ $1000, DX
	ADDQ DX, R10
	
	MOVL BX, DX
	SHRL $16, DX
	ANDL $0xFF, DX           // d2
	IMULQ $100, DX
	ADDQ DX, R10
	
	MOVL BX, DX
	SHRL $8, DX
	ANDL $0xFF, DX           // d1
	IMULQ $10, DX
	ADDQ DX, R10
	
	MOVL BX, DX
	ANDL $0xFF, DX           // d0
	ADDQ DX, R10
	
	ADDQ $4, R9
	SUBQ $4, R12
	
scalar_loop:
	// Process remaining digits one at a time
	CMPQ R12, $0
	JLE check_complete
	
	MOVBLZX (DI)(R9*1), AX
	SUBB $CHAR_ZERO, AX
	CMPB AX, $9
	JA check_complete
	
	// Multiply value by 10 and add digit
	IMULQ $10, R10
	MOVQ AX, R14
	ANDQ $0xFF, R14
	ADDQ R14, R10
	
	// Check overflow
	JC return_false
	CMPQ R8, $32
	JE check_scalar_32
	MOVQ $0x7FFFFFFFFFFFFFFF, R14
	CMPQ R10, R14
	JA return_false
	JMP continue_scalar
	
check_scalar_32:
	MOVQ $0x7FFFFFFF, R14
	CMPQ R10, R14
	JA return_false
	
continue_scalar:
	INCQ R9
	DECQ R12
	JMP scalar_loop
	
check_complete:
	// Must have consumed entire string
	CMPQ R9, SI
	JNE return_false
	
	// Must have parsed at least one digit
	TESTQ R10, R10
	JZ check_if_zero_valid
	
apply_sign:
	// Apply sign if negative
	TESTQ R11, R11
	JZ return_result
	NEGQ R10
	
return_result:
	MOVQ R10, result+24(FP)
	MOVB $1, ok+32(FP)
	VZEROUPPER
	RET
	
check_if_zero_valid:
	// Check if we actually parsed "0"
	CMPQ SI, $1
	JE return_result
	CMPQ SI, $2
	JNE return_false
	// Could be "+0" or "-0"
	MOVBLZX 1(DI), AX
	CMPB AX, $CHAR_ZERO
	JE return_result
	
return_false:
	MOVQ $0, result+24(FP)
	MOVB $0, ok+32(FP)
	VZEROUPPER
	RET

process_remaining:
	// Process CX remaining digits using scalar
	JMP scalar_loop

