# Makefile Quick Reference Card

## 🚀 Getting Started

```bash
make quick-start          # Show setup guide
make install-tools        # Install all development tools
make tool-status          # Check which tools are installed
make help                 # Show all available commands
```

## 💻 Daily Development

```bash
make fmt                  # Format code (gofmt + goimports)
make test                 # Run all tests
make test-short           # Quick test run
make lint                 # Basic linting (vet + staticcheck + errcheck)
make pre-commit           # Fast checks before commit
```

## 🔍 Testing

```bash
make test                 # Standard tests
make test-short           # Short tests only
make test-race            # Tests with race detector
make test-coverage        # Generate HTML coverage report
make test-all             # All tests (race + coverage)
make coverage-func        # Show coverage per function
```

## 📊 Benchmarking

```bash
make bench                # Run benchmarks
make bench-cpu            # Benchmark with CPU profiling
make bench-mem            # Benchmark with memory profiling
make bench-trace          # Benchmark with execution trace
```

## 🧹 Formatting

```bash
make fmt                  # Format all Go files
make fmt-check            # Check if files are formatted
make gofumpt              # Stricter formatting check
make gofumpt-fix          # Auto-fix with gofumpt
```

## 🔬 Linting (Basic)

```bash
make vet                  # Go vet
make staticcheck          # Staticcheck
make gosec                # Security scanner
make golangci-lint        # golangci-lint (comprehensive)
make errcheck             # Unchecked errors
make lint                 # Run basic linters
make lint-all             # Run all basic linters
```

## 🎯 Linting (Advanced)

```bash
make gocyclo              # Cyclomatic complexity
make gocognit             # Cognitive complexity
make goconst              # Repeated strings → constants
make gocritic             # Opinionated linter
make shadow               # Shadowed variables
make dupl                 # Code duplication
make nilaway              # Nil pointer analysis
make misspell             # Spelling mistakes
make lint-advanced        # All advanced linters
```

## 🏷️ Linting (Categorized)

```bash
make lint-style           # Style-focused linters
make lint-security        # Security-focused linters
make lint-performance     # Performance-focused linters
make super-lint           # ALL linters (comprehensive)
```

## 🔐 Security

```bash
make vuln-check           # Check for vulnerabilities
make gosec                # Security scanner
make audit                # Complete security audit
make check-security       # All security checks
```

## 📦 Dependencies

```bash
make mod-tidy             # Tidy go.mod/go.sum
make mod-verify           # Verify dependencies
make mod-download         # Download dependencies
make mod-graph            # Show dependency graph
make mod-outdated         # Check for updates
make upgrade-deps         # Upgrade all dependencies
```

## 🏗️ Building

```bash
make build                # Build binary
make build-all            # Build for all platforms
make clean                # Clean artifacts
make clean-cache          # Clean Go caches
make clean-all            # Clean everything
```

## 📚 Documentation

```bash
make doc                  # Serve docs locally (port 6060)
make doc-generate         # Generate markdown docs
make stats                # Show code statistics
make info                 # Show project info
```

## ✅ Quality Checks

```bash
make complexity-check     # All complexity checkers
make spell-check          # Spell checker
make duplicate-check      # Duplication detection
make line-length-check    # Line length validation
make comment-check        # Package documentation check
make asm-check            # Assembly file validation
make check-style          # All style checks
make check-performance    # All performance checks
```

## 🔄 Complete Workflows

```bash
# Before Committing (Fast - ~30s)
make pre-commit

# Before Pushing (Medium - 1-2min)
make pre-push

# Before Pull Request (Complete - 2-5min)
make full-check

# CI Pipeline (Comprehensive - 10-15min)
make ci-extended

# Release Preparation
make release-ready
```

## 🎪 Special Commands

```bash
make workflows            # Show common workflows
make quick-start          # Quick start guide
make tool-status          # Show installed tools
make list-targets         # List all makefile targets
```

## 📱 One-Liners for Common Scenarios

### First Time Setup
```bash
make install-tools && make test
```

### Before Every Commit
```bash
make fmt && make pre-commit
```

### Complete Check Before PR
```bash
make full-check && make check-security
```

### Performance Analysis
```bash
make bench-cpu && make check-performance
```

### Update Everything
```bash
make mod-outdated && make upgrade-deps && make test-all
```

### Security Audit
```bash
make audit && make check-security
```

### Clean and Rebuild
```bash
make clean-all && make build
```

## 🎨 Workflow Recommendations

### Individual Developer (Daily)
```bash
make fmt test-short pre-commit
```

### Team Lead (Weekly)
```bash
make super-lint && make check-security && make mod-outdated
```

### CI/CD Pipeline
```bash
make ci-extended
```

### Release Manager
```bash
make release-ready && make build-all
```

## 🔧 Troubleshooting

### Tool not found?
```bash
make install-tools        # Install all Go tools
make tool-status          # Check what's installed
```

### golangci-lint not found?
```bash
# macOS
brew install golangci-lint

# Linux/Windows
# See https://golangci-lint.run/usage/install/
```

### Slow linting?
```bash
# Use faster checks during development
make lint

# Save comprehensive checks for CI
make super-lint
```

### Need help?
```bash
make help                 # Show all commands
make workflows            # Show workflow examples
make quick-start          # Setup guide
```

## 📊 Performance Guide

| Command | Time | When to Use |
|---------|------|-------------|
| `make pre-commit` | ~30s | Before every commit |
| `make lint` | ~1min | Quick quality check |
| `make full-check` | 2-5min | Before PR |
| `make super-lint` | 5-10min | Comprehensive analysis |
| `make ci-extended` | 10-15min | CI pipeline |

## 🎯 Target Hierarchy

```
Basic:      make lint
  ↓
Standard:   make lint-all
  ↓
Advanced:   make lint-advanced
  ↓
Complete:   make super-lint
  ↓
Ultimate:   make ci-extended
```

## 💡 Pro Tips

1. **Use pre-commit hooks**: Run `make pre-commit` automatically
2. **Parallel testing**: Tests run in parallel by default
3. **Incremental linting**: Use golangci-lint for faster feedback
4. **Profile regularly**: Use `bench-cpu` and `bench-mem` often
5. **Update tools**: Re-run `make install-tools` monthly
6. **Check security**: Run `make audit` weekly
7. **Watch dependencies**: Run `make mod-outdated` regularly

## 🆘 Quick Help

Need immediate help?
```bash
make help                 # Full command list
make quick-start          # Setup guide  
make workflows            # Common workflows
make tool-status          # Tool installation status
```

---

**Print this card** and keep it handy during development!

**Latest Version**: See [MAKEFILE_REFERENCE.md](MAKEFILE_REFERENCE.md) for complete documentation.

