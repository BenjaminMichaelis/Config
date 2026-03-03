#!/usr/bin/env bash
# Installs the global git commit-msg hook on macOS / Linux.
# Configures git to use ~/.config/git/hooks as the global hooks directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks"

mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/commit-msg" "$HOOKS_DIR/commit-msg"
chmod +x "$HOOKS_DIR/commit-msg"

git config --global core.hooksPath "$HOOKS_DIR"

echo "Installed commit-msg hook → $HOOKS_DIR/commit-msg"
echo "Global git hooks path set to: $HOOKS_DIR"
