// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

import (
	"fmt"
	"strconv"
	"testing"
)

// SIMD-specific benchmarks to measure the impact of AVX2/AVX-512 optimizations

// BenchmarkParseFloatSIMD benchmarks float parsing with various string lengths
func BenchmarkParseFloatSIMD(b *testing.B) {
	testCases := []struct {
		name string
		s    string
	}{
		{"Short_4digits", "1234"},
		{"Medium_8digits", "12345678"},
		{"Long_16digits", "1234567890123456"},
		{"VeryLong_32digits", "12345678901234567890123456789012"},
		{"Decimal_Simple", "123.456"},
		{"Decimal_Long", "123.45678901234567890123456789"},
		{"Scientific", "1.23e10"},
		{"Scientific_Long", "1.234567890123456789e100"},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = ParseFloat(tc.s, 64)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = strconv.ParseFloat(tc.s, 64)
			}
		})
	}
}

// BenchmarkParseIntSIMD benchmarks integer parsing with various lengths
func BenchmarkParseIntSIMD(b *testing.B) {
	testCases := []struct {
		name string
		s    string
	}{
		{"Short_4digits", "1234"},
		{"Medium_8digits", "12345678"},
		{"Long_16digits", "1234567890123456"},
		{"MaxInt64_19digits", "9223372036854775807"},
		{"Negative_Long", "-1234567890123456"},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = ParseInt(tc.s, 10, 64)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = strconv.ParseInt(tc.s, 10, 64)
			}
		})
	}
}

// BenchmarkParseUintSIMD benchmarks unsigned integer parsing
func BenchmarkParseUintSIMD(b *testing.B) {
	testCases := []struct {
		name string
		s    string
	}{
		{"Short_4digits", "1234"},
		{"Medium_8digits", "12345678"},
		{"Long_16digits", "1234567890123456"},
		{"MaxUint64_20digits", "18446744073709551615"},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = ParseUint(tc.s, 10, 64)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = strconv.ParseUint(tc.s, 10, 64)
			}
		})
	}
}

// BenchmarkQuoteSIMD benchmarks quote escaping detection with various string lengths
func BenchmarkQuoteSIMD(b *testing.B) {
	// Generate test strings of various lengths
	testCases := []struct {
		name string
		s    string
	}{
		{"Short_ASCII", "hello world"},
		{"Medium_ASCII_32bytes", "this is a 32 byte ASCII string"},
		{"Long_ASCII_64bytes", "this is a much longer ASCII string that takes up 64 bytes of data"},
		{"VeryLong_ASCII_128bytes", "this is an even longer ASCII string designed to test SIMD performance with strings that are 128 bytes long and contain no special characters"},
		{"WithEscapes", "hello \"world\" with\nescapes"},
		{"NonASCII", "hello 世界 мир"},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_ = Quote(tc.s)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_ = strconv.Quote(tc.s)
			}
		})
	}
}

// BenchmarkCPUDetection benchmarks the CPU feature detection
func BenchmarkCPUDetection(b *testing.B) {
	b.Run("HasAVX2", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = HasAVX2()
		}
	})
	
	b.Run("HasAVX512", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			_ = HasAVX512()
		}
	})
}

// BenchmarkFloat32Rounding benchmarks the native float32 rounding
func BenchmarkFloat32Rounding(b *testing.B) {
	testCases := []struct {
		name string
		s    string
	}{
		{"Simple", "123.456"},
		{"Scientific", "1.23e10"},
		{"Small", "1.23e-10"},
		{"Large", "1.23e30"},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = ParseFloat(tc.s, 32)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_, _ = strconv.ParseFloat(tc.s, 32)
			}
		})
	}
}

// BenchmarkFormatIntSIMD benchmarks integer formatting
func BenchmarkFormatIntSIMD(b *testing.B) {
	testCases := []struct {
		name  string
		value int64
		base  int
	}{
		{"Base10_Small", 1234, 10},
		{"Base10_Large", 1234567890123456, 10},
		{"Base16_Small", 0xABCD, 16},
		{"Base16_Large", 0x7BCDEF0123456789, 16},
		{"Base2_Small", 255, 2},
		{"Base8_Small", 0777, 8},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_ = FormatInt(tc.value, tc.base)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				_ = strconv.FormatInt(tc.value, tc.base)
			}
		})
	}
}

// BenchmarkAppendIntSIMD benchmarks integer appending
func BenchmarkAppendIntSIMD(b *testing.B) {
	dst := make([]byte, 0, 100)
	
	testCases := []struct {
		name  string
		value int64
		base  int
	}{
		{"Base10_Small", 1234, 10},
		{"Base10_Large", 1234567890123456, 10},
		{"Base16_Large", 0x7BCDEF0123456789, 16},
	}
	
	for _, tc := range testCases {
		b.Run("FastParse_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				dst = dst[:0]
				dst = AppendInt(dst, tc.value, tc.base)
			}
		})
		
		b.Run("Strconv_"+tc.name, func(b *testing.B) {
			b.ReportAllocs()
			for i := 0; i < b.N; i++ {
				dst = dst[:0]
				dst = strconv.AppendInt(dst, tc.value, tc.base)
			}
		})
	}
}

// Print CPU feature support on test run
func init() {
	if testing.Testing() {
		fmt.Printf("CPU Features: AVX2=%v, AVX-512=%v\n", HasAVX2(), HasAVX512())
	}
}

