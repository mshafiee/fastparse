// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// formatIntBase10Optimized falls back to generic implementation
func formatIntBase10Optimized(u uint64) string {
	return FormatUint(u, 10)
}

// appendIntBase10Optimized falls back to generic implementation
func appendIntBase10Optimized(dst []byte, u uint64) []byte {
	return AppendUint(dst, u, 10)
}

