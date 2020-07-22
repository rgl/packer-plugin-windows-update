SOURCE_FILES := *.go update/* update/assets_vfsdata.go update/provisioner.hcl2spec.go

all: build

build: \
	build/darwin/packer-provisioner-windows-update \
	build/linux/packer-provisioner-windows-update \
	build/windows/packer-provisioner-windows-update.exe

build/%: $(SOURCE_FILES)
	$(eval GOOS := $(word 2,$(subst /, ,$@)))
	mkdir -p $(dir $@)
	GOOS=$(GOOS) GOARCH=amd64 go build -v -o $@

update/assets_vfsdata.go: update/assets_generate.go update/*.ps1
	cd update && go run assets_generate.go

# see https://www.packer.io/guides/hcl/component-object-spec/
update/provisioner.hcl2spec.go: update/provisioner.go
	go install github.com/hashicorp/packer/cmd/mapstructure-to-hcl2
	go generate ./...

dist: package-chocolatey

package: build
	cd build/darwin && tar -czf ../../packer-provisioner-windows-update-darwin.tgz packer-provisioner-windows-update
	cd build/linux && tar -czf ../../packer-provisioner-windows-update-linux.tgz packer-provisioner-windows-update
	cd build/windows && zip ../../packer-provisioner-windows-update-windows.zip packer-provisioner-windows-update.exe

package-chocolatey: package
	rm -rf tmp-package-chocolatey
	cp -R package-chocolatey tmp-package-chocolatey
	sed -i -E " \
			s,@@VERSION@@,$(shell cat VERSION),g; \
			s,@@CHECKSUM@@,$(shell sha256sum packer-provisioner-windows-update-windows.zip | awk '{print $$1}'),g; \
			" \
		tmp-package-chocolatey/*.nuspec \
		tmp-package-chocolatey/tools/*.ps1
	choco pack tmp-package-chocolatey/*.nuspec

clean:
	rm -rf build packer-provisioner-windows-update* tmp* update/assets_vfsdata.go

.PHONY: build dist package package-chocolatey clean
