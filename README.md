# Packer Windows Update Provisioner

[![Build status](https://ci.appveyor.com/api/projects/status/1bmqt9ywh82vhojt?svg=true)](https://ci.appveyor.com/project/rgl/packer-provisioner-windows-update)
[![Latest version released](https://img.shields.io/chocolatey/v/packer-provisioner-windows-update.svg)](https://chocolatey.org/packages/packer-provisioner-windows-update)
[![Package downloads count](https://img.shields.io/chocolatey/dt/packer-provisioner-windows-update.svg)](https://chocolatey.org/packages/packer-provisioner-windows-update)

This is a Packer plugin for installing Windows updates (akin to [rgl/vagrant-windows-update](https://github.com/rgl/vagrant-windows-update)).

**NB** This was only tested with Packer 1.2.5 and Windows Server 2016.

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

## Search Criteria, Filters and Update Limit

You can select which Windows Updates are installed by defining the search criteria, a set of filters, and how many updates are installed at a time, e.g.:

```json
{
    "provisioners": [
        {
            "type": "windows-update",
            "search_criteria": "IsAssigned=1 and IsInstalled=0 and IsHidden=0",
            "filters": [
                "exclude:$_.Title -like '*Preview*'",
                "include:$true"
            ],
            "update_limit": 25
        }
    ]
}
```

**NB** If the `search_criteria` attribute is not declared, it defaults to `IsAssigned=1 and IsInstalled=0 and IsHidden=0`, which should search for important updates. For more information see the [IUpdateSearcher::Search method](https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search) documentation and the [xWindowsUpdateAgent DSC resource source](https://github.com/PowerShell/xWindowsUpdate/blob/dev/DscResources/MSFT_xWindowsUpdateAgent/MSFT_xWindowsUpdateAgent.psm1).

**NB** If the `filters` attribute is not declared, it defaults to `include:$true`.

**NB** If the `update_limit` attribute is not declared, it defaults to `100`.

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
