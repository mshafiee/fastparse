// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package ryu

import (
	"math"
	"math/bits"
)

// Ryū algorithm for float32 to decimal conversion

const (
	FLOAT_MANTISSA_BITS     = 23
	FLOAT_EXPONENT_BITS     = 8
	FLOAT_BIAS              = 127
	FLOAT_POW5_INV_BITCOUNT = 59
	FLOAT_POW5_BITCOUNT     = 61
)

// pow5Split_f32 contains power-of-5 tables for float32
// For float32, we need smaller tables than float64
var pow5Split_f32 = [47][2]uint64{
	{0x0, 0x1},                          // 5^0
	{0x0, 0x5},                          // 5^1
	{0x0, 0x19},                         // 5^2
	{0x0, 0x7d},                         // 5^3
	{0x0, 0x271},                        // 5^4
	{0x0, 0xc35},                        // 5^5
	{0x0, 0x3d09},                       // 5^6
	{0x0, 0x1312d},                      // 5^7
	{0x0, 0x5f5e1},                      // 5^8
	{0x0, 0x1dcd65},                     // 5^9
	{0x0, 0x9502f9},                     // 5^10
	{0x0, 0x2e90edd},                    // 5^11
	{0x0, 0xe8d4a51},                    // 5^12
	{0x0, 0x48c27395},                   // 5^13
	{0x0, 0x16bcc41e9},                  // 5^14
	{0x0, 0x71afd498d},                  // 5^15
	{0x0, 0x2386f26fc1},                 // 5^16
	{0x0, 0xb1a2bc2ec5},                 // 5^17
	{0x0, 0x3782dace9d9},                // 5^18
	{0x0, 0x1158e460913d},               // 5^19
	{0x0, 0x56bc75e2d631},               // 5^20
	{0x0, 0x1b1ae4d6e2ef5},              // 5^21
	{0x0, 0x878678326eac9},              // 5^22
	{0x0, 0x2a5a058fc295ed},             // 5^23
	{0x0, 0xd3c21bcecceda1},             // 5^24
	{0x0, 0x422ca8b0a00a425},            // 5^25
	{0x0, 0x14adf4b7320334b9},           // 5^26
	{0x0, 0x6765c793fa10079d},           // 5^27
	{0x2, 0x4fce5e3e2502611},            // 5^28
	{0xa, 0x18f07d736b90be55},           // 5^29
	{0x32, 0x7cb2734119d3b7a9},          // 5^30
	{0xfc, 0x6f7c40458122964d},          // 5^31
	{0x4ee, 0x2d6d415b85acef81},         // 5^32
	{0x18a6, 0xe32246c99c60ad85},        // 5^33
	{0x7b42, 0x6fab61f00de36399},        // 5^34
	{0x2684c, 0x2e58e9b04570f1fd},       // 5^35
	{0xc097c, 0xe7bc90715b34b9f1},       // 5^36
	{0x3c2f70, 0x86aed236c807a1b5},      // 5^37
	{0x12ced32, 0xa16a1b11e8262889},     // 5^38
	{0x5e0a1fd, 0x2712875988becaad},     // 5^39
	{0x1d6329f1, 0xc35ca4bfabb9f561},    // 5^40
	{0x92efd1b8, 0xd0cf37be5aa1cae5},    // 5^41
	{0x2deaf189c, 0x140c16b7c528f679},   // 5^42
	{0xe596b7b0c, 0x643c7196d9ccd05d},   // 5^43
	{0x47bf19673d, 0xf52e37f2410011d1},  // 5^44
	{0x166bb7f0435, 0xc9e717bb45005915}, // 5^45
	{0x701a97b150c, 0xf18376a85901bd69}, // 5^46
}

