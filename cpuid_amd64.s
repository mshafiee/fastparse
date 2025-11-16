//go:build amd64

#include "textflag.h"

// func cpuidAMD64(eaxIn, ecxIn uint32) (eax, ebx, ecx, edx uint32)
TEXT ·cpuidAMD64(SB), NOSPLIT, $0-24
	MOVL eaxIn+0(FP), AX
	MOVL ecxIn+4(FP), CX
	CPUID
	MOVL AX, eax+8(FP)
	MOVL BX, ebx+12(FP)
	MOVL CX, ecx+16(FP)
	MOVL DX, edx+20(FP)
	RET

