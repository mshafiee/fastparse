package quoting

import (
	"unicode/utf8"
)

// Quote modes
const (
	ModeGraphic = iota // Use IsGraphic for non-ASCII
	ModeASCII          // Escape all non-ASCII
	ModePrint          // Use IsPrint for non-ASCII (default)
)

// Quote returns a double-quoted Go string literal representing s.
// It uses Go escape sequences for control characters and non-printable characters.
func Quote(s string, mode int) string {
	return quoteWith(s, '"', mode)
}

// QuoteToASCII returns a double-quoted Go string literal representing s.
// It uses Go escape sequences for non-ASCII and non-printable characters.
func QuoteToASCII(s string) string {
	return quoteWith(s, '"', ModeASCII)
}

// QuoteToGraphic returns a double-quoted Go string literal representing s.
// It uses Go escape sequences for non-graphic characters.
func QuoteToGraphic(s string) string {
	return quoteWith(s, '"', ModeGraphic)
}

// AppendQuote appends a double-quoted Go string literal to dst.
func AppendQuote(dst []byte, s string, mode int) []byte {
	return appendQuotedWith(dst, s, '"', mode)
}

// AppendQuoteToASCII appends a double-quoted Go string literal to dst,
// escaping all non-ASCII characters.
func AppendQuoteToASCII(dst []byte, s string) []byte {
	return appendQuotedWith(dst, s, '"', ModeASCII)
}

// AppendQuoteToGraphic appends a double-quoted Go string literal to dst,
// escaping all non-graphic characters.
func AppendQuoteToGraphic(dst []byte, s string) []byte {
	return appendQuotedWith(dst, s, '"', ModeGraphic)
}

// QuoteRune returns a single-quoted Go character literal representing the rune.
func QuoteRune(r rune, mode int) string {
	return quoteRuneWith(r, '\'', mode)
}

// QuoteRuneToASCII returns a single-quoted Go character literal,
// escaping non-ASCII characters.
func QuoteRuneToASCII(r rune) string {
	return quoteRuneWith(r, '\'', ModeASCII)
}

// QuoteRuneToGraphic returns a single-quoted Go character literal,
// escaping non-graphic characters.
func QuoteRuneToGraphic(r rune) string {
	return quoteRuneWith(r, '\'', ModeGraphic)
}

// AppendQuoteRune appends a single-quoted Go character literal to dst.
func AppendQuoteRune(dst []byte, r rune, mode int) []byte {
	return appendQuotedRuneWith(dst, r, '\'', mode)
}

// AppendQuoteRuneToASCII appends a single-quoted Go character literal to dst,
// escaping non-ASCII characters.
func AppendQuoteRuneToASCII(dst []byte, r rune) []byte {
	return appendQuotedRuneWith(dst, r, '\'', ModeASCII)
}

// AppendQuoteRuneToGraphic appends a single-quoted Go character literal to dst,
// escaping non-graphic characters.
func AppendQuoteRuneToGraphic(dst []byte, r rune) []byte {
	return appendQuotedRuneWith(dst, r, '\'', ModeGraphic)
}

// quoteWith returns a quoted string using the specified quote character and mode.
func quoteWith(s string, quote byte, mode int) string {
	// Fast path: check if string needs escaping using SIMD where available
	if needsEscaping := checkNeedsEscaping(s, quote, mode); !needsEscaping {
		// Simple case: just add quotes
		buf := make([]byte, len(s)+2)
		buf[0] = quote
		copy(buf[1:], s)
		buf[len(buf)-1] = quote
		return string(buf)
	}
	
	// Two-pass approach: calculate required size first
	size := 2 // Opening and closing quotes
	for i := 0; i < len(s); {
		r, width := utf8.DecodeRuneInString(s[i:])
		i += width
		size += runeEscapedSize(r, quote, mode)
	}
	
	// Allocate buffer and build result
	buf := make([]byte, size)
	buf[0] = quote
	pos := 1
	
	for i := 0; i < len(s); {
		r, width := utf8.DecodeRuneInString(s[i:])
		i += width
		pos = appendEscapedRune(buf, pos, r, quote, mode)
	}
	
	buf[pos] = quote
	return string(buf)
}

// appendQuotedWith appends a quoted string to dst.
func appendQuotedWith(dst []byte, s string, quote byte, mode int) []byte {
	// Fast path: check if string needs escaping
	if needsEscaping := checkNeedsEscaping(s, quote, mode); !needsEscaping {
		dst = append(dst, quote)
		dst = append(dst, s...)
		dst = append(dst, quote)
		return dst
	}
	
	// Calculate required size
	size := 2
	for i := 0; i < len(s); {
		r, width := utf8.DecodeRuneInString(s[i:])
		i += width
		size += runeEscapedSize(r, quote, mode)
	}
	
	// Grow buffer
	oldLen := len(dst)
	dst = append(dst, make([]byte, size)...)
	
	// Build quoted string
	dst[oldLen] = quote
	pos := oldLen + 1
	
	for i := 0; i < len(s); {
		r, width := utf8.DecodeRuneInString(s[i:])
		i += width
		pos = appendEscapedRune(dst, pos, r, quote, mode)
	}
	
	dst[pos] = quote
	return dst[:pos+1]
}

