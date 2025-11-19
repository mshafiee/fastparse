// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package eisel_lemire

import (
	"math"
	"math/bits"
)

// Helper functions to expose table values for inlining in parseSimpleFast.
func MinTableExp() int { return minTableExp }
func MaxTableExp() int { return maxTableExp }
func GetTableValues(idx int) (uint64, uint64) {
	return pow10TableHigh[idx], pow10TableLow[idx]
}

// tryParseFallback implements the reference Eisel-Lemire algorithm in Go.
// It matches Go's strconv behaviour and is used whenever the assembly
// implementations are unavailable or should be bypassed.
func tryParseFallback(mantissa uint64, exp10 int) (float64, bool) {
	if mantissa == 0 {
		return 0, true
	}

	if exp10 < minTableExp || exp10 > maxTableExp {
		return 0, false
	}

	// Normalize mantissa so its MSB is at bit 63.
	clz := bits.LeadingZeros64(mantissa)
	mantissa <<= uint(clz)

	const float64ExponentBias = 1023
	retExp2 := uint64((217706*exp10)>>16+64+float64ExponentBias) - uint64(clz)

	idx := exp10 - minTableExp
	xHi, xLo := bits.Mul64(mantissa, pow10TableHigh[idx])

	// Wider approximation (see Go's strconv for details).
	if xHi&0x1FF == 0x1FF && xLo+mantissa < mantissa {
		yHi, yLo := bits.Mul64(mantissa, pow10TableLow[idx])
		mergedHi := xHi
		mergedLo := xLo + yHi
		if mergedLo < xLo {
			mergedHi++
		}
		if mergedHi&0x1FF == 0x1FF && mergedLo+1 == 0 && yLo+mantissa < mantissa {
			return 0, false
		}
		xHi, xLo = mergedHi, mergedLo
	}

	msb := xHi >> 63
	retMantissa := xHi >> (msb + 9)
	retExp2 -= 1 ^ msb

	// Half-way ambiguity check.
	if xLo == 0 && xHi&0x1FF == 0 && retMantissa&3 == 1 {
		return 0, false
	}

	// Round from 54 to 53 bits.
	retMantissa += retMantissa & 1
	retMantissa >>= 1
	if retMantissa>>53 > 0 {
		retMantissa >>= 1
		retExp2++
	}

	// Overflow or underflow detection.
	if retExp2 >= 0x7FF {
		return 0, false
	}
	if retExp2 == 0 {
		if retMantissa == 0 {
			return 0, true
		}
		return 0, false
	}
	if retExp2 > 0x7FF {
		return 0, false
	}

	retBits := retExp2<<52 | retMantissa&0x000FFFFFFFFFFFFF
	return math.Float64frombits(retBits), true
}

