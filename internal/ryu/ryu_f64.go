// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ryu

import (
	"math"
	"math/bits"
)

// Ryū algorithm for float64 to decimal conversion
// Based on the paper "Ryū: fast float-to-string conversion" by Ulf Adams

const (
	DOUBLE_MANTISSA_BITS = 52
	DOUBLE_EXPONENT_BITS = 11
	DOUBLE_BIAS          = 1023
	DOUBLE_POW5_INV_BITCOUNT_ACTUAL = 122
	DOUBLE_POW5_BITCOUNT_ACTUAL     = 121
)

// FormatFloat64 converts a float64 to its shortest decimal representation.
// Returns the mantissa digits and the decimal exponent.
func FormatFloat64(f float64) ([]byte, int) {
	// Handle special cases
	if math.IsNaN(f) {
		return []byte("NaN"), 0
	}
	if math.IsInf(f, 1) {
		return []byte("+Inf"), 0
	}
	if math.IsInf(f, -1) {
		return []byte("-Inf"), 0
	}
	if f == 0 {
		if math.Signbit(f) {
			return []byte("-0"), 0
		}
		return []byte("0"), 0
	}

	// Extract IEEE 754 bits
	bits := math.Float64bits(f)
	ieeeSign := (bits >> 63) != 0
	ieeeMantissa := bits & ((1 << DOUBLE_MANTISSA_BITS) - 1)
	ieeeExponent := int32((bits >> DOUBLE_MANTISSA_BITS) & ((1 << DOUBLE_EXPONENT_BITS) - 1))

	var e2 int32
	var m2 uint64
	
	if ieeeExponent == 0 {
		// Subnormal number
		e2 = 1 - DOUBLE_BIAS - DOUBLE_MANTISSA_BITS
		m2 = ieeeMantissa
	} else {
		// Normal number
		e2 = int32(ieeeExponent) - DOUBLE_BIAS - DOUBLE_MANTISSA_BITS
		m2 = (1 << DOUBLE_MANTISSA_BITS) | ieeeMantissa
	}

	// Convert to decimal using Ryū algorithm
	output, decimalExponent := d2dGeneral(m2, e2)
	
	// Add sign if needed
	if ieeeSign {
		result := make([]byte, len(output)+1)
		result[0] = '-'
		copy(result[1:], output)
		return result, decimalExponent
	}
	
	return output, decimalExponent
}

// d2dGeneral implements the general Ryū algorithm for binary to decimal conversion
func d2dGeneral(m2 uint64, e2 int32) ([]byte, int) {
	// Step 1: Determine the interval of valid decimal representations
	acceptBounds := (m2 & 1) == 0 // IEEE "round to even" rule
	
	// Calculate boundaries
	mv := m2 << 2
	mmShift := uint64(1)
	if m2 != (1 << DOUBLE_MANTISSA_BITS) || e2 <= -(DOUBLE_BIAS + DOUBLE_MANTISSA_BITS + 2) {
		mmShift = 0
	}
	
	// Step 2: Determine the decimal exponent
	var e10 int32
	var vr, vp, vm uint64
	var removed int32
	
	if e2 >= 0 {
		// Positive binary exponent
		q := log10Pow2(e2)
		e10 = q
		k := int32(DOUBLE_POW5_INV_BITCOUNT_ACTUAL) + pow5bits(q) - 1
		i := -e2 + q + k
		
		// Bounds check for table access
		if q < 0 || q >= DOUBLE_POW5_INV_TABLE_SIZE {
			// Fall back to simple conversion for out of range
			return formatMantissa64(m2), int(e2)
		}
		
		mul := pow5InvSplit[q]
		vr = mulShift(mv, mul, uint(i))
		vp = mulShift(mv+2, mul, uint(i))
		vm = mulShift(mv-1-mmShift, mul, uint(i))
		
		if q != 0 && q > 0 && (vp-1)/10 <= vm/10 {
			// Rounding might affect result
			l := int32(DOUBLE_POW5_INV_BITCOUNT_ACTUAL) + pow5bits(q-1) - 1
			lastRemovedDigit := uint8(mulShift(mv, pow5InvSplit[q-1], uint(-e2+q-1+l)) % 10)
			removed = int32(lastRemovedDigit)
		}
	} else {
		// Negative binary exponent
		q := log10Pow5(-e2)
		e10 = q + e2
		i := -e2 - q
		k := pow5bits(i) - int32(DOUBLE_POW5_BITCOUNT_ACTUAL)
		j := q - k
		
		// Bounds check for table access
		if i < 0 || i >= DOUBLE_POW5_TABLE_SIZE {
			// Fall back to simple conversion for out of range
			return formatMantissa64(m2), int(e2)
		}
		
		mul := pow5Split[i]
		vr = mulShift(mv, mul, uint(j))
		vp = mulShift(mv+2, mul, uint(j))
		vm = mulShift(mv-1-mmShift, mul, uint(j))
		
		if q != 0 && i+1 < DOUBLE_POW5_TABLE_SIZE && (vp-1)/10 <= vm/10 {
			j2 := q - 1 - (pow5bits(i+1) - int32(DOUBLE_POW5_BITCOUNT_ACTUAL))
			lastRemovedDigit := uint8(mulShift(mv, pow5Split[i+1], uint(j2)) % 10)
			removed = int32(lastRemovedDigit)
		}
	}
	
	// Step 3: Find the shortest decimal representation in the interval
	var output uint64
	var lastRemovedDigit uint8
	
	// Remove trailing zeros
	if acceptBounds {
		for vp/10 > vm/10 {
			vmIsTrailingZeros := removed == 0
			lastRemovedDigit = uint8(vr % 10)
			vr /= 10
			vp /= 10
			vm /= 10
			if lastRemovedDigit != 0 {
				vmIsTrailingZeros = false
			}
			removed++
			if !vmIsTrailingZeros {
				break
			}
		}
		if removed > 0 && lastRemovedDigit == 5 && vr%2 == 0 {
			// Round to even
			lastRemovedDigit = 4
		}
		output = vr
		if lastRemovedDigit >= 5 {
			output++
		}
	} else {
		for vp/10 > vm/10 {
			lastRemovedDigit = uint8(vr % 10)
			vr /= 10
			vp /= 10
			vm /= 10
			removed++
		}
		output = vr
		if vr == vm && lastRemovedDigit >= 5 {
			output++
		} else if lastRemovedDigit >= 5 {
			output++
		}
	}
	
	// Format output
	return formatMantissa64(output), int(e10) + int(removed)
}

