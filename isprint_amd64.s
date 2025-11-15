// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"

// func isPrintASM(r rune) bool
// Optimized binary search for Unicode ranges > 0xFF
TEXT ·isPrintASM(SB), NOSPLIT, $0-5
	MOVL r+0(FP), AX         // AX = r (rune)
	
	// Fast check: if r >= 0x20000, it's printable
	CMPL AX, $0x20000
	JAE is_printable
	
	// Check if r < 0x10000 (16-bit)
	CMPL AX, $0x10000
	JL check_16bit
	
	// r is in range [0x10000, 0x20000)
	// Adjust r to search in isNotPrint (r -= 0x10000)
	SUBL $0x10000, AX
	
	// Binary search in isNotPrint16
	// Get table address
	LEAQ ·isNotPrint16(SB), SI
	MOVQ $0, CX              // left = 0
	MOVQ ·isNotPrint16+8(SB), DX  // right = len(isNotPrint16)
	SHRQ $1, DX              // right /= 2 (convert byte length to element count)
	
not_print_search:
	CMPQ CX, DX
	JAE not_found_not_print
	
	// mid = left + (right - left) / 2
	MOVQ DX, BX
	SUBQ CX, BX
	SHRQ $1, BX
	ADDQ CX, BX              // BX = mid
	
	// Load isPrint[mid]
	MOVWQZX (SI)(BX*2), DI   // DI = isNotPrint16[mid]
	
	CMPW AX, DI
	JL not_print_go_left
	JE found_in_not_print
	
	// go right: left = mid + 1
	LEAQ 1(BX), CX
	JMP not_print_search
	
not_print_go_left:
	// go left: right = mid
	MOVQ BX, DX
	JMP not_print_search
	
found_in_not_print:
	// Found in isNotPrint list, so it's NOT printable
	MOVB $0, ret+4(FP)
	RET
	
not_found_not_print:
	// Not found in isNotPrint, so it IS printable
	MOVB $1, ret+4(FP)
	RET
	
check_16bit:
	// r is in range [0x100, 0x10000)
	// Binary search in isPrint16
	LEAQ ·isPrint16(SB), SI
	MOVQ $0, CX              // left = 0
	MOVQ ·isPrint16+8(SB), DX     // right = len(isPrint16)
	SHRQ $1, DX              // right /= 2 (convert byte length to element count)
	
	// Find first i such that isPrint16[i] >= r
print16_search:
	CMPQ CX, DX
	JAE print16_not_found
	
	// mid = left + (right - left) / 2
	MOVQ DX, BX
	SUBQ CX, BX
	SHRQ $1, BX
	ADDQ CX, BX              // BX = mid
	
	// Load isPrint16[mid]
	MOVWQZX (SI)(BX*2), DI   // DI = isPrint16[mid]
	
	CMPW DI, AX
	JL print16_go_right
	
	// go left: right = mid
	MOVQ BX, DX
	JMP print16_search
	
print16_go_right:
	// go right: left = mid + 1
	LEAQ 1(BX), CX
	JMP print16_search
	
print16_not_found:
	// i = left (CX)
	// Check if we're past the end
	MOVQ ·isPrint16+8(SB), DX
	SHRQ $1, DX
	CMPQ CX, DX
	JAE not_printable
	
	// Check if r < isPrint16[i&^1] || isPrint16[i|1] < r
	MOVQ CX, BX
	ANDQ $-2, BX             // BX = i & ^1 (clear low bit)
	MOVWQZX (SI)(BX*2), DI   // DI = isPrint16[i&^1]
	CMPW AX, DI
	JL not_printable
	
	ORQ $1, CX               // CX = i | 1
	CMPQ CX, DX
	JAE not_printable
	MOVWQZX (SI)(CX*2), DI   // DI = isPrint16[i|1]
	CMPW DI, AX
	JL check_not_print16
	
not_printable:
	MOVB $0, ret+4(FP)
	RET
	
check_not_print16:
	// Check isNotPrint16
	LEAQ ·isNotPrint16(SB), SI
	MOVQ $0, CX              // left = 0
	MOVQ ·isNotPrint16+8(SB), DX  // right = len(isNotPrint16)
	SHRQ $1, DX
	
not_print16_search:
	CMPQ CX, DX
	JAE is_printable
	
	// mid = left + (right - left) / 2
	MOVQ DX, BX
	SUBQ CX, BX
	SHRQ $1, BX
	ADDQ CX, BX
	
	MOVWQZX (SI)(BX*2), DI
	
	CMPW AX, DI
	JE not_printable
	JL not_print16_go_left
	
	// go right
	LEAQ 1(BX), CX
	JMP not_print16_search
	
not_print16_go_left:
	MOVQ BX, DX
	JMP not_print16_search
	
is_printable:
	MOVB $1, ret+4(FP)
	RET

