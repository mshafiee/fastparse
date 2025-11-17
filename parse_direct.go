// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// parseDirectFloat provides ultra-fast direct conversion for common float patterns.
// This is the purego fallback implementation.
//
// Returns (result, mantissa, exp, neg, true) on success.
// Returns (0, 0, 0, false, false) on failure (doesn't parse mantissa/exp, only integers).
//
// Note: This function only handles pure integers, so mantissa/exp are always 0.
func parseDirectFloat(s string) (float64, uint64, int, bool, bool) {
	if len(s) == 0 || len(s) > 16 {
		return 0, 0, 0, false, false
	}

	i := 0
	negative := false

	// Parse optional sign
	if s[i] == '-' {
		negative = true
		i++
	} else if s[i] == '+' {
		i++
	}

	if i >= len(s) {
		return 0, 0, 0, false, false
	}

	// Must start with a digit
	if s[i] < '0' || s[i] > '9' {
		return 0, 0, 0, false, false
	}

	// Parse integer part
	var intPart uint64
	intDigits := 0

	for i < len(s) && s[i] >= '0' && s[i] <= '9' {
		digit := uint64(s[i] - '0')

		// Limit to 6 digits total for direct conversion (precision guaranteed)
		if intDigits >= 6 {
			return 0, 0, 0, false, false
		}

		intPart = intPart*10 + digit
		intDigits++
		i++
	}

	// Pure integer - safe for direct conversion
	if i == len(s) {
		result := float64(intPart)
		if negative {
			return -result, 0, 0, false, true
		}
		return result, 0, 0, false, true
	}

	// Any other pattern (decimal, exponent, etc.) - fall back to parseSimpleFast
	// which has Eisel-Lemire inlined for correct rounding
	// Note: Direct decimal division has rounding precision issues,
	// so we let Eisel-Lemire handle all decimals for correctness
	return 0, 0, 0, false, false
}

// pow10Direct is a small table for direct exponent computation
// This covers exp in range [-15, 15] which handles most real-world cases
var pow10Direct = [16]float64{
	1.0,                // 10^0
	10.0,               // 10^1
	100.0,              // 10^2
	1000.0,             // 10^3
	10000.0,            // 10^4
	100000.0,           // 10^5
	1000000.0,          // 10^6
	10000000.0,         // 10^7
	100000000.0,        // 10^8
	1000000000.0,       // 10^9
	10000000000.0,      // 10^10
	100000000000.0,     // 10^11
	1000000000000.0,    // 10^12
	10000000000000.0,   // 10^13
	100000000000000.0,  // 10^14
	1000000000000000.0, // 10^15
}
