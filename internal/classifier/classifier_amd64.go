//go:build amd64

package classifier

// Classify uses the AMD64 assembly-optimized classifier.
func Classify(s string) Pattern {
	return classifyAmd64(s)
}

// classifyAmd64 is implemented in classifier_amd64.s
func classifyAmd64(s string) Pattern

