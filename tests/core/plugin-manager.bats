#!/usr/bin/env bats
# tests/core/plugin-manager.bats — Tests for core/plugin-manager.sh

load '../test_helper/common-setup'

setup() {
  common_setup
}

# ── omp_plugin_validate ───────────────────────────────────────────────────────

@test "omp_plugin_validate: succeeds for a valid plugin" {
  create_test_plugin "test-plugin"
  run omp_plugin_validate "test-plugin"
  assert_success
}

@test "omp_plugin_validate: fails when plugin directory does not exist" {
  run omp_plugin_validate "nonexistent-plugin"
  assert_failure
}

@test "omp_plugin_validate: fails when install.sh is missing" {
  create_test_plugin "incomplete-plugin"
  rm "${OMP_HOME}/plugins/incomplete-plugin/install.sh"
  run omp_plugin_validate "incomplete-plugin"
  assert_failure
}

@test "omp_plugin_validate: fails when uninstall.sh is missing" {
  create_test_plugin "no-uninstall"
  rm "${OMP_HOME}/plugins/no-uninstall/uninstall.sh"
  run omp_plugin_validate "no-uninstall"
  assert_failure
}

@test "omp_plugin_validate: fails when plugin.yaml is missing" {
  create_test_plugin "no-yaml"
  rm "${OMP_HOME}/plugins/no-yaml/plugin.yaml"
  run omp_plugin_validate "no-yaml"
  assert_failure
}

@test "omp_plugin_validate: fails when README.md is missing" {
  create_test_plugin "no-readme"
  rm "${OMP_HOME}/plugins/no-readme/README.md"
  run omp_plugin_validate "no-readme"
  assert_failure
}

@test "omp_plugin_validate: fails when plugin.yaml is missing required fields" {
  create_test_plugin "bad-yaml"
  # Write a plugin.yaml missing 'min_proxmox'
  cat > "${OMP_HOME}/plugins/bad-yaml/plugin.yaml" <<'EOF'
name: bad-yaml
version: 0.1.0
description: "Missing required fields"
EOF
  run omp_plugin_validate "bad-yaml"
  assert_failure
}

# ── omp_plugin_list ───────────────────────────────────────────────────────────

@test "omp_plugin_list: succeeds with empty plugins dir" {
  run omp_plugin_list
  assert_success
}

@test "omp_plugin_list: shows plugin as disabled by default" {
  create_test_plugin "my-plugin"
  run omp_plugin_list
  assert_success
  assert_output --partial "my-plugin"
  assert_output --partial "disabled"
}

@test "omp_plugin_list: shows plugin as enabled when in config" {
  create_test_plugin "enabled-plugin"
  omp_config_set "enabled_plugins" "enabled-plugin"
  omp_config_load
  run omp_plugin_list
  assert_success
  assert_output --partial "enabled-plugin"
  assert_output --partial "enabled"
}

@test "omp_plugin_list: warns when plugins directory does not exist" {
  rm -rf "${OMP_HOME}/plugins"
  run omp_plugin_list
  assert_success
  assert_output --partial "not found"
}

# ── omp_plugin_enable ─────────────────────────────────────────────────────────

@test "omp_plugin_enable: enables a valid plugin" {
  create_test_plugin "enable-me"
  run omp_plugin_enable "enable-me"
  assert_success
}

@test "omp_plugin_enable: runs install.sh when enabling" {
  create_test_plugin "install-test"
  omp_plugin_enable "install-test"
  assert [ -f "${OMP_HOME}/plugins/install-test/.installed" ]
}

@test "omp_plugin_enable: adds plugin to config enabled_plugins" {
  create_test_plugin "config-test"
  omp_plugin_enable "config-test"
  omp_config_load
  run omp_config_get "enabled_plugins"
  assert_output --partial "config-test"
}

@test "omp_plugin_enable: warns when plugin already enabled" {
  create_test_plugin "already-on"
  omp_plugin_enable "already-on"
  run omp_plugin_enable "already-on"
  assert_success
  assert_output --partial "already enabled"
}

@test "omp_plugin_enable: fails for nonexistent plugin" {
  run omp_plugin_enable "ghost-plugin"
  assert_failure
}

# ── omp_plugin_disable ────────────────────────────────────────────────────────

@test "omp_plugin_disable: disables an enabled plugin" {
  create_test_plugin "disable-me"
  omp_plugin_enable "disable-me"
  run omp_plugin_disable "disable-me"
  assert_success
}

@test "omp_plugin_disable: runs uninstall.sh when disabling" {
  create_test_plugin "uninstall-test"
  omp_plugin_enable "uninstall-test"
  omp_plugin_disable "uninstall-test"
  assert [ ! -f "${OMP_HOME}/plugins/uninstall-test/.installed" ]
}

@test "omp_plugin_disable: removes plugin from config enabled_plugins" {
  create_test_plugin "remove-from-config"
  omp_plugin_enable "remove-from-config"
  omp_plugin_disable "remove-from-config"
  omp_config_load
  run omp_config_get "enabled_plugins"
  refute_output --partial "remove-from-config"
}

@test "omp_plugin_disable: warns when plugin is not enabled" {
  create_test_plugin "not-enabled"
  run omp_plugin_disable "not-enabled"
  assert_success
  assert_output --partial "not enabled"
}

@test "omp_plugin_disable: fails for nonexistent plugin directory" {
  run omp_plugin_disable "phantom-plugin"
  assert_failure
}

# ── omp_plugin_install_all ────────────────────────────────────────────────────

@test "omp_plugin_install_all: succeeds with no enabled plugins" {
  run omp_plugin_install_all
  assert_success
}

@test "omp_plugin_install_all: runs install.sh for each enabled plugin" {
  create_test_plugin "plugin-a"
  create_test_plugin "plugin-b"
  omp_config_set "enabled_plugins" "plugin-a plugin-b"
  omp_config_load
  omp_plugin_install_all
  assert [ -f "${OMP_HOME}/plugins/plugin-a/.installed" ]
  assert [ -f "${OMP_HOME}/plugins/plugin-b/.installed" ]
}

@test "omp_plugin_install_all: skips missing plugin dirs with warning" {
  omp_config_set "enabled_plugins" "missing-plugin"
  omp_config_load
  run omp_plugin_install_all
  assert_success
  assert_output --partial "not found"
}
