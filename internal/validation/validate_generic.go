//go:build !amd64 && !arm64

package validation

// hasComplexCharsImpl is a pure scalar implementation for other architectures
func hasComplexCharsImpl(s string) bool {
	// Check for underscores
	for i := 0; i < len(s); i++ {
		if s[i] == '_' {
			return true
		}
	}
	return false
}

