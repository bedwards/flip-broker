#!/bin/bash
# Check status of all workers
# Usage: ./status.sh [list|ready|active|cleanup]

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
STATUS_DIR="${REPO_ROOT}/.claude/status"
WORKTREE_BASE="${REPO_ROOT}-worktrees"

mkdir -p "$STATUS_DIR"

case "${1:-list}" in
    list)
        echo "Worker Status"
        echo "============="

        if [ -z "$(ls -A "$STATUS_DIR" 2>/dev/null)" ]; then
            echo "No active workers"
            exit 0
        fi

        for status_file in "$STATUS_DIR"/*.json; do
            [ -f "$status_file" ] || continue

            issue=$(jq -r '.issue' "$status_file")
            title=$(jq -r '.title' "$status_file" | head -c 50)
            status=$(jq -r '.status' "$status_file")
            pr=$(jq -r '.pr // "none"' "$status_file")

            # Check for actual PR
            if [ "$pr" = "none" ] || [ "$pr" = "null" ]; then
                actual_pr=$(gh pr list --head "feature/GH-${issue}" --json number -q '.[0].number' 2>/dev/null || echo "")
                if [ -n "$actual_pr" ]; then
                    pr=$actual_pr
                    # Update status file
                    jq --arg pr "$pr" '.pr = $pr | .status = "pr_created"' "$status_file" > "${status_file}.tmp" && mv "${status_file}.tmp" "$status_file"
                    status="pr_created"
                fi
            fi

            # Check PR status if exists
            if [ "$pr" != "none" ] && [ "$pr" != "null" ] && [ -n "$pr" ]; then
                pr_state=$(gh pr view "$pr" --json state,mergeable -q '.state + "/" + (.mergeable // "unknown")' 2>/dev/null || echo "unknown")
                echo "GH-${issue}: ${status} | PR #${pr} (${pr_state}) | ${title}..."
            else
                echo "GH-${issue}: ${status} | No PR | ${title}..."
            fi
        done
        ;;

    ready)
        echo "PRs Ready to Merge"
        echo "=================="

        gh pr list --json number,title,headRefName,reviewDecision,mergeable \
            --jq '.[] | select(.mergeable == "MERGEABLE") | "#\(.number): \(.title) [\(.headRefName)]"'
        ;;

    active)
        echo "Active Worktrees"
        echo "================"
        git worktree list
        ;;

    cleanup)
        echo "Cleaning up merged branches..."

        for status_file in "$STATUS_DIR"/*.json; do
            [ -f "$status_file" ] || continue

            issue=$(jq -r '.issue' "$status_file")
            branch="feature/GH-${issue}"
            worktree="${WORKTREE_BASE}/GH-${issue}"

            # Check if PR is merged
            pr=$(gh pr list --head "$branch" --state merged --json number -q '.[0].number' 2>/dev/null || echo "")

            if [ -n "$pr" ]; then
                echo "Cleaning GH-${issue} (PR #${pr} merged)..."

                # Remove worktree
                if [ -d "$worktree" ]; then
                    git worktree remove "$worktree" --force 2>/dev/null || true
                fi

                # Delete branch
                git branch -D "$branch" 2>/dev/null || true
                git push origin --delete "$branch" 2>/dev/null || true

                # Remove status file
                rm "$status_file"

                echo "  Cleaned up!"
            fi
        done
        ;;

    *)
        echo "Usage: $0 [list|ready|active|cleanup]"
        echo ""
        echo "Commands:"
        echo "  list    - Show all worker statuses (default)"
        echo "  ready   - Show PRs ready to merge"
        echo "  active  - Show active worktrees"
        echo "  cleanup - Remove merged branches and worktrees"
        ;;
esac
