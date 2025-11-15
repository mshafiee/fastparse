// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func isPrintASM(r rune) bool
// Optimized binary search for Unicode ranges > 0xFF
TEXT ·isPrintASM(SB), NOSPLIT, $0-5
	MOVW r+0(FP), R0         // R0 = r (rune)
	
	// Fast check: if r >= 0x20000, it's printable
	MOVD $0x20000, R1
	CMP R1, R0
	BGE is_printable
	
	// Check if r < 0x10000 (16-bit)
	MOVD $0x10000, R1
	CMP R1, R0
	BLT check_16bit
	
	// r is in range [0x10000, 0x20000)
	// Adjust r to search in isNotPrint (r -= 0x10000)
	SUB $0x10000, R0
	
	// Binary search in isNotPrint16
	// Get table address
	MOVD $·isNotPrint16(SB), R1
	MOVD $0, R2              // left = 0
	MOVD ·isNotPrint16+8(SB), R3  // right = len(isNotPrint16)
	LSR $1, R3               // right /= 2 (convert byte length to element count)
	
not_print_search:
	CMP R3, R2
	BGE not_found_not_print
	
	// mid = left + (right - left) / 2
	SUB R2, R3, R4
	LSR $1, R4
	ADD R2, R4               // R4 = mid
	
	// Load isPrint[mid]
	LSL $1, R4, R5           // R5 = mid * 2
	MOVHU (R1)(R5), R6       // R6 = isNotPrint16[mid]
	
	CMP R6, R0
	BLT not_print_go_left
	BEQ found_in_not_print
	
	// go right: left = mid + 1
	ADD $1, R4, R2
	MOVD ·isNotPrint16+8(SB), R3
	LSR $1, R3
	B not_print_search
	
not_print_go_left:
	// go left: right = mid
	MOVD R4, R3
	B not_print_search
	
found_in_not_print:
	// Found in isNotPrint list, so it's NOT printable
	MOVD $0, R0
	MOVB R0, ret+4(FP)
	RET
	
not_found_not_print:
	// Not found in isNotPrint, so it IS printable
	MOVD $1, R0
	MOVB R0, ret+4(FP)
	RET
	
check_16bit:
	// r is in range [0x100, 0x10000)
	// Binary search in isPrint16
	MOVD $·isPrint16(SB), R1
	MOVD $0, R2              // left = 0
	MOVD ·isPrint16+8(SB), R3     // right = len(isPrint16)
	LSR $1, R3               // right /= 2
	
print16_search:
	CMP R3, R2
	BGE print16_not_found
	
	// mid = left + (right - left) / 2
	SUB R2, R3, R4
	LSR $1, R4
	ADD R2, R4               // R4 = mid
	
	// Load isPrint16[mid]
	LSL $1, R4, R5
	MOVHU (R1)(R5), R6       // R6 = isPrint16[mid]
	
	CMP R6, R0
	BLT print16_go_right
	
	// go left: right = mid
	MOVD R4, R3
	B print16_search
	
print16_go_right:
	// go right: left = mid + 1
	ADD $1, R4, R2
	MOVD ·isPrint16+8(SB), R3
	LSR $1, R3
	B print16_search
	
print16_not_found:
	// i = left (R2)
	// Check if we're past the end
	MOVD ·isPrint16+8(SB), R3
	LSR $1, R3
	CMP R3, R2
	BGE not_printable
	
	// Check if r < isPrint16[i&^1] || isPrint16[i|1] < r
	AND $-2, R2, R4          // R4 = i & ^1
	LSL $1, R4, R5
	MOVHU (R1)(R5), R6       // R6 = isPrint16[i&^1]
	CMP R0, R6               // Compare r with isPrint16[i&^1]
	BLT not_printable        // if r < isPrint16[i&^1], not printable
	
	ORR $1, R2, R4           // R4 = i | 1
	CMP R3, R4
	BGE not_printable
	LSL $1, R4, R5
	MOVHU (R1)(R5), R6       // R6 = isPrint16[i|1]
	CMP R6, R0
	BLT check_not_print16
	
not_printable:
	MOVD $0, R0
	MOVB R0, ret+4(FP)
	RET
	
check_not_print16:
	// Check isNotPrint16
	MOVD $·isNotPrint16(SB), R1
	MOVD $0, R2
	MOVD ·isNotPrint16+8(SB), R3
	LSR $1, R3
	
not_print16_search:
	CMP R3, R2
	BGE is_printable
	
	// mid = left + (right - left) / 2
	SUB R2, R3, R4
	LSR $1, R4
	ADD R2, R4
	
	LSL $1, R4, R5
	MOVHU (R1)(R5), R6
	
	CMP R6, R0
	BEQ not_printable
	BLT not_print16_go_left
	
	// go right
	ADD $1, R4, R2
	MOVD ·isNotPrint16+8(SB), R3
	LSR $1, R3
	B not_print16_search
	
not_print16_go_left:
	MOVD R4, R3
	B not_print16_search
	
is_printable:
	MOVD $1, R0
	MOVB R0, ret+4(FP)
	RET

