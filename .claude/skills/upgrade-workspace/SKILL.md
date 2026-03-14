---
name: upgrade-workspace
description: >
  Upgrade an existing project workspace to the latest orchestrator template.
  Replaces tooling (agents, skills, rules, scripts, conventions, templates)
  while preserving all project content (PRDs, designs, roadmap, STATUS.md,
  repos.yaml, active-work, architecture docs). Safe to run at any pipeline
  stage. Re-applies project value substitutions using the same process as
  /initialise-workspace.
---

## Instructions

### 1. Pre-flight Checks

Verify this is a valid workspace:

```bash
ls CLAUDE.md .claude/ 2>/dev/null
```

If `CLAUDE.md` or `.claude/` don't exist at workspace root, this is not
an initialised workspace. Stop and tell the user.

Find the docs repo:

```bash
# Find the subdirectory containing repos.yaml
for dir in */; do
  if [ -f "${dir}repos.yaml" ]; then
    echo "$dir"
    break
  fi
done
```

If no docs repo found, stop — can't upgrade without it.

Read the docs repo name (strip trailing slash) — this is `[DOCS_REPO]`.

Verify gh is authenticated:

```bash
gh auth status
```

Extract the GitHub account from the output.

### 2. Extract Project Values

Read project values from the existing workspace. These are needed to
re-substitute template placeholders.

**From repos.yaml:**

```bash
cat [DOCS_REPO]/repos.yaml
```

Extract:
- **Project name** — from the docs repo entry name (e.g., `northwind-docs`
  → project name is `northwind`). Or read from the `name` field.
- **Docs repo GitHub path** — from the `github` field

**From the docs repo directory name:**
- `[DOCS_REPO]` = the directory name (e.g., `northwind-docs`)

**From gh auth:**
- `[GITHUB_ACCOUNT]` = the authenticated GitHub username

Confirm the extracted values with the user before proceeding:

```
Detected workspace:
  Project name: [name]
  Docs repo: [DOCS_REPO]
  GitHub account: [account]
  Template source: themachinagod/andgasm-claude-orchestration-project

Proceed with upgrade? (y/n)
```

### 3. Fetch Latest Template

Clone the template repo to a temporary directory:

```bash
TEMPLATE_DIR=$(mktemp -d)
gh repo clone themachinagod/andgasm-claude-orchestration-project "$TEMPLATE_DIR" -- --depth 1
```

Verify the clone succeeded:

```bash
ls "$TEMPLATE_DIR/CLAUDE.md" "$TEMPLATE_DIR/.claude/" 2>/dev/null
```

### 4. Replace Workspace Root Tooling

Replace `.claude/` wholesale:

```bash
rm -rf ./.claude
cp -a "$TEMPLATE_DIR/.claude" ./.claude
```

Regenerate `CLAUDE.md` from the template with project value substitutions:

```bash
cp "$TEMPLATE_DIR/CLAUDE.md" ./CLAUDE.md
```

Apply substitutions to `CLAUDE.md`:
- Replace all `[DOCS_REPO]` with the actual docs repo directory name
- Replace all `[PROJECT_NAME]` with the actual project name

### 5. Replace Docs Repo Tooling

Replace tooling files inside the docs repo. These are template artifacts,
not project content.

```bash
cd [DOCS_REPO]
```

**Scripts:**
```bash
rm -rf ./scripts
cp -a "$TEMPLATE_DIR/scripts" ./scripts
```

**GitHub config:**
```bash
rm -rf ./.github
cp -a "$TEMPLATE_DIR/.github" ./.github
```

**GUIDE.md:**
```bash
cp "$TEMPLATE_DIR/GUIDE.md" ./GUIDE.md
```

**README.md** (regenerate with project values):
```bash
cp "$TEMPLATE_DIR/README.md" ./README.md
```
Apply substitutions to README.md:
- Replace template references with actual project name and account

**Conventions:**
```bash
rm -rf ./docs/conventions
cp -a "$TEMPLATE_DIR/docs/conventions" ./docs/conventions
```

