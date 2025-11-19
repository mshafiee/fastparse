// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package eisel_lemire

// TryParse for architectures without assembly optimizations.
func TryParse(mantissa uint64, exp10 int) (float64, bool) {
	return tryParseFallback(mantissa, exp10)
}
