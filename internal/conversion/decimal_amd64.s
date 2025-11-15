// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

#include "textflag.h"

// func convertDecimalExactAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (result float64, ok bool)
// AMD64 version - simplified to return false and use scalar fallback for correctness
// Full FMA implementation deferred pending thorough validation
TEXT ·convertDecimalExactAsm(SB), NOSPLIT, $0-50
	// Return false to use scalar implementation
	// FMA optimization deferred - needs more validation
	XORPD X0, X0
	MOVSD X0, result+40(FP)
	MOVB $0, ok+48(FP)
	RET

// func convertDecimalExtendedAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (result float64, ok bool)
// AMD64 version - simplified to return false and use scalar fallback
TEXT ·convertDecimalExtendedAsm(SB), NOSPLIT, $0-50
	// Return false to use scalar implementation
	XORPD X0, X0
	MOVSD X0, result+40(FP)
	MOVB $0, ok+48(FP)
	RET
