// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

// parseUintGeneric parses an unsigned integer in any base (2-36) with any bitSize (0-64).
// This is the generic pure Go implementation available to all platforms.
func parseUintGeneric(s string, base int, bitSize int) (uint64, error) {
	if len(s) == 0 {
		return 0, syntaxError("ParseUint", s)
	}

	// Validate base
	if base < 0 || base == 1 || base > 36 {
		return 0, baseError("ParseUint", s, base)
	}

	// Validate bitSize
	if bitSize < 0 || bitSize > 64 {
		return 0, bitSizeError("ParseUint", s, bitSize)
	}

	// Determine maximum value based on bitSize
	var maxVal uint64
	switch bitSize {
	case 0:
		maxVal = 1<<64 - 1 // uint
	case 8:
		maxVal = 1<<8 - 1
	case 16:
		maxVal = 1<<16 - 1
	case 32:
		maxVal = 1<<32 - 1
	case 64:
		maxVal = 1<<64 - 1
	default:
		// For other bit sizes, calculate the max
		if bitSize < 64 {
			maxVal = 1<<uint(bitSize) - 1
		} else {
			maxVal = 1<<64 - 1
		}
	}

	// Handle base 0 (auto-detect from prefix)
	origBase := base
	i := 0

	// Check for sign
	// Signs are ONLY allowed when base == 0 (auto-detect mode)
	hasSign := false
	if s[i] == '+' || s[i] == '-' {
		if base != 0 {
			// Signs not allowed for explicit bases
			return 0, syntaxError("ParseUint", s)
		}
		hasSign = true
		if s[i] == '-' {
			// Negative values are invalid for unsigned
			// Will handle this after parsing
		}
		i++
		if i >= len(s) {
			return 0, syntaxError("ParseUint", s)
		}
	}

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
				// Just "0" or "+0" or "-0"
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

	// Check if we have any digits after prefix/sign
	if i >= len(s) {
		return 0, syntaxError("ParseUint", s)
	}

	// Remember the start position for underscore validation
	startPos := i

	// Track underscore usage
	var (
		value      uint64
		hasDigits  bool
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
			// Can't be at the very start (before any prefix)
			if i == startPos && startPos == 0 {
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

	// Handle negative sign (for unsigned, this is always invalid)
	if hasSign && s[0] == '-' {
		if value == 0 {
			// Special case: "-0" is valid and equals 0 (only for base 0)
			return 0, nil
		}
		// Negative value for unsigned type is a syntax error, not range error
		return 0, syntaxError("ParseUint", s)
	}

	return value, nil
}

