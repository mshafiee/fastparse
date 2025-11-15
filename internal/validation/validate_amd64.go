// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package validation

import "golang.org/x/sys/cpu"

// hasUnderscoreAVX2 scans for underscore using AVX2 (32 bytes at a time)
//
//go:noescape
func hasUnderscoreAVX2(s string) bool

// hasUnderscoreSSE2 scans for underscore using SSE2 (16 bytes at a time)
//go:noescape
func hasUnderscoreSSE2(s string) bool

var useAVX2 bool

func init() {
	// Check for AVX2 support
	useAVX2 = cpu.X86.HasAVX2
}

// hasComplexCharsImpl uses SIMD to scan for underscores
func hasComplexCharsImpl(s string) bool {
	// For very short strings, use scalar
	if len(s) < 16 {
		return hasUnderscoreScalar(s)
	}
	
	// Use AVX2 if available, otherwise SSE2
	if useAVX2 {
		return hasUnderscoreAVX2(s)
	}
	return hasUnderscoreSSE2(s)
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

