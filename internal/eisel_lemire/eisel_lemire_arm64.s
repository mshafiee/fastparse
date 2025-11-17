// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func tryParseAsm(mantissa uint64, exp10 int, tablePtrHigh *uint64, tablePtrLow *uint64) (result float64, ok bool)
// Optimized Eisel-Lemire algorithm using ARM64 UMULH instruction with wider approximation
TEXT ·tryParseAsm(SB), NOSPLIT, $0-41
	// Load arguments
	MOVD mantissa+0(FP), R0     // R0 = mantissa
	MOVD exp10+8(FP), R1        // R1 = exp10 (int)
	MOVD tablePtrHigh+16(FP), R2    // R2 = pow10TableHigh pointer
	MOVD tablePtrLow+24(FP), R3     // R3 = pow10TableLow pointer
	
	// Check for zero mantissa
	CBZ R0, return_zero
	
	// Check exponent range: exp10 < -348 || exp10 > 308
	MOVD $-348, R4
	CMP R4, R1
	BLT return_false
	MOVD $308, R4
	CMP R4, R1
	BGT return_false
	
	// Normalize mantissa: count leading zeros and shift
	CLZ R0, R4                  // R4 = clz
	LSL R4, R0, R5              // R5 = mantissa << clz (normalized mantissa)
	
	// Calculate biased exponent: (217706*exp10>>16) + 64 + 1023 - clz
	// Need signed multiplication since exp10 can be negative
	MOVD $217706, R6
	MUL R1, R6, R6              // R6 = 217706 * exp10 (treating as signed)
	ASR $16, R6, R6             // R6 = (217706 * exp10) >> 16 (arithmetic shift for sign extension)
	ADD $64, R6, R6             // R6 += 64
	MOVD $1023, R7
	ADD R7, R6, R6              // R6 += 1023
	SUB R4, R6, R7              // R7 = retExp2 = result - clz
	
	// Calculate table index: idx = exp10 + 348
	ADD $348, R1, R8            // R8 = idx
	LSL $3, R8, R9              // R9 = idx * 8 (byte offset)
	
	// Load pow10TableHigh[idx]
	ADD R2, R9, R10             // R10 = address of pow10TableHigh[idx]
	MOVD (R10), R10             // R10 = pow10TableHigh[idx]
	
	// 128-bit multiplication using MUL (low) and UMULH (high)
	MUL R5, R10, R11            // R11 = xLo (low 64 bits)
	UMULH R5, R10, R12          // R12 = xHi (high 64 bits)
	
	// Wider Approximation: check if xHi & 0x1FF == 0x1FF && xLo + mantissa < mantissa
	MOVD R12, R13
	AND $0x1FF, R13             // R13 = xHi & 0x1FF
	CMP $0x1FF, R13
	BNE skip_wider_approx
	
	// Check if xLo + mantissa < mantissa (unsigned overflow)
	ADDS R5, R11, R14           // R14 = xLo + mantissa
	BCC skip_wider_approx       // If NO carry, no overflow (xLo + mantissa >= mantissa), skip
	
	// Wider approximation needed - multiply by low table
	ADD R3, R9, R15             // R15 = address of pow10TableLow[idx]
	MOVD (R15), R15             // R15 = pow10TableLow[idx]
	
	MUL R5, R15, R16            // R16 = yLo
	UMULH R5, R15, R17          // R17 = yHi
	
	// Merge: mergedLo = xLo + yHi, mergedHi = xHi
	MOVD R12, R20               // R20 = mergedHi = xHi
	ADDS R17, R11, R21          // R21 = mergedLo = xLo + yHi
	ADC $0, R20, R20            // mergedHi++ if carry
	
	// Check if still ambiguous
	MOVD R20, R22
	AND $0x1FF, R22
	CMP $0x1FF, R22
	BNE use_merged
	
	ADDS $1, R21, R19
	CBNZ R19, use_merged
	
	ADDS R5, R16, R19
	BCS use_merged
	
	// Still ambiguous - fall back
	B return_false
	
use_merged:
	MOVD R20, R12               // xHi = mergedHi
	MOVD R21, R11               // xLo = mergedLo
	
skip_wider_approx:
	// Extract MSB of xHi: msb = xHi >> 63
	LSR $63, R12, R13           // R13 = msb (0 or 1)
	
	// Calculate shift amount: msb + 9
	ADD $9, R13, R14            // R14 = msb + 9
	
	// retMantissa = xHi >> (msb + 9)
	LSR R14, R12, R14           // R14 = retMantissa
	
	// retExp2 -= 1 ^ msb
	MOVD $1, R15
	EOR R13, R15, R15           // R15 = 1 ^ msb
	SUB R15, R7, R7             // R7 = retExp2 (updated)
	
	// Check for half-way ambiguity: xLo == 0 && xHi&0x1FF == 0 && retMantissa&3 == 1
	CBNZ R11, skip_ambiguity    // if xLo != 0, skip
	
	AND $0x1FF, R12, R15        // R15 = xHi & 0x1FF
	CBNZ R15, skip_ambiguity    // if (xHi & 0x1FF) != 0, skip
	
	AND $3, R14, R15            // R15 = retMantissa & 3
	CMP $1, R15
	BEQ return_false            // Ambiguous case - fall back
	
skip_ambiguity:
	// Round from 54 to 53 bits: retMantissa += retMantissa & 1
	AND $1, R14, R15
	ADD R15, R14, R14           // R14 = retMantissa (with rounding bit)
	
	// retMantissa >>= 1
	LSR $1, R14, R14
	
	// Check if mantissa overflowed to 54 bits: if retMantissa >> 53 > 0
	LSR $53, R14, R15
	CBZ R15, no_overflow
	
	// Overflow: retMantissa >>= 1, retExp2 += 1
	LSR $1, R14, R14
	ADD $1, R7, R7
	
no_overflow:
	// Check for exponent overflow/underflow: retExp2-1 >= 0x7FF-1
	SUB $1, R7, R15             // R15 = retExp2 - 1
	MOVD $0x7FE, R16
	CMP R16, R15
	BHS return_false            // Unsigned compare (>=): handles both overflow and underflow
	
	// Construct IEEE 754 float64: retExp2<<52 | (retMantissa & 0x000FFFFFFFFFFFFF)
	LSL $52, R7, R15            // R15 = retExp2 << 52
	
	MOVD $0x000FFFFFFFFFFFFF, R16
	AND R16, R14, R14           // R14 = retMantissa & 0x000FFFFFFFFFFFFF
	
	ORR R14, R15, R15           // R15 = retExp2<<52 | retMantissa
	
	// Store result
	MOVD R15, result+32(FP)
	MOVD $1, R15
	MOVB R15, ok+40(FP)
	RET
	
return_zero:
	// Return (0.0, true)
	MOVD $0, R15
	MOVD R15, result+32(FP)
	MOVD $1, R15
	MOVB R15, ok+40(FP)
	RET
	
return_false:
	// Return (0, false)
	MOVD $0, R15
	MOVD R15, result+32(FP)
	MOVB R15, ok+40(FP)
	RET

