// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package fastparse

import (
	"math"
	
	"github.com/mshafiee/fastparse/internal/eisel_lemire"
)

// On amd64 we use assembly-optimized entry points implemented in
// parse_float_amd64.s and parse_int_amd64.s

// ParseFloatAsm is the amd64-specific entry point that delegates to the
// assembly implementation or falls back to the fast paths.
//
//go:noescape
func ParseFloatAsm(s string) (float64, error)

// ParseIntAsm is the amd64-specific integer parser entry point.
//
//go:noescape
func ParseIntAsm(s string, bitSize int) (int64, error)

// parseIntAVX512 is the AVX-512 optimized integer parser
//
//go:noescape
func parseIntAVX512(s string, bitSize int) (result int64, ok bool)

// parseIntAVX2 is the AVX2 optimized integer parser
//
//go:noescape
func parseIntAVX2(s string, bitSize int) (result int64, ok bool)

// parseIntBMI2 is the BMI2 optimized integer parser (fast overflow checking)
//
//go:noescape
func parseIntBMI2(s string, bitSize int) (result int64, ok bool)

// parseUintBMI2 is the BMI2 optimized unsigned integer parser
//
//go:noescape
func parseUintBMI2(s string, bitSize int) (result uint64, ok bool)

// parseFloat implements the main float parsing logic with assembly optimizations
func parseFloat(s string) (float64, error) {
	// Inline the parseFloatGeneric logic with assembly-optimized fast paths
	// This is the AMD64-optimized version that avoids extra function call overhead
	if len(s) == 0 {
		return 0, ErrSyntax
	}

	// Fast path for hex floats (5% of inputs, specialized parser)
	if len(s) > 2 && len(s) < 64 {
		idx := 0
		if s[idx] == '-' || s[idx] == '+' {
			idx++
		}
		if idx+1 < len(s) && s[idx] == '0' && (s[idx+1] == 'x' || s[idx+1] == 'X') {
			if result, ok := parseHexFast(s); ok {
				return result, nil
			}
		}
	}

	// Fast path for simple decimal patterns (70-80% of real-world inputs)
	// Assembly-optimized version for AMD64
	if len(s) < 32 {
		if result, mantissa, exp, neg, ok := parseSimpleFast(s); ok {
			return result, nil
		} else if mantissa != 0 && exp >= -348 && exp <= 308 {
			// parseSimpleFast parsed successfully but couldn't convert - try Eisel-Lemire directly!
			// This bypasses the FSA overhead (50-80ns savings) - matching strconv's approach
			// Only do this if exp is in Eisel-Lemire's valid range
			if result, ok := eisel_lemire.TryParse(mantissa, exp); ok {
				if neg {
					result = -result
				}
				// Check for overflow or NaN
				if math.IsInf(result, 0) || math.IsNaN(result) {
					return result, ErrRange
				}
				return result, nil
			}
		}
	}

	// Fast path for long decimals (5-10% of inputs)
	if len(s) >= 20 && len(s) <= 100 {
		if result, ok := parseLongDecimalFast(s); ok {
			return result, nil
		}
	}

	// Full FSA path for complex cases - delegate to generic implementation
	return parseFloatGeneric(s)
}

// parseInt implements the main integer parsing logic with assembly optimizations
func parseInt(s string, bitSize int) (int64, error) {
	// AMD64-optimized integer parser with CPU-specific dispatch
	if len(s) == 0 {
		return 0, ErrSyntax
	}

	if bitSize != 32 && bitSize != 64 {
		return 0, ErrSyntax
	}

	// For simple integers, use optimized parsers based on CPU capabilities
	if len(s) <= 19 {
		// Try BMI2 path first (fastest overflow checking)
		if HasBMI2() {
			if result, ok := parseIntBMI2(s, bitSize); ok {
				return result, nil
			}
		}
		
		// Try AVX-512 path (processes up to 16 digits in parallel)
		if HasAVX512() && len(s) >= 4 {
			if result, ok := parseIntAVX512(s, bitSize); ok {
				return result, nil
			}
		}
		
		// Try AVX2 path (processes up to 8 digits in parallel)
		if HasAVX2() && len(s) >= 4 {
			if result, ok := parseIntAVX2(s, bitSize); ok {
				return result, nil
			}
		}
		
		// Fall back to basic assembly fast path
		if result, ok := parseIntFastAsm(s, bitSize); ok {
			return result, nil
		}
	}

	// Fall back to generic implementation for complex cases
	return parseIntGeneric(s, bitSize)
}

