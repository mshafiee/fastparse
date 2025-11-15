// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

import "math"

// ParseLongDecimalFast is the pure Go fallback for parseLongDecimalFast.
// Handles long decimals (20-100 digits) without FSA overhead.
func parseLongDecimalFast(s string) (float64, bool) {
	i := 0
	negative := s[0] == '-'
	if s[0] == '-' || s[0] == '+' {
		i++
		if i >= len(s) || s[i] < '0' || s[i] > '9' {
			return 0, false
		}
	}
	
	// Collect mantissa (first 19 significant digits)
	var mantissa uint64
	mantissaDigits := 0
	digitsBeforeDot := 0
	
	// Skip leading zeros
	for i < len(s) && s[i] == '0' {
		i++
	}
	
	// Collect digits before decimal point
	for i < len(s) && s[i] != '.' {
		digit := s[i] - '0'
		if digit > 9 {
			// Not a digit - invalid
			return 0, false
		}
		if mantissaDigits < 19 {
			mantissa = mantissa*10 + uint64(digit)
			mantissaDigits++
		} else {
			// Beyond 19 digits - just count them for exponent adjustment
		}
		digitsBeforeDot++
		i++
	}
	
	// Handle decimal point if present
	if i < len(s) && s[i] == '.' {
		i++
		
		// Collect digits after decimal point
		for i < len(s) {
			digit := s[i] - '0'
			if digit > 9 {
				// Not a digit - invalid
				return 0, false
			}
			if mantissaDigits < 19 {
				mantissa = mantissa*10 + uint64(digit)
				mantissaDigits++
			}
			i++
		}
	}
	
	// Validate we consumed everything
	if i != len(s) || mantissaDigits == 0 {
		return 0, false
	}
	
	// Calculate exponent: position of decimal point - digits in mantissa
	exp := digitsBeforeDot - mantissaDigits
	
	// Quick range check
	if exp < -308 || exp > 308 {
		return 0, false
	}
	
	// Convert mantissa to float64
	if mantissa == 0 {
		if negative {
			return math.Copysign(0, -1), true
		}
		return 0, true
	}
	
	f := float64(mantissa)
	if negative {
		f = -f
	}
	
	// Apply power of 10 (simplified version)
	if exp == 0 {
		return f, true
	}
	
	// For non-zero exponents, fall back to full parser
	return 0, false
}
