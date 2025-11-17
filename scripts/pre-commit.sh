#!/usr/bin/env bash

# Pre-commit hook for fastparse
# Install this hook by running: ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit

set -e

echo "Running pre-commit checks..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Get list of staged Go files
STAGED_GO_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.go$' || true)

if [ -z "$STAGED_GO_FILES" ]; then
    echo -e "${GREEN}No Go files to check${NC}"
    exit 0
fi

echo -e "${YELLOW}Checking $(echo "$STAGED_GO_FILES" | wc -l | tr -d ' ') Go files...${NC}"

# Check formatting
echo "Checking formatting..."
UNFORMATTED=$(gofmt -l $STAGED_GO_FILES)
if [ -n "$UNFORMATTED" ]; then
    echo -e "${RED}The following files are not formatted:${NC}"
    echo "$UNFORMATTED"
    echo -e "${YELLOW}Run 'make fmt' to format them${NC}"
    exit 1
fi

# Run go vet
echo "Running go vet..."
if ! go vet ./...; then
    echo -e "${RED}go vet failed${NC}"
    exit 1
fi

# Run tests (short mode for speed)
echo "Running tests (short mode)..."
if ! go test -short ./...; then
    echo -e "${RED}Tests failed${NC}"
    exit 1
fi

# Check for common mistakes with errcheck (if installed)
if command -v errcheck > /dev/null 2>&1; then
    echo "Running errcheck..."
    if ! errcheck ./...; then
        echo -e "${YELLOW}Warning: errcheck found unchecked errors${NC}"
        # Don't fail on errcheck warnings, just warn
    fi
fi

# Run staticcheck (if installed)
if command -v staticcheck > /dev/null 2>&1; then
    echo "Running staticcheck..."
    if ! staticcheck ./...; then
        echo -e "${RED}staticcheck failed${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}All pre-commit checks passed!${NC}"
exit 0

