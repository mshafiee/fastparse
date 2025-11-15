// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Constants for AMD64 assembly fast paths

// Character constants
#define CHAR_ZERO      '0'
#define CHAR_NINE      '9'
#define CHAR_DOT       '.'
#define CHAR_MINUS     '-'
#define CHAR_PLUS      '+'
#define CHAR_E_LOWER   'e'
#define CHAR_E_UPPER   'E'
#define CHAR_X_LOWER   'x'
#define CHAR_X_UPPER   'X'
#define CHAR_P_LOWER   'p'
#define CHAR_P_UPPER   'P'
#define CHAR_A_LOWER   'a'
#define CHAR_F_LOWER   'f'
#define CHAR_A_UPPER   'A'
#define CHAR_F_UPPER   'F'

// Numeric constants
#define TEN            10
#define SIXTEEN        16
#define NINETEEN       19
#define MAX_EXP        10000

// Bit masks
#define SIGN_BIT       0x8000000000000000

// Exponent bias for float64
#define EXP_BIAS       1023
#define EXP_BITS       11
#define MANTISSA_BITS  52
#define IMPLICIT_BIT   0x0010000000000000

// SIMD constants for AVX2
#define ZERO_VECTOR    0x00
#define DIGIT_LOWER    0x30  // '0'
#define DIGIT_UPPER    0x39  // '9'

