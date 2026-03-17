#!/usr/bin/env bash
# core/utils.sh — Shared helper functions for oh-my-proxmox
# Sourceable with no side effects. All functions prefixed with omp_.

# ANSI color codes
OMP_COLOR_RESET='\033[0m'
OMP_COLOR_GREEN='\033[0;32m'
OMP_COLOR_YELLOW='\033[0;33m'
OMP_COLOR_RED='\033[0;31m'
OMP_COLOR_CYAN='\033[0;36m'

# omp_log <message>
# Print an info-level log message with timestamp.
omp_log() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "${OMP_COLOR_CYAN}[${timestamp}] [INFO]${OMP_COLOR_RESET} $*"
}

# omp_warn <message>
# Print a warning-level log message (yellow).
omp_warn() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "${OMP_COLOR_YELLOW}[${timestamp}] [WARN]${OMP_COLOR_RESET} $*" >&2
}

# omp_error <message> [exit_code]
# Print an error-level log message (red). Exits with exit_code if provided.
omp_error() {
  local message="$1"
  local exit_code="${2:-}"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "${OMP_COLOR_RED}[${timestamp}] [ERROR]${OMP_COLOR_RESET} ${message}" >&2
  if [[ -n "${exit_code}" ]]; then
    exit "${exit_code}"
  fi
}

# omp_backup_file <file_path>
# Copy a file to $OMP_BACKUP_DIR preserving its relative path structure.
# Creates backup directory if needed.
omp_backup_file() {
  local file_path="$1"
  local backup_base="${OMP_BACKUP_DIR:-/var/lib/oh-my-proxmox/backups}"

  if [[ ! -f "${file_path}" ]]; then
    omp_warn "Cannot backup '${file_path}': file does not exist"
    return 0
  fi

  local backup_dest="${backup_base}${file_path}"
  local backup_dir
  backup_dir="$(dirname "${backup_dest}")"

  mkdir -p "${backup_dir}"
  cp -p "${file_path}" "${backup_dest}"
  omp_log "Backed up: ${file_path} → ${backup_dest}"
}

# omp_restore_file <file_path>
# Restore a file from $OMP_BACKUP_DIR.
omp_restore_file() {
  local file_path="$1"
  local backup_base="${OMP_BACKUP_DIR:-/var/lib/oh-my-proxmox/backups}"
  local backup_src="${backup_base}${file_path}"

  if [[ ! -f "${backup_src}" ]]; then
    omp_error "Cannot restore '${file_path}': backup not found at '${backup_src}'"
    return 1
  fi

  local dest_dir
  dest_dir="$(dirname "${file_path}")"
  mkdir -p "${dest_dir}"
  cp -p "${backup_src}" "${file_path}"
  omp_log "Restored: ${backup_src} → ${file_path}"
}

# omp_require_root
# Assert the script is running as root. Exits with code 1 if not.
omp_require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    omp_error "This operation requires root privileges. Please run as root or with sudo." 1
  fi
}

# omp_require_proxmox
# Assert the script is running on a Proxmox VE host. Exits with code 1 if not.
omp_require_proxmox() {
  if ! command -v pveversion &>/dev/null; then
    omp_error "This operation requires Proxmox VE. 'pveversion' not found." 1
  fi
}
