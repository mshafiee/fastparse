// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

import (
	"unsafe"
)

// stringToBytes converts a string to []byte without allocation.
// WARNING: The returned slice must not be modified!
// This eliminates the allocation that would normally occur with []byte(s).
//
//go:nosplit
//go:nocheckptr
func stringToBytes(s string) []byte {
	if len(s) == 0 {
		return nil
	}
	return unsafe.Slice(unsafe.StringData(s), len(s))
}

// bytesToString converts []byte to string without allocation.
// WARNING: The input slice must not be modified after this call!
// This eliminates the allocation that would normally occur with string(b).
//
//go:nosplit
//go:nocheckptr
func bytesToString(b []byte) string {
	if len(b) == 0 {
		return ""
	}
	return unsafe.String(unsafe.SliceData(b), len(b))
}

// getByteUnchecked returns the byte at index i without bounds checking.
// UNSAFE: Caller must ensure i < len(s).
//
//go:nosplit
//go:nocheckptr
func getByteUnchecked(s string, i int) byte {
	return *(*byte)(unsafe.Add(unsafe.Pointer(unsafe.StringData(s)), i))
}

// getBytesUnchecked returns n bytes starting at index i without bounds checking.
// UNSAFE: Caller must ensure i+n <= len(s).
//
//go:nosplit
//go:nocheckptr
func getBytesUnchecked(s string, i, n int) string {
	if n == 0 {
		return ""
	}
	return unsafe.String((*byte)(unsafe.Add(unsafe.Pointer(unsafe.StringData(s)), i)), n)
}

// sliceByteUnchecked returns s[i:j] without bounds checking.
// UNSAFE: Caller must ensure 0 <= i <= j <= len(s).
//
//go:nosplit
//go:nocheckptr
func sliceByteUnchecked(s string, i, j int) string {
	return unsafe.String((*byte)(unsafe.Add(unsafe.Pointer(unsafe.StringData(s)), i)), j-i)
}

// readUint64 reads a uint64 from string at offset i (8 bytes, little-endian on most platforms).
// UNSAFE: Caller must ensure i+8 <= len(s).
//
//go:nosplit
//go:nocheckptr
func readUint64(s string, i int) uint64 {
	return *(*uint64)(unsafe.Add(unsafe.Pointer(unsafe.StringData(s)), i))
}

// readUint32 reads a uint32 from string at offset i (4 bytes).
// UNSAFE: Caller must ensure i+4 <= len(s).
//
//go:nosplit
//go:nocheckptr
func readUint32(s string, i int) uint32 {
	return *(*uint32)(unsafe.Add(unsafe.Pointer(unsafe.StringData(s)), i))
}

// readUint16 reads a uint16 from string at offset i (2 bytes).
// UNSAFE: Caller must ensure i+2 <= len(s).
//
//go:nosplit
//go:nocheckptr
func readUint16(s string, i int) uint16 {
	return *(*uint16)(unsafe.Add(unsafe.Pointer(unsafe.StringData(s)), i))
}

// writeByteUnchecked writes a byte to buffer at index i without bounds checking.
// UNSAFE: Caller must ensure i < len(buf).
//
//go:nosplit
//go:nocheckptr
func writeByteUnchecked(buf []byte, i int, b byte) {
	*(*byte)(unsafe.Add(unsafe.Pointer(unsafe.SliceData(buf)), i)) = b
}

// writeUint64 writes a uint64 to buffer at offset i (8 bytes).
// UNSAFE: Caller must ensure i+8 <= len(buf).
//
//go:nosplit
//go:nocheckptr
func writeUint64(buf []byte, i int, v uint64) {
	*(*uint64)(unsafe.Add(unsafe.Pointer(unsafe.SliceData(buf)), i)) = v
}

// writeUint32 writes a uint32 to buffer at offset i (4 bytes).
// UNSAFE: Caller must ensure i+4 <= len(buf).
//
//go:nosplit
//go:nocheckptr
func writeUint32(buf []byte, i int, v uint32) {
	*(*uint32)(unsafe.Add(unsafe.Pointer(unsafe.SliceData(buf)), i)) = v
}

// writeUint16 writes a uint16 to buffer at offset i (2 bytes).
// UNSAFE: Caller must ensure i+2 <= len(buf).
//
//go:nosplit
//go:nocheckptr
func writeUint16(buf []byte, i int, v uint16) {
	*(*uint16)(unsafe.Add(unsafe.Pointer(unsafe.SliceData(buf)), i)) = v
}

