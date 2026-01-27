#!/bin/bash
set -euxo pipefail

# ensure provisioner.hcl2spec.go is updated by re-generate it. if there are
# differences, abort the build.
rm -f update/provisioner.hcl2spec.go
make update/provisioner.hcl2spec.go
git diff --exit-code update/provisioner.hcl2spec.go \
  || (echo 'ERROR: You must re-generate update/provisioner.hcl2spec.go and commit the changes.' && exit 1)

# point the msys2 user gpg home to the one managed by the crazy-max/ghaction-import-gpg github action.
ln -s /c/Users/runneradmin/.gnupg ~/.gnupg

# do the release.
if [[ $GITHUB_REF == refs/tags/v* ]]; then
  make release
else
  make release-snapshot
fi
