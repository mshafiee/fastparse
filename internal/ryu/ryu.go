// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package ryu implements the Ryū algorithm for fast float-to-string conversion.
// Ryū is currently the fastest known algorithm for converting floating-point numbers
// to their shortest decimal string representation.
//
// Reference: "Ryū: fast float-to-string conversion" by Ulf Adams (2018)
// https://dl.acm.org/doi/10.1145/3192366.3192369
package ryu

// This is a pragmatic hybrid implementation:
// - Uses Ryū-inspired optimizations for the hot path (shortest representation)
// - Delegates to strconv for complex format specifiers
// - Provides significant speedup for common cases while maintaining correctness
//
// A full production implementation would include:
// - Complete power-of-5 lookup tables (generated offline)
// - Assembly optimizations for critical paths
// - Full support for all format modes without strconv delegation
//
// The current implementation focuses on:
// 1. Correctness (matches strconv behavior exactly)
// 2. Performance for common cases (shortest representation)
// 3. Code maintainability and simplicity

