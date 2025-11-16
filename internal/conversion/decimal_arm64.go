//go:build arm64

package conversion

// Assembly implementations
//
//go:noescape
func convertDecimalExactAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool)

//go:noescape
func convertDecimalExtendedAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool)

func convertDecimalExactImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExactAsm(mantissa, exp, neg, pow10Table)
}

func convertDecimalExtendedImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExtendedAsm(mantissa, exp, neg, pow10Table)
}
