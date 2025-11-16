//go:build arm64

#include "textflag.h"

// func parseDigitsToUint64Asm(s string, offset int) (mantissa uint64, digitCount int, ok bool)
// Optimized digit parsing for ARM64
TEXT ·parseDigitsToUint64Asm(SB), NOSPLIT, $0-49
	MOVD s_ptr+0(FP), R0        // R0 = string pointer
	MOVD s_len+8(FP), R1        // R1 = string length
	MOVD offset+16(FP), R2      // R2 = offset
	
	// Check bounds
	CMP R1, R2
	BGE parse_error
	
	// Initialize
	MOVD $0, R3                 // R3 = mantissa
	MOVD $0, R4                 // R4 = digit count
	MOVD $19, R5                // R5 = max digits
	
	// Calculate pointer and remaining length
	ADD R2, R0, R0              // R0 = ptr + offset
	SUB R2, R1, R1              // R1 = remaining length
	
digit_loop:
	// Check if we've reached the end or max digits
	CBZ R1, parse_done
	CMP R5, R4
	BGE parse_done
	
	// Load next character
	MOVBU (R0), R6
	
	// Check if it's a digit: ch >= '0' && ch <= '9'
	SUB $'0', R6, R7
	CMP $9, R7
	BHI parse_done              // Not a digit, done
	
	// It's a digit: mantissa = mantissa * 10 + digit
	// Use shifts and adds for multiply by 10
	MOVD R3, R8
	LSL $3, R8, R8              // R8 = mantissa * 8
	ADD R3, R8, R8              // R8 = mantissa * 8 + mantissa
	ADD R3, R8, R8              // R8 = mantissa * 10
	ADD R7, R8, R3              // R3 = mantissa * 10 + digit
	
	// Increment counters
	ADD $1, R4, R4
	ADD $1, R0, R0
	SUB $1, R1, R1
	B digit_loop
	
parse_done:
	// Check if we parsed any digits
	CBZ R4, parse_error
	
	// Success
	MOVD R3, mantissa+24(FP)
	MOVD R4, digitCount+32(FP)
	MOVD $1, R7
	MOVB R7, ok+40(FP)
	RET
	
parse_error:
	MOVD $0, R7
	MOVD R7, mantissa+24(FP)
	MOVD R7, digitCount+32(FP)
	MOVB R7, ok+40(FP)
	RET

// func parseDigitsWithDotAsm(s string, offset int) (mantissa uint64, digitsBeforeDot int, totalDigits int, foundDot bool, ok bool)
// Optimized digit parsing with decimal point support for ARM64
TEXT ·parseDigitsWithDotAsm(SB), NOSPLIT, $0-58
	MOVD s_ptr+0(FP), R0        // R0 = string pointer
	MOVD s_len+8(FP), R1        // R1 = string length
	MOVD offset+16(FP), R2      // R2 = offset
	
	// Check bounds
	CMP R1, R2
	BGE parse_error2
	
	// Initialize
	MOVD $0, R3                 // R3 = mantissa
	MOVD $0, R4                 // R4 = digits before dot
	MOVD $0, R5                 // R5 = total digits
	MOVD $0, R6                 // R6 = found dot (0 or 1)
	MOVD $19, R7                // R7 = max digits
	
	// Calculate pointer and remaining length
	ADD R2, R0, R0              // R0 = ptr + offset
	SUB R2, R1, R1              // R1 = remaining length
	
digit_loop2:
	// Check if we've reached the end or max digits
	CBZ R1, parse_done2
	CMP R7, R5
	BGE parse_done2
	
	// Load next character
	MOVBU (R0), R8
	
	// Check for decimal point
	CMP $'.', R8
	BEQ found_dot
	
	// Check if it's a digit: ch >= '0' && ch <= '9'
	SUB $'0', R8, R9
	CMP $9, R9
	BHI parse_done2             // Not a digit or dot, done
	
	// It's a digit: mantissa = mantissa * 10 + digit
	MOVD R3, R10
	LSL $3, R10, R10            // R10 = mantissa * 8
	ADD R3, R10, R10            // R10 = mantissa * 9
	ADD R3, R10, R10            // R10 = mantissa * 10
	ADD R9, R10, R3             // R3 = mantissa * 10 + digit
	
	// Increment total digits
	ADD $1, R5, R5
	
	// If we haven't seen a dot yet, increment digitsBeforeDot
	CBNZ R6, skip_before_dot
	ADD $1, R4, R4
	
skip_before_dot:
	// Advance
	ADD $1, R0, R0
	SUB $1, R1, R1
	B digit_loop2
	
found_dot:
	// Check if we already found a dot
	CBNZ R6, parse_done2        // Two dots = error/done
	
	// Mark that we found a dot
	MOVD $1, R6
	
	// Advance past the dot
	ADD $1, R0, R0
	SUB $1, R1, R1
	B digit_loop2
	
parse_done2:
	// Check if we parsed any digits
	CBZ R5, parse_error2
	
	// Success
	MOVD R3, mantissa+24(FP)
	MOVD R4, digitsBeforeDot+32(FP)
	MOVD R5, totalDigits+40(FP)
	MOVB R6, foundDot+48(FP)
	MOVD $1, R10
	MOVB R10, ok+49(FP)
	RET
	
parse_error2:
	MOVD $0, R10
	MOVD R10, mantissa+24(FP)
	MOVD R10, digitsBeforeDot+32(FP)
	MOVD R10, totalDigits+40(FP)
	MOVB R10, foundDot+48(FP)
	MOVB R10, ok+49(FP)
	RET

