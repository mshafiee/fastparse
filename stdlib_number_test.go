// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: These tests are focused mainly on generating the right errors.
// The extensive numerical tests are in ../internal/strconv.
// Add new tests there instead of here whenever possible.

package fastparse_test

import (
	"bytes"
	"errors"
	"math"
	"math/cmplx"
	"reflect"
	"testing"

	"github.com/mshafiee/fastparse"
)

func TestAppendBoolNumber(t *testing.T) {
	appendBoolTests := []struct {
		b   bool
		in  []byte
		out []byte
	}{
		{true, []byte("foo "), []byte("foo true")},
		{false, []byte("foo "), []byte("foo false")},
	}
	for _, test := range appendBoolTests {
		b := fastparse.AppendBool(test.in, test.b)
		if !bytes.Equal(b, test.out) {
			t.Errorf("AppendBool(%q, %v) = %q; want %q", test.in, test.b, b, test.out)
		}
	}
}

func TestParseComplexNumber(t *testing.T) {
	infp0 := complex(math.Inf(+1), 0)
	infm0 := complex(math.Inf(-1), 0)
	inf0p := complex(0, math.Inf(+1))
	inf0m := complex(0, math.Inf(-1))
	infpp := complex(math.Inf(+1), math.Inf(+1))
	infpm := complex(math.Inf(+1), math.Inf(-1))
	infmp := complex(math.Inf(-1), math.Inf(+1))
	infmm := complex(math.Inf(-1), math.Inf(-1))

	tests := []atocTest{
		// Clearly invalid
		{"", 0, fastparse.ErrSyntax},
		{" ", 0, fastparse.ErrSyntax},
		{"(", 0, fastparse.ErrSyntax},
		{")", 0, fastparse.ErrSyntax},
		{"i", 0, fastparse.ErrSyntax},
		{"+i", 0, fastparse.ErrSyntax},
		{"-i", 0, fastparse.ErrSyntax},
		{"1I", 0, fastparse.ErrSyntax},
		{"10  + 5i", 0, fastparse.ErrSyntax},
		{"3+", 0, fastparse.ErrSyntax},
		{"3+5", 0, fastparse.ErrSyntax},
		{"3+5+5i", 0, fastparse.ErrSyntax},

		// Parentheses
		{"()", 0, fastparse.ErrSyntax},
		{"(i)", 0, fastparse.ErrSyntax},
		{"(0)", 0, nil},
		{"(1i)", 1i, nil},
		{"(3.0+5.5i)", 3.0 + 5.5i, nil},
		{"(1)+1i", 0, fastparse.ErrSyntax},
		{"(3.0+5.5i", 0, fastparse.ErrSyntax},
		{"3.0+5.5i)", 0, fastparse.ErrSyntax},

		// NaNs
		{"NaN", complex(math.NaN(), 0), nil},
		{"NANi", complex(0, math.NaN()), nil},
		{"nan+nAni", complex(math.NaN(), math.NaN()), nil},
		{"+NaN", 0, fastparse.ErrSyntax},
		{"-NaN", 0, fastparse.ErrSyntax},
		{"NaN-NaNi", 0, fastparse.ErrSyntax},

		// Infs
		{"Inf", infp0, nil},
		{"+inf", infp0, nil},
		{"-inf", infm0, nil},
		{"Infinity", infp0, nil},
		{"+INFINITY", infp0, nil},
		{"-infinity", infm0, nil},
		{"+infi", inf0p, nil},
		{"0-infinityi", inf0m, nil},
		{"Inf+Infi", infpp, nil},
		{"+Inf-Infi", infpm, nil},
		{"-Infinity+Infi", infmp, nil},
		{"inf-inf", 0, fastparse.ErrSyntax},

		// Zeros
		{"0", 0, nil},
		{"0i", 0, nil},
		{"-0.0i", 0, nil},
		{"0+0.0i", 0, nil},
		{"0e+0i", 0, nil},
		{"0e-0+0i", 0, nil},
		{"-0.0-0.0i", 0, nil},
		{"0e+012345", 0, nil},
		{"0x0p+012345i", 0, nil},
		{"0x0.00p-012345i", 0, nil},
		{"+0e-0+0e-0i", 0, nil},
		{"0e+0+0e+0i", 0, nil},
		{"-0e+0-0e+0i", 0, nil},

		// Regular non-zeroes
		{"0.1", 0.1, nil},
		{"0.1i", 0 + 0.1i, nil},
		{"0.123", 0.123, nil},
		{"0.123i", 0 + 0.123i, nil},
		{"0.123+0.123i", 0.123 + 0.123i, nil},
		{"99", 99, nil},
		{"+99", 99, nil},
		{"-99", -99, nil},
		{"+1i", 1i, nil},
		{"-1i", -1i, nil},
		{"+3+1i", 3 + 1i, nil},
		{"30+3i", 30 + 3i, nil},
		{"+3e+3-3e+3i", 3e+3 - 3e+3i, nil},
		{"+3e+3+3e+3i", 3e+3 + 3e+3i, nil},
		{"+3e+3+3e+3i+", 0, fastparse.ErrSyntax},

		// Separators
		{"0.1", 0.1, nil},
		{"0.1i", 0 + 0.1i, nil},
		{"0.1_2_3", 0.123, nil},
		{"+0x_3p3i", 0x3p3i, nil},
		{"0_0+0x_0p0i", 0, nil},
		{"0x_10.3p-8+0x3p3i", 0x10.3p-8 + 0x3p3i, nil},
		{"+0x_1_0.3p-8+0x_3_0p3i", 0x10.3p-8 + 0x30p3i, nil},
		{"0x1_0.3p+8-0x_3p3i", 0x10.3p+8 - 0x3p3i, nil},

		// Hexadecimals
		{"0x10.3p-8+0x3p3i", 0x10.3p-8 + 0x3p3i, nil},
		{"+0x10.3p-8+0x3p3i", 0x10.3p-8 + 0x3p3i, nil},
		{"0x10.3p+8-0x3p3i", 0x10.3p+8 - 0x3p3i, nil},
		{"0x1p0", 1, nil},
		{"0x1p1", 2, nil},
		{"0x1p-1", 0.5, nil},
		{"0x1ep-1", 15, nil},
		{"-0x1ep-1", -15, nil},
		{"-0x2p3", -16, nil},
		{"0x1e2", 0, fastparse.ErrSyntax},
		{"1p2", 0, fastparse.ErrSyntax},
		{"0x1e2i", 0, fastparse.ErrSyntax},

		// ErrRange
		// next float64 - too large
		{"+0x1p1024", infp0, fastparse.ErrRange},
		{"-0x1p1024", infm0, fastparse.ErrRange},
		{"+0x1p1024i", inf0p, fastparse.ErrRange},
		{"-0x1p1024i", inf0m, fastparse.ErrRange},
		{"+0x1p1024+0x1p1024i", infpp, fastparse.ErrRange},
		{"+0x1p1024-0x1p1024i", infpm, fastparse.ErrRange},
		{"-0x1p1024+0x1p1024i", infmp, fastparse.ErrRange},
		{"-0x1p1024-0x1p1024i", infmm, fastparse.ErrRange},
		// the border is ...158079
		// borderline - okay
		{"+0x1.fffffffffffff7fffp1023+0x1.fffffffffffff7fffp1023i", 1.7976931348623157e+308 + 1.7976931348623157e+308i, nil},
		{"+0x1.fffffffffffff7fffp1023-0x1.fffffffffffff7fffp1023i", 1.7976931348623157e+308 - 1.7976931348623157e+308i, nil},
		{"-0x1.fffffffffffff7fffp1023+0x1.fffffffffffff7fffp1023i", -1.7976931348623157e+308 + 1.7976931348623157e+308i, nil},
		{"-0x1.fffffffffffff7fffp1023-0x1.fffffffffffff7fffp1023i", -1.7976931348623157e+308 - 1.7976931348623157e+308i, nil},
		// borderline - too large
		{"+0x1.fffffffffffff8p1023", infp0, fastparse.ErrRange},
		{"-0x1fffffffffffff.8p+971", infm0, fastparse.ErrRange},
		{"+0x1.fffffffffffff8p1023i", inf0p, fastparse.ErrRange},
		{"-0x1fffffffffffff.8p+971i", inf0m, fastparse.ErrRange},
		{"+0x1.fffffffffffff8p1023+0x1.fffffffffffff8p1023i", infpp, fastparse.ErrRange},
		{"+0x1.fffffffffffff8p1023-0x1.fffffffffffff8p1023i", infpm, fastparse.ErrRange},
		{"-0x1fffffffffffff.8p+971+0x1fffffffffffff.8p+971i", infmp, fastparse.ErrRange},
		{"-0x1fffffffffffff8p+967-0x1fffffffffffff8p+967i", infmm, fastparse.ErrRange},
		// a little too large
		{"1e308+1e308i", 1e+308 + 1e+308i, nil},
		{"2e308+2e308i", infpp, fastparse.ErrRange},
		{"1e309+1e309i", infpp, fastparse.ErrRange},
		{"0x1p1025+0x1p1025i", infpp, fastparse.ErrRange},
		{"2e308", infp0, fastparse.ErrRange},
		{"1e309", infp0, fastparse.ErrRange},
		{"0x1p1025", infp0, fastparse.ErrRange},
		{"2e308i", inf0p, fastparse.ErrRange},
		{"1e309i", inf0p, fastparse.ErrRange},
		{"0x1p1025i", inf0p, fastparse.ErrRange},
		// way too large
		{"+1e310+1e310i", infpp, fastparse.ErrRange},
		{"+1e310-1e310i", infpm, fastparse.ErrRange},
		{"-1e310+1e310i", infmp, fastparse.ErrRange},
		{"-1e310-1e310i", infmm, fastparse.ErrRange},
		// under/overflow exponent
		{"1e-4294967296", 0, nil},
		{"1e-4294967296i", 0, nil},
		{"1e-4294967296+1i", 1i, nil},
		{"1+1e-4294967296i", 1, nil},
		{"1e-4294967296+1e-4294967296i", 0, nil},
		{"1e+4294967296", infp0, fastparse.ErrRange},
		{"1e+4294967296i", inf0p, fastparse.ErrRange},
		{"1e+4294967296+1e+4294967296i", infpp, fastparse.ErrRange},
		{"1e+4294967296-1e+4294967296i", infpm, fastparse.ErrRange},
	}
	for i := range tests {
		test := &tests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{Func: "ParseComplex", Num: test.in, Err: test.err}
		}
		got, err := fastparse.ParseComplex(test.in, 128)
		if !reflect.DeepEqual(err, test.err) {
			t.Fatalf("ParseComplex(%q, 128) = %v, %v; want %v, %v", test.in, got, err, test.out, test.err)
		}
		if !(cmplx.IsNaN(test.out) && cmplx.IsNaN(got)) && got != test.out {
			t.Fatalf("ParseComplex(%q, 128) = %v, %v; want %v, %v", test.in, got, err, test.out, test.err)
		}

		if complex128(complex64(test.out)) == test.out {
			got, err := fastparse.ParseComplex(test.in, 64)
			if !reflect.DeepEqual(err, test.err) {
				t.Fatalf("ParseComplex(%q, 64) = %v, %v; want %v, %v", test.in, got, err, test.out, test.err)
			}
			got64 := complex64(got)
			if complex128(got64) != test.out {
				t.Fatalf("ParseComplex(%q, 64) = %v, %v; want %v, %v", test.in, got, err, test.out, test.err)
			}
		}
	}
}

