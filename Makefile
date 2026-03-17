SHELL := /bin/bash
SHELLCHECK_FLAGS := --severity=warning --shell=bash
BATS := ./tests/bats/bin/bats
SRC_FILES := $(shell find . \( -name '*.sh' -o -name '*.bash' \) \
  -not -path './.git/*' \
  -not -path './tests/bats/*' \
  -not -path './tests/test_helper/bats-support/*' \
  -not -path './tests/test_helper/bats-assert/*')
TEST_FILES := $(shell find tests/core tests/plugins -name '*.bats' 2>/dev/null)

.PHONY: lint test install uninstall release clean deps

deps:  ## Install dev dependencies (shellcheck, bats-core submodules)
	@./scripts/install-dev-deps.sh

lint:  ## Run ShellCheck on all .sh files
	shellcheck $(SHELLCHECK_FLAGS) $(SRC_FILES)

test: deps  ## Run bats-core test suite
	$(BATS) $(TEST_FILES)

install:  ## Install oh-my-proxmox to /opt/oh-my-proxmox
	@./install.sh --local

uninstall:  ## Remove oh-my-proxmox
	@rm -rf /opt/oh-my-proxmox

release:  ## Tag version, update CHANGELOG, push tag
	@./scripts/release.sh

clean:  ## Remove test artifacts
	@rm -rf tests/tmp tests/.bats-*
