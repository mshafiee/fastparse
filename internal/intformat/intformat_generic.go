package intformat

import "math/bits"

// Digit lookup table for bases up to 36
const digits = "0123456789abcdefghijklmnopqrstuvwxyz"

// formatUint64Base10 formats a uint64 in base 10 using optimized division.
func formatUint64Base10(u uint64) string {
	// Fast path: use a fixed-size buffer that can hold any uint64 (max 20 digits)
	var buf [20]byte
	i := len(buf)
	
	// Generate digits in reverse order
	for u >= 10 {
		q := u / 10
		i--
		buf[i] = byte('0' + u - q*10)
		u = q
	}
	// Handle the last digit
	i--
	buf[i] = byte('0' + u)
	
	return string(buf[i:])
}

// formatUint64Base16 formats a uint64 in base 16 using bit shifts.
func formatUint64Base16(u uint64) string {
	// Calculate number of hex digits needed
	if u == 0 {
		return "0"
	}
	
	// Find the position of the highest bit
	nbits := 64 - bits.LeadingZeros64(u)
	// Number of hex digits = ceiling(nbits / 4)
	ndigits := (nbits + 3) / 4
	
	var buf [16]byte // max 16 hex digits for uint64
	i := len(buf)
	
	for u > 0 {
		buf[i-1] = digits[u&0xF]
		u >>= 4
		i--
	}
	
	return string(buf[len(buf)-ndigits:])
}

// formatUint64Base8 formats a uint64 in base 8 using bit shifts.
func formatUint64Base8(u uint64) string {
	if u == 0 {
		return "0"
	}
	
	// Find the position of the highest bit
	nbits := 64 - bits.LeadingZeros64(u)
	// Number of octal digits = ceiling(nbits / 3)
	ndigits := (nbits + 2) / 3
	
	var buf [22]byte // max 22 octal digits for uint64
	i := len(buf)
	
	for u > 0 {
		buf[i-1] = byte('0' + (u & 0x7))
		u >>= 3
		i--
	}
	
	return string(buf[len(buf)-ndigits:])
}

// formatUint64Base2 formats a uint64 in base 2 using bit shifts.
func formatUint64Base2(u uint64) string {
	if u == 0 {
		return "0"
	}
	
	// Find the position of the highest bit
	ndigits := 64 - bits.LeadingZeros64(u)
	
	var buf [64]byte // max 64 binary digits for uint64
	i := len(buf)
	
	for u > 0 {
		buf[i-1] = byte('0' + (u & 1))
		u >>= 1
		i--
	}
	
	return string(buf[len(buf)-ndigits:])
}

// formatUint64Generic formats a uint64 in any base from 2 to 36.
func formatUint64Generic(u uint64, base int) string {
	// Maximum digits needed for any base >= 2
	var buf [64]byte
	i := len(buf)
	
	b := uint64(base)
	for u >= b {
		i--
		buf[i] = digits[u%b]
		u /= b
	}
	i--
	buf[i] = digits[u]
	
	return string(buf[i:])
}

// appendUint64Base10 appends a uint64 in base 10 to dst.
func appendUint64Base10(dst []byte, u uint64) []byte {
	var buf [20]byte
	i := len(buf)
	
	for u >= 10 {
		q := u / 10
		i--
		buf[i] = byte('0' + u - q*10)
		u = q
	}
	i--
	buf[i] = byte('0' + u)
	
	return append(dst, buf[i:]...)
}

// appendUint64Base16 appends a uint64 in base 16 to dst.
func appendUint64Base16(dst []byte, u uint64) []byte {
	if u == 0 {
		return append(dst, '0')
	}
	
	nbits := 64 - bits.LeadingZeros64(u)
	ndigits := (nbits + 3) / 4
	
	var buf [16]byte
	i := len(buf)
	
	for u > 0 {
		buf[i-1] = digits[u&0xF]
		u >>= 4
		i--
	}
	
	return append(dst, buf[len(buf)-ndigits:]...)
}

// appendUint64Base8 appends a uint64 in base 8 to dst.
func appendUint64Base8(dst []byte, u uint64) []byte {
	if u == 0 {
		return append(dst, '0')
	}
	
	nbits := 64 - bits.LeadingZeros64(u)
	ndigits := (nbits + 2) / 3
	
	var buf [22]byte
	i := len(buf)
	
	for u > 0 {
		buf[i-1] = byte('0' + (u & 0x7))
		u >>= 3
		i--
	}
	
	return append(dst, buf[len(buf)-ndigits:]...)
}

// appendUint64Base2 appends a uint64 in base 2 to dst.
func appendUint64Base2(dst []byte, u uint64) []byte {
	if u == 0 {
		return append(dst, '0')
	}
	
	ndigits := 64 - bits.LeadingZeros64(u)
	
	var buf [64]byte
	i := len(buf)
	
	for u > 0 {
		buf[i-1] = byte('0' + (u & 1))
		u >>= 1
		i--
	}
	
	return append(dst, buf[len(buf)-ndigits:]...)
}

// appendUint64Generic appends a uint64 in any base to dst.
func appendUint64Generic(dst []byte, u uint64, base int) []byte {
	var buf [64]byte
	i := len(buf)
	
	b := uint64(base)
	for u >= b {
		i--
		buf[i] = digits[u%b]
		u /= b
	}
	i--
	buf[i] = digits[u]
	
	return append(dst, buf[i:]...)
}

