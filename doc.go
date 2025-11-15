// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package fastparse implements ultra-fast number parsing and formatting optimized for
// amd64 and arm64 architectures.
//
// # Performance
//
// On supported amd64 and arm64 CPUs, fastparse provides significantly
// faster parsing than the standard library's strconv package through
// architecture-specific assembly implementations and optimized fast paths.
//
// # API
//
// The package provides comprehensive strconv-compatible functions:
//
// Parsing:
//
//	ParseBool(str string) (bool, error)
//	ParseFloat(s string, bitSize int) (float64, error)
//	ParseFloatBytes(b []byte) (float64, error)
//	MustParseFloat(s string) float64
//	ParseInt(s string, base int, bitSize int) (int64, error)
//	ParseUint(s string, base int, bitSize int) (uint64, error)
//	ParseComplex(s string, bitSize int) (complex128, error)
//	Atoi(s string) (int, error)
//
// Formatting:
//
//	FormatBool(b bool) string
//	FormatInt(i int64, base int) string
//	FormatUint(i uint64, base int) string
//	FormatFloat(f float64, fmt byte, prec, bitSize int) string
//	FormatComplex(c complex128, fmt byte, prec, bitSize int) string
//	Itoa(i int) string
//
// Appending:
//
//	AppendBool(dst []byte, b bool) []byte
//	AppendInt(dst []byte, i int64, base int) []byte
//	AppendUint(dst []byte, i uint64, base int) []byte
//	AppendFloat(dst []byte, f float64, fmt byte, prec, bitSize int) []byte
//
// Quoting:
//
//	Quote(s string) string
//	QuoteToASCII(s string) string
//	QuoteToGraphic(s string) string
//	QuoteRune(r rune) string
//	Unquote(s string) (string, error)
//	CanBackquote(s string) bool
//
// Utilities:
//
//	IsPrint(r rune) bool
//	IsGraphic(r rune) bool
//
// fastparse is a drop-in replacement for strconv with optimized implementations
// for common use cases. All 34 public functions from strconv are implemented
// with identical signatures and behavior.
//
// # Drop-in Replacement
//
// To use fastparse as a replacement for strconv, simply change your import:
//
//	import strconv "github.com/mshafiee/fastparse"
//
// All function calls, error handling, and behavior remain identical to strconv.
//
// # Correctness
//
// fastparse aims to be a drop-in replacement for strconv with identical
// edge-case handling. The implementation is validated against strconv using
// unit tests and fuzzing. Error messages and formats match strconv exactly.
//
// # Errors
//
// The package returns the following sentinel errors that match strconv exactly:
//
//	ErrSyntax    - invalid syntax (matches strconv.ErrSyntax message)
//	ErrRange     - value out of range (matches strconv.ErrRange message)
//	ErrOverflow  - integer overflow
//	ErrUnderflow - floating-point underflow
//
// NumError format matches strconv.NumError exactly for drop-in compatibility.
// Error messages are identical to strconv for seamless replacement.
//
// # Safety
//
// The parsers are implemented to avoid heap allocations and to respect
// input bounds. Additional sanitizer and fuzz tests are provided in the
// repository.
package fastparse
