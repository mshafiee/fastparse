.PHONY: test bench fuzz generate generate-eisel

test:
	go test ./...

bench:
	go test -bench=. -benchmem ./benchmark

fuzz:
	go test -fuzz=FuzzParseFloat -fuzztime=10s ./benchmark/fuzz

generate:
	go generate ./...

generate-eisel:
	go run internal/eisel_lemire/generate/extract_go_tables.go


