//go:build amd64

package fastparse

// parseLongDecimalFastAsm is the AMD64 assembly implementation of parseLongDecimalFast.
// It handles long decimals (20-100 digits): [-]?[0-9]+\.?[0-9]*
// Returns (result, true) on success, (0, false) to fall back to pure Go.
//
//go:noescape
func parseLongDecimalFastAsm(s string) (result float64, ok bool)

// ParseLongDecimalFast dispatches to the assembly implementation.
func parseLongDecimalFast(s string) (float64, bool) {
	return parseLongDecimalFastAsm(s)
}
