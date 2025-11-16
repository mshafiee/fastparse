//go:build amd64

#include "textflag.h"

// func classifyAmd64(s string) Pattern
// Ultra-fast pattern classifier for AMD64
// Returns PatternSimple (0) for simple patterns, PatternComplex (1) for complex patterns
TEXT ·classifyAmd64(SB), NOSPLIT, $0-24
	// Load string pointer and length
	MOVQ s_ptr+0(FP), SI    // SI = string pointer
	MOVQ s_len+8(FP), CX    // CX = length
	
	// Quick length check
	TESTQ CX, CX
	JZ complex_pattern       // Empty string
	CMPQ CX, $24
	JG complex_pattern       // Too long (>24 chars)
	
	// Initialize
	XORQ R12, R12            // R12 = flags (bit 0: dot, bit 1: exp)
	XORQ DI, DI              // DI = index
	
	// Check first character (optional sign)
	MOVBLZX (SI), AX
	CMPB AX, $'-'
	JE skip_sign
	CMPB AX, $'+'
	JE skip_sign
	JMP check_first_digit
	
skip_sign:
	INCQ DI
	CMPQ DI, CX
	JGE complex_pattern
	
check_first_digit:
	// Must start with digit after optional sign
	MOVBLZX (SI)(DI*1), AX
	SUBB $'0', AX
	CMPB AX, $9
	JA complex_pattern
	
	// Main scan loop - optimized for digit fast path
scan_loop:
	CMPQ DI, CX
	JGE simple_pattern
	
	MOVBLZX (SI)(DI*1), AX
	INCQ DI
	
	// Check digit (most common case - optimized path)
	SUBB $'0', AX
	CMPB AX, $9
	JBE scan_loop            // Fast path: it's a digit, continue
	ADDB $'0', AX            // Restore original character
	
	// Check for decimal point
	CMPB AX, $'.'
	JE handle_dot
	
	// Check for exponent markers
	CMPB AX, $'e'
	JE handle_exp
	CMPB AX, $'E'
	JE handle_exp
	
	// Check for complexity markers (underscore, hex, special)
	CMPB AX, $'_'
	JE complex_pattern
	CMPB AX, $'x'
	JE complex_pattern
	CMPB AX, $'X'
	JE complex_pattern
	CMPB AX, $'i'
	JE complex_pattern
	CMPB AX, $'I'
	JE complex_pattern
	CMPB AX, $'n'
	JE complex_pattern
	CMPB AX, $'N'
	JE complex_pattern
	
	// Any other character is invalid
	JMP complex_pattern
	
handle_dot:
	// Check if we already saw a dot (bit 0 of R12)
	TESTB $1, R12
	JNZ complex_pattern      // Second dot
	ORB $1, R12              // Set dot flag
	JMP scan_loop
	
handle_exp:
	// Check if we already saw an exponent (bit 1 of R12)
	TESTB $2, R12
	JNZ complex_pattern      // Second exponent
	ORB $2, R12              // Set exp flag
	
	// Parse exponent: [+-]?[0-9]+
	CMPQ DI, CX
	JGE complex_pattern      // No characters after 'e'
	
	MOVBLZX (SI)(DI*1), AX
	CMPB AX, $'+'
	JE skip_exp_sign
	CMPB AX, $'-'
	JNE check_exp_digit
	
skip_exp_sign:
	INCQ DI
	CMPQ DI, CX
	JGE complex_pattern
	
check_exp_digit:
	// Must have at least one exponent digit
	MOVBLZX (SI)(DI*1), AX
	SUBB $'0', AX
	CMPB AX, $9
	JA complex_pattern
	INCQ DI
	
exp_loop:
	// Continue parsing exponent digits
	CMPQ DI, CX
	JGE simple_pattern
	
	MOVBLZX (SI)(DI*1), AX
	SUBB $'0', AX
	CMPB AX, $9
	JA complex_pattern       // Non-digit in exponent
	INCQ DI
	JMP exp_loop
	
simple_pattern:
	// Return PatternSimple (0)
	MOVB $0, ret+16(FP)
	RET
	
complex_pattern:
	// Return PatternComplex (1)
	MOVB $1, ret+16(FP)
	RET

