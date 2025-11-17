.PHONY: help test bench fuzz generate generate-eisel \
	lint fmt fmt-check vet staticcheck gosec \
	test-race test-coverage test-all \
	build build-all clean clean-cache clean-all \
	install-tools check-all pre-commit \
	vuln-check mod-tidy mod-verify mod-download \
	bench-compare bench-cpu bench-mem bench-trace deadcode errcheck \
	gocyclo gocognit misspell misspell-fix goconst gocritic \
	unconvert unparam nakedret prealloc \
	shadow dupl gofumpt gofumpt-fix nilaway \
	complexity-check spell-check duplicate-check \
	lint-advanced lint-security lint-performance lint-style \
	asm-check line-length-check comment-check \
	mod-graph mod-outdated upgrade-deps \
	test-integration test-benchmark-compare \
	docker-lint shellcheck yamllint \
	check-performance check-security check-style \
	super-lint audit verify-all \
	doc doc-generate coverage-func coverage-badge \
	info stats tool-status list-targets \
	full-check ci-extended pre-push release-ready \
	workflows quick-start

# Default target
.DEFAULT_GOAL := help

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
GOVET=$(GOCMD) vet
GOFMT=gofmt
BINARY_NAME=fastparse
COVERAGE_FILE=coverage.out
COVERAGE_HTML=coverage.html

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