// Issue 42297: allow ParseComplex(s, not_32_or_64) for legacy reasons
func TestParseComplexIncorrectBitSizeNumber(t *testing.T) {
	const s = "1.5e308+1.0e307i"
	const want = 1.5e308 + 1.0e307i

	for _, bitSize := range []int{0, 10, 100, 256} {
		c, err := fastparse.ParseComplex(s, bitSize)
		if err != nil {
			t.Fatalf("ParseComplex(%q, %d) gave error %s", s, bitSize, err)
		}
		if c != want {
			t.Fatalf("ParseComplex(%q, %d) = %g (expected %g)", s, bitSize, c, want)
		}
	}
}

func TestAtofNumber(t *testing.T) {
	for i := 0; i < len(atoftests); i++ {
		test := &atoftests[i]
		out, err := fastparse.ParseFloat(test.in, 64)
		outs := fastparse.FormatFloat(out, 'g', -1, 64)
		if outs != test.out || !equalInnerError(test.err, err) {
			t.Errorf("ParseFloat(%v, 64) = %v, %v want %v, %v",
				test.in, out, err, test.out, test.err)
		}

		if float64(float32(out)) == out {
			out, err := fastparse.ParseFloat(test.in, 32)
			out32 := float32(out)
			if float64(out32) != out {
				t.Errorf("ParseFloat(%v, 32) = %v, not a float32 (closest is %v)", test.in, out, float64(out32))
				continue
			}
			outs := fastparse.FormatFloat(float64(out32), 'g', -1, 32)
			if outs != test.out || !equalInnerError(test.err, err) {
				t.Errorf("ParseFloat(%v, 32) = %v, %v want %v, %v  # %v",
					test.in, out32, err, test.out, test.err, out)
			}
		}
	}
}

