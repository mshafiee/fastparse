// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package fastparse

import (
	"math"
	
	"github.com/mshafiee/fastparse/internal/eisel_lemire"
)

// On arm64 we use assembly-optimized entry points implemented in
// parse_float_arm64.s and parse_int_arm64.s

// ParseFloatAsm is the ARM64-specific entry point implemented with
// NEON-optimized assembly.
//
//go:noescape
func ParseFloatAsm(s string) (float64, error)

// ParseIntAsm is the ARM64-specific integer parser entry point
// implemented with NEON-optimized assembly.
//
//go:noescape
func ParseIntAsm(s string, bitSize int) (int64, error)

// parseIntNEON is the NEON-optimized integer parser (processes 16 bytes in parallel)
//
//go:noescape
func parseIntNEON(s string, bitSize int) (result int64, ok bool)

// parseFloat implements the main float parsing logic with ARM64 assembly optimizations
func parseFloat(s string) (float64, error) {
	// Inline the parseFloatGeneric logic with assembly-optimized fast paths
	// This is the ARM64-optimized version that avoids extra function call overhead
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
	// Assembly-optimized version for ARM64 with NEON
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

// parseInt implements the main integer parsing logic with ARM64 assembly optimizations
func parseInt(s string, bitSize int) (int64, error) {
	// ARM64-optimized integer parser with NEON SIMD
	if len(s) == 0 {
		return 0, ErrSyntax
	}

	if bitSize != 32 && bitSize != 64 {
		return 0, ErrSyntax
	}

	// For simple integers, use NEON-optimized parser
	if len(s) <= 19 {
		// Try NEON path first (processes up to 16 bytes in parallel)
		if len(s) >= 4 {
			if result, ok := parseIntNEON(s, bitSize); ok {
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

