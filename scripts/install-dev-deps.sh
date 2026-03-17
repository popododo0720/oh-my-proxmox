#!/usr/bin/env bash
# install-dev-deps.sh — Idempotent dev dependency installer
# Installs shellcheck and initializes bats-core git submodules.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  echo "[install-dev-deps] $*"
}

# Validate required commands
if ! command -v git &>/dev/null; then
  echo "ERROR: git is required but not found. Please install git." >&2
  exit 1
fi

# Install shellcheck if not present
if command -v shellcheck &>/dev/null; then
  log "shellcheck already installed: $(shellcheck --version | head -1)"
else
  log "Installing shellcheck..."
  if command -v apt-get &>/dev/null; then
    if [[ "${EUID}" -eq 0 ]]; then
      apt-get install -y shellcheck
    else
      if ! command -v sudo &>/dev/null; then
        echo "ERROR: sudo is required to install shellcheck as non-root but was not found." >&2
        exit 1
      fi
      sudo apt-get install -y shellcheck
    fi
  elif command -v brew &>/dev/null; then
    brew install shellcheck
  else
    echo "ERROR: Cannot install shellcheck — no supported package manager found." >&2
    echo "Please install shellcheck manually: https://github.com/koalaman/shellcheck" >&2
    exit 1
  fi
  log "shellcheck installed: $(shellcheck --version | head -1)"
fi

# Initialize and update git submodules (bats-core, bats-support, bats-assert)
log "Initializing git submodules..."
cd "${REPO_ROOT}"
git submodule update --init --recursive

log "Verifying bats-core..."
if [[ -x "${REPO_ROOT}/tests/bats/bin/bats" ]]; then
  log "bats-core ready: $("${REPO_ROOT}/tests/bats/bin/bats" --version)"
else
  echo "ERROR: bats-core not found at tests/bats/bin/bats" >&2
  exit 1
fi

log "Dev dependencies ready."
