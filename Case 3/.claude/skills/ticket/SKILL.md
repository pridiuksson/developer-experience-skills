---
name: ticket
description: "Create well-structured, agent-ready tickets in multica. Scans codebase for evidence, enforces consistent format, peer-reviews the ticket body before creation, and syncs Knowledge/multica.md. Tickets carry a mandatory preamble instructing executing agents to verify all claims and follow CLAUDE.md."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - Write
  - Edit
argument-hint: "<description of what to ticket — single task or batch directive>"
---

# Ticket — Agent-Ready Ticket Authoring

Create well-structured, self-contained tickets in multica that any agent can pick up with zero conversation history.

## Core Invariant

After this skill runs, `Knowledge/multica.md` and the multica backend are in sync. No manual bookkeeping.

---

## Process

### Step 1: Understand the Ask

Read `$ARGUMENTS`:
- If it's a description of a single task → create one ticket
- If it's a batch directive (e.g., "create one ticket per skill that needs adaptation") → identify the individual tasks, then create one ticket per task
- If empty → ask the user what they want to ticket, then proceed

**Do NOT start creating tickets yet.** Present the plan first:

> "I'll create [N] tickets: [list of titles]. Each will be peer-reviewed before creation. Proceed?"

### Step 2: Gather Evidence

For each ticket, scan the codebase to gather concrete evidence:

- **File paths mentioned** — verify they exist
- **Stale references** — grep for patterns that indicate outdated state (e.g., other project names, placeholder text, TBDs)
- **Dependencies** — check what must be in place before this ticket can be executed
- **Verification commands** — determine what grep/build/test commands can validate the work

This evidence becomes part of the ticket description. A fresh agent receiving the ticket should not need to do exploratory research — the ticket already contains the relevant facts.

### Step 3: Draft Ticket Body

Each ticket body MUST follow this exact structure:

```
## ⚠️ CRITICAL — Read Before Starting

**This ticket body may be outdated.** It was written at a point in time and the codebase may have changed since. You MUST:

1. **Verify all claims yourself** — every file path, export name, function signature, and dependency mentioned below. Read the actual files (prioritize the filesystem over Knowledge/ docs). Example: if the ticket says `extraction pipeline exists at lib/extract.ts`, check that the file and function actually exist.
2. **Read `CLAUDE.md` at the project root** (same directory as this repo's `.git`) — this is your operational instruction manual. Follow its Core Workflow and Working Style.
3. **If a dependency listed below is NOT met** (e.g., a ticket it depends on is not `done`), stop and report. Do not proceed on unmet dependencies.

**Project context**: This is a 5-hour interview prototype — Next.js + Shadcn UI + Vercel AI SDK + Zod + VLM (GLM-OCR or GPT-4o) + TypeScript. No database, synthetic data only. Deployed on Vercel.

---

## Context

[1–2 sentences: why this ticket exists and what problem it solves. Written for an agent with ZERO conversation history.]

## Current State

[What exists right now. Concrete: file paths, line ranges, actual content. No "see conversation" — the ticket IS the context.]

## Desired State

[What should exist after this ticket is done. Be concrete: file paths, exports, behavior. This is the destination — the agent figures out the path. Each item should be independently verifiable against the Current State above.]

## Not in Scope

[Explicit exclusions. What this ticket deliberately does NOT do. Prevents scope creep and keeps the agent focused.]

## How to Verify

[Commands to run and what the expected output is. Each command must be falsifiable — it would fail if the work was done incorrectly.]

```bash
# Example verification commands
grep -rn '<pattern>' <path>  # Should return zero results
npx tsc --noEmit             # Should pass
```

## Dependencies

[Which other tickets must be `done` before this one can start. Listed by identifier and title. If none, state "None — can start immediately."]

## Acceptance

This ticket is NOT done until ALL of the following pass:

1. [ ] Every verification command in "How to Verify" passes
2. [ ] No placeholder text remains (no `TBD`, `_Populate..._`, or `TODO` in delivered work)
3. [ ] The Desired State is fully achieved — every concrete item in that section is realized
4. [ ] Nothing from "Not in Scope" was implemented
5. [ ] **Peer review**: Use `@peer-review` to get a second opinion on all delivered work. Present the changes made and ask: "Does this look correct? What did I miss?" React to the feedback using YOUR OWN judgment — accept valid criticism, push back on things you've already handled. Do NOT blindly accept all feedback.
```

