// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package fastparse

// isGraphicOptimized uses optimizations for fast IsGraphic checking
func isGraphicOptimized(r rune) bool {
	// Fast path: ASCII range
	if r < 0x7F {
		// Graphic includes space and printable characters
		// 0x20 <= r <= 0x7E
		return r >= 0x20 && r <= 0x7E
	}

	// Fast path for common Latin-1 range
	if r <= 0xFF {
		if r >= 0xA1 {
			return r != 0xAD // soft hyphen is not graphic
		}
		// Check if it's 0xA0 (non-breaking space)
		return r == 0xA0
	}

	// Check if printable first
	if isPrintOptimized(r) {
		return true
	}

	// Check graphic list
	return isInGraphicList(r)
}