var pow5InvSplit_f32 = [55][2]uint64{
	{0x1, 0x0},                // ceil(2^59 / 5^0)
	{0x0, 0xcccccccccccccccd}, // ceil(2^60 / 5^1)
	{0x0, 0xa3d70a3d70a3d70b}, // ceil(2^61 / 5^2)
	{0x0, 0x83126e978d4fdf3c}, // ceil(2^62 / 5^3)
	{0x0, 0xd1b71758e219652c}, // ceil(2^63 / 5^4)
	{0x0, 0xa7c5ac471b478424}, // ceil(2^64 / 5^5)
	{0x0, 0x8637bd05af6c69b6}, // ceil(2^65 / 5^6)
	{0x0, 0xd6bf94d5e57a42bd}, // ceil(2^66 / 5^7)
	{0x0, 0xabcc77118461cefd}, // ceil(2^67 / 5^8)
	{0x0, 0x89705f4136b4a598}, // ceil(2^68 / 5^9)
	{0x0, 0xdbe6fecebdedd5bf}, // ceil(2^69 / 5^10)
	{0x0, 0xafebff0bcb24aaff}, // ceil(2^70 / 5^11)
	{0x0, 0x8cbccc096f5088cc}, // ceil(2^71 / 5^12)
	{0x0, 0xe12e13424bb40e14}, // ceil(2^72 / 5^13)
	{0x0, 0xb424dc35095cd810}, // ceil(2^73 / 5^14)
	{0x0, 0x901d7cf73ab0acda}, // ceil(2^74 / 5^15)
	{0x0, 0xe69594bec44de15c}, // ceil(2^75 / 5^16)
	{0x0, 0xb877aa3236a4b44a}, // ceil(2^76 / 5^17)
	{0x0, 0x9392ee8e921d5d08}, // ceil(2^77 / 5^18)
	{0x0, 0xec1e4a7db69561a6}, // ceil(2^78 / 5^19)
	{0x0, 0xbce5086492111aeb}, // ceil(2^79 / 5^20)
	{0x0, 0x971da05074da7bef}, // ceil(2^80 / 5^21)
	{0x0, 0xf1c90080baf72cb2}, // ceil(2^81 / 5^22)
	{0x0, 0xc16d9a0095928a28}, // ceil(2^82 / 5^23)
	{0x0, 0x9abe14cd44753b53}, // ceil(2^83 / 5^24)
	{0x0, 0xf79687aed3eec552}, // ceil(2^84 / 5^25)
	{0x0, 0xc612062576589ddb}, // ceil(2^85 / 5^26)
	{0x0, 0x9e74d1b791e07e49}, // ceil(2^86 / 5^27)
	{0x0, 0xfd87b5f28300ca0e}, // ceil(2^87 / 5^28)
	{0x0, 0xcad2f7f5359a3b3f}, // ceil(2^88 / 5^29)
	{0x0, 0xa2425ff75e14fc32}, // ceil(2^89 / 5^30)
	{0x1, 0x81ceb32c4b43fcf5}, // ceil(2^90 / 5^31)
	{0x1, 0x3d7f783b4c0a6f1},  // ceil(2^91 / 5^32)
	{0x0, 0xf6c69a72a3989f5c}, // ceil(2^92 / 5^33)
	{0x0, 0xc5371912364ce306}, // ceil(2^93 / 5^34)
	{0x0, 0x9d9ba7832936edc1}, // ceil(2^94 / 5^35)
	{0x0, 0xfb9dc700f77e2a9a}, // ceil(2^95 / 5^36)
	{0x0, 0xc97e3f65c9e30c89}, // ceil(2^96 / 5^37)
	{0x0, 0xa0ff8ae7a7d2f5a7}, // ceil(2^97 / 5^38)
	{0x1, 0x14f6ec8507bf0a99}, // ceil(2^98 / 5^39)
	{0x0, 0xfdcb4fa002162a64}, // ceil(2^99 / 5^40)
	{0x0, 0xcb090c8001bd82a},  // ceil(2^100 / 5^41)
	{0x0, 0xa2db947e18f9e857}, // ceil(2^101 / 5^42)
	{0x1, 0x87f421e5c7e76c8},  // ceil(2^102 / 5^43)
	{0x1, 0x19f92a4b24b760a},  // ceil(2^103 / 5^44)
	{0x0, 0xe94c2ebcc01b28f5}, // ceil(2^104 / 5^45)
	{0x0, 0xba4a18ee21a0b98f}, // ceil(2^105 / 5^46)
	{0x0, 0x953e2f4d7e5c3a73}, // ceil(2^106 / 5^47)
	{0x0, 0xefb2b6f8372c68f1}, // ceil(2^107 / 5^48)
	{0x0, 0xbf5cdba588af8959}, // ceil(2^108 / 5^49)
	{0x0, 0x98ee450917088991}, // ceil(2^109 / 5^50)
	{0x0, 0xf6494f6cf4ee86ed}, // ceil(2^110 / 5^51)
	{0x0, 0xc4ad6e5cfb842f91}, // ceil(2^111 / 5^52)
	{0x0, 0x9d2b8cb7c0e6ae74}, // ceil(2^112 / 5^53)
	{0x0, 0xfbb8c17967aa9c2e}, // ceil(2^113 / 5^54)
}

// FormatFloat32 converts a float32 to its shortest decimal representation.
func FormatFloat32(f float32) ([]byte, int) {
	// Handle special cases
	if math.IsNaN(float64(f)) {
		return []byte("NaN"), 0
	}
	if math.IsInf(float64(f), 1) {
		return []byte("+Inf"), 0
	}
	if math.IsInf(float64(f), -1) {
		return []byte("-Inf"), 0
	}
	if f == 0 {
		if math.Signbit(float64(f)) {
			return []byte("-0"), 0
		}
		return []byte("0"), 0
	}

	// Extract IEEE 754 bits
	bits := math.Float32bits(f)
	ieeeSign := (bits >> 31) != 0
	ieeeMantissa := bits & ((1 << FLOAT_MANTISSA_BITS) - 1)
	ieeeExponent := int32((bits >> FLOAT_MANTISSA_BITS) & ((1 << FLOAT_EXPONENT_BITS) - 1))

	var e2 int32
	var m2 uint32

	if ieeeExponent == 0 {
		// Subnormal number
		e2 = 1 - FLOAT_BIAS - FLOAT_MANTISSA_BITS
		m2 = ieeeMantissa
	} else {
		// Normal number
		e2 = ieeeExponent - FLOAT_BIAS - FLOAT_MANTISSA_BITS
		m2 = (1 << FLOAT_MANTISSA_BITS) | ieeeMantissa
	}

	// Convert to decimal using Ryū algorithm
	output, decimalExponent := f2dGeneral(m2, e2)

	// Add sign if needed
	if ieeeSign {
		result := make([]byte, len(output)+1)
		result[0] = '-'
		copy(result[1:], output)
		return result, decimalExponent
	}

	return output, decimalExponent
}

