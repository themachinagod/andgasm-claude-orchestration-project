#!/bin/bash
# TaskCompleted hook — Quality checks and state persistence checklist.
#
# This runs from workspace root.

set -euo pipefail

echo "=== TASK COMPLETE: Quality & State Checklist ==="
echo ""
echo "  [ ] 1. All changes committed in every repo touched"
echo "  [ ] 2. Branches pushed to remote (survive between sessions)"
echo "  [ ] 3. Docs repo STATUS.md updated ([DOCS_REPO]/STATUS.md)"
echo "  [ ] 4. Active-work epic file updated ([DOCS_REPO]/active-work/)"
echo "  [ ] 5. Component repo STATUS.md updated (if code work was done)"
echo "  [ ] 6. PR created with issue references (if implementation work)"
echo "  [ ] 7. GitHub Issue labels advanced to correct pipeline stage"
echo ""
echo "=== The next session has NO memory — files are all it has ==="
