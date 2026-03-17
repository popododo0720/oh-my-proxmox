#!/usr/bin/env bash
# tests/test_helper/common-setup.bash — Shared bats test setup for oh-my-proxmox
# Load this in every test file via: load 'test_helper/common-setup'

# Get the root of the repository (two levels up from test_helper/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Load bats-support and bats-assert
load "${REPO_ROOT}/tests/test_helper/bats-support/load.bash"
load "${REPO_ROOT}/tests/test_helper/bats-assert/load.bash"

# Setup isolated temp directories for each test
setup_test_dirs() {
  export OMP_HOME="${BATS_TEST_TMPDIR}/omp"
  export OMP_BACKUP_DIR="${BATS_TEST_TMPDIR}/backups"
  export OMP_CONFIG_FILE="${BATS_TEST_TMPDIR}/config.yaml"

  mkdir -p "${OMP_HOME}/plugins"
  mkdir -p "${OMP_BACKUP_DIR}"
}

# Prepend mocks directory to PATH so stub commands override real ones
setup_mocks() {
  export PATH="${REPO_ROOT}/tests/test_helper/mocks:${PATH}"
}

# Common setup: call both setup_test_dirs and setup_mocks
# Test files can call this in their setup() function
common_setup() {
  setup_test_dirs
  setup_mocks

  # Source core modules with test environment
  # shellcheck source=../../core/utils.sh
  source "${REPO_ROOT}/core/utils.sh"
  # shellcheck source=../../core/config.sh
  source "${REPO_ROOT}/core/config.sh"
  # shellcheck source=../../core/plugin-manager.sh
  source "${REPO_ROOT}/core/plugin-manager.sh"
}

# Create a minimal test plugin in $OMP_HOME/plugins/<name>
create_test_plugin() {
  local plugin_name="$1"
  local plugin_dir="${OMP_HOME}/plugins/${plugin_name}"

  mkdir -p "${plugin_dir}"

  cat > "${plugin_dir}/plugin.yaml" <<EOF
name: ${plugin_name}
version: 0.1.0
description: "Test plugin for ${plugin_name}"
author: test
min_proxmox: "8.0"
max_proxmox: "9.99"
dependencies: []
EOF

  cat > "${plugin_dir}/install.sh" <<'EOF'
#!/usr/bin/env bash
# Test plugin install.sh — marks installation with a flag file
PLUGIN_DIR="$(dirname "${BASH_SOURCE[0]}")"
touch "${PLUGIN_DIR}/.installed"
exit 0
EOF
  chmod +x "${plugin_dir}/install.sh"

  cat > "${plugin_dir}/uninstall.sh" <<'EOF'
#!/usr/bin/env bash
# Test plugin uninstall.sh — removes installation flag file
PLUGIN_DIR="$(dirname "${BASH_SOURCE[0]}")"
rm -f "${PLUGIN_DIR}/.installed"
exit 0
EOF
  chmod +x "${plugin_dir}/uninstall.sh"

  cat > "${plugin_dir}/README.md" <<EOF
# ${plugin_name}

Test plugin for unit testing.
EOF
}
