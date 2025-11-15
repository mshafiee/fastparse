// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package fastparse

// parseIntFastAsm is the AMD64 assembly implementation of fast integer parsing.
// It parses simple integer patterns: [-+]?[0-9]+
// Returns (result, true) on success, (0, false) to fall back to generic implementation.
//
//go:noescape
func parseIntFastAsm(s string, bitSize int) (result int64, ok bool)

