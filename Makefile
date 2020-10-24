GOPATH := $(shell go env GOPATH | tr '\\' '/')
GOEXE := $(shell go env GOEXE)
GOHOSTOS := $(shell go env GOHOSTOS)
GOHOSTARCH := $(shell go env GOHOSTARCH)
GORELEASER := $(GOPATH)/bin/goreleaser
SOURCE_FILES := *.go update/* update/assets_vfsdata.go update/provisioner.hcl2spec.go

all: build

$(GORELEASER):
	curl -sfL https://install.goreleaser.com/github.com/goreleaser/goreleaser.sh | BINDIR=$(GOPATH)/bin sh

build: $(GORELEASER) $(SOURCE_FILES)
	$(GORELEASER) build --skip-validate --rm-dist

release-snapshot: $(GORELEASER) $(SOURCE_FILES)
	$(GORELEASER) release --snapshot --skip-publish --rm-dist
	$(MAKE) package-chocolatey

release: $(GORELEASER) $(SOURCE_FILES)
	$(GORELEASER) release --rm-dist
	$(MAKE) package-chocolatey

update/assets_vfsdata.go: update/assets_generate.go update/*.ps1
	cd update && go run assets_generate.go

# see https://www.packer.io/guides/hcl/component-object-spec/
update/provisioner.hcl2spec.go: update/provisioner.go
	go install github.com/hashicorp/packer/cmd/mapstructure-to-hcl2
	go generate ./...

package-chocolatey:
	rm -rf tmp-package-chocolatey
	cp -R package-chocolatey tmp-package-chocolatey
	sed -i -E " \
			s,@@VERSION@@,$(shell ls dist/packer-provisioner-windows-update_*_windows_amd64.zip | sed -E 's,.+-update_(.+)_windows_amd64.zip,\1,g'),g; \
			s,@@CHECKSUM@@,$(shell sha256sum dist/packer-provisioner-windows-update_*_windows_amd64.zip | awk '{print $$1}'),g; \
			" \
		tmp-package-chocolatey/*.nuspec \
		tmp-package-chocolatey/tools/*.ps1
	unzip -d tmp-package-chocolatey/tools dist/packer-provisioner-windows-update_*_windows_amd64.zip
	choco pack --output-directory dist tmp-package-chocolatey/*.nuspec

install: dist/packer-provisioner-windows-update_$(GOHOSTOS)_$(GOHOSTARCH)/packer-provisioner-windows-update$(GOEXE)
	mkdir -p $(HOME)/.packer.d/plugins
	cp -f $< $(HOME)/.packer.d/plugins/$(notdir $<)

clean:
	rm -rf dist tmp* update/assets_vfsdata.go

.PHONY: all build release release-snapshot package-chocolatey install clean
