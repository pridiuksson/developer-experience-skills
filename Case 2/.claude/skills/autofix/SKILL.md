---
name: autofix
description: "Apply safe mechanical fixes for review findings and API drift. Reads findings from PR comments (primary), registries (persistent items), or local ephemeral findings. Four modes: explicit F-ids, nightly, ci, or --local."
allowed-tools:
  - Read
  - Edit
  - Bash
  - Agent
argument-hint: "[F<id> F<id>...] | [nightly] | [ci] | [--local]"
---

# Autofix

Apply safe mechanical fixes for review findings. Findings live in two places:

1. **PR comments** — the review skill posts all findings here. Auto-fixable items get F-ids so `@claude autofix F123` can target them.
2. **Registries** — `Knowledge/Plans/Backlog.md` (persistent HIGH/MEDIUM non-auto-fixable) and `Knowledge/Plans/api-drift.md` (API drift). Only items too complex for auto-fix go here.

Only fixes findings marked `Auto-fixable: Yes`.

## Mode Selection

- `$ARGUMENTS` contains finding IDs (e.g., `F63 F66`) → **explicit mode**: fix only those findings
- `$ARGUMENTS` contains `nightly` → **nightly mode**: read registry, filter, rank, take top 5
- `$ARGUMENTS` contains `ci` or env `CI=true` → **CI mode** (same as nightly or explicit, but with commit/push after)
- `$ARGUMENTS` contains `--local` → **local mode**: read ephemeral findings from `.claude/local-findings.json`
- Default → report usage

## Findings Sources

In CI mode, findings can come from either PR comments or registry files. Use this lookup order:

1. **PR comments** — Read the PR's review comment (the one posted by `claude-review.yml`) to find findings with F-ids:
   ```bash
   gh api "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
     --jq '.[].body' 2>/dev/null
   ```
   Parse the comment for finding entries in the collapsible `<details>` section. Each has an F-id, file, description, and fix hint.

2. **Registry files** — Fall back to `Knowledge/Plans/Backlog.md` and `Knowledge/Plans/api-drift.md` for persistent items that aren't in the current PR's comment.

**Explicit mode** (`F123`): Always check PR comment first, then registry. The review posts auto-fixable items with F-ids in the PR comment.

**Nightly mode**: Reads primarily from registries (those are the persistent backlog items).

## Auto-Fix Eligibility

Only fix findings marked `Auto-fixable: Yes`. If a finding lacks the field, treat as `No`. This tag is set by the reviewer during classification and indicates the fix is purely mechanical — no domain judgment needed.

## Nightly Mode: Finding Selection

Read `Knowledge/Plans/Backlog.md` and `Knowledge/Plans/api-drift.md` and merge their findings into a single pool. Also scan the current PR's review comment for any auto-fixable items with F-ids. Then filter:
1. **Status**: `OPEN` or `PLANNED`
2. **Risk**: `Low` only
3. **Effort**: ≤ 30 min (e.g., "5 min", "15 min", "30 min")
4. **Sort**: Impact descending (High → Medium → Low)
5. **Cap**: Top 5 per run
6. **Diversity cap**: At most 2 fixes where the only changed files are `.md` files (docs-only)
   - If 3+ of the top 5 are docs-only, replace the lowest-impact docs-only picks with the next-highest-impact code fixes from the qualifying pool
   - If no code fixes qualify, take all docs (don't skip valid fixes — just don't fill the entire run with docs)

If fewer than 5 qualify, take all that qualify. If none qualify, report "No actionable findings" and stop.

## API Drift Findings

In nightly/CI mode, also read `Knowledge/Plans/api-drift.md` as a second findings source. This registry is populated by autofix's Drift Triage step, which runs before the fix loop when raw test output is present in the prompt.

Drift findings follow the same `#### D{id}` format as code review `#### F{id}` entries, with the same `Auto-fixable` tag. Treat them identically in the fix loop with these additions:

- **File scope**: Drift fixes typically touch `Knowledge/steep-api.md`, `src/lib/resolvers/`, `src/lib/constants.ts`, and `tests/` files
- **Never modify the verification test itself** (`tests/nightly/steep-api-verification.test.ts`) to "fix" drift — that test is the source of truth. Fix the production code and docs instead.
- **ESCALATE status**: If a drift finding has status `ESCALATE`, do not attempt to fix it — it requires human judgment (e.g., removed endpoint, fundamental API redesign). Include it in the report as a blocked item.

If `Knowledge/Plans/api-drift.md` doesn't exist or has no OPEN findings, proceed with code review findings only.

## Explicit Mode: Finding Selection

