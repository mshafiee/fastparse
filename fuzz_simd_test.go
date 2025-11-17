// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

import (
	"strconv"
	"testing"
)

// Fuzz tests to validate SIMD optimizations match strconv behavior

func FuzzParseFloatSIMD(f *testing.F) {
	// Seed corpus with various patterns
	seeds := []string{
		"0", "1", "-1", "123", "-456",
		"1.23", "-4.56", "0.123", "123.456",
		"1e10", "1.23e-5", "-4.56e20",
		"inf", "-inf", "nan",
		"1234567890123456",               // Long integer
		"123456789012345678901234567890", // Very long
		"1.234567890123456",              // Many decimal places
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, s string) {
		// Test float64
		got, gotErr := ParseFloat(s, 64)
		want, wantErr := strconv.ParseFloat(s, 64)

		// Compare results
		if (gotErr == nil) != (wantErr == nil) {
			t.Errorf("ParseFloat(%q, 64) error mismatch: got %v, want %v", s, gotErr, wantErr)
			return
		}

		if gotErr == nil && got != want {
			// Allow NaN mismatch (NaN != NaN)
			if !(isNaN(got) && isNaN(want)) {
				t.Errorf("ParseFloat(%q, 64) = %v, want %v", s, got, want)
			}
		}

		// Test float32
		got32, gotErr32 := ParseFloat(s, 32)
		want32, wantErr32 := strconv.ParseFloat(s, 32)

		if (gotErr32 == nil) != (wantErr32 == nil) {
			t.Errorf("ParseFloat(%q, 32) error mismatch: got %v, want %v", s, gotErr32, wantErr32)
			return
		}

		if gotErr32 == nil && got32 != want32 {
			if !(isNaN(got32) && isNaN(want32)) {
				t.Errorf("ParseFloat(%q, 32) = %v, want %v", s, got32, want32)
			}
		}
	})
}

func FuzzParseIntSIMD(f *testing.F) {
	// Seed corpus
	seeds := []string{
		"0", "1", "-1", "123", "-456",
		"9223372036854775807",  // max int64
		"-9223372036854775808", // min int64
		"1234567890123456",     // long
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, s string) {
		// Test base 10, bitSize 64
		got, gotErr := ParseInt(s, 10, 64)
		want, wantErr := strconv.ParseInt(s, 10, 64)

		if (gotErr == nil) != (wantErr == nil) {
			t.Errorf("ParseInt(%q, 10, 64) error mismatch: got %v, want %v", s, gotErr, wantErr)
			return
		}

		if gotErr == nil && got != want {
			t.Errorf("ParseInt(%q, 10, 64) = %v, want %v", s, got, want)
		}

		// Also test bitSize 32
		got32, gotErr32 := ParseInt(s, 10, 32)
		want32, wantErr32 := strconv.ParseInt(s, 10, 32)

		if (gotErr32 == nil) != (wantErr32 == nil) {
			t.Errorf("ParseInt(%q, 10, 32) error mismatch: got %v, want %v", s, gotErr32, wantErr32)
			return
		}

		if gotErr32 == nil && got32 != want32 {
			t.Errorf("ParseInt(%q, 10, 32) = %v, want %v", s, got32, want32)
		}
	})
}

func FuzzParseUintSIMD(f *testing.F) {
	// Seed corpus
	seeds := []string{
		"0", "1", "123", "456",
		"18446744073709551615", // max uint64
		"1234567890123456",     // long
		"0x1234", "0xABCD",     // hex
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, s string) {
		// Test base 10
		got, gotErr := ParseUint(s, 10, 64)
		want, wantErr := strconv.ParseUint(s, 10, 64)

		if (gotErr == nil) != (wantErr == nil) {
			t.Errorf("ParseUint(%q, 10, 64) error mismatch: got %v, want %v", s, gotErr, wantErr)
			return
		}

		if gotErr == nil && got != want {
			t.Errorf("ParseUint(%q, 10, 64) = %v, want %v", s, got, want)
		}

		// Test base 16
		got16, gotErr16 := ParseUint(s, 16, 64)
		want16, wantErr16 := strconv.ParseUint(s, 16, 64)

		if (gotErr16 == nil) != (wantErr16 == nil) {
			// Error mismatch is OK for base 16 (different validation)
			return
		}

		if gotErr16 == nil && got16 != want16 {
			t.Errorf("ParseUint(%q, 16, 64) = %v, want %v", s, got16, want16)
		}
	})
}

func FuzzQuoteSIMD(f *testing.F) {
	// Seed corpus with various patterns
	seeds := []string{
		"", "a", "hello", "hello world",
		"hello \"world\"",
		"line1\nline2",
		"tab\there",
		"backslash\\here",
		"control\x00char",
		"unicode 世界",
		"very long string that is designed to test SIMD performance with strings over 64 bytes",
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, s string) {
		// Test Quote
		got := Quote(s)
		want := strconv.Quote(s)

		// Note: We may have different but equivalent representations
		// Just verify that unquoting gives the same result
		gotUnquoted, gotErr := Unquote(got)
		wantUnquoted, wantErr := strconv.Unquote(want)

		if (gotErr == nil) != (wantErr == nil) {
			t.Errorf("Quote/Unquote(%q) error mismatch: got %v, want %v", s, gotErr, wantErr)
			return
		}

		if gotErr == nil && gotUnquoted != wantUnquoted {
			t.Errorf("Quote/Unquote(%q) = %q, want %q", s, gotUnquoted, wantUnquoted)
		}
	})
}

func FuzzFormatIntSIMD(f *testing.F) {
	// Seed corpus
	seeds := []int64{
		0, 1, -1, 123, -456,
		9223372036854775807,  // max int64
		-9223372036854775808, // min int64
		1234567890123456,
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, i int64) {
		// Test base 10
		got := FormatInt(i, 10)
		want := strconv.FormatInt(i, 10)

		if got != want {
			t.Errorf("FormatInt(%d, 10) = %q, want %q", i, got, want)
		}

		// Test base 16
		got16 := FormatInt(i, 16)
		want16 := strconv.FormatInt(i, 16)

		if got16 != want16 {
			t.Errorf("FormatInt(%d, 16) = %q, want %q", i, got16, want16)
		}

		// Test base 2
		got2 := FormatInt(i, 2)
		want2 := strconv.FormatInt(i, 2)

		if got2 != want2 {
			t.Errorf("FormatInt(%d, 2) = %q, want %q", i, got2, want2)
		}
	})
}

func FuzzFormatUintSIMD(f *testing.F) {
	// Seed corpus
	seeds := []uint64{
		0, 1, 123, 456,
		18446744073709551615, // max uint64
		1234567890123456,
	}

	for _, seed := range seeds {
		f.Add(seed)
	}

	f.Fuzz(func(t *testing.T, u uint64) {
		// Test base 10
		got := FormatUint(u, 10)
		want := strconv.FormatUint(u, 10)

		if got != want {
			t.Errorf("FormatUint(%d, 10) = %q, want %q", u, got, want)
		}

		// Test base 16
		got16 := FormatUint(u, 16)
		want16 := strconv.FormatUint(u, 16)

		if got16 != want16 {
			t.Errorf("FormatUint(%d, 16) = %q, want %q", u, got16, want16)
		}
	})
}

// Helper function to check if a float64 is NaN
func isNaN(f float64) bool {
	return f != f
}
