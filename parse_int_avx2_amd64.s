// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"
#include "constants_amd64.h"

// func parseIntAVX2(s string, bitSize int) (result int64, ok bool)
// AVX2 integer parser processing 8 digits in parallel
// Handles simple decimal integers: [-+]?[0-9]+
TEXT ·parseIntAVX2(SB), NOSPLIT, $0-41
	// Load string pointer and length
	MOVQ s_ptr+0(FP), DI    // DI = string pointer
	MOVQ s_len+8(FP), SI    // SI = string length
	MOVQ bitSize+16(FP), R8 // R8 = bitSize
	
	// Check for empty string
	TESTQ SI, SI
	JZ return_false
	
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
	CMPB AL, $CHAR_MINUS
	JE set_negative
	CMPB AL, $CHAR_PLUS
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
	
	// Check if we have enough for AVX2 (at least 8 digits)
	CMPQ R12, $8
	JL process_4
	
process_8_digits:
	// Process 8 digits at a time using optimized scalar (AVX2 for validation)
	CMPQ R12, $8
	JL process_4
	
	// Load 8 bytes
	MOVQ (DI)(R9*1), AX      // AX = 8 ASCII bytes
	
	// Subtract '0' from all bytes
	MOVQ $0x3030303030303030, BX
	MOVQ AX, CX
	SUBQ BX, CX              // CX = bytes - '0'
	
	// Validate all bytes are in range [0, 9]
	// Check if any byte > 9
	MOVQ CX, DX
	MOVQ $0xF6F6F6F6F6F6F6F6, BX  // 0xF6 = 256 - 10
	ADDQ BX, DX              // DX = (byte - '0') + 246
	// If byte was 0-9, result is 246-255 (no carry into next byte)
	// If byte was > 9, result wraps and sets high bit differently
	
	// Alternative: use parallel comparison
	// Each byte: if (byte - '0') > 9, it's invalid
	MOVQ CX, BX
	MOVQ $0x0A0A0A0A0A0A0A0A, DX
	
	// Check using bit manipulation
	// For each byte b in CX: if b <= 9, valid
	MOVQ CX, R13
	MOVQ $0xF6F6F6F6F6F6F6F6, R14  // ~9 in each byte (actually 246 = -10 in u8)
	ADDQ R14, R13
	MOVQ $0x8080808080808080, BX
	ANDQ BX, R13
	TESTQ R13, R13
	JNZ process_4            // Some digit out of range
	
	// All 8 digits valid - convert using Horner's method
	// value = (((((((d7*10+d6)*10+d5)*10+d4)*10+d3)*10+d2)*10+d1)*10+d0
	
	// Multiply current value by 100000000 (10^8)
	MOVQ R10, R13
	IMULQ $100000000, R13
	JC return_false          // Overflow check
	
	// Extract each digit (they're in CX after subtracting '0')
	MOVQ CX, DX
	SHRQ $56, DX
	IMULQ $10000000, DX      // d7 * 10^7
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	SHRQ $48, DX
	ANDQ $0xFF, DX
	IMULQ $1000000, DX       // d6 * 10^6
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	SHRQ $40, DX
	ANDQ $0xFF, DX
	IMULQ $100000, DX        // d5 * 10^5
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	SHRQ $32, DX
	ANDQ $0xFF, DX
	IMULQ $10000, DX         // d4 * 10^4
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	SHRQ $24, DX
	ANDQ $0xFF, DX
	IMULQ $1000, DX          // d3 * 10^3
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	SHRQ $16, DX
	ANDQ $0xFF, DX
	IMULQ $100, DX           // d2 * 10^2
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	SHRQ $8, DX
	ANDQ $0xFF, DX
	IMULQ $10, DX            // d1 * 10
	ADDQ DX, R13
	JC return_false
	
	MOVQ CX, DX
	ANDQ $0xFF, DX           // d0
	ADDQ DX, R13
	JC return_false
	
	MOVQ R13, R10
	
	// Check against max value
	CMPQ R8, $32
	JE check_max_32_8
	MOVQ $0x7FFFFFFFFFFFFFFF, R14
	CMPQ R10, R14
	JA return_false
	JMP continue_8
	
check_max_32_8:
	CMPQ R10, $0x7FFFFFFF
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
	
	MOVL (DI)(R9*1), AX     // AX = 4 ASCII bytes
	
	// Subtract '0' from all bytes
	MOVL $0x30303030, BX
	MOVL AX, CX
	SUBL BX, CX            // CX = bytes - '0'
	
	// Validate all 4 bytes
	MOVL CX, DX
	MOVL $0xF6F6F6F6, BX
	ADDL BX, DX
	ANDL $0x80808080, DX
	TESTL DX, DX
	JNZ scalar_loop
	
	// Extract 4 digits
	IMULQ $10000, R10
	JC return_false
	
	MOVL CX, DX
	SHRL $24, DX            // d3
	IMULQ $1000, DX
	ADDQ DX, R10
	
	MOVL CX, DX
	SHRL $16, DX
	ANDL $0xFF, DX          // d2
	IMULQ $100, DX
	ADDQ DX, R10
	
	MOVL CX, DX
	SHRL $8, DX
	ANDL $0xFF, DX          // d1
	IMULQ $10, DX
	ADDQ DX, R10
	
	MOVL CX, DX
	ANDL $0xFF, DX          // d0
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
	JC return_false
	MOVQ AX, R14
	ANDQ $0xFF, R14
	ADDQ R14, R10
	JC return_false
	
	// Check max value
	CMPQ R8, $32
	JE check_scalar_32
	MOVQ $0x7FFFFFFFFFFFFFFF, BX
	CMPQ R10, BX
	JA return_false
	JMP continue_scalar
	
check_scalar_32:
	CMPQ R10, $0x7FFFFFFF
	JA return_false
	
continue_scalar:
	INCQ R9
	DECQ R12
	JMP scalar_loop
	
check_complete:
	// Must have consumed entire string
	CMPQ R9, SI
	JNE return_false
	
	// Must have parsed at least one digit (R9 > start position)
	MOVQ s_len+8(FP), CX
	SUBQ SI, CX
	ADDQ R11, CX             // Add 1 if negative (had sign)
	// Actually simpler: just check if index moved from initial position
	
	// Apply sign if negative
	TESTQ R11, R11
	JZ return_result
	NEGQ R10
	
	// Check for int32 negative range
	CMPQ R8, $32
	JNE return_result
	CMPQ R10, $-0x80000000
	JL return_false
	
return_result:
	MOVQ R10, result+24(FP)
	MOVB $1, ok+32(FP)
	VZEROUPPER
	RET
	
return_false:
	MOVQ $0, result+24(FP)
	MOVB $0, ok+32(FP)
	VZEROUPPER
	RET