// noescape hides a pointer from escape analysis. noescape is
// the identity function but escape analysis doesn't think the
// output depends on the input. noescape is inlined and currently
// compiles down to zero instructions.
//
//go:nosplit
//go:nocheckptr
func noescape(p unsafe.Pointer) unsafe.Pointer {
	x := uintptr(p)
	return unsafe.Pointer(x ^ 0)
}

// fastEqual8 compares 8 bytes for equality using uint64.
// Much faster than byte-by-byte comparison.
// UNSAFE: Caller must ensure len(a) >= i+8 and len(b) >= j+8.
//
//go:nosplit
//go:nocheckptr
func fastEqual8(a string, i int, b string, j int) bool {
	return readUint64(a, i) == readUint64(b, j)
}

// fastEqual4 compares 4 bytes for equality using uint32.
// UNSAFE: Caller must ensure len(a) >= i+4 and len(b) >= j+4.
//
//go:nosplit
//go:nocheckptr
func fastEqual4(a string, i int, b string, j int) bool {
	return readUint32(a, i) == readUint32(b, j)
}

// isDigitFast checks if byte is a digit ('0'-'9') without bounds.
// This is inlined and compiles to just 2 instructions.
//
//go:nosplit
func isDigitFast(b byte) bool {
	return b-'0' < 10
}

// isHexDigitFast checks if byte is a hex digit.
//
//go:nosplit
func isHexDigitFast(b byte) bool {
	return isDigitFast(b) || (b|32)-'a' < 6
}

// digitValue returns the numeric value of a digit byte.
// UNSAFE: Caller must ensure isDigitFast(b) is true.
//
//go:nosplit
func digitValue(b byte) int {
	return int(b - '0')
}

// hexDigitValue returns the numeric value of a hex digit byte.
// UNSAFE: Caller must ensure isHexDigitFast(b) is true.
//
//go:nosplit
func hexDigitValue(b byte) int {
	if b <= '9' {
		return int(b - '0')
	}
	return int((b|32)-'a') + 10
}

// skipSpacesUnsafe skips leading spaces and returns the new offset.
// Uses unsafe operations for speed.
//
//go:nosplit
func skipSpacesUnsafe(s string) int {
	i := 0
	n := len(s)
	// Unroll by 4 for better performance
	for i+4 <= n {
		// Load 4 bytes at once
		if i+4 <= n {
			b := readUint32(s, i)
			// Check if all 4 bytes are spaces (0x20)
			if b == 0x20202020 {
				i += 4
				continue
			}
		}
		break
	}
	// Handle remaining bytes
	for i < n && s[i] == ' ' {
		i++
	}
	return i
}

// mulOverflow checks if a*b would overflow uint64.
// Returns true if overflow would occur.
//
//go:nosplit
func mulOverflow(a, b uint64) bool {
	if a == 0 || b == 0 {
		return false
	}
	c := a * b
	return c/a != b
}

// addOverflow checks if a+b would overflow uint64.
//
//go:nosplit
func addOverflow(a, b uint64) bool {
	return a > ^b
}

// clz64 counts leading zeros in a uint64.
// This should compile to a single instruction on most platforms.
//
//go:nosplit
func clz64(x uint64) int {
	if x == 0 {
		return 64
	}
	n := 0
	if x <= 0x00000000FFFFFFFF {
		n += 32
		x <<= 32
	}
	if x <= 0x0000FFFFFFFFFFFF {
		n += 16
		x <<= 16
	}
	if x <= 0x00FFFFFFFFFFFFFF {
		n += 8
		x <<= 8
	}
	if x <= 0x0FFFFFFFFFFFFFFF {
		n += 4
		x <<= 4
	}
	if x <= 0x3FFFFFFFFFFFFFFF {
		n += 2
		x <<= 2
	}
	if x <= 0x7FFFFFFFFFFFFFFF {
		n += 1
	}
	return n
}

// ctz64 counts trailing zeros in a uint64.
//
//go:nosplit
func ctz64(x uint64) int {
	if x == 0 {
		return 64
	}
	n := 0
	if (x & 0x00000000FFFFFFFF) == 0 {
		n += 32
		x >>= 32
	}
	if (x & 0x000000000000FFFF) == 0 {
		n += 16
		x >>= 16
	}
	if (x & 0x00000000000000FF) == 0 {
		n += 8
		x >>= 8
	}
	if (x & 0x000000000000000F) == 0 {
		n += 4
		x >>= 4
	}
	if (x & 0x0000000000000003) == 0 {
		n += 2
		x >>= 2
	}
	if (x & 0x0000000000000001) == 0 {
		n += 1
	}
	return n
}

