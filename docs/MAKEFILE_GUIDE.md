# Makefile Guide for FastParse

This guide provides detailed information about all available Makefile targets and common workflows.

## Quick Start

View all available targets:
```bash
make help
```

## Common Workflows

### Daily Development

```bash
# 1. Format your code
make fmt

# 2. Run basic lints
make lint

# 3. Run tests
make test

# 4. Quick pre-commit check (before committing)
make pre-commit
```

### Before Pushing

```bash
# Run all checks that will run in CI
make ci
```

### Performance Testing

```bash
# Run benchmarks
make bench

# Compare benchmark results
make bench-compare  # Run multiple times to compare

# Run fuzz tests
make fuzz
make fuzz-long  # Longer duration
```

## Target Categories

### 🧪 Testing Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make test` | Run all tests with verbose output | Regular development |
| `make test-short` | Run only short tests | Quick feedback loop |
| `make test-race` | Run tests with race detector | Before committing concurrent code |
| `make test-coverage` | Generate HTML coverage report | Checking test coverage |
| `make test-coverage-text` | Show coverage in terminal | Quick coverage check |
| `make test-all` | Run tests with race detector and coverage | Comprehensive testing |
| `make bench` | Run all benchmarks | Performance testing |
| `make bench-compare` | Save benchmark results to file | Performance comparisons |
| `make fuzz` | Run fuzz tests (10s) | Finding edge cases |
| `make fuzz-long` | Run fuzz tests (5m) | Thorough fuzzing |

### 🎨 Formatting Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make fmt` | Format all Go files | Before committing |
| `make fmt-check` | Check formatting without changes | In CI or pre-commit |

### 🔍 Linting Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make vet` | Run go vet | Basic static analysis |
| `make staticcheck` | Run staticcheck | Advanced static analysis |
| `make gosec` | Run security scanner | Security checks |
| `make golangci-lint` | Run golangci-lint | Comprehensive linting |
| `make golangci-lint-fix` | Auto-fix linting issues | Quick fixes |
| `make revive` | Run revive linter | Code quality checks |
| `make errcheck` | Check unchecked errors | Error handling verification |
| `make deadcode` | Find unused code | Code cleanup |
| `make ineffassign` | Find ineffectual assignments | Code optimization |
| `make lint` | Run basic linters (vet, staticcheck, errcheck) | Standard linting |
| `make lint-all` | Run all linters | Comprehensive linting |

### 🔒 Security Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make vuln-check` | Check for known vulnerabilities | Before releases |
| `make gosec` | Security-focused linting | Security audits |

### 📦 Dependency Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make mod-tidy` | Tidy go.mod and go.sum | After adding/removing dependencies |
| `make mod-verify` | Verify dependencies | In CI |
| `make mod-download` | Download dependencies | Fresh setup |
| `make mod-check` | Check if go.mod is up to date | In CI |

### 🔨 Build Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make build` | Build the binary | Testing builds |
| `make build-all` | Build for all platforms | Cross-platform builds |
| `make clean` | Clean build artifacts | Fresh start |

### 🛠️ Tool Management

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make install-tools` | Install all dev tools | Initial setup |

### ✅ Quality Check Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make check-all` | Run all quality checks | Before pushing |
| `make pre-commit` | Fast pre-commit checks | Before committing |
| `make ci` | All CI checks | In CI pipeline |

### ℹ️ Information Targets

| Target | Description | When to Use |
|--------|-------------|-------------|
| `make info` | Display project info | Environment debugging |
| `make list-targets` | List all makefile targets | Discovering targets |
| `make help` | Display help message | Finding available commands |

## Detailed Examples

### Setting Up a New Development Environment

```bash
# 1. Clone the repository
git clone https://github.com/mshafiee/fastparse.git
cd fastparse

# 2. Install development tools
make install-tools

# 3. Install golangci-lint separately (see: https://golangci-lint.run/usage/install/)
# On macOS:
brew install golangci-lint

# On Linux:
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin

# 4. Set up pre-commit hooks
ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit

# 5. Verify everything works
make check-all
```