func init() {
	// The parse routines return NumErrors wrapping
	// the error and the string. Convert the tables above.
	for i := range parseUint64Tests {
		test := &parseUint64Tests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{"ParseUint", test.in, test.err}
		}
	}
	for i := range parseUint64BaseTests {
		test := &parseUint64BaseTests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{"ParseUint", test.in, test.err}
		}
	}
	for i := range parseInt64Tests {
		test := &parseInt64Tests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{"ParseInt", test.in, test.err}
		}
	}
	for i := range parseInt64BaseTests {
		test := &parseInt64BaseTests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{"ParseInt", test.in, test.err}
		}
	}
	for i := range parseUint32Tests {
		test := &parseUint32Tests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{"ParseUint", test.in, test.err}
		}
	}
	for i := range parseInt32Tests {
		test := &parseInt32Tests[i]
		if test.err != nil {
			test.err = &fastparse.NumError{"ParseInt", test.in, test.err}
		}
	}
}

func TestParseUint64BaseNumber(t *testing.T) {
	for i := range parseUint64BaseTests {
		test := &parseUint64BaseTests[i]
		out, err := fastparse.ParseUint(test.in, test.base, 64)
		if test.out != out || !equalInnerError(test.err, err) {
			t.Errorf("ParseUint(%q, %v, 64) = %v, %v want %v, %v",
				test.in, test.base, out, err, test.out, test.err)
		}
	}
}

