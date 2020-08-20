$pluginsDirectory = "$env:USERPROFILE\packer.d\plugins"
$pluginExe = "$env:ChocolateyPackageFolder\tools\packer-provisioner-windows-update.exe"
mkdir -Force $pluginsDirectory | Out-Null
Copy-Item -Force $pluginExe $pluginsDirectory
Remove-Item $pluginExe
