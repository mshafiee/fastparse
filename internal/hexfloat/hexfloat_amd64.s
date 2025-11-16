//go:build amd64

#include "textflag.h"

// func parseHexMantissaAsm(s string, offset int, maxDigits int) (mantissa uint64, hexIntDigits int, hexFracDigits int, digitsParsed int, ok bool)
// Optimized hex digit parsing with branchless conversion
TEXT ·parseHexMantissaAsm(SB), NOSPLIT, $0-65
	MOVQ s_ptr+0(FP), SI        // SI = string pointer
	MOVQ s_len+8(FP), CX        // CX = string length
	MOVQ offset+16(FP), DI      // DI = offset
	MOVQ maxDigits+24(FP), R15  // R15 = maxDigits
	
	// Check bounds
	CMPQ DI, CX
	JGE parse_error_hex
	TESTQ R15, R15
	JLE parse_error_hex
	
	// Initialize
	XORQ R8, R8                 // R8 = mantissa
	XORQ R9, R9                 // R9 = hexIntDigits
	XORQ R10, R10               // R10 = hexFracDigits
	XORQ R11, R11               // R11 = digitsParsed
	XORQ R12, R12               // R12 = saw dot (0 or 1)
	
	// Add offset to pointer
	ADDQ DI, SI
	SUBQ DI, CX                 // CX = remaining length
	
hex_loop:
	// Check if we've reached the end or max digits
	TESTQ CX, CX
	JZ parse_done_hex
	CMPQ R11, R15
	JGE parse_done_hex
	
	// Load next character
	MOVBLZX (SI), AX
	
	// Check for decimal point
	CMPB AX, $'.'
	JE found_dot_hex
	
	// Convert hex character to value (branchless)
	// If '0'-'9': digit = ch - '0'
	// If 'a'-'f': digit = ch - 'a' + 10
	// If 'A'-'F': digit = ch - 'A' + 10
	
	MOVQ AX, BX
	SUBQ $'0', BX
	CMPQ BX, $9
	JBE is_digit_hex            // '0'-'9'
	
	MOVQ AX, BX
	SUBQ $'a', BX
	CMPQ BX, $5
	JBE is_lower_hex            // 'a'-'f'
	
	MOVQ AX, BX
	SUBQ $'A', BX
	CMPQ BX, $5
	JBE is_upper_hex            // 'A'-'F'
	
	// Not a hex digit, done
	JMP parse_done_hex
	
is_digit_hex:
	MOVQ AX, BX
	SUBQ $'0', BX
	JMP accumulate_hex
	
is_lower_hex:
	MOVQ AX, BX
	SUBQ $'a', BX
	ADDQ $10, BX
	JMP accumulate_hex
	
is_upper_hex:
	MOVQ AX, BX
	SUBQ $'A', BX
	ADDQ $10, BX
	
accumulate_hex:
	// mantissa = mantissa * 16 + digit
	SHLQ $4, R8
	ADDQ BX, R8
	
	// Increment digit counters
	INCQ R11                    // digitsParsed++
	
	// If we've seen a dot, increment hexFracDigits, else hexIntDigits
	TESTQ R12, R12
	JNZ inc_frac_hex
	INCQ R9                     // hexIntDigits++
	JMP next_hex
	
inc_frac_hex:
	INCQ R10                    // hexFracDigits++
	
next_hex:
	// Advance
	INCQ SI
	DECQ CX
	JMP hex_loop
	
found_dot_hex:
	// Check if we already found a dot
	TESTQ R12, R12
	JNZ parse_done_hex          // Two dots = done
	
	// Mark that we found a dot
	MOVQ $1, R12
	
	// Advance past the dot (but don't count it as a digit)
	INCQ SI
	DECQ CX
	JMP hex_loop
	
parse_done_hex:
	// Check if we parsed any digits
	TESTQ R11, R11
	JZ parse_error_hex
	
	// Success
	MOVQ R8, mantissa+32(FP)
	MOVQ R9, hexIntDigits+40(FP)
	MOVQ R10, hexFracDigits+48(FP)
	MOVQ R11, digitsParsed+56(FP)
	MOVB $1, ok+64(FP)
	RET
	
parse_error_hex:
	XORQ AX, AX
	MOVQ AX, mantissa+32(FP)
	MOVQ AX, hexIntDigits+40(FP)
	MOVQ AX, hexFracDigits+48(FP)
	MOVQ AX, digitsParsed+56(FP)
	MOVB $0, ok+64(FP)
	RET

