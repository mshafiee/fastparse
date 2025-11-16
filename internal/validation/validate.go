package validation

// HasComplexChars quickly checks if string contains characters that require full FSA
// Returns true if has: underscores, hex prefix (0x), or special values (inf/nan)
// This function dispatches to architecture-specific SIMD implementations when available
func HasComplexChars(s string) bool {
	if len(s) == 0 {
		return false
	}
	
	// Check first character for special values (done in all implementations)
	switch s[0] {
	case 'i', 'I', 'n', 'N':
		return true // Could be inf/nan
	case '0':
		// Check for hex prefix
		if len(s) > 1 && (s[1] == 'x' || s[1] == 'X') {
			return true
		}
	}
	
	// Use architecture-specific SIMD scan for underscores
	return hasComplexCharsImpl(s)
}

