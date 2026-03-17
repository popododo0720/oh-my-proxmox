#!/usr/bin/env bash
# core/config.sh — YAML-lite config parser for oh-my-proxmox
# Pure Bash, no external dependencies. Config path via $OMP_CONFIG_FILE.
# Sourceable with no side effects.

# _OMP_CONFIG_DATA is an associative array holding parsed key=value pairs.
declare -gA _OMP_CONFIG_DATA=()

# omp_config_load [config_file]
# Parse config.yaml (or $OMP_CONFIG_FILE) and populate _OMP_CONFIG_DATA.
# Supports simple key: value pairs and list entries (- item).
# Ignores comments (#) and blank lines.
omp_config_load() {
  local config_file="${1:-${OMP_CONFIG_FILE:-${OMP_HOME:-/opt/oh-my-proxmox}/config.yaml}}"

  if [[ ! -f "${config_file}" ]]; then
    # No config file is not an error — use defaults
    return 0
  fi

  _OMP_CONFIG_DATA=()
  local current_key=""
  local list_index=0

  while IFS= read -r line; do
    # Skip blank lines and comments
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    # List item: "  - value"
    if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
      local list_value="${BASH_REMATCH[1]}"
      # Trim surrounding quotes if present
      list_value="${list_value#\"}"
      list_value="${list_value%\"}"
      list_value="${list_value#\'}"
      list_value="${list_value%\'}"
      if [[ -n "${current_key}" ]]; then
        _OMP_CONFIG_DATA["${current_key}.${list_index}"]="${list_value}"
        _OMP_CONFIG_DATA["${current_key}.__count"]="${list_index}"
        (( list_index++ )) || true
      fi
      continue
    fi

    # Key: value pair
    if [[ "${line}" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*:[[:space:]]*(.*) ]]; then
      current_key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      list_index=0

      # Trim surrounding quotes if present
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"

      # Only set scalar if value is not empty (list keys have empty values)
      if [[ -n "${value}" ]]; then
        _OMP_CONFIG_DATA["${current_key}"]="${value}"
      else
        # Initialize as empty (may be a list parent)
        _OMP_CONFIG_DATA["${current_key}"]=""
      fi
      continue
    fi
  done < "${config_file}"
}

# omp_config_get <key> [default]
# Get a config value by key. Prints the value or default if not found.
omp_config_get() {
  local key="$1"
  local default="${2:-}"

  if [[ -v "_OMP_CONFIG_DATA[${key}]" ]]; then
    echo "${_OMP_CONFIG_DATA[${key}]}"
  else
    echo "${default}"
  fi
}

# omp_config_set <key> <value> [config_file]
# Set a config value and write it back to the config file.
# Creates the file if it does not exist.
omp_config_set() {
  local key="$1"
  local value="$2"
  local config_file="${3:-${OMP_CONFIG_FILE:-${OMP_HOME:-/opt/oh-my-proxmox}/config.yaml}}"

  # Update in-memory store
  _OMP_CONFIG_DATA["${key}"]="${value}"

  local config_dir
  config_dir="$(dirname "${config_file}")"
  mkdir -p "${config_dir}"

  if [[ ! -f "${config_file}" ]]; then
    echo "${key}: ${value}" > "${config_file}"
    return 0
  fi

  # Update existing file: replace line if key exists, append if not
  local temp_file
  temp_file="$(mktemp)"
  local found=false

  while IFS= read -r line; do
    if [[ "${line}" =~ ^[[:space:]]*${key}[[:space:]]*: ]]; then
      echo "${key}: ${value}" >> "${temp_file}"
      found=true
    else
      echo "${line}" >> "${temp_file}"
    fi
  done < "${config_file}"

  if [[ "${found}" == false ]]; then
    echo "${key}: ${value}" >> "${temp_file}"
  fi

  mv "${temp_file}" "${config_file}"
}
