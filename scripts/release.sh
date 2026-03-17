#!/usr/bin/env bash
# release.sh — Tag version, update CHANGELOG, create and push git tag.
# Usage: ./scripts/release.sh [VERSION]
#   VERSION: optional version string (e.g. 0.2.0). Prompts if not provided.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

log() {
  echo "[release] $*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Validate we're on main branch
current_branch="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
if [[ "${current_branch}" != "main" ]]; then
  die "Releases must be cut from main branch. Current branch: ${current_branch}"
fi

# Ensure working tree is clean (includes untracked files)
if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain --untracked-files=all)" ]]; then
  die "Working tree is dirty (uncommitted changes or untracked files). Commit or stash before releasing."
fi

# Determine version
if [[ $# -ge 1 ]]; then
  VERSION="$1"
else
  # Read latest tag and suggest next patch
  latest_tag="$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")"
  latest_ver="${latest_tag#v}"
  IFS='.' read -r major minor patch <<<"${latest_ver}"
  suggested="$((patch + 1))"
  read -rp "Version (latest: ${latest_tag}, suggestion: ${major}.${minor}.${suggested}): " VERSION
fi

# Strip leading 'v' if provided
VERSION="${VERSION#v}"
TAG="v${VERSION}"

# Validate version format
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "Version must be in X.Y.Z format, got: ${VERSION}"
fi

# Check tag doesn't already exist
if git -C "${REPO_ROOT}" rev-parse "${TAG}" &>/dev/null; then
  die "Tag ${TAG} already exists."
fi

TODAY="$(date +%Y-%m-%d)"

log "Releasing ${TAG} (${TODAY})..."

# Update CHANGELOG.md: replace [Unreleased] heading with versioned entry
if grep -q "## \[Unreleased\]" "${CHANGELOG}"; then
  # Add new versioned section after [Unreleased] block
  sed -i "s/## \[Unreleased\]/## [Unreleased]\n\n## [${VERSION}] - ${TODAY}/" "${CHANGELOG}"

  # Update comparison links at the bottom
  # Replace the Unreleased link to point from new version
  sed -i "s|^\[Unreleased\]:.*|\[Unreleased\]: https://github.com/popododo0720/oh-my-proxmox/compare/${TAG}...HEAD\n[${VERSION}]: https://github.com/popododo0720/oh-my-proxmox/releases/tag/${TAG}|" "${CHANGELOG}"

  log "Updated CHANGELOG.md"
else
  log "WARNING: [Unreleased] section not found in CHANGELOG.md — skipping changelog update."
fi

# Commit CHANGELOG update
git -C "${REPO_ROOT}" add "${CHANGELOG}"
git -C "${REPO_ROOT}" commit -m "chore(release): prepare ${TAG}

Co-Authored-By: Paperclip <noreply@paperclip.ing>"

# Create annotated tag
git -C "${REPO_ROOT}" tag -a "${TAG}" -m "Release ${TAG}"

log "Created tag ${TAG}"

# Push commit and tag
log "Pushing to origin..."
git -C "${REPO_ROOT}" push origin main
git -C "${REPO_ROOT}" push origin "${TAG}"

log "Released ${TAG} successfully."
log "GitHub Actions will create the GitHub Release automatically."
