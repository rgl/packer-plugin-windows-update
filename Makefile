build: packer-provisioner-windows-update packer-provisioner-windows-update.exe

packer-provisioner-windows-update: *.go update/* update/assets_vfsdata.go update/provisioner.hcl2spec.go
	GOOS=linux GOARCH=amd64 go build -v -o $@

packer-provisioner-windows-update.exe: *.go update/* update/assets_vfsdata.go update/provisioner.hcl2spec.go
	GOOS=windows GOARCH=amd64 go build -v -o $@

update/assets_vfsdata.go: update/assets_generate.go update/*.ps1
	cd update && go run assets_generate.go

# see https://www.packer.io/guides/hcl/component-object-spec/
update/provisioner.hcl2spec.go: update/provisioner.go
	go install github.com/hashicorp/packer/cmd/mapstructure-to-hcl2
	go generate ./...

dist: package-chocolatey

package: build
	tar -czf packer-provisioner-windows-update-linux.tgz packer-provisioner-windows-update
	zip packer-provisioner-windows-update-windows.zip packer-provisioner-windows-update.exe

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
	rm -rf packer-provisioner-windows-update* tmp* update/assets_vfsdata.go

.PHONY: build dist package package-chocolatey clean
