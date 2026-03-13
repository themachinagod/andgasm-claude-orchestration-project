#!/bin/bash
#
# ralph.sh — Autonomous pipeline orchestration loop
#
# Runs Claude Code sessions in a loop. Each session reads project state,
# picks the highest-priority action, executes it, updates state, and exits.
# The next session reads state from files and GitHub and continues.
#
# Handles all implemented pipeline stages (review, decompose).
# Runs /orchestrate which dispatches to the correct stage logic.
#
# Usage:
#   ./ralph.sh                    # run from workspace root
#   ./ralph.sh --max-cycles 10    # limit to 10 cycles
#   ./ralph.sh --dry-run          # show what would run without executing
#
# Prerequisites:
#   - Claude Code CLI (claude) installed and authenticated
#   - gh CLI authenticated
#   - Run from the workspace root (directory containing CLAUDE.md and .claude/)
#
# To stop: Ctrl+C (state is always saved, safe to interrupt between cycles)
#

set -euo pipefail

WORKSPACE_ROOT="$(pwd)"

MAX_CYCLES=0        # 0 = unlimited
MAX_TURNS=0         # 0 = unlimited claude tool-use turns per cycle
TIMEOUT=0           # 0 = no wall-clock timeout per cycle
DRY_RUN=false
PAUSE_BETWEEN=15    # seconds between cycles
CYCLE=0
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3

while [[ $# -gt 0 ]]; do
    case $1 in
        --max-cycles)
            MAX_CYCLES="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --pause)
            PAUSE_BETWEEN="$2"
            shift 2
            ;;
        --max-turns)
            MAX_TURNS="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ralph.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --max-cycles N    Stop after N cycles (default: unlimited)"
            echo "  --max-turns N     Claude tool-use turns per cycle (default: unlimited)"
            echo "  --timeout SECS    Wall-clock timeout per cycle in seconds (default: none)"
            echo "  --pause SECONDS   Pause between cycles (default: 15)"
            echo "  --dry-run         Show what would run without executing"
            echo ""
            echo "Run from the workspace root (directory containing CLAUDE.md and .claude/)."
            echo "Stop with Ctrl+C. State is always saved between cycles."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    echo "[ralph $(date '+%H:%M:%S')] $*"
}

