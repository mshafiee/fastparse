// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ryu

import (
	"math"
	"math/big"
	
	"github.com/mshafiee/fastparse/internal/intformat"
)

// Format formats a float64 according to the specified format and precision.
// This handles the different format verbs: 'e', 'E', 'f', 'g', 'G', 'b', 'x', 'X'
func Format(f float64, fmt byte, prec int, bitSize int) string {
	// Validate bitSize
	if bitSize != 32 && bitSize != 64 {
		panic("fastparse: invalid bitSize")
	}
	
	// Handle special values first
	switch {
	case math.IsNaN(f):
		return "NaN"
	case math.IsInf(f, 1):
		return "+Inf"
	case math.IsInf(f, -1):
		return "-Inf"
	}
	
	// Handle bitSize 32: round to float32 precision
	if bitSize == 32 {
		f = float64(float32(f))
	}
	
	// Dispatch to appropriate formatter
	switch fmt {
	case 'e', 'E':
		return formatScientific(f, fmt, prec, bitSize)
	case 'f':
		return formatFixed(f, prec, bitSize)
	case 'g', 'G':
		return formatShortest(f, fmt, prec, bitSize)
	case 'b':
		return formatBinary(f)
	case 'x', 'X':
		return formatHex(f, fmt, prec)
	default:
		// Unknown format verb - return format string with verb (matching strconv behavior)
		return "%" + string(fmt)
	}
}

// formatScientific formats in scientific notification: [-]d.dddde±dd
func formatScientific(f float64, fmt byte, prec int, bitSize int) string {
	// Use big.Float for reliable formatting
	if prec < 0 {
		prec = 6 // Default precision
	}
	
	// Handle bitSize 32: round to float32 precision
	if bitSize == 32 {
		f = float64(float32(f))
	}
	
	bf := big.NewFloat(f).SetPrec(256)
	
	// Use 'e' or 'E' format
	fmtChar := 'e'
	if fmt == 'E' {
		fmtChar = 'E'
	}
	
	// big.Float.Text prec parameter is total significant digits for 'e' format
	// strconv prec is digits after decimal point, so add 1
	result := bf.Text(byte(fmtChar), prec+1)
	
	// big.Float may produce different exponent formatting than strconv
	// strconv always uses at least 2 digits for exponent (e.g., e+01, e+00)
	result = fixExponentPadding(result, byte(fmtChar))
	
	return result
}

// formatFixed formats in fixed-point notation: [-]ddd.ddd
func formatFixed(f float64, prec int, bitSize int) string {
	neg := math.Signbit(f)
	if neg {
		f = -f
	}
	
	// Special case: zero
	if f == 0 {
		return formatZeroFixed(neg, prec)
	}
	
	if prec < 0 {
		prec = 6
	}
	
	// For very large numbers or high precision, use big.Float
	if f > 1e15 || prec > 15 {
		return formatFixedHighPrecision(f, prec, neg)
	}
	
	// Scale by 10^prec and round
	scale := pow10(prec)
	scaled := f * float64(scale)
	rounded := uint64(scaled + 0.5)
	
	// Build result
	var buf [64]byte
	pos := 0
	
	if neg {
		buf[pos] = '-'
		pos++
	}
	
	// Integer part
	intPart := rounded / scale
	intStr := formatUint64(intPart)
	copy(buf[pos:], intStr)
	pos += len(intStr)
	
	if prec > 0 {
		buf[pos] = '.'
		pos++
		
		// Fractional part
		fracPart := rounded % scale
		for i := prec - 1; i >= 0; i-- {
			buf[pos+i] = byte('0' + fracPart%10)
			fracPart /= 10
		}
		pos += prec
	}
	
	return string(buf[:pos])
}

// formatFixedHighPrecision handles fixed-point formatting for large numbers
// or high precision using big.Float for accurate decimal representation
func formatFixedHighPrecision(f float64, prec int, neg bool) string {
	// Use big.Float for high-precision arithmetic
	// Set precision high enough to avoid rounding errors
	const floatPrec = 256
	
	bf := big.NewFloat(f).SetPrec(floatPrec)
	if neg {
		bf = bf.Neg(bf)
	}
	
	// Get the string representation with the specified precision
	// Use 'f' format with the requested precision
	str := bf.Text('f', prec)
	
	// Restore the sign if necessary
	if neg && str[0] != '-' {
		str = "-" + str
	}
	
	return str
}

