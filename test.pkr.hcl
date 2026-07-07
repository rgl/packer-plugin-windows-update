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
  headless = true
  cpus     = 2
  memory   = 4096
  qemuargs = [
    strcontains(var.disk_image, "uefi") ? ["-bios", "/usr/share/ovmf/OVMF.fd"] : null,
    ["-machine", "type=q35,accel=kvm,hpet=off"],
    ["-cpu", "host,hv-passthrough"],
    ["-rtc", "base=localtime,clock=host"],
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
  communicator     = "ssh" # or winrm.
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "4h"
  winrm_username   = "vagrant"
  winrm_password   = "vagrant"
  winrm_timeout    = "4h"
}

build {
  sources = [
    "source.qemu.test",
  ]
  provisioner "windows-update" {
    filters = [
      # exclude KB5007651:
      #   Update for Windows Security platform - KB5007651 (Version 10.0.29510.1001)
      # NB it can only be applied while the user is logged in.
      "exclude:$_.Title -like '*KB5007651*'",
      "include:$true",
    ]
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
