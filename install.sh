#!/usr/bin/env bash
# install.sh — oh-my-proxmox remote installer
# Usage: curl -fsSL https://raw.githubusercontent.com/popododo0720/oh-my-proxmox/main/install.sh | bash
# Or for local install: ./install.sh --local

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
REPO_URL="https://github.com/popododo0720/oh-my-proxmox.git"
INSTALL_DIR="${OMP_HOME:-/opt/oh-my-proxmox}"
SYMLINK_PATH="/usr/local/bin/omp"
LOCAL_INSTALL=false

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "${arg}" in
    --local)
      LOCAL_INSTALL=true
      ;;
    --dir=*)
      INSTALL_DIR="${arg#--dir=}"
      ;;
    --help|-h)
      cat <<EOF
oh-my-proxmox installer

Usage: install.sh [options]

Options:
  --local        Install from the current directory (development mode)
  --dir=PATH     Install to PATH instead of ${INSTALL_DIR}
  --help         Show this help message

Remote install:
  curl -fsSL https://raw.githubusercontent.com/popododo0720/oh-my-proxmox/main/install.sh | bash
EOF
      exit 0
      ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log() {
  echo "[install] $*"
}

error() {
  echo "[install] ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" &>/dev/null || error "Required command not found: $1 — please install it first"
}

# ── Pre-flight checks ──────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
  error "This installer must be run as root. Try: sudo bash install.sh"
fi

require_cmd git
require_cmd bash
require_cmd curl

# ── Detect latest release ─────────────────────────────────────────────────────
get_latest_release() {
  local api_url="https://api.github.com/repos/popododo0720/oh-my-proxmox/releases/latest"
  local version
  version="$(curl -sf "${api_url}" 2>/dev/null \
    | grep '"tag_name":' \
    | sed 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/' || true)"
  echo "${version:-main}"
}

# ── Install ───────────────────────────────────────────────────────────────────
if [[ "${LOCAL_INSTALL}" == true ]]; then
  log "Local install mode — using current directory as source"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ "${SCRIPT_DIR}" != "${INSTALL_DIR}" ]]; then
    log "Copying files to ${INSTALL_DIR}..."
    mkdir -p "${INSTALL_DIR}"
    cp -r "${SCRIPT_DIR}/." "${INSTALL_DIR}/"
  fi
else
  # Detect latest release tag
  log "Detecting latest release..."
  RELEASE_TAG="$(get_latest_release)"
  log "Latest release: ${RELEASE_TAG}"

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    # Already installed — update
    log "Updating existing installation at ${INSTALL_DIR}..."
    git -C "${INSTALL_DIR}" fetch origin
    git -C "${INSTALL_DIR}" checkout "${RELEASE_TAG}" 2>/dev/null \
      || git -C "${INSTALL_DIR}" pull --ff-only origin main
  else
    # Fresh install
    log "Installing oh-my-proxmox to ${INSTALL_DIR}..."
    if [[ -d "${INSTALL_DIR}" ]] && [[ -n "$(ls -A "${INSTALL_DIR}")" ]]; then
      error "${INSTALL_DIR} exists and is not empty. Remove it or use --dir= to specify a different path."
    else
      git clone "${REPO_URL}" "${INSTALL_DIR}" --branch "${RELEASE_TAG}" 2>/dev/null \
        || git clone "${REPO_URL}" "${INSTALL_DIR}"
    fi
  fi
fi

# ── Initialize submodules ─────────────────────────────────────────────────────
log "Initializing git submodules..."
git -C "${INSTALL_DIR}" submodule update --init --recursive

# ── Create default config ─────────────────────────────────────────────────────
CONFIG_FILE="${INSTALL_DIR}/config.yaml"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  log "Creating default config at ${CONFIG_FILE}..."
  if [[ -f "${INSTALL_DIR}/config.yaml.example" ]]; then
    cp "${INSTALL_DIR}/config.yaml.example" "${CONFIG_FILE}"
  else
    cat > "${CONFIG_FILE}" <<'EOF'
# oh-my-proxmox configuration
# Space-separated list of enabled plugins
enabled_plugins:
EOF
  fi
fi

# ── Create symlink ────────────────────────────────────────────────────────────
log "Creating symlink: ${SYMLINK_PATH} -> ${INSTALL_DIR}/omp.sh"
chmod +x "${INSTALL_DIR}/omp.sh"
ln -sf "${INSTALL_DIR}/omp.sh" "${SYMLINK_PATH}"

# ── Done ──────────────────────────────────────────────────────────────────────
log ""
log "oh-my-proxmox installed successfully!"
log ""
log "  Installation directory: ${INSTALL_DIR}"
log "  Command:                omp"
log ""
log "Quick start:"
log "  omp plugin list"
log "  omp plugin enable no-subscription"
log "  omp install"
log ""
