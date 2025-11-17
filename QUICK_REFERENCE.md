# Quick Reference Card

## 🚀 Most Used Commands

```bash
make help              # Show all targets
make fmt               # Format code
make lint              # Run basic linters
make test              # Run tests
make pre-commit        # Quick checks before commit
make ci                # Full CI checks before push
```

## 📋 Cheat Sheet

### Daily Development
```bash
make fmt lint test
```

### Before Commit
```bash
make pre-commit
```

### Before Push
```bash
make ci
```

### Testing Variants
```bash
make test              # All tests
make test-short        # Fast tests only
make test-race         # With race detector
make test-coverage     # With coverage report
make bench             # Benchmarks
make fuzz              # Fuzz testing
```

### Linting Options
```bash
make lint              # Fast: vet + staticcheck + errcheck
make lint-all          # Comprehensive: all linters
make golangci-lint     # golangci-lint only
make vet               # go vet only
make staticcheck       # staticcheck only
```

### Security
```bash
make gosec             # Security linter
make vuln-check        # Vulnerability scanner
```

### Dependencies
```bash
make mod-tidy          # Clean up dependencies
make mod-verify        # Verify checksums
```

### Build
```bash
make build             # Build for current platform
make build-all         # Build for all platforms
make clean             # Remove artifacts
```

### Information
```bash
make info              # Project info
make list-targets      # All available targets
```

## 🎯 Common Workflows

**New Feature:**
```bash
git checkout -b feature/name
# ... make changes ...
make fmt
make test
make pre-commit
git commit -am "Add feature"
make ci
git push
```

**Bug Fix:**
```bash
# ... fix bug ...
make fmt
make test
make lint
git commit -am "Fix bug"
```

**Performance:**
```bash
make bench-compare     # Baseline
# ... optimize ...
make bench-compare     # Compare
make test-race         # Verify correctness
```

## 🛠️ Setup

**Initial Setup:**
```bash
make install-tools
ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

**Install golangci-lint:**
```bash
# macOS
brew install golangci-lint

# Linux
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin
```

## 📚 Documentation

- `make help` - Quick help
- `CONTRIBUTING.md` - How to contribute
- `docs/MAKEFILE_GUIDE.md` - Complete guide
- `MAKEFILE_SUMMARY.md` - Detailed summary

## 💡 Tips

- Run `make pre-commit` before every commit
- Run `make ci` before pushing
- Use `make fmt` frequently
- Check `make info` if environment issues occur
- Use `make test-race` for concurrent code
- Use `make bench-compare` for performance work

## 🔥 Power User Combos

```bash
# Clean slate
make clean && make build && make test

# Full quality check
make fmt-check lint-all vuln-check test-race

# Quick iteration
make fmt && make test-short

# Release prep
make clean mod-tidy ci build-all
```

---
**Tip:** Print this page and keep it near your desk! 📌

