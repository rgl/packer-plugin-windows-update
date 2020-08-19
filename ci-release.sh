#!/bin/bash
set -euxo pipefail

if [[ $GITHUB_REF == refs/tags/v* ]]; then
  make release
else
  make release-snapshot
fi
