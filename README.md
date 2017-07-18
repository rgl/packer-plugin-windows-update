# Packer Windows Update Provisioner

[![Build status](https://ci.appveyor.com/api/projects/status/1bmqt9ywh82vhojt?svg=true)](https://ci.appveyor.com/project/rgl/packer-provisioner-windows-update)

This is a Packer plugin for installing Windows updates (akin to [rgl/vagrant-windows-update](https://github.com/rgl/vagrant-windows-update)).

**NB** This was only tested with Packer 1.0.2 and Windows Server 2016.

# Usage

[Download the binary from the releases page](https://github.com/rgl/packer-provisioner-windows-update/releases)
and put it in the same directory as your `packer` executable.

Use the provisioner from your packer template file, e.g. like in [rgl/windows-2016-vagrant](https://github.com/rgl/windows-2016-vagrant):

```json
{
    "provisioners": [
        {
            "type": "windows-update"
        }
    ]
}
```

# Development

Install the dependencies:

```bash
go get -u github.com/hashicorp/packer/packer/plugin
go get -u github.com/masterzen/winrm
go get -u github.com/jteeuwen/go-bindata/...
```

Build:

```bash
make
```

Configure packer with the path to this provisioner by adding something like the
following snippet to your `~/.packerconfig` (or `%APPDATA%/packer.config`):

```json
{
    "provisioners": {
        "windows-update": "/home/rgl/Projects/packer-provisioner-windows-update/packer-provisioner-windows-update"
    }
}
```

If you are having problems running `packer` set the `PACKER_LOG=1` environment
variable to see more information.
