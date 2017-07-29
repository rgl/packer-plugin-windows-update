# Packer Windows Update Provisioner

[![Build status](https://ci.appveyor.com/api/projects/status/1bmqt9ywh82vhojt?svg=true)](https://ci.appveyor.com/project/rgl/packer-provisioner-windows-update)
[![Latest version released](https://img.shields.io/chocolatey/v/packer-provisioner-windows-update.svg)](https://chocolatey.org/packages/packer-provisioner-windows-update)
[![Package downloads count](https://img.shields.io/chocolatey/dt/packer-provisioner-windows-update.svg)](https://chocolatey.org/packages/packer-provisioner-windows-update)

This is a Packer plugin for installing Windows updates (akin to [rgl/vagrant-windows-update](https://github.com/rgl/vagrant-windows-update)).

**NB** This was only tested with Packer 1.2.2 and Windows Server 2016.

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

## Filters

You can select which Windows Updates are installed by defining a set of filters, e.g.:

```json
{
    "provisioners": [
        {
            "type": "windows-update",
            "filters": [
                "exclude:$_.Title -like '*Preview*'",
                "include:$_.Title -like '*Cumulative Update for Windows*'",
                "include:$_.AutoSelectOnWebSites"
            ]
        }
    ]
}
```

**NB** If the `filters` attribute is not declared, only important updates are installed (equivalent of declaring a single `include:$_.AutoSelectOnWebSites` filter).

The general filter syntax is:

    ACTION:EXPRESSION

`ACTION` is a string that can have one of the following values:

| action    | description                                                  |
| --------- | ------------------------------------------------------------ |
| `include` | includes the update when the expression evaluates to `$true` |
| `exclude` | excludes the update when the expression evaluates to `$true` |

**NB** If no `ACTION` evaluates to `$true` the update will **NOT** be installed.

`EXPRESSION` is a PowerShell expression. When it returns `$true`, the
`ACTION` is executed and no further filters are evaluated.

Inside an expression, the Windows Update [IUpdate interface](https://msdn.microsoft.com/en-us/library/windows/desktop/aa386099(v=vs.85).aspx) can be referenced by the `$_` variable.

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
