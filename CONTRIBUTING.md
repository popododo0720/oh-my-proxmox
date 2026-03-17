# Contributing to oh-my-proxmox

Thank you for contributing to oh-my-proxmox! This guide covers everything you need to get started.

---

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone --recurse-submodules https://github.com/YOUR_USERNAME/oh-my-proxmox.git
   cd oh-my-proxmox
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/popododo0720/oh-my-proxmox.git
   ```
4. Create a feature branch:
   ```bash
   git checkout develop
   git checkout -b feature/my-feature
   ```

---

## Development Setup

### Prerequisites

- Bash 5.0+
- Git
- `make`
- `shellcheck`

Install dev dependencies (shellcheck + bats-core submodules):

```bash
make deps
```

Or manually:

```bash
sudo apt-get install -y shellcheck make
git submodule update --init --recursive
```

### Available Make targets

```
make lint       # Run ShellCheck on all .sh files
make test       # Run bats-core test suite
make install    # Install oh-my-proxmox locally to /opt/oh-my-proxmox
make uninstall  # Remove oh-my-proxmox
make release    # Tag version, update CHANGELOG, push tag
make clean      # Remove test artifacts
```

---

## Plugin Development Guide

### Overview

Plugins are self-contained directories under `plugins/`. Each plugin must be idempotent, back up any files it modifies, and support uninstallation.

### Plugin Interface Contract

Every plugin directory **MUST** contain these four files:

| File | Purpose | Required |
|------|---------|----------|
| `install.sh` | Apply the plugin's changes to the system | Yes |
| `uninstall.sh` | Revert the plugin's changes (rollback) | Yes |
| `plugin.yaml` | Plugin metadata | Yes |
| `README.md` | Plugin-specific documentation | Yes |

### `plugin.yaml` schema

```yaml
name: my-plugin              # Must match directory name
version: 0.1.0               # Semantic version
description: "Short description of what this plugin does"
author: your-name
min_proxmox: "8.0"           # Minimum compatible Proxmox VE version
max_proxmox: "9.99"          # Maximum compatible version
dependencies: []             # Plugins must be independent — always []
```

### `install.sh` contract

- **MUST** be idempotent (safe to run multiple times with the same result)
- **MUST** source `../../core/utils.sh` for logging and assertions
- **MUST** back up any modified files to `$OMP_BACKUP_DIR/<plugin-name>/` before changes
- **MUST** use `omp_require_root` if root is needed
- **MUST** use `omp_require_proxmox` if Proxmox-specific commands are used
- **MUST** exit 0 on success, non-zero on failure
- **MUST NOT** depend on other plugins
- **MUST** use `omp_log`, `omp_warn`, `omp_error` for all output

```bash
#!/usr/bin/env bash
# plugins/my-plugin/install.sh
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../core/utils.sh
source "${PLUGIN_DIR}/../../core/utils.sh"

omp_require_root
omp_require_proxmox

TARGET_FILE="/etc/some/config"

# Idempotency check
if grep -q "already-applied-marker" "${TARGET_FILE}" 2>/dev/null; then
  omp_log "my-plugin: already applied, skipping"
  exit 0
fi

# Backup before modifying
omp_backup_file "${TARGET_FILE}"

# Make changes
echo "# oh-my-proxmox: my-plugin marker" >> "${TARGET_FILE}"
echo "my-setting=value" >> "${TARGET_FILE}"

omp_log "my-plugin: installed successfully"
```

### `uninstall.sh` contract

- **MUST** restore modified files from `$OMP_BACKUP_DIR/<plugin-name>/`
- **MUST** be idempotent
- **MUST** exit 0 on success, non-zero on failure

```bash
#!/usr/bin/env bash
# plugins/my-plugin/uninstall.sh
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../core/utils.sh
source "${PLUGIN_DIR}/../../core/utils.sh"

omp_require_root

TARGET_FILE="/etc/some/config"

# Restore from backup
omp_restore_file "${TARGET_FILE}"

omp_log "my-plugin: uninstalled successfully"
```

### `README.md` structure

```markdown
# my-plugin

Brief description of what this plugin does.

## What it does

