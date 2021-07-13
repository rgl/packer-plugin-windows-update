GOPATH := $(shell go env GOPATH | tr '\\' '/')
GOEXE := $(shell go env GOEXE)
GOHOSTOS := $(shell go env GOHOSTOS)
GOHOSTARCH := $(shell go env GOHOSTARCH)
GORELEASER := $(GOPATH)/bin/goreleaser
SOURCE_FILES := *.go update/* update/provisioner.hcl2spec.go

all: build

init:
	go mod download

$(GORELEASER):
	wget -qO- https://install.goreleaser.com/github.com/goreleaser/goreleaser.sh | BINDIR=$(GOPATH)/bin sh

build: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) build --skip-validate --rm-dist --single-target

release-snapshot: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) release --snapshot --skip-publish --rm-dist

release: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) release --rm-dist

# see https://www.packer.io/guides/hcl/component-object-spec/
update/provisioner.hcl2spec.go: update/provisioner.go
	go install github.com/hashicorp/packer/cmd/mapstructure-to-hcl2
	go generate ./...

install: dist/packer-plugin-windows-update_$(GOHOSTOS)_$(GOHOSTARCH)/packer-plugin-windows-update_*_$(GOHOSTOS)_$(GOHOSTARCH)$(GOEXE)
	mkdir -p $(HOME)/.packer.d/plugins
	cp -f $< $(HOME)/.packer.d/plugins/packer-provisioner-windows-update$(GOEXE)

clean:
	rm -rf dist tmp*

.PHONY: all init build release release-snapshot install clean
