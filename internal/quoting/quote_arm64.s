// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func needsEscapingASM(s string, quote byte, mode int) bool
// NEON-optimized version that processes 16 bytes at a time
TEXT ·needsEscapingASM(SB), NOSPLIT, $0-34
	// Get string pointer and length
	MOVD s_base+0(FP), R0    // R0 = string data pointer
	MOVD s_len+8(FP), R1     // R1 = string length
	MOVBU quote+16(FP), R2   // R2 = quote character
	MOVD mode+24(FP), R3     // R3 = mode
	
	// Fast path: empty string needs no escaping
	CBZ R1, no_escape
	
	// Use optimized scalar loop (16-byte unrolled) for strings >= 16 bytes
	// Note: NEON not fully supported in Go assembler
	CMP $16, R1
	BLT scalar_loop
	
	MOVD $0, R4              // R4 = index
	
unrolled_loop:
	// Check if we have at least 16 bytes left
	SUB R4, R1, R5
	CMP $16, R5
	BLT loop_remainder
	
	// Check 16 bytes manually (unrolled for performance)
	// Byte 0
	MOVBU (R0)(R4), R5
	CMP R2, R5              // == quote?
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5              // == backslash?
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5              // < space?
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5              // == DEL?
	BEQ needs_escape
	CMP $1, R3              // Check mode
	BNE byte1_check
	MOVD $0x80, R6
	CMP R6, R5              // >= 0x80 (non-ASCII)?
	BGE needs_escape
	
byte1_check:
	ADD $1, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte2_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte2_check:
	ADD $2, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte3_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte3_check:
	ADD $3, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte4_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte4_check:
	ADD $4, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte5_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte5_check:
	ADD $5, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte6_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte6_check:
	ADD $6, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte7_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte7_check:
	ADD $7, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte8_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte8_check:
	ADD $8, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte9_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte9_check:
	ADD $9, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte10_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte10_check:
	ADD $10, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte11_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte11_check:
	ADD $11, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte12_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte12_check:
	ADD $12, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte13_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte13_check:
	ADD $13, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte14_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte14_check:
	ADD $14, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE byte15_check
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
byte15_check:
	ADD $15, R4, R7
	MOVBU (R0)(R7), R5
	CMP R2, R5
	BEQ needs_escape
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	CMP $1, R3
	BNE unrolled_next
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
unrolled_next:
	// Advance by 16 bytes
	ADD $16, R4
	B unrolled_loop
	
loop_remainder:
	// Process remaining bytes with scalar loop
	CMP R1, R4
	BEQ no_escape
	
loop_remainder_body:
	MOVBU (R0)(R4), R5
	
	// Check if byte == quote
	CMP R2, R5
	BEQ needs_escape
	
	// Check if byte == backslash
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	
	// Check if byte < ' '
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	
	// Check if byte == 0x7F
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	
	// Check for non-ASCII in ASCII mode
	CMP $1, R3
	BNE loop_remainder_next
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
loop_remainder_next:
	ADD $1, R4
	CMP R1, R4
	BLT loop_remainder_body
	B no_escape
	
scalar_loop:
	MOVD $0, R4              // R4 = index
	
scalar_loop_body:
	MOVBU (R0)(R4), R5       // R5 = current byte
	
	// Check if byte == quote
	CMP R2, R5
	BEQ needs_escape
	
	// Check if byte == backslash
	MOVD $'\\', R6
	CMP R6, R5
	BEQ needs_escape
	
	// Check if byte < ' '
	MOVD $' ', R6
	CMP R6, R5
	BLT needs_escape
	
	// Check if byte == 0x7F
	MOVD $0x7F, R6
	CMP R6, R5
	BEQ needs_escape
	
	// Check for non-ASCII in ASCII mode
	CMP $1, R3
	BNE scalar_next
	MOVD $0x80, R6
	CMP R6, R5
	BGE needs_escape
	
scalar_next:
	ADD $1, R4
	CMP R1, R4
	BLT scalar_loop_body
	
no_escape:
	MOVD $0, R0
	MOVB R0, ret+32(FP)
	RET
	
needs_escape:
	MOVD $1, R0
	MOVB R0, ret+32(FP)
	RET

