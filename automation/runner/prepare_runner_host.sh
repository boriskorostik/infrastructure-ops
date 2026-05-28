#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  git \
  jq \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep \
  software-properties-common

if ! command -v ansible-playbook >/dev/null 2>&1; then
  apt-get install -y ansible
fi

if command -v docker >/dev/null 2>&1; then
  docker compose version >/dev/null 2>&1 || true
fi

echo "Runner host prerequisites installed."
echo "Verify next:"
echo "  git --version"
echo "  python3 --version"
echo "  ansible-playbook --version"
echo "  docker compose version"
