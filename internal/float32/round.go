package float32

import (
	"math"
)

const (
	// MaxFloat32 is the largest finite value representable by float32
	MaxFloat32 = 0x1p127 * (1 + (1 - 0x1p-23))
	// SmallestNonzeroFloat32 is the smallest positive, non-zero value representable by float32
	SmallestNonzeroFloat32 = 0x1p-126 * 0x1p-23
)

// RoundFloat32 rounds a float64 value to float32 precision and returns it as float64.
// It handles overflow and underflow according to IEEE 754 semantics.
// Returns the rounded value and a boolean indicating if overflow occurred.
func RoundFloat32(f float64) (result float64, overflow bool) {
	// Handle special values
	if math.IsNaN(f) {
		return f, false
	}
	if math.IsInf(f, 0) {
		return f, false
	}
	
	// Convert to float32 and back to get proper rounding
	f32 := float32(f)
	result = float64(f32)
	
	// Check for overflow: if the result is infinity but the input wasn't
	if math.IsInf(result, 0) && !math.IsInf(f, 0) {
		return result, true
	}
	
	return result, false
}

// IsFloat32Overflow checks if a float64 value would overflow when converted to float32.
func IsFloat32Overflow(f float64) bool {
	if math.IsInf(f, 0) || math.IsNaN(f) {
		return false
	}
	
	abs := math.Abs(f)
	return abs > MaxFloat32
}