Parse finding IDs from `$ARGUMENTS`. For each ID, look it up in this order:
1. **PR comment first** — scan the review comment for the F-id. Auto-fixable items from the current review live here.
2. **Registry fallback** — check `Knowledge/Plans/Backlog.md` and `Knowledge/Plans/api-drift.md` for the F-id.

For each found finding:
1. Verify it has `Auto-fixable: Yes`
2. If not safe, report why and skip it
3. If not found in either source, report "F{id} not found in PR comments or registry" and skip

## Local Mode: Ephemeral Findings

**Local mode** reads findings from `.claude/local-findings.json` — a file written by `@verify`'s Tier 3 review when run locally. This file contains review findings without F-ids, classified by severity.

### How it works

1. **Read `.claude/local-findings.json`** — if the file doesn't exist, report "No local findings found. Run `@verify` first to generate local review findings." and stop.
2. **Parse the JSON** — the file contains an array of finding objects:
   ```json
   [
     {
       "file": "src/lib/example.ts",
       "line": 42,
       "checklist": "checks-general.md §3",
       "description": "Unused import: 'foo'",
       "impact": "Low",
       "autoFixable": true,
       "fixHint": "Remove the unused import"
     }
   ]
   ```
3. **Filter**: Only fix findings where `autoFixable` is `true`
4. **Apply**: Use the same Core Fix Loop as other modes — delegate to sub-agents by directory
5. **Verify**: Run `npx tsc --noEmit` after fixes
6. **Clean up**: Delete `.claude/local-findings.json` after fixes are applied
7. **No registry updates**: Local findings are ephemeral — no Backlog.md or api-drift.md changes
8. **No commit**: The user runs `@commit` separately after reviewing the fixes

### When to use

After `@verify` reports local review findings, the agent can run `@autofix --local` to mechanically fix auto-fixable items (dead code, unused imports, stale comments). The agent then re-runs `@verify` to confirm fixes. This gives the agent a fast local loop: verify → autofix local → verify → commit → create-pr.

## Phase 1: Classify Drift

Runs **only** when the prompt contains `❌` lines from API verification output. If no `❌` lines are present, skip to the Core Fix Loop.

### Classification Rubric

Each `❌` line has the format: `  ❌ {checkId} {name} — {detail}` where `checkId` is a category letter + number (e.g., `B3`, `C2`).

Classify each failure using this deterministic table:

| Pattern | Cat | Auto-fixable | Action | Files |
|---|---|---|---|---|
| HTTP 4xx/5xx, timeout, connection refused | A | No | `ESCALATE` | — |
| `not found`, `got "X"` (identifier mismatch) | B | Yes | Rename identifier | `constants.ts`, `steep-api.md`, test `EXPECTED_METRICS` |
| `dimension`, `breakdown`, `unsupported` | C | Yes | Update dimension list | `constants.ts` JSDoc |
| Production query returns 0 rows / unexpected status | D | No | `ESCALATE` | — |
| Missing/extra field, wrong type in response | E | Conditional | `ESCALATE` unless simple field rename | `src/lib/resolvers/` |
| SUM/LATEST mismatch, non-monotonic cumulative | F | No | `ESCALATE` | — |
| Week alignment, mondayOffset constraint changed | G | Conditional | `ESCALATE` if constraint changed; fix if docs updated | `src/lib/resolvers/` |
| Row count 0, zero-fill gap | H | No | `OPEN` (may be transient) | — |

**Fallback**: if the pattern doesn't match any row, `ESCALATE`.

**Overrides**:
- B findings that touch a metric used in `src/lib/resolvers/` are still auto-fixable — rename both catalog entry and query in one fix
- C findings that remove a dimension used as a production filter → escalate (filter logic needs human judgment)

### Entry Creation Steps

1. **Extract check ID** from each `❌` line (first token after `❌`, e.g., `B3`)
2. **Map first letter** to category (A–H) using the rubric
3. **Apply the classification rubric** to determine `Auto-fixable` status
4. **Scan registry** (`Knowledge/Plans/api-drift.md`) for the highest `D{id}` in any section. Assign `D{n+1}`, `D{n+2}`, etc.
5. **Dedup**: if the same check ID already exists with status `OPEN`, skip it — do not create a duplicate entry
6. **Write new entries** to the `### OPEN` section of `Knowledge/Plans/api-drift.md`

### Entry Format

```markdown
#### D{id}: {checkId} {check name}
- **Category**: {letter} — {category name}
- **Status**: `OPEN` (or `ESCALATE` if not auto-fixable)
- **What**: {detail from test output}
- **Effort**: {estimate}
- **Risk**: {Low/Medium/High}
- **Impact**: {assessment}
- **Auto-fixable**: `Yes`/`No`
```

