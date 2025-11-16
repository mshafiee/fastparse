//go:build !amd64 && !arm64

package classifier

// Classify uses the pure Go classifier implementation for non-optimized architectures.
func Classify(s string) Pattern {
	return ClassifyPureGo(s)
}

