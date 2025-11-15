// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package classifier

// Classify uses the pure Go classifier implementation for non-optimized architectures.
func Classify(s string) Pattern {
	return ClassifyPureGo(s)
}

