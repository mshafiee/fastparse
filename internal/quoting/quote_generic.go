// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package quoting

// hasASM indicates whether assembly implementation is available
const hasASM = false

// needsEscapingASM is not available on this platform
func needsEscapingASM(s string, quote byte, mode int) bool {
	panic("unreachable")
}

// needsEscapingOptimized is the same as ASM version on non-amd64
func needsEscapingOptimized(s string, quote byte, mode int) bool {
	return needsEscapingASM(s, quote, mode)
}