**Templates (inside docs/):**
```bash
# PRD templates
rm -rf ./docs/prd/templates
cp -a "$TEMPLATE_DIR/docs/prd/templates" ./docs/prd/templates

# Planning templates
rm -rf ./docs/planning/templates
cp -a "$TEMPLATE_DIR/docs/planning/templates" ./docs/planning/templates

# Discovery templates
rm -rf ./docs/discovery/templates
cp -a "$TEMPLATE_DIR/docs/discovery/templates" ./docs/discovery/templates

# Architecture decision templates
mkdir -p ./docs/architecture/decisions/templates
rm -rf ./docs/architecture/decisions/templates
cp -a "$TEMPLATE_DIR/docs/architecture/decisions/templates" ./docs/architecture/decisions/templates 2>/dev/null || true
```

**Research docs:**
```bash
rm -rf ./docs/research
cp -a "$TEMPLATE_DIR/docs/research" ./docs/research
```

**Issue/epic templates (root templates dir):**
```bash
if [ -d "$TEMPLATE_DIR/templates" ]; then
  rm -rf ./templates
  cp -a "$TEMPLATE_DIR/templates" ./templates
fi

if [ -d "$TEMPLATE_DIR/active-work/templates" ]; then
  cp -a "$TEMPLATE_DIR/active-work/templates/." ./active-work/templates/
fi
```

```bash
cd ..
```

### 6. Sync Labels

Sync labels from the updated `.github/labels.yml` to the docs repo
on GitHub. This is additive — it creates/updates template labels but
does NOT delete project-created labels.

```bash
cd [DOCS_REPO]
```

For each label defined in `.github/labels.yml`:

```bash
gh label create "[name]" --color "[color]" --description "[description]" --force
```

The `--force` flag updates existing labels with new color/description.
Labels not in the template (like `initiative:auth`) are untouched.

Check for deprecated labels that might be on existing issues:

```bash
# Check if any issues still have the old pipeline:verify label
gh issue list --label "pipeline:verify" --state open --json number,title 2>/dev/null
```

If any issues have deprecated labels, report them to the user for
manual review. Do NOT auto-remove labels from issues.

```bash
cd ..
```

### 7. Clean Up

```bash
rm -rf "$TEMPLATE_DIR"
```

### 8. Commit and Push

Commit the docs repo changes:

```bash
cd [DOCS_REPO]
git add -A
git status
```

If there are changes:

```bash
git commit -m "chore: upgrade workspace tooling from orchestrator template

Updated: agents, skills, rules, hooks, scripts, conventions,
templates, labels, GUIDE.md, README.md, research docs.
Preserved: STATUS.md, repos.yaml, active-work, all project docs."
git push origin main
cd ..
```

### 9. Report

Tell the user what was updated:

```
Workspace upgraded!

Updated from template: themachinagod/andgasm-claude-orchestration-project

Replaced:
  - .claude/ (agents, skills, rules, hooks)
  - CLAUDE.md (regenerated with project values)
  - scripts/ralph.sh
  - .github/ (labels, PR template, issue templates)
  - GUIDE.md
  - README.md (regenerated with project values)
  - docs/conventions/
  - docs/*/templates/
  - docs/research/

Preserved (untouched):
  - STATUS.md
  - repos.yaml
  - active-work/
  - docs/prd/ (project content)
  - docs/discovery/ (project content)
  - docs/planning/roadmap.md
  - docs/architecture/ (project content)
  - docs/design/ (project content)

Labels synced to GitHub.
[any deprecated label warnings]

The upgrade takes effect immediately. New agents and pipeline rules
will be used on the next orchestrator cycle.
```

## Important Notes

- This skill lives in the template at `.claude/skills/upgrade-workspace/`
- It is NOT a global skill — it ships with the workspace tooling
- For the first upgrade of a pre-upgrade workspace, manually copy this
  skill file into `.claude/skills/upgrade-workspace/SKILL.md` or
  instruct Claude to perform the upgrade steps directly
- Safe to run at any pipeline stage — new tooling takes effect on
  next cycle without affecting in-flight work
- The template source is hardcoded to
  `themachinagod/andgasm-claude-orchestration-project` — same as
  `/initialise-workspace`
- STATUS.md, repos.yaml, and all project content are NEVER touched
- Label sync is additive — project-created labels are preserved
