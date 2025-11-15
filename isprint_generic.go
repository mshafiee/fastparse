// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// isPrintOptimized provides the generic implementation
func isPrintOptimized(r rune) bool {
	// Fast path for common ASCII range
	// 0x20 <= r <= 0x7E
	if r <= 0x7E {
		return r >= 0x20
	}
	
	// Fast path for Latin-1 range
	// 0xA1 <= r <= 0xFF (except 0xAD)
	if r <= 0xFF {
		if r >= 0xA1 {
			return r != 0xAD // soft hyphen is not printable
		}
		return false
	}
	
	// Use fallback for higher Unicode ranges
	return isPrintFallback(r)
}

// isPrintFallback is a pure Go implementation
func isPrintFallback(r rune) bool {
	// Binary search in isPrint16 and isPrint32 tables
	if r < 0x10000 {
		// Check 16-bit table
		rr := uint16(r)
		// Find the first element >= rr using binary search
		i, _ := bsearch(isPrint16, rr)
		if i >= len(isPrint16) {
			return false
		}
		// Check if in a valid range [isPrint16[i&^1], isPrint16[i|1]]
		if rr < isPrint16[i&^1] || isPrint16[i|1] < rr {
			return false
		}
		// Check if in the exclusion list
		_, found := bsearch(isNotPrint16, rr)
		return !found
	}
	
	// Check 32-bit table for r >= 0x10000
	// For r in [0x10000, 0x20000), also check isNotPrint32
	i, _ := bsearch(isPrint32, uint32(r))
	if i >= len(isPrint32) {
		return false
	}
	// Check if in a valid range [isPrint32[i&^1], isPrint32[i|1]]
	if uint32(r) < isPrint32[i&^1] || isPrint32[i|1] < uint32(r) {
		return false
	}
	
	// For r in [0x10000, 0x20000), also check the not-print list
	if r < 0x20000 {
		rr := uint16(r - 0x10000)
		_, found := bsearch(isNotPrint32, rr)
		return !found
	}
	
	return true
}

