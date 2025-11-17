// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64

package fastparse

// HasAVX2 returns false on non-amd64 platforms
func HasAVX2() bool {
	return false
}

// HasAVX512 returns false on non-amd64 platforms
func HasAVX512() bool {
	return false
}