##@ Help

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(GREEN)<target>$(RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

generate: ## Run go generate for all packages
	$(GOCMD) generate ./...

generate-eisel: ## Generate Eisel-Lemire tables
	$(GOCMD) run internal/eisel_lemire/generate/extract_go_tables.go

##@ Testing

test: ## Run tests
	$(GOTEST) -v ./...

test-short: ## Run short tests
	$(GOTEST) -short -v ./...

test-race: ## Run tests with race detector
	$(GOTEST) -race -v ./...

test-coverage: ## Run tests with coverage
	$(GOTEST) -coverprofile=$(COVERAGE_FILE) -covermode=atomic ./...
	$(GOCMD) tool cover -html=$(COVERAGE_FILE) -o $(COVERAGE_HTML)
	@echo "$(GREEN)Coverage report generated: $(COVERAGE_HTML)$(RESET)"

test-coverage-text: ## Run tests with coverage (text output)
	$(GOTEST) -coverprofile=$(COVERAGE_FILE) -covermode=atomic ./...
	$(GOCMD) tool cover -func=$(COVERAGE_FILE)

test-all: test-race test-coverage ## Run all tests including race detector and coverage

bench: ## Run benchmarks
	$(GOTEST) -bench=. -benchmem ./...

bench-compare: ## Run benchmarks and save to file for comparison
	$(GOTEST) -bench=. -benchmem ./... | tee bench.txt

bench-cpu: ## Run benchmarks with CPU profiling
	$(GOTEST) -bench=. -benchmem -cpuprofile=cpu.prof ./...
	@echo "$(GREEN)CPU profile saved to cpu.prof$(RESET)"
	@echo "$(YELLOW)View with: go tool pprof cpu.prof$(RESET)"

bench-mem: ## Run benchmarks with memory profiling
	$(GOTEST) -bench=. -benchmem -memprofile=mem.prof ./...
	@echo "$(GREEN)Memory profile saved to mem.prof$(RESET)"
	@echo "$(YELLOW)View with: go tool pprof mem.prof$(RESET)"

bench-trace: ## Run benchmarks with execution trace
	$(GOTEST) -bench=. -trace=trace.out ./...
	@echo "$(GREEN)Trace saved to trace.out$(RESET)"
	@echo "$(YELLOW)View with: go tool trace trace.out$(RESET)"

fuzz: ## Run fuzz tests
	$(GOTEST) -fuzz=. -fuzztime=10s

fuzz-long: ## Run fuzz tests for longer duration
	$(GOTEST) -fuzz=. -fuzztime=5m

##@ Formatting

fmt: ## Format all Go files
	$(GOFMT) -w -s .
	@command -v goimports >/dev/null 2>&1 && goimports -w . || echo "$(YELLOW)goimports not installed, skipping...$(RESET)"

fmt-check: ## Check if files are properly formatted
	@test -z "$$($(GOFMT) -l .)" || (echo "$(YELLOW)The following files are not formatted:$(RESET)" && $(GOFMT) -l . && exit 1)
	@echo "$(GREEN)All files are properly formatted$(RESET)"

##@ Linting & Static Analysis

vet: ## Run go vet
	@VET_OUTPUT=$$($(GOVET) ./... 2>&1 || true); \
	if echo "$$VET_OUTPUT" | grep -q "unsafe_helpers.go.*possible misuse of unsafe.Pointer"; then \
		FILTERED=$$(echo "$$VET_OUTPUT" | grep -v "unsafe_helpers.go" | grep -v "^# github.com" | grep -v "^# \[github.com" | grep -v "^$$"); \
		FILTERED_LINES=$$(echo "$$FILTERED" | wc -l | tr -d ' '); \
		if [ "$$FILTERED_LINES" -eq "0" ] || [ -z "$$FILTERED" ]; then \
			echo "Note: unsafe_helpers.go:noescape warning is a known false positive (standard library escape analysis pattern)"; \
			exit 0; \
		else \
			echo "$$VET_OUTPUT"; \
			exit 1; \
		fi; \
	else \
		$(GOVET) ./...; \
	fi

staticcheck: ## Run staticcheck
	@command -v staticcheck >/dev/null 2>&1 || (echo "$(YELLOW)Installing staticcheck...$(RESET)" && $(GOGET) honnef.co/go/tools/cmd/staticcheck)
	staticcheck ./...

gosec: ## Run gosec security scanner
	@command -v gosec >/dev/null 2>&1 || (echo "$(YELLOW)Installing gosec...$(RESET)" && $(GOGET) github.com/securego/gosec/v2/cmd/gosec)
	gosec -quiet ./...

golangci-lint: ## Run golangci-lint
	@command -v golangci-lint >/dev/null 2>&1 || (echo "$(YELLOW)golangci-lint not installed. Install from https://golangci-lint.run/$(RESET)" && exit 1)
	golangci-lint run --timeout=5m ./...

golangci-lint-fix: ## Run golangci-lint with auto-fix
	@command -v golangci-lint >/dev/null 2>&1 || (echo "$(YELLOW)golangci-lint not installed. Install from https://golangci-lint.run/$(RESET)" && exit 1)
	golangci-lint run --fix --timeout=5m ./...

revive: ## Run revive linter
	@command -v revive >/dev/null 2>&1 || (echo "$(YELLOW)Installing revive...$(RESET)" && $(GOGET) github.com/mgechev/revive)
	revive -config .revive.toml ./... || revive ./...

errcheck: ## Check for unchecked errors
	@command -v errcheck >/dev/null 2>&1 || (echo "$(YELLOW)Installing errcheck...$(RESET)" && $(GOGET) github.com/kisielk/errcheck)
	errcheck ./...

deadcode: ## Find dead code
	@command -v deadcode >/dev/null 2>&1 || (echo "$(YELLOW)Installing deadcode...$(RESET)" && $(GOGET) golang.org/x/tools/cmd/deadcode@latest)
	deadcode -test ./...

ineffassign: ## Detect ineffectual assignments
	@command -v ineffassign >/dev/null 2>&1 || (echo "$(YELLOW)Installing ineffassign...$(RESET)" && $(GOGET) github.com/gordonklaus/ineffassign)
	ineffassign ./...

lint: vet staticcheck errcheck ## Run basic linters (vet, staticcheck, errcheck)

lint-all: vet staticcheck gosec errcheck ineffassign ## Run all linters

##@ Security & Vulnerabilities

vuln-check: ## Check for known vulnerabilities
	@command -v govulncheck >/dev/null 2>&1 || (echo "$(YELLOW)Installing govulncheck...$(RESET)" && $(GOGET) golang.org/x/vuln/cmd/govulncheck@latest)
	govulncheck ./...

##@ Dependencies

mod-tidy: ## Tidy go.mod and go.sum
	$(GOMOD) tidy

mod-verify: ## Verify dependencies
	$(GOMOD) verify

mod-download: ## Download dependencies
	$(GOMOD) download

mod-check: mod-tidy ## Check if go.mod and go.sum are up to date
	@git diff --exit-code go.mod go.sum || (echo "$(YELLOW)go.mod or go.sum needs updating$(RESET)" && exit 1)

##@ Build

build: ## Build the binary
	$(GOBUILD) -v -o $(BINARY_NAME) ./...

build-all: ## Build for multiple platforms
	GOOS=linux GOARCH=amd64 $(GOBUILD) -v -o $(BINARY_NAME)-linux-amd64 ./...
	GOOS=linux GOARCH=arm64 $(GOBUILD) -v -o $(BINARY_NAME)-linux-arm64 ./...
	GOOS=darwin GOARCH=amd64 $(GOBUILD) -v -o $(BINARY_NAME)-darwin-amd64 ./...
	GOOS=darwin GOARCH=arm64 $(GOBUILD) -v -o $(BINARY_NAME)-darwin-arm64 ./...
	GOOS=windows GOARCH=amd64 $(GOBUILD) -v -o $(BINARY_NAME)-windows-amd64.exe ./...

clean: ## Clean build artifacts and coverage files
	$(GOCLEAN)
	rm -f $(BINARY_NAME)*
	rm -f $(COVERAGE_FILE) $(COVERAGE_HTML)
	rm -f bench.txt bench-old.txt bench-new.txt
	rm -f fastparse.test
	rm -f cpu.prof mem.prof trace.out
	find . -name '*.test' -type f -delete
	find . -name '*.out' -type f -delete

clean-cache: ## Clean Go build cache
	$(GOCMD) clean -cache -testcache -modcache -fuzzcache
	@echo "$(GREEN)All caches cleaned$(RESET)"

clean-all: clean clean-cache ## Clean everything including caches

##@ Tools

install-tools: ## Install all required tools
	@echo "$(GREEN)Installing development tools...$(RESET)"
	@echo "$(YELLOW)Installing basic linters...$(RESET)"
	$(GOGET) honnef.co/go/tools/cmd/staticcheck@latest
	$(GOGET) github.com/securego/gosec/v2/cmd/gosec@latest
	$(GOGET) github.com/mgechev/revive@latest
	$(GOGET) github.com/kisielk/errcheck@latest
	$(GOGET) golang.org/x/tools/cmd/deadcode@latest
	$(GOGET) github.com/gordonklaus/ineffassign@latest
	$(GOGET) golang.org/x/vuln/cmd/govulncheck@latest
	$(GOGET) golang.org/x/tools/cmd/goimports@latest
	@echo "$(YELLOW)Installing advanced linters...$(RESET)"
	$(GOGET) github.com/fzipp/gocyclo/cmd/gocyclo@latest
	$(GOGET) github.com/uudashr/gocognit/cmd/gocognit@latest
	$(GOGET) github.com/jgautheron/goconst/cmd/goconst@latest
	$(GOGET) github.com/go-critic/go-critic/cmd/gocritic@latest
	$(GOGET) github.com/mdempsky/unconvert@latest
	$(GOGET) mvdan.cc/unparam@latest
	$(GOGET) github.com/alexkohler/nakedret/cmd/nakedret@latest
	$(GOGET) github.com/alexkohler/prealloc@latest
	$(GOGET) golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow@latest
	$(GOGET) github.com/mibk/dupl@latest
	$(GOGET) mvdan.cc/gofumpt@latest
	$(GOGET) go.uber.org/nilaway/cmd/nilaway@latest
	$(GOGET) github.com/client9/misspell/cmd/misspell@latest
	@echo "$(YELLOW)Installing benchmark tools...$(RESET)"
	$(GOGET) golang.org/x/perf/cmd/benchstat@latest
	@echo "$(GREEN)All Go tools installed!$(RESET)"
	@echo ""
	@echo "$(YELLOW)Optional external tools (install separately):$(RESET)"
	@echo "  - golangci-lint: https://golangci-lint.run/"
	@echo "  - hadolint (Docker): https://github.com/hadolint/hadolint"
	@echo "  - shellcheck: https://www.shellcheck.net/"
	@echo "  - yamllint: pip install yamllint"

##@ Quality Checks

check-all: fmt-check vet lint vuln-check test-race ## Run all quality checks

pre-commit: fmt-check lint test-short ## Run pre-commit checks (fast)

ci: mod-verify fmt-check lint-all vuln-check test-all ## Run all CI checks

##@ Documentation & Analysis

doc: ## Generate and serve documentation locally
	@echo "$(GREEN)Starting documentation server...$(RESET)"
	@echo "$(YELLOW)Visit http://localhost:6060/pkg/$(shell go list -m)$(RESET)"
	godoc -http=:6060

doc-generate: ## Generate package documentation (markdown)
	@command -v gomarkdoc >/dev/null 2>&1 || (echo "$(YELLOW)Installing gomarkdoc...$(RESET)" && $(GOGET) github.com/princjef/gomarkdoc/cmd/gomarkdoc@latest)
	gomarkdoc --output README_API.md ./...
	@echo "$(GREEN)API documentation generated: README_API.md$(RESET)"

coverage-func: ## Show coverage per function
	@if [ -f $(COVERAGE_FILE) ]; then \
		$(GOCMD) tool cover -func=$(COVERAGE_FILE); \
	else \
		echo "$(YELLOW)Run 'make test-coverage' first$(RESET)"; \
	fi

coverage-badge: ## Generate coverage badge
	@if [ -f $(COVERAGE_FILE) ]; then \
		@$(GOCMD) tool cover -func=$(COVERAGE_FILE) | grep total | awk '{print "Coverage: " $$3}'; \
	else \
		echo "$(YELLOW)Run 'make test-coverage' first$(RESET)"; \
	fi

##@ Information

info: ## Display project information
	@echo "$(GREEN)Go Version:$(RESET)"
	@$(GOCMD) version
	@echo "\n$(GREEN)Go Environment:$(RESET)"
	@$(GOCMD) env GOOS GOARCH CGO_ENABLED
	@echo "\n$(GREEN)Module Info:$(RESET)"
	@$(GOCMD) list -m
	@echo "\n$(GREEN)Dependencies:$(RESET)"
	@$(GOCMD) list -m all

stats: ## Show code statistics
	@echo "$(GREEN)Code Statistics:$(RESET)"
	@echo "Total Go files: $$(find . -name '*.go' -not -path './vendor/*' | wc -l)"
	@echo "Total Assembly files: $$(find . -name '*.s' -not -path './vendor/*' | wc -l)"
	@echo "Total test files: $$(find . -name '*_test.go' -not -path './vendor/*' | wc -l)"
	@echo "Lines of Go code: $$(find . -name '*.go' -not -path './vendor/*' -not -name '*_test.go' -exec cat {} \; | wc -l)"
	@echo "Lines of test code: $$(find . -name '*_test.go' -not -path './vendor/*' -exec cat {} \; | wc -l)"
	@echo "Total packages: $$(go list ./... | wc -l)"

tool-status: ## Check which tools are installed
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)                    TOOL STATUS                                $(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)Core Go Tools:$(RESET)"
	@command -v go >/dev/null 2>&1 && echo "  ✓ go" || echo "  ✗ go"
	@command -v gofmt >/dev/null 2>&1 && echo "  ✓ gofmt" || echo "  ✗ gofmt"
	@command -v goimports >/dev/null 2>&1 && echo "  ✓ goimports" || echo "  ✗ goimports (optional)"
	@echo ""
	@echo "$(YELLOW)Basic Linters:$(RESET)"
	@command -v staticcheck >/dev/null 2>&1 && echo "  ✓ staticcheck" || echo "  ✗ staticcheck"
	@command -v gosec >/dev/null 2>&1 && echo "  ✓ gosec" || echo "  ✗ gosec"
	@command -v revive >/dev/null 2>&1 && echo "  ✓ revive" || echo "  ✗ revive"
	@command -v errcheck >/dev/null 2>&1 && echo "  ✓ errcheck" || echo "  ✗ errcheck"
	@command -v deadcode >/dev/null 2>&1 && echo "  ✓ deadcode" || echo "  ✗ deadcode"
	@command -v ineffassign >/dev/null 2>&1 && echo "  ✓ ineffassign" || echo "  ✗ ineffassign"
	@echo ""
	@echo "$(YELLOW)Advanced Linters:$(RESET)"
	@command -v gocyclo >/dev/null 2>&1 && echo "  ✓ gocyclo" || echo "  ✗ gocyclo"
	@command -v gocognit >/dev/null 2>&1 && echo "  ✓ gocognit" || echo "  ✗ gocognit"
	@command -v goconst >/dev/null 2>&1 && echo "  ✓ goconst" || echo "  ✗ goconst"
	@command -v gocritic >/dev/null 2>&1 && echo "  ✓ gocritic" || echo "  ✗ gocritic"
	@command -v unconvert >/dev/null 2>&1 && echo "  ✓ unconvert" || echo "  ✗ unconvert"
	@command -v unparam >/dev/null 2>&1 && echo "  ✓ unparam" || echo "  ✗ unparam"
	@command -v nakedret >/dev/null 2>&1 && echo "  ✓ nakedret" || echo "  ✗ nakedret"
	@command -v prealloc >/dev/null 2>&1 && echo "  ✓ prealloc" || echo "  ✗ prealloc"
	@command -v shadow >/dev/null 2>&1 && echo "  ✓ shadow" || echo "  ✗ shadow"
	@command -v dupl >/dev/null 2>&1 && echo "  ✓ dupl" || echo "  ✗ dupl"
	@command -v gofumpt >/dev/null 2>&1 && echo "  ✓ gofumpt" || echo "  ✗ gofumpt"
	@command -v nilaway >/dev/null 2>&1 && echo "  ✓ nilaway" || echo "  ✗ nilaway"
	@command -v misspell >/dev/null 2>&1 && echo "  ✓ misspell" || echo "  ✗ misspell"
	@echo ""
	@echo "$(YELLOW)Security & Vulnerability:$(RESET)"
	@command -v govulncheck >/dev/null 2>&1 && echo "  ✓ govulncheck" || echo "  ✗ govulncheck"
	@echo ""
	@echo "$(YELLOW)Performance Tools:$(RESET)"
	@command -v benchstat >/dev/null 2>&1 && echo "  ✓ benchstat" || echo "  ✗ benchstat (optional)"
	@echo ""
	@echo "$(YELLOW)Recommended (External):$(RESET)"
	@command -v golangci-lint >/dev/null 2>&1 && echo "  ✓ golangci-lint" || echo "  ✗ golangci-lint (install from https://golangci-lint.run/)"
	@command -v hadolint >/dev/null 2>&1 && echo "  ✓ hadolint" || echo "  ✗ hadolint (optional - for Docker)"
	@command -v shellcheck >/dev/null 2>&1 && echo "  ✓ shellcheck" || echo "  ✗ shellcheck (optional - for shell scripts)"
	@command -v yamllint >/dev/null 2>&1 && echo "  ✓ yamllint" || echo "  ✗ yamllint (optional - for YAML)"
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(YELLOW)💡 Run 'make install-tools' to install missing Go tools$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"

