// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package intformat

// FormatInt64 returns the string representation of i in the given base,
// for 2 <= base <= 36. The result uses the lower-case letters 'a' to 'z'
// for digit values >= 10.
func FormatInt64(i int64, base int) string {
	if base < 2 || base > 36 {
		panic("intformat: invalid base")
	}

	// Handle zero specially
	if i == 0 {
		return "0"
	}

	// Handle negative numbers
	neg := i < 0
	var u uint64
	if neg {
		// Handle minimum int64 value specially to avoid overflow
		if i == -9223372036854775808 {
			u = 9223372036854775808
		} else {
			u = uint64(-i)
		}
	} else {
		u = uint64(i)
	}

	// Format the unsigned value
	s := FormatUint64(u, base)

	// Add minus sign for negative numbers
	if neg {
		return "-" + s
	}
	return s
}

// FormatUint64 returns the string representation of u in the given base,
// for 2 <= base <= 36. The result uses the lower-case letters 'a' to 'z'
// for digit values >= 10.
func FormatUint64(u uint64, base int) string {
	if base < 2 || base > 36 {
		panic("intformat: invalid base")
	}

	// Handle zero specially
	if u == 0 {
		return "0"
	}

	// Use optimized paths for common bases
	switch base {
	case 10:
		return formatUint64Base10(u)
	case 16:
		return formatUint64Base16(u)
	case 8:
		return formatUint64Base8(u)
	case 2:
		return formatUint64Base2(u)
	default:
		return formatUint64Generic(u, base)
	}
}

// AppendInt64 appends the string form of i in the given base to dst and
// returns the extended buffer.
func AppendInt64(dst []byte, i int64, base int) []byte {
	if base < 2 || base > 36 {
		panic("intformat: invalid base")
	}

	// Handle zero specially
	if i == 0 {
		return append(dst, '0')
	}

	// Handle negative numbers
	neg := i < 0
	var u uint64
	if neg {
		// Handle minimum int64 value specially to avoid overflow
		if i == -9223372036854775808 {
			u = 9223372036854775808
		} else {
			u = uint64(-i)
		}
		dst = append(dst, '-')
	} else {
		u = uint64(i)
	}

	// Append the unsigned value
	return AppendUint64(dst, u, base)
}

// AppendUint64 appends the string form of u in the given base to dst and
// returns the extended buffer.
func AppendUint64(dst []byte, u uint64, base int) []byte {
	if base < 2 || base > 36 {
		panic("intformat: invalid base")
	}

	// Handle zero specially
	if u == 0 {
		return append(dst, '0')
	}

	// Use optimized paths for common bases
	switch base {
	case 10:
		return appendUint64Base10(dst, u)
	case 16:
		return appendUint64Base16(dst, u)
	case 8:
		return appendUint64Base8(dst, u)
	case 2:
		return appendUint64Base2(dst, u)
	default:
		return appendUint64Generic(dst, u, base)
	}
}
