//go:build arm64

package quoting

// hasASM indicates whether assembly implementation is available
const hasASM = true

//go:noescape
func needsEscapingASM(s string, quote byte, mode int) bool

// needsEscapingOptimized uses ARM NEON optimizations (no AVX-512 on ARM)
func needsEscapingOptimized(s string, quote byte, mode int) bool {
	return needsEscapingASM(s, quote, mode)
}

