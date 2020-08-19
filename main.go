package main

import (
	"log"

	"github.com/hashicorp/packer/packer/plugin"
	"github.com/rgl/packer-provisioner-windows-update/update"
)

var (
	version = "unknown"
	commit  = "unknown"
	date    = "unknown"
)

func main() {
	log.Printf("Starting packer-provisioner-windows-update (version %s; commit %s; date %s)", version, commit, date)
	server, err := plugin.Server()
	if err != nil {
		panic(err)
	}
	server.RegisterProvisioner(new(update.Provisioner))
	server.Serve()
}
