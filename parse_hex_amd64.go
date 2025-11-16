//go:build amd64

package fastparse

// parseHexFastAsm is the AMD64 assembly implementation of parseHexFast.
// It parses hex floats: [-]?0[xX][0-9a-fA-F]+\.?[0-9a-fA-F]*[pP][-+]?[0-9]+
// Returns (result, true) on success, (0, false) to fall back to pure Go.
//
//go:noescape
func parseHexFastAsm(s string) (result float64, ok bool)

// ParseHexFast dispatches to the assembly implementation.
func parseHexFast(s string) (float64, bool) {
	return parseHexFastAsm(s)
}

