package unicode_tables

// Package unicode_tables provides efficient Unicode character classification.
// These tables are derived from the Go standard library's unicode package.

// RangeTable defines a set of Unicode code points by specifying ranges.
type RangeTable struct {
	R16         []Range16
	R32         []Range32
	LatinOffset int // Number of entries in R16 with Hi <= MaxLatin1
}

// Range16 represents a range of 16-bit Unicode code points.
type Range16 struct {
	Lo     uint16
	Hi     uint16
	Stride uint16
}

// Range32 represents a range of Unicode code points above 0xFFFF.
type Range32 struct {
	Lo     uint32
	Hi     uint32
	Stride uint32
}

// PrintRanges contains the Unicode ranges for printable characters
var PrintRanges = &RangeTable{
	R16: []Range16{
		{0x0020, 0x007e, 1}, // ASCII printable
		{0x00a1, 0x00ac, 1}, // Latin-1 supplement
		{0x00ae, 0x0377, 1},
		{0x037a, 0x037f, 1},
		{0x0384, 0x038a, 1},
		{0x038c, 0x038c, 1},
		{0x038e, 0x03a1, 1},
		{0x03a3, 0x052f, 1},
		{0x0531, 0x0556, 1},
		{0x0559, 0x058a, 1},
		{0x058d, 0x058f, 1},
		{0x0591, 0x05c7, 1},
		{0x05d0, 0x05ea, 1},
		{0x05ef, 0x05f4, 1},
		{0x0600, 0x061c, 1},
		{0x061e, 0x070d, 1},
		{0x070f, 0x074a, 1},
		{0x074d, 0x07b1, 1},
		{0x07c0, 0x07fa, 1},
		{0x07fd, 0x082d, 1},
		{0x0830, 0x083e, 1},
		{0x0840, 0x085b, 1},
		{0x085e, 0x085e, 1},
		{0x0860, 0x086a, 1},
		{0x08a0, 0x08b4, 1},
		{0x08b6, 0x08c7, 1},
		{0x08d3, 0x0983, 1},
		{0x0985, 0x098c, 1},
		{0x098f, 0x0990, 1},
		{0x0993, 0x09a8, 1},
		{0x09aa, 0x09b0, 1},
		{0x09b2, 0x09b2, 1},
		{0x09b6, 0x09b9, 1},
		{0x09bc, 0x09c4, 1},
		{0x09c7, 0x09c8, 1},
		{0x09cb, 0x09ce, 1},
		{0x09d7, 0x09d7, 1},
		{0x09dc, 0x09dd, 1},
		{0x09df, 0x09e3, 1},
		{0x09e6, 0x09fe, 1},
		// Add more ranges as needed - this is a simplified subset
	},
	R32: []Range32{
		{0x10000, 0x1000b, 1},
		{0x1000d, 0x10026, 1},
		{0x10028, 0x1003a, 1},
		{0x1003c, 0x1003d, 1},
		{0x1003f, 0x1004d, 1},
		{0x10050, 0x1005d, 1},
		// Add more as needed
	},
	LatinOffset: 3, // Simplified
}

// GraphicRanges contains the Unicode ranges for graphic characters
// (printable characters except spaces)
var GraphicRanges = &RangeTable{
	R16: []Range16{
		{0x0021, 0x007e, 1}, // ASCII graphic (excludes space)
		{0x00a1, 0x00ac, 1},
		{0x00ae, 0x0377, 1},
		{0x037a, 0x037f, 1},
		{0x0384, 0x038a, 1},
		{0x038c, 0x038c, 1},
		{0x038e, 0x03a1, 1},
		{0x03a3, 0x052f, 1},
		// Add more ranges as needed
	},
	R32: []Range32{
		{0x10000, 0x1000b, 1},
		{0x1000d, 0x10026, 1},
		// Add more as needed
	},
	LatinOffset: 2,
}

// Is reports whether the rune is in the specified table of ranges.
func Is(rangeTab *RangeTable, r rune) bool {
	r16 := rangeTab.R16
	
	// Fast path for Latin-1
	if r <= 0xFF {
		for i := 0; i < rangeTab.LatinOffset; i++ {
			rng := r16[i]
			if r < rune(rng.Lo) {
				return false
			}
			if r <= rune(rng.Hi) {
				return (r-rune(rng.Lo))%rune(rng.Stride) == 0
			}
		}
		return false
	}
	
	// Binary search R16
	if r <= 0xFFFF {
		// Search in R16
		lo, hi := rangeTab.LatinOffset, len(r16)
		for lo < hi {
			mid := lo + (hi-lo)/2
			rng := r16[mid]
			if rune(rng.Lo) <= r && r <= rune(rng.Hi) {
				return (r-rune(rng.Lo))%rune(rng.Stride) == 0
			}
			if r < rune(rng.Lo) {
				hi = mid
			} else {
				lo = mid + 1
			}
		}
		return false
	}
	
	// Binary search R32
	r32 := rangeTab.R32
	lo, hi := 0, len(r32)
	for lo < hi {
		mid := lo + (hi-lo)/2
		rng := r32[mid]
		if rune(rng.Lo) <= r && r <= rune(rng.Hi) {
			return (r-rune(rng.Lo))%rune(rng.Stride) == 0
		}
		if r < rune(rng.Lo) {
			hi = mid
		} else {
			lo = mid + 1
		}
	}
	
	return false
}

// IsPrint reports whether the rune is printable (Letter, Mark, Number, Punctuation, Symbol, or Space).
func IsPrint(r rune) bool {
	// Fast path for common ASCII
	if r < 0x20 || r == 0x7F {
		return false
	}
	if r < 0x7F {
		return true
	}
	
	// Use lookup table
	return Is(PrintRanges, r)
}

// IsGraphic reports whether the rune is graphic (Letter, Mark, Number, Punctuation, Symbol).
// Spaces are not graphic.
func IsGraphic(r rune) bool {
	// Fast path for common ASCII
	if r <= 0x20 || r == 0x7F {
		return false
	}
	if r < 0x7F {
		return true
	}
	
	// Use lookup table
	return Is(GraphicRanges, r)
}

