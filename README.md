# fastparse

[![Go Reference](https://pkg.go.dev/badge/github.com/mshafiee/fastparse.svg)](https://pkg.go.dev/github.com/mshafiee/fastparse)
[![Go Version](https://img.shields.io/badge/go-1.24+-blue.svg)](https://go.dev/dl/)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**Ultra-fast number parsing and formatting for Go** — Up to **2.4X faster** than `strconv` with aggressive SIMD and unsafe optimizations.

FastParse implements all 34 functions from Go's `strconv` package with heavily optimized implementations featuring:
- **Up to 2.4X speedup** — Achieved through SIMD, BMI2, and unsafe optimizations
- **SIMD acceleration** — AVX-512, AVX2, BMI2 (amd64) and NEON (arm64)
- **Zero-copy operations** — Unsafe conversions eliminating allocations
- **Massive lookup tables** — 256KB+ precomputed tables for instant results
- **100% compatible** — Drop-in replacement for strconv
- **Runtime CPU detection** — Automatic dispatch to best implementation

## Performance

FastParse delivers **up to 2.4X faster performance** compared to the standard library through aggressive SIMD optimizations, unsafe operations, and massive lookup tables:

### Parsing Benchmarks (Latest Results)

| Operation | Input Type | FastParse | Strconv | Speedup |
|-----------|-----------|-----------|---------|---------|
| `ParseFloat` | Short (4 digits) | 11.2 ns/op | 18.1 ns/op | **61% faster (1.61x)** |
| `ParseFloat` | Medium (8 digits) | 13.2 ns/op | 24.0 ns/op | **82% faster (1.82x)** |
| `ParseFloat` | Long (16 digits) | 20.2 ns/op | 38.0 ns/op | **88% faster (1.88x)** |
| `ParseFloat` | Scientific | 15.2 ns/op | 22.6 ns/op | **49% faster (1.49x)** |
| `ParseFloat` | Scientific (long) | 46.2 ns/op | 54.2 ns/op | **17% faster (1.17x)** |
| `ParseInt` | Short (4 digits) | 9.9 ns/op | 10.0 ns/op | **1% faster (1.01x)** |
| `ParseInt` | Medium (8 digits) | 17.4 ns/op | 15.7 ns/op | **10% slower (0.90x)** |
| `ParseInt` | Long (16 digits) | 23.9 ns/op | 24.5 ns/op | **2% faster (1.02x)** |
| `ParseInt` | Max positive (19 digits) | 32.1 ns/op | 40.0 ns/op | **25% faster (1.25x)** |
| `ParseInt` | Max negative (19 digits) | 28.6 ns/op | 67.7 ns/op | **136% faster (2.36x)** 🚀 |
| `ParseUint` | Short (4 digits) | 7.6 ns/op | 8.3 ns/op | **9% faster (1.09x)** |
| `ParseUint` | Medium (8 digits) | 11.5 ns/op | 11.6 ns/op | **1% faster (1.01x)** |
| `ParseUint` | Long (16 digits) | 21.7 ns/op | 21.7 ns/op | **Same speed (1.00x)** |
| `ParseUint` | MaxUint64 (20 digits) | 25.4 ns/op | 27.2 ns/op | **7% faster (1.07x)** |

### Quoting Benchmarks (Apple M1 Pro, ARM64 NEON)

| Operation | Input Type | FastParse | Strconv | Speedup |
|-----------|-----------|-----------|---------|---------|
| `Quote` | Short ASCII | 72.1 ns/op | 82.2 ns/op | **12% faster** |
| `Quote` | ASCII (32 bytes) | 166 ns/op | 189 ns/op | **12% faster** |
| `Quote` | ASCII (64 bytes) | 371 ns/op | 363 ns/op | **2% slower** |
| `Quote` | ASCII (128 bytes) | 699 ns/op | 745 ns/op | **6% faster** |
| `QuoteToASCII` | Unicode | 202 ns/op | 263 ns/op | **23% faster** |

### Other Benchmarks (Apple M1 Pro, ARM64 NEON)

| Operation | Input Type | FastParse | Strconv | Speedup |
|-----------|-----------|-----------|---------|---------|
| `IsGraphic` | Character | 2.15 ns/op | 3.05 ns/op | **29% faster** |
| `AppendInt` | Base16 (large) | 12.8 ns/op | 17.8 ns/op | **28% faster** |

### Key Performance Highlights

- **🚀 2.4X faster** for negative integer parsing (ParseInt)
- **🚀 1.9X faster** for long float parsing (ParseFloat 16 digits)
- **🚀 1.8X faster** for medium float parsing (ParseFloat 8 digits)
- **Zero allocations** across all parsing operations
- **SIMD acceleration** with AVX-512, AVX2 (AMD64) and NEON (ARM64)
- **BMI2 optimizations** for division-free overflow checking on modern CPUs
- **Unsafe operations** eliminating bounds checking in hot paths
- **256KB+ lookup tables** for ultra-fast number formatting

*Benchmarks run with Go 1.24+ on systems supporting modern CPU features. Performance varies by input size and CPU capabilities.*

## Installation

```bash
go get github.com/mshafiee/fastparse
```

## Usage

### Drop-in Replacement

FastParse is a complete drop-in replacement for `strconv`:

```go
import strconv "github.com/mshafiee/fastparse"

// All strconv functions work exactly the same
f, err := strconv.ParseFloat("123.456", 64)
i, err := strconv.ParseInt("12345", 10, 64)
s := strconv.FormatFloat(3.14159, 'f', 2, 64)
```

### Direct Usage

Or use it alongside strconv:

```go
import "github.com/mshafiee/fastparse"

// Parsing
f, err := fastparse.ParseFloat("123.456", 64)
i, err := fastparse.ParseInt("12345", 10, 64)
u, err := fastparse.ParseUint("12345", 10, 64)
b, err := fastparse.ParseBool("true")
c, err := fastparse.ParseComplex("(1+2i)", 128)

// Formatting
s := fastparse.FormatFloat(3.14159, 'f', 2, 64)  // "3.14"
s := fastparse.FormatInt(-42, 16)                 // "-2a"
s := fastparse.FormatUint(42, 16)                 // "2a"
s := fastparse.FormatBool(true)                   // "true"

// Quoting
s := fastparse.Quote("hello\nworld")              // "\"hello\\nworld\""
s, err := fastparse.Unquote(`"hello\nworld"`)    // "hello\nworld"

// Zero-allocation variants
f, err := fastparse.ParseFloatBytes([]byte("123.456"), 64)
dst := fastparse.AppendFloat(dst, 3.14, 'f', 2, 64)
```

### Bonus Functions

FastParse includes additional zero-allocation functions:

```go
// Parse from []byte without allocation
f, err := fastparse.ParseFloatBytes(b, 64)
i, err := fastparse.ParseIntBytes(b, 10, 64)
u, err := fastparse.ParseUintBytes(b, 10, 64)
c, err := fastparse.ParseComplexBytes(b, 128)

// Panic on error (for known-valid input)
f := fastparse.MustParseFloat("123.456")
```

## API Coverage

FastParse implements **all 34 public functions** from Go's `strconv` package:

### Parsing Functions (6)

| Function | Status | Notes |
|----------|--------|-------|
| `ParseBool` | ✅ Native | Simple switch-based parser |
| `ParseFloat` | ✅ Native | 3-tier optimization with assembly |
| `ParseInt` | ✅ Native | Multi-base (2-36) with FSA |
| `ParseUint` | ✅ Native | Multi-base with underscore support |
| `ParseComplex` | ✅ Native | Full format support |
| `Atoi` | ✅ Native | Wrapper around ParseInt |

### Formatting Functions (6)

| Function | Status | Notes |
|----------|--------|-------|
| `FormatBool` | ✅ Native | Direct string return |
| `FormatFloat` | ✅ Native | Ryū algorithm with big.Float |
| `FormatInt` | ✅ Native | Optimized for bases 2, 8, 10, 16 |
| `FormatUint` | ✅ Native | Division-free for power-of-2 bases |
| `FormatComplex` | ✅ Native | Uses Ryū for components |
| `Itoa` | ✅ Native | Wrapper around FormatInt |

### Append Functions (10)

| Function | Status | Notes |
|----------|--------|-------|
| `AppendBool` | ✅ Native | Zero allocation |
| `AppendFloat` | ✅ Native | Ryū algorithm |
| `AppendInt` | ✅ Native | Zero allocation |
| `AppendUint` | ✅ Native | Zero allocation |
| `AppendComplex` | ✅ Native | Zero allocation |
| `AppendQuote` | ✅ Native | SIMD optimized |
| `AppendQuoteRune` | ✅ Native | Full Unicode support |
| `AppendQuoteRuneToASCII` | ✅ Native | ASCII escape sequences |
| `AppendQuoteRuneToGraphic` | ✅ Native | Graphic character support |
| `AppendQuoteToASCII` | ✅ Native | SIMD + ASCII escaping |
| `AppendQuoteToGraphic` | ✅ Native | SIMD + graphic filtering |

### Quoting Functions (9)

| Function | Status | Notes |
|----------|--------|-------|
| `Quote` | ✅ Native | SIMD fast path for ASCII |
| `QuoteToASCII` | ✅ Native | SIMD optimized |
| `QuoteToGraphic` | ✅ Native | Unicode-aware |
| `QuoteRune` | ✅ Native | Full escape sequences |
| `QuoteRuneToASCII` | ✅ Native | Hex escaping |
| `QuoteRuneToGraphic` | ✅ Native | Graphic filtering |
| `Unquote` | ✅ Native | State machine parser |
| `UnquoteChar` | ✅ Native | Single character unquoting |
| `QuotedPrefix` | ✅ Native | Prefix extraction |

### Utility Functions (3)

| Function | Status | Notes |
|----------|--------|-------|
| `IsPrint` | ✅ Native | Binary search lookup tables |
| `IsGraphic` | ✅ Native | Unicode range tables |
| `CanBackquote` | ✅ Native | Fast validation |

**Total: 34/34 strconv functions + 5 bonus functions**

## Technical Implementation

### Architecture Overview

```
fastparse/
├── Core Parsing (Multi-tier optimization)
│   ├── ParseFloat: 3-tier (fast path → Eisel-Lemire → fallback)
│   ├── ParseInt: AVX-512/AVX2/BMI2 → SIMD batching → Scalar fallback
│   └── ParseUint: BMI2-optimized overflow checking
│
├── Core Formatting
│   ├── FormatFloat: Ryū algorithm using big.Float
│   ├── FormatInt/Uint: Lookup table-based (256KB precomputed)
│   └── Quote/Unquote: AVX-512 64-byte SIMD with VPCOMPRESSB
│
├── SIMD Optimizations
│   ├── AVX-512: 64-byte operations + gather instructions (amd64)
│   ├── AVX2: 32-byte parallel operations (amd64)
│   ├── BMI2: MULX for division-free multiply (amd64)
│   └── NEON: 16-byte operations (arm64)
│
└── Unsafe Optimizations
    ├── Zero-copy string ↔ []byte conversions
    ├── Bounds check elimination in hot paths
    └── Massive precomputed lookup tables (40KB-256KB)
```

### Assembly Optimizations

**AMD64 (x86-64)**
- **AVX-512**: 64-byte vectorized operations with VPCOMPRESSB for selective processing
- **AVX2**: 32-byte parallel digit validation and conversion
- **BMI2**: MULX instruction for division-free overflow checking (2X faster than IDIV)
- **SSE2**: 16-byte fallback for older CPUs
- **Runtime CPU detection**: Automatic dispatch to best available implementation

**ARM64**
- **NEON SIMD**: Optimized 16-byte parallel operations
- **MADD instruction**: Fast multiply-accumulate for digit processing
- **Efficient scalar**: Optimized register allocation and branch-free validation
- **Load-pair/store-pair**: Memory throughput optimization

**Generic Fallback**
- Pure Go implementation for all platforms
- No performance degradation on unsupported architectures
- Maintains full compatibility

### SIMD Implementations

#### Quote/Unquote Fast Paths
- **AVX-512**: Process 64 bytes/iteration with mask operations
- **AVX2**: Process 32 bytes/iteration checking for quotes, backslashes, control chars
- **NEON**: Process 16 bytes/iteration with ARM vector instructions
- Detects if string needs escaping in single pass

#### Digit Validation
- **SSE2/AVX2**: Validate 16-32 digits in parallel
- **NEON**: Validate 16 digits in parallel
- Range checking using SIMD compare instructions

### Ryū Algorithm

FastParse implements the Ryū algorithm for float-to-string conversion:
- **Shortest representation**: Minimal digit output
- **All format modes**: e, E, f, g, G, b, x, X
- **Precision control**: Exact digit count or shortest form
- **Special values**: NaN, +Inf, -Inf handling
- **Uses big.Float** for reliable high-precision formatting

### Integer Formatting Optimizations

- **Lookup tables**: 40KB precomputed tables for 2-digit and 4-digit combinations
- **Base 10**: Process multiple digits per iteration using table lookups
- **Base 2, 8, 16**: Division-free using bit shifts
- **Generic bases 3-36**: Efficient modulo operations
- **Zero allocations**: Stack buffers for all operations
- **Unsafe operations**: Direct memory writes eliminating bounds checks

### CPU Feature Detection

Runtime detection with `sync.Once` initialization:

```go
// Automatically detects CPU capabilities
if HasAVX512() {
    // Use AVX-512 implementation
} else if HasAVX2() {
    // Use AVX2 implementation
} else {
    // Use generic implementation
}
```

## Internal Packages

| Package | Purpose |
|---------|---------|
| `internal/classifier` | FSA-based number classification |
| `internal/conversion` | Decimal to binary conversion |
| `internal/digitparse` | SIMD digit parsing |
| `internal/eisel_lemire` | Fast float parsing algorithm |
| `internal/float32` | IEEE 754 float32 rounding |
| `internal/fsa` | Finite state automaton for parsing |
| `internal/hexfloat` | Hexadecimal float support |
| `internal/intformat` | Native integer formatting |
| `internal/quoting` | SIMD-optimized quote/unquote |
| `internal/ryu` | Ryū float formatting algorithm |
| `internal/unicode_tables` | Unicode character classification |
| `internal/validation` | Input validation helpers |

## Benchmarking

Run benchmarks to compare with strconv:

```bash
# Run all benchmarks
go test -bench=. -benchmem

# Run SIMD-specific benchmarks
go test -bench=SIMD -benchmem

# Compare specific operations
go test -bench='ParseFloat' -benchmem
go test -bench='Quote' -benchmem
```

Run fuzz tests:

```bash
# Fuzz float parsing
go test -fuzz=FuzzParseFloatSIMD -fuzztime=30s

# Fuzz quote/unquote
go test -fuzz=FuzzQuoteSIMD -fuzztime=30s

# Fuzz all operations
go test -fuzz=. -fuzztime=1m
```

## Platform Support

| Platform | Status | Optimizations |
|----------|--------|---------------|
| **amd64** | ✅ Full support | AVX-512, AVX2, SSE2 |
| **arm64** | ✅ Full support | NEON |
| **386** | ✅ Pure Go | Generic fallback |
| **arm** | ✅ Pure Go | Generic fallback |
| **Other** | ✅ Pure Go | Generic fallback |

## Requirements

- **Go 1.24+** (for latest optimizations)
- No external dependencies for core functionality
- Optional: CPU with AVX2/AVX-512 for maximum performance

## Project Structure

```
fastparse/
├── README.md                  # This file
├── LICENSE                    # BSD 3-Clause
├── go.mod                     # Module definition
│
├── Core API (consolidated)
│   ├── parse.go              # All Parse* functions (ParseInt, ParseFloat, etc.)
│   ├── format.go             # All Format* functions (FormatInt, FormatFloat, etc.)
│   ├── quote.go              # Quote/Unquote functions
│   ├── errors.go             # Error types (NumError, ErrSyntax, ErrRange)
│   ├── unicode.go            # IsPrint/IsGraphic with Unicode tables
│   ├── decimal.go            # Shared decimal type
│   ├── bytealg.go            # Byte algorithms
│   └── doc.go                # Package documentation
│
│── Implementation files
│   ├── parse_*.go            # Float parsing implementations
│   ├── eisel_lemire.go       # Eisel-Lemire algorithm wrapper
│   ├── ftoaryu.go            # Ryu algorithm for float formatting
│   └── parse_*.go            # Integer parsing implementations
│
├── Architecture-specific
│   ├── unicode_*.go/s        # Unicode/IsPrint optimizations (amd64/arm64/generic)
│   ├── parse_*_amd64.go/s    # AMD64 parsing implementations
│   ├── parse_*_arm64.go/s    # ARM64 parsing implementations
│   ├── *_generic.go          # Generic fallbacks
│   ├── cpuid_*.go            # CPU feature detection
│   └── constants_*.h         # Assembly constants
│
├── Tests
│   ├── compat_*_test.go      # Compatibility tests with stdlib strconv
│   ├── parse_*_test.go       # Parse function tests
│   ├── format_*_test.go      # Format function tests
│   ├── quote_test.go         # Quote/unquote tests
│   ├── benchmark_*.go        # Benchmarks
│   ├── fuzz_*.go             # Fuzz tests
│   └── testdata/             # Test fixtures
│
└── internal/                 # Internal packages
    ├── classifier/           # Number classification
    ├── conversion/           # Type conversions
    ├── digitparse/           # Digit parsing
    ├── eisel_lemire/         # Fast float algorithm
    ├── float32/              # Float32 support
    ├── fsa/                  # Finite state automaton
    ├── hexfloat/             # Hex float support
    ├── intformat/            # Integer formatting
    ├── quoting/              # Quote/unquote core
    ├── ryu/                  # Ryū algorithm
    ├── unicode_tables/       # Unicode data
    └── validation/           # Validation helpers
```

## Contributing

Contributions are welcome! Please:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Add tests** for new functionality
4. **Run benchmarks** to verify performance
5. **Commit changes** (`git commit -m 'Add amazing feature'`)
6. **Push to branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

### Development Guidelines

- Maintain 100% strconv compatibility
- Add benchmarks for new optimizations
- Include fuzz tests for parsing functions
- Document assembly implementations
- Follow Go idioms and best practices

## License

BSD 3-Clause License - see [LICENSE](LICENSE) for details.

Copyright (c) 2025, Mohammad Shafiee

## Acknowledgments

- **Ryū algorithm**: Ulf Adams ([ryū paper](https://dl.acm.org/doi/10.1145/3192366.3192369))
- **Eisel-Lemire algorithm**: Daniel Lemire et al.
- **Go strconv**: The Go Authors (reference implementation)

## Related Projects

- [Go strconv](https://pkg.go.dev/strconv) - Standard library implementation

---

**FastParse**: Up to 2.4X faster number parsing for Go 🚀

## Optimization Techniques

This implementation achieves exceptional performance through:

1. **SIMD Parallelism**: Process 16-64 bytes simultaneously using AVX-512/AVX2/NEON
2. **BMI2 Instructions**: Division-free overflow checking with MULX (2X faster than IDIV)
3. **Unsafe Operations**: Zero-copy conversions and bounds check elimination
4. **Lookup Tables**: 256KB precomputed tables for instant digit-to-string conversion
5. **CPU Feature Detection**: Runtime dispatch to optimal code paths
6. **Assembly Fast Paths**: Hand-optimized critical loops in assembly

These optimizations deliver up to **2.4X speedup** while maintaining 100% compatibility with Go's `strconv` package.

