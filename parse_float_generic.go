// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

import (
	"math"
	"math/big"
	"math/bits"
	"sync"

	"github.com/mshafiee/fastparse/internal/classifier"
	"github.com/mshafiee/fastparse/internal/conversion"
	"github.com/mshafiee/fastparse/internal/eisel_lemire"
	"github.com/mshafiee/fastparse/internal/fsa"
	"github.com/mshafiee/fastparse/internal/validation"
)

const maxSignificantDigits = 19

// Pool for parsedComponents to reduce allocations
var pcPool = sync.Pool{
	New: func() interface{} {
		return &parsedComponents{
			mantDigitsArray: [32]byte{}, // Stack array for common cases
		}
	},
}

// parseFloatGeneric parses a base-10 or hexadecimal float64 from string using an FSA-based parser.
// This is the generic pure Go implementation available to all platforms.
//
// Architecture: Optimized three-tier parsing strategy
// 1. Ultra-fast direct conversion (5-20 ns, 60-70% hit rate)
// 2. Optimized simple parser with Eisel-Lemire (20-40 ns, 25-30% hit rate)
// 3. Comprehensive FSA parser (100+ ns, 5-10% hit rate)
//
// PHASE 4 OPTIMIZATION: Inline simple pattern detection (4-10 ns savings)
func parseFloatGeneric(s string) (float64, error) {
	if len(s) == 0 {
		return 0, ErrSyntax
	}

	// TIER 1: Ultra-fast direct conversion for common patterns (60-70% of inputs)
	// Bypasses classifier overhead for short inputs (≤16 chars)
	// Handles: integers ("123"), simple decimals ("12.34")
	// Target: 5-20 ns (faster than strconv's 23-33 ns)
	if len(s) <= 16 {
		if result, mantissa, exp, neg, ok := parseDirectFloat(s); ok {
			return result, nil
		} else if mantissa != 0 && exp >= -348 && exp <= 308 {
			// parseDirectFloat parsed but couldn't convert - try Eisel-Lemire directly!
			// This is the key optimization: bypass FSA for large exponents
			if result, ok := eisel_lemire.TryParse(mantissa, exp); ok {
				if neg {
					result = -result
				}
				// Check for overflow or NaN
				if math.IsInf(result, 0) || math.IsNaN(result) {
					return result, ErrRange
				}
				return result, nil
			}
		}
		// Fall through if can't handle it
	}

	// TIER 2: Pattern classification and optimized simple parser (25-30% of inputs)
	// Use the optimized classifier (it's already very fast at 3-10 ns)
	pattern := classifier.Classify(s)

	if pattern == classifier.PatternSimple {
		// Simple pattern: try improved fast path
		// Format: [-+]?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?
		if result, mantissa, exp, neg, ok := parseSimpleFast(s); ok {
			return result, nil
		} else if mantissa != 0 && exp >= -348 && exp <= 308 {
			// parseSimpleFast parsed successfully but couldn't convert - try Eisel-Lemire directly!
			// This bypasses the FSA overhead (50-80ns savings) - matching strconv's approach
			// Only do this if exp is in Eisel-Lemire's valid range
			if result, ok := eisel_lemire.TryParse(mantissa, exp); ok {
				if neg {
					result = -result
				}
				// Check for overflow or NaN
				if math.IsInf(result, 0) || math.IsNaN(result) {
					return result, ErrRange
				}
				return result, nil
			}
		}
		// Fall through to FSA if Eisel-Lemire also fails
	}

	// TIER 3: Complex pattern handling - comprehensive FSA path (5-10% of inputs)
	// Handles: underscores, hex floats, special values (inf/nan), very long numbers

	// Check for hex floats specifically (pattern classifier rejects these as complex)
	if len(s) > 2 && len(s) < 64 {
		idx := 0
		if s[idx] == '-' || s[idx] == '+' {
			idx++
		}
		if idx+1 < len(s) && s[idx] == '0' && (s[idx+1] == 'x' || s[idx+1] == 'X') {
			if result, ok := parseHexFast(s); ok {
				return result, nil
			}
		}
	}

	// Try long decimal fast path for very long simple decimals
	// (pattern classifier rejects >24 chars as complex)
	if len(s) >= 20 && len(s) <= 100 && !validation.HasComplexChars(s) {
		if result, ok := parseLongDecimalFast(s); ok {
			return result, nil
		}
	}

	// Full FSA path for all remaining cases
	// Use pool to reduce allocations
	pc := pcPool.Get().(*parsedComponents)
	defer pcPool.Put(pc)
	pc.reset()

	err := parseComponents(s, pc)
	if err != nil {
		return 0, err
	}

	if pc.special != specialNone {
		return handleSpecial(pc)
	}

	if pc.isHex {
		return convertHexFloat(pc)
	}
	return convertDecimalFloat(pc)
}