// f2dGeneral implements the Ryū algorithm for float32
func f2dGeneral(m2 uint32, e2 int32) ([]byte, int) {
	acceptBounds := (m2 & 1) == 0

	mv := uint64(m2) << 2
	mmShift := uint32(1)
	if m2 != (1<<FLOAT_MANTISSA_BITS) || e2 <= -(FLOAT_BIAS+FLOAT_MANTISSA_BITS+2) {
		mmShift = 0
	}

	var e10 int32
	var vr, vp, vm uint64
	var removed int32

	if e2 >= 0 {
		q := log10Pow2(e2)
		e10 = q
		k := int32(FLOAT_POW5_INV_BITCOUNT) + pow5bits(q) - 1
		i := -e2 + q + k

		// Use float32 tables with bounds check
		if q >= 0 && q < int32(len(pow5InvSplit_f32)) {
			mul := pow5InvSplit_f32[q]
			vr = mulShift32(uint32(mv), mul, uint(i))
			vp = mulShift32(uint32(mv+2), mul, uint(i))
			vm = mulShift32(uint32(mv-uint64(mmShift)-1), mul, uint(i))

			if q > 0 && q-1 >= 0 && (vp-1)/10 <= vm/10 {
				l := int32(FLOAT_POW5_INV_BITCOUNT) + pow5bits(q-1) - 1
				lastRemovedDigit := uint8(mulShift32(uint32(mv), pow5InvSplit_f32[q-1], uint(-e2+q-1+l)) % 10)
				removed = int32(lastRemovedDigit)
			}
		} else {
			// Fallback for out of range
			return formatMantissa64(uint64(m2)), int(e2)
		}
	} else {
		q := log10Pow5(-e2)
		e10 = q + e2
		i := -e2 - q
		k := pow5bits(i) - int32(FLOAT_POW5_BITCOUNT)
		j := q - k

		// Use float32 tables with bounds check
		if i >= 0 && i < int32(len(pow5Split_f32)) {
			mul := pow5Split_f32[i]
			vr = mulShift32(uint32(mv), mul, uint(j))
			vp = mulShift32(uint32(mv+2), mul, uint(j))
			vm = mulShift32(uint32(mv-uint64(mmShift)-1), mul, uint(j))

			if q != 0 && i+1 < int32(len(pow5Split_f32)) && (vp-1)/10 <= vm/10 {
				j2 := q - 1 - (pow5bits(i+1) - int32(FLOAT_POW5_BITCOUNT))
				lastRemovedDigit := uint8(mulShift32(uint32(mv), pow5Split_f32[i+1], uint(j2)) % 10)
				removed = int32(lastRemovedDigit)
			}
		} else {
			// Fallback for out of range
			return formatMantissa64(uint64(m2)), int(e2)
		}
	}

	// Remove trailing zeros and round
	var output uint64
	var lastRemovedDigit uint8

	if acceptBounds {
		for vp/10 > vm/10 {
			lastRemovedDigit = uint8(vr % 10)
			vr /= 10
			vp /= 10
			vm /= 10
			removed++
		}
		if removed > 0 && lastRemovedDigit == 5 && vr%2 == 0 {
			lastRemovedDigit = 4
		}
		output = vr
		if lastRemovedDigit >= 5 {
			output++
		}
	} else {
		for vp/10 > vm/10 {
			lastRemovedDigit = uint8(vr % 10)
			vr /= 10
			vp /= 10
			vm /= 10
			removed++
		}
		output = vr
		if vr == vm && lastRemovedDigit >= 5 {
			output++
		} else if lastRemovedDigit >= 5 {
			output++
		}
	}

	return formatMantissa64(output), int(e10) + int(removed)
}

// mulShift32 performs (m * mul) >> shift for 32-bit mantissa
func mulShift32(m uint32, mul [2]uint64, shift uint) uint64 {
	// Convert m to uint64 for multiplication
	m64 := uint64(m)

	// m * mul[1] (low part)
	hi1, lo1 := bits.Mul64(m64, mul[1])

	// m * mul[0] (high part)
	hi2, lo2 := bits.Mul64(m64, mul[0])

	// Combine results
	lo := lo1
	mid := hi1 + lo2
	hi := hi2
	if mid < lo2 {
		hi++
	}

	// Shift right
	if shift >= 128 {
		return hi >> (shift - 128)
	} else if shift >= 64 {
		s := shift - 64
		if s == 0 {
			return mid
		}
		return (mid >> s) | (hi << (64 - s))
	} else {
		if shift == 0 {
			return lo
		}
		return (lo >> shift) | (mid << (64 - shift))
	}
}
