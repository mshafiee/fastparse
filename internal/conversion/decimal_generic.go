// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !amd64 && !arm64

package conversion

func convertDecimalExactImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExactScalar(mantissa, exp, neg, pow10Table)
}

func convertDecimalExtendedImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	return convertDecimalExtendedScalar(mantissa, exp, neg, pow10Table)
}

