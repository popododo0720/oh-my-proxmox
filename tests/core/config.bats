#!/usr/bin/env bats
# tests/core/config.bats — Tests for core/config.sh

load '../test_helper/common-setup'

setup() {
  common_setup
}

# ── omp_config_load ──────────────────────────────────────────────────────────

@test "omp_config_load: succeeds when config file does not exist" {
  export OMP_CONFIG_FILE="${BATS_TEST_TMPDIR}/nonexistent.yaml"
  run omp_config_load
  assert_success
}

@test "omp_config_load: parses simple key: value pairs" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
enabled_plugins: no-subscription dark-mode
version: 0.1.0
EOF
  omp_config_load
  run omp_config_get "enabled_plugins"
  assert_output "no-subscription dark-mode"
}

@test "omp_config_load: parses quoted string values" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
description: "a quoted value"
EOF
  omp_config_load
  run omp_config_get "description"
  assert_output "a quoted value"
}

@test "omp_config_load: ignores comment lines" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
# This is a comment
enabled_plugins: no-subscription
# Another comment
EOF
  omp_config_load
  run omp_config_get "enabled_plugins"
  assert_output "no-subscription"
}

@test "omp_config_load: ignores blank lines" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'

enabled_plugins: test-plugin

version: 1.0

EOF
  omp_config_load
  run omp_config_get "enabled_plugins"
  assert_output "test-plugin"
}

@test "omp_config_load: parses list items under a key" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
plugins:
  - no-subscription
  - dark-mode
EOF
  omp_config_load
  run omp_config_get "plugins.0"
  assert_output "no-subscription"
}

# ── omp_config_get ────────────────────────────────────────────────────────────

@test "omp_config_get: returns value for existing key" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
my_key: my_value
EOF
  omp_config_load
  run omp_config_get "my_key"
  assert_output "my_value"
}

@test "omp_config_get: returns default for missing key" {
  omp_config_load
  run omp_config_get "missing_key" "default_value"
  assert_output "default_value"
}

@test "omp_config_get: returns empty string when key missing and no default" {
  omp_config_load
  run omp_config_get "absent_key"
  assert_output ""
}

@test "omp_config_get: returns correct value after multiple loads" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
key1: value1
key2: value2
EOF
  omp_config_load
  run omp_config_get "key2"
  assert_output "value2"
}

# ── omp_config_set ────────────────────────────────────────────────────────────

@test "omp_config_set: creates config file if it does not exist" {
  export OMP_CONFIG_FILE="${BATS_TEST_TMPDIR}/new-config.yaml"
  run omp_config_set "test_key" "test_value"
  assert_success
  assert [ -f "${OMP_CONFIG_FILE}" ]
}

@test "omp_config_set: written value is readable by omp_config_get" {
  omp_config_set "written_key" "written_value"
  omp_config_load
  run omp_config_get "written_key"
  assert_output "written_value"
}

@test "omp_config_set: updates existing key in config file" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
existing_key: old_value
other_key: keep_me
EOF
  omp_config_set "existing_key" "new_value"
  omp_config_load
  run omp_config_get "existing_key"
  assert_output "new_value"
}

@test "omp_config_set: preserves other keys when updating" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
key_a: value_a
key_b: value_b
EOF
  omp_config_set "key_a" "updated_a"
  omp_config_load
  run omp_config_get "key_b"
  assert_output "value_b"
}

@test "omp_config_set: appends new key to existing config file" {
  cat > "${OMP_CONFIG_FILE}" <<'EOF'
existing_key: existing_value
EOF
  omp_config_set "new_key" "new_value"
  omp_config_load
  run omp_config_get "new_key"
  assert_output "new_value"
}
