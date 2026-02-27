packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-qemu
    qemu = {
      version = "1.1.4"
      source  = "github.com/hashicorp/qemu"
    }
    # see https://github.com/rgl/packer-plugin-windows-update
    windows-update = {
      version = ">= 0.0.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "disk_image" {
  type = string
}

source "qemu" "test" {
  headless     = true
  accelerator  = "kvm"
  machine_type = "q35"
  cpus         = 2
  memory       = 4096
  qemuargs = [
    strcontains(var.disk_image, "uefi") ? ["-bios", "/usr/share/ovmf/OVMF.fd"] : null,
    ["-cpu", "host"],
  ]
  disk_interface   = "virtio-scsi"
  disk_cache       = "unsafe"
  disk_discard     = "unmap"
  disk_image       = true
  use_backing_file = true
  disk_size        = var.disk_size
  iso_url          = var.disk_image
  iso_checksum     = "none"
  net_device       = "virtio-net"
  shutdown_command = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator     = "winrm"
  winrm_username   = "vagrant"
  winrm_password   = "vagrant"
  winrm_timeout    = "4h"
}

build {
  sources = [
    "source.qemu.test",
  ]
  provisioner "windows-update" {
  }
  provisioner "powershell" {
    use_pwsh = true
    inline = [
      <<-EOF
      $p = 'c:/packer.delete.me.to.end.test.wait.txt'
      Set-Content $p 'delete this file to end the packer test wait'
      Write-Host "ATTENTION To end this test wait, login into the machine and delete the $p file. Or just press Ctrl+C."
      while (Test-Path $p) {
        Start-Sleep -Seconds 5
      }
      EOF
    ]
  }
}