// formatShortest formats using 'g'/'G' rules: shortest of 'e' or 'f'
func formatShortest(f float64, fmt byte, prec int, bitSize int) string {
	// Use big.Float for reliable formatting
	if prec < 0 {
		prec = 6
	}
	if prec == 0 {
		prec = 1
	}
	
	// Handle bitSize 32: round to float32 precision
	if bitSize == 32 {
		f = float64(float32(f))
	}
	
	bf := big.NewFloat(f).SetPrec(256)
	
	// Use 'g' or 'G' format
	fmtChar := 'g'
	if fmt == 'G' {
		fmtChar = 'G'
	}
	
	result := bf.Text(byte(fmtChar), prec)
	
	return result
}

// formatBinary formats in binary exponent form: [-]mantissap±exponent
// The mantissa is in decimal, the exponent is the binary exponent
func formatBinary(f float64) string {
	if f == 0 {
		if math.Signbit(f) {
			return "-0p+0"
		}
		return "0p+0"
	}
	
	fbits := math.Float64bits(f)
	sign := fbits >> 63
	biasedExp := (fbits >> 52) & 0x7ff
	frac := fbits & (1<<52 - 1)
	
	var mant uint64
	var exp int64
	
	if biasedExp == 0 {
		// Subnormal number: no implicit leading 1
		mant = frac
		exp = -1022 - 52 // Subnormal exponent, adjusted for fractional bits
	} else {
		// Normal number: add implicit leading 1
		mant = frac | (1 << 52)
		exp = int64(biasedExp) - 1023 - 52 // Adjust for bias and fractional bits
	}
	
	var buf [64]byte
	pos := 0
	
	if sign != 0 {
		buf[pos] = '-'
		pos++
	}
	
	// Format mantissa in decimal
	mantStr := intformat.FormatUint64(mant, 10)
	copy(buf[pos:], mantStr)
	pos += len(mantStr)
	
	buf[pos] = 'p'
	pos++
	
	if exp >= 0 {
		buf[pos] = '+'
		pos++
	}
	
	expStr := intformat.FormatInt64(exp, 10)
	copy(buf[pos:], expStr)
	pos += len(expStr)
	
	return string(buf[:pos])
}

