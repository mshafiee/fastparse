// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Assembly-optimized float exponent formatting for arm64
//go:build arm64

#include "textflag.h"

// func formatExponentASM(dst []byte, exp int, fmt byte) int
TEXT ·formatExponentASM(SB), NOSPLIT, $0-35
	MOVD dst_base+0(FP), R0  // R0 = dst pointer
	MOVD R0, R10             // R10 = save original pointer
	MOVD exp+24(FP), R1      // R1 = exp (signed)
	MOVBU fmt+32(FP), R2     // R2 = format char
	
	// Store format character
	MOVB R2, (R0)
	ADD $1, R0
	
	// Handle sign
	MOVD $'+', R3
	CMP $0, R1
	BGE positive
	NEG R1, R1               // Make exp positive
	MOVD $'-', R3
	
positive:
	MOVB R3, (R0)
	ADD $1, R0
	
	// Check if exp < 10
	CMP $10, R1
	BLT single_digit_exp
	
	// Check if exp < 100
	CMP $100, R1
	BLT two_digit_exp
	
	// Three digits
	MOVD R1, R4
	
	// hundreds = exp / 100 using magic multiply
	MOVD $0x51EB851F, R5
	MUL R5, R4
	LSR $37, R4              // R4 = hundreds
	ADD $'0', R4
	MOVB R4, (R0)
	ADD $1, R0
	
	// exp = exp - hundreds * 100
	SUB $'0', R4
	MOVD $100, R5
	MSUB R4, R5, R1, R1
	
two_digit_exp:
	// tens = exp / 10
	MOVD $0xCCCCCCCD, R5
	UMULH R5, R1, R4
	LSR $3, R4               // R4 = tens
	ADD $'0', R4
	MOVB R4, (R0)
	ADD $1, R0
	
	// ones = exp - tens * 10
	SUB $'0', R4
	MOVD $10, R5
	MSUB R4, R5, R1, R1
	ADD $'0', R1
	MOVB R1, (R0)
	ADD $1, R0
	
	// Calculate length
	SUB R10, R0
	MOVD R0, ret+32(FP)
	RET
	
single_digit_exp:
	// e±0d
	MOVD $'0', R3
	MOVB R3, (R0)
	ADD $1, R0
	ADD $'0', R1
	MOVB R1, (R0)
	ADD $1, R0
	
	// Calculate length
	SUB R10, R0
	MOVD R0, ret+32(FP)
	RET

