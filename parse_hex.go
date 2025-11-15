// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

import (
	"math"
	"math/bits"
)

// ParseHexFast is the pure Go fallback for parseHexFast.
// Handles: [-]?0[xX][0-9a-fA-F]+\.?[0-9a-fA-F]*[pP][-+]?[0-9]+
func parseHexFast(s string) (float64, bool) {
	if len(s) < 5 {
		return 0, false
	}

	i := 0
	negative := false

	// Optional sign
	if s[i] == '-' {
		negative = true
		i++
	} else if s[i] == '+' {
		i++
	}

	// Require 0x prefix
	if i+1 >= len(s) || s[i] != '0' || (s[i+1] != 'x' && s[i+1] != 'X') {
		return 0, false
	}
	i += 2

	// Parse hex mantissa
	var mantissa uint64
	hexIntDigits := 0
	hexFracDigits := 0
	sawDot := false
	sawDigit := false
	digitCount := 0

	for i < len(s) {
		ch := s[i]
		var digit uint64

		if ch >= '0' && ch <= '9' {
			digit = uint64(ch - '0')
			sawDigit = true
		} else if ch >= 'a' && ch <= 'f' {
			digit = uint64(ch - 'a' + 10)
			sawDigit = true
		} else if ch >= 'A' && ch <= 'F' {
			digit = uint64(ch - 'A' + 10)
			sawDigit = true
		} else if ch == '.' && !sawDot {
			sawDot = true
			i++
			continue
		} else {
			break
		}

		// Collect up to 16 hex digits (64 bits)
		if digitCount < 16 {
			mantissa = mantissa*16 + digit
			if sawDot {
				hexFracDigits++
			} else {
				hexIntDigits++
			}
			digitCount++
		}

		i++
	}

	if !sawDigit {
		return 0, false
	}

	// Require binary exponent (p or P)
	if i >= len(s) || (s[i] != 'p' && s[i] != 'P') {
		return 0, false
	}
	i++

	// Parse binary exponent
	if i >= len(s) {
		return 0, false
	}

	expNeg := false
	if s[i] == '-' {
		expNeg = true
		i++
	} else if s[i] == '+' {
		i++
	}

	if i >= len(s) || s[i] < '0' || s[i] > '9' {
		return 0, false
	}

	exp2 := 0
	for i < len(s) && s[i] >= '0' && s[i] <= '9' {
		exp2 = exp2*10 + int(s[i]-'0')
		if exp2 > 10000 {
			return 0, false
		}
		i++
	}

	if expNeg {
		exp2 = -exp2
	}

	// Must have consumed entire string
	if i != len(s) {
		return 0, false
	}

	// Adjust exponent for fractional hex digits
	exp2 -= hexFracDigits * 4

	if mantissa == 0 {
		if negative {
			return math.Copysign(0, -1), true
		}
		return 0, true
	}

	// Normalize mantissa
	shift := bits.LeadingZeros64(mantissa)
	mantissa <<= uint(shift)
	exp2 -= shift

	// For full implementation, would do proper IEEE 754 conversion
	// For now, fall back to full parser
	return 0, false
}
