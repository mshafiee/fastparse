// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package conversion

import "math"

func convertDecimalExactImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExactScalar(mantissa, exp, neg, pow10Table)
}

func convertDecimalExtendedImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExtendedScalar(mantissa, exp, neg, pow10Table)
}

func convertDecimalExactScalar(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	// Check if mantissa fits in float64 mantissa (53 bits)
	const float64MantissaBits = 52
	if mantissa>>float64MantissaBits != 0 {
		return 0, false
	}
	
	f := float64(mantissa)
	if neg {
		f = -f
	}
	
	switch {
	case exp == 0:
		return f, true
		
	case exp > 0 && exp <= 15+22:
		if exp > 22 {
			f *= pow10Table[exp-22]
			exp = 22
		}
		
		if f > 1e15 || f < -1e15 {
			return 0, false
		}
		
		return f * pow10Table[exp], true
		
	case exp < 0 && exp >= -22:
		return f / pow10Table[-exp], true
	}
	
	return 0, false
}

func convertDecimalExtendedScalar(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	if exp < -308 || exp > 308 {
		return 0, false
	}
	
	const maxMantissa = uint64(1) << 53
	
	if mantissa > maxMantissa {
		digitsToRemove := 0
		temp := mantissa
		for temp > maxMantissa {
			temp /= 10
			digitsToRemove++
		}
		
		if digitsToRemove > 0 {
			var divisor uint64 = 1
			for i := 0; i < digitsToRemove; i++ {
				divisor *= 10
				if divisor == 0 {
					return 0, false
				}
			}
			
			quotient := mantissa / divisor
			remainder := mantissa % divisor
			halfDivisor := divisor / 2
			
			if remainder > halfDivisor || (remainder == halfDivisor && (quotient&1) != 0) {
				quotient++
			}
			
			mantissa = quotient
			exp += digitsToRemove
			
			if exp > 308 {
				return 0, false
			}
		}
	}
	
	if mantissa == 0 {
		if neg {
			return math.Copysign(0, -1), true
		}
		return 0, true
	}
	
	f := float64(mantissa)
	if neg {
		f = -f
	}
	
	if exp == 0 {
		return f, true
	} else if exp > 0 {
		if exp < len(pow10Table) {
			result := f * pow10Table[exp]
			if !math.IsInf(result, 0) {
				return result, true
			}
		}
		return 0, false
	} else {
		absExp := -exp
		if absExp < len(pow10Table) {
			result := f / pow10Table[absExp]
			if result != 0 || mantissa == 0 {
				return result, true
			}
		}
		return 0, false
	}
}

