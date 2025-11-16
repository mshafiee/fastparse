//go:build amd64

#include "textflag.h"

// func ParseFloatAsm(s string) (f float64, err error)
// Optimized assembly entry point for AMD64
TEXT ·ParseFloatAsm(SB), NOSPLIT, $0-40
	JMP ·parseFloat(SB)
