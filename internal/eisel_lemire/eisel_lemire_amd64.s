//go:build amd64

#include "textflag.h"

// func tryParseAsm(mantissa uint64, exp10 int, tablePtrHigh *uint64, tablePtrLow *uint64) (result float64, ok bool)
// Optimized Eisel-Lemire algorithm with wider approximation using native 128-bit multiplication
TEXT ·tryParseAsm(SB), NOSPLIT, $0-49
	// Load arguments
	MOVQ mantissa+0(FP), AX     // AX = mantissa
	MOVQ exp10+8(FP), CX        // CX = exp10 (int)
	MOVQ tablePtrHigh+16(FP), R15   // R15 = pow10TableHigh pointer
	MOVQ tablePtrLow+24(FP), R14    // R14 = pow10TableLow pointer
	
	// Check for zero mantissa
	TESTQ AX, AX
	JZ return_zero
	
	// Check exponent range: exp10 < minTableExp (-348) || exp10 > maxTableExp (308)
	CMPQ CX, $-348
	JL return_false
	CMPQ CX, $308
	JG return_false
	
	// Normalize mantissa: count leading zeros and shift
	// Use LZCNT if available, otherwise BSR
	MOVQ AX, BX                 // BX = mantissa (preserve for later)
	
	// Count leading zeros using LZCNT (supported on most modern CPUs)
	BYTE $0xF3; BYTE $0x48; BYTE $0x0F; BYTE $0xBD; BYTE $0xD0  // LZCNTQ AX, DX
	MOVQ DX, R8                 // R8 = clz
	
	// Shift mantissa left by clz
	MOVQ DX, CX                 // CX = shift count
	SHLQ CX, BX                 // BX = mantissa << clz
	
	// Restore exp10 to CX
	MOVQ exp10+8(FP), CX        // CX = exp10
	
	// Calculate biased exponent: (217706*exp10>>16) + 64 + 1023 - clz
	MOVQ CX, AX                 // AX = exp10
	IMULQ $217706, AX           // AX = 217706 * exp10
	SHRQ $16, AX                // AX = (217706 * exp10) >> 16
	ADDQ $64, AX                // AX += 64
	ADDQ $1023, AX              // AX += 1023 (float64ExponentBias)
	SUBQ R8, AX                 // AX -= clz
	MOVQ AX, R9                 // R9 = retExp2
	
	// Calculate table index: idx = exp10 - minTableExp = exp10 - (-348) = exp10 + 348
	MOVQ exp10+8(FP), CX        // CX = exp10
	ADDQ $348, CX               // CX = idx
	MOVQ CX, DI                 // DI = idx (save for later)
	
	// Load pow10TableHigh[idx]
	MOVQ (R15)(CX*8), R10       // R10 = pow10TableHigh[idx]
	
	// 128-bit multiplication: (xHi, xLo) = mantissa * pow10TableHigh[idx]
	// MULQ computes RDX:RAX = RAX * operand
	MOVQ BX, AX                 // AX = mantissa (normalized)
	MOVQ BX, SI                 // SI = mantissa (save for wider approx check)
	MULQ R10                    // RDX:RAX = mantissa * pow10TableHigh[idx]
	// RAX = xLo, RDX = xHi
	MOVQ RAX, R11               // R11 = xLo
	MOVQ RDX, R12               // R12 = xHi
	
	// Wider Approximation: check if xHi & 0x1FF == 0x1FF && xLo + mantissa < mantissa
	MOVQ R12, AX
	ANDQ $0x1FF, AX
	CMPQ AX, $0x1FF
	JNE skip_wider_approx
	
	// Check if xLo + mantissa < mantissa (unsigned overflow check)
	MOVQ R11, AX
	ADDQ SI, AX                 // AX = xLo + mantissa
	JC skip_wider_approx        // If carry, sum >= mantissa, no overflow
	
	// Wider approximation needed - multiply by low table
	MOVQ (R14)(DI*8), R10       // R10 = pow10TableLow[idx]
	
	MOVQ SI, AX                 // AX = mantissa
	MULQ R10                    // RDX:RAX = mantissa * pow10TableLow[idx]
	// RAX = yLo, RDX = yHi
	MOVQ RAX, R13               // R13 = yLo (save for second ambiguity check)
	
	// Merge: mergedLo = xLo + yHi, mergedHi = xHi (with carry)
	ADDQ RDX, R11               // R11 = mergedLo = xLo + yHi
	JNC no_merge_carry
	INCQ R12                    // mergedHi++ if carry
