#!/bin/bash
# Batch create GitHub issues from a JSON file
# Usage: ./create-issues.sh <issues.json>
#
# JSON format:
# [
#   {"title": "Issue title", "body": "Issue body", "labels": ["label1", "label2"]},
#   ...
# ]

set -e

ISSUES_FILE=$1

if [ -z "$ISSUES_FILE" ] || [ ! -f "$ISSUES_FILE" ]; then
    echo "Usage: $0 <issues.json>"
    echo ""
    echo "JSON format:"
    echo '[{"title": "...", "body": "...", "labels": ["..."]}]'
    exit 1
fi

# Validate JSON
if ! jq empty "$ISSUES_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in $ISSUES_FILE"
    exit 1
fi

COUNT=$(jq length "$ISSUES_FILE")
echo "Creating $COUNT issues..."
echo ""

CREATED=0
FAILED=0

for i in $(seq 0 $((COUNT - 1))); do
    TITLE=$(jq -r ".[$i].title" "$ISSUES_FILE")
    BODY=$(jq -r ".[$i].body // \"\"" "$ISSUES_FILE")
    LABELS=$(jq -r ".[$i].labels // [] | join(\",\")" "$ISSUES_FILE")

    echo -n "[$((i + 1))/$COUNT] $TITLE... "

    # Build command
    CMD="gh issue create --title \"$TITLE\""
    [ -n "$BODY" ] && CMD="$CMD --body \"$BODY\""
    [ -n "$LABELS" ] && CMD="$CMD --label \"$LABELS\""

    # Create issue with rate limiting
    if RESULT=$(eval "$CMD" 2>&1); then
        ISSUE_NUM=$(echo "$RESULT" | grep -oE '[0-9]+$')
        echo "created #$ISSUE_NUM"
        CREATED=$((CREATED + 1))
    else
        echo "FAILED: $RESULT"
        FAILED=$((FAILED + 1))
    fi

    # Rate limit: 1 second between requests
    sleep 1
done

echo ""
echo "Done! Created: $CREATED, Failed: $FAILED"