// formatHex formats in hexadecimal: [-]0x1.hhhhp±dd
// The mantissa is in hex with a binary point, exponent is decimal power of 2
func formatHex(f float64, fmt byte, prec int) string {
	if f == 0 {
		result := "0x0p+00"
		if math.Signbit(f) {
			result = "-" + result
		}
		if fmt == 'X' {
			result = "-0X0p+00"
			if !math.Signbit(f) {
				result = "0X0p+00"
			}
		}
		// Handle precision for zero
		if prec > 0 {
			// Insert fractional part after '0'
			dotPos := 3 // Position after "0x0" or "-0x0"
			if math.Signbit(f) {
				dotPos = 4
			}
			if fmt == 'X' {
				dotPos = 3
				if math.Signbit(f) {
					dotPos = 4
				}
			}
			zeros := make([]byte, prec+1)
			zeros[0] = '.'
			for i := 1; i <= prec; i++ {
				zeros[i] = '0'
			}
			result = result[:dotPos] + string(zeros) + result[dotPos:]
		}
		return result
	}
	
	fbits := math.Float64bits(f)
	sign := fbits >> 63
	biasedExp := (fbits >> 52) & 0x7ff
	frac := fbits & (1<<52 - 1)
	
	var buf [64]byte
	pos := 0
	
	if sign != 0 {
		buf[pos] = '-'
		pos++
	}
	
	buf[pos] = '0'
	pos++
	
	if fmt == 'X' {
		buf[pos] = 'X'
	} else {
		buf[pos] = 'x'
	}
	pos++
	
	var exp int64
	
	if biasedExp == 0 {
		// Subnormal number
		if frac == 0 {
			// Zero was already handled above
			buf[pos] = '0'
			pos++
			buf[pos] = 'p'
			pos++
			buf[pos] = '+'
			pos++
			buf[pos] = '0'
			pos++
			buf[pos] = '0'
			pos++
			return string(buf[:pos])
		}
		// Format as 0.frac with adjusted exponent
		buf[pos] = '0'
		pos++
		
		if prec != 0 {
			buf[pos] = '.'
			pos++
			
			// Format fractional part in hex (13 hex digits for 52 bits)
			fracHex := formatHexFraction(frac, fmt, prec)
			copy(buf[pos:], fracHex)
			pos += len(fracHex)
		}
		
		exp = -1022
	} else {
		// Normal number: format as 1.frac
		buf[pos] = '1'
		pos++
		
		if frac != 0 || prec > 0 {
			buf[pos] = '.'
			pos++
			
			// Format fractional part in hex
			fracHex := formatHexFraction(frac, fmt, prec)
			copy(buf[pos:], fracHex)
			pos += len(fracHex)
		}
		
		exp = int64(biasedExp) - 1023
	}
	
	buf[pos] = 'p'
	pos++
	
	if exp >= 0 {
		buf[pos] = '+'
		pos++
	}
	
	expStr := intformat.FormatInt64(exp, 10)
	copy(buf[pos:], expStr)
	pos += len(expStr)
	
	result := string(buf[:pos])
	
	// Pad exponent to at least 2 digits
	result = fixHexExponentPadding(result)
	
	return result
}

// formatHexFraction formats the 52-bit fractional part as hex
func formatHexFraction(frac uint64, fmt byte, prec int) string {
	// Format as 13 hex digits (52 bits / 4 bits per hex digit)
	var buf [13]byte
	
	for i := 12; i >= 0; i-- {
		digit := frac & 0xF
		if fmt == 'X' {
			if digit < 10 {
				buf[i] = byte('0' + digit)
			} else {
				buf[i] = byte('A' + digit - 10)
			}
		} else {
			if digit < 10 {
				buf[i] = byte('0' + digit)
			} else {
				buf[i] = byte('a' + digit - 10)
			}
		}
		frac >>= 4
	}
	
	// Handle precision
	if prec < 0 {
		// Remove trailing zeros
		end := 13
		for end > 0 && buf[end-1] == '0' {
			end--
		}
		
		if end == 0 {
			return ""
		}
		
		return string(buf[:end])
	} else if prec == 0 {
		return ""
	} else {
		// Use exactly prec digits
		if prec > 13 {
			// Pad with zeros
			result := string(buf[:13])
			for i := 13; i < prec; i++ {
				result += "0"
			}
			return result
		}
		return string(buf[:prec])
	}
}

// Append appends the formatted float to dst
func Append(dst []byte, f float64, fmt byte, prec int, bitSize int) []byte {
	// Format to string then append
	s := Format(f, fmt, prec, bitSize)
	return append(dst, s...)
}

// Helper functions

func formatZeroScientific(neg bool, fmt byte, prec int) string {
	if prec < 0 {
		prec = 6
	}
	
	var buf [32]byte
	pos := 0
	
	if neg {
		buf[pos] = '-'
		pos++
	}
	
	buf[pos] = '0'
	pos++
	
	if prec > 0 {
		buf[pos] = '.'
		pos++
		for i := 0; i < prec; i++ {
			buf[pos] = '0'
			pos++
		}
	}
	
	buf[pos] = fmt
	pos++
	buf[pos] = '+'
	pos++
	buf[pos] = '0'
	pos++
	buf[pos] = '0'
	pos++
	
	return string(buf[:pos])
}

func formatZeroFixed(neg bool, prec int) string {
	if prec < 0 {
		prec = 6
	}
	
	var buf [32]byte
	pos := 0
	
	if neg {
		buf[pos] = '-'
		pos++
	}
	
	buf[pos] = '0'
	pos++
	
	if prec > 0 {
		buf[pos] = '.'
		pos++
		for i := 0; i < prec; i++ {
			buf[pos] = '0'
			pos++
		}
	}
	
	return string(buf[:pos])
}

