$pluginExe = "$env:APPDATA\packer.d\plugins\packer-provisioner-windows-update.exe"

if (Test-Path $pluginExe) {
    Remove-Item $pluginExe
}
