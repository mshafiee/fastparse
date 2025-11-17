// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build amd64

package fastparse

import (
	"sync"
)

// CPU feature flags
var (
	hasAVX2      bool
	hasAVX512F   bool
	hasAVX512BW  bool
	hasAVX512DQ  bool
	hasBMI2      bool
	onceInit     sync.Once
)

// detectCPUFeatures uses CPUID to detect CPU capabilities
//
//go:noescape
func cpuidAMD64(eaxIn, ecxIn uint32) (eax, ebx, ecx, edx uint32)

func initCPUFeatures() {
	// Check for AVX2 and BMI2 support
	// CPUID.(EAX=07H, ECX=0H):EBX
	_, ebx, _, _ := cpuidAMD64(7, 0)
	hasAVX2 = (ebx & (1 << 5)) != 0
	hasBMI2 = (ebx & (1 << 8)) != 0
	
	// Check for AVX-512 support
	// AVX512F (Foundation) - bit 16
	// AVX512BW (Byte/Word) - bit 30
	// AVX512DQ (Doubleword/Quadword) - bit 17
	hasAVX512F = (ebx & (1 << 16)) != 0
	hasAVX512DQ = (ebx & (1 << 17)) != 0
	hasAVX512BW = (ebx & (1 << 30)) != 0
}

// HasAVX2 returns true if the CPU supports AVX2 instructions
func HasAVX2() bool {
	onceInit.Do(initCPUFeatures)
	return hasAVX2
}

// HasAVX512 returns true if the CPU supports AVX-512F instructions
func HasAVX512() bool {
	onceInit.Do(initCPUFeatures)
	return hasAVX512F
}

// HasAVX512BW returns true if the CPU supports AVX-512 Byte/Word instructions
func HasAVX512BW() bool {
	onceInit.Do(initCPUFeatures)
	return hasAVX512BW
}

// HasBMI2 returns true if the CPU supports BMI2 instructions
func HasBMI2() bool {
	onceInit.Do(initCPUFeatures)
	return hasBMI2
}

