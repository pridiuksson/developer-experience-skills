---
name: work
description: "Execute a multica ticket end-to-end: fetch, verify preamble, execute scope, run verification commands, peer-review delivered work, complete. The agent executing the ticket uses its own judgment throughout."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - Write
  - Edit
argument-hint: "<ticket-identifier (e.g., MUL-15)>"
---

# Work — Execute a Multica Ticket

Pick up a ticket, verify it's still valid, execute the scope, prove the work is done, and complete it.

## Core Invariant

The ticket moves from `todo` → `in_progress` → `done` only when ALL acceptance criteria pass. No shortcuts.

---

## Process

### Step 1: Fetch the Ticket

```bash
multica issue get $ARGUMENTS --output json
```

Parse the response. Extract:
- `title`
- `description` (the ticket body)
- `status` — must be `todo` or `in_progress`. If `done`, report and stop.
- `identifier`

If the ticket doesn't exist, report the error and stop.

### Step 2: Preamble — Verify Before Starting

Read the ticket body's `⚠️ CRITICAL — Read Before Starting` section. Execute every instruction:

**2a. Read CLAUDE.md**

```
Read CLAUDE.md at the project root.
```

This is non-negotiable. The executing agent MUST load the operational instructions (Core Workflow, Working Style, Knowledge Base) before touching any code. Report: *"CLAUDE.md loaded. Core Workflow acknowledged."*

**2b. Check Dependencies**

The ticket body lists dependencies as ticket identifiers (e.g., MUL-5, MUL-7). For each:

```bash
multica issue get <dep-id> --output json | jq -r '.status'
```

- If `done` → dependency met. Continue.
- If `todo` or `in_progress` → dependency NOT met. **Stop.** Report: *"⛔ Blocked: <dep-id> (<title>) is <status>. Cannot proceed."* Also: update the ticket with a comment noting the blocker so there's visibility. Report the blocker to the user with the specific ticket IDs.
- If dependency not found → warn but continue (may have been removed or renumbered).

**2c. Verify Claims**

The ticket body makes claims about the codebase (file paths, function signatures, exports, current content). For each concrete claim:

- File path exists? → `ls <path>` or `test -f <path>`
- Export exists? → `grep -n 'export.*<name>' <path>`
- Content matches? → `grep -n '<expected content>' <path>`

If reality matches → note it, proceed.
If reality differs → **do not stop**. Note the discrepancy, trust reality, and adjust the execution plan accordingly. The ticket body warned you it might be outdated.

**Also verify the verification commands themselves.** The ticket's "How to Verify" section may reference stale commands (e.g., `npm run test` when the project uses `bun test`). If a command doesn't work, find the correct alternative — but only if you can confirm the work was done correctly.

**Report preamble results:**

```
## Preamble Check

- CLAUDE.md: ✅ Loaded
- Dependencies: ✅ MUL-5 (done), ✅ MUL-7 (done)
- Claims verified: 5/6 ✅, 1 ⚠️ adjusted
  - ⚠️ "src/lib/extraction.ts exports extractFields" → actually exports `extractInvoiceFields`. Adjusted.
```

### Step 3: Move to In Progress

```bash
multica issue status $ARGUMENTS in_progress --output json
```

### Step 4: Plan Before Executing

Before writing any code, read the ticket's `## Current State` and `## Desired State` sections and form a brief implementation plan:

1. What files will I change?
2. What's the order of operations?
3. Are there any risks or ambiguities?
4. Does anything in `## Not in Scope` look like it might accidentally get pulled in?

If the desired state is unclear or seems wrong after preamble verification, **pause and report**. Don't guess at intent.

### Step 5: Execute the Scope

Transform the codebase from `## Current State` to `## Desired State`. The ticket defines the destination — you figure out the path.

**Execution rules:**

1. **Follow the scope as written** — but adjust where preamble verification found discrepancies. Trust reality over the ticket body.
2. **Smallest change, biggest impact** — don't gold-plate. Don't add things the ticket didn't ask for.
3. **If you encounter something unexpected** (file deleted, assumption invalidated, need >2× planned effort):
   - **Minor** (extra param, moved lines, non-blocking bug): note it, continue.
   - **Major** (file deleted, core assumption wrong, blocked by external issue): **pause**. Write a discovery note. Report to the user. Do not silently push through a major blocker.
