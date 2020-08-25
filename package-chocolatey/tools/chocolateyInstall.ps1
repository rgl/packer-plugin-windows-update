$pluginExe = "$env:ChocolateyPackageFolder\tools\packer-provisioner-windows-update.exe"
# NB in order for packer to find the plugin under msys2 and cmd/ps we must
#    install in these directories.
#    see https://github.com/rgl/packer-provisioner-windows-update/issues/64
@(
    "$env:APPDATA\packer.d\plugins"
    "$env:USERPROFILE\packer.d\plugins"
) | ForEach-Object {
    mkdir -Force $_ | Out-Null
    Copy-Item -Force $pluginExe $_
}
Remove-Item $pluginExe
