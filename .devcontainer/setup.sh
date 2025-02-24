#!/bin/bash
set -euxo pipefail

pushd /home/vscode
sudo chown vscode:vscode .ssh && sudo chmod 700 .ssh
sudo chown vscode:vscode .cache && sudo chmod 700 .cache
sudo chown vscode:vscode .cache/libvirt && sudo chmod 700 .cache/libvirt
popd
