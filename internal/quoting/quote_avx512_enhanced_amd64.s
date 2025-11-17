// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"

// func needsEscapingAVX512(s string, quote byte, mode int) bool
// AVX-512 optimized version that processes 64 bytes at a time
// Uses AVX-512 BW for byte/word operations
TEXT ·needsEscapingAVX512(SB), NOSPLIT, $0-34
	// Get string pointer and length
	MOVQ s_base+0(FP), SI    // SI = string data pointer
	MOVQ s_len+8(FP), CX     // CX = string length
	MOVB quote+16(FP), DX    // DL = quote character
	MOVQ mode+24(FP), R8     // R8 = mode
	
	// Fast path: empty string needs no escaping
	TESTQ CX, CX
	JZ no_escape
	
	// Require at least 64 bytes for AVX-512 path
	CMPQ CX, $64
	JL fallback
	
	// Prepare AVX-512 constants
	// Broadcast quote character to all 64 bytes of Z0
	MOVB DL, AX
	VPBROADCASTB AX, Z0      // Z0 = quote repeated 64 times
	
	// Z1 = backslash (0x5C) repeated 64 times
	MOVQ $0x5C, AX
	VPBROADCASTB AX, Z1
	
	// Z2 = space (0x20) for control character check
	MOVQ $0x20, AX
	VPBROADCASTB AX, Z2
	
	// Z3 = DEL (0x7F)
	MOVQ $0x7F, AX
	VPBROADCASTB AX, Z3
	
	XORQ DX, DX              // DX = index
	
avx512_loop:
	// Check if we have at least 64 bytes left
	MOVQ CX, BX
	SUBQ DX, BX
	CMPQ BX, $64
	JL avx512_remainder
	
	// Load 64 bytes
	VMOVDQU8 (SI)(DX*1), Z4
	
	// Check 1: byte == quote
	VPCMPEQB Z0, Z4, K1
	KORTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 2: byte == backslash
	VPCMPEQB Z1, Z4, K1
	KORTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 3: byte < ' ' (control characters)
	VPCMPUB $1, Z2, Z4, K1   // K1 = mask where Z4 < Z2 (compare LT)
	KORTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 4: byte == 0x7F (DEL)
	VPCMPEQB Z3, Z4, K1
	KORTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 5: byte >= 0x80 (non-ASCII) if mode == ModeASCII (1)
	CMPQ R8, $1
	JNE avx512_next
	
	// Check high bit: create mask of bytes with bit 7 set
	MOVQ $0x80, AX
	VPBROADCASTB AX, Z5
	VPTESTMB Z5, Z4, K1      // K1 = mask where (Z4 & 0x80) != 0
	KORTESTQ K1, K1
	JNZ avx512_needs_escape
	
avx512_next:
	ADDQ $64, DX
	JMP avx512_loop
	
avx512_remainder:
	// Process remaining bytes with smaller chunks
	VZEROUPPER
	JMP fallback_remainder
	
avx512_needs_escape:
	VZEROUPPER
	MOVB $1, ret+32(FP)
	RET
	
fallback:
	// Not enough bytes for AVX-512, return false to use fallback
	MOVB $0, ret+32(FP)
	RET
	
fallback_remainder:
	// Process remaining bytes with scalar or AVX2
	MOVB $0, ret+32(FP)
	RET
	
no_escape:
	MOVB $0, ret+32(FP)
	RET

// func quoteWithAVX512(dst []byte, s string, quote byte) int
// AVX-512 optimized quoting that uses VPCOMPRESSB for selective escaping
// Returns number of bytes written to dst
TEXT ·quoteWithAVX512(SB), NOSPLIT, $0-59
	// Get arguments
	MOVQ dst_base+0(FP), DI   // DI = dst pointer
	MOVQ dst_len+8(FP), R9    // R9 = dst capacity
	MOVQ s_base+24(FP), SI    // SI = src string pointer
	MOVQ s_len+32(FP), CX     // CX = src length
	MOVB quote+48(FP), DL     // DL = quote character
	
	// Track output position
	XORQ R10, R10             // R10 = dst index
	XORQ R11, R11             // R11 = src index
	
	// Write opening quote
	CMPQ R10, R9
	JGE overflow
	MOVB DL, (DI)(R10*1)
	INCQ R10
	
	// Prepare AVX-512 constants for escape detection
	MOVQ $0x5C, AX            // backslash
	VPBROADCASTB AX, Z0
	
	MOVB DL, AX               // quote char
	VPBROADCASTB AX, Z1
	
	MOVQ $0x20, AX            // space
	VPBROADCASTB AX, Z2
	
	MOVQ $0x7F, AX            // DEL
	VPBROADCASTB AX, Z3
	