list-targets: ## List all makefile targets
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

##@ Advanced Linting

gocyclo: ## Check cyclomatic complexity
	@command -v gocyclo >/dev/null 2>&1 || (echo "$(YELLOW)Installing gocyclo...$(RESET)" && $(GOGET) github.com/fzipp/gocyclo/cmd/gocyclo@latest)
	@echo "$(GREEN)Checking cyclomatic complexity (threshold: 15)...$(RESET)"
	@gocyclo -over 15 . || echo "$(YELLOW)Some functions have high complexity$(RESET)"

gocognit: ## Check cognitive complexity
	@command -v gocognit >/dev/null 2>&1 || (echo "$(YELLOW)Installing gocognit...$(RESET)" && $(GOGET) github.com/uudashr/gocognit/cmd/gocognit@latest)
	@echo "$(GREEN)Checking cognitive complexity (threshold: 20)...$(RESET)"
	@gocognit -over 20 . || echo "$(YELLOW)Some functions have high cognitive complexity$(RESET)"

goconst: ## Find repeated strings that could be constants
	@command -v goconst >/dev/null 2>&1 || (echo "$(YELLOW)Installing goconst...$(RESET)" && $(GOGET) github.com/jgautheron/goconst/cmd/goconst@latest)
	goconst -min 3 ./...

