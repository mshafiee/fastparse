//go:build amd64

package hexfloat

// parseHexMantissaAsm is the assembly implementation
//go:noescape
func parseHexMantissaAsm(s string, offset int, maxDigits int) (mantissa uint64, hexIntDigits int, hexFracDigits int, digitsParsed int, ok bool)

func parseHexMantissaImpl(s string, offset int, maxDigits int) (uint64, int, int, int, bool) {
	if offset >= len(s) || maxDigits <= 0 {
		return 0, 0, 0, 0, false
	}
	return parseHexMantissaAsm(s, offset, maxDigits)
}

