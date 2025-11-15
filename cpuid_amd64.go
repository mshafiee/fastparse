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
	hasAVX2   bool
	hasAVX512 bool
	onceInit  sync.Once
)

// detectCPUFeatures uses CPUID to detect CPU capabilities
//
//go:noescape
func cpuidAMD64(eaxIn, ecxIn uint32) (eax, ebx, ecx, edx uint32)

func initCPUFeatures() {
	// Check for AVX2 support
	// CPUID.(EAX=07H, ECX=0H):EBX.AVX2[bit 5]
	_, ebx, _, _ := cpuidAMD64(7, 0)
	hasAVX2 = (ebx & (1 << 5)) != 0
	
	// Check for AVX-512F support (foundation)
	// CPUID.(EAX=07H, ECX=0H):EBX.AVX512F[bit 16]
	hasAVX512 = (ebx & (1 << 16)) != 0
}

// HasAVX2 returns true if the CPU supports AVX2 instructions
func HasAVX2() bool {
	onceInit.Do(initCPUFeatures)
	return hasAVX2
}

// HasAVX512 returns true if the CPU supports AVX-512 instructions
func HasAVX512() bool {
	onceInit.Do(initCPUFeatures)
	return hasAVX512
}