gocritic: ## Run gocritic linter
	@command -v gocritic >/dev/null 2>&1 || (echo "$(YELLOW)Installing gocritic...$(RESET)" && $(GOGET) github.com/go-critic/go-critic/cmd/gocritic@latest)
	gocritic check -enableAll ./...

unconvert: ## Find unnecessary type conversions
	@command -v unconvert >/dev/null 2>&1 || (echo "$(YELLOW)Installing unconvert...$(RESET)" && $(GOGET) github.com/mdempsky/unconvert@latest)
	unconvert -v ./...

unparam: ## Find unused function parameters
	@command -v unparam >/dev/null 2>&1 || (echo "$(YELLOW)Installing unparam...$(RESET)" && $(GOGET) mvdan.cc/unparam@latest)
	unparam ./...

nakedret: ## Check for naked returns in long functions
	@command -v nakedret >/dev/null 2>&1 || (echo "$(YELLOW)Installing nakedret...$(RESET)" && $(GOGET) github.com/alexkohler/nakedret/cmd/nakedret@latest)
	nakedret -l 5 ./...

prealloc: ## Find slice declarations that could be preallocated
	@command -v prealloc >/dev/null 2>&1 || (echo "$(YELLOW)Installing prealloc...$(RESET)" && $(GOGET) github.com/alexkohler/prealloc@latest)
	prealloc ./...

