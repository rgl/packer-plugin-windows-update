package main

import (
	"github.com/hashicorp/packer/packer/plugin"
	"github.com/rgl/packer-provisioner-windows-update/update"
)

func main() {
	server, err := plugin.Server()
	if err != nil {
		panic(err)
	}
	server.RegisterProvisioner(new(update.Provisioner))
	server.Serve()
}
