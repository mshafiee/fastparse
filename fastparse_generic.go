// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// minEiselLemireExp defines the minimum base-10 exponent for which we attempt
// the Eisel-Lemire optimization.
const minEiselLemireExp = -307

// parseFloat provides a generic fallback for architectures without
// assembly-optimized implementations (e.g., 386, wasm, etc.)
func parseFloat(s string) (float64, error) {
	return parseFloatGeneric(s)
}