func TestParseInt32Number(t *testing.T) {
	for i := range parseInt32Tests {
		test := &parseInt32Tests[i]
		out, err := fastparse.ParseInt(test.in, 10, 32)
		errForCompare := extractInnerError(err)
		testErrForCompare := extractInnerError(test.err)
		if int64(test.out) != out || !reflect.DeepEqual(testErrForCompare, errForCompare) {
			t.Errorf("ParseInt(%q, 10 ,32) = %v, %v want %v, %v",
				test.in, out, err, test.out, test.err)
		}
	}
}

func TestParseInt64BaseNumber(t *testing.T) {
	for i := range parseInt64BaseTests {
		test := &parseInt64BaseTests[i]
		out, err := fastparse.ParseInt(test.in, test.base, 64)
		if test.out != out || !equalInnerError(test.err, err) {
			t.Errorf("ParseInt(%q, %v, 64) = %v, %v want %v, %v",
				test.in, test.base, out, err, test.out, test.err)
		}
	}
}

func TestAtoiNumber(t *testing.T) {
	switch fastparse.IntSize {
	case 32:
		for i := range parseInt32Tests {
			test := &parseInt32Tests[i]
			out, err := fastparse.Atoi(test.in)
			var testErr error
			if test.err != nil {
				testErr = &fastparse.NumError{"Atoi", test.in, extractInnerError(test.err)}
			}
			if int(test.out) != out || !equalInnerError(testErr, err) {
				t.Errorf("Atoi(%q) = %v, %v want %v, %v",
					test.in, out, err, test.out, testErr)
			}
		}
	case 64:
		for i := range parseInt64Tests {
			test := &parseInt64Tests[i]
			out, err := fastparse.Atoi(test.in)
			var testErr error
			if test.err != nil {
				testErr = &fastparse.NumError{"Atoi", test.in, extractInnerError(test.err)}
			}
			if test.out != int64(out) || !equalInnerError(testErr, err) {
				t.Errorf("Atoi(%q) = %v, %v want %v, %v",
					test.in, out, err, test.out, testErr)
			}
		}
	}
}

