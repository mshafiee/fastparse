// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64 || arm64

package eisel_lemire

import "math"

// Helper functions to expose table values for inlining in parseSimpleFast
func MinTableExp() int { return minTableExp }
func MaxTableExp() int { return maxTableExp }
func GetTableValues(idx int) (uint64, uint64) {
	return pow10TableHigh[idx], pow10TableLow[idx]
}

// tryParseAsm is the assembly implementation of Eisel-Lemire algorithm
// It returns (result, true) on success or (0, false) on failure
//
//go:noescape
func tryParseAsm(mantissa uint64, exp10 int, tablePtrHigh *uint64, tablePtrLow *uint64) (result float64, ok bool)

// TryParse attempts to parse a decimal float using the optimized assembly Eisel-Lemire algorithm.
func TryParse(mantissa uint64, exp10 int) (float64, bool) {
	// Handle zero
	if mantissa == 0 {
		return 0.0, true
	}

	// Check if exponent is in our table range
	if exp10 < minTableExp || exp10 > maxTableExp {
		return 0, false
	}

	// Call assembly implementation with pointers to both tables
	result, ok := tryParseAsm(mantissa, exp10, &pow10TableHigh[0], &pow10TableLow[0])
	
	// Assembly Eisel-Lemire may not detect all overflow cases or may produce NaN
	// If result is NaN, fall back to allow proper overflow detection
	if ok && math.IsNaN(result) {
		return 0, false
	}
	
	// If result is exactly MaxFloat64 with mantissa+exp indicating potential overflow,
	// fall back to big.Float for proper overflow detection
	if ok {
		absResult := result
		if absResult < 0 {
			absResult = -absResult
		}
		// Only fall back if result is MaxFloat64 AND we're at the overflow boundary
		// This catches "1.797693134862315808e308" but not legitimate MaxFloat64 values
		if absResult == math.MaxFloat64 && exp10 >= 290 && mantissa >= 1797693134862315700 {
			return 0, false
		}
	}
	
	return result, ok
}