### Making Changes

```bash
# 1. Create a new branch
git checkout -b feature/my-feature

# 2. Make your changes
# ... edit files ...

# 3. Format code
make fmt

# 4. Run tests
make test

# 5. Run linters
make lint

# 6. If everything passes, commit
git add .
git commit -m "Add my feature"

# 7. Before pushing, run full checks
make ci

# 8. Push changes
git push origin feature/my-feature
```

### Performance Optimization Workflow

```bash
# 1. Establish baseline
make bench-compare
mv bench.txt bench-before.txt

# 2. Make your optimizations
# ... edit code ...

# 3. Run benchmarks again
make bench-compare
mv bench.txt bench-after.txt

# 4. Compare results using benchstat
go install golang.org/x/perf/cmd/benchstat@latest
benchstat bench-before.txt bench-after.txt

# 5. Verify correctness with tests
make test-race
```

### Debugging Test Coverage

```bash
# 1. Generate coverage report
make test-coverage

# 2. Open coverage.html in your browser
open coverage.html  # macOS
# or
xdg-open coverage.html  # Linux

# 3. For text output
make test-coverage-text
```

### Finding and Fixing Issues

```bash
# Run individual checks to narrow down issues:

# Check formatting
make fmt-check

# Check for vet issues
make vet

# Check for unchecked errors
make errcheck

# Check for dead code
make deadcode

# Check for security issues
make gosec

# Check for vulnerabilities
make vuln-check
```

## CI/CD Integration

### GitHub Actions Example

The Makefile targets are designed to integrate easily with CI/CD:

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
      
      - name: Install golangci-lint
        run: |
          curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | \
            sh -s -- -b $(go env GOPATH)/bin
      
      - name: Run CI checks
        run: make ci
```

## Troubleshooting

### Tool Not Found

If you see "command not found" errors:

```bash
# Install all tools
make install-tools

# Add Go bin to PATH
export PATH=$PATH:$(go env GOPATH)/bin
```

### golangci-lint Not Working

```bash
# Install golangci-lint separately
# See: https://golangci-lint.run/usage/install/

# On macOS:
brew install golangci-lint

# On Linux:
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | \
  sh -s -- -b $(go env GOPATH)/bin
```

### Tests Failing in CI But Passing Locally

```bash
# Run the exact same checks as CI
make ci

# Check for race conditions
make test-race

# Verify dependencies
make mod-verify
```

### Slow Linting

```bash
# Run only fast linters
make lint

# Or run linters individually
make vet
make staticcheck
make errcheck
```

## Configuration Files

The Makefile uses these configuration files:

- `.golangci.yml` - Configuration for golangci-lint
- `.revive.toml` - Configuration for revive linter
- `.editorconfig` - Editor configuration for consistent formatting

## Tips and Best Practices

1. **Run `make pre-commit` before every commit** - It's fast and catches most issues
2. **Run `make ci` before pushing** - Ensures CI will pass
3. **Use `make fmt` regularly** - Keep code consistently formatted
4. **Run `make test-race` on concurrent code** - Catch race conditions early
5. **Use `make bench-compare` for performance work** - Track performance changes
6. **Run `make vuln-check` periodically** - Stay secure
7. **Keep tools updated** - Rerun `make install-tools` occasionally

## Custom Target Patterns

You can combine targets:

```bash
# Format, lint, and test
make fmt lint test

# Clean and rebuild
make clean build

# Tidy dependencies and run checks
make mod-tidy check-all
```

## Environment Variables

You can override Go command variables:

```bash
# Use different Go command
GOCMD=go1.23 make test

# Build with tags
GOFLAGS="-tags=integration" make test

# Set timeout for tests
GOTEST="go test -timeout=30s" make test
```

## Getting Help

- Run `make help` for a quick reference
- Check this guide for detailed information
- See `CONTRIBUTING.md` for contribution guidelines
- Open an issue if you find problems with the Makefile

