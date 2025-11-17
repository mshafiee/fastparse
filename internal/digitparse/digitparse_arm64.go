// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package digitparse

// parseDigitsToUint64Asm is the assembly implementation
//
//go:noescape
func parseDigitsToUint64Asm(s string, offset int) (mantissa uint64, digitCount int, ok bool)

// parseDigitsWithDotAsm is the assembly implementation with decimal point support
//
//go:noescape
func parseDigitsWithDotAsm(s string, offset int) (mantissa uint64, digitsBeforeDot int, totalDigits int, foundDot bool, ok bool)

func parseDigitsToUint64Impl(s string, offset int) (uint64, int, bool) {
	if offset >= len(s) {
		return 0, 0, false
	}
	return parseDigitsToUint64Asm(s, offset)
}

func parseDigitsWithDotImpl(s string, offset int) (uint64, int, int, bool, bool) {
	if offset >= len(s) {
		return 0, 0, 0, false, false
	}
	return parseDigitsWithDotAsm(s, offset)
}
