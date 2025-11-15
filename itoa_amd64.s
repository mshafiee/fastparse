// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Assembly-optimized FormatInt base-10 for amd64
//go:build amd64

#include "textflag.h"

// smallsString lookup table (external reference)
DATA smallsStringData<>+0(SB)/8, $"00010203"
DATA smallsStringData<>+8(SB)/8, $"04050607"
DATA smallsStringData<>+16(SB)/8, $"08091011"
DATA smallsStringData<>+24(SB)/8, $"12131415"
DATA smallsStringData<>+32(SB)/8, $"16171819"
DATA smallsStringData<>+40(SB)/8, $"20212223"
DATA smallsStringData<>+48(SB)/8, $"24252627"
DATA smallsStringData<>+56(SB)/8, $"28293031"
DATA smallsStringData<>+64(SB)/8, $"32333435"
DATA smallsStringData<>+72(SB)/8, $"36373839"
DATA smallsStringData<>+80(SB)/8, $"40414243"
DATA smallsStringData<>+88(SB)/8, $"44454647"
DATA smallsStringData<>+96(SB)/8, $"48495051"
DATA smallsStringData<>+104(SB)/8, $"52535455"
DATA smallsStringData<>+112(SB)/8, $"56575859"
DATA smallsStringData<>+120(SB)/8, $"60616263"
DATA smallsStringData<>+128(SB)/8, $"64656667"
DATA smallsStringData<>+136(SB)/8, $"68697071"
DATA smallsStringData<>+144(SB)/8, $"72737475"
DATA smallsStringData<>+152(SB)/8, $"76777879"
DATA smallsStringData<>+160(SB)/8, $"80818283"
DATA smallsStringData<>+168(SB)/8, $"84858687"
DATA smallsStringData<>+176(SB)/8, $"88899091"
DATA smallsStringData<>+184(SB)/8, $"92939495"
DATA smallsStringData<>+192(SB)/8, $"96979899"
GLOBL smallsStringData<>(SB), RODATA, $200

// func formatIntBase10ASM(dst []byte, u uint64) int
// Formats u as base-10 into dst, returns number of bytes written
TEXT ·formatIntBase10ASM(SB), NOSPLIT, $24-36
	MOVQ dst_base+0(FP), DI  // DI = dst pointer
	MOVQ u+24(FP), AX        // AX = u
	
	// Handle u == 0 specially
	TESTQ AX, AX
	JNZ nonzero
	MOVB $'0', (DI)
	MOVQ $1, ret+32(FP)
	RET
	
nonzero:
	// Use a fixed buffer on stack to build the number backwards
	LEAQ -24(SP), SI         // SI = temp buffer pointer (24 bytes)
	MOVQ SI, R8              // R8 = start of buffer
	ADDQ $23, SI             // SI = end of buffer
	
	// Load magic constant for division by 100
	// Reciprocal: (1 << 64) / 100 ≈ 184467440737095516 = 0x28F5C28F5C28F5C
	MOVQ $0x28F5C28F5C28F5C, R9
	MOVQ $100, R10
	LEAQ smallsStringData<>(SB), R11
	
convert_loop:
	// Check if u >= 100
	CMPQ AX, $100
	JL last_digits
	
	// Compute u / 100 and u % 100 using multiplication
	// q = (u * reciprocal) >> 64
	MOVQ AX, DX
	MULQ R9                  // DX:AX = u * reciprocal
	// DX now contains the high 64 bits = u / 100 (approximately)
	SHRQ $7, DX              // Adjust: (u * recip >> 64) >> 7
	MOVQ DX, CX              // CX = q = u / 100
	
	// r = u - q * 100
	IMULQ R10, DX            // DX = q * 100
	SUBQ DX, AX              // AX = r = u % 100
	
	// Look up two digits from smallsString
	MOVQ AX, BX
	SHLQ $1, BX              // BX = r * 2
	MOVW (R11)(BX*1), DX     // Load 2 bytes
	
	// Store in reverse order
	SUBQ $2, SI
	MOVW DX, (SI)
	
	// Continue with q
	MOVQ CX, AX
	JMP convert_loop
	
last_digits:
	// Handle remaining 1 or 2 digits
	CMPQ AX, $10
	JL single_digit
	
	// Two digits
	MOVQ AX, BX
	SHLQ $1, BX
	MOVW (R11)(BX*1), DX
	SUBQ $2, SI
	MOVW DX, (SI)
	JMP copy_result
	
single_digit:
	// One digit
	ADDB $'0', AX
	SUBQ $1, SI
	MOVB AX, (SI)
	
copy_result:
	// Calculate length
	MOVQ R8, CX
	ADDQ $23, CX
	SUBQ SI, CX              // CX = length
	
	// Copy from temp buffer to dst
	MOVQ DI, R12             // Save dst
	MOVQ CX, R13             // Save length
	
copy_loop:
	TESTQ CX, CX
	JZ done
	MOVB (SI), AX
	MOVB AX, (DI)
	INCQ SI
	INCQ DI
	DECQ CX
	JMP copy_loop
	
done:
	MOVQ R13, ret+32(FP)     // Return length
	RET