// mulShift performs (m * mul) >> shift with 128-bit precision
func mulShift(m uint64, mul [2]uint64, shift uint) uint64 {
	// Perform 64x128-bit multiplication
	// m * (mul[0]:mul[1]) where mul[0] is high 64 bits, mul[1] is low 64 bits
	
	// m * mul[1] (low part)
	hi1, lo1 := bits.Mul64(m, mul[1])
	
	// m * mul[0] (high part)
	hi2, lo2 := bits.Mul64(m, mul[0])
	
	// Add the results: (hi2:lo2:0) + (hi1:lo1)
	lo := lo1
	mid := hi1 + lo2
	hi := hi2
	if mid < lo2 {
		hi++ // Carry
	}
	
	// Now we have a 192-bit result: (hi:mid:lo)
	// Shift right by 'shift' bits
	if shift >= 128 {
		// Result is entirely from hi
		return hi >> (shift - 128)
	} else if shift >= 64 {
		// Result is from hi:mid
		s := shift - 64
		if s == 0 {
			return mid
		}
		return (mid >> s) | (hi << (64 - s))
	} else {
		// Result is from mid:lo
		if shift == 0 {
			return lo
		}
		return (lo >> shift) | (mid << (64 - shift))
	}
}

// formatMantissa64 formats a uint64 mantissa as decimal digits
func formatMantissa64(m uint64) []byte {
	if m == 0 {
		return []byte{'0'}
	}
	
	// Count digits
	digits := 0
	temp := m
	for temp > 0 {
		digits++
		temp /= 10
	}
	
	result := make([]byte, digits)
	for i := digits - 1; i >= 0; i-- {
		result[i] = byte('0' + m%10)
		m /= 10
	}
	
	return result
}

// log10Pow2 returns floor(log10(2^e))
func log10Pow2(e int32) int32 {
	// log10(2^e) = e * log10(2) ≈ e * 0.30102999566398114
	// We use: floor(e * 78913) >> 18) which gives a good approximation
	return (e * 78913) >> 18
}

// log10Pow5 returns floor(log10(5^e))
func log10Pow5(e int32) int32 {
	// log10(5^e) = e * log10(5) ≈ e * 0.69897000433601886
	// We use: floor((e * 1217359) >> 19)
	return (e * 1217359) >> 19
}

// pow5bits returns the number of bits required to represent 5^e
func pow5bits(e int32) int32 {
	// 5^e requires ceil(e * log2(5)) = ceil(e * 2.321928...)
	// We use: floor(e * 163391) >> 16) + 1
	return ((e * 163391) >> 16) + 1
}
