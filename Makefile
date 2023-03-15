GOPATH := $(shell go env GOPATH | tr '\\' '/')
GOEXE := $(shell go env GOEXE)
GOHOSTOS := $(shell go env GOHOSTOS)
GOHOSTARCH := $(shell go env GOHOSTARCH)
GOHOSTARCHVERSION := $(shell go env "GO$(shell go env GOHOSTARCH | tr '[:lower:]' '[:upper:]')")
GORELEASER := $(GOPATH)/bin/goreleaser
SOURCE_FILES := *.go update/* update/provisioner.hcl2spec.go
PLUGIN_PATH := dist/packer-plugin-windows-update_$(GOHOSTOS)_$(GOHOSTARCH)_$(GOHOSTARCHVERSION)/packer-plugin-windows-update_*_$(GOHOSTOS)_$(GOHOSTARCH)$(GOEXE)

all: build

init:
	go mod download

$(GORELEASER):
	go install github.com/goreleaser/goreleaser@v1.16.1

build: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) build --skip-validate --clean --single-target

release-snapshot: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) release --snapshot --skip-publish --clean

release: init $(GORELEASER) $(SOURCE_FILES)
	API_VERSION="$(shell go run . describe 2>/dev/null | jq -r .api_version)" \
		$(GORELEASER) release --clean

# see https://www.packer.io/guides/hcl/component-object-spec/
update/provisioner.hcl2spec.go: update/provisioner.go
	go install github.com/hashicorp/packer-plugin-sdk/cmd/packer-sdc@$(shell go list -m -f '{{.Version}}' github.com/hashicorp/packer-plugin-sdk)
	go generate ./...

install: uninstall $(PLUGIN_PATH) build
	mkdir -p $(HOME)/.packer.d/plugins
	cp -f $(PLUGIN_PATH) $(HOME)/.packer.d/plugins/packer-plugin-windows-update$(GOEXE)

uninstall:
	rm -f $(HOME)/.packer.d/plugins/packer-provisioner-windows-update$(GOEXE) # rm the old name too.
	rm -f $(HOME)/.packer.d/plugins/packer-plugin-windows-update$(GOEXE)

clean:
	rm -rf dist tmp* output-test *.log

test:
	rm -rf output-test test.log
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=test.log \
	PKR_VAR_disk_image=~/.vagrant.d/boxes/windows-2022-amd64/0.0.0/libvirt/box.img \
		packer build -only=qemu.test -on-error=abort test.pkr.hcl

.PHONY: all init build release release-snapshot install uninstall clean test
