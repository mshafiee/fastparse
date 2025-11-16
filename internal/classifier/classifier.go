package classifier

// Pattern represents the classification of a float string.
type Pattern uint8

const (
	// PatternSimple indicates a simple decimal float that can use the optimized fast path.
	// Format: [-+]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
	PatternSimple Pattern = iota
	
	// PatternComplex indicates a complex pattern requiring FSA parsing.
	// Includes: underscores, hex floats, special values, very long inputs, edge cases.
	PatternComplex
)

// Classify performs ultra-fast pattern detection on a float string.
// Returns PatternSimple if input matches: [-+]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
// Otherwise returns PatternComplex for FSA handling.
//
// This function is optimized for minimal overhead (2-3 ns target) and uses:
// - Bit flags instead of multiple booleans (cache-friendly)
// - Early returns on complexity markers
// - No allocations, pure stack operations
// - Goto for exponent parsing (eliminates function call overhead)
func ClassifyPureGo(s string) Pattern {
	n := len(s)
	
	// Length-based quick rejections
	if n == 0 || n > 24 {
		return PatternComplex
	}
	
	// Single-pass scan with bit flags
	i := 0
	flags := uint8(0)
	const (
		flagDot  = 1 << 0
		flagExp  = 1 << 1
		flagSign = 1 << 2
	)
	
	// Check first character (sign)
	ch := s[0]
	if ch == '-' || ch == '+' {
		flags |= flagSign
		i++
		if i >= n {
			return PatternComplex
		}
	}
	
	// Must have at least one digit
	if s[i] < '0' || s[i] > '9' {
		return PatternComplex
	}
	
	// Scan mantissa: digits and optional dot
	sawDigit := false
	for i < n {
		ch = s[i]
		
		switch {
		case ch >= '0' && ch <= '9':
			sawDigit = true
			i++
			
		case ch == '.':
			if (flags & flagDot) != 0 {
				return PatternComplex // Second dot
			}
			flags |= flagDot
			i++
			
		case ch == 'e' || ch == 'E':
			if !sawDigit || (flags & flagExp) != 0 {
				return PatternComplex
			}
			flags |= flagExp
			i++
			goto parseExponent
			
		case ch == '_':
			return PatternComplex // Underscore
			
		case ch == 'x' || ch == 'X':
			return PatternComplex // Hex
			
		case ch == 'i' || ch == 'I' || ch == 'n' || ch == 'N':
			return PatternComplex // inf/nan
			
		default:
			return PatternComplex // Invalid character
		}
	}
	
	return PatternSimple // Valid simple pattern
	
parseExponent:
	// Parse exponent: [+-]?[0-9]+
	if i >= n {
		return PatternComplex
	}
	
	ch = s[i]
	if ch == '+' || ch == '-' {
		i++
		if i >= n {
			return PatternComplex
		}
	}
	
	// Must have exponent digits
	if s[i] < '0' || s[i] > '9' {
		return PatternComplex
	}
	
	for i < n {
		ch = s[i]
		if ch >= '0' && ch <= '9' {
			i++
		} else {
			return PatternComplex // Invalid in exponent
		}
	}
	
	return PatternSimple
}