no_merge_carry:
	
	// Check if still ambiguous: mergedHi&0x1FF == 0x1FF && mergedLo+1 == 0 && yLo+mantissa < mantissa
	MOVQ R12, AX
	ANDQ $0x1FF, AX
	CMPQ AX, $0x1FF
	JNE skip_wider_approx       // Not near boundary anymore
	
	MOVQ R11, AX
	INCQ AX                     // mergedLo + 1
	JNZ skip_wider_approx       // If not zero, not ambiguous
	
	MOVQ R13, AX
	ADDQ SI, AX                 // yLo + mantissa
	JC skip_wider_approx        // If carry, no overflow
	
	// Still ambiguous - fall back
	JMP return_false
	
skip_wider_approx:
	
	// Extract MSB of xHi: msb = xHi >> 63
	MOVQ R12, R13
	SHRQ $63, R13               // R13 = msb (0 or 1)
	
	// Calculate shift amount: msb + 9
	MOVQ R13, CX
	ADDQ $9, CX                 // CX = msb + 9
	
	// retMantissa = xHi >> (msb + 9)
	MOVQ R12, R14
	SHRQ CX, R14                // R14 = retMantissa
	
	// retExp2 -= 1 ^ msb  (equivalent to: if msb == 0 then retExp2 -= 1)
	MOVQ $1, AX
	XORQ R13, AX                // AX = 1 ^ msb
	SUBQ AX, R9                 // R9 = retExp2 (updated)
	
	// Check for half-way ambiguity: xLo == 0 && xHi&0x1FF == 0 && retMantissa&3 == 1
	TESTQ R11, R11              // xLo == 0?
	JNZ skip_ambiguity
	
	MOVQ R12, AX
	ANDQ $0x1FF, AX             // xHi & 0x1FF
	JNZ skip_ambiguity
	
	MOVQ R14, AX
	ANDQ $3, AX                 // retMantissa & 3
	CMPQ AX, $1
	JE return_false             // Ambiguous case - fall back
	
skip_ambiguity:
	// Round from 54 to 53 bits: retMantissa += retMantissa & 1
	MOVQ R14, AX
	ANDQ $1, AX
	ADDQ AX, R14                // R14 = retMantissa (with rounding bit added)
	
	// retMantissa >>= 1
	SHRQ $1, R14
	
	// Check if mantissa overflowed to 54 bits: if retMantissa >> 53 > 0
	MOVQ R14, AX
	SHRQ $53, AX
	TESTQ AX, AX
	JZ no_overflow
	
	// Overflow: retMantissa >>= 1, retExp2 += 1
	SHRQ $1, R14
	INCQ R9
	
no_overflow:
	// Check for exponent overflow/underflow: retExp2-1 >= 0x7FF-1
	MOVQ R9, AX
	DECQ AX                     // AX = retExp2 - 1
	CMPQ AX, $0x7FE             // Compare with 0x7FF - 1
	JA return_false             // Unsigned compare: handles both overflow and underflow
	
	// Construct IEEE 754 float64: retExp2<<52 | (retMantissa & 0x000FFFFFFFFFFFFF)
	MOVQ R9, AX
	SHLQ $52, AX                // AX = retExp2 << 52
	
	MOVQ R14, BX
	MOVQ $0x000FFFFFFFFFFFFF, CX
	ANDQ CX, BX                 // BX = retMantissa & 0x000FFFFFFFFFFFFF
	
	ORQ BX, AX                  // AX = retExp2<<52 | retMantissa
	
	// Store result
	MOVQ AX, result+32(FP)
	MOVB $1, ok+40(FP)
	RET
	
return_zero:
	// Return (0.0, true)
	XORQ AX, AX
	MOVQ AX, result+32(FP)
	MOVB $1, ok+40(FP)
	RET
	
return_false:
	// Return (0, false)
	XORQ AX, AX
	MOVQ AX, result+32(FP)
	MOVB $0, ok+40(FP)
	RET

