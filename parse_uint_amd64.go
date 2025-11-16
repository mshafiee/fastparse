//go:build amd64

package fastparse

// parseUintFastAsm is the AMD64 assembly implementation of fast unsigned integer parsing.
// It parses simple unsigned integer patterns for base 10 and base 16.
// Returns (result, true) on success, (0, false) to fall back to generic implementation.
//
//go:noescape
func parseUintFastAsm(s string, base int, bitSize int) (result uint64, ok bool)

