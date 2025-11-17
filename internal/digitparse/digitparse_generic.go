// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package digitparse

// parseDigitsToUint64Impl is a scalar fallback implementation
func parseDigitsToUint64Impl(s string, offset int) (uint64, int, bool) {
	if offset >= len(s) {
		return 0, 0, false
	}

	var mantissa uint64
	digitCount := 0
	maxDigits := 19

	for i := offset; i < len(s) && digitCount < maxDigits; i++ {
		ch := s[i]
		if ch < '0' || ch > '9' {
			break
		}
		mantissa = mantissa*10 + uint64(ch-'0')
		digitCount++
	}

	if digitCount == 0 {
		return 0, 0, false
	}

	return mantissa, digitCount, true
}

// parseDigitsWithDotImpl is a scalar fallback with decimal point support
func parseDigitsWithDotImpl(s string, offset int) (uint64, int, int, bool, bool) {
	if offset >= len(s) {
		return 0, 0, 0, false, false
	}

	var mantissa uint64
	digitsBeforeDot := 0
	totalDigits := 0
	foundDot := false
	maxDigits := 19

	for i := offset; i < len(s) && totalDigits < maxDigits; i++ {
		ch := s[i]

		if ch == '.' {
			if foundDot {
				break // Two dots
			}
			foundDot = true
			continue
		}

		if ch < '0' || ch > '9' {
			break
		}

		mantissa = mantissa*10 + uint64(ch-'0')
		totalDigits++

		if !foundDot {
			digitsBeforeDot++
		}
	}

	if totalDigits == 0 {
		return 0, 0, 0, false, false
	}

	return mantissa, digitsBeforeDot, totalDigits, foundDot, true
}
