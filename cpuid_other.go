//go:build !amd64

package fastparse

// HasAVX2 returns false on non-amd64 platforms
func HasAVX2() bool {
	return false
}

// HasAVX512 returns false on non-amd64 platforms
func HasAVX512() bool {
	return false
}