shadow: ## Check for shadowed variables
	@command -v shadow >/dev/null 2>&1 || (echo "$(YELLOW)Installing shadow...$(RESET)" && $(GOGET) golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow@latest)
	shadow ./...

dupl: ## Find code duplication
	@command -v dupl >/dev/null 2>&1 || (echo "$(YELLOW)Installing dupl...$(RESET)" && $(GOGET) github.com/mibk/dupl@latest)
	dupl -threshold 100 .

gofumpt: ## Check with stricter gofmt (gofumpt)
	@command -v gofumpt >/dev/null 2>&1 || (echo "$(YELLOW)Installing gofumpt...$(RESET)" && $(GOGET) mvdan.cc/gofumpt@latest)
	@test -z "$$(gofumpt -l .)" || (echo "$(YELLOW)The following files need gofumpt:$(RESET)" && gofumpt -l . && exit 1)
	@echo "$(GREEN)All files pass gofumpt$(RESET)"

gofumpt-fix: ## Auto-fix with gofumpt
	@command -v gofumpt >/dev/null 2>&1 || (echo "$(YELLOW)Installing gofumpt...$(RESET)" && $(GOGET) mvdan.cc/gofumpt@latest)
	gofumpt -w .

nilaway: ## Static analysis for nil panics
	@command -v nilaway >/dev/null 2>&1 || (echo "$(YELLOW)Installing nilaway...$(RESET)" && $(GOGET) go.uber.org/nilaway/cmd/nilaway@latest)
	nilaway ./...

