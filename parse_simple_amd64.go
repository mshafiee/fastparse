//go:build amd64

package fastparse

// parseSimpleFastAsm is the AMD64 assembly implementation of parseSimpleFast.
// It parses simple decimal patterns: [-]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
// Returns (result, mantissa, exp, neg, true) on success.
// Returns (0, mantissa, exp, neg, false) if parsed but can't convert (for Eisel-Lemire fallback).
//
//go:noescape
func parseSimpleFastAsm(s string) (result float64, mantissa uint64, exp int, neg bool, ok bool)

// parseSimpleFast dispatches to the assembly implementation.
func parseSimpleFast(s string) (float64, uint64, int, bool, bool) {
	return parseSimpleFastAsm(s)
}

