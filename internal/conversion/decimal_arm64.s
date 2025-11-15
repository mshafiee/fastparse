// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build arm64

#include "textflag.h"

// func convertDecimalExactAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (result float64, ok bool)
// ARM64 version - simplified to return false and use scalar fallback
// Full FP implementation requires more complex Go assembler syntax
TEXT ·convertDecimalExactAsm(SB), NOSPLIT, $0-50
	// Return false to use scalar implementation
	// This avoids Go ARM64 assembler FP instruction limitations
	MOVD $0, R0
	MOVD R0, result+40(FP)
	MOVB R0, ok+48(FP)
	RET

// func convertDecimalExtendedAsm(mantissa uint64, exp int, neg bool, pow10Table []float64) (result float64, ok bool)
// ARM64 version - simplified to return false and use scalar fallback
TEXT ·convertDecimalExtendedAsm(SB), NOSPLIT, $0-50
	// Return false to use scalar implementation
	MOVD $0, R0
	MOVD R0, result+40(FP)
	MOVB R0, ok+48(FP)
	RET
