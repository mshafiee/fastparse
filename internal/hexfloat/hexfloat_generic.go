// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package hexfloat

// parseHexMantissaImpl is a scalar fallback implementation
func parseHexMantissaImpl(s string, offset int, maxDigits int) (uint64, int, int, int, bool) {
	if offset >= len(s) || maxDigits <= 0 {
		return 0, 0, 0, 0, false
	}

	var mantissa uint64
	hexIntDigits := 0
	hexFracDigits := 0
	digitsParsed := 0
	sawDot := false

	for i := offset; i < len(s) && digitsParsed < maxDigits; i++ {
		ch := s[i]

		if ch == '.' {
			if sawDot {
				break // Two dots
			}
			sawDot = true
			continue
		}

		var digit uint64
		if ch >= '0' && ch <= '9' {
			digit = uint64(ch - '0')
		} else if ch >= 'a' && ch <= 'f' {
			digit = uint64(ch - 'a' + 10)
		} else if ch >= 'A' && ch <= 'F' {
			digit = uint64(ch - 'A' + 10)
		} else {
			break // Not a hex digit
		}

		mantissa = mantissa*16 + digit
		digitsParsed++

		if sawDot {
			hexFracDigits++
		} else {
			hexIntDigits++
		}
	}

	if digitsParsed == 0 {
		return 0, 0, 0, 0, false
	}

	return mantissa, hexIntDigits, hexFracDigits, digitsParsed, true
}
