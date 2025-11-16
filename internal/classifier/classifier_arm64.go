//go:build arm64

package classifier

// Classify uses the ARM64 assembly-optimized classifier.
func Classify(s string) Pattern {
	return classifyArm64(s)
}

// classifyArm64 is implemented in classifier_arm64.s
func classifyArm64(s string) Pattern

