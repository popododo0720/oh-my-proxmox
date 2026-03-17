#!/usr/bin/env bats
# tests/core/utils.bats — Tests for core/utils.sh

load '../test_helper/common-setup'

setup() {
  common_setup
}

# ── omp_log ──────────────────────────────────────────────────────────────────

@test "omp_log: outputs message to stdout" {
  run omp_log "test message"
  assert_success
  assert_output --partial "test message"
}

@test "omp_log: output contains [INFO] tag" {
  run omp_log "hello world"
  assert_success
  assert_output --partial "[INFO]"
}

@test "omp_log: output contains a timestamp" {
  run omp_log "ts test"
  assert_success
  # Timestamp format: YYYY-MM-DD HH:MM:SS
  assert_output --regexp "^.*[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.*"
}

# ── omp_warn ─────────────────────────────────────────────────────────────────

@test "omp_warn: outputs message to stderr" {
  run omp_warn "test warning"
  assert_success
  assert_output --partial "test warning"
}

@test "omp_warn: output contains [WARN] tag" {
  run omp_warn "some warning"
  assert_success
  assert_output --partial "[WARN]"
}

# ── omp_error ────────────────────────────────────────────────────────────────

@test "omp_error: outputs message to stderr" {
  run omp_error "test error"
  assert_success
  assert_output --partial "test error"
}

@test "omp_error: output contains [ERROR] tag" {
  run omp_error "an error"
  assert_success
  assert_output --partial "[ERROR]"
}

@test "omp_error: exits with given exit code when provided" {
  run omp_error "fatal error" 42
  assert_failure 42
}

@test "omp_error: does not exit when no exit code given" {
  run omp_error "non-fatal error"
  assert_success
}

# ── omp_backup_file ───────────────────────────────────────────────────────────

@test "omp_backup_file: backs up an existing file" {
  local test_file="${BATS_TEST_TMPDIR}/testfile.conf"
  echo "original content" > "${test_file}"

  run omp_backup_file "${test_file}"
  assert_success
  assert [ -f "${OMP_BACKUP_DIR}${test_file}" ]
}

@test "omp_backup_file: backup preserves file content" {
  local test_file="${BATS_TEST_TMPDIR}/preserve.conf"
  echo "preserve me" > "${test_file}"

  omp_backup_file "${test_file}"
  run cat "${OMP_BACKUP_DIR}${test_file}"
  assert_output "preserve me"
}

@test "omp_backup_file: warns when file does not exist" {
  run omp_backup_file "/nonexistent/path/file.conf"
  assert_success
  assert_output --partial "Cannot backup"
}

# ── omp_restore_file ──────────────────────────────────────────────────────────

@test "omp_restore_file: restores a backed up file" {
  local test_file="${BATS_TEST_TMPDIR}/restore.conf"
  echo "restore me" > "${test_file}"
  omp_backup_file "${test_file}"

  rm "${test_file}"
  run omp_restore_file "${test_file}"
  assert_success
  assert [ -f "${test_file}" ]
}

@test "omp_restore_file: restored file has original content" {
  local test_file="${BATS_TEST_TMPDIR}/content.conf"
  echo "original data" > "${test_file}"
  omp_backup_file "${test_file}"

  rm "${test_file}"
  omp_restore_file "${test_file}"
  run cat "${test_file}"
  assert_output "original data"
}

@test "omp_restore_file: fails when backup does not exist" {
  run omp_restore_file "/no/backup/here.conf"
  assert_failure
}

# ── omp_require_root ──────────────────────────────────────────────────────────

@test "omp_require_root: exits non-zero when not root" {
  # Tests always run as non-root in CI
  if [[ "${EUID}" -eq 0 ]]; then
    skip "Running as root — cannot test non-root path"
  fi
  run omp_require_root
  assert_failure
}

# ── omp_require_proxmox ───────────────────────────────────────────────────────

@test "omp_require_proxmox: succeeds when pveversion is available" {
  # Mock pveversion is on PATH via common_setup
  run omp_require_proxmox
  assert_success
}

@test "omp_require_proxmox: fails when pveversion is not found" {
  # Run in a subshell with a clean PATH that has no pveversion
  local clean_dir="${BATS_TEST_TMPDIR}/clean_path"
  mkdir -p "${clean_dir}"
  run bash -c "export PATH='${clean_dir}'; source '${REPO_ROOT}/core/utils.sh'; omp_require_proxmox"
  assert_failure
}
