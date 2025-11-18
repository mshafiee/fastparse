// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

package fastparse

import "unsafe"

// parseSimpleFastAsm is the Go wrapper that prepares the raw pointer/length
// arguments for the ARM64 assembly implementation.
func parseSimpleFastAsm(s string) (float64, uint64, int, bool, bool) {
	var ptr *byte
	if len(s) > 0 {
		ptr = unsafe.StringData(s)
	}
	return parseSimpleFastAsmRaw(ptr, len(s))
}

// parseSimpleFastAsmRaw is implemented in parse_simple_arm64.s and expects the
// already-extracted data pointer and length.
//
//go:noescape
func parseSimpleFastAsmRaw(ptr *byte, length int) (result float64, mantissa uint64, exp int, neg bool, ok bool)

// parseSimpleFast dispatches to the assembly implementation.
func parseSimpleFast(s string) (float64, uint64, int, bool, bool) {
	return parseSimpleFastAsm(s)
}
