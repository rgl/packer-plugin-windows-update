GOARCH := amd64
SOURCE_FILES := *.go update/* update/assets_vfsdata.go update/provisioner.hcl2spec.go

 ifeq "${VERBOSE}" ""
 	Q=@
 else
 	Q=
 endif
 
all: build

build: build/linux/packer-provisioner-windows-update \
	build/windows/packer-provisioner-windows-update.exe \
	build/darwin/packer-provisioner-windows-update

#
#	Generic build target
#
build/%: $(SOURCE_FILES)
	$(eval GOOS := $(word 2, $(subst /, ,$@)))
	@echo "BUILD $@"
	$(Q)mkdir -p $(dir $@)
	$(Q)GOOS=$(GOOS) GOARCH=$(GOARCH) go build -v -o $@

update/assets_vfsdata.go: update/assets_generate.go update/*.ps1
	@echo "UPDATE $@"
	$(Q)(cd update && go run assets_generate.go)

#
# see https://www.packer.io/guides/hcl/component-object-spec/
#
update/provisioner.hcl2spec.go: update/provisioner.go
	$(Q)go install github.com/hashicorp/packer/cmd/mapstructure-to-hcl2
	$(Q)go generate ./...

dist: package-chocolatey

package: build
	(cd build/linux  && tar -czf ../../packer-provisioner-windows-update_linux-$(GOARCH).tgz packer-provisioner-windows-update)
	(cd build/darwin && tar -czf ../../packer-provisioner-windows-update_darwin-$(GOARCH).tgz packer-provisioner-windows-update)
	(cd build/windows && zip ../../packer-provisioner-windows-update_windows-$(GOARCH).zip packer-provisioner-windows-update.exe)

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
	rm -rf build/ packer-provisioner-windows-update* tmp* update/assets_vfsdata.go

.PHONY: build dist package package-chocolatey clean
