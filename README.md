# oh-my-proxmox

[![Lint](https://github.com/popododo0720/oh-my-proxmox/actions/workflows/lint.yml/badge.svg)](https://github.com/popododo0720/oh-my-proxmox/actions/workflows/lint.yml)
[![Test](https://github.com/popododo0720/oh-my-proxmox/actions/workflows/test.yml/badge.svg)](https://github.com/popododo0720/oh-my-proxmox/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A plugin-based framework for Proxmox VE post-install automation, inspired by [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh).

---

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/popododo0720/oh-my-proxmox/main/install.sh | bash
omp plugin list
```

---

## Installation

### Remote one-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/popododo0720/oh-my-proxmox/main/install.sh | bash
```

This will:
1. Download the latest release to `/opt/oh-my-proxmox`
2. Initialize git submodules (bats-core)
3. Create a default `config.yaml`
4. Make `omp` available system-wide

### Manual installation

```bash
git clone --recurse-submodules https://github.com/popododo0720/oh-my-proxmox.git /opt/oh-my-proxmox
cd /opt/oh-my-proxmox
cp config.yaml.example config.yaml
ln -sf /opt/oh-my-proxmox/omp.sh /usr/local/bin/omp
```

### Requirements

- Proxmox VE 8.0+
- Bash 5.0+
- Git

---

## Usage

```
omp <command> [options]

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
```

**Examples:**

```bash
# List all available plugins
omp plugin list

# Diagnose issues
omp doctor

# Roll back all installed plugins
omp rollback
```

> **Note:** Plugin commands such as `omp plugin enable no-subscription` will be available once
> plugin directories are added in upcoming releases. See the [Plugin List](#plugin-list) section.

---

## Plugin List

> **Note:** Plugins are under development. The table below reflects the planned plugin set;
> individual plugin directories will be added in upcoming releases.

| Plugin | Description | Status |
|--------|-------------|--------|
| `no-subscription` | Remove enterprise subscription nag, add no-subscription repo | coming soon |
| `dark-mode` | Enable dark theme in Proxmox web UI | coming soon |
| `base-packages` | Install common system utilities (curl, vim, htop, etc.) | coming soon |
| `security` | Apply security hardening: fail2ban, SSH hardening, firewall rules | coming soon |

---

## Plugin Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full plugin development guide.

### Quick overview

Each plugin is a directory under `plugins/` with four required files:

```
plugins/
└── my-plugin/
    ├── plugin.yaml     # Metadata (name, version, description, author, min_proxmox)
    ├── install.sh      # Apply changes (idempotent, backs up files)
    ├── uninstall.sh    # Revert changes (restores from backup)
    └── README.md       # Plugin-specific documentation
```

Minimal `plugin.yaml`:

```yaml
name: my-plugin
version: 0.1.0
description: "What this plugin does"
author: your-name
min_proxmox: "8.0"
max_proxmox: "9.99"
dependencies: []
```

Minimal `install.sh`:

```bash
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../core/utils.sh"
omp_require_root
omp_require_proxmox

# Backup before modifying
omp_backup_file "/etc/some/config"

# Make your changes (idempotent)
echo "my change" >> /etc/some/config

omp_log "my-plugin installed successfully"
```

---

## Configuration

Configuration is stored in `$OMP_HOME/config.yaml` (default: `/opt/oh-my-proxmox/config.yaml`).

```yaml
# Enabled plugins (space-separated list)
enabled_plugins: no-subscription dark-mode
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `OMP_HOME` | `/opt/oh-my-proxmox` | Installation directory |
| `OMP_BACKUP_DIR` | `/var/lib/oh-my-proxmox/backups` | Backup directory |
| `OMP_CONFIG_FILE` | `$OMP_HOME/config.yaml` | Config file path |

---

## Troubleshooting

**`omp doctor`** — run diagnostics to check Proxmox version, network, disk space, and config.

**Common issues:**

| Issue | Solution |
|-------|----------|
| `pveversion not found` | Must run on Proxmox VE host |
| `Permission denied` | Most operations require root: `sudo omp ...` |
| `Plugin install failed` | Check plugin README; run `omp doctor`; inspect logs |
| `omp: command not found` | Add `/opt/oh-my-proxmox` to PATH or re-run install.sh |

For more help, open an issue at [github.com/popododo0720/oh-my-proxmox/issues](https://github.com/popododo0720/oh-my-proxmox/issues).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contributing guide including:

- Development setup
- Plugin development guide with interface contract
- Coding standards
- Testing
- PR process

---

## License

[MIT](LICENSE) © oh-my-proxmox contributors