type specialKind int

const (
	specialNone specialKind = iota
	specialNaN
	specialInf
)

type parsedComponents struct {
	negative bool
	isHex    bool
	special  specialKind

	mantissa        uint64
	mantDigits      []byte   // Slice view into mantDigitsArray or heap allocation
	mantDigitsArray [32]byte // Stack array for common cases (≤32 digits)
	mantDigitsLen   int      // Length of mantDigits
	mantExp         int
	exp             int64
	expNeg          bool
	digitCount      int
	trailingZeros   int
	hasMore         bool // For hex/decimal: are there more non-zero bits/digits beyond collected?
	hexIntDigits    int  // Number of hex integer digits (before decimal point)
	hexFracDigits   int  // Number of hex fractional digits (after decimal point)
	totalFracDigits int  // Total fractional digits seen (including uncollected)
}

// reset prepares a parsedComponents for reuse
func (pc *parsedComponents) reset() {
	pc.negative = false
	pc.isHex = false
	pc.special = specialNone
	pc.mantissa = 0
	// Clear the array to prevent pollution between uses
	for i := range pc.mantDigitsArray {
		pc.mantDigitsArray[i] = 0
	}
	pc.mantDigits = pc.mantDigitsArray[:0] // Use stack array
	pc.mantDigitsLen = 0
	pc.mantExp = 0
	pc.exp = 0
	pc.expNeg = false
	pc.digitCount = 0
	pc.trailingZeros = 0
	pc.hasMore = false
	pc.hexIntDigits = 0
	pc.hexFracDigits = 0
	pc.totalFracDigits = 0
}

