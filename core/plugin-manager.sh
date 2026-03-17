#!/usr/bin/env bash
# core/plugin-manager.sh — Plugin lifecycle management for oh-my-proxmox
# Sourceable with no side effects. Discovery via ls $OMP_HOME/plugins/.

# Guard against sourcing without utils.sh
if ! declare -f omp_log &>/dev/null; then
  # shellcheck source=core/utils.sh
  source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
fi

# Guard against sourcing without config.sh
if ! declare -f omp_config_load &>/dev/null; then
  # shellcheck source=core/config.sh
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# omp_plugin_validate <plugin_name>
# Check that a plugin directory has all required files and a valid plugin.yaml.
# Returns 0 if valid, 1 if invalid.
omp_plugin_validate() {
  local plugin_name="$1"
  local plugin_dir="${OMP_HOME:-/opt/oh-my-proxmox}/plugins/${plugin_name}"
  local valid=true

  if [[ ! -d "${plugin_dir}" ]]; then
    omp_error "Plugin directory not found: ${plugin_dir}"
    return 1
  fi

  local required_files=("install.sh" "uninstall.sh" "plugin.yaml" "README.md")
  for f in "${required_files[@]}"; do
    if [[ ! -f "${plugin_dir}/${f}" ]]; then
      omp_error "Plugin '${plugin_name}' missing required file: ${f}"
      valid=false
    fi
  done

  if [[ "${valid}" == false ]]; then
    return 1
  fi

  # Validate plugin.yaml has required fields
  local required_yaml_fields=("name" "version" "description" "author" "min_proxmox")
  for field in "${required_yaml_fields[@]}"; do
    if ! grep -q "^${field}:" "${plugin_dir}/plugin.yaml"; then
      omp_error "Plugin '${plugin_name}' plugin.yaml missing required field: ${field}"
      valid=false
    fi
  done

  [[ "${valid}" == true ]]
}

# omp_plugin_list
# List all discovered plugins with their status (enabled/disabled).
omp_plugin_list() {
  local plugins_dir="${OMP_HOME:-/opt/oh-my-proxmox}/plugins"

  if [[ ! -d "${plugins_dir}" ]]; then
    omp_warn "Plugins directory not found: ${plugins_dir}"
    return 0
  fi

  # Load config to know which plugins are enabled
  omp_config_load

  local enabled_plugins
  enabled_plugins="$(omp_config_get "enabled_plugins" "")"

  printf "%-25s %-10s %s\n" "PLUGIN" "STATUS" "DESCRIPTION"
  printf "%-25s %-10s %s\n" "------" "------" "-----------"

  local found=false
  for plugin_dir in "${plugins_dir}"/*/; do
    [[ -d "${plugin_dir}" ]] || continue
    local plugin_name
    plugin_name="$(basename "${plugin_dir}")"
    found=true

    # Determine status
    local status="disabled"
    if echo "${enabled_plugins}" | grep -qw "${plugin_name}"; then
      status="enabled"
    fi

    # Get description from plugin.yaml if available
    local description=""
    if [[ -f "${plugin_dir}/plugin.yaml" ]]; then
      description="$(grep "^description:" "${plugin_dir}/plugin.yaml" | sed 's/^description:[[:space:]]*//' | tr -d '"'"'")"
    fi

    printf "%-25s %-10s %s\n" "${plugin_name}" "${status}" "${description}"
  done

  if [[ "${found}" == false ]]; then
    echo "No plugins found in ${plugins_dir}"
  fi
}

# omp_plugin_enable <plugin_name>
# Add plugin to config and run its install.sh.
omp_plugin_enable() {
  local plugin_name="$1"
  local plugin_dir="${OMP_HOME:-/opt/oh-my-proxmox}/plugins/${plugin_name}"

  omp_log "Enabling plugin: ${plugin_name}"

  if ! omp_plugin_validate "${plugin_name}"; then
    omp_error "Plugin validation failed: ${plugin_name}" 1
  fi

  omp_config_load

  # Check if already enabled
  local enabled_plugins
  enabled_plugins="$(omp_config_get "enabled_plugins" "")"
  if echo "${enabled_plugins}" | grep -qw "${plugin_name}"; then
    omp_warn "Plugin '${plugin_name}' is already enabled"
    return 0
  fi

  # Run install.sh
  omp_log "Running install.sh for plugin: ${plugin_name}"
  if ! bash "${plugin_dir}/install.sh"; then
    omp_error "install.sh failed for plugin: ${plugin_name}" 1
  fi

  # Add to enabled_plugins list in config
  local new_enabled
  if [[ -z "${enabled_plugins}" ]]; then
    new_enabled="${plugin_name}"
  else
    new_enabled="${enabled_plugins} ${plugin_name}"
  fi
  omp_config_set "enabled_plugins" "${new_enabled}"
  omp_log "Plugin enabled: ${plugin_name}"
}

# omp_plugin_disable <plugin_name>
# Remove plugin from config and run its uninstall.sh.
omp_plugin_disable() {
  local plugin_name="$1"
  local plugin_dir="${OMP_HOME:-/opt/oh-my-proxmox}/plugins/${plugin_name}"

  omp_log "Disabling plugin: ${plugin_name}"

  if [[ ! -d "${plugin_dir}" ]]; then
    omp_error "Plugin not found: ${plugin_name}" 1
  fi

  omp_config_load

  # Check if currently enabled
  local enabled_plugins
  enabled_plugins="$(omp_config_get "enabled_plugins" "")"
  if ! echo "${enabled_plugins}" | grep -qw "${plugin_name}"; then
    omp_warn "Plugin '${plugin_name}' is not enabled"
    return 0
  fi

  # Run uninstall.sh if it exists
  if [[ -f "${plugin_dir}/uninstall.sh" ]]; then
    omp_log "Running uninstall.sh for plugin: ${plugin_name}"
    if ! bash "${plugin_dir}/uninstall.sh"; then
      omp_error "uninstall.sh failed for plugin: ${plugin_name}" 1
    fi
  fi

  # Remove from enabled_plugins list
  local new_enabled
  new_enabled="$(echo "${enabled_plugins}" | tr ' ' '\n' | grep -v "^${plugin_name}$" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  omp_config_set "enabled_plugins" "${new_enabled}"
  omp_log "Plugin disabled: ${plugin_name}"
}

# omp_plugin_install_all
# Run install.sh for all currently enabled plugins.
omp_plugin_install_all() {
  omp_log "Installing all enabled plugins..."

  omp_config_load
  local enabled_plugins
  enabled_plugins="$(omp_config_get "enabled_plugins" "")"

  if [[ -z "${enabled_plugins}" ]]; then
    omp_log "No plugins enabled. Nothing to install."
    return 0
  fi

  local success=true
  for plugin_name in ${enabled_plugins}; do
    local plugin_dir="${OMP_HOME:-/opt/oh-my-proxmox}/plugins/${plugin_name}"
    if [[ ! -d "${plugin_dir}" ]]; then
      omp_warn "Plugin directory not found, skipping: ${plugin_name}"
      continue
    fi
    omp_log "Installing plugin: ${plugin_name}"
    if ! bash "${plugin_dir}/install.sh"; then
      omp_error "install.sh failed for plugin: ${plugin_name}"
      success=false
    fi
  done

  if [[ "${success}" == true ]]; then
    omp_log "All plugins installed successfully."
  else
    omp_error "Some plugins failed to install." 1
  fi
}