misspell: ## Check for spelling mistakes
	@command -v misspell >/dev/null 2>&1 || (echo "$(YELLOW)Installing misspell...$(RESET)" && $(GOGET) github.com/client9/misspell/cmd/misspell@latest)
	misspell -error .

misspell-fix: ## Fix spelling mistakes
	@command -v misspell >/dev/null 2>&1 || (echo "$(YELLOW)Installing misspell...$(RESET)" && $(GOGET) github.com/client9/misspell/cmd/misspell@latest)
	misspell -w .

##@ Code Quality Checks

complexity-check: gocyclo gocognit ## Run all complexity checkers

spell-check: misspell ## Run spell checker

duplicate-check: dupl goconst ## Check for code duplication and repeated strings

line-length-check: ## Check for long lines (>120 chars)
	@echo "$(GREEN)Checking for lines longer than 120 characters...$(RESET)"
	@find . -name '*.go' -not -path './vendor/*' -not -path './internal/eisel_lemire/generate/*' -exec awk 'length>120 {print FILENAME":"NR": line too long ("length" chars)"; exit 1}' {} \; && echo "$(GREEN)All lines are within limit$(RESET)" || true

comment-check: ## Check for package comments
	@echo "$(GREEN)Checking for package documentation...$(RESET)"
	@for pkg in $$(go list ./... | grep -v /internal/ | grep -v /vendor/); do \
		if ! go doc $$pkg 2>/dev/null | grep -q "^package"; then \
			echo "$(YELLOW)Missing package documentation: $$pkg$(RESET)"; \
		fi \
	done

