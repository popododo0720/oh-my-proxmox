#!/usr/bin/env bash
# omp.sh — oh-my-proxmox CLI entry point
# Usage: omp <command> [options]

set -euo pipefail

# ── Default paths ────────────────────────────────────────────────────────────
OMP_HOME="${OMP_HOME:-/opt/oh-my-proxmox}"
OMP_BACKUP_DIR="${OMP_BACKUP_DIR:-/var/lib/oh-my-proxmox/backups}"
OMP_CONFIG_FILE="${OMP_CONFIG_FILE:-${OMP_HOME}/config.yaml}"
export OMP_HOME OMP_BACKUP_DIR OMP_CONFIG_FILE

# ── Source core modules ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core/utils.sh
source "${SCRIPT_DIR}/core/utils.sh"
# shellcheck source=core/config.sh
source "${SCRIPT_DIR}/core/config.sh"
# shellcheck source=core/plugin-manager.sh
source "${SCRIPT_DIR}/core/plugin-manager.sh"

# ── Version ──────────────────────────────────────────────────────────────────
OMP_VERSION="0.1.0"
if [[ -f "${OMP_HOME}/VERSION" ]]; then
  OMP_VERSION="$(cat "${OMP_HOME}/VERSION")"
elif command -v git &>/dev/null && [[ -d "${OMP_HOME}/.git" ]]; then
  OMP_VERSION="$(git -C "${OMP_HOME}" describe --tags --always 2>/dev/null || echo "0.1.0")"
fi

# ── Help text ────────────────────────────────────────────────────────────────
omp_usage() {
  cat <<EOF
oh-my-proxmox ${OMP_VERSION} — Proxmox VE post-install automation framework

Usage: omp <command> [options]

Commands:
  install                   Install all enabled plugins
  plugin list               List available plugins and their status
  plugin enable <name>      Enable and install a plugin
  plugin disable <name>     Disable and uninstall a plugin
  update                    Update oh-my-proxmox to the latest version
  doctor                    Run system diagnostics
  rollback                  Rollback the last applied plugin set
  --help, -h                Show this help message
  --version, -v             Show version information

Examples:
  omp install
  omp plugin list
  omp plugin enable no-subscription
  omp plugin disable dark-mode
  omp doctor

EOF
}

omp_plugin_usage() {
  cat <<EOF
Usage: omp plugin <subcommand> [options]

Subcommands:
  list                      List available plugins and their status
  enable <name>             Enable and install a plugin
  disable <name>            Disable and uninstall a plugin

EOF
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_install() {
  omp_require_root
  omp_require_proxmox
  omp_plugin_install_all
}

cmd_plugin() {
  local subcmd="${1:-}"
  shift || true

  case "${subcmd}" in
    list)
      omp_plugin_list
      ;;
    enable)
      local plugin_name="${1:-}"
      if [[ -z "${plugin_name}" ]]; then
        omp_error "Usage: omp plugin enable <name>" 1
      fi
      omp_require_root
      omp_require_proxmox
      omp_plugin_enable "${plugin_name}"
      ;;
    disable)
      local plugin_name="${1:-}"
      if [[ -z "${plugin_name}" ]]; then
        omp_error "Usage: omp plugin disable <name>" 1
      fi
      omp_require_root
      omp_require_proxmox
      omp_plugin_disable "${plugin_name}"
      ;;
    --help|-h|help|"")
      omp_plugin_usage
      ;;
    *)
      omp_error "Unknown plugin subcommand: ${subcmd}"
      omp_plugin_usage
      exit 1
      ;;
  esac
}

cmd_update() {
  omp_require_root
  omp_log "Updating oh-my-proxmox..."

  if ! command -v git &>/dev/null; then
    omp_error "git is required for updates." 1
  fi

  if [[ ! -d "${OMP_HOME}/.git" ]]; then
    omp_error "oh-my-proxmox is not a git repository. Cannot auto-update." 1
  fi

  git -C "${OMP_HOME}" pull --ff-only origin main
  git -C "${OMP_HOME}" submodule update --init --recursive
  omp_log "Update complete. Re-sourcing modules..."
  # Re-source is best-effort in the current shell; user should re-run omp
  omp_log "Please restart omp to use the updated version."
}

