// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// parseInt is the entry point for generic platforms
func parseInt(s string, bitSize int) (int64, error) {
	return parseIntGeneric(s, bitSize)
}

