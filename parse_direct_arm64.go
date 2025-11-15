// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package fastparse

// parseDirectFloat provides ultra-fast direct conversion for common float patterns.
// This uses optimized assembly for ARM64.
//
// Note: Assembly only handles pure integers, so mantissa/exp are always 0.
//
//go:noescape
func parseDirectFloatAsm(s string) (result float64, ok bool)

func parseDirectFloat(s string) (float64, uint64, int, bool, bool) {
	result, ok := parseDirectFloatAsm(s)
	return result, 0, 0, false, ok
}