func parseComponents(s string, pc *parsedComponents) error {
	// pc is already reset and has mantDigits pointing to mantDigitsArray

	var (
		state                     fsa.State = fsa.StateStart
		mantissa                  uint64    = 0
		mantExp                   int       = 0
		exp                       int64     = 0
		expNeg                    bool      = false
		negative                  bool      = false
		isHex                     bool      = false
		hasDigits                 bool      = false
		hasHexDigits              bool      = false
		inFraction                bool      = false
		inHexFraction             bool      = false
		digitCount                int       = 0
		sawNonZero                bool      = false
		significantDigits         int       = 0
		trailingZeros             int       = 0
		fractionalDigitsCollected int       = 0
		maxFractionalDigits       int       = 300 // Limit for fractional digit collection (increased to handle long fractional strings)
	)

	for i := 0; i < len(s); i++ {
		ch := s[i]
		idx := int(state)*256 + int(ch)
		nextState := fsa.State(fsa.TransitionTable[idx])
		action := fsa.Action(fsa.ActionTable[idx])

		if nextState == fsa.StateError {
			return ErrSyntax
		}

		// Validate underscore placement
		if ch == '_' {
			if i == 0 || i == len(s)-1 {
				return ErrSyntax
			}
			prevCh := s[i-1]
			// Consecutive underscores not allowed
			if prevCh == '_' {
				return ErrSyntax
			}
			// Not after sign or decimal point
			if prevCh == '+' || prevCh == '-' || prevCh == '.' {
				return ErrSyntax
			}
			// Not after exponent marker
			// In decimal: e/E are exponent markers
			// In hex: p/P are exponent markers (e/E are valid hex digits)
			if isHex {
				if prevCh == 'p' || prevCh == 'P' {
					return ErrSyntax
				}
			} else {
				if prevCh == 'e' || prevCh == 'E' {
					return ErrSyntax
				}
			}
			if i+1 < len(s) {
				nextCh := s[i+1]
				// Not before decimal point
				if nextCh == '.' {
					return ErrSyntax
				}
				// Not before exponent marker (context-sensitive)
				if isHex {
					if nextCh == 'p' || nextCh == 'P' {
						return ErrSyntax
					}
				} else {
					if nextCh == 'e' || nextCh == 'E' {
						return ErrSyntax
					}
				}
			}
		}

		// Update state flags BEFORE processing actions
		if nextState == fsa.StateHexFraction || nextState == fsa.StateHexDecimal {
			inHexFraction = true
		}
		if nextState == fsa.StateFraction || nextState == fsa.StateDecimal {
			inFraction = true
		}

		switch action {
		case fsa.ActionSetSign:
			negative = (ch == '-')

		case fsa.ActionDigit:
			digit := uint64(ch - '0')
			if state == fsa.StateExponent || state == fsa.StateExpSign || state == fsa.StateExpDigits ||
				state == fsa.StateHexExpMarker || state == fsa.StateHexExpSign || state == fsa.StateHexExpDigits {
				if exp < 1e15 {
					exp = exp*10 + int64(digit)
				}
			} else {
				hasDigits = true
				digitCount++

				if digit != 0 || sawNonZero {
					sawNonZero = true

					// For fractional digits, limit collection to avoid pathological cases
					if inFraction {
						pc.totalFracDigits++ // Track all fractional digits

						// Check if we should still collect this digit
						if fractionalDigitsCollected < maxFractionalDigits {
							// Within fractional limit - collect the digit
							pc.mantDigits = append(pc.mantDigits, ch)

							if significantDigits < maxSignificantDigits {
								if mantissa < (1<<63)/10 {
									mantissa = mantissa*10 + digit
								}
								significantDigits++
							}

							mantExp--
							fractionalDigitsCollected++
						} else {
							// Beyond fractional precision limit
							if digit != 0 {
								pc.hasMore = true
							}
							// Don't adjust mantExp - precision limit reached
						}
					} else {
						// Integer part
						if len(pc.mantDigits) < 800 {
							pc.mantDigits = append(pc.mantDigits, ch)

							if significantDigits < maxSignificantDigits {
								if mantissa < (1<<63)/10 {
									mantissa = mantissa*10 + digit
									significantDigits++
								}
							}
							// Note: Don't increment mantExp for collected digits
							// They're handled by big.Int conversion in convertDecimalFloat
						} else {
							// Beyond integer limit (800 digits)
							// These digits are NOT collected, so increment mantExp
							if digit != 0 {
								pc.hasMore = true
							}
							mantExp++
						}
					}
				} else if inFraction {
					// Leading zeros in fraction (before any significant digit)
					mantExp--
				}
			}

		case fsa.ActionHexDigit:
			var digit uint64
			if ch >= '0' && ch <= '9' {
				digit = uint64(ch - '0')
			} else if ch >= 'a' && ch <= 'f' {
				digit = uint64(ch - 'a' + 10)
			} else if ch >= 'A' && ch <= 'F' {
				digit = uint64(ch - 'A' + 10)
			}

			hasHexDigits = true
			digitCount++

			// Track whether this is an integer or fractional digit
			if inHexFraction {
				pc.hexFracDigits++
			} else {
				pc.hexIntDigits++
			}

			// Collect hex digits
			if len(pc.mantDigits) < 20 {
				pc.mantDigits = append(pc.mantDigits, ch)
			} else if digit != 0 {
				pc.hasMore = true
			}

			// Update mantissa (will be re-parsed in converter)
			if mantissa < (1 << 60) {
				mantissa = mantissa*16 + digit
			}

		case fsa.ActionHexPrefix:
			isHex = true
			mantissa = 0
			pc.mantDigits = pc.mantDigits[:0]
			hasDigits = false
			digitCount = 0

		case fsa.ActionDot:
			if isHex {
				inHexFraction = true
			} else {
				inFraction = true
			}
		}

		if nextState == fsa.StateExpSign || nextState == fsa.StateHexExpSign {
			if ch == '-' {
				expNeg = true
			}
		}

		state = nextState
	}

	// Validate final state
	switch state {
	case fsa.StateOK:
		lower := toLowerASCII(s)
		lower = trimSign(lower)
		if lower == "inf" || lower == "infinity" {
			pc.special = specialInf
			pc.negative = negative
			return nil
		}
		if lower == "nan" {
			pc.special = specialNaN
			return nil
		}
		return ErrSyntax

	case fsa.StateInteger, fsa.StateFraction, fsa.StateExpDigits:
		if !hasDigits {
			return ErrSyntax
		}

	case fsa.StateHexInteger, fsa.StateHexFraction:
		if !hasHexDigits {
			return ErrSyntax
		}
		return ErrSyntax

	case fsa.StateHexExpDigits:
		if !hasHexDigits {
			return ErrSyntax
		}

	default:
		return ErrSyntax
	}

	pc.negative = negative
	pc.isHex = isHex
	pc.mantissa = mantissa
	pc.mantExp = mantExp
	pc.exp = exp
	pc.expNeg = expNeg
	pc.digitCount = digitCount
	pc.trailingZeros = trailingZeros

	return nil
}

