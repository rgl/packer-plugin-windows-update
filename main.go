package main

import (
	"github.com/hashicorp/packer/packer/plugin"

	"./update"
)

func main() {
	server, err := plugin.Server()
	if err != nil {
		panic(err)
	}
	server.RegisterProvisioner(new(update.Provisioner))
	server.Serve()
}