func formatInt(n int) string {
	if n == 0 {
		return "0"
	}
	
	var buf [20]byte
	pos := len(buf)
	
	for n > 0 {
		pos--
		buf[pos] = byte('0' + n%10)
		n /= 10
	}
	
	return string(buf[pos:])
}

func formatUint64(n uint64) string {
	if n == 0 {
		return "0"
	}
	
	var buf [20]byte
	pos := len(buf)
	
	for n > 0 {
		pos--
		buf[pos] = byte('0' + n%10)
		n /= 10
	}
	
	return string(buf[pos:])
}

func pow10(n int) uint64 {
	pow := uint64(1)
	for i := 0; i < n; i++ {
		pow *= 10
	}
	return pow
}

func trimTrailingZeros(s string, expChar byte) string {
	// Find the exponent part
	expIdx := -1
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == expChar {
			expIdx = i
			break
		}
	}
	
	if expIdx < 0 {
		return s
	}
	
	// Find decimal point
	dotIdx := -1
	for i := 0; i < expIdx; i++ {
		if s[i] == '.' {
			dotIdx = i
			break
		}
	}
	
	if dotIdx < 0 {
		return s
	}
	
	// Trim zeros between dot and exp
	end := expIdx
	for end > dotIdx+1 && s[end-1] == '0' {
		end--
	}
	
	// Remove decimal point if no fractional digits remain
	if end == dotIdx+1 {
		end = dotIdx
	}
	
	return s[:end] + s[expIdx:]
}

func trimTrailingZerosFixed(s string) string {
	// Find decimal point
	dotIdx := -1
	for i := 0; i < len(s); i++ {
		if s[i] == '.' {
			dotIdx = i
			break
		}
	}
	
	if dotIdx < 0 {
		return s
	}
	
	// Trim trailing zeros
	end := len(s)
	for end > dotIdx+1 && s[end-1] == '0' {
		end--
	}
	
	// Remove decimal point if no fractional digits remain
	if end == dotIdx+1 {
		end = dotIdx
	}
	
	return s[:end]
}

// fixExponentPadding ensures exponent has at least 2 digits (e.g., e+01 not e+1)
func fixExponentPadding(s string, expChar byte) string {
	// Find the exponent marker
	expIdx := -1
	for i := 0; i < len(s); i++ {
		if s[i] == expChar {
			expIdx = i
			break
		}
	}
	
	if expIdx < 0 {
		return s
	}
	
	// Check if we have a sign after the exponent
	signIdx := expIdx + 1
	if signIdx >= len(s) {
		return s
	}
	
	// Skip the sign if present
	digitStart := signIdx
	if s[signIdx] == '+' || s[signIdx] == '-' {
		digitStart++
	}
	
	// Count digits in exponent
	digitCount := len(s) - digitStart
	
	// If we already have 2+ digits, no padding needed
	if digitCount >= 2 {
		return s
	}
	
	// If we have 1 digit, pad with a zero
	if digitCount == 1 {
		// Insert '0' before the last digit
		return s[:digitStart] + "0" + s[digitStart:]
	}
	
	return s
}

// fixHexExponentPadding ensures hex exponent has at least 2 digits
func fixHexExponentPadding(s string) string {
	// Find 'p' or 'P'
	pIdx := -1
	for i := 0; i < len(s); i++ {
		if s[i] == 'p' || s[i] == 'P' {
			pIdx = i
			break
		}
	}
	
	if pIdx < 0 {
		return s
	}
	
	// Check if we need padding
	signIdx := pIdx + 1
	if signIdx >= len(s) {
		return s
	}
	
	digitStart := signIdx
	if s[signIdx] == '+' || s[signIdx] == '-' {
		digitStart++
	}
	
	digitCount := len(s) - digitStart
	
	if digitCount >= 2 {
		return s
	}
	
	if digitCount == 1 {
		return s[:digitStart] + "0" + s[digitStart:]
	}
	
	return s
}
