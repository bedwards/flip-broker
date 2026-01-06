#!/bin/bash
# Install git hooks for the project
# Usage: ./install-hooks.sh

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
HOOKS_SRC="${REPO_ROOT}/.claude/hooks"
HOOKS_DST="${REPO_ROOT}/.git/hooks"

echo "Installing git hooks..."

# Install pre-commit hook
if [ -f "${HOOKS_SRC}/pre-commit" ]; then
    cp "${HOOKS_SRC}/pre-commit" "${HOOKS_DST}/pre-commit"
    chmod +x "${HOOKS_DST}/pre-commit"
    echo "  Installed: pre-commit"
fi

echo ""
echo "Done! Hooks installed to ${HOOKS_DST}"