func handleSpecial(pc *parsedComponents) (float64, error) {
	switch pc.special {
	case specialNaN:
		return math.NaN(), nil
	case specialInf:
		if pc.negative {
			return math.Inf(-1), nil
		}
		return math.Inf(1), nil
	}
	return 0, ErrSyntax
}

// convertDecimalExact attempts exact float64 arithmetic conversion
// Based on strconv's atof64exact algorithm
// Returns (result, true) if exact conversion possible, (0, false) otherwise
func convertDecimalExact(mantissa uint64, exp int, neg bool) (float64, bool) {
	// Check if mantissa fits in float64 mantissa (53 bits)
	const float64MantissaBits = 52 // Excluding implicit leading 1
	if mantissa>>float64MantissaBits != 0 {
		return 0, false
	}

	f := float64(mantissa)
	if neg {
		f = -f
	}

	switch {
	case exp == 0:
		// An exact integer
		return f, true

	case exp > 0 && exp <= 15+22: // mantissa * 10^exp
		// Exact integers are <= 10^15
		// Exact powers of ten are <= 10^22
		// If exponent is big but mantissa is small, can use float arithmetic

		if exp > 22 {
			// Move some zeros into the integer part
			f *= float64pow10[exp-22]
			exp = 22
		}

		if f > 1e15 || f < -1e15 {
			// Exponent was really too large for exact arithmetic
			return 0, false
		}

		return f * float64pow10[exp], true

	case exp < 0 && exp >= -22: // mantissa / 10^|exp|
		return f / float64pow10[-exp], true
	}

	return 0, false
}

