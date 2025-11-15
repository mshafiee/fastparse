// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"

// func needsEscapingASM(s string, quote byte, mode int) bool
// AVX2-optimized version that processes 32 bytes at a time
TEXT ·needsEscapingASM(SB), NOSPLIT, $0-34
	// Get string pointer and length
	MOVQ s_base+0(FP), SI    // SI = string data pointer
	MOVQ s_len+8(FP), CX     // CX = string length
	MOVB quote+16(FP), DX    // DL = quote character
	MOVQ mode+24(FP), R8     // R8 = mode
	
	// Fast path: empty string needs no escaping
	TESTQ CX, CX
	JZ no_escape
	
	// Try AVX2 path for strings >= 32 bytes
	CMPQ CX, $32
	JL sse2_path
	
	// Prepare AVX2 constants
	// Broadcast quote character to all 32 bytes of Y0
	MOVB DL, AX
	MOVQ AX, X0
	VPBROADCASTB X0, Y0      // Y0 = quote repeated 32 times
	
	// Y1 = backslash repeated 32 times
	MOVQ $0x5C, AX           // '\' = 0x5C
	MOVQ AX, X1
	VPBROADCASTB X1, Y1
	
	// Y2 = space (0x20) repeated 32 times (for < check)
	MOVQ $0x20, AX
	MOVQ AX, X2
	VPBROADCASTB X2, Y2
	
	// Y3 = DEL (0x7F) repeated 32 times
	MOVQ $0x7F, AX
	MOVQ AX, X3
	VPBROADCASTB X3, Y3
	
	// Y4 = 0x80 for non-ASCII check
	MOVQ $0x80, AX
	MOVQ AX, X4
	VPBROADCASTB X4, Y4
	
	XORQ DX, DX              // DX = index
	
avx2_loop:
	// Check if we have at least 32 bytes left
	MOVQ CX, BX
	SUBQ DX, BX
	CMPQ BX, $32
	JL avx2_remainder
	
	// Load 32 bytes
	VMOVDQU (SI)(DX*1), Y5
	
	// Check 1: byte == quote
	VPCMPEQB Y0, Y5, Y6
	VPMOVMSKB Y6, AX
	TESTL AX, AX
	JNZ avx2_needs_escape
	
	// Check 2: byte == backslash
	VPCMPEQB Y1, Y5, Y6
	VPMOVMSKB Y6, AX
	TESTL AX, AX
	JNZ avx2_needs_escape
	
	// Check 3: byte < ' ' (control characters)
	VPCMPGTB Y5, Y2, Y6      // Y6 = (Y5 < Y2) = (byte < 0x20)
	VPMOVMSKB Y6, AX
	TESTL AX, AX
	JNZ avx2_needs_escape
	
	// Check 4: byte == 0x7F (DEL)
	VPCMPEQB Y3, Y5, Y6
	VPMOVMSKB Y6, AX
	TESTL AX, AX
	JNZ avx2_needs_escape
	
	// Check 5: byte >= 0x80 (non-ASCII) if mode == ModeASCII (1)
	CMPQ R8, $1
	JNE avx2_next
	VPCMPGTB Y4, Y5, Y6      // Y6 = (Y5 >= Y4) = (byte >= 0x80)
	// Actually need: byte >= 0x80, which is NOT(byte < 0x80)
	// Use: VPCMPGTB with negation or VPSUBB
	// Better: check if any byte has high bit set
	VPMOVMSKB Y5, AX         // Get sign bits (high bits)
	TESTL AX, AX
	JNZ avx2_needs_escape
	
avx2_next:
	ADDQ $32, DX
	JMP avx2_loop
	
avx2_remainder:
	// Clean up AVX2 registers
	VZEROUPPER
	// Fall through to scalar for remaining bytes
	JMP scalar_path

avx2_needs_escape:
	VZEROUPPER
	MOVB $1, ret+32(FP)
	RET

sse2_path:
	// SSE2 path for 16-31 byte strings
	CMPQ CX, $16
	JL scalar_path
	
	// Broadcast quote to XMM0
	MOVB quote+16(FP), AX
	MOVQ AX, X0
	// Replicate byte across XMM0
	PUNPCKLBW X0, X0
	PUNPCKLWD X0, X0
	PSHUFD $0, X0, X0
	
	// XMM1 = backslash
	MOVQ $0x5C, AX
	MOVQ AX, X1
	PUNPCKLBW X1, X1
	PUNPCKLWD X1, X1
	PSHUFD $0, X1, X1
	
	// XMM2 = space (0x20)
	MOVQ $0x20, AX
	MOVQ AX, X2
	PUNPCKLBW X2, X2
	PUNPCKLWD X2, X2
	PSHUFD $0, X2, X2
	
	// XMM3 = DEL (0x7F)
	MOVQ $0x7F, AX
	MOVQ AX, X3
	PUNPCKLBW X3, X3
	PUNPCKLWD X3, X3
	PSHUFD $0, X3, X3
	
	XORQ DX, DX
	
sse2_loop:
	MOVQ CX, BX
	SUBQ DX, BX
	CMPQ BX, $16
	JL scalar_path
	
	// Load 16 bytes
	MOVOU (SI)(DX*1), X4
	
	// Check quote
	PCMPEQB X0, X4
	PMOVMSKB X4, AX
	TESTL AX, AX
	JNZ sse2_needs_escape
	
	// Reload for next check
	MOVOU (SI)(DX*1), X4
	
	// Check backslash
	PCMPEQB X1, X4
	PMOVMSKB X4, AX
	TESTL AX, AX
	JNZ sse2_needs_escape
	
	// Reload
	MOVOU (SI)(DX*1), X4
	
	// Check < space
	MOVOA X4, X5
	PCMPGTB X2, X5           // X5 = (X4 < X2)
	PMOVMSKB X5, AX
	TESTL AX, AX
	JNZ sse2_needs_escape
	
	// Reload
	MOVOU (SI)(DX*1), X4
	
	// Check DEL
	PCMPEQB X3, X4
	PMOVMSKB X4, AX
	TESTL AX, AX
	JNZ sse2_needs_escape
	
	// Check non-ASCII if mode == 1
	CMPQ R8, $1
	JNE sse2_next
	MOVOU (SI)(DX*1), X4
	PMOVMSKB X4, AX
	TESTL AX, AX
	JNZ sse2_needs_escape
	
sse2_next:
	ADDQ $16, DX
	JMP sse2_loop

sse2_needs_escape:
	MOVB $1, ret+32(FP)
	RET

scalar_path:
	// Scalar loop for remaining bytes or short strings
	CMPQ DX, CX
	JGE no_escape
	
scalar_loop:
	MOVBLZX (SI)(DX*1), AX
	
	// Check quote
	MOVB quote+16(FP), BX
	CMPB AL, BL
	JE needs_escape
	
	// Check backslash
	CMPB AL, $0x5C
	JE needs_escape
	
	// Check < space
	CMPB AL, $0x20
	JL needs_escape
	
	// Check DEL
	CMPB AL, $0x7F
	JE needs_escape
	
	// Check non-ASCII
	CMPQ R8, $1
	JNE scalar_next
	CMPB AL, $0x80
	JGE needs_escape
	
scalar_next:
	INCQ DX
	CMPQ DX, CX
	JL scalar_loop
	
no_escape:
	MOVB $0, ret+32(FP)
	RET
	
needs_escape:
	MOVB $1, ret+32(FP)
	RET

