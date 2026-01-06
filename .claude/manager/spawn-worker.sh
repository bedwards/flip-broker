#!/bin/bash
# Spawn a Claude Code worker for a GitHub issue
# Usage: ./spawn-worker.sh <issue-number>

set -e

ISSUE_NUM=$1
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
WORKTREE_BASE="${REPO_ROOT}-worktrees"

if [ -z "$ISSUE_NUM" ]; then
    echo "Usage: $0 <issue-number>"
    echo "Example: $0 5"
    exit 1
fi

BRANCH_NAME="feature/GH-${ISSUE_NUM}"
WORKTREE_PATH="${WORKTREE_BASE}/GH-${ISSUE_NUM}"

# Fetch latest from origin
echo "Fetching latest from origin..."
git fetch origin main

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
    echo "Worktree already exists at $WORKTREE_PATH"
    echo "To remove: git worktree remove $WORKTREE_PATH"
    exit 1
fi

# Create worktrees directory if needed
mkdir -p "$WORKTREE_BASE"

# Create new worktree with feature branch
echo "Creating worktree at $WORKTREE_PATH..."
git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" origin/main

# Get issue details
ISSUE_TITLE=$(gh issue view "$ISSUE_NUM" --json title -q '.title' 2>/dev/null || echo "Issue #$ISSUE_NUM")
ISSUE_BODY=$(gh issue view "$ISSUE_NUM" --json body -q '.body' 2>/dev/null || echo "")

# Create status file
STATUS_DIR="${REPO_ROOT}/.claude/status"
mkdir -p "$STATUS_DIR"
cat > "${STATUS_DIR}/GH-${ISSUE_NUM}.json" << EOF
{
  "issue": $ISSUE_NUM,
  "title": "$ISSUE_TITLE",
  "branch": "$BRANCH_NAME",
  "worktree": "$WORKTREE_PATH",
  "status": "spawned",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pr": null
}
EOF

echo ""
echo "Worker environment ready!"
echo "========================="
echo "Issue:    #$ISSUE_NUM - $ISSUE_TITLE"
echo "Branch:   $BRANCH_NAME"
echo "Worktree: $WORKTREE_PATH"
echo ""
echo "To start worker:"
echo "  cd $WORKTREE_PATH"
echo "  claude -p \"Implement GitHub issue #$ISSUE_NUM. Read the issue with 'gh issue view $ISSUE_NUM'. When done, create a PR with 'gh pr create'.\""
echo ""
echo "Or run headless:"
echo "  cd $WORKTREE_PATH && claude --dangerously-skip-permissions -p \"...\""