cmd_doctor() {
  omp_log "Running oh-my-proxmox diagnostics..."

  # Check Proxmox
  if command -v pveversion &>/dev/null; then
    local pve_ver
    pve_ver="$(pveversion 2>/dev/null | head -1)"
    omp_log "Proxmox VE: ${pve_ver}"
  else
    omp_warn "pveversion not found — not running on Proxmox VE?"
  fi

  # Check connectivity
  if ! command -v curl &>/dev/null; then
    omp_warn "Network: curl not found — cannot check connectivity"
  elif curl -s --max-time 5 https://github.com &>/dev/null; then
    omp_log "Network: OK (reached github.com)"
  else
    omp_warn "Network: Cannot reach github.com"
  fi

  # Check disk space
  local avail_kb
  avail_kb="$(df -k "${OMP_HOME}" 2>/dev/null | awk 'NR==2{print $4}')"
  if [[ -n "${avail_kb}" ]]; then
    local avail_mb=$(( avail_kb / 1024 ))
    if [[ "${avail_mb}" -lt 100 ]]; then
      omp_warn "Disk space low: ${avail_mb}MB available at ${OMP_HOME}"
    else
      omp_log "Disk space: ${avail_mb}MB available at ${OMP_HOME}"
    fi
  fi

  # Check OMP_HOME
  if [[ -d "${OMP_HOME}" ]]; then
    omp_log "OMP_HOME: ${OMP_HOME} (OK)"
  else
    omp_warn "OMP_HOME not found: ${OMP_HOME}"
  fi

  # Check config
  if [[ -f "${OMP_CONFIG_FILE}" ]]; then
    omp_log "Config: ${OMP_CONFIG_FILE} (OK)"
  else
    omp_warn "Config file not found: ${OMP_CONFIG_FILE}"
  fi

  omp_log "Diagnostics complete."
}

cmd_rollback() {
  omp_require_root
  omp_log "Rolling back last applied plugin set..."

  if [[ ! -d "${OMP_BACKUP_DIR}" ]]; then
    omp_error "Backup directory not found: ${OMP_BACKUP_DIR}" 1
  fi

  omp_config_load
  local enabled_plugins
  enabled_plugins="$(omp_config_get "enabled_plugins" "")"

  if [[ -z "${enabled_plugins}" ]]; then
    omp_log "No enabled plugins to roll back."
    return 0
  fi

  local success=true
  for plugin_name in ${enabled_plugins}; do
    local plugin_dir="${OMP_HOME}/plugins/${plugin_name}"
    if [[ -f "${plugin_dir}/uninstall.sh" ]]; then
      omp_log "Rolling back plugin: ${plugin_name}"
      if ! bash "${plugin_dir}/uninstall.sh"; then
        omp_error "uninstall.sh failed for plugin: ${plugin_name}"
        success=false
      fi
    else
      omp_warn "No uninstall.sh for plugin: ${plugin_name} — skipping rollback"
    fi
  done

  if [[ "${success}" == true ]]; then
    omp_log "Rollback complete."
  else
    omp_error "Some plugins failed to roll back." 1
  fi
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
main() {
  local command="${1:-}"
  shift || true

  case "${command}" in
    install)
      cmd_install "$@"
      ;;
    plugin)
      cmd_plugin "$@"
      ;;
    update)
      cmd_update "$@"
      ;;
    doctor)
      cmd_doctor "$@"
      ;;
    rollback)
      cmd_rollback "$@"
      ;;
    --version|-v|version)
      echo "oh-my-proxmox ${OMP_VERSION}"
      ;;
    --help|-h|help|"")
      omp_usage
      ;;
    *)
      omp_error "Unknown command: ${command}"
      omp_usage
      exit 1
      ;;
  esac
}

main "$@"
