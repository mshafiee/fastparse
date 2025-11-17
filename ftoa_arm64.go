// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package fastparse

// formatExponentASM formats an exponent value into dst buffer
// Returns the number of bytes written
//
//go:noescape
func formatExponentASM(dst []byte, exp int, fmt byte) int

// formatExponentOptimized formats exponent with branchless operations
func formatExponentOptimized(dst []byte, exp int, fmt byte) []byte {
	// Use optimized Go implementation
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
