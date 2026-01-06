#!/bin/bash
# Merge a PR for a completed issue
# Usage: ./merge-pr.sh <issue-number>

set -e

ISSUE_NUM=$1
REPO_ROOT=$(git rev-parse --show-toplevel)
STATUS_DIR="${REPO_ROOT}/.claude/status"
WORKTREE_BASE="${REPO_ROOT}-worktrees"

if [ -z "$ISSUE_NUM" ]; then
    echo "Usage: $0 <issue-number>"
    echo "Example: $0 5"
    exit 1
fi

BRANCH_NAME="feature/GH-${ISSUE_NUM}"

# Find the PR
PR_NUM=$(gh pr list --head "$BRANCH_NAME" --json number -q '.[0].number' 2>/dev/null || echo "")

if [ -z "$PR_NUM" ]; then
    echo "No PR found for branch $BRANCH_NAME"
    exit 1
fi

echo "Found PR #${PR_NUM} for issue #${ISSUE_NUM}"

# Check PR status
PR_STATUS=$(gh pr view "$PR_NUM" --json state,mergeable,reviewDecision -q '"\(.state)|\(.mergeable)|\(.reviewDecision)"')
echo "Status: $PR_STATUS"

# Check if mergeable
MERGEABLE=$(echo "$PR_STATUS" | cut -d'|' -f2)
if [ "$MERGEABLE" != "MERGEABLE" ]; then
    echo ""
    echo "PR is not mergeable. Current status: $MERGEABLE"
    echo "Run 'gh pr view $PR_NUM' for details."
    exit 1
fi

# Confirm merge
echo ""
read -p "Merge PR #${PR_NUM}? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Merge the PR
echo "Merging PR #${PR_NUM}..."
gh pr merge "$PR_NUM" --squash --delete-branch

# Update status
STATUS_FILE="${STATUS_DIR}/GH-${ISSUE_NUM}.json"
if [ -f "$STATUS_FILE" ]; then
    jq '.status = "merged" | .merged_at = now | .pr = "'"$PR_NUM"'"' "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
fi

# Clean up worktree
WORKTREE_PATH="${WORKTREE_BASE}/GH-${ISSUE_NUM}"
if [ -d "$WORKTREE_PATH" ]; then
    echo "Removing worktree..."
    git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || true
fi

echo ""
echo "Done! PR #${PR_NUM} merged and cleaned up."
