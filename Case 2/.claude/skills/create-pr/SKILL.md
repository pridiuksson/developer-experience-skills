---
name: create-pr
description: "Lift commits onto a named branch and open a PR — without checkout. Runs /verify gate (build + scoped tests + local report-only review) before pushing. Safe when another agent works on the same branch. Designed as the step after /commit."
allowed-tools:
  - Bash
  - Read
  - Glob
  - Agent
argument-hint: "[branch-name]"
---

# Create PR

Takes commits that landed on the current branch (often `main`) and opens a pull request — **without ever running `git checkout`**. Runs the /verify gate (build + scoped tests + local review) before pushing so CI acts as a confirmer, not a fixer.

The full local-to-PR flow:

```
/commit        → tsc + lint gate → commits land on current branch
/create-pr     → /verify gate → branch (no checkout) → push → PR
```

CI (`claude-review.yml`) then runs as the safety net: tsc + lint + build → `/test ci` → `/review ci`.

---

## Why /verify and not /test directly?

`/verify` runs three tiers: build gate (tsc + lint + build), scoped tests (via /test auto mode), and local report-only review (via /review). Running all three before push means CI sees a cleaner diff and the coding agent gets immediate feedback on all quality dimensions.

---

## Core Invariant

**Never run `git checkout`, `git switch`, or `git checkout -b`.**

Branch creation (`git branch <name> <sha>`) writes a ref without moving `HEAD`. Editors and parallel agents watch `HEAD` — since it never moves, they see nothing. This skill creates and pushes branches exclusively via ref writes and `git push`.

---

## Step 1: Identify Commits to PR

```bash
git log origin/main..HEAD --oneline
git rev-parse HEAD
```

- If `git log` is empty → "Nothing ahead of origin/main — nothing to PR" and stop.
- Capture `HEAD_SHA` for branch creation.

---

## Step 2: Run Verify Gate

Delegate to the `/verify` skill via a sub-agent:

```
Run the /verify skill against the current commit range.
Changed files: <list from git diff origin/main..HEAD --name-only>
Return: gate result (pass/fail), build gate result, tests run (suite, count, result),
        review findings (if any, report-only), risk assessment, any warnings.
```

**On failure**: stop. Report the failing tier (build, tests, review). Do not create the branch or PR.
**On pass**: continue. Record results for the PR body.

**Skip condition**: if all changed files are under `Knowledge/`, `tests/nightly/`, or are `.md` files — verify's Tier 2 and Tier 3 automatically skip for these. Tier 1 (build gate) still runs.

---

## Step 3: Determine Branch Name

If `$ARGUMENTS` contains a branch name → use it as-is.

Otherwise derive from the **first commit message** in the range (oldest first):

```bash
git log origin/main..HEAD --oneline --reverse | head -1
```

Derivation rules:
1. Strip conventional commit prefix: `type: ` → drop `type: `
2. Lowercase, replace spaces/slashes/parens with `-`
3. Remove special chars except `-` and `_`
4. Truncate to 50 chars
5. Prefix with type slug: `fix/`, `feat/`, `test/`, `docs/`, `chore/`, `refactor/`

Examples:
- `test: fix nightly API verification` → `test/fix-nightly-api-verification`
- `feat: add churn risk column` → `feat/add-churn-risk-column`
- `docs: sync metric catalog` → `docs/sync-metric-catalog`

Check for collision on origin:
```bash
git ls-remote --exit-code origin <branch-name>
```
If exists, append `-2`, `-3` until free.

---

## Step 4: Create Branch and Push (no checkout)

```bash
git branch <branch-name> <HEAD_SHA>
git push -u origin <branch-name>
```

**Never run `git checkout`** — HEAD stays where it is.

If `git branch` fails (local branch already exists): `git branch -f <branch-name> <HEAD_SHA>`.

---

## Step 5: Draft PR Title and Body

**Title**: first commit message if single commit; synthesize from the range otherwise. Max 70 chars.

### Fetch latest main

```bash
git fetch origin main
```

Ensures `origin/main` is current. Without this, a recently-merged PR on main will inflate the file count and diff scope (the local tracking branch can be hours stale).

### Check: Does this PR need Visual Verification?

Run: `git diff origin/main..HEAD --name-only` and check against:

**Tier 1** (direct UI):
- `src/components/dashboard/**`
- `src/components/ui/**`
- `src/app/(dashboard)/page.tsx`
- `src/app/layout.tsx`
- `src/app/(dashboard)/layout.tsx`
- `src/app/globals.css`
- `src/lib/tab-configs.ts`
- `src/app/(dashboard)/tabs/**`

**Tier 2** (data/logic feeding UI):
- `src/lib/settings-context.tsx`
- `src/lib/ai-models.ts`
- `src/app/(dashboard)/actions.ts`
- `src/lib/resolvers/**`
- `src/lib/proactive-insights.ts`
- `src/lib/churn-risk-insights.ts`
- `src/lib/ai/prompt-template.ts`
- `src/lib/ai/field-registry.ts`

If **Tier 1** files match → `NEEDS_VV = true` (no exceptions).
If only **Tier 2** files match → inspect the actual diff of those files. Tier 2 files contain both UI-feeding logic AND non-visual concerns (prompts, model config, eval). Apply this test:

