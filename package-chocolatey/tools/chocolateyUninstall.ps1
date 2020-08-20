$pluginsDirectory = "$env:USERPROFILE\packer.d\plugins"
$pluginExe = "$pluginsDirectory\packer-provisioner-windows-update.exe"

if (Test-Path $pluginExe) {
    Remove-Item $pluginExe
}
