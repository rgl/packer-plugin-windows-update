# Packer Windows Update Provisioner

[![Build status](https://github.com/rgl/packer-provisioner-windows-update/workflows/Build/badge.svg)](https://github.com/rgl/packer-provisioner-windows-update/actions?query=workflow%3ABuild)
[![Latest version released](https://img.shields.io/chocolatey/v/packer-provisioner-windows-update.svg)](https://chocolatey.org/packages/packer-provisioner-windows-update)
[![Package downloads count](https://img.shields.io/chocolatey/dt/packer-provisioner-windows-update.svg)](https://chocolatey.org/packages/packer-provisioner-windows-update)

This is a Packer plugin for installing Windows updates (akin to [rgl/vagrant-windows-update](https://github.com/rgl/vagrant-windows-update)).

**NB** This was only tested with Packer 1.6.1 on Windows Server 2019, macOS Catalina and Ubuntu 20.04.

# Usage

[Download the binary from the releases page](https://github.com/rgl/packer-provisioner-windows-update/releases)
and put it in the same directory as your `packer` executable.

Use the provisioner from your packer template file, e.g. like in [rgl/windows-vagrant](https://github.com/rgl/windows-vagrant):

```json
{
    "provisioners": [
        {
            "type": "windows-update"
        }
    ]
}
```

Note, the plugin automatically restarts the machine after Windows Updates are applied.  The reboots occur similar to the windows-restart provisioner built into packer where packer is aware that a shutdown is in progress.

## Search Criteria, Filters and Update Limit

You can select which Windows Updates are installed by defining the search criteria, a set of filters, and how many updates are installed at a time.

Normally you would use one of the following settings:

| Name          | `search_criteria`                           | `filters`       |
|---------------|---------------------------------------------|-----------------|
| Important     | `AutoSelectOnWebSites=1 and IsInstalled=0`  | `$true`         |
| Recommended   | `BrowseOnly=0 and IsInstalled=0`            | `$true`         |
| All           | `IsInstalled=0`                             | `$true`         |
| Optional Only | `AutoSelectOnWebSites=0 and IsInstalled=0`  | `$_.BrowseOnly` |

**NB** `Recommended` is the default setting.

But you can customize them, e.g.:

```json
{
    "provisioners": [
        {
            "type": "windows-update",
            "search_criteria": "IsInstalled=0",
            "filters": [
                "exclude:$_.Title -like '*Preview*'",
                "include:$true"
            ],
            "update_limit": 25
        }
    ]
}
```

**NB** For more information about the search criteria see the [IUpdateSearcher::Search method](https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search) documentation and the [xWindowsUpdateAgent DSC resource source](https://github.com/PowerShell/xWindowsUpdate/blob/dev/DscResources/MSFT_xWindowsUpdateAgent/MSFT_xWindowsUpdateAgent.psm1).

**NB** If the `update_limit` attribute is not declared, it defaults to `1000`.

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

Or install into `$HOME/.packer.d/plugins` with:

```
make install
```

If you are having problems running `packer` set the `PACKER_LOG=1` environment
variable to see more information.