**Rules for the body**:
- No references to "the conversation" or "as discussed" — the ticket is self-contained
- Every file path must actually exist at the time of writing (verified in Step 2)
- Every grep/verification command must be runnable from the repo root and produce deterministic output (not human-readable descriptions like "check the file")
- Dependencies reference ticket identifiers (e.g., MUL-5) not vague descriptions
- Verify each "How to Verify" command is correct by running it during drafting (Step 2) if possible

### Step 4: Peer-Review the Ticket Body

Before creating any ticket, use `@peer-review` to stress-test the ticket body.

**How**: Run the peer-review script via Bash:

```bash
.claude/skills/peer-review/peer-review.sh "<prompt>"
```

Set `cd` to `"Pit 1"`. Set `timeout_ms` to 300000.

**The prompt**:
```
You are reviewing a ticket description for a software project. The ticket will be assigned to an AI agent with ZERO conversation history. The agent will ONLY have this ticket body as context.

Ticket title: <title>

Ticket body:
<ticket body>

Answer these questions:
1. Is every file path verifiable? Could an agent find every file mentioned?
2. Is every claim specific enough to be falsified? (Vague claims = agent will guess)
3. Are the verification commands correct and runnable?
4. Is there any assumed context that's NOT in the ticket? (References to "the plan", "our discussion", etc.)
5. Could a competent agent complete this ticket WITHOUT asking the user for clarification?
6. What's missing? What would make this ticket more actionable?
```

**After peer review**: Incorporate valid feedback. If the peer identifies missing context or vague claims, fix them. If the peer's feedback is already covered, note it and move on. Use YOUR judgment — don't blindly accept all suggestions.

**For batch tickets**: Peer-review the first ticket in a batch fully (the template-setter). Subsequent tickets can skip individual peer review ONLY IF they follow the exact same structure and the peer found no structural issues on the first. If the peer found structural issues, fix the template and re-review the next one. Document the shared pattern explicitly (e.g., "All tickets follow: grep for X → update Y → verify Z") so the skip is justified.

### Step 5: Create Tickets via CLI

For each ticket:

Get the project ID from `Knowledge/multica.md` (field: Project ID). Then:

```bash
multica issue create \
  --title "<title>" \
  --description "<ticket body>" \
  --project <project-id> \
  --output json
```

Parse the JSON response. Extract `identifier` (e.g., MUL-20).

**Error handling**:
- If CLI fails → report the error, stop. Do not retry without understanding the failure.
- If `--description` is too long for a single command → write the body to a temp file and pass via stdin if the CLI supports it, or trim to essentials.

### Step 6: Report

Present a summary:

```
## Tickets Created

| ID | Title | Depends On |
|----|-------|------------|
| MUL-20 | ... | MUL-5, MUL-7 |
| MUL-21 | ... | None |

**Multica.md**: Updated with [N] new entries in [section name].
**Peer review**: [N/N] tickets peer-reviewed before creation.
```

---

## Anti-Patterns

| # | Don't | Do |
|---|-------|----|
| 1 | Write vague tickets ("update the docs") | Write specific tickets with Current State → Desired State transitions, file paths, and verification commands |
| 2 | Reference conversation context ("as we discussed") | The ticket IS the context — make it self-contained |
| 3 | Skip peer review for "obvious" tickets | Peer review catches vague claims and missing context — always review at least the first in a batch |
| 4 | Create tickets without syncing multica.md | The doc and the backend must stay in sync |
| 5 | Write verification commands that can't fail | Every command must be falsifiable — "grep returns zero results" not "check the file" |
| 6 | Skip the CRITICAL preamble | Every ticket MUST have the preamble. The executing agent has no other context. |
| 7 | Leave Desired State vague ("improve the code") | State exactly what should exist: "File X exports function Y with signature Z" |
| 8 | Skip "Not in Scope" | Explicit exclusions prevent scope creep. Always state what this ticket does NOT do. |

## When to Use

```
Need to create work items for the backlog?
├── Single task → @ticket "<description>"
├── Batch of related tasks → @ticket "<batch directive>"
└── Just updating an existing ticket? → Use multica CLI directly, this skill is for creation
```