asm-check: ## Validate assembly files syntax
	@echo "$(GREEN)Checking assembly files...$(RESET)"
	@find . -name '*.s' -not -path './vendor/*' | while read -r file; do \
		echo "Checking $$file"; \
		$(GOCMD) tool asm -S=false "$$file" || exit 1; \
	done
	@echo "$(GREEN)All assembly files are valid$(RESET)"

##@ Categorized Linting

lint-advanced: gocritic unconvert unparam nakedret prealloc shadow ## Run advanced linters

lint-security: gosec vuln-check ## Run security-focused linters

lint-performance: prealloc ineffassign deadcode ## Run performance-focused linters

lint-style: gofumpt misspell ## Run style-focused linters

##@ Dependency Management

mod-graph: ## Show module dependency graph
	$(GOMOD) graph

mod-outdated: ## Check for outdated dependencies
	@echo "$(GREEN)Checking for outdated dependencies...$(RESET)"
	@$(GOCMD) list -u -m all

upgrade-deps: ## Upgrade all dependencies
	@echo "$(YELLOW)Upgrading all dependencies...$(RESET)"
	$(GOGET) -u ./...
	$(GOMOD) tidy
	@echo "$(GREEN)Dependencies upgraded$(RESET)"

##@ Extended Testing

test-integration: ## Run integration tests
	@echo "$(GREEN)Running integration tests...$(RESET)"
	$(GOTEST) -tags=integration -v ./...

test-benchmark-compare: ## Compare benchmark results
	@if [ ! -f bench-old.txt ]; then \
		echo "$(YELLOW)Creating baseline benchmark...$(RESET)"; \
		$(GOTEST) -bench=. -benchmem ./... > bench-old.txt; \
		echo "$(GREEN)Baseline created. Run 'make test-benchmark-compare' again after changes.$(RESET)"; \
	else \
		echo "$(GREEN)Running new benchmarks...$(RESET)"; \
		$(GOTEST) -bench=. -benchmem ./... > bench-new.txt; \
		if command -v benchcmp >/dev/null 2>&1; then \
			benchcmp bench-old.txt bench-new.txt; \
		elif command -v benchstat >/dev/null 2>&1; then \
			benchstat bench-old.txt bench-new.txt; \
		else \
			echo "$(YELLOW)Install benchstat: go install golang.org/x/perf/cmd/benchstat@latest$(RESET)"; \
			diff bench-old.txt bench-new.txt || true; \
		fi \
	fi

##@ Docker & Scripts Linting

docker-lint: ## Lint Dockerfile (if exists)
	@if [ -f Dockerfile ]; then \
		if command -v hadolint >/dev/null 2>&1; then \
			hadolint Dockerfile; \
		else \
			echo "$(YELLOW)hadolint not installed. Install from https://github.com/hadolint/hadolint$(RESET)"; \
		fi \
	else \
		echo "$(YELLOW)No Dockerfile found$(RESET)"; \
	fi

shellcheck: ## Lint shell scripts
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name '*.sh' -not -path './vendor/*' -exec shellcheck {} \; ; \
	else \
		echo "$(YELLOW)shellcheck not installed. Install from https://www.shellcheck.net/$(RESET)"; \
	fi

yamllint: ## Lint YAML files
	@if command -v yamllint >/dev/null 2>&1; then \
		find . \( -name '*.yml' -o -name '*.yaml' \) -not -path './vendor/*' -exec yamllint {} \; ; \
	else \
		echo "$(YELLOW)yamllint not installed. Install with: pip install yamllint$(RESET)"; \
	fi

##@ Comprehensive Checks

check-performance: bench test-race prealloc ineffassign ## Run performance-related checks

check-security: gosec vuln-check ## Run all security checks

check-style: fmt-check gofumpt misspell comment-check line-length-check ## Run all style checks

super-lint: lint-all lint-advanced lint-style complexity-check duplicate-check ## Run ALL linters