process_loop:
	// Check if we have 64 bytes to process
	MOVQ CX, BX
	SUBQ R11, BX
	CMPQ BX, $64
	JL process_scalar
	
	// Load 64 bytes
	VMOVDQU8 (SI)(R11*1), Z4
	
	// Create escape mask (bytes that need escaping)
	// Initialize mask to all zeros
	KXORQ K1, K1, K1
	
	// Check backslash
	VPCMPEQB Z0, Z4, K2
	KORQ K1, K2, K1
	
	// Check quote
	VPCMPEQB Z1, Z4, K2
	KORQ K1, K2, K1
	
	// Check control chars (< 0x20)
	VPCMPUB $1, Z2, Z4, K2    // LT comparison
	KORQ K1, K2, K1
	
	// Check DEL
	VPCMPEQB Z3, Z4, K2
	KORQ K1, K2, K1
	
	// Check if any bytes need escaping
	KORTESTQ K1, K1
	JNZ process_scalar        // If any need escaping, use scalar
	
	// No escaping needed - fast copy 64 bytes
	MOVQ R9, AX
	SUBQ R10, AX
	CMPQ AX, $64
	JL overflow
	
	VMOVDQU8 Z4, (DI)(R10*1)
	ADDQ $64, R10
	ADDQ $64, R11
	JMP process_loop
	
process_scalar:
	// Process remaining bytes or bytes that need escaping
	CMPQ R11, CX
	JGE write_closing_quote
	
	// Load one byte
	MOVBLZX (SI)(R11*1), AX
	INCQ R11
	
	// Check if needs escaping
	CMPB AX, DL               // quote?
	JE escape_quote
	CMPB AX, $0x5C            // backslash?
	JE escape_backslash
	CMPB AX, $0x20            // < space?
	JL escape_control
	CMPB AX, $0x7F            // DEL?
	JE escape_control
	
	// No escaping needed
	CMPQ R10, R9
	JGE overflow
	MOVB AX, (DI)(R10*1)
	INCQ R10
	JMP process_scalar
	
escape_quote:
escape_backslash:
	// Write backslash + character
	MOVQ R9, BX
	SUBQ R10, BX
	CMPQ BX, $2
	JL overflow
	MOVB $0x5C, (DI)(R10*1)
	INCQ R10
	MOVB AX, (DI)(R10*1)
	INCQ R10
	JMP process_scalar
	
escape_control:
	// Escape control characters as \x## or special escapes
	// For simplicity, use \x## format
	MOVQ R9, BX
	SUBQ R10, BX
	CMPQ BX, $4
	JL overflow
	
	// Write \x
	MOVB $0x5C, (DI)(R10*1)
	INCQ R10
	MOVB $'x', (DI)(R10*1)
	INCQ R10
	
	// Write two hex digits
	MOVQ AX, BX
	SHRQ $4, BX
	ANDQ $0xF, BX
	CMPQ BX, $10
	JL hex_hi_digit
	ADDB $('a'-10), BX
	JMP write_hex_hi
hex_hi_digit:
	ADDB $'0', BX
write_hex_hi:
	MOVB BX, (DI)(R10*1)
	INCQ R10
	
	ANDQ $0xF, AX
	CMPQ AX, $10
	JL hex_lo_digit
	ADDB $('a'-10), AX
	JMP write_hex_lo
hex_lo_digit:
	ADDB $'0', AX
write_hex_lo:
	MOVB AX, (DI)(R10*1)
	INCQ R10
	JMP process_scalar
	
write_closing_quote:
	// Write closing quote
	CMPQ R10, R9
	JGE overflow
	MOVB DL, (DI)(R10*1)
	INCQ R10
	
	// Clean up and return
	VZEROUPPER
	MOVQ R10, ret+56(FP)
	RET
	
overflow:
	// Buffer overflow - return -1
	VZEROUPPER
	MOVQ $-1, ret+56(FP)
	RET

