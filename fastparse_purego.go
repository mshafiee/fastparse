// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package fastparse

// parseFloat and parseInt are implemented in parse_float_generic.go
// and parse_int_generic.go for non-optimized architectures.

