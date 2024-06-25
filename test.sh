#!/usr/bin/bash
set -euo pipefail

GOHOSTOS="$(go env GOHOSTOS)"
GOHOSTARCH="$(go env GOHOSTARCH)"
PLUGIN_PATH="$(
    jq -r \
        --arg goos "$GOHOSTOS" \
        --arg goarch "$GOHOSTARCH" \
        '.[] | select(.goos == $goos and .goarch == $goarch and .extra.ID == "packer-plugin-windows-update") | .path' \
        dist/artifacts.json)"
PLUGIN_BASE_NAME="$(basename "$PLUGIN_PATH")"
PLUGIN_TEST_PATH="dist/test/plugins/github.com/rgl/windows-update/$PLUGIN_BASE_NAME"

# see https://developer.hashicorp.com/packer/docs/plugins/creation/plugin-load-spec
rm -rf output-test test.log dist/test
install -d dist/test/plugins/github.com/rgl/windows-update
install "$PLUGIN_PATH" "$PLUGIN_TEST_PATH"
(cd "$(dirname "$PLUGIN_TEST_PATH")" && \
    sha256sum "$PLUGIN_BASE_NAME" >"${PLUGIN_BASE_NAME}_SHA256SUM")

export CHECKPOINT_DISABLE=1
export PACKER_LOG=1
export PACKER_LOG_PATH=test.log
export PACKER_CONFIG_DIR="$PWD/dist/test"
export PACKER_PLUGIN_PATH="$PWD/dist/test/plugins"
export PKR_VAR_disk_image=~/.vagrant.d/boxes/windows-2022-amd64/0.0.0/libvirt/box_0.img

packer init -only=qemu.test test.pkr.hcl
packer build -only=qemu.test -on-error=abort test.pkr.hcl