4. **Respect `## Not in Scope`** — do not implement things the ticket explicitly excludes. If you think an excluded item should be included, report it to the user rather than deciding yourself.
5. **Use other skills when appropriate** — if the ticket says "use `@commit`", invoke that skill. If it says "run `@eval`", invoke that skill. The ticket is the task description; the skills are the tools.
6. **No partial commits** — don't commit half-done work. Execute the full scope, then commit.

### Step 6: Verify

Run every command in the ticket's `## How to Verify` section. For each:

- ✅ Pass → note it
- ❌ Fail → **fix the issue**, then re-run. Do not proceed past a failing verification command.

If a verification command itself is wrong (e.g., the grep pattern doesn't match what it should), find the correct alternative and confirm the work is done — but document the discrepancy.

**Report verification results:**

```
## Verification

- [ ] `grep -rn 'Steep' .claude/skills/commit/` → ✅ zero results
- [ ] `npx tsc --noEmit` → ✅ clean
- [ ] `npm run build` → ✅ clean
```

### Step 7: Peer Review (Acceptance Gate)

This is the final acceptance step. Use `@peer-review` to get a second opinion on ALL delivered work.

**How**: Run the peer-review script via Bash:

```bash
.claude/skills/peer-review/peer-review.sh "<prompt>"
```

Set `cd` to `"Pit 1"`. Set `timeout_ms` to 300000.

**The prompt** — construct it from the actual work done:

```
You are reviewing completed work on a ticket. The agent claims the following changes are correct and complete.

Ticket: <identifier> — <title>

Changes made:
<list each file changed and what was done — be specific>

Verification results:
<copy the verification report from Step 5>

Questions:
1. Are the changes correct? Anything that looks wrong or incomplete?
2. Were any files changed that SHOULDN'T have been?
3. Were any files NOT changed that SHOULD have been?
4. Do the changes introduce any new risks or regressions?
5. Is there anything the agent missed or handwaved?
```

**After peer review — exit criteria:**

1. **No blocking issues against acceptance criteria** → proceed to Step 8 (complete).
2. **Blocking issues identified** → fix, re-verify (Step 6), re-review once. If still blocked after second review → surface to user with the specific issues. Do NOT mark ticket done.
3. **Non-blocking suggestions** → use your judgment. Accept valid improvements, skip cosmetic nits.

**Maximum re-review cycles: 1.** If issues persist after fix + re-review, the ticket needs human input.

### Step 8: Complete

Only after Steps 4–6 all pass:

```bash
multica issue status $ARGUMENTS done --output json
```

**Sync `Knowledge/multica.md`**: Update the ticket's status in the tracking table from `todo`/`in_progress` to `done`.

⚠️ **If multica status update succeeds but multica.md sync fails**, the ticket is done in the system but the knowledge file is stale. Retry the sync once. If it still fails, report the inconsistency to the user.

### Step 9: Report

```
## Ticket Complete: $ARGUMENTS — <title>

**Status**: `done`
**Preamble**: <N> deps checked, <M> claims verified
**Scope**: <N> items executed
**Verification**: <N>/<N> passed
**Peer review**: <summary of feedback + what was addressed>
**multica.md**: Synced
```

---

## Error Handling

| Condition | Action |
|-----------|--------|
| Ticket not found | Report error, stop |
| Ticket already `done` | Report status, stop |
| Dependency not met | Report blocker to user with ticket IDs, stop — do not start work |
| Verification command fails | Fix, re-run. Do not proceed past failures. |
| Peer review identifies real issue | Fix, re-verify, re-review once. Still blocked → surface to user. |
| `multica issue status` fails | Report error, do not retry blindly |
| Major unexpected blocker during execution | Pause, report to user, wait for guidance |

## Anti-Patterns

| # | Don't | Do |
|---|-------|----|
| 1 | Skip the preamble | Always verify claims, check deps, read CLAUDE.md — the ticket body warned you it might be stale |
| 2 | Blindly follow outdated ticket text | Trust reality. If a file path is wrong, find the right one. If an API changed, adapt. |
| 3 | Skip peer review "because I'm sure it's correct" | Peer review is the acceptance gate. Always run it. |
| 4 | Accept all peer feedback without thinking | Use your judgment. Push back on wrong feedback. Accept valid criticism. |
| 5 | Commit half-done work | Execute fully: achieve Desired State, verify, peer-review, then commit. |
| 6 | Move ticket to `done` without syncing multica.md | The doc and the backend must stay in sync. |

## When to Use

```
Have a ticket to execute?
├── @work MUL-15
├── @work MUL-16
└── Don't have a ticket yet? → @ticket "<description>" first
```
