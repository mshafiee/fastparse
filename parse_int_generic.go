// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fastparse

import (
	"github.com/mshafiee/fastparse/internal/fsa"
)

// parseIntGeneric parses a base-10 integer of the specified bitSize (32 or 64).
// This is the generic pure Go implementation available to all platforms.
func parseIntGeneric(s string, bitSize int) (int64, error) {
	if len(s) == 0 {
		return 0, syntaxError("ParseInt", s)
	}

	if bitSize != 32 && bitSize != 64 {
		return 0, bitSizeError("ParseInt", s, bitSize)
	}

	// Track parsing state
	var (
		state  fsa.State = fsa.StateStart
		value  uint64    = 0
		sign   int64     = 1
		digits int       = 0
	)

	// Determine max value based on bitSize
	var maxValue uint64
	if bitSize == 32 {
		maxValue = 1<<31 - 1 // Max int32
	} else {
		maxValue = 1<<63 - 1 // Max int64
	}

	// Run the FSA
	for i := 0; i < len(s); i++ {
		ch := s[i]

		// For base-10 integers, underscores are not allowed
		if ch == '_' {
			return 0, syntaxError("ParseInt", s)
		}

		idx := int(state)*256 + int(ch)
		nextState := fsa.State(fsa.TransitionTable[idx])
		action := fsa.Action(fsa.ActionTable[idx])

		// Handle actions
		switch action {
		case fsa.ActionSetSign:
			if ch == '-' {
				sign = -1
			} else {
				sign = 1
			}
		case fsa.ActionDigit:
			digit := uint64(ch - '0')
			// Check for overflow before multiplying
			if value > maxValue/10 {
			// Overflow - return max/min value with error (matching strconv behavior)
			if sign < 0 {
				if bitSize == 64 {
					return -9223372036854775808, rangeError("ParseInt", s)
				}
				return -2147483648, rangeError("ParseInt", s)
			}
			if bitSize == 64 {
				return 9223372036854775807, rangeError("ParseInt", s)
			}
			return 2147483647, rangeError("ParseInt", s)
			}
			newValue := value*10 + digit
			if newValue > maxValue {
				// Check for special case: minimum negative value
				if sign < 0 && newValue == maxValue+1 {
					if bitSize == 64 && newValue == 9223372036854775808 {
						return -9223372036854775808, nil
					}
					if bitSize == 32 && newValue == 2147483648 {
						return -2147483648, nil
					}
				}
				// Overflow - return max/min value with error
				if sign < 0 {
					if bitSize == 64 {
						return -9223372036854775808, rangeError("ParseInt", s)
					}
					return -2147483648, rangeError("ParseInt", s)
				}
				if bitSize == 64 {
					return 9223372036854775807, rangeError("ParseInt", s)
				}
				return 2147483647, rangeError("ParseInt", s)
			}
			value = newValue
			digits++
		}

		// Check for error state
		if nextState == fsa.StateError {
			return 0, syntaxError("ParseInt", s)
		}

		// Reject non-integer states
		if nextState == fsa.StateDecimal || nextState == fsa.StateFraction || nextState == fsa.StateExponent {
			return 0, syntaxError("ParseInt", s)
		}

		state = nextState
	}

	// Finalize based on final state
	switch state {
	case fsa.StateInteger:
		if digits == 0 {
			return 0, syntaxError("ParseInt", s)
		}

		result := int64(value)
		if sign < 0 {
			result = -result
		}

		return result, nil

	default:
		return 0, syntaxError("ParseInt", s)
	}
}

