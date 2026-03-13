---
name: initialise-workspace
description: >
  Bootstrap a new project workspace. Creates the docs repo from the
  orchestrator template, moves agent configuration to workspace root,
  and configures everything with project details. Install this skill
  globally (~/.claude/skills/) — it must exist before any project does.
---

## Instructions

### 1. Pre-flight Checks

Verify the environment is ready:

```bash
# Check gh is authenticated — get the account name
gh auth status
```

If `gh auth status` fails, tell the user to run `gh auth login` first and stop.

Extract the GitHub account (username) from the output. This will be used
for repo creation — don't ask the user for it.

Check the current directory is suitable:

```bash
ls -la
```

If `.claude/` or `CLAUDE.md` already exist in the current directory, warn
the user that a workspace may already be initialised here and confirm
before proceeding.

### 2. Gather Information

Ask the user these questions. Project name and description are required.
The rest are optional — skip if the user doesn't know yet.

| Question | Required | Default | Example |
|----------|----------|---------|---------|
| **Project name / codename** | Yes | — | "northwind", "acme" |
| **High-level description** (one paragraph — what are you building?) | Yes | — | "A platform for..." |
| **Target users / audience** (brief — who is this for?) | No | — | "Internal ops team" |
| **Known tech preferences** | No | — | ".NET APIs, Angular UI" |
| **Known constraints** (timeline, compliance, integrations) | No | — | "Must integrate with SAP" |
| **Repo visibility** | No | private | "private" or "public" |

### 3. Create the Docs Repo

Create the docs repo from the orchestrator template:

```bash
gh repo create [account]/[project]-docs \
  --template andgasm/andgasm-claude-orchestration-project \
  --[visibility] \
  --clone
```

Wait for the clone to complete. Verify `./[project]-docs/` exists.

### 4. Move Workspace Configuration

Move Claude configuration from the docs repo to workspace root. These
are static tooling files — they don't change during the project.

```bash
# Ensure .claude/ exists at workspace root (Claude Code may have already created it)
mkdir -p ./.claude

# Move contents from docs repo into workspace .claude/ (merge, don't nest)
cp -a ./[project]-docs/.claude/. ./.claude/
rm -rf ./[project]-docs/.claude

# Move CLAUDE.md operating manual
mv ./[project]-docs/CLAUDE.md ./CLAUDE.md
```

### 5. Configure CLAUDE.md

Update `./CLAUDE.md` with the actual project details:

- Replace all `[DOCS_REPO]` with `[project]-docs`
- Replace all `[PROJECT_NAME]` with the project name

### 6. Configure STATUS.md

Update `./[project]-docs/STATUS.md` with project details:

- Replace `[PROJECT_NAME]` with the project name
- Replace `[PROJECT_DESCRIPTION]` with the description the user provided
- Replace `[GITHUB_ACCOUNT]` with the detected GitHub account
- Set the date in "Last Updated"

### 7. Configure repos.yaml

Update `./[project]-docs/repos.yaml`:

- Replace `[PROJECT_NAME]` with the project name
- Replace `[GITHUB_ACCOUNT]` with the detected GitHub account
- Replace `[PROJECT_DESCRIPTION]` with the description
- Uncomment and populate the docs repo entry:
  ```yaml
  repos:
    - name: "[project]-docs"
      type: docs
      github: "[account]/[project]-docs"
      path: ./[project]-docs
      purpose: "Project documentation, coordination, and pipeline state"
  ```

### 8. Configure README.md

Update `./[project]-docs/README.md`:

- Replace template references with actual project name and account

### 9. Sync Pipeline Labels

Sync the labels from `.github/labels.yml` to the docs repo:

```bash
cd [project]-docs

# Read labels.yml and create each label
# For each label in .github/labels.yml:
gh label create "[name]" --color "[color]" --description "[description]" --force

cd ..
```

### 10. Create GitHub Project

Create a GitHub Project for cross-repo tracking and visibility:

```bash
gh project create --title "[PROJECT_NAME]" --owner [account]
```

Note the project number from the output. This project will be used
to track issues across all repos as the pipeline progresses.

### 11. Commit and Push

```bash
cd [project]-docs
git add -A
git commit -m "chore: configure project — [project name]"
git push
cd ..
```

### 12. Report

Tell the user:

```
Workspace ready!

Docs repo: [project]-docs/ (GitHub: [account]/[project]-docs)
GitHub Project: [PROJECT_NAME] (project #[number])
CLAUDE.md: configured at workspace root
.claude/: moved to workspace root
Labels: synced to docs repo

Next steps:
1. Write your PRDs in [project]-docs/docs/prd/
2. Write vision/context docs in [project]-docs/docs/discovery/
3. Work with AI in the IDE — iterate as much as needed
4. When ready to enter the pipeline: run /submit-prds
```

## Important Notes

- This skill MUST be installed globally at `~/.claude/skills/initialise-workspace/SKILL.md`
- Run from an EMPTY directory that will become the workspace root
- The docs repo is the only repo created from a template — component repos
  come later during the Design phase via `/repo-provision`
- `.claude/` and `CLAUDE.md` are MOVED (not copied) from the docs repo
- No AGENTS.md — Claude Code uses auto memory natively
- GitHub account is auto-detected from `gh auth status`, never asked
