//go:build amd64

#include "textflag.h"

// func ParseIntAsm(s string, bitSize int) (i int64, err error)
// For now, delegate to the parseInt implementation
TEXT ·ParseIntAsm(SB), NOSPLIT, $0-48
	JMP ·parseInt(SB)
