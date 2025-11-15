// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"

// func hasUnderscoreAVX2(s string) bool
// Scans string for underscore using AVX2 (32 bytes per iteration)
TEXT ·hasUnderscoreAVX2(SB), NOSPLIT, $0-17
	MOVQ s_ptr+0(FP), SI        // SI = string pointer
	MOVQ s_len+8(FP), CX        // CX = string length
	
	// Check for empty string
	TESTQ CX, CX
	JZ not_found
	
	// Load underscore into all bytes of YMM0
	MOVQ $0x5F5F5F5F5F5F5F5F, AX  // '_' repeated 8 times
	MOVQ AX, X0
	VPBROADCASTQ X0, Y0          // Broadcast to all 32 bytes of Y0
	
	// Process 32 bytes at a time
	XORQ DX, DX                  // DX = index
	
avx2_loop:
	// Check if we have at least 32 bytes left
	MOVQ CX, BX
	SUBQ DX, BX
	CMPQ BX, $32
	JL avx2_remainder
	
	// Load 32 bytes
	VMOVDQU (SI)(DX*1), Y1
	
	// Compare with underscore
	VPCMPEQB Y0, Y1, Y2
	
	// Check if any byte matched
	VPMOVMSKB Y2, AX
	TESTL AX, AX
	JNZ found
	
	// Advance by 32 bytes
	ADDQ $32, DX
	JMP avx2_loop
	
avx2_remainder:
	// Handle remaining bytes (< 32) with scalar
	CMPQ DX, CX
	JGE not_found
	
scalar_loop:
	MOVBLZX (SI)(DX*1), AX
	CMPB AX, $'_'
	JE found
	INCQ DX
	CMPQ DX, CX
	JL scalar_loop
	
not_found:
	MOVB $0, ret+16(FP)
	VZEROUPPER                   // Clean up YMM registers
	RET
	
found:
	MOVB $1, ret+16(FP)
	VZEROUPPER                   // Clean up YMM registers
	RET

// func hasUnderscoreSSE2(s string) bool
// Scans string for underscore using SSE2 (16 bytes per iteration)
TEXT ·hasUnderscoreSSE2(SB), NOSPLIT, $0-17
	MOVQ s_ptr+0(FP), SI        // SI = string pointer
	MOVQ s_len+8(FP), CX        // CX = string length
	
	// Check for empty string
	TESTQ CX, CX
	JZ sse2_not_found
	
	// Load underscore into all bytes of XMM0
	MOVQ $0x5F5F5F5F5F5F5F5F, AX  // '_' repeated 8 times
	MOVQ AX, X0
	PSHUFB X0, X0                 // Broadcast (using PSHUFB as broadcast)
	// Actually, simpler approach:
	MOVQ $0x5F5F5F5F5F5F5F5F, AX
	MOVQ AX, X0
	MOVQ AX, X1
	PUNPCKLQDQ X1, X0             // X0 = all underscores (16 bytes)
	
	// Process 16 bytes at a time
	XORQ DX, DX                  // DX = index
	
sse2_loop:
	// Check if we have at least 16 bytes left
	MOVQ CX, BX
	SUBQ DX, BX
	CMPQ BX, $16
	JL sse2_remainder
	
	// Load 16 bytes
	MOVOU (SI)(DX*1), X1
	
	// Compare with underscore
	PCMPEQB X0, X1
	
	// Check if any byte matched
	PMOVMSKB X1, AX
	TESTL AX, AX
	JNZ sse2_found
	
	// Advance by 16 bytes
	ADDQ $16, DX
	JMP sse2_loop
	
sse2_remainder:
	// Handle remaining bytes (< 16) with scalar
	CMPQ DX, CX
	JGE sse2_not_found
	
sse2_scalar_loop:
	MOVBLZX (SI)(DX*1), AX
	CMPB AX, $'_'
	JE sse2_found
	INCQ DX
	CMPQ DX, CX
	JL sse2_scalar_loop
	
sse2_not_found:
	MOVB $0, ret+16(FP)
	RET
	
sse2_found:
	MOVB $1, ret+16(FP)
	RET

