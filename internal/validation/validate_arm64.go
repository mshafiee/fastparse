// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package validation

// hasUnderscoreNEON scans for underscore using NEON (16 bytes at a time)
//
//go:noescape
func hasUnderscoreNEON(s string) bool

// hasComplexCharsImpl uses NEON SIMD to scan for underscores
func hasComplexCharsImpl(s string) bool {
	// For very short strings, use scalar
	if len(s) < 16 {
		return hasUnderscoreScalar(s)
	}

	// NEON is always available on ARM64
	return hasUnderscoreNEON(s)
}

// hasUnderscoreScalar is a scalar fallback
func hasUnderscoreScalar(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] == '_' {
			return true
		}
	}
	return false
}