// quoteRuneWith returns a quoted rune using the specified quote character and mode.
func quoteRuneWith(r rune, quote byte, mode int) string {
	size := 2 + runeEscapedSize(r, quote, mode)
	buf := make([]byte, size)
	buf[0] = quote
	pos := appendEscapedRune(buf, 1, r, quote, mode)
	buf[pos] = quote
	return string(buf[:pos+1])
}

// appendQuotedRuneWith appends a quoted rune to dst.
func appendQuotedRuneWith(dst []byte, r rune, quote byte, mode int) []byte {
	size := 2 + runeEscapedSize(r, quote, mode)
	oldLen := len(dst)
	dst = append(dst, make([]byte, size)...)
	
	dst[oldLen] = quote
	pos := appendEscapedRune(dst, oldLen+1, r, quote, mode)
	dst[pos] = quote
	return dst[:pos+1]
}

// checkNeedsEscaping checks if a string needs any escaping.
// This can be optimized with SIMD on amd64/arm64.
func checkNeedsEscaping(s string, quote byte, mode int) bool {
	// Use optimized version if available
	if hasASM {
		return needsEscapingOptimized(s, quote, mode)
	}
	return checkNeedsEscapingGeneric(s, quote, mode)
}

// checkNeedsEscapingGeneric is the generic implementation.
func checkNeedsEscapingGeneric(s string, quote byte, mode int) bool {
	for i := 0; i < len(s); {
		c := s[i]
		
		// Fast path for common ASCII printable characters
		if c < utf8.RuneSelf {
			if c == quote || c == '\\' || c < ' ' || c == 0x7F {
				return true
			}
			if mode == ModeASCII && c >= 0x80 {
				return true
			}
			i++
			continue
		}
		
		// Multi-byte UTF-8
		r, width := utf8.DecodeRuneInString(s[i:])
		if r == utf8.RuneError {
			return true
		}
		
		if mode == ModeASCII {
			return true // Non-ASCII needs escaping in ASCII mode
		}
		
		if mode == ModeGraphic {
			if !isGraphic(r) {
				return true
			}
		} else {
			if !isPrint(r) {
				return true
			}
		}
		
		i += width
	}
	
	return false
}

// runeEscapedSize returns the number of bytes needed to represent the rune when escaped.
func runeEscapedSize(r rune, quote byte, mode int) int {
	// Check if rune needs escaping
	if r == rune(quote) || r == '\\' {
		return 2 // \q or \\
	}
	
	// Standard escape sequences
	switch r {
	case '\a', '\b', '\f', '\n', '\r', '\t', '\v':
		return 2
	}
	
	// ASCII printable
	if r < utf8.RuneSelf {
		if r >= ' ' && r != 0x7F {
			return 1
		}
		// Control characters: \xHH
		return 4
	}
	
	// Non-ASCII
	if mode == ModeASCII {
		if r <= 0xFFFF {
			return 6 // \uHHHH
		}
		return 10 // \UHHHHHHHH
	}
	
	// Check if printable/graphic
	needsEscape := false
	if mode == ModeGraphic {
		needsEscape = !isGraphic(r)
	} else {
		needsEscape = !isPrint(r)
	}
	
	if needsEscape {
		if r <= 0xFFFF {
			return 6 // \uHHHH
		}
		return 10 // \UHHHHHHHH
	}
	
	// Valid UTF-8 rune, return its size
	return utf8.RuneLen(r)
}

