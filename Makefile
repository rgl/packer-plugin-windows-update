build: packer-provisioner-windows-update packer-provisioner-windows-update.exe

packer-provisioner-windows-update: *.go update/* update/bindata.go
	GOOS=linux GOARCH=amd64 go build -v -o $@

packer-provisioner-windows-update.exe: *.go update/* update/bindata.go
	GOOS=windows GOARCH=amd64 go build -v -o $@

update/bindata.go: update/*.ps1
	go-bindata -nocompress -ignore '\.go$$' -o $@ -prefix update -pkg update update

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
	rm -rf packer-provisioner-windows-update* tmp* update/bindata.go

.PHONY: build dist package package-chocolatey clean
