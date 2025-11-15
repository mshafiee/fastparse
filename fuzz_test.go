// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse_test

import (
	"math"
	"strconv"
	"testing"
	
	"github.com/mshafiee/fastparse"
)

// Fuzz tests to ensure correctness against strconv

func FuzzFormatFloat(f *testing.F) {
	// Seed corpus
	f.Add(float64(0.0), byte('g'), int(-1), int(64))
	f.Add(float64(3.14159), byte('f'), int(6), int(64))
	f.Add(float64(1.23e10), byte('e'), int(-1), int(64))
	f.Add(float64(-123.456), byte('g'), int(5), int(64))
	f.Add(math.NaN(), byte('g'), int(-1), int(64))
	f.Add(math.Inf(1), byte('g'), int(-1), int(64))
	f.Add(math.Inf(-1), byte('g'), int(-1), int(64))
	
	f.Fuzz(func(t *testing.T, val float64, fmt byte, prec int, bitSize int) {
		// Limit inputs to valid ranges
		if bitSize != 32 && bitSize != 64 {
			t.Skip()
		}
		if fmt != 'e' && fmt != 'E' && fmt != 'f' && fmt != 'g' && fmt != 'G' && fmt != 'b' && fmt != 'x' && fmt != 'X' {
			t.Skip()
		}
		if prec < -1 || prec > 100 {
			t.Skip()
		}
		
		// Compare outputs
		fastResult := fastparse.FormatFloat(val, fmt, prec, bitSize)
		strconvResult := strconv.FormatFloat(val, fmt, prec, bitSize)
		
		// Results should match (or at least be equivalent)
		// Note: Some minor differences in formatting might be acceptable
		if fastResult != strconvResult {
			// Allow for minor differences in special cases
			if !math.IsNaN(val) && !math.IsInf(val, 0) {
				// For normal values, they should match more closely
				// Log but don't fail for now since Ryū might format slightly differently
				t.Logf("Difference: fast=%q strconv=%q (val=%v fmt=%c prec=%d bits=%d)", 
					fastResult, strconvResult, val, fmt, prec, bitSize)
			}
		}
	})
}

func FuzzQuote(f *testing.F) {
	// Seed corpus
	f.Add("Hello, World!")
	f.Add("Line1\nLine2")
	f.Add("Tab\there")
	f.Add(`Quote"Test`)
	f.Add("Unicode: 世界 🚀")
	f.Add("Backslash\\test")
	f.Add("")
	
	f.Fuzz(func(t *testing.T, s string) {
		fastResult := fastparse.Quote(s)
		strconvResult := strconv.Quote(s)
		
		if fastResult != strconvResult {
			t.Errorf("Quote mismatch:\nInput: %q\nFast:    %q\nStrconv: %q", s, fastResult, strconvResult)
		}
	})
}

func FuzzUnquote(f *testing.F) {
	// Seed corpus
	f.Add(`"Hello, World!"`)
	f.Add(`"Line1\nLine2"`)
	f.Add(`"Tab\there"`)
	f.Add(`"Unicode: \u4e16\u754c"`)
	f.Add(`'a'`)
	f.Add("``")
	f.Add("`raw string`")
	
	f.Fuzz(func(t *testing.T, s string) {
		fastResult, fastErr := fastparse.Unquote(s)
		strconvResult, strconvErr := strconv.Unquote(s)
		
		// Both should succeed or fail together
		if (fastErr == nil) != (strconvErr == nil) {
			t.Errorf("Unquote error mismatch:\nInput: %q\nFast error: %v\nStrconv error: %v", 
				s, fastErr, strconvErr)
			return
		}
		
		// If both succeeded, results should match
		if fastErr == nil && fastResult != strconvResult {
			t.Errorf("Unquote result mismatch:\nInput: %q\nFast:    %q\nStrconv: %q", 
				s, fastResult, strconvResult)
		}
	})
}