// appendEscapedRune appends an escaped rune to buf starting at pos.
// Returns the new position.
func appendEscapedRune(buf []byte, pos int, r rune, quote byte, mode int) int {
	// Quote character or backslash
	if r == rune(quote) {
		buf[pos] = '\\'
		buf[pos+1] = quote
		return pos + 2
	}
	if r == '\\' {
		buf[pos] = '\\'
		buf[pos+1] = '\\'
		return pos + 2
	}
	
	// Standard escape sequences
	switch r {
	case '\a':
		buf[pos] = '\\'
		buf[pos+1] = 'a'
		return pos + 2
	case '\b':
		buf[pos] = '\\'
		buf[pos+1] = 'b'
		return pos + 2
	case '\f':
		buf[pos] = '\\'
		buf[pos+1] = 'f'
		return pos + 2
	case '\n':
		buf[pos] = '\\'
		buf[pos+1] = 'n'
		return pos + 2
	case '\r':
		buf[pos] = '\\'
		buf[pos+1] = 'r'
		return pos + 2
	case '\t':
		buf[pos] = '\\'
		buf[pos+1] = 't'
		return pos + 2
	case '\v':
		buf[pos] = '\\'
		buf[pos+1] = 'v'
		return pos + 2
	}
	
	// ASCII printable
	if r < utf8.RuneSelf {
		if r >= ' ' && r != 0x7F {
			buf[pos] = byte(r)
			return pos + 1
		}
		// Control characters: \xHH
		buf[pos] = '\\'
		buf[pos+1] = 'x'
		buf[pos+2] = hexDigit(byte(r) >> 4)
		buf[pos+3] = hexDigit(byte(r) & 0xF)
		return pos + 4
	}
	
	// Non-ASCII
	if mode == ModeASCII {
		if r <= 0xFFFF {
			// \uHHHH
			buf[pos] = '\\'
			buf[pos+1] = 'u'
			buf[pos+2] = hexDigit(byte(r >> 12))
			buf[pos+3] = hexDigit(byte(r >> 8 & 0xF))
			buf[pos+4] = hexDigit(byte(r >> 4 & 0xF))
			buf[pos+5] = hexDigit(byte(r & 0xF))
			return pos + 6
		}
		// \UHHHHHHHH
		buf[pos] = '\\'
		buf[pos+1] = 'U'
		buf[pos+2] = hexDigit(byte(r >> 28))
		buf[pos+3] = hexDigit(byte(r >> 24 & 0xF))
		buf[pos+4] = hexDigit(byte(r >> 20 & 0xF))
		buf[pos+5] = hexDigit(byte(r >> 16 & 0xF))
		buf[pos+6] = hexDigit(byte(r >> 12 & 0xF))
		buf[pos+7] = hexDigit(byte(r >> 8 & 0xF))
		buf[pos+8] = hexDigit(byte(r >> 4 & 0xF))
		buf[pos+9] = hexDigit(byte(r & 0xF))
		return pos + 10
	}
	
	// Check if printable/graphic
	needsEscape := false
	if mode == ModeGraphic {
		needsEscape = !isGraphic(r)
	} else {
		needsEscape = !isPrint(r)
	}
	
	if needsEscape {
		if r <= 0xFFFF {
			// \uHHHH
			buf[pos] = '\\'
			buf[pos+1] = 'u'
			buf[pos+2] = hexDigit(byte(r >> 12))
			buf[pos+3] = hexDigit(byte(r >> 8 & 0xF))
			buf[pos+4] = hexDigit(byte(r >> 4 & 0xF))
			buf[pos+5] = hexDigit(byte(r & 0xF))
			return pos + 6
		}
		// \UHHHHHHHH
		buf[pos] = '\\'
		buf[pos+1] = 'U'
		buf[pos+2] = hexDigit(byte(r >> 28))
		buf[pos+3] = hexDigit(byte(r >> 24 & 0xF))
		buf[pos+4] = hexDigit(byte(r >> 20 & 0xF))
		buf[pos+5] = hexDigit(byte(r >> 16 & 0xF))
		buf[pos+6] = hexDigit(byte(r >> 12 & 0xF))
		buf[pos+7] = hexDigit(byte(r >> 8 & 0xF))
		buf[pos+8] = hexDigit(byte(r >> 4 & 0xF))
		buf[pos+9] = hexDigit(byte(r & 0xF))
		return pos + 10
	}
	
	// Valid UTF-8 rune, encode it
	return pos + utf8.EncodeRune(buf[pos:], r)
}

// hexDigit returns the hexadecimal character for a value 0-15.
func hexDigit(b byte) byte {
	if b < 10 {
		return '0' + b
	}
	return 'a' + b - 10
}

// isPrint reports whether the rune is printable (from Unicode package).
func isPrint(r rune) bool {
	// This will be replaced with optimized lookup table
	if r < 0x20 || r == 0x7F {
		return false
	}
	if r < 0x7F {
		return true
	}
	// For now, accept all non-ASCII as printable
	// TODO: Use proper Unicode tables
	return r != utf8.RuneError
}

// isGraphic reports whether the rune is graphic (from Unicode package).
func isGraphic(r rune) bool {
	// This will be replaced with optimized lookup table
	if r < 0x20 || r == 0x7F {
		return false
	}
	if r < 0x7F {
		return r != ' ' // Space is not graphic
	}
	// For now, accept all non-ASCII as graphic
	// TODO: Use proper Unicode tables
	return r != utf8.RuneError
}

