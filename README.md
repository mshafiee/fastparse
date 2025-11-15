# fastparse

[![Go Reference](https://pkg.go.dev/badge/github.com/mshafiee/fastparse.svg)](https://pkg.go.dev/github.com/mshafiee/fastparse)
[![Go Version](https://img.shields.io/badge/go-1.24+-blue.svg)](https://go.dev/dl/)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**Ultra-fast number parsing and formatting for Go** — A drop-in replacement for `strconv` with architecture-specific optimizations.

FastParse implements all 34 functions from Go's `strconv` package with native, optimized implementations featuring:
- **100% native code** — No strconv dependencies in production
- **SIMD optimizations** — AVX-512, AVX2 (amd64) and NEON (arm64) 
- **Assembly fast paths** — Hand-optimized critical paths
- **Ryū algorithm** — State-of-the-art float formatting
- **Runtime CPU detection** — Automatic dispatch to best implementation

## Performance

FastParse delivers **competitive to improved performance** compared to the standard library, with significant gains for specific operations:

### Parsing Benchmarks (Apple M1 Pro, ARM64 NEON)

| Operation | Input Type | FastParse | Strconv | Speedup |
|-----------|-----------|-----------|---------|---------|
| `ParseFloat` | Short (4 digits) | 13.7 ns/op | 18.4 ns/op | **26% faster** |
| `ParseFloat` | Medium (8 digits) | 13.0 ns/op | 23.8 ns/op | **45% faster** |
| `ParseFloat` | Long (16 digits) | 19.3 ns/op | 40.3 ns/op | **52% faster** |
| `ParseFloat` | Scientific | 15.6 ns/op | 21.2 ns/op | **26% faster** |
| `ParseFloat` | Scientific (long) | 32.5 ns/op | 53.8 ns/op | **40% faster** |
| `ParseInt` | Medium (8 digits) | 13.9 ns/op | 14.3 ns/op | **3% faster** |
| `ParseInt` | Long (16 digits) | 32.1 ns/op | 25.4 ns/op | **21% slower** |
| `ParseInt` | Max (19 digits) | 26.4 ns/op | 26.9 ns/op | **2% faster** |
| `ParseUint` | Medium (8 digits) | 11.5 ns/op | 13.0 ns/op | **12% faster** |
| `ParseUint` | Long (16 digits) | 20.4 ns/op | 21.0 ns/op | **3% faster** |

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

*Benchmarks run on Apple M1 Pro with ARM64 NEON instructions. Greater speedups expected on AMD64 systems with AVX2/AVX-512 support.*

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
├── Core Parsing
│   ├── ParseFloat: 3-tier optimization (fast path → Eisel-Lemire → fallback)
│   ├── ParseInt: FSA-based with overflow detection
│   └── ParseUint: Multi-base with underscore support
│
├── Core Formatting
│   ├── FormatFloat: Ryū algorithm using big.Float
│   ├── FormatInt/Uint: Division-free for power-of-2 bases
│   └── Quote/Unquote: Two-pass with SIMD detection
│
└── SIMD Optimizations
    ├── AVX-512: 64-byte operations (amd64)
    ├── AVX2: 32-byte operations (amd64)
    └── NEON: 16-byte operations (arm64)
```

### Assembly Optimizations

**AMD64 (x86-64)**
- AVX-512 vectorized operations for 64-byte chunks
- AVX2 vectorized operations for 32-byte chunks  
- SSE2 fallback for 16-byte operations
- Hand-optimized scalar fallback
- Runtime CPU feature detection

**ARM64**
- NEON SIMD instructions for 16-byte operations
- Optimized register allocation
- Branch-free digit validation

**Generic Fallback**
- Pure Go implementation for all platforms
- No performance degradation on unsupported architectures

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

- **Base 2, 8, 16**: Division-free using bit shifts
- **Base 10**: Optimized division with strength reduction
- **Generic bases 3-36**: Efficient modulo operations
- **Zero allocations**: Stack buffers for all operations

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
- [json-iterator](https://github.com/json-iterator/go) - Fast JSON parsing
- [sonic](https://github.com/bytedance/sonic) - JIT-based JSON library

---

**FastParse**: Blazing fast number parsing for Go 🚀

