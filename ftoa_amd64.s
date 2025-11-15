// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Assembly-optimized float exponent formatting for amd64
//go:build amd64

#include "textflag.h"

// func formatExponentASM(dst []byte, exp int, fmt byte) int
// Formats exponent in scientific notation (e±dd or e±ddd)
TEXT ·formatExponentASM(SB), NOSPLIT, $0-35
	MOVQ dst_base+0(FP), DI  // DI = dst pointer
	MOVQ DI, R15             // R15 = save original pointer
	MOVQ exp+24(FP), AX      // AX = exp (signed)
	MOVB fmt+32(FP), BL      // BL = format char ('e' or 'E')
	
	// Store format character
	MOVB BL, (DI)
	ADDQ $1, DI
	
	// Handle sign
	MOVB $'+', CL
	TESTQ AX, AX
	JNS positive
	NEGQ AX                  // Make exp positive
	MOVB $'-', CL
	
positive:
	MOVB CL, (DI)
	ADDQ $1, DI
	
	// Format exponent digits using branchless approach
	// Check if exp < 10
	CMPQ AX, $10
	JL single_digit_exp
	
	// Check if exp < 100
	CMPQ AX, $100
	JL two_digit_exp
	
	// Three digits: exp >= 100
	MOVQ AX, CX
	
	// hundreds = exp / 100
	MOVQ $0x51EB851F, DX     // Magic number for /100
	IMULQ DX, CX
	SHRQ $37, CX             // CX = hundreds
	ADDB $'0', CL
	MOVB CL, (DI)
	ADDQ $1, DI
	
	// Remove hundreds: exp = exp - hundreds * 100
	IMULQ $100, CX
	SUBQ CX, AX
	
two_digit_exp:
	// tens = exp / 10
	MOVQ AX, CX
	MOVQ $0xCCCCCCCD, DX     // Magic number for /10
	MULQ DX
	SHRQ $35, DX             // DX = tens
	MOVB DL, CL
	ADDB $'0', CL
	MOVB CL, (DI)
	ADDQ $1, DI
	
	// ones = exp - tens * 10
	IMULQ $10, DX
	SUBQ DX, AX
	ADDB $'0', AL
	MOVB AL, (DI)
	ADDQ $1, DI
	
	// Calculate total length
	SUBQ R15, DI
	MOVQ DI, ret+32(FP)
	RET
	
single_digit_exp:
	// Single digit with leading zero: e±0d
	MOVB $'0', (DI)
	ADDQ $1, DI
	ADDB $'0', AL
	MOVB AL, (DI)
	ADDQ $1, DI
	
	// Calculate total length
	SUBQ R15, DI
	MOVQ DI, ret+32(FP)
	RET

