//go:build !amd64 && !arm64

package fastparse

// parseInt is the entry point for generic platforms
func parseInt(s string, bitSize int) (int64, error) {
	return parseIntGeneric(s, bitSize)
}

