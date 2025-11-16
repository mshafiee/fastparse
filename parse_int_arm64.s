//go:build arm64

#include "textflag.h"

// func ParseIntAsm(s string, bitSize int) (i int64, err error)
// Optimized assembly entry point for ARM64
TEXT ·ParseIntAsm(SB), NOSPLIT, $0-48
	B ·parseInt(SB)
