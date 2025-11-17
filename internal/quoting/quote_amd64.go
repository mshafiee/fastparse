// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package quoting

import (
	"github.com/mshafiee/fastparse"
)

// hasASM indicates whether assembly implementation is available
const hasASM = true

//go:noescape
func needsEscapingASM(s string, quote byte, mode int) bool

//go:noescape
func needsEscapingAVX512(s string, quote byte, mode int) bool

// needsEscapingOptimized dispatches to the best available SIMD implementation
func needsEscapingOptimized(s string, quote byte, mode int) bool {
	// Try AVX-512 for very long strings on supported CPUs
	if len(s) >= 64 && fastparse.HasAVX512() {
		// AVX-512 processes 64 bytes at a time
		// For strings >= 64 bytes, use AVX-512 then fall back to AVX2 for remainder
		if needsEscapingAVX512(s, quote, mode) {
			return true
		}
		// If AVX-512 didn't find anything, still need to check remainder with AVX2
		// Fall through to AVX2 path
	}

	// Use AVX2 for all strings (handles 32-byte chunks + SSE2 + scalar fallback)
	return needsEscapingASM(s, quote, mode)
}
