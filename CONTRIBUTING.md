# Contributing to FastParse

Thank you for your interest in contributing to FastParse! This guide will help you get started.

## Development Setup

### Prerequisites

- Go 1.24.0 or later
- Make
- Git

### Installing Development Tools

Install all required development tools:

```bash
make install-tools
```

For golangci-lint, follow the installation instructions at: https://golangci-lint.run/usage/install/

### Setting Up Pre-commit Hooks

To automatically run checks before each commit:

```bash
ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

## Development Workflow

### Making Changes

1. Fork the repository and create a new branch
2. Make your changes
3. Format your code: `make fmt`
4. Run linters: `make lint`
5. Run tests: `make test`
6. Run all checks: `make check-all`

### Testing

```bash
# Run all tests
make test

# Run tests with race detector
make test-race

# Run tests with coverage
make test-coverage

# Run benchmarks
make bench

# Run fuzz tests
make fuzz
```

### Code Quality

```bash
# Format code
make fmt

# Check formatting without modifying files
make fmt-check

# Run go vet
make vet

# Run staticcheck
make staticcheck

# Run all linters
make lint-all

# Check for security issues
make gosec

# Check for vulnerabilities
make vuln-check
```

### Pre-commit Checks

Before committing, run:

```bash
make pre-commit
```

This runs fast checks including:
- Format verification
- Linting
- Short tests

### Full CI Checks

To run all checks that CI will run:

```bash
make ci
```

This includes:
- Module verification
- Format checking
- All linters
- Vulnerability scanning
- Race detection
- Full test suite with coverage

## Makefile Targets

For a complete list of available targets:

```bash
make help
```

### Common Targets

- `make test` - Run tests
- `make bench` - Run benchmarks
- `make lint` - Run basic linters
- `make lint-all` - Run all linters
- `make fmt` - Format code
- `make check-all` - Run all quality checks
- `make pre-commit` - Quick pre-commit checks
- `make ci` - Full CI checks
- `make clean` - Clean build artifacts
- `make help` - Show all available targets

## Code Style

- Follow standard Go conventions
- Use `gofmt` for formatting (run `make fmt`)
- Write clear, descriptive commit messages
- Add tests for new functionality
- Keep functions focused and under 50 lines when possible
- Document exported functions and types

## Performance Considerations

FastParse is a high-performance library. When contributing:

- Run benchmarks to verify performance isn't regressed
- Use benchstat to compare before/after performance
- Consider SIMD optimizations for critical paths
- Profile your changes if they affect hot paths

## Reporting Issues

When reporting issues, please include:

- Go version (`go version`)
- Operating system and architecture
- Minimal reproduction code
- Expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