- Item 1
- Item 2

## Compatibility

- Proxmox VE 8.0+

## Backup

Files modified: `/etc/some/config`

## Reverting

Run `omp plugin disable my-plugin` to restore all backed-up files.
```

### Available core utilities (`core/utils.sh`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `omp_log` | `omp_log <message>` | Info log with timestamp (cyan) |
| `omp_warn` | `omp_warn <message>` | Warning log (yellow, to stderr) |
| `omp_error` | `omp_error <message> [exit_code]` | Error log (red, to stderr); exits if exit_code given |
| `omp_backup_file` | `omp_backup_file <path>` | Copy file to `$OMP_BACKUP_DIR` preserving path |
| `omp_restore_file` | `omp_restore_file <path>` | Restore file from `$OMP_BACKUP_DIR` |
| `omp_require_root` | `omp_require_root` | Assert root; exits 1 if not |
| `omp_require_proxmox` | `omp_require_proxmox` | Assert Proxmox VE; exits 1 if not |

---

## Coding Standards

- All scripts must use `#!/usr/bin/env bash` shebang
- Use `set -euo pipefail` in scripts that are run as entry points (not sourced as libraries)
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- All functions must use the `omp_` prefix
- No tabs — use 2-space indentation
- `shellcheck --severity=warning` must pass before PR
- Keep functions small and focused
- Use `local` for all function-scoped variables

---

## Testing

Tests use [bats-core](https://bats-core.readthedocs.io/) (vendored as git submodule).

### Running tests

```bash
make test
# or
./tests/bats/bin/bats tests/
```

### Writing tests

1. Create a `.bats` file in `tests/core/` (for core module tests) or `tests/plugins/` (for plugin tests)
2. Load the shared helper at the top:
   ```bash
   load '../test_helper/common-setup'
   setup() { common_setup; }
   ```
3. Use `create_test_plugin <name>` to scaffold a minimal plugin for testing
4. Every function must have at least 2 test cases (happy path + at least one edge case)
5. Tests must not modify the real filesystem — all paths must use `$BATS_TEST_TMPDIR`

### Mock commands

`tests/test_helper/mocks/` provides stub scripts configurable via environment variables:

| Mock | Env vars | Default behavior |
|------|----------|------------------|
| `pveversion` | `MOCK_PVEVERSION_EXIT`, `MOCK_PVEVERSION_OUTPUT` | Exit 0, print PVE version string |
| `apt` | `MOCK_APT_EXIT`, `MOCK_APT_OUTPUT` | Exit 0 |
| `apt-get` | `MOCK_APTGET_EXIT`, `MOCK_APTGET_OUTPUT` | Exit 0 |
| `systemctl` | `MOCK_SYSTEMCTL_EXIT`, `MOCK_SYSTEMCTL_OUTPUT` | Exit 0 |
| `dpkg` | `MOCK_DPKG_EXIT`, `MOCK_DPKG_OUTPUT` | Exit 0 |

Example — test failure path:

```bash
@test "plugin fails when apt returns error" {
  export MOCK_APT_EXIT=1
  run omp_plugin_enable "base-packages"
  assert_failure
}
```

---

## PR Process

1. Create a feature branch from `develop`: `git checkout -b feature/my-feature develop`
2. Make your changes following the coding standards above
3. Ensure `make lint` and `make test` pass locally
4. Write tests for new functionality (every function, at least 2 cases)
5. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:
   - `feat:` new feature
   - `fix:` bug fix
   - `docs:` documentation only
   - `chore:` maintenance/tooling
   - `test:` adding or updating tests
6. Submit a PR to `develop` — a Code Reviewer will review and approve
7. PRs to `main` require lint + test + manual approval

---

## Release Process

Releases are created by merging `develop` → `main` and pushing a version tag:

```bash
make release
```

This runs `scripts/release.sh` which:
1. Validates you're on `main`
2. Bumps version in `VERSION` file
3. Updates `CHANGELOG.md`
4. Creates a git tag (`v0.1.0`)
5. Pushes tag → triggers `release.yml` GitHub Action

Semantic versioning: `v<major>.<minor>.<patch>`
