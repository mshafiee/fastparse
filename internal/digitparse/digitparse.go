// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package digitparse

// ParseDigitsToUint64 parses decimal digits from string to uint64
// Returns (mantissa, digitCount, success)
// Stops at first non-digit character or after 19 digits (to prevent overflow)
func ParseDigitsToUint64(s string, offset int) (mantissa uint64, digitCount int, ok bool) {
	return parseDigitsToUint64Impl(s, offset)
}

// ParseDigitsWithDot parses decimal digits with optional decimal point
// Returns (mantissa, digitsBeforeDot, totalDigits, foundDot, success)
func ParseDigitsWithDot(s string, offset int) (mantissa uint64, digitsBeforeDot int, totalDigits int, foundDot bool, ok bool) {
	return parseDigitsWithDotImpl(s, offset)
}

