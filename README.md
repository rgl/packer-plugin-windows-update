# Packer Windows Update Provisioner

[![Build status](https://github.com/rgl/packer-plugin-windows-update/workflows/Build/badge.svg)](https://github.com/rgl/packer-plugin-windows-update/actions?query=workflow%3ABuild)

This is a Packer plugin for installing Windows updates (akin to [rgl/vagrant-windows-update](https://github.com/rgl/vagrant-windows-update)).

**NB** This was only tested with Packer 1.14.1 and the images at [rgl/windows-vagrant](https://github.com/rgl/windows-vagrant), so YMMV.

# Usage

Configure your packer template to require a [release version of the plugin](https://github.com/rgl/packer-plugin-windows-update/releases), e.g.:

```hcl
packer {
  required_plugins {
    windows-update = {
      version = "0.17.2"
      source  = "github.com/rgl/windows-update"
    }
  }
}
```

Initialize your packer template (it will install the plugin):

```bash
packer init your-template.pkr.hcl
```

Use this provisioner plugin from your packer template file, e.g. like in [rgl/windows-vagrant](https://github.com/rgl/windows-vagrant):

```hcl
build {
  provisioner "windows-update" {
  }
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

```hcl
build {
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    update_limit = 25
    reboot_delay = 900
    use_extended_validation = true
  }
}
```

**NB** For more information about the search criteria see the [IUpdateSearcher::Search method](https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search) documentation and the [xWindowsUpdateAgent DSC resource source](https://github.com/PowerShell/xWindowsUpdate/blob/dev/DscResources/MSFT_xWindowsUpdateAgent/MSFT_xWindowsUpdateAgent.psm1).

**NB** If the `update_limit` attribute is not declared, it defaults to `1000`.

**NB** If the `reboot_delay` attribute is not declared, it defaults to `0`.  reboot_delay is in seconds.  It delays reboots after windows updates have completed.

**NB** If the `use_extended_validation` attribute is not declared, it defaults to 'false'.  use_extended_validation accepts boolean values (true/false).  If set to true, windows update completion is validated by either the exiting of the windows installer process or event logs / CBS logs that validate the completion.  Some Windows updates complete, but do not exit the TiWorker.exe process to validate the completion.  This parameter handles those types of scenarios, ensuring this windows update module finalizes successfully.

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

* [Docker](https://docs.docker.com/engine/install/).
* [Visual Studio Code](https://code.visualstudio.com).
* [Dev Container plugin](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).
* [`windows-2022-amd64` vagrant box](https://github.com/rgl/windows-vagrant).

Open this directory with the Dev Container plugin.

Open `bash` inside the Visual Studio Code Terminal.

Build:

```bash
make
```

Test with QEMU:

```bash
make test
```
