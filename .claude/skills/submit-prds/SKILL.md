---
name: submit-prds
description: >
  Bridge from manual discovery to the automated pipeline. Takes PRD and
  discovery files the user has written, creates a branch and PR, creates
  a GitHub Issue at pipeline:review, and updates STATUS.md. Re-runnable
  for subsequent submissions.
---

## Instructions

### 1. Find the Docs Repo

Identify the docs repo path. Check for `repos.yaml` in subdirectories,
or read `CLAUDE.md` for the `[DOCS_REPO]` reference.

### 2. Check for Submittable Content

```bash
cd [DOCS_REPO]
git status
```

Check for new or modified files in:
- `docs/prd/` — PRD documents (required — at least one must exist)
- `docs/discovery/` — vision/context docs (optional but encouraged)

If there are no PRD files (new or modified), tell the user:
"No PRD files found in `docs/prd/`. Write your PRDs there first, then
run `/submit-prds` again."

Also check that we're on the `main` branch. If not:
```bash
git checkout main && git pull origin main
```

### 3. Determine Submission Number

Check existing branches and issues to determine the next submission number:

```bash
git branch -a | grep "prd-submission" || echo "No prior submissions"
gh issue list --label "type:prd-review" --json number,title --state all
```

Use the next sequential number (e.g., if `prd-submission-001` exists,
use `prd-submission-002`). If no prior submissions, use `001`.

### 4. Create Branch and Stage Files

```bash
git checkout -b docs/prd-submission-[NNN]
git add docs/prd/
git add docs/discovery/
```

Only stage files from these two directories. Do not stage STATUS.md or
other operational files.

### 5. Commit

```bash
git commit -m "docs: submit PRDs for review

Submits the following PRDs for pipeline review:
$(ls docs/prd/*.md 2>/dev/null | sed 's/docs\/prd\//- /')"
```

### 6. Push and Create PR

```bash
git push origin docs/prd-submission-[NNN]
```

Create PR with a structured description:

```bash
gh pr create \
  --title "docs: PRD submission [NNN] for review" \
  --body "## PRD Submission

### PRDs submitted
$(ls docs/prd/*.md 2>/dev/null | sed 's/^/- /')

### Discovery docs
$(ls docs/discovery/*.md 2>/dev/null | grep -v templates | sed 's/^/- /' || echo '- (none)')

### Process
This PR will be reviewed by the review team (product-manager + architect).
Review findings will appear as PR comments.
The stakeholder facilitator will walk through any items needing input.

Closes #[ISSUE_NUMBER]"
```

Note: The `Closes #` reference will be added after the issue is created.

### 7. Create GitHub Issue

```bash
gh issue create \
  --title "PRD Review: submission [NNN]" \
  --label "type:prd-review,pipeline:review" \
  --body "## PRD Review Cycle

**Submission:** [NNN]
**PR:** #[PR_NUMBER]
**PRDs:**
$(ls docs/prd/*.md 2>/dev/null | sed 's/^/- /')

### Review State
Awaiting first review by review team.

### Process
1. Review team analyses PRDs (autonomous)
2. Stakeholder facilitator walks through findings (interactive)
3. Review team re-reviews until clean
4. Merge PR, advance to pipeline:decompose"
```

### 8. Link PR to Issue

Update the PR body to reference the issue number:

```bash
gh pr edit [PR_NUMBER] --body "$(gh pr view [PR_NUMBER] --json body -q .body | sed 's/Closes #\[ISSUE_NUMBER\]/Closes #[ACTUAL_ISSUE_NUMBER]/')"
```

### 9. Return to Main and Workspace Root

```bash
git checkout main
cd ..
```

### 10. Update STATUS.md

Update `[DOCS_REPO]/STATUS.md` (direct to main — operational state):

```bash
cd [DOCS_REPO]
```

Update the STATUS.md file:
- Set phase to "Review"
- Add the issue to the Active Work table
- Note the PR number
- Update the "Last Updated" timestamp

```bash
git add STATUS.md
git commit -m "status: PRDs submitted for review — issue #[NUMBER]"
git push origin main
cd ..
```

### 11. Report to User

Tell the user:

```
PRDs submitted for review!

Issue: #[NUMBER] — PRD Review: submission [NNN]
PR: #[PR_NUMBER]
PRDs submitted: [list]

What happens next:
1. Run ralph.sh to start the autonomous review cycle
   — OR start Claude and run /orchestrate-review
2. The review team (product-manager + architect) will analyse your PRDs
3. If they find items needing your input, ralph will stop
4. Start an interactive Claude session — the stakeholder facilitator
   will walk you through the findings
5. Restart ralph for re-review
6. Cycle continues until PRDs are approved
```

## Important Notes

- This skill is **re-runnable**. If you add more PRDs later (e.g., after
  review feedback suggests splitting a PRD), just add the files and run
  `/submit-prds` again. It creates a new submission each time.
- Files in `docs/prd/templates/` are NOT submitted — they're templates.
- Files in `docs/discovery/inputs/` are NOT submitted — they're raw inputs.
- The user never needs to touch git, branches, PRs, or issues manually.
- After submission, the user should not edit files on main directly —
  changes go through the PR via the review cycle.
