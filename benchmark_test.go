// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse_test

import (
	"strconv"
	"testing"

	"github.com/mshafiee/fastparse"
)

// Float formatting benchmarks

func BenchmarkFormatFloat_Fastparse_e(b *testing.B) {
	v := 3.141592653589793
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.FormatFloat(v, 'e', -1, 64)
	}
}

func BenchmarkFormatFloat_Strconv_e(b *testing.B) {
	v := 3.141592653589793
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.FormatFloat(v, 'e', -1, 64)
	}
}

func BenchmarkFormatFloat_Fastparse_f(b *testing.B) {
	v := 3.141592653589793
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.FormatFloat(v, 'f', 6, 64)
	}
}

func BenchmarkFormatFloat_Strconv_f(b *testing.B) {
	v := 3.141592653589793
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.FormatFloat(v, 'f', 6, 64)
	}
}

func BenchmarkFormatFloat_Fastparse_g(b *testing.B) {
	v := 3.141592653589793
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.FormatFloat(v, 'g', -1, 64)
	}
}

func BenchmarkFormatFloat_Strconv_g(b *testing.B) {
	v := 3.141592653589793
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.FormatFloat(v, 'g', -1, 64)
	}
}

// Integer formatting benchmarks

func BenchmarkFormatInt_Fastparse(b *testing.B) {
	v := int64(1234567890)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.FormatInt(v, 10)
	}
}

func BenchmarkFormatInt_Strconv(b *testing.B) {
	v := int64(1234567890)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.FormatInt(v, 10)
	}
}

func BenchmarkFormatUint_Fastparse(b *testing.B) {
	v := uint64(1234567890)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.FormatUint(v, 10)
	}
}

func BenchmarkFormatUint_Strconv(b *testing.B) {
	v := uint64(1234567890)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.FormatUint(v, 10)
	}
}

// Quote benchmarks

func BenchmarkQuote_Fastparse_ASCII(b *testing.B) {
	s := "Hello, World! This is a test string."
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.Quote(s)
	}
}

func BenchmarkQuote_Strconv_ASCII(b *testing.B) {
	s := "Hello, World! This is a test string."
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.Quote(s)
	}
}

func BenchmarkQuote_Fastparse_Unicode(b *testing.B) {
	s := "Hello, 世界! Привет мир! 🚀"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.Quote(s)
	}
}

func BenchmarkQuote_Strconv_Unicode(b *testing.B) {
	s := "Hello, 世界! Привет мир! 🚀"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.Quote(s)
	}
}

func BenchmarkQuoteToASCII_Fastparse(b *testing.B) {
	s := "Hello, 世界! Привет мир!"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.QuoteToASCII(s)
	}
}

func BenchmarkQuoteToASCII_Strconv(b *testing.B) {
	s := "Hello, 世界! Привет мир!"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.QuoteToASCII(s)
	}
}

// Unquote benchmarks

func BenchmarkUnquote_Fastparse(b *testing.B) {
	s := `"Hello, World! This is a test string."`
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = fastparse.Unquote(s)
	}
}

func BenchmarkUnquote_Strconv(b *testing.B) {
	s := `"Hello, World! This is a test string."`
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = strconv.Unquote(s)
	}
}

// Complex number benchmarks

func BenchmarkFormatComplex_Fastparse(b *testing.B) {
	c := complex(3.14, 2.71)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.FormatComplex(c, 'g', -1, 128)
	}
}

func BenchmarkFormatComplex_Strconv(b *testing.B) {
	c := complex(3.14, 2.71)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.FormatComplex(c, 'g', -1, 128)
	}
}

func BenchmarkParseComplex_Fastparse(b *testing.B) {
	s := "(3.14+2.71i)"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = fastparse.ParseComplex(s, 128)
	}
}

func BenchmarkParseComplex_Strconv(b *testing.B) {
	s := "(3.14+2.71i)"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = strconv.ParseComplex(s, 128)
	}
}

// ParseFloat benchmarks (existing optimizations)

func BenchmarkParseFloat_Fastparse(b *testing.B) {
	s := "3.141592653589793"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = fastparse.ParseFloat(s, 64)
	}
}

func BenchmarkParseFloat_Strconv(b *testing.B) {
	s := "3.141592653589793"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = strconv.ParseFloat(s, 64)
	}
}

func BenchmarkParseInt_Fastparse(b *testing.B) {
	s := "1234567890"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = fastparse.ParseInt(s, 10, 64)
	}
}

func BenchmarkParseInt_Strconv(b *testing.B) {
	s := "1234567890"
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = strconv.ParseInt(s, 10, 64)
	}
}

// AppendFloat benchmarks

func BenchmarkAppendFloat_Fastparse(b *testing.B) {
	v := 3.141592653589793
	buf := make([]byte, 0, 32)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		buf = buf[:0]
		buf = fastparse.AppendFloat(buf, v, 'g', -1, 64)
	}
}

func BenchmarkAppendFloat_Strconv(b *testing.B) {
	v := 3.141592653589793
	buf := make([]byte, 0, 32)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		buf = buf[:0]
		buf = strconv.AppendFloat(buf, v, 'g', -1, 64)
	}
}

// IsPrint/IsGraphic benchmarks

func BenchmarkIsPrint_Fastparse(b *testing.B) {
	r := 'A'
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.IsPrint(r)
	}
}

func BenchmarkIsPrint_Strconv(b *testing.B) {
	r := 'A'
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.IsPrint(r)
	}
}

func BenchmarkIsGraphic_Fastparse(b *testing.B) {
	r := 'A'
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fastparse.IsGraphic(r)
	}
}

func BenchmarkIsGraphic_Strconv(b *testing.B) {
	r := 'A'
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = strconv.IsGraphic(r)
	}
}