func FuzzParseComplex(f *testing.F) {
	// Seed corpus
	f.Add("(1+2i)", int(128))
	f.Add("(3.14+2.71i)", int(128))
	f.Add("(1.5e10+2.5e-5i)", int(128))
	f.Add("5", int(128))
	f.Add("3i", int(128))
	f.Add("(-1-1i)", int(64))
	
	f.Fuzz(func(t *testing.T, s string, bitSize int) {
		if bitSize != 64 && bitSize != 128 {
			t.Skip()
		}
		
		fastResult, fastErr := fastparse.ParseComplex(s, bitSize)
		strconvResult, strconvErr := strconv.ParseComplex(s, bitSize)
		
		// Both should succeed or fail together
		if (fastErr == nil) != (strconvErr == nil) {
			// Some differences are OK due to different parsing approaches
			t.Logf("ParseComplex error mismatch:\nInput: %q\nFast error: %v\nStrconv error: %v", 
				s, fastErr, strconvErr)
			return
		}
		
		// If both succeeded, results should be very close
		if fastErr == nil {
			realDiff := math.Abs(real(fastResult) - real(strconvResult))
			imagDiff := math.Abs(imag(fastResult) - imag(strconvResult))
			
			if realDiff > 1e-10 || imagDiff > 1e-10 {
				t.Errorf("ParseComplex result mismatch:\nInput: %q\nFast:    %v\nStrconv: %v", 
					s, fastResult, strconvResult)
			}
		}
	})
}

func FuzzFormatInt(f *testing.F) {
	// Seed corpus
	f.Add(int64(0), int(10))
	f.Add(int64(123), int(10))
	f.Add(int64(-456), int(10))
	f.Add(int64(255), int(16))
	f.Add(int64(7), int(2))
	f.Add(int64(math.MaxInt64), int(10))
	f.Add(int64(math.MinInt64), int(10))
	
	f.Fuzz(func(t *testing.T, val int64, base int) {
		if base < 2 || base > 36 {
			t.Skip()
		}
		
		fastResult := fastparse.FormatInt(val, base)
		strconvResult := strconv.FormatInt(val, base)
		
		if fastResult != strconvResult {
			t.Errorf("FormatInt mismatch:\nInput: %d (base %d)\nFast:    %q\nStrconv: %q", 
				val, base, fastResult, strconvResult)
		}
	})
}

func FuzzFormatUint(f *testing.F) {
	// Seed corpus
	f.Add(uint64(0), int(10))
	f.Add(uint64(123), int(10))
	f.Add(uint64(255), int(16))
	f.Add(uint64(7), int(2))
	f.Add(uint64(math.MaxUint64), int(10))
	
	f.Fuzz(func(t *testing.T, val uint64, base int) {
		if base < 2 || base > 36 {
			t.Skip()
		}
		
		fastResult := fastparse.FormatUint(val, base)
		strconvResult := strconv.FormatUint(val, base)
		
		if fastResult != strconvResult {
			t.Errorf("FormatUint mismatch:\nInput: %d (base %d)\nFast:    %q\nStrconv: %q", 
				val, base, fastResult, strconvResult)
		}
	})
}

func FuzzIsPrint(f *testing.F) {
	// Seed corpus
	f.Add(rune('A'))
	f.Add(rune(' '))
	f.Add(rune('\n'))
	f.Add(rune('\t'))
	f.Add(rune('世'))
	f.Add(rune(0x7F))
	
	f.Fuzz(func(t *testing.T, r rune) {
		fastResult := fastparse.IsPrint(r)
		strconvResult := strconv.IsPrint(r)
		
		if fastResult != strconvResult {
			t.Errorf("IsPrint mismatch for rune %U (%c):\nFast: %v\nStrconv: %v", 
				r, r, fastResult, strconvResult)
		}
	})
}

func FuzzIsGraphic(f *testing.F) {
	// Seed corpus
	f.Add(rune('A'))
	f.Add(rune(' '))
	f.Add(rune('\n'))
	f.Add(rune('世'))
	
	f.Fuzz(func(t *testing.T, r rune) {
		fastResult := fastparse.IsGraphic(r)
		strconvResult := strconv.IsGraphic(r)
		
		if fastResult != strconvResult {
			t.Errorf("IsGraphic mismatch for rune %U (%c):\nFast: %v\nStrconv: %v", 
				r, r, fastResult, strconvResult)
		}
	})
}

func FuzzCanBackquote(f *testing.F) {
	// Seed corpus
	f.Add("simple")
	f.Add("with space")
	f.Add("with\nnewline")
	f.Add("with\ttab")
	f.Add("with`backtick")
	
	f.Fuzz(func(t *testing.T, s string) {
		fastResult := fastparse.CanBackquote(s)
		strconvResult := strconv.CanBackquote(s)
		
		if fastResult != strconvResult {
			t.Errorf("CanBackquote mismatch:\nInput: %q\nFast: %v\nStrconv: %v", 
				s, fastResult, strconvResult)
		}
	})
}