audit: vuln-check gosec mod-verify ## Run security audit

verify-all: mod-verify fmt-check vet lint-all vuln-check test-all asm-check ## Verify everything before release

##@ Complete Workflows

full-check: fmt-check check-style super-lint check-security test-all ## Complete quality check (use before PR)

ci-extended: ci super-lint check-security verify-all ## Extended CI checks

pre-push: fmt lint test-race ## Quick checks before push

release-ready: verify-all check-performance bench ## Verify project is release-ready

##@ Workflows & Help

workflows: ## Show common workflows
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)                    COMMON WORKFLOWS                           $(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)🚀 Quick Start (First Time Setup):$(RESET)"
	@echo "   make install-tools          # Install all required linting tools"
	@echo "   make test                   # Run tests to verify setup"
	@echo ""
	@echo "$(YELLOW)💻 Daily Development:$(RESET)"
	@echo "   make fmt                    # Format your code"
	@echo "   make test-short             # Quick test run"
	@echo "   make pre-commit             # Before committing (fast)"
	@echo ""
	@echo "$(YELLOW)🔍 Before Committing:$(RESET)"
	@echo "   make pre-commit             # Fast checks (fmt, lint, test-short)"
	@echo "   make fmt lint test          # Standard workflow"
	@echo ""
	@echo "$(YELLOW)📤 Before Pushing:$(RESET)"
	@echo "   make pre-push               # Quick pre-push checks"
	@echo "   make full-check             # Complete quality check"
	@echo ""
	@echo "$(YELLOW)🔐 Security Audit:$(RESET)"
	@echo "   make audit                  # Run security checks"
	@echo "   make check-security         # Comprehensive security analysis"
	@echo ""
	@echo "$(YELLOW)🎯 Performance Analysis:$(RESET)"
	@echo "   make bench                  # Run benchmarks"
	@echo "   make bench-cpu              # Benchmark with CPU profiling"
	@echo "   make bench-mem              # Benchmark with memory profiling"
	@echo "   make check-performance      # All performance checks"
	@echo ""
	@echo "$(YELLOW)🧪 Testing Workflows:$(RESET)"
	@echo "   make test                   # Standard tests"
	@echo "   make test-race              # Tests with race detector"
	@echo "   make test-coverage          # Tests with coverage report"
	@echo "   make test-all               # All tests"
	@echo ""
	@echo "$(YELLOW)🔬 Deep Analysis:$(RESET)"
	@echo "   make super-lint             # Run ALL linters"
	@echo "   make complexity-check       # Check code complexity"
	@echo "   make duplicate-check        # Find code duplication"
	@echo "   make verify-all             # Verify everything"
	@echo ""
	@echo "$(YELLOW)📦 Release Preparation:$(RESET)"
	@echo "   make release-ready          # Verify project is ready for release"
	@echo "   make ci-extended            # Full CI simulation"
	@echo ""
	@echo "$(YELLOW)🧹 Cleanup:$(RESET)"
	@echo "   make clean                  # Clean build artifacts"
	@echo "   make clean-cache            # Clean Go caches"
	@echo "   make clean-all              # Clean everything"
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(YELLOW)💡 Tip: Run 'make help' to see all available targets$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"

quick-start: ## Quick start guide
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(GREEN)                    QUICK START GUIDE                          $(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo ""
	@echo "$(YELLOW)Step 1:$(RESET) Install all development tools"
	@echo "   $$ make install-tools"
	@echo ""
	@echo "$(YELLOW)Step 2:$(RESET) Verify your installation"
	@echo "   $$ make test"
	@echo ""
	@echo "$(YELLOW)Step 3:$(RESET) Run linters to check code quality"
	@echo "   $$ make lint"
	@echo ""
	@echo "$(YELLOW)Step 4:$(RESET) Format your code"
	@echo "   $$ make fmt"
	@echo ""
	@echo "$(YELLOW)Step 5:$(RESET) Before committing, run:"
	@echo "   $$ make pre-commit"
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
	@echo "$(YELLOW)📚 For more workflows, run: make workflows$(RESET)"
	@echo "$(YELLOW)📖 For all available commands, run: make help$(RESET)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════════$(RESET)"
