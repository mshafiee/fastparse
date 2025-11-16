//go:build amd64

#include "textflag.h"

// func needsEscapingAVX512(s string, quote byte, mode int) bool
// AVX-512 version that processes 64 bytes at a time
// Only called if CPU supports AVX-512
TEXT ·needsEscapingAVX512(SB), NOSPLIT, $0-34
	// Get string pointer and length
	MOVQ s_base+0(FP), SI    // SI = string data pointer
	MOVQ s_len+8(FP), CX     // CX = string length
	MOVB quote+16(FP), DX    // DL = quote character
	MOVQ mode+24(FP), R8     // R8 = mode
	
	// Fast path: empty string needs no escaping
	TESTQ CX, CX
	JZ no_escape
	
	// For strings < 64 bytes, use AVX2 path
	CMPQ CX, $64
	JL no_escape  // Fall back to AVX2 (caller will handle)
	
	// Prepare AVX-512 constants using ZMM registers
	// Broadcast quote character to all 64 bytes of Z0
	MOVB DL, AX
	VPBROADCASTB AX, Z0      // Z0 = quote repeated 64 times
	
	// Z1 = backslash repeated 64 times
	MOVQ $0x5C, AX           // '\' = 0x5C
	VPBROADCASTB AX, Z1
	
	// Z2 = space (0x20) repeated 64 times (for < check)
	MOVQ $0x20, AX
	VPBROADCASTB AX, Z2
	
	// Z3 = DEL (0x7F) repeated 64 times
	MOVQ $0x7F, AX
	VPBROADCASTB AX, Z3
	
	// Z4 = 0x80 for non-ASCII check
	MOVQ $0x80, AX
	VPBROADCASTB AX, Z4
	
	XORQ DX, DX              // DX = index
	
avx512_loop:
	// Check if we have at least 64 bytes left
	MOVQ CX, BX
	SUBQ DX, BX
	CMPQ BX, $64
	JL avx512_remainder
	
	// Load 64 bytes using AVX-512
	VMOVDQU8 (SI)(DX*1), Z5
	
	// Check 1: byte == quote (using mask registers)
	VPCMPEQB Z0, Z5, K1      // K1 = mask where bytes == quote
	KTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 2: byte == backslash
	VPCMPEQB Z1, Z5, K1
	KTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 3: byte < ' ' (control characters)
	VPCMPUB $1, Z2, Z5, K1   // K1 = mask where bytes < 0x20 (cmp LT)
	KTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 4: byte == 0x7F (DEL)
	VPCMPEQB Z3, Z5, K1
	KTESTQ K1, K1
	JNZ avx512_needs_escape
	
	// Check 5: byte >= 0x80 (non-ASCII) if mode == ModeASCII (1)
	CMPQ R8, $1
	JNE avx512_next
	VPCMPUB $5, Z4, Z5, K1   // K1 = mask where bytes >= 0x80 (cmp GE)
	KTESTQ K1, K1
	JNZ avx512_needs_escape
	
avx512_next:
	ADDQ $64, DX
	JMP avx512_loop
	
avx512_remainder:
	// Clean up AVX-512 registers
	VZEROUPPER
	// Fall back to scalar for remaining bytes
	JMP no_escape  // Let caller handle remainder with AVX2/scalar
	
avx512_needs_escape:
	VZEROUPPER
	MOVB $1, ret+32(FP)
	RET

no_escape:
	MOVB $0, ret+32(FP)
	RET

