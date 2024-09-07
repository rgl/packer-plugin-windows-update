GOPATH := $(shell go env GOPATH | tr '\\' '/')
GOEXE := $(shell go env GOEXE)
GOHOSTOS := $(shell go env GOHOSTOS)
GOHOSTARCH := $(shell go env GOHOSTARCH)
GOHOSTARCHVERSION := $(shell go env "GO$(shell go env GOHOSTARCH | tr '[:lower:]' '[:upper:]')")
GORELEASER := $(GOPATH)/bin/goreleaser
SOURCE_FILES := *.go update/* update/provisioner.hcl2spec.go
PLUGIN_PATH := dist/packer-plugin-windows-update_$(GOHOSTOS)_$(GOHOSTARCH)_$(GOHOSTARCHVERSION)/packer-plugin-windows-update_*_$(GOHOSTOS)_$(GOHOSTARCH)$(GOEXE)

# see https://github.com/goreleaser/goreleaser
# renovate: datasource=github-releases depName=goreleaser/goreleaser extractVersion=^v?(?<version>1\..+)
GORELEASER_VERSION := 2.2.0

all: build

init:
	go mod download

$(GORELEASER):
	go install github.com/goreleaser/goreleaser/v2@v$(GORELEASER_VERSION)

build: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) build --skip=validate --clean --single-target

release-snapshot: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) release --snapshot --skip=publish --clean

release: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) release --clean

# see https://www.packer.io/guides/hcl/component-object-spec/
update/provisioner.hcl2spec.go: update/provisioner.go
	go install github.com/hashicorp/packer-plugin-sdk/cmd/packer-sdc@$(shell go list -m -f '{{.Version}}' github.com/hashicorp/packer-plugin-sdk)
	go generate ./...

clean:
	rm -rf dist tmp* output-test *.log

test: build
	./test.sh

.PHONY: all init build release release-snapshot install uninstall clean test
