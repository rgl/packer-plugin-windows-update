# syntax=docker.io/docker/dockerfile:1.18

# see https://github.com/devcontainers/images/tree/main/src/base-debian/history
FROM mcr.microsoft.com/devcontainers/base:2.0.1-trixie

RUN <<'EOF'
#!/usr/bin/bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install --no-install-recommends \
    bash-completion \
    curl \
    git \
    openssh-client \
    pylint \
    python3-argcomplete \
    python3-openssl \
    python3-pip \
    python3-venv \
    python3-yaml \
    qemu-system-x86 \
    qemu-utils \
    sudo \
    unzip \
    wget
apt-get clean
rm -rf /var/lib/apt/lists/*
activate-global-python-argcomplete
python3 -m venv --system-site-packages /opt/venv
EOF
ENV PATH="/opt/venv/bin:$PATH"

# disable the packer telemetry.
ENV CHECKPOINT_DISABLE=1

RUN <<'EOF'
#!/usr/bin/bash
set -euxo pipefail
# ensure /etc/profile is called at the top of the file, when running in a
# login shell.
sed -i '0,/esac/s/esac/&\n\nsource \/etc\/profile/' /home/vscode/.bashrc
EOF
COPY .devcontainer/inputrc /etc/inputrc
COPY .devcontainer/login.sh /etc/profile.d/login.sh
