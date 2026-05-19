---
name: commit
description: "Structured commits following conventional commit conventions. Local mode: autonomous 3-step flow (gather → quick checks → plan & execute). CI mode: autonomous — no prompts, commits with 🤖 prefix, structured output for PR comments."
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
argument-hint: "[ci]"
---

# Structured Commits

Create well-scoped, readable commits from the current changes. Groups files by independent intent, applies conventional commit conventions.

**Dual mode**: local (autonomous, 3-step) and CI (autonomous, no prompts). CI mode activates when `$ARGUMENTS` contains `ci` **or** env `CI=true`.

---

## Commit Format

Conventional commits with mandatory type:

```
<type>: <imperative description>
```

**Types:**

| Type | Meaning |
|------|---------|
| `feat` | New feature or behavior |
| `fix` | Bug fix |
| `refactor` | Behavior-preserving restructure |
| `test` | Test files only |
| `docs` | Knowledge/*.md, README, CLAUDE.md |
| `chore` | Config, deps, CI, skills |
| `style` | Formatting only, no logic change |

**Prefix by mode:**

| Mode | Prefix | Example |
|------|--------|---------|
| Local | (none) | `fix: resolve off-by-one in pass rate threshold` |
| CI | `🤖` | `🤖 fix: remove unused exports in resolver-pipeline` |

---

## Commit Message Rules

1. **Imperative mood**: "add churn risk column" not "added churn risk column"
2. **Why, not what**: "fix pass rate for low-volume orgs (threshold was off-by-one)" not "change pass rate calculation"
3. **No attribution**: Never add co-author, "Generated with Claude", or "Co-Authored-By" lines
4. **Subject under 72 chars**, body wrapped at 72 chars. Body is required for non-trivial changes — the CI review agent reads commit messages as author intent context; a bare subject line leaves it without rationale.

---

## Commit Splitting Rules

Split by **independent intent**, not rigidly by file type. Coupled changes stay together:

| Scenario | Split? | Rationale |
|----------|--------|-----------|
| New feature + its test | **No** | Bisectable; test proves the feature works |
| New feature + unrelated bug fix | **Yes** | Independent intents, independent revert risk |
| Refactor + docs update for that refactor | **No** | Doc describes what the refactor does |
| Refactor + unrelated docs fix | **Yes** | Independent intents |
| Multiple findings fixed by autofix | **Per-finding** if files don't overlap; **batch** if same file | Nightly PR stays readable |
| Test-only change (new test, fix test) | **Yes** — separate from production | Review and CI test step run independently |
| Knowledge doc sync | **Yes** — separate from code | Autofix can safely apply without verification |

**Coupling rule**: If two changes must be reverted together, they must be committed together.

---

## Changed Files Context

!`git status --short 2>/dev/null`
!`git diff HEAD 2>/dev/null; git diff --cached 2>/dev/null`

---

# Local Mode (default)

Autonomous 3-step flow. Plans and executes without confirmation.

## Step 1: Gather Changes

1. **Review conversation context** — what was done in this session (primary source for intent and why)
2. **Read git output above** — what's actually on disk (source of truth for what gets committed)
3. **Reconcile** — if conversation mentions changes that `git status` doesn't show, files may be unsaved. Ask user to save before proceeding.

If no changes found → report "Nothing to commit" and stop.

## Step 2: Quick Checks (local only)

Fast quality gate. Catches type errors, lint violations, and stale lock files before they reach CI. **Skipped in CI mode** — CI already runs these before the commit skill.

### Blocking: Dependency Sync Check

If `package.json` was modified (check `git diff HEAD` or `git diff --cached`), verify the lock file is in sync:

```bash
set +e
NPM_OUTPUT=$(npm ci --dry-run 2>&1)
NPM_EXIT=$?
set -e

if [ $NPM_EXIT -ne 0 ]; then
  echo "❌ Lock file out of sync with package.json (exit code $NPM_EXIT)"
  echo "$NPM_OUTPUT"
  echo "Run 'npm install', stage package-lock.json, then retry /commit."
  exit 1
fi
```

**On failure**: report the error, **stop**. The developer must run `npm install` and stage the updated lock file before committing.

### Blocking: Type Check & Lint

Run these in parallel:

```bash
npx tsc --noEmit
npm run lint
```

**On failure:**
- `tsc` errors → report the errors, **stop**. Do not attempt to fix — the current task is committing, not editing.
- Lint errors → run `npm run lint -- --fix`. If files were modified by `--fix`, re-stage them (`git add` the affected files). Then re-lint. If still failing, report errors, **stop**.

**On pass:** continue to Step 3.

### Advisory Flags (non-blocking)

After checks pass, compute advisory notes from the changed files. Display after the commit plan in Step 3. These **never block** a commit.

**Critical files** — flag if any staged file is in this list:

| File | Risk |
|------|------|
| `src/proxy.ts` | Route protection (never create `src/middleware.ts`) |
| `src/auth.ts` | `@qa.tech` domain check |
| `vercel.json` | `maxDuration: 120` for LLM timeout |
| `next.config.ts` | HTTP security headers |
| `src/app/api/mcp/route.ts` | MCP endpoint auth + tool dispatch |
| `src/lib/mcp/auth.ts` | Token validation via KV |

**Suggested test suite** — match top-to-bottom, first match wins:

| If changed files include... | Suggest |
|---|---|
| `src/lib/resolvers/` | `npm run test:regression` + `npm run test:smoke` (~13 API calls) |
| `src/lib/canonical/` | `npx tsx tests/run.ts smoke:canonical` (0 API calls) |
| `src/lib/mcp/` or `src/app/api/mcp*/` | `npx tsx tests/run.ts smoke:mcp` (0 API calls) |
| `tab-configs.ts` | `npx tsx tests/run.ts smoke:shared` (0 API calls) |
| `query-resolver.ts` | `npx tsx tests/run.ts smoke:canonical` (0 API calls) |
| `src/components/` only | `npx tsx tests/run.ts smoke:shared` (0 API calls) |
| `proactive-insights.ts`, `poc-resolver.ts`, or `paying-resolver.ts` | `npx tsx tests/run.ts smoke:poc` (3 API calls) |
| Any other `src/` file | `npx tsx tests/run.ts verify` (3 API calls) |
| Only `tests/*.test.ts` | Run the changed test file directly |
| Only docs / `Knowledge/` | No tests needed |

**Uncommitted changes** — after planning commits in Step 3, cross-reference the planned files against `git status --short`. If there are changed files not included in any planned commit, warn: "⚠️ Uncommitted changes not in this commit plan: `<file list>`. Save and stage before proceeding, or commit separately."

**Cross-thread isolation** — multiple agents may work in the same repo simultaneously. Only stage files that appear in this conversation's context as having been modified by this session. If `git status` shows modified (`M`) or untracked (`??`) files you did not touch in this conversation, leave them completely unstaged. Never commit another agent's work, even if it looks related. If a file appears in `git status` but you have no memory of modifying it this session, skip it and warn: "⚠️ `<file>` is modified but was not touched in this session — leaving it unstaged."

**High-risk file regression** — if `poc-resolver.ts` or `paying-resolver.ts` is in the changed files, warn: "⚠️ Resolver modified — run `npm run test:regression` before pushing (~15s, 10-12 API calls). Silent async bugs are common in these files."

## Step 3: Plan & Execute

Group files by independent intent using the splitting rules. Plan the commits, then execute immediately without confirmation.

For each group, determine:

- **Type** from the conventional commit types table
- **Message** following the commit message rules
- **Files** to stage for this commit

Present the plan:

```
### Commit Plan (N commits)

**1.** `type: message`
   - `path/to/file1.ts`
   - `path/to/file2.ts`

**2.** `type: message`
   - `path/to/file3.ts`
```

### Execute

1. For each planned commit: `git add` specific files per commit (never `-A` or `.`), then `git commit -m "<message>"`
2. Show `git log --oneline -n N` to confirm
3. Show advisory flags from Step 2 (critical files, suggested tests) — if any apply

---

# CI Mode

Activated when `$ARGUMENTS` contains `ci` **or** env `CI=true`. Autonomous — no interactive prompts, no confirmation. Other CI skills (autofix, test) either delegate to this skill or follow its conventions when committing.

## CI Git Context

The workflow runs `git reset --soft origin/main` — all changes are staged. **`git diff --cached` is the canonical diff source.** `git diff HEAD` (without `--cached`) shows nothing.

## CI Step 1: Gather Changes

1. **Read `git diff --cached`** — the only source of truth in CI (no conversation context)
2. **Infer intent from paths and diff content**:
   - `Knowledge/Plans/Backlog.md` or `Knowledge/Plans/api-drift.md` changed + source files → finding resolution (type: `fix`)
   - Only `tests/` files changed → test fix (type: `test`)
   - Only `Knowledge/*.md` changed → doc sync (type: `docs`)
   - Mixed source files → analyze hunks to determine if coupled or independent
3. If no staged changes → report "Nothing to commit" and stop

## CI Step 2: Plan Commits

Same splitting rules and message rules as local mode, with these additions:

- **🤖 prefix**: All CI commit messages start with `🤖`
- **Batch when ambiguous**: If splitting intent is unclear from the diff alone, prefer a single well-described batch commit over incorrect splits. The coupling rule applies — when in doubt, commit together.
- **Finding-based splitting**: If `Knowledge/Plans/Backlog.md` or `Knowledge/Plans/api-drift.md` shows newly RESOLVED entries, use those finding IDs (F## or D##) to inform both the split and the commit messages (e.g., `🤖 fix: remove unused export in resolver (F63)` or `🤖 fix: rename metric identifier TEST_EXECUTIONS_V2 (D5)`)

## CI Step 3: Execute

1. **No confirmation** — plan and execute immediately
2. For each planned commit:
   - `git reset HEAD` — unstage everything first to start clean
   - `git add <specific files>` — stage only this commit's files
   - `git commit -m "🤖 <type>: <message>"`
3. Never use `git add -A` or `git add .`

## Bail-out Conditions

| Condition | Action |
|-----------|--------|
| No staged changes | Report "Nothing to commit", exit cleanly |
| `git commit` fails | Report error with `git status` output, **do not retry** |
| Merge conflict | Report error, **do not attempt resolution** |

Maximum: **1 attempt** per commit. If it fails, report and stop.

## Structured Output

End with a summary suitable for PR comments:

```
## Commits Created

| # | Message | Files |
|---|---------|-------|
| 1 | 🤖 fix: ... | file1.ts, file2.ts |
| 2 | 🤖 docs: ... | Knowledge/xxx.md |

**Total**: N commit(s), M file(s)
```

If nothing to commit:
```
## Commits Created

No changes to commit.
```

---

## Examples

**Local — coupled changes stay together:**
```
feat: add churn risk column to org health tab
 - src/components/ChurnRiskColumn.tsx
 - tests/churn-risk-column.test.ts
```

**Local — independent intents split:**
```
1. fix: resolve off-by-one in pass rate threshold
   - src/lib/pass-rate.ts

2. docs: update pass rate docs to reflect new threshold
   - Knowledge/development.md
```

**CI — autofix with per-finding split:**
```
1. 🤖 fix: remove unused export in resolver-pipeline (F63)
   - src/lib/query-resolver.ts

2. 🤖 fix: remove unreachable code after return in resolver (F66)
   - src/lib/resolvers/paying-resolver.ts

3. 🤖 chore: mark F63 F66 resolved in backlog
   - Knowledge/Plans/Backlog.md
```
F63 and F66 touch different files → split. Registry update is coupled to the fixes → same commit OR separate `chore` if both fixes land first.

**CI — ambiguous intent, batched:**
```
🤖 refactor: extract shared date formatting, update related docs
 - src/lib/format-date.ts
 - src/components/DateCell.tsx
 - Knowledge/development.md
```
Can't determine independence from diff alone → batch together.
