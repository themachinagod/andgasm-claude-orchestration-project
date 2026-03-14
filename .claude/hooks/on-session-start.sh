#!/bin/bash
# SessionStart hook — Orient the agent at workspace level.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Generate a unique session ID for this Claude instance.
# Format: interactive-YYYYMMDDTHHMMSS-PID
# This ID is used for issue claiming, STATUS.md tracking, and
# distinguishing concurrent sessions. Every Claude instance gets one.
SESSION_ID="interactive-$(date '+%Y%m%dT%H%M%S')-$$"

# Persist session ID as env var available to all subsequent Bash calls.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export CLAUDE_SESSION_ID=\"$SESSION_ID\"" >> "$CLAUDE_ENV_FILE"
fi

echo "=== SESSION START: Workspace Orientation ==="
echo "Session ID: $SESSION_ID"
echo ""

cd "$WORKSPACE_ROOT"

# Find docs repo (look for repos.yaml)
DOCS_REPO=""
for dir in */; do
    if [ -f "${dir}repos.yaml" ]; then
        DOCS_REPO="${dir%/}"
        break
    fi
done

if [ -n "$DOCS_REPO" ]; then
    echo "--- Docs Repo: $DOCS_REPO ---"
    echo ""

    if [ -f "$DOCS_REPO/STATUS.md" ]; then
        echo "--- Project STATUS ---"
        cat "$DOCS_REPO/STATUS.md"
        echo ""
    fi

    echo "--- Active Work ---"
    ls "$DOCS_REPO/active-work/"*.md 2>/dev/null || echo "(no active epics)"
    echo ""

    # Show review sub-state if a pipeline:review issue exists
    if command -v gh &>/dev/null; then
        REVIEW_ISSUES=$(cd "$DOCS_REPO" && gh issue list --state open --label "pipeline:review" --json number,title 2>/dev/null || echo "")
        if [ -n "$REVIEW_ISSUES" ] && [ "$REVIEW_ISSUES" != "[]" ]; then
            echo "--- Active Review Issues ---"
            echo "$REVIEW_ISSUES"
            echo ""
        fi
    fi
fi

echo "--- Workspace Repos ---"
for dir in */; do
    if [ -d "${dir}.git" ]; then
        branch=$(cd "$dir" && git branch --show-current 2>/dev/null || echo "?")
        changes=$(cd "$dir" && git status --short 2>/dev/null | wc -l)
        echo "  $dir → branch: $branch, uncommitted: $changes"
    fi
done
echo ""

echo "=== Session ID: $SESSION_ID — Read CLAUDE.md for operating manual. ==="