| Diff touches… | NEEDS_VV |
|----------------|----------|
| Exported function/type signatures, return values, or data shapes consumed by components | `true` |
| Prompt strings, model config, comments, import-only changes, or non-exported constants | `false` |

If unsure → default to `true`.
If no match at all → `NEEDS_VV = false`.

Record this decision for Step 5.5 and Step 8.

### Body template

**Copy this template exactly. Fill in the placeholders. Do not omit sections.**

```markdown
## Summary

<2–4 bullet points covering what changed and why>

## Changed Files

<details><summary>Files changed in this PR</summary>

<For each file from `git diff origin/main..HEAD --name-only`, add one line with the key change. Example:>

- `src/app/(dashboard)/tabs/customer-accordion.tsx` — maxLength 2000→5000, org-scoped notes, attribution label
- `src/app/(dashboard)/actions.ts` — server-side note content limit 2000→5000
- `tests/smoke/customer-notes.test.ts` — updated regex assertion to match 5000

</details>

## Quality gate

- **Build**: ✅ tsc + lint + build passed
- **Tests**: <suite> — ✅ <N> passed
- **Review**: ✅ <N> findings (<M> auto-fixable) — all addressed locally (or "skipped — CI handles review")
- **Risk assessment**: <list critical files modified, or "No critical files modified.">

## Test plan
- [x] Local: verify gate passed (build + tests + review)
- [ ] CI: tsc + lint + build
- [ ] CI: /test ci
- [ ] CI: /review ci (findings posted as PR comment)

## Review context

> This section is written for the CI review agent (`/review ci`). It maps
> the flat diff back to intent so the reviewer can distinguish intentional
> changes from mistakes.

**Intentional changes that may look suspicious:**
<list any diff hunks that invert a condition, rename a value, flip an assertion,
or change a constant — with one-line rationale for each>

**Confirmed by testing:**
<what was verified before this PR — e.g. "148/148 tests passed against live API">

**Not touched (do not flag as missing):**
<areas deliberately left unchanged — e.g. "production query logic unchanged,
only test expectations updated">

<!-- IF NEEDS_VV = true, include this section. If false, omit it entirely. -->

## Visual Verification

> **Intent:** <what the PR changes visually — derived from commit messages>
> **Areas:** <which tabs/views are affected — derived from `Knowledge/ui-map.md` Quick Reference lookup if the file exists; otherwise list affected file paths without tab mapping>
> **Run with:** `@claude vv`

<details><summary>Files that changed UI</summary>

- `src/components/dashboard/tab-view.tsx` — <what changed>
- `src/components/dashboard/settings-modal.tsx` — <what changed>

</details>
<!-- END conditional section -->
```

Write the Review context section honestly — if there are no suspicious-looking changes, say so. The goal is to pre-answer the reviewer's likely questions, not to fill space.

---

## Step 5.5: Verify Body Completeness

Before opening the PR, confirm ALL required sections are present in the body. Check each one:

- [ ] `## Summary` — 2–4 bullet points
- [ ] `## Changed Files` — collapsible list with per-file one-liners
- [ ] `## Quality gate` — with Build, Tests, Review, and Risk assessment sub-items
- [ ] `## Test plan` — local + CI checklist
- [ ] `## Review context` — Intentional changes, Confirmed by testing, Not touched
- [ ] `## Visual Verification` — **ONLY** if `NEEDS_VV = true` from the check above

If any section is missing, add it before proceeding to Step 6.

---

## Step 6: Open PR

```bash
gh pr create \
  --title "<title>" \
  --body "<body>" \
  --base main \
  --head <branch-name>
```

---

## Step 7: Report

```
## PR Created

**Branch**: `<branch-name>` (created at <short-sha>, HEAD stayed on `<current-branch>`)
**PR**: <url>
**Commits**: <N>
**Tests**: <suite> — ✅ passed / ⏭ skipped / via /verify gate

| # | Commit |
|---|--------|
| 1 | <sha> <message> |

**Local state**: HEAD still on `<current-branch>` — no checkout performed.
**CI**: tsc + lint + build → /test ci → /review ci will run automatically.
```

### Step 8 — Visual Verification (if applicable)

If the PR body includes a `## Visual Verification` section (added in Step 5 for UI PRs), **comment `@claude vv` on the PR immediately** — do not wait for Vercel. The `visual-verify.yml` workflow triggers the `visual-verify` skill, which takes annotated screenshots of affected tabs, uploads them via GitHub's release assets API, and posts a verdict comment with embedded images. The workflow itself waits up to 8 minutes for the preview deployment to be ready before proceeding.

If the section is missing (no UI files detected in the diff), skip this step entirely.

---

## Already on a Feature Branch

If `git branch --show-current` returns something other than `main`:

- Skip branch creation entirely
- Run `git push -u origin <current-branch>` (or `git push` if tracking exists)
- Continue from Step 2 (run tests, then proceed to draft + open PR)

The "no checkout" invariant is trivially satisfied — you're already on the right branch.

---

## Error Handling

| Condition | Action |
|-----------|--------|
| Nothing ahead of `origin/main` | Report and stop — nothing to PR |
| Tests fail | Stop — report failures, do not create branch or PR |
| Branch name collision on origin | Append `-2`, `-3` until free |
| `git push` fails (non-fast-forward) | Report error — do not force push |
| `gh pr create` fails | Report error; branch already pushed, user can open PR manually |

