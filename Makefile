build: packer-provisioner-windows-update packer-provisioner-windows-update.exe

packer-provisioner-windows-update: *.go update/* update/bindata.go
	GOOS=linux GOARCH=amd64 go build -v -o $@

packer-provisioner-windows-update.exe: *.go update/* update/bindata.go
	GOOS=windows GOARCH=amd64 go build -v -o $@

update/bindata.go: update/*.ps1
	go-bindata -nocompress -ignore '\.go$$' -o $@ -prefix update -pkg update update

dist: build
	tar -czf packer-provisioner-windows-update-linux.tgz packer-provisioner-windows-update
	zip packer-provisioner-windows-update-windows.zip packer-provisioner-windows-update.exe

clean:
	rm -f packer-provisioner-windows-update* update/bindata.go

.PHONY: build dist clean
