# Makefile Reference Guide

This comprehensive Makefile provides a complete suite of tools for Go development, including linting, testing, security checks, and more.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Common Workflows](#common-workflows)
4. [All Available Commands](#all-available-commands)
5. [Linter Details](#linter-details)
6. [CI/CD Integration](#cicd-integration)
7. [Troubleshooting](#troubleshooting)

## Quick Start

```bash
# Show quick start guide
make quick-start

# Install all development tools
make install-tools

# Run tests
make test

# Format and lint your code
make fmt lint

# Before committing
make pre-commit
```

## Installation

### Install All Tools

```bash
make install-tools
```

This installs:
- **Basic Linters**: staticcheck, gosec, revive, errcheck, deadcode, ineffassign
- **Advanced Linters**: gocyclo, gocognit, goconst, gocritic, unconvert, unparam, nakedret, prealloc, shadow, dupl, gofumpt, nilaway, misspell
- **Security Tools**: govulncheck
- **Utilities**: goimports, benchstat

### Optional External Tools

Some tools need to be installed separately:

```bash
# golangci-lint (recommended)
# macOS
brew install golangci-lint

# Linux
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin

# hadolint (Docker linting)
brew install hadolint  # macOS
# Or download from https://github.com/hadolint/hadolint

# shellcheck (Shell script linting)
brew install shellcheck  # macOS
apt-get install shellcheck  # Debian/Ubuntu

# yamllint (YAML linting)
pip install yamllint
```

## Common Workflows

View all common workflows:
```bash
make workflows
```

### Daily Development

```bash
# Format your code
make fmt

# Run quick tests
make test-short

# Before committing
make pre-commit
```

### Before Committing

```bash
# Fast checks (recommended)
make pre-commit

# Or run individually
make fmt lint test-short
```

### Before Pushing

```bash
# Quick checks
make pre-push

# Complete quality check
make full-check
```

### Security Audit

```bash
# Basic security check
make audit

# Comprehensive security analysis
make check-security
```

### Performance Analysis

```bash
# Run benchmarks
make bench

# Benchmark with CPU profiling
make bench-cpu

# Benchmark with memory profiling
make bench-mem

# Benchmark with execution trace
make bench-trace

# All performance checks
make check-performance
```

### Release Preparation

```bash
# Verify project is release-ready
make release-ready

# Full CI simulation
make ci-extended
```

## All Available Commands

### Help & Information

| Command | Description |
|---------|-------------|
| `make help` | Display help message with all targets |
| `make workflows` | Show common workflows |
| `make quick-start` | Show quick start guide |
| `make info` | Display project information |
| `make stats` | Show code statistics |
| `make tool-status` | Check which tools are installed |
| `make list-targets` | List all makefile targets |

### Testing

| Command | Description |
|---------|-------------|
| `make test` | Run all tests |
| `make test-short` | Run short tests only |
| `make test-race` | Run tests with race detector |
| `make test-coverage` | Generate HTML coverage report |
| `make test-coverage-text` | Generate text coverage report |
| `make test-all` | Run all tests (race + coverage) |
| `make test-integration` | Run integration tests |
| `make coverage-func` | Show coverage per function |
| `make coverage-badge` | Generate coverage badge |

### Benchmarking

| Command | Description |
|---------|-------------|
| `make bench` | Run benchmarks |
| `make bench-compare` | Run benchmarks and save to file |
| `make bench-cpu` | Benchmark with CPU profiling |
| `make bench-mem` | Benchmark with memory profiling |
| `make bench-trace` | Benchmark with execution trace |
| `make test-benchmark-compare` | Compare benchmark results over time |

### Fuzzing

| Command | Description |
|---------|-------------|
| `make fuzz` | Run fuzz tests (10 seconds) |
| `make fuzz-long` | Run fuzz tests (5 minutes) |

### Formatting

| Command | Description |
|---------|-------------|
| `make fmt` | Format all Go files (gofmt + goimports) |
| `make fmt-check` | Check if files are properly formatted |
| `make gofumpt` | Check with stricter gofmt |
| `make gofumpt-fix` | Auto-fix with gofumpt |

### Basic Linting

| Command | Description |
|---------|-------------|
| `make vet` | Run go vet |
| `make staticcheck` | Run staticcheck |
| `make gosec` | Run gosec security scanner |
| `make golangci-lint` | Run golangci-lint |
| `make golangci-lint-fix` | Run golangci-lint with auto-fix |
| `make revive` | Run revive linter |
| `make errcheck` | Check for unchecked errors |
| `make deadcode` | Find dead code |
| `make ineffassign` | Detect ineffectual assignments |
| `make lint` | Run basic linters (vet, staticcheck, errcheck) |
| `make lint-all` | Run all basic linters |

### Advanced Linting

| Command | Description |
|---------|-------------|
| `make gocyclo` | Check cyclomatic complexity |
| `make gocognit` | Check cognitive complexity |
| `make goconst` | Find repeated strings that could be constants |
| `make gocritic` | Run gocritic linter |
| `make unconvert` | Find unnecessary type conversions |
| `make unparam` | Find unused function parameters |
| `make nakedret` | Check for naked returns in long functions |
| `make prealloc` | Find slice declarations that could be preallocated |
| `make shadow` | Check for shadowed variables |
| `make dupl` | Find code duplication |
| `make nilaway` | Static analysis for nil panics |
| `make misspell` | Check for spelling mistakes |
| `make misspell-fix` | Fix spelling mistakes |

### Categorized Linting

| Command | Description |
|---------|-------------|
| `make lint-advanced` | Run advanced linters |
| `make lint-security` | Run security-focused linters |
| `make lint-performance` | Run performance-focused linters |
| `make lint-style` | Run style-focused linters |
| `make super-lint` | Run ALL linters |

### Code Quality Checks

| Command | Description |
|---------|-------------|
| `make complexity-check` | Run all complexity checkers |
| `make spell-check` | Run spell checker |
| `make duplicate-check` | Check for code duplication and repeated strings |
| `make line-length-check` | Check for long lines (>120 chars) |
| `make comment-check` | Check for package comments |
| `make asm-check` | Validate assembly files syntax |
| `make check-style` | Run all style checks |

### Security & Vulnerabilities

| Command | Description |
|---------|-------------|
| `make vuln-check` | Check for known vulnerabilities |
| `make gosec` | Run gosec security scanner |
| `make audit` | Run security audit |
| `make check-security` | Run all security checks |

### Dependencies

| Command | Description |
|---------|-------------|
| `make mod-tidy` | Tidy go.mod and go.sum |
| `make mod-verify` | Verify dependencies |
| `make mod-download` | Download dependencies |
| `make mod-check` | Check if go.mod and go.sum are up to date |
| `make mod-graph` | Show module dependency graph |
| `make mod-outdated` | Check for outdated dependencies |
| `make upgrade-deps` | Upgrade all dependencies |

### Build & Clean

| Command | Description |
|---------|-------------|
| `make build` | Build the binary |
| `make build-all` | Build for multiple platforms |
| `make clean` | Clean build artifacts and coverage files |
| `make clean-cache` | Clean Go build cache |
| `make clean-all` | Clean everything including caches |

### Documentation

| Command | Description |
|---------|-------------|
| `make doc` | Generate and serve documentation locally |
| `make doc-generate` | Generate package documentation (markdown) |

### Docker & Scripts

| Command | Description |
|---------|-------------|
| `make docker-lint` | Lint Dockerfile (if exists) |
| `make shellcheck` | Lint shell scripts |
| `make yamllint` | Lint YAML files |

### Comprehensive Checks

| Command | Description |
|---------|-------------|
| `make check-all` | Run all quality checks |
| `make check-performance` | Run performance-related checks |
| `make check-security` | Run all security checks |
| `make check-style` | Run all style checks |
| `make verify-all` | Verify everything before release |

### Complete Workflows

| Command | Description |
|---------|-------------|
| `make pre-commit` | Fast checks before committing |
| `make pre-push` | Quick checks before pushing |
| `make full-check` | Complete quality check (use before PR) |
| `make ci` | Run all CI checks |
| `make ci-extended` | Extended CI checks |
| `make release-ready` | Verify project is release-ready |

## Linter Details

### Cyclomatic Complexity (gocyclo)
- **Threshold**: 15
- **Purpose**: Identifies overly complex functions
- **Fix**: Break down complex functions into smaller ones

### Cognitive Complexity (gocognit)
- **Threshold**: 20
- **Purpose**: Measures how difficult code is to understand
- **Fix**: Simplify logic and reduce nesting

### Code Duplication (dupl)
- **Threshold**: 100 tokens
- **Purpose**: Finds duplicated code blocks
- **Fix**: Extract common code into functions

### Repeated Strings (goconst)
- **Min Length**: 3 characters
- **Min Occurrences**: 3
- **Purpose**: Finds strings that should be constants
- **Fix**: Extract repeated strings to constants

### Naked Returns (nakedret)
- **Max Function Lines**: 5
- **Purpose**: Finds risky naked returns in long functions
- **Fix**: Use explicit returns in long functions

### Line Length
- **Max Length**: 120 characters
- **Purpose**: Ensures code readability
- **Fix**: Break long lines

## CI/CD Integration

### GitHub Actions

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.24'
      
      - name: Install tools
        run: make install-tools
      
      - name: Run checks
        run: make ci
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.out
```

### GitLab CI

```yaml
stages:
  - test
  - lint
  - security

test:
  stage: test
  script:
    - make install-tools
    - make test-coverage

lint:
  stage: lint
  script:
    - make install-tools
    - make super-lint

security:
  stage: security
  script:
    - make install-tools
    - make audit
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/sh
make pre-commit
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Troubleshooting

### Tool Not Found

If a tool is not installed:
```bash
# Install all tools
make install-tools

# Or install specific tool manually
go install honnef.co/go/tools/cmd/staticcheck@latest
```

### golangci-lint Not Found

```bash
# macOS
brew install golangci-lint

# Linux/Windows - see https://golangci-lint.run/usage/install/
```

### Permission Denied on Shell Scripts

```bash
chmod +x scripts/*.sh
```

### Slow Performance

Some linters can be slow on large codebases. You can:

1. Run specific linters instead of `super-lint`
2. Use `pre-commit` for fast checks
3. Configure `.golangci.yml` to skip directories

### False Positives

Add exclusions to `.golangci.yml`:

```yaml
issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - gocyclo
```

## Best Practices

1. **Daily Development**: Use `make pre-commit` before every commit
2. **Before PR**: Run `make full-check`
3. **CI Pipeline**: Use `make ci` or `make ci-extended`
4. **Release**: Run `make release-ready`
5. **Regular Maintenance**: Run `make mod-outdated` to check for updates

## Performance Tips

- **Parallel Execution**: Most linters run in parallel automatically
- **Incremental Checks**: Use `golangci-lint` with `--new` flag for only new issues
- **Cache**: Go build cache speeds up repeated runs
- **Selective Linting**: Run specific linters during development, all linters in CI

## Contributing

When contributing to projects using this Makefile:

1. Install tools: `make install-tools`
2. Format code: `make fmt`
3. Run tests: `make test`
4. Check quality: `make pre-commit`
5. Before push: `make full-check`

## Additional Resources

- [golangci-lint documentation](https://golangci-lint.run/)
- [staticcheck documentation](https://staticcheck.io/)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Effective Go](https://golang.org/doc/effective_go)

---

**Generated for fastparse project**

