Install-ChocolateyZipPackage `
    'packer-provisioner-windows-update' `
    'https://github.com/rgl/packer-provisioner-windows-update/releases/download/v@@VERSION@@/packer-provisioner-windows-update-windows.zip' `
    "$env:APPDATA\packer.d\plugins" `
    -Checksum '@@CHECKSUM@@' `
    -ChecksumType 'sha256'