// convertDecimalExtended handles long decimals using optimized rounding + exact table
// This is faster than big.Float for 20-60 digit numbers
// Returns (result, true) if successful, (0, false) to fall back to big.Float
func convertDecimalExtended(mantissa uint64, exp int, neg bool) (float64, bool) {
	// Quick rejection for cases outside our range
	if exp < -308 || exp > 308 {
		return 0, false
	}

	// If mantissa is too large for float64, round it down to 53 bits
	const maxMantissa = uint64(1) << 53

	if mantissa > maxMantissa {
		// Optimized rounding: calculate how many divisions needed upfront
		// This is faster than loop for large mantissas
		digitsToRemove := 0
		temp := mantissa
		for temp > maxMantissa {
			temp /= 10
			digitsToRemove++
		}

		// Perform divisions with accumulated rounding
		// More accurate than iterative rounding
		if digitsToRemove > 0 {
			// Calculate divisor
			var divisor uint64 = 1
			for i := 0; i < digitsToRemove; i++ {
				divisor *= 10
				if divisor == 0 {
					// Overflow in divisor calculation - fall back
					return 0, false
				}
			}

			quotient := mantissa / divisor
			remainder := mantissa % divisor

			// Round based on the remainder
			// If remainder > divisor/2, round up
			halfDivisor := divisor / 2
			if remainder > halfDivisor || (remainder == halfDivisor && (quotient&1) != 0) {
				quotient++
			}

			mantissa = quotient
			exp += digitsToRemove

			// Re-check exponent range
			if exp > 308 {
				return 0, false
			}
		}
	}

	// Now mantissa fits in float64
	if mantissa == 0 {
		if neg {
			return math.Copysign(0, -1), true
		}
		return 0, true
	}

	f := float64(mantissa)
	if neg {
		f = -f
	}

	// Use extended exact table (covers 0-308)
	if exp == 0 {
		return f, true
	} else if exp > 0 {
		if exp < len(float64pow10) {
			// Use exact pre-computed value (fastest!)
			result := f * float64pow10[exp]
			if !math.IsInf(result, 0) {
				return result, true
			}
		}
		// Overflow or out of table range
		return 0, false
	} else { // exp < 0
		absExp := -exp
		if absExp < len(float64pow10) {
			// Use exact pre-computed value (fastest!)
			result := f / float64pow10[absExp]
			if result != 0 || mantissa == 0 {
				return result, true
			}
		}
		// Underflow to zero or out of range
		return 0, false
	}
}

