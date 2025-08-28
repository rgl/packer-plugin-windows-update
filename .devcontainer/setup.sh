#!/bin/bash
set -euxo pipefail

pushd /home/vscode
sudo chown vscode:vscode .ssh && sudo chmod 700 .ssh
popd