find_docs_repo() {
    for dir in "$WORKSPACE_ROOT"/*/; do
        if [ -f "${dir}repos.yaml" ]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

check_prerequisites() {
    if ! command -v claude &> /dev/null; then
        echo "Error: claude CLI not found. Install Claude Code first."
        exit 1
    fi

    if ! command -v gh &> /dev/null; then
        echo "Error: gh CLI not found. Install GitHub CLI first."
        exit 1
    fi

    if ! gh auth status &> /dev/null 2>&1; then
        echo "Error: gh CLI not authenticated. Run 'gh auth login' first."
        exit 1
    fi

    if [ ! -f "$WORKSPACE_ROOT/CLAUDE.md" ] && [ ! -d "$WORKSPACE_ROOT/.claude" ]; then
        echo "Error: Not in a workspace root (no CLAUDE.md or .claude/ found)."
        echo "Run this script from the workspace root directory."
        exit 1
    fi

    DOCS_REPO_DIR=$(find_docs_repo)
    if [ -z "$DOCS_REPO_DIR" ]; then
        echo "Error: No docs repo found (no subdirectory contains repos.yaml)."
        exit 1
    fi

    if [ ! -f "$DOCS_REPO_DIR/STATUS.md" ]; then
        echo "Error: STATUS.md not found in docs repo ($DOCS_REPO_DIR)."
        echo "Run /initialise-workspace first."
        exit 1
    fi
}

check_stakeholder_input() {
    DOCS_REPO_DIR=$(find_docs_repo)

    local repo_id
    repo_id=$(cd "$DOCS_REPO_DIR" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')
    if [ -z "$repo_id" ]; then
        return 1
    fi

    local open_issues
    open_issues=$(gh issue list \
        --repo "$repo_id" \
        --label "needs-stakeholder-input" \
        --state open \
        --json number,title \
        2>/dev/null || echo "[]")

    if [ "$open_issues" != "[]" ] && [ -n "$open_issues" ]; then
        log "Issues waiting on stakeholder input:"
        echo "$open_issues" | python3 -c "
import json, sys
issues = json.load(sys.stdin)
for i in issues:
    print(f'  #{i[\"number\"]}: {i[\"title\"]}')
" 2>/dev/null || echo "$open_issues"
        return 0
    fi

    return 1
}

check_all_done() {
    DOCS_REPO_DIR=$(find_docs_repo)

    local repo_id
    repo_id=$(cd "$DOCS_REPO_DIR" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')
    if [ -z "$repo_id" ]; then
        return 1
    fi

    local open_pipeline_issues
    open_pipeline_issues=$(gh issue list \
        --repo "$repo_id" \
        --state open \
        --json labels \
        2>/dev/null || echo "[]")

    local pipeline_count
    pipeline_count=$(echo "$open_pipeline_issues" | python3 -c "
import json, sys
issues = json.load(sys.stdin)
count = sum(1 for i in issues for l in i.get('labels', []) if l.get('name', '').startswith('pipeline:') and l['name'] != 'pipeline:done')
print(count)
" 2>/dev/null || echo "unknown")

    if [ "$pipeline_count" = "0" ]; then
        return 0
    fi

    return 1
}

PROMPT='You are in an AUTONOMOUS session (Ralph). The user is NOT present.
Read CLAUDE.md for operating instructions.

Run /orchestrate to:
1. Orient: read STATUS.md, repos.yaml, GitHub Issues and PRs
2. Determine the pipeline stage and sub-state for open issues
3. Execute the appropriate action (dispatch agent teams for review, decompose, etc.)
4. Update all state (STATUS.md, issue labels, issue comments)
5. Stop after completing one action cycle

If stakeholder input is needed:
- Add the needs-stakeholder-input label to the issue
- Update STATUS.md
- Stop immediately — do NOT attempt to engage the user

If nothing is actionable (no open pipeline issues, or all waiting on stakeholder):
- Update STATUS.md with current state
- Stop

IMPORTANT: You must persist all state before stopping. The next session has
no memory — files and GitHub state are all it has.'

run_cycle() {
    CYCLE=$((CYCLE + 1))
    log "=== Cycle $CYCLE ==="

    if $DRY_RUN; then
        log "[dry-run] Would run claude in $WORKSPACE_ROOT"
        log "[dry-run] Prompt: (orchestrate single cycle)"
        return 0
    fi

    local start_time
    start_time=$(date +%s)

    local cmd=(claude --print "$PROMPT" --directory "$WORKSPACE_ROOT")

    if [ "$MAX_TURNS" -gt 0 ]; then
        cmd+=(--max-turns "$MAX_TURNS")
    fi

    if [ "$TIMEOUT" -gt 0 ]; then
        timeout "$TIMEOUT" "${cmd[@]}" 2>&1 | while IFS= read -r line; do
            echo "  $line"
        done
    else
        "${cmd[@]}" 2>&1 | while IFS= read -r line; do
            echo "  $line"
        done
    fi

    local exit_code=${PIPESTATUS[0]}

    if [ $exit_code -eq 124 ]; then
        log "Cycle hit wall-clock timeout (${TIMEOUT}s) — state should be saved, continuing"
        return 0
    fi
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log "Cycle $CYCLE completed in ${duration}s (exit code: $exit_code)"
    return $exit_code
}

# --- Main ---

log "Starting Ralph loop"
log "Workspace:    $WORKSPACE_ROOT"
log "Max cycles:   $([ $MAX_CYCLES -eq 0 ] && echo 'unlimited' || echo $MAX_CYCLES)"
log "Max turns:    $([ $MAX_TURNS -eq 0 ] && echo 'unlimited' || echo $MAX_TURNS) per cycle"
log "Timeout:      $([ $TIMEOUT -eq 0 ] && echo 'none' || echo "${TIMEOUT}s") per cycle"
log "Pause:        ${PAUSE_BETWEEN}s between cycles"
log ""

check_prerequisites

log "Docs repo:    $DOCS_REPO_DIR"
log ""

while true; do
    if [ $MAX_CYCLES -gt 0 ] && [ $CYCLE -ge $MAX_CYCLES ]; then
        log "Reached max cycles ($MAX_CYCLES). Stopping."
        break
    fi

    if check_stakeholder_input; then
        log "Stakeholder input needed. Pausing Ralph."
        log "Start an interactive Claude session to handle review feedback."
        log "Then restart Ralph for re-review."
        break
    fi

    if check_all_done; then
        log "All pipeline issues are done. Nothing left to do."
        break
    fi

    if run_cycle; then
        CONSECUTIVE_FAILURES=0
    else
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        log "Warning: cycle failed ($CONSECUTIVE_FAILURES consecutive failures)"

        if [ $CONSECUTIVE_FAILURES -ge $MAX_CONSECUTIVE_FAILURES ]; then
            log "Error: $MAX_CONSECUTIVE_FAILURES consecutive failures. Stopping."
            log "Check STATUS.md and recent session logs for details."
            break
        fi
    fi

    log "Pausing ${PAUSE_BETWEEN}s before next cycle..."
    sleep "$PAUSE_BETWEEN"
done

log "Ralph stopped after $CYCLE cycles."
