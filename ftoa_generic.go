// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// formatExponentOptimized falls back to generic implementation
func formatExponentOptimized(dst []byte, exp int, fmt byte) []byte {
	// Append format character
	dst = append(dst, fmt)

	// Append sign
	ch := byte('+')
	if exp < 0 {
		ch = '-'
		exp = -exp
	}
	dst = append(dst, ch)

	// Append exponent digits
	switch {
	case exp < 10:
		dst = append(dst, '0', byte(exp)+'0')
	case exp < 100:
		dst = append(dst, byte(exp/10)+'0', byte(exp%10)+'0')
	default:
		dst = append(dst, byte(exp/100)+'0', byte(exp/10)%10+'0', byte(exp%10)+'0')
	}

	return dst
}
