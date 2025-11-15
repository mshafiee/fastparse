// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package fastparse

// formatIntBase10ASM formats a uint64 to base-10 string using assembly
//
//go:noescape
func formatIntBase10ASM(dst []byte, u uint64) int

// formatIntBase10Optimized is the optimized base-10 formatter
func formatIntBase10Optimized(u uint64) string {
	var buf [20]byte // max uint64 in base 10 is 20 digits
	n := formatIntBase10ASM(buf[:], u)
	return string(buf[:n])
}

// appendIntBase10Optimized appends base-10 formatted uint64 to dst
func appendIntBase10Optimized(dst []byte, u uint64) []byte {
	var buf [20]byte
	n := formatIntBase10ASM(buf[:], u)
	return append(dst, buf[:n]...)
}

