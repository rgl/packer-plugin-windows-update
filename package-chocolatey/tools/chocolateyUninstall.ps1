@(
    "$env:APPDATA\packer.d\plugins"
    "$env:USERPROFILE\packer.d\plugins"
) | ForEach-Object {
    $pluginExe = "$_\packer-provisioner-windows-update.exe"
    if (Test-Path $pluginExe) {
        Remove-Item $pluginExe
    }
}
