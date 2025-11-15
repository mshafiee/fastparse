// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func hasUnderscoreNEON(s string) bool
// Scans string for underscore using scalar loop (NEON not fully supported in Go assembler)
TEXT ·hasUnderscoreNEON(SB), NOSPLIT, $0-17
	MOVD s_ptr+0(FP), R0        // R0 = string pointer
	MOVD s_len+8(FP), R1        // R1 = string length
	
	// Check for empty string
	CBZ R1, not_found
	
	// Use optimized scalar loop (16-byte unrolled)
	MOVD $0, R3                 // R3 = index
	
neon_loop:
	// Check if we have at least 16 bytes left
	SUB R3, R1, R4              // R4 = remaining bytes
	CMP $16, R4
	BLT neon_remainder
	
	// Check 16 bytes manually (unrolled for performance)
	MOVBU (R0)(R3), R5
	CMP $'_', R5
	BEQ found
	ADD $1, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $2, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $3, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $4, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $5, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $6, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $7, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $8, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $9, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $10, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $11, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $12, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $13, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $14, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	ADD $15, R3, R6
	MOVBU (R0)(R6), R5
	CMP $'_', R5
	BEQ found
	
	// Advance by 16 bytes
	ADD $16, R3, R3
	B neon_loop
	
neon_remainder:
	// Handle remaining bytes (< 16) with scalar
	CMP R1, R3
	BGE not_found
	
scalar_loop:
	MOVBU (R0)(R3), R5
	CMP $'_', R5
	BEQ found
	ADD $1, R3, R3
	CMP R1, R3
	BLT scalar_loop
	
not_found:
	MOVD $0, R5
	MOVB R5, ret+16(FP)
	RET
	
found:
	MOVD $1, R5
	MOVB R5, ret+16(FP)
	RET