func convertDecimalFloat(pc *parsedComponents) (float64, error) {
	totalExp := pc.mantExp
	if pc.expNeg {
		totalExp -= int(pc.exp)
	} else {
		totalExp += int(pc.exp)
	}

	if pc.mantissa == 0 {
		if pc.negative {
			return math.Copysign(0, -1), nil
		}
		return 0, nil
	}

	// Check for extreme exponents that would overflow/underflow
	if totalExp >= 309 {
		if pc.negative {
			return math.Inf(-1), ErrRange
		}
		return math.Inf(1), ErrRange
	}

	// Check for extreme underflow
	if totalExp < -324 {
		// Way below minimum normal float64, underflows to zero
		if pc.negative {
			return math.Copysign(0, -1), nil
		}
		return 0, nil
	}

	// Try Eisel-Lemire fast path (based on Go's strconv implementation)
	// Only call if totalExp is in Eisel-Lemire's valid range
	if pc.mantissa != 0 && !pc.hasMore && len(pc.mantDigits) <= 19 && totalExp >= -348 && totalExp <= 308 {
		if result, ok := eisel_lemire.TryParse(pc.mantissa, totalExp); ok {
			if pc.negative {
				result = -result
			}
			// Check for overflow or NaN
			if math.IsInf(result, 0) || math.IsNaN(result) {
				return result, ErrRange
			}
			return result, nil
		}
	}

	// Try exact float64 arithmetic (atof64exact algorithm from strconv)
	// Handles cases where mantissa fits in 53 bits with moderate exponents
	// Much faster than big.Float for these cases - now with assembly optimization
	// Only use when mantissa contains all significant digits (≤19 digits collected)
	if len(pc.mantDigits) <= 19 {
		if result, ok := conversion.ConvertDecimalExact(pc.mantissa, totalExp, pc.negative, float64pow10[:]); ok {
			// Check for overflow or NaN
			if math.IsInf(result, 0) || math.IsNaN(result) {
				return result, ErrRange
			}
			return result, nil
		}

		// Try extended conversion with math.Pow10 and rounding
		// Handles long decimals (20-60 digits) faster than big.Float - now with assembly optimization
		if result, ok := conversion.ConvertDecimalExtended(pc.mantissa, totalExp, pc.negative, float64pow10[:]); ok {
			// Check for overflow or NaN
			if math.IsInf(result, 0) || math.IsNaN(result) {
				return result, ErrRange
			}
			return result, nil
		}
	}

	// Limit mantissa digits to prevent performance issues
	// But keep enough for precise rounding
	mantDigits := pc.mantDigits
	hadNonZeroTruncated := pc.hasMore

	maxDigits := 200
	if pc.hasMore {
		maxDigits = 400 // Keep more digits if there are additional ones for better precision
	}

	if len(mantDigits) > maxDigits {
		// Check if any truncated digits are non-zero
		for i := maxDigits; i < len(mantDigits); i++ {
			if mantDigits[i] != '0' {
				hadNonZeroTruncated = true
				break
			}
		}

		// When truncating digits, we must adjust totalExp
		// because totalExp is relative to the number of digits in the big.Int
		digitsRemoved := len(mantDigits) - maxDigits
		totalExp += digitsRemoved

		mantDigits = mantDigits[:maxDigits]
	}

	// Build mantissa using big.Int for exact representation
	mant := new(big.Int)
	for _, d := range mantDigits {
		if d >= '0' && d <= '9' {
			mant.Mul(mant, big.NewInt(10))
			mant.Add(mant, big.NewInt(int64(d-'0')))
		}
	}

	if mant.Sign() == 0 {
		if pc.negative {
			return math.Copysign(0, -1), nil
		}
		return 0, nil
	}

	// Use big.Float with high precision for exact conversion
	// Use extra precision if there are more digits or large exponents
	prec := uint(256)
	if pc.hasMore || len(mantDigits) > 50 {
		prec = 1024 // Very high precision for complex cases
	}
	if pc.totalFracDigits > 1000 {
		prec = 2048 // Even higher precision for very long fractional strings
	}
	f := new(big.Float).SetPrec(prec).SetInt(mant)

	if totalExp != 0 {
		pow10 := new(big.Float).SetPrec(prec)
		absExp := totalExp
		if absExp < 0 {
			absExp = -absExp
		}

		// Build power of 10
		if absExp < 512 {
			pow10.SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(absExp)), nil))
			if totalExp > 0 {
				f.Mul(f, pow10)
			} else {
				f.Quo(f, pow10)
			}
		} else {
			// Very extreme exponent
			if totalExp > 0 {
				if pc.negative {
					return math.Inf(-1), ErrRange
				}
				return math.Inf(1), ErrRange
			} else {
				// Very large negative exponent
				if pc.negative {
					return math.Copysign(0, -1), nil
				}
				return 0, nil
			}
		}
	}

	// Check for overflow BEFORE converting to float64
	// big.Float.Float64() rounds to nearest, but we want to detect overflow
	maxF64 := new(big.Float).SetPrec(prec).SetFloat64(math.MaxFloat64)
	if f.Cmp(maxF64) > 0 {
		// Value exceeds max float64
		if pc.negative {
			return math.Inf(-1), ErrRange
		}
		return math.Inf(1), ErrRange
	}

	minF64 := new(big.Float).SetPrec(prec).SetFloat64(-math.MaxFloat64)
	if f.Cmp(minF64) < 0 {
		// Value below min float64
		return math.Inf(-1), ErrRange
	}

	// Convert to float64 with correct rounding
	result, acc := f.Float64()

	// Double-check for overflow after conversion (should not happen now)
	if math.IsInf(result, 0) {
		// Any conversion to infinity is an overflow error
		if pc.negative {
			return math.Inf(-1), ErrRange
		}
		return math.Inf(1), ErrRange
	}

	// Handle tie-breaking when we have truncated non-zero digits
	// Only apply for specific pathological cases
	hasMoreDigits := hadNonZeroTruncated

	if hasMoreDigits && result != 0 && acc == big.Below {
		// big.Float rounded DOWN, but we have more non-zero digits
		// This handles the "1.000...001" case where a distant digit should round up
		//
		// Only adjust if we have VERY MANY uncollected fractional digits
		// This avoids incorrectly rounding repeating decimals like "2.222...222"
		uncollectedFracDigits := pc.totalFracDigits - len(pc.mantDigits)
		if uncollectedFracDigits > 5000 {
			// Very long fractional part with distant trailing digit
			if result > 0 {
				result = math.Nextafter(result, math.Inf(1))
			} else {
				result = math.Nextafter(result, math.Inf(-1))
			}
		}
	}
	// Note: For most cases, trust big.Float's rounding

	if pc.negative {
		result = -result
	}

	return result, nil
}

