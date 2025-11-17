// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package hexfloat

// ParseHexMantissa parses hex digits from a string
// Returns (mantissa, hexIntDigits, hexFracDigits, totalDigitsParsed, success)
// Stops at first non-hex character or after maxDigits
func ParseHexMantissa(s string, offset int, maxDigits int) (mantissa uint64, hexIntDigits int, hexFracDigits int, digitsParsed int, ok bool) {
	return parseHexMantissaImpl(s, offset, maxDigits)
}

// HasHexPrefix checks if the string at offset has a hex prefix (0x or 0X)
func HasHexPrefix(s string, offset int) bool {
	if offset+2 > len(s) {
		return false
	}
	return s[offset] == '0' && (s[offset+1] == 'x' || s[offset+1] == 'X')
}