func TestParseIntBitSizeNumber(t *testing.T) {
	for i := range parseBitSizeTests {
		test := &parseBitSizeTests[i]
		testErr := test.errStub("ParseInt", test.arg)
		_, err := fastparse.ParseInt("0", 0, test.arg)
		if !equalError(testErr, err) {
			t.Errorf("ParseInt(\"0\", 0, %v) = 0, %v want 0, %v",
				test.arg, err, testErr)
		}
	}
}

func TestParseUintBitSizeNumber(t *testing.T) {
	for i := range parseBitSizeTests {
		test := &parseBitSizeTests[i]
		testErr := test.errStub("ParseUint", test.arg)
		_, err := fastparse.ParseUint("0", 0, test.arg)
		if !equalError(testErr, err) {
			t.Errorf("ParseUint(\"0\", 0, %v) = 0, %v want 0, %v",
				test.arg, err, testErr)
		}
	}
}

func TestParseIntBaseNumber(t *testing.T) {
	for i := range parseBaseTests {
		test := &parseBaseTests[i]
		testErr := test.errStub("ParseInt", test.arg)
		_, err := fastparse.ParseInt("0", test.arg, 0)
		if !equalError(testErr, err) {
			t.Errorf("ParseInt(\"0\", %v, 0) = 0, %v want 0, %v",
				test.arg, err, testErr)
		}
	}
}

func TestParseUintBaseNumber(t *testing.T) {
	for i := range parseBaseTests {
		test := &parseBaseTests[i]
		testErr := test.errStub("ParseUint", test.arg)
		_, err := fastparse.ParseUint("0", test.arg, 0)
		if !equalError(testErr, err) {
			t.Errorf("ParseUint(\"0\", %v, 0) = 0, %v want 0, %v",
				test.arg, err, testErr)
		}
	}
}

func TestNumError(t *testing.T) {
	for _, test := range numErrorTests {
		err := &fastparse.NumError{
			Func: "ParseFloat",
			Num:  test.num,
			Err:  errors.New("failed"),
		}
		if got := err.Error(); got != test.want {
			t.Errorf(`(&NumError{"ParseFloat", %q, "failed"}).Error() = %v, want %v`, test.num, got, test.want)
		}
	}
}

func TestNumErrorUnwrap(t *testing.T) {
	err := &fastparse.NumError{Err: fastparse.ErrSyntax}
	if !errors.Is(err, fastparse.ErrSyntax) {
		t.Error("errors.Is failed, wanted success")
	}
}

func TestFormatComplex(t *testing.T) {
	tests := []struct {
		c       complex128
		fmt     byte
		prec    int
		bitSize int
		out     string
	}{
		// a variety of signs
		{1 + 2i, 'g', -1, 128, "(1+2i)"},
		{3 - 4i, 'g', -1, 128, "(3-4i)"},
		{-5 + 6i, 'g', -1, 128, "(-5+6i)"},
		{-7 - 8i, 'g', -1, 128, "(-7-8i)"},

		// test that fmt and prec are working
		{3.14159 + 0.00123i, 'e', 3, 128, "(3.142e+00+1.230e-03i)"},
		{3.14159 + 0.00123i, 'f', 3, 128, "(3.142+0.001i)"},
		{3.14159 + 0.00123i, 'g', 3, 128, "(3.14+0.00123i)"},

		// ensure bitSize rounding is working
		{1.2345678901234567 + 9.876543210987654i, 'f', -1, 128, "(1.2345678901234567+9.876543210987654i)"},
		{1.2345678901234567 + 9.876543210987654i, 'f', -1, 64, "(1.2345679+9.876543i)"},

		// other cases are handled by FormatFloat tests
	}
	for _, test := range tests {
		out := fastparse.FormatComplex(test.c, test.fmt, test.prec, test.bitSize)
		if out != test.out {
			t.Fatalf("FormatComplex(%v, %q, %d, %d) = %q; want %q",
				test.c, test.fmt, test.prec, test.bitSize, out, test.out)
		}
	}
}

