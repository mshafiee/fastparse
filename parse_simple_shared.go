// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

import (
	"math"

	"github.com/mshafiee/fastparse/internal/eisel_lemire"
)

// parseSimpleFastPureGo is the pure Go implementation that can be called
// from any architecture when the pure Go path is faster (e.g., large exponents).
// This file has no build tags so it's available on all platforms.
func parseSimpleFastPureGo(s string) (float64, bool) {
	if len(s) == 0 {
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

	if i >= len(s) {
		return 0, false
	}

	// Must start with a digit
	if s[i] < '0' || s[i] > '9' {
		return 0, false
	}

	// Skip leading zeros (but track if we saw any digit)
	leadingZeros := false
	for i < len(s) && s[i] == '0' {
		leadingZeros = true
		i++
	}

	// Parse mantissa
	var mantissa uint64
	mantExp := 0
	sawDot := false
	significantDigits := 0 // Actual significant digits in mantissa
	totalDigits := 0       // Total digits seen (for tracking position)

	for i < len(s) {
		ch := s[i]

		if ch >= '0' && ch <= '9' {
			digit := uint64(ch - '0')
			totalDigits++

			// Collect up to 19 significant digits (Eisel-Lemire limit)
			if significantDigits < 19 {
				mantissa = mantissa*10 + digit
				significantDigits++
				if sawDot {
					mantExp--
				}
			} else if !sawDot {
				// Beyond 19 digits in integer part - just adjust exponent
				mantExp++
			} else {
				// Beyond 19 digits in fractional part - can ignore remaining
				// Continue parsing to validate format
			}
			i++
		} else if ch == '.' && !sawDot {
			sawDot = true
			i++
		} else {
			break
		}
	}

	// Handle case where we only saw zeros (or zero)
	if significantDigits == 0 && leadingZeros {
		// This is zero - continue to parse exponent but result is 0
		mantissa = 0
		significantDigits = 1 // Mark as valid
	}

	if significantDigits == 0 {
		return 0, false
	}

	// Optional exponent
	exp10 := int64(0)
	if i < len(s) && (s[i] == 'e' || s[i] == 'E') {
		i++
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

		for i < len(s) && s[i] >= '0' && s[i] <= '9' {
			exp10 = exp10*10 + int64(s[i]-'0')
			if exp10 > 10000 {
				// Extreme exponent - fall back
				return 0, false
			}
			i++
		}

		if expNeg {
			exp10 = -exp10
		}
	}

	// Must have consumed entire string
	if i != len(s) {
		return 0, false
	}

	// Handle zero specially
	if mantissa == 0 {
		if negative {
			return -0.0, true
		}
		return 0.0, true
	}

	// Calculate total exponent
	totalExp := mantExp + int(exp10)

	// Expanded range check for Eisel-Lemire
	if totalExp < -350 || totalExp > 310 {
		return 0, false
	}

	// OPTIMIZATION: Direct power-of-10 conversion for small to medium exponents
	// This bypasses Eisel-Lemire entirely for common cases (80-90% of floats)
	// Much faster than Eisel-Lemire's complex algorithm
	//
	// Extended range from [-15, 15] to [-22, 22] for better coverage
	// Note: For very large exponents (>22 or <-22), Eisel-Lemire is more accurate
	if totalExp >= -22 && totalExp <= 22 && significantDigits <= 15 {
		result := float64(mantissa)

		// For small exponents, use the local simplePow10TableShared (faster due to cache locality)
		if totalExp >= -15 && totalExp <= 15 {
			if totalExp > 0 {
				result *= simplePow10TableShared[totalExp]
			} else if totalExp < 0 {
				result /= simplePow10TableShared[-totalExp]
			}

			if negative {
				return -result, true
			}
			return result, true
		}

		// For medium exponents (16-22), use math.Pow10
		// This is faster than Eisel-Lemire and still accurate for this range
		if totalExp > 15 && totalExp <= 22 {
			result *= math.Pow10(totalExp)
			if negative {
				return -result, true
			}
			return result, true
		}

		// For medium negative exponents (-22 to -16)
		if totalExp < -15 && totalExp >= -22 {
			result /= math.Pow10(-totalExp)
			if negative {
				return -result, true
			}
			return result, true
		}
	}

	// For larger exponents, try Eisel-Lemire (optimized assembly on amd64/arm64)
	if result, ok := eisel_lemire.TryParse(mantissa, totalExp); ok {
		if negative {
			return -result, true
		}
		return result, true
	}

	// Eisel-Lemire failed - fall back to FSA
	return 0, false
}

// simplePow10TableShared for direct conversion (avoids Eisel-Lemire overhead)
// Covers 10^0 through 10^15, handles 80-90% of real-world floats
var simplePow10TableShared = [16]float64{
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
