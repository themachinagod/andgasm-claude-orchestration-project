#!/bin/bash
# PreToolUse[Bash] hook — Block destructive shell commands.
#
# Prevents accidental execution of dangerous commands like force push,
# hard reset, or database drops. Allows --force-with-lease (safe force push
# on feature branches after rebase).

# Claude Code passes tool input as JSON on stdin.
# Extract the command from the JSON payload.
INPUT=$(cat)
if command -v jq &>/dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
else
    # Fallback: extract command value with grep/sed (handles most cases)
    COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Allow --force-with-lease (safe alternative to --force)
if echo "$COMMAND" | grep -qiE "force-with-lease"; then
    exit 0
fi

# List of dangerous patterns
DANGEROUS_PATTERNS=(
    "git push.*--force"
    "git push.*-f "
    "git reset --hard"
    "rm -rf /"
    "DROP DATABASE"
    "DROP TABLE"
    "TRUNCATE TABLE"
    "DELETE FROM .* WHERE 1"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        echo "BLOCKED: Dangerous command detected: $pattern"
        exit 2
    fi
done

# Command is safe
exit 0
