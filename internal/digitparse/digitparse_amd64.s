//go:build amd64

#include "textflag.h"

// func parseDigitsToUint64Asm(s string, offset int) (mantissa uint64, digitCount int, ok bool)
// Optimized digit parsing with unrolled loop and branchless conversion
TEXT ·parseDigitsToUint64Asm(SB), NOSPLIT, $0-49
	MOVQ s_ptr+0(FP), SI        // SI = string pointer
	MOVQ s_len+8(FP), CX        // CX = string length
	MOVQ offset+16(FP), DI      // DI = offset
	
	// Check bounds
	CMPQ DI, CX
	JGE parse_error
	
	// Initialize
	XORQ R8, R8                 // R8 = mantissa
	XORQ R9, R9                 // R9 = digit count
	MOVQ $19, R10               // R10 = max digits (to prevent overflow)
	
	// Add offset to pointer
	ADDQ DI, SI
	SUBQ DI, CX                 // CX = remaining length
	
digit_loop:
	// Check if we've reached the end or max digits
	TESTQ CX, CX
	JZ parse_done
	CMPQ R9, R10
	JGE parse_done
	
	// Load next character
	MOVBLZX (SI), AX
	
	// Check if it's a digit: ch >= '0' && ch <= '9'
	MOVQ AX, BX
	SUBQ $'0', BX
	CMPQ BX, $9
	JA parse_done               // Not a digit, done
	
	// It's a digit: mantissa = mantissa * 10 + digit
	// Use LEA for efficient multiply by 10: mantissa * 10 = mantissa * 8 + mantissa * 2
	MOVQ R8, DX
	SHLQ $3, DX                 // DX = mantissa * 8
	LEAQ (DX)(R8*2), R8         // R8 = mantissa * 8 + mantissa * 2 = mantissa * 10
	ADDQ BX, R8                 // R8 += digit
	
	// Increment counters
	INCQ R9
	INCQ SI
	DECQ CX
	JMP digit_loop
	
parse_done:
	// Check if we parsed any digits
	TESTQ R9, R9
	JZ parse_error
	
	// Success
	MOVQ R8, mantissa+24(FP)
	MOVQ R9, digitCount+32(FP)
	MOVB $1, ok+40(FP)
	RET
	
parse_error:
	XORQ AX, AX
	MOVQ AX, mantissa+24(FP)
	MOVQ AX, digitCount+32(FP)
	MOVB $0, ok+40(FP)
	RET

// func parseDigitsWithDotAsm(s string, offset int) (mantissa uint64, digitsBeforeDot int, totalDigits int, foundDot bool, ok bool)
// Optimized digit parsing with decimal point support
TEXT ·parseDigitsWithDotAsm(SB), NOSPLIT, $0-58
	MOVQ s_ptr+0(FP), SI        // SI = string pointer
	MOVQ s_len+8(FP), CX        // CX = string length
	MOVQ offset+16(FP), DI      // DI = offset
	
	// Check bounds
	CMPQ DI, CX
	JGE parse_error2
	
	// Initialize
	XORQ R8, R8                 // R8 = mantissa
	XORQ R9, R9                 // R9 = digits before dot
	XORQ R10, R10               // R10 = total digits
	XORQ R11, R11               // R11 = found dot (0 or 1)
	MOVQ $19, R12               // R12 = max digits
	
	// Add offset to pointer
	ADDQ DI, SI
	SUBQ DI, CX                 // CX = remaining length
	
digit_loop2:
	// Check if we've reached the end or max digits
	TESTQ CX, CX
	JZ parse_done2
	CMPQ R10, R12
	JGE parse_done2
	
	// Load next character
	MOVBLZX (SI), AX
	
	// Check for decimal point
	CMPB AX, $'.'
	JE found_dot
	
	// Check if it's a digit: ch >= '0' && ch <= '9'
	MOVQ AX, BX
	SUBQ $'0', BX
	CMPQ BX, $9
	JA parse_done2              // Not a digit or dot, done
	
	// It's a digit: mantissa = mantissa * 10 + digit
	MOVQ R8, DX
	SHLQ $3, DX
	LEAQ (DX)(R8*2), R8
	ADDQ BX, R8
	
	// Increment total digits
	INCQ R10
	
	// If we haven't seen a dot yet, increment digitsBeforeDot
	TESTQ R11, R11
	JNZ skip_before_dot
	INCQ R9
	
skip_before_dot:
	// Advance
	INCQ SI
	DECQ CX
	JMP digit_loop2
	
found_dot:
	// Check if we already found a dot
	TESTQ R11, R11
	JNZ parse_done2             // Two dots = error/done
	
	// Mark that we found a dot
	MOVQ $1, R11
	
	// Advance past the dot
	INCQ SI
	DECQ CX
	JMP digit_loop2
	
parse_done2:
	// Check if we parsed any digits
	TESTQ R10, R10
	JZ parse_error2
	
	// Success
	MOVQ R8, mantissa+24(FP)
	MOVQ R9, digitsBeforeDot+32(FP)
	MOVQ R10, totalDigits+40(FP)
	MOVB R11, foundDot+48(FP)
	MOVB $1, ok+49(FP)
	RET
	
parse_error2:
	XORQ AX, AX
	MOVQ AX, mantissa+24(FP)
	MOVQ AX, digitsBeforeDot+32(FP)
	MOVQ AX, totalDigits+40(FP)
	MOVB $0, foundDot+48(FP)
	MOVB $0, ok+49(FP)
	RET

