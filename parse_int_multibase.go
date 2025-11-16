package fastparse

// parseIntMultiBase parses a signed integer in any base (2-36) with any bitSize (0-64).
// This implementation uses the unsigned parser and then checks for signed overflow.
func parseIntMultiBase(s string, base int, bitSize int) (int64, error) {
	if len(s) == 0 {
		return 0, syntaxError("ParseInt", s)
	}

	// Validate base
	if base < 0 || base == 1 || base > 36 {
		return 0, baseError("ParseInt", s, base)
	}

	// Validate bitSize
	if bitSize < 0 || bitSize > 64 {
		return 0, bitSizeError("ParseInt", s, bitSize)
	}

	// Determine the actual bit size
	actualBitSize := bitSize
	if bitSize == 0 {
		actualBitSize = IntSize
	}

	// Determine max value for signed integer
	var maxVal uint64
	var minNeg uint64 // abs value of minimum negative
	switch actualBitSize {
	case 8:
		maxVal = 1<<7 - 1 // 127
		minNeg = 1 << 7   // 128
	case 16:
		maxVal = 1<<15 - 1 // 32767
		minNeg = 1 << 15   // 32768
	case 32:
		maxVal = 1<<31 - 1 // 2147483647
		minNeg = 1 << 31   // 2147483648
	case 64:
		maxVal = 1<<63 - 1 // 9223372036854775807
		minNeg = 1 << 63   // 9223372036854775808
	default:
		// For unusual bit sizes
		if actualBitSize < 64 {
			maxVal = 1<<uint(actualBitSize-1) - 1
			minNeg = 1 << uint(actualBitSize-1)
		} else {
			maxVal = 1<<63 - 1
			minNeg = 1 << 63
		}
	}

	// Check for sign
	negative := false
	i := 0
	if s[0] == '+' || s[0] == '-' {
		negative = (s[0] == '-')
		i++
	}

	// Parse as unsigned with the appropriate max value
	// For negative numbers, we can accept up to minNeg
	// For positive numbers, we can accept up to maxVal
	parseMax := maxVal
	if negative {
		parseMax = minNeg
	}

	// Parse the unsigned portion using a modified version
	value, err := parseUintForSigned(s[i:], base, parseMax)
	if err != nil {
		// Convert error to use ParseInt function name
		if numErr, ok := err.(*NumError); ok {
			if numErr.Err == ErrRange {
				// Return overflow value
				if negative {
					// Return minimum value
					switch actualBitSize {
					case 8:
						return -128, rangeError("ParseInt", s)
					case 16:
						return -32768, rangeError("ParseInt", s)
					case 32:
						return -2147483648, rangeError("ParseInt", s)
					case 64:
						return -9223372036854775808, rangeError("ParseInt", s)
					default:
						return -int64(minNeg), rangeError("ParseInt", s)
					}
				} else {
					// Return maximum value
					return int64(maxVal), rangeError("ParseInt", s)
				}
			}
			return 0, syntaxError("ParseInt", s)
		}
		return 0, err
	}

	// Convert to signed
	if negative {
		// Special case: minimum negative value
		if value == minNeg {
			return -int64(minNeg), nil
		}
		return -int64(value), nil
	}

	return int64(value), nil
}

// parseUintForSigned is a helper that parses unsigned with a specific max value
// Used by parseIntMultiBase to handle signed overflow correctly
func parseUintForSigned(s string, base int, maxVal uint64) (uint64, error) {
	if len(s) == 0 {
		return 0, syntaxError("ParseUint", s)
	}

	// Handle base 0 (auto-detect from prefix)
	origBase := base
	i := 0

	if base == 0 {
		// Auto-detect base from prefix
		base = 10 // default
		if s[i] == '0' {
			if i+1 < len(s) {
				switch s[i+1] {
				case 'x', 'X':
					base = 16
					i += 2
				case 'b', 'B':
					base = 2
					i += 2
				case 'o', 'O':
					base = 8
					i += 2
				default:
					// Octal (legacy: 0 prefix without 'o')
					base = 8
					i++
				}
			} else {
				// Just "0"
				base = 10
			}
		}
	} else if base == 16 {
		// For explicit base 16, allow optional 0x prefix
		if i+1 < len(s) && s[i] == '0' && (s[i+1] == 'x' || s[i+1] == 'X') {
			i += 2
		}
	}

	// Underscores are ONLY allowed when original base was 0
	// (regardless of whether a prefix was detected)
	allowUnderscores := (origBase == 0)

	// Check if we have any digits after prefix
	if i >= len(s) {
		return 0, syntaxError("ParseUint", s)
	}

	// Track underscore usage
	var (
		value             uint64
		hasDigits         bool
		lastWasUnderscore bool
	)

	// Parse digits
	for ; i < len(s); i++ {
		ch := s[i]

		// Handle underscore
		if ch == '_' {
			// Underscores are only allowed with base 0
			if !allowUnderscores {
				return 0, syntaxError("ParseUint", s)
			}
			// Validate underscore placement
			// Can't be at the very start (position 0)
			if i == 0 {
				return 0, syntaxError("ParseUint", s)
			}
			if lastWasUnderscore {
				// Consecutive underscores
				return 0, syntaxError("ParseUint", s)
			}
			if i == len(s)-1 {
				// Underscore at end
				return 0, syntaxError("ParseUint", s)
			}
			lastWasUnderscore = true
			continue
		}

		lastWasUnderscore = false

		// Convert character to digit value
		var d uint64
		if ch >= '0' && ch <= '9' {
			d = uint64(ch - '0')
		} else if ch >= 'a' && ch <= 'z' {
			d = uint64(ch - 'a' + 10)
		} else if ch >= 'A' && ch <= 'Z' {
			d = uint64(ch - 'A' + 10)
		} else {
			return 0, syntaxError("ParseUint", s)
		}

		// Check if digit is valid for this base
		if d >= uint64(base) {
			return 0, syntaxError("ParseUint", s)
		}

		hasDigits = true

		// Check for overflow before multiplying
		if value > maxVal/uint64(base) {
			// Overflow
			return maxVal, rangeError("ParseUint", s)
		}

		value *= uint64(base)

		// Check for overflow before adding
		if value > maxVal-d {
			// Overflow
			return maxVal, rangeError("ParseUint", s)
		}

		value += d
	}

	if !hasDigits {
		return 0, syntaxError("ParseUint", s)
	}

	return value, nil
}

// parseUintMultiBase parses an unsigned integer in any base (2-36) with any bitSize (0-64).
// This delegates to the generic implementation.
func parseUintMultiBase(s string, base int, bitSize int) (uint64, error) {
	return parseUintGeneric(s, base, bitSize)
}
