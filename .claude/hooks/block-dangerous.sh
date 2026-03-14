#!/bin/bash
# PreToolUse[Bash] hook — Block destructive shell commands.
#
# Prevents accidental execution of dangerous commands like force push,
# hard reset, or database drops. Allows --force-with-lease (safe force push
# on feature branches after rebase).

# The command being executed is passed via stdin or environment
COMMAND="${CLAUDE_TOOL_INPUT:-}"

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
