Install-ChocolateyZipPackage `
    'packer-provisioner-windows-update' `
    'https://github.com/rgl/packer-provisioner-windows-update/releases/download/v@@VERSION@@/packer-provisioner-windows-update_@@VERSION@@_windows_amd64.zip' `
    "$env:APPDATA\packer.d\plugins" `
    -Checksum '@@CHECKSUM@@' `
    -ChecksumType 'sha256'