func TestFormatComplexInvalidBitSize(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("expected panic due to invalid bitSize")
		}
	}()
	_ = fastparse.FormatComplex(1+2i, 'g', -1, 100)
}

func TestItoaNumber(t *testing.T) {
	itob64tests := []struct {
		in   int64
		base int
		out  string
	}{
		{0, 10, "0"},
		{1, 10, "1"},
		{-1, 10, "-1"},
		{12345678, 10, "12345678"},
		{-1 << 63, 10, "-9223372036854775808"},
		{16, 17, "g"},
		{25, 25, "10"},
		{(((((17*36+24)*36+21)*36+34)*36+12)*36+24)*36 + 32, 36, "holycow"},
	}
	for _, test := range itob64tests {
		s := fastparse.FormatInt(test.in, test.base)
		if s != test.out {
			t.Errorf("FormatInt(%v, %v) = %v want %v",
				test.in, test.base, s, test.out)
		}
		x := fastparse.AppendInt([]byte("abc"), test.in, test.base)
		if string(x) != "abc"+test.out {
			t.Errorf("AppendInt(%q, %v, %v) = %q want %v",
				"abc", test.in, test.base, x, test.out)
		}

		if test.in >= 0 {
			s := fastparse.FormatUint(uint64(test.in), test.base)
			if s != test.out {
				t.Errorf("FormatUint(%v, %v) = %v want %v",
					test.in, test.base, s, test.out)
			}
			x := fastparse.AppendUint(nil, uint64(test.in), test.base)
			if string(x) != test.out {
				t.Errorf("AppendUint(%q, %v, %v) = %q want %v",
					"abc", uint64(test.in), test.base, x, test.out)
			}
		}

		if test.base == 10 && int64(int(test.in)) == test.in {
			s := fastparse.Itoa(int(test.in))
			if s != test.out {
				t.Errorf("Itoa(%v) = %v want %v",
					test.in, s, test.out)
			}
		}
	}

	// Override when base is illegal
	defer func() {
		if r := recover(); r == nil {
			t.Fatalf("expected panic due to illegal base")
		}
	}()
	fastparse.FormatUint(12345678, 1)
}

func TestUitoaNumber(t *testing.T) {
	uitob64tests := []struct {
		in   uint64
		base int
		out  string
	}{
		{1<<63 - 1, 10, "9223372036854775807"},
		{1 << 63, 10, "9223372036854775808"},
		{1<<63 + 1, 10, "9223372036854775809"},
		{1<<64 - 2, 10, "18446744073709551614"},
		{1<<64 - 1, 10, "18446744073709551615"},
		{1<<64 - 1, 2, "1111111111111111111111111111111111111111111111111111111111111111"},
	}
	for _, test := range uitob64tests {
		s := fastparse.FormatUint(test.in, test.base)
		if s != test.out {
			t.Errorf("FormatUint(%v, %v) = %v want %v",
				test.in, test.base, s, test.out)
		}
		x := fastparse.AppendUint([]byte("abc"), test.in, test.base)
		if string(x) != "abc"+test.out {
			t.Errorf("AppendUint(%q, %v, %v) = %q want %v",
				"abc", test.in, test.base, x, test.out)
		}

	}
}

func TestFormatUintVarlenNumber(t *testing.T) {
	varlenUints := []struct {
		in  uint64
		out string
	}{
		{1, "1"},
		{12, "12"},
		{123, "123"},
		{1234, "1234"},
		{12345, "12345"},
		{123456, "123456"},
		{1234567, "1234567"},
		{12345678, "12345678"},
		{123456789, "123456789"},
		{1234567890, "1234567890"},
		{12345678901, "12345678901"},
		{123456789012, "123456789012"},
		{1234567890123, "1234567890123"},
		{12345678901234, "12345678901234"},
		{123456789012345, "123456789012345"},
		{1234567890123456, "1234567890123456"},
		{12345678901234567, "12345678901234567"},
		{123456789012345678, "123456789012345678"},
		{1234567890123456789, "1234567890123456789"},
		{12345678901234567890, "12345678901234567890"},
	}
	for _, test := range varlenUints {
		s := fastparse.FormatUint(test.in, 10)
		if s != test.out {
			t.Errorf("FormatUint(%v, 10) = %v want %v", test.in, s, test.out)
		}
	}
}