**Status defaults**:
- `Auto-fixable: Yes` → `Status: OPEN`
- `Auto-fixable: No` → `Status: ESCALATE`
- H category → `Status: OPEN` (may be transient)

After writing entries, proceed to the Core Fix Loop. The fix loop will pick up any entries with `Auto-fixable: Yes` and `Status: OPEN`.

## Core Fix Loop

For each finding to fix:

1. **Delegate to a sub-agent** using the `Agent` tool. Pass:
   - The file path(s) from the finding
   - The finding description and fix hint
   - Instruction: "Read the file, apply the narrowest fix, return: {file, finding-id, what-changed, succeeded: bool}"
   
2. **Sub-agent batching**: Group fixes by directory (first segment under `src/` or root). Batch 3-5 fixes per sub-agent. Run batches sequentially (they edit files). If a single batch has >5 fixes, split by subdirectory.

   Directory grouping examples:
   | Directory pattern | Batch name |
   |---|---|
   | `src/lib/**/*.ts` | Core lib |
   | `src/components/**/*` | Components |
   | `src/lib/server/**/*` | Server |
   | `Knowledge/*.md` | Knowledge docs |
   | `.claude/skills/**/*` | Skills & CI |

   Each sub-agent receives: the directory, the list of findings with file paths, fix hints, and the auto-fixable rationale.

3. **If a sub-agent fails**: Revert the fix (`git checkout -- <file>`), mark the finding as `PLANNED` in your results, and move on. Do NOT retry.

## Verification

After all fixes are applied, delegate verification to a sub-agent:

```
Run these commands and report only pass/fail summary:
1. npm run build
2. npm run lint  
3. npx tsx tests/run.ts smoke:shared

Return: "Build: ✅/❌ | Lint: ✅/❌ | Smoke: ✅/❌" plus any error details.
```

If verification fails:
1. Revert ALL fixes: `git checkout -- .`
2. Mark all findings as `PLANNED` (not fixed)
3. Report the failure

## Update Registries

Only update registry files for findings that actually exist in them. Many findings now live only in PR comments — if a fixed finding was from the PR comment and has no registry entry, skip the registry update for that finding.

Edit registry files using **in-place resolution** (never move entries between sections):

For `Knowledge/Plans/Backlog.md`:
- Only if the fixed finding exists in the backlog's Review Findings section (HIGH/MEDIUM non-auto-fixable items)
- Edit the Status line in-place: `- **Status**: `OPEN`` → `- **Status**: `RESOLVED` (Auto-fixed by @autofix — <date>)`
- Do NOT move the finding — leave it where it is
- Do NOT touch the RESOLVED section

For `Knowledge/Plans/api-drift.md`:
- Same in-place resolution pattern: edit the Status line within the OPEN section
- Change: `- **Status**: `OPEN`` → `- **Status**: `RESOLVED` (Auto-fixed by @autofix — <date>)`
- Update the History table at the bottom with today's date, categories affected, new/resolved/auto-fixed counts

## Stage Changes (CI mode only)

After completing all steps, stage the modified files:

1. `git add <specific files>` — stage each file that was modified (source fixes + `Knowledge/Plans/Backlog.md`)
2. Do **NOT** commit — the `@commit` skill handles commits in CI
3. Do **NOT** use `git add -A` or `git add .`

Files to stage:
- Every source file that was successfully fixed
- `Knowledge/Plans/Backlog.md` (only if finding entries were updated)
- `Knowledge/Plans/api-drift.md` (only if drift entries were updated)

## Report

Return a structured summary:

```
## Autofix Summary

**Mode**: <nightly | explicit | ci>
**Findings processed**: <count>
**Successfully fixed**: <count> (list IDs)
**Failed/skipped**: <count> (list IDs + reason)

### Fixes Applied
| Finding | File | What Changed |
|---------|------|-------------|
| <entries> |

### Verification
- Build: ✅/❌
- Lint: ✅/❌  
- Smoke: ✅/❌

### Registry Changes
#### Review Findings (`Knowledge/Plans/Backlog.md`)
<list moved from OPEN/PLANNED → RESOLVED>

#### API Drift (`Knowledge/Plans/api-drift.md`)
<list moved from OPEN → RESOLVED, or note "No drift findings">
```

## Error Handling

- If the registry file doesn't exist or is malformed → report error, don't crash
- If a finding references a file that doesn't exist → skip, mark as PLANNED
- If `Auto-fixable` field is missing from a finding → treat as `No`, skip it
- If git push fails → report error with details, don't retry
- If `$ARGUMENTS` is empty and not CI → print usage help