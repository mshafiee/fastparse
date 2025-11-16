//go:build arm64

#include "textflag.h"

// func classifyArm64(s string) Pattern
// Ultra-fast pattern classifier for ARM64
// Returns PatternSimple (0) for simple patterns, PatternComplex (1) for complex patterns
TEXT ·classifyArm64(SB), NOSPLIT, $0-24
	// Load string pointer and length
	MOVD s_ptr+0(FP), R0     // R0 = string pointer
	MOVD s_len+8(FP), R1     // R1 = length
	
	// Quick length check
	CBZ R1, complex_pattern   // Empty string
	CMP $24, R1
	BGT complex_pattern       // Too long (>24 chars)
	
	// Initialize
	MOVD $0, R2              // R2 = index
	MOVD $0, R3              // R3 = flags (bit 0: dot, bit 1: exp)
	
	// Check first character (optional sign)
	MOVBU (R0), R4
	CMP $'-', R4
	BEQ skip_sign
	CMP $'+', R4
	BNE check_first_digit
	
skip_sign:
	ADD $1, R2
	CMP R1, R2
	BHS complex_pattern
	
check_first_digit:
	// Must start with digit after optional sign
	ADD R0, R2, R5
	MOVBU (R5), R4
	SUB $'0', R4
	CMP $9, R4
	BHI complex_pattern
	
	// Main scan loop - optimized for digit fast path
scan_loop:
	CMP R1, R2
	BHS simple_pattern
	
	ADD R0, R2, R5
	MOVBU (R5), R4
	ADD $1, R2
	
	// Check digit (most common case - optimized path)
	SUB $'0', R4, R6
	CMP $9, R6
	BLS scan_loop            // Fast path: it's a digit, continue
	
	// Check for decimal point
	CMP $'.', R4
	BEQ handle_dot
	
	// Check for exponent markers
	CMP $'e', R4
	BEQ handle_exp
	CMP $'E', R4
	BEQ handle_exp
	
	// Check for complexity markers (underscore, hex, special)
	CMP $'_', R4
	BEQ complex_pattern
	CMP $'x', R4
	BEQ complex_pattern
	CMP $'X', R4
	BEQ complex_pattern
	CMP $'i', R4
	BEQ complex_pattern
	CMP $'I', R4
	BEQ complex_pattern
	CMP $'n', R4
	BEQ complex_pattern
	CMP $'N', R4
	BEQ complex_pattern
	
	// Any other character is invalid
	B complex_pattern
	
handle_dot:
	// Check if we already saw a dot (bit 0 of R3)
	TST $1, R3
	BNE complex_pattern      // Second dot
	ORR $1, R3, R3           // Set dot flag
	B scan_loop
	
handle_exp:
	// Check if we already saw an exponent (bit 1 of R3)
	TST $2, R3
	BNE complex_pattern      // Second exponent
	ORR $2, R3, R3           // Set exp flag
	
	// Parse exponent: [+-]?[0-9]+
	CMP R1, R2
	BHS complex_pattern      // No characters after 'e'
	
	ADD R0, R2, R5
	MOVBU (R5), R4
	CMP $'+', R4
	BEQ skip_exp_sign
	CMP $'-', R4
	BNE check_exp_digit
	
skip_exp_sign:
	ADD $1, R2
	CMP R1, R2
	BHS complex_pattern
	
check_exp_digit:
	// Must have at least one exponent digit
	ADD R0, R2, R5
	MOVBU (R5), R4
	SUB $'0', R4
	CMP $9, R4
	BHI complex_pattern
	ADD $1, R2
	
exp_loop:
	// Continue parsing exponent digits
	CMP R1, R2
	BHS simple_pattern
	
	ADD R0, R2, R5
	MOVBU (R5), R4
	SUB $'0', R4
	CMP $9, R4
	BHI complex_pattern      // Non-digit in exponent
	ADD $1, R2
	B exp_loop
	
simple_pattern:
	// Return PatternSimple (0)
	MOVD $0, R0
	MOVB R0, ret+16(FP)
	RET
	
complex_pattern:
	// Return PatternComplex (1)
	MOVD $1, R0
	MOVB R0, ret+16(FP)
	RET

