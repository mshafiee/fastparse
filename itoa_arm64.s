// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Assembly-optimized FormatInt base-10 for arm64
//go:build arm64

#include "textflag.h"

// smallsString lookup table
DATA smallsStringData<>+0(SB)/8, $0x3330323130303130    // "01020304"
DATA smallsStringData<>+8(SB)/8, $0x3730363035303430    // "04050607"
DATA smallsStringData<>+16(SB)/8, $0x3131303139303830   // "08091011"
DATA smallsStringData<>+24(SB)/8, $0x3531343133313231   // "12131415"
DATA smallsStringData<>+32(SB)/8, $0x3931383137313631   // "16171819"
DATA smallsStringData<>+40(SB)/8, $0x3332323132303230   // "20212223"
DATA smallsStringData<>+48(SB)/8, $0x3732363235323432   // "24252627"
DATA smallsStringData<>+56(SB)/8, $0x3133303239323832   // "28293031"
DATA smallsStringData<>+64(SB)/8, $0x3533343333323333   // "32333435"
DATA smallsStringData<>+72(SB)/8, $0x3933383337333633   // "36373839"
DATA smallsStringData<>+80(SB)/8, $0x3334323134303430   // "40414243"
DATA smallsStringData<>+88(SB)/8, $0x3734363435343434   // "44454647"
DATA smallsStringData<>+96(SB)/8, $0x3135303139343834   // "48495051"
DATA smallsStringData<>+104(SB)/8, $0x3535343335323535  // "52535455"
DATA smallsStringData<>+112(SB)/8, $0x3935383537353635  // "56575859"
DATA smallsStringData<>+120(SB)/8, $0x3336323136303630  // "60616263"
DATA smallsStringData<>+128(SB)/8, $0x3736363536343636  // "64656667"
DATA smallsStringData<>+136(SB)/8, $0x3137303139363836  // "68697071"
DATA smallsStringData<>+144(SB)/8, $0x3537343337323737  // "72737475"
DATA smallsStringData<>+152(SB)/8, $0x3937383738363737  // "76777879"
DATA smallsStringData<>+160(SB)/8, $0x3338323138303830  // "80818283"
DATA smallsStringData<>+168(SB)/8, $0x3738363538343838  // "84858687"
DATA smallsStringData<>+176(SB)/8, $0x3139303139383838  // "88899091"
DATA smallsStringData<>+184(SB)/8, $0x3539343339323939  // "92939495"
DATA smallsStringData<>+192(SB)/8, $0x3939383739363939  // "96979899"
GLOBL smallsStringData<>(SB), RODATA, $200

// func formatIntBase10ASM(dst []byte, u uint64) int
TEXT ·formatIntBase10ASM(SB), NOSPLIT, $24-40
	MOVD dst_base+0(FP), R0  // R0 = dst pointer
	MOVD u+24(FP), R1        // R1 = u
	
	// Handle u == 0
	CBZ R1, zero
	
	// Use stack buffer (24 bytes)
	MOVD RSP, R2             // R2 = temp buffer
	ADD $23, R2, R3          // R3 = end of buffer
	
	// Magic constant for /100: 0x28F5C28F5C28F5C
	MOVD $0x28F5C28F5C28F5C, R4
	MOVD $100, R5
	MOVD $smallsStringData<>(SB), R6
	
convert_loop:
	// Check if u >= 100
	CMP $100, R1
	BLT last_digits
	
	// Compute u / 100 using multiplication
	UMULH R4, R1, R7         // R7 = (u * magic) >> 64
	LSR $7, R7               // R7 = q = u / 100
	
	// r = u - q * 100
	MSUB R7, R5, R1, R8      // R8 = r = u - q * 100
	
	// Look up two digits
	LSL $1, R8               // R8 = r * 2
	MOVHU (R6)(R8), R9       // Load 2 bytes
	
	// Store in reverse
	SUB $2, R3
	MOVH R9, (R3)
	
	// Continue with q
	MOVD R7, R1
	B convert_loop
	
last_digits:
	// Handle 1 or 2 digits
	CMP $10, R1
	BLT single_digit
	
	// Two digits
	LSL $1, R1
	MOVHU (R6)(R1), R9
	SUB $2, R3
	MOVH R9, (R3)
	B copy_result
	
single_digit:
	// One digit
	ADD $'0', R1
	SUB $1, R3
	MOVB R1, (R3)
	
copy_result:
	// Calculate length
	MOVD RSP, R7
	ADD $23, R7
	SUB R3, R7               // R7 = length
	
	// Copy to dst
	MOVD R7, R8              // Save length
	
copy_loop:
	CBZ R7, done
	MOVBU.P 1(R3), R9
	MOVB.P R9, 1(R0)
	SUB $1, R7
	B copy_loop
	
done:
	MOVD R8, ret+32(FP)
	RET
	
zero:
	MOVD $'0', R1
	MOVB R1, (R0)
	MOVD $1, R1
	MOVD R1, ret+32(FP)
	RET