func convertDecimalSimple(mantissa uint64, exp10 int, negative bool) (float64, error) {
	if mantissa == 0 {
		if negative {
			return math.Copysign(0, -1), nil
		}
		return 0, nil
	}

	f := float64(mantissa)

	if exp10 > 308 {
		if negative {
			return math.Inf(-1), ErrRange
		}
		return math.Inf(1), ErrRange
	}

	if exp10 > 0 {
		f *= math.Pow10(exp10)
	} else if exp10 < 0 {
		f /= math.Pow10(-exp10)
	}

	if negative {
		f = -f
	}

	if math.IsInf(f, 0) {
		return f, ErrRange
	}

	return f, nil
}

func convertHexFloat(pc *parsedComponents) (float64, error) {
	if len(pc.mantDigits) == 0 {
		if pc.negative {
			return math.Copysign(0, -1), nil
		}
		return 0, nil
	}

	// Parse hex mantissa
	// Simply parse all collected digits up to the limit
	var mantissa uint64
	digitsParsed := len(pc.mantDigits)
	if digitsParsed > 16 {
		digitsParsed = 16
	}

	for i := 0; i < digitsParsed; i++ {
		d := pc.mantDigits[i]
		var digit uint64
		if d >= '0' && d <= '9' {
			digit = uint64(d - '0')
		} else if d >= 'a' && d <= 'f' {
			digit = uint64(d - 'a' + 10)
		} else if d >= 'A' && d <= 'F' {
			digit = uint64(d - 'A' + 10)
		}
		mantissa = mantissa*16 + digit
	}

	// Calculate binary exponent
	explicitExp := int(pc.exp)
	if pc.expNeg {
		explicitExp = -explicitExp
	}

	// Track if the explicit exponent is in subnormal range
	// This helps with boundary rounding decisions
	originallySubnormal := (explicitExp < -1022)

	exp2 := explicitExp

	// Adjust for hex decimal point position
	// The mantissa we parsed includes integer + fractional digits
	// We need to account for the fractional position
	// If we parsed N total digits with F fractional digits, the value is:
	//   mantissa / 16^F * 2^exp  =  mantissa * 2^(exp - 4*F)
	parsedFracDigits := digitsParsed - pc.hexIntDigits
	if parsedFracDigits < 0 {
		parsedFracDigits = 0
	}
	if parsedFracDigits > pc.hexFracDigits {
		parsedFracDigits = pc.hexFracDigits
	}

	exp2 -= parsedFracDigits * 4

	if mantissa == 0 {
		if pc.negative {
			return math.Copysign(0, -1), nil
		}
		return 0, nil
	}

	// Normalize to get 53-bit mantissa
	// Find the position of the MSB
	shift := bits.LeadingZeros64(mantissa)
	mantissa <<= uint(shift) // Now MSB is at bit 63
	exp2 -= shift            // Adjust exponent for the normalization shift

	// mantissa now has MSB at position 63
	// We need 53 bits, so shift right by (64 - 53) = 11
	// But we also need to handle the implicit leading 1 in IEEE 754

	// Extract 53 bits with rounding
	// Position 63 is the implicit 1, positions 62-11 are the fractional part (52 bits)
	roundBits := mantissa & ((1 << 11) - 1)
	mantissa >>= 11

	// Pre-calculate what finalExp will be to detect boundary cases
	prelimExp := exp2 + 63

	// Detect if we're at subnormal/normal boundary before rounding
	// If prelimExp == -1023 and mantissa is at max, rounding would push to normal
	atBoundary := (prelimExp == -1023)

	// Round to nearest, ties to even
	// If there are more bits beyond what we parsed (pc.hasMore), treat as if roundBits is non-zero
	shouldRoundUp := false
	if roundBits > (1 << 10) {
		shouldRoundUp = true
	} else if roundBits == (1 << 10) {
		// Exactly halfway - round to even, or up if there are more bits
		if (mantissa&1) != 0 || pc.hasMore {
			shouldRoundUp = true
		}
	} else if pc.hasMore && roundBits >= (1<<9) {
		// If there are more bits and we're close to halfway, round up
		shouldRoundUp = true
	}

	if shouldRoundUp {
		mantissa++
		if mantissa >= (1 << 53) {
			mantissa >>= 1
			exp2++
			// If we were at boundary and rounding pushed us to normal, cap at largest subnormal
			if atBoundary {
				fbits := uint64(0x000FFFFFFFFFFFFF)
				if pc.negative {
					fbits |= 1 << 63
				}
				return math.Float64frombits(fbits), nil
			}
		}
	}

	// Calculate the final exponent
	finalExp := exp2 + 63

	// Check overflow
	if finalExp > 1023 {
		if pc.negative {
			return math.Inf(-1), ErrRange
		}
		return math.Inf(1), ErrRange
	}

	// Handle subnormal
	if finalExp < -1022 {
		// Denormalize with rounding
		denormShift := -1022 - finalExp
		if denormShift > 53 {
			// Complete underflow
			if pc.negative {
				return math.Copysign(0, -1), nil
			}
			return 0, nil
		}

		// Round when shifting
		if denormShift == 53 {
			// Special case: shifting out all 53 bits
			// The mantissa is in [2^52, 2^53) after rounding
			// We're shifting right by 53, leaving only the rounding decision
			// mantissa >> 53 would give 0 or 1
			// Rounding: if mantissa > 2^52 (more than halfway), round up
			//           if mantissa == 2^52 (exactly halfway), round to even (0)
			//           if mantissa < 2^52, round down to 0
			if mantissa > (1<<52) || (mantissa == (1<<52) && pc.hasMore) {
				// Round up to smallest subnormal
				fbits := uint64(1)
				if pc.negative {
					fbits |= 1 << 63
				}
				return math.Float64frombits(fbits), nil
			}
			// Round down to zero (including the exact halfway case without hasMore)
			if pc.negative {
				return math.Copysign(0, -1), nil
			}
			return 0, nil
		}

		if denormShift > 0 {
			// Extract bits that will be shifted out
			roundMask := (uint64(1) << uint(denormShift)) - 1
			roundBits := mantissa & roundMask
			mantissa >>= uint(denormShift)

			// Round to nearest, ties to even (or up if hasMore)
			halfway := uint64(1) << uint(denormShift-1)
			if roundBits > halfway || (roundBits == halfway && ((mantissa&1) != 0 || pc.hasMore)) {
				mantissa++
				// Check if rounding caused overflow into normal range
				if mantissa >= (1 << 52) {
					// Overflowed to normal
					// If the original exponent was in normal range, allow it
					// Otherwise, cap at largest subnormal
					if !originallySubnormal {
						fbits := uint64(0x0010000000000000)
						if pc.negative {
							fbits |= 1 << 63
						}
						return math.Float64frombits(fbits), nil
					}
					// Cap at largest subnormal
					mantissa = (1 << 52) - 1
				}
			}
		}

		// Subnormal: biased exponent = 0, mantissa contains all bits
		fbits := mantissa
		if pc.negative {
			fbits |= 1 << 63
		}
		return math.Float64frombits(fbits), nil
	}

	// Normal number: biased exponent (finalExp + 1023) and mantissa without implicit leading 1
	fbits := (uint64(finalExp+1023) << 52) | (mantissa & ((1 << 52) - 1))

	if pc.negative {
		fbits |= 1 << 63
	}

	return math.Float64frombits(fbits), nil
}

func toLowerASCII(s string) string {
	b := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] >= 'A' && s[i] <= 'Z' {
			b[i] = s[i] + 32
		} else {
			b[i] = s[i]
		}
	}
	return string(b)
}

func trimSign(s string) string {
	if len(s) > 0 && (s[0] == '+' || s[0] == '-') {
		return s[1:]
	}
	return s
}
