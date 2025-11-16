package conversion

// ConvertDecimalExact attempts exact float64 arithmetic conversion
// Returns (result, true) if exact conversion possible, (0, false) otherwise
func ConvertDecimalExact(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExactImpl(mantissa, exp, neg, pow10Table)
}

// ConvertDecimalExtended handles long decimals using optimized rounding + exact table
// Returns (result, true) if successful, (0, false) to fall back to big.Float
func ConvertDecimalExtended(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExtendedImpl(mantissa, exp, neg, pow10Table)
}

