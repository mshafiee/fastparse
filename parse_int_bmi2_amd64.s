// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseIntBMI2(s string, bitSize int) (result int64, ok bool)
// BMI2-optimized integer parser using MULX for fast overflow checking
// MULX performs unsigned multiply without affecting flags - much faster than IMUL
TEXT ·parseIntBMI2(SB), NOSPLIT, $0-41
	// Load arguments
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	MOVQ bitSize+16(FP), R8 // R8 = bitSize
	
	// Check for empty string
	TESTQ SI, SI
	JZ return_false
	
	// Validate bitSize
	CMPQ R8, $32
	JE bitsize_ok
	CMPQ R8, $64
	JNE return_false
	
bitsize_ok:
	// Initialize
	XORQ R9, R9              // R9 = index
	XORQ R10, R10            // R10 = value (accumulator)
	XORQ R11, R11            // R11 = negative flag
	
	// Set max value
	MOVQ $0x7FFFFFFFFFFFFFFF, R13  // Max int64
	CMPQ R8, $32
	JNE parse_sign
	MOVQ $0x7FFFFFFF, R13          // Max int32
	
parse_sign:
	// Parse optional sign
	MOVBLZX (DI), AX
	CMPB AL, $CHAR_MINUS
	JE set_negative
	CMPB AL, $CHAR_PLUS
	JE skip_sign
	JMP digit_loop
	
set_negative:
	MOVQ $1, R11
	INCQ R9
	JMP check_after_sign
	
skip_sign:
	INCQ R9
	
check_after_sign:
	CMPQ R9, SI
	JGE return_false
	
digit_loop:
	// Check if we're done
	CMPQ R9, SI
	JGE check_valid
	
	// Load and validate digit
	MOVBLZX (DI)(R9*1), AX
	SUBB $CHAR_ZERO, AL
	CMPB AL, $9
	JA check_valid
	
	// BMI2 OPTIMIZATION: Use MULX for overflow-free multiplication
	// MULX performs RDX * src -> hi:lo without affecting flags
	// This is much faster than IMUL + overflow check
	
	// Check overflow before multiply: value > maxValue/10
	// Using BMI2: compute value * 10 and check if result > maxValue
	
	// Setup for MULX: RDX = multiplier (10)
	MOVQ $10, DX
	
	// MULX: compute R10 * 10 -> R15:R14 (hi:lo)
	// MULX operands: MULX src, lo_dest, hi_dest
	BYTE $0xC4; BYTE $0xE2; BYTE $0x8B; BYTE $0xF6; BYTE $0xD2  // MULX R10, R14, R15
	
	// Check for overflow: if hi != 0, overflow occurred
	TESTQ R15, R15
	JNZ check_max_negative
	
	// Add digit to result
	MOVQ AX, R12
	ANDQ $0xFF, R12          // R12 = digit value
	ADDQ R12, R14            // R14 = value * 10 + digit
	JC check_max_negative   // Carry = overflow
	
	// Check against max value
	CMPQ R14, R13
	JA check_max_negative
	
	// Update value
	MOVQ R14, R10
	
continue_digit:
	INCQ R9
	JMP digit_loop
	
check_max_negative:
	// Check for special case: minimum negative value
	// int64: -9223372036854775808, int32: -2147483648
	TESTQ R11, R11
	JZ return_false          // Positive overflow
	
	// Check if this is exactly maxValue + 1
	MOVQ R13, BX
	INCQ BX
	CMPQ R14, BX
	JNE return_false
	
	// This is min negative - make sure we're at end of string
	INCQ R9
	CMPQ R9, SI
	JNE return_false
	
	// Return minimum negative value
	NEGQ R14
	MOVQ R14, result+24(FP)
	MOVB $1, ok+32(FP)
	RET
	
check_valid:
	// Must have parsed at least one digit
	CMPQ R9, SI
	JNE return_false         // Didn't consume entire string
	
	// Must have moved beyond sign (if any)
	TESTQ R11, R11
	JNZ check_negative
	
	// Positive number - check we moved from start
	MOVBLZX (DI), AX
	CMPB AL, $CHAR_PLUS
	JE check_moved_1
	JMP check_moved_0
	
check_moved_1:
	CMPQ R9, $1
	JLE return_false
	JMP apply_sign
	
check_moved_0:
	TESTQ R9, R9
	JZ return_false
	JMP apply_sign
	
check_negative:
	// Negative number - check we moved past '-'
	CMPQ R9, $1
	JLE return_false
	
apply_sign:
	// Apply sign if negative
	TESTQ R11, R11
	JZ return_result
	NEGQ R10
	
	// Check int32 negative range
	CMPQ R8, $32
	JNE return_result
	CMPQ R10, $-0x80000000
	JL return_false
	
return_result:
	MOVQ R10, result+24(FP)
	MOVB $1, ok+32(FP)
	RET
	
return_false:
	MOVQ $0, result+24(FP)
	MOVB $0, ok+32(FP)
	RET

// func parseUintBMI2(s string, bitSize int) (result uint64, ok bool)
// BMI2-optimized unsigned integer parser
TEXT ·parseUintBMI2(SB), NOSPLIT, $0-41
	// Load arguments
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	MOVQ bitSize+16(FP), R8 // R8 = bitSize
	
	// Check for empty string
	TESTQ SI, SI
	JZ return_false_u
	
	// Validate bitSize
	CMPQ R8, $32
	JE bitsize_ok_u
	CMPQ R8, $64
	JNE return_false_u
	
bitsize_ok_u:
	// Initialize
	XORQ R9, R9              // R9 = index
	XORQ R10, R10            // R10 = value
	
	// Set max value
	MOVQ $0xFFFFFFFFFFFFFFFF, R13  // Max uint64
	CMPQ R8, $32
	JNE parse_digits_u
	MOVQ $0xFFFFFFFF, R13          // Max uint32
	
parse_digits_u:
	// Parse optional '+' sign (no '-' for unsigned)
	MOVBLZX (DI), AX
	CMPB AL, $CHAR_PLUS
	JNE digit_loop_u
	INCQ R9
	CMPQ R9, SI
	JGE return_false_u
	
digit_loop_u:
	CMPQ R9, SI
	JGE check_valid_u
	
	// Load and validate digit
	MOVBLZX (DI)(R9*1), AX
	SUBB $CHAR_ZERO, AL
	CMPB AL, $9
	JA check_valid_u
	
	// BMI2 MULX optimization
	MOVQ $10, DX
	
	// MULX: R10 * 10 -> R15:R14
	BYTE $0xC4; BYTE $0xE2; BYTE $0x8B; BYTE $0xF6; BYTE $0xD2  // MULX R10, R14, R15
	
	// Check overflow
	TESTQ R15, R15
	JNZ return_false_u
	
	// Add digit
	MOVQ AX, R12
	ANDQ $0xFF, R12
	ADDQ R12, R14
	JC return_false_u
	
	// Check max
	CMPQ R14, R13
	JA return_false_u
	
	MOVQ R14, R10
	INCQ R9
	JMP digit_loop_u
	
check_valid_u:
	// Must have consumed entire string
	CMPQ R9, SI
	JNE return_false_u
	
	// Must have moved from start
	TESTQ R9, R9
	JZ return_false_u
	
	MOVQ R10, result+24(FP)
	MOVB $1, ok+32(FP)
	RET
	
return_false_u:
	MOVQ $0, result+24(FP)
	MOVB $0, ok+32(FP)
	RET

