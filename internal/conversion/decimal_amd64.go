// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package conversion

import "golang.org/x/sys/cpu"

// Assembly implementations
//go:noescape
func convertDecimalExactAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool)

//go:noescape
func convertDecimalExtendedAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool)

var useFMA bool

func init() {
	// Check for FMA3 support
	useFMA = cpu.X86.HasFMA
}

func convertDecimalExactImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	if useFMA {
		return convertDecimalExactAsm(mantissa, exp, neg, pow10Table)
	}
	return convertDecimalExactScalar(mantissa, exp, neg, pow10Table)
}

func convertDecimalExtendedImpl(mantissa uint64, exp int, neg bool, pow10Table []float64) (float64, bool) {
	if useFMA {
		return convertDecimalExtendedAsm(mantissa, exp, neg, pow10Table)
	}
	return convertDecimalExtendedScalar(mantissa, exp, neg, pow10Table)
}

