# [Feature Name]

> **Status**: Planning
> **Created**: [date]
> **Tier**: Full

---

## Overview

[1–2 sentences: what we're building and why.]

## Current State vs Desired State

### Desired State — High-Level Overview

[3–6 sentences: paint the picture of what the system looks like after all phases ship. What can a user do that they couldn't before? What changed for developers? What's simpler, faster, or more reliable? Keep it concrete — no "improved experience" without saying what improves. This is the elevator pitch for the entire plan.]

### Current State

_Verified [date] by reading the codebase._

| Aspect | Status | Notes |
|--------|--------|-------|
| [Relevant aspect] | ✅ / ⚠️ / ❌ | [What exists, what's broken, what's missing] |

### Desired State — Detailed

| Aspect | Current | Desired | Gap |
|--------|---------|---------|-----|
| [Aspect] | [What exists now] | [What should exist] | [What needs to change — the delta] |

## Research Findings

| ID | Question | Status | Finding |
|----|----------|--------|---------|
| R1 | [Question] | ✅ / ❌ | [One-paragraph finding] |
| R2 | [Question] | ✅ / ❌ | [One-paragraph finding] |

_Unresolved research items block the phases that depend on them._

## What's NOT in Scope

[Explicit exclusions to prevent scope creep.]

## Key Invariants

_Rules that must not be violated during implementation._

- [Invariant — e.g., "Fire-and-forget logging must not block responses"]

## Dependency Graph

_Express as waves — phases that can execute simultaneously share a wave. A serial plan is just "each wave has 1 phase."_

```
Wave 1: Phase 1 — [name] (no deps)
Wave 2: Phase 2 — [name] (depends on Phase 1)
         Phase 3 — [name] (depends on Phase 1)  ← parallel with Phase 2
Wave 3: Phase 4 — [name] (depends on Phase 2 + Phase 3)
```

## Dependency Analysis

_Every artifact a phase consumes must trace to a source (codebase or earlier phase). Build the dependency graph from this table, not from intuition._

| Phase | Consumes (artifact → source) | Produces (artifact → used by) |
|-------|------------------------------|-------------------------------|
| 1 | (nothing — foundation) | [artifacts produced] → [phases that use them] |
| 2 | [artifact] → (codebase or Phase N) | [artifacts produced] → [phases that use them] |
| 3 | [artifact] → (Phase N) | [artifacts produced] → [phases that use them] |

---

## Phase 1: [Descriptive Name — What Ships]

**Ships**: [What's working after this phase — be concrete]
**Depends on**: [Wave N — Phase(s) this consumes output from. "Nothing" for Wave 1. Be specific: name the artifact, not just the phase number.]
**Research basis**: R1, R3 (findings inlined below)
**Estimated scope**: ~[N] files

### Changes

#### `path/to/file.ts` — [What changes and why]

**Current**:
```
// actual current code from the file
```

**Replace with**:
```
// what the new code should look like (or a pattern reference:
// "Follow the pattern in `other-file.tsx:L45`")
```

**Design decision**: [What was chosen, why, what was rejected — only when non-obvious.]

_Repeat the Current/Replace/Decision block for each location this phase changes._

#### [Optional: Research findings relevant to this phase]
_Inline any research findings that constrain this phase's implementation. Do not cross-reference "see R5" — copy the finding here._

- **R1**: [Finding summary — the specific answer this phase depends on]
- **R3**: [Finding summary]

#### [Optional: Constraints from other phases]
_State as concrete artifacts, not cross-references._

- `someExport` exists with signature `(ctx) => Result` — produced by Phase N
- `tableName` table has columns `[...]` — created by Phase M

### Ship Gate

**Phase-specific proof** (pick from Common Gate Patterns above, or see `ship-gates.md` for rare archetypes):
- [ ] [Never use `localhost`. Use `curl` against the PR preview deployment (`curl https://<preview>/api/…`), or defer to manual verification on preview. If preview URL is unknown, write as placeholder: the executing agent fills it in once the preview is live.]

**Build gate** (every phase):
- [ ] `npx tsc --noEmit && npm run lint && npm run build` — clean

**Functional tests** (select suite via `/test` skill):
- [ ] `npx tsx tests/run.ts <suite>` — passes

**Anti-regression** (skip for Phase 1):
- [ ] Previous phase's gate still passes

**Do not proceed to Phase {N+1} until this gate passes.**

### Reflection Focus

- **R1 (before starting)**: [What to verify is still true before investing work]
- **R2 (after gate passes)**: [What to check for downstream impact]

### Reflections

_Populated during execution. See Execution Protocol._

---

## Phase 2: [Descriptive Name — What Ships]

**Ships**: [What's working after this phase — be concrete]
**Depends on**: [Phase N — specific artifact consumed]
**Research basis**: R2 (findings inlined below)
**Estimated scope**: ~[N] files

### Changes

[Same Current/Replace/Decision format as Phase 1]

### Ship Gate

[Same structure as Phase 1]

### Reflection Focus

- **R1 (before starting)**: [What to verify is still true before investing work]
- **R2 (after gate passes)**: [What to check for downstream impact]

### Reflections

_Populated during execution. See Execution Protocol._

---

## Latent Issues

_Pre-existing bugs or fragilities discovered during research.
Each must be assigned to a phase or explicitly scoped out — no unassigned items._

| ID | Severity | Description | Fix In | Status |
|----|----------|-------------|--------|--------|
| L1 | High/Med/Low | [File:line — what's wrong, why it matters] | Phase N | ⬜ / ✅ Fixed |

## Deferred Work

_Items considered but consciously postponed._

| Item | Reason | Unblocks when |
|------|--------|---------------|
| [Deferred item] | [Why not now] | [Condition for un-deferring] |

## Cross-Plan Dependencies

_[If applicable — when this plan depends on or feeds into other plans.]_

| Prerequisite | Source Plan | Phase/Step | Blocking? | Notes |
|---|---|---|---|---|
| [Artifact] | [other-plan.md] | Phase N | Yes/No | [Context] |

## Schema

_[If applicable — for plans that add or modify database tables.]_

[Column-by-column descriptions with nullability semantics, design rationale, index strategy.]

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| [Specific risk] | High/Med/Low | [How to handle] |

## New Environment Variables

_[If applicable — deployment checklist for ops.]_

| Variable | Purpose | Required by |
|----------|---------|-------------|
| `EXAMPLE_VAR` | [What it does] | Phase N |

## Related Docs

- `Knowledge/development.md` — [relevant section]
- `.claude/skills/test/reference.md` — test inventory, gotchas, coverage status (if tests change)

## Common Gate Patterns

_Quick reference for the most common phase types. See `ship-gates.md` for full archetype reference (schema, refactor, integration, data pipeline, regression risk)._

### Build Gate (every phase)
```bash
npx tsc --noEmit && npm run lint && npm run build
```

### API Route / Server Action
- [ ] Happy path: `curl` against PR preview deployment with valid input → expected status + output (never `localhost`)
- [ ] Auth guard: `curl` without credentials → 401/403
- [ ] Error path: upstream failure → error response (not hang/crash)

### UI Component / Tab
- [ ] Renders without JS errors in console
- [ ] Expected content appears (accessibility snapshot)
- [ ] Interactive behavior works (clicks, navigation)
- [ ] Visual check on preview deployment

### Anti-Regression (Layer 4, every phase after Phase 1)
- [ ] Previous phase's gate still passes

---

## Execution Protocol

_Self-contained instructions for the agent executing this plan. Follow these when working through phases._

### Orientation

1. Read the full plan. Note the Status header and which phases are ✅ / ▶️ / ⬜.
2. For each item in Current State marked ✅, spot-check it still exists (read the file, check the export). Flag phantom references immediately.
3. Check for codebase changes: `git log --oneline --since="[plan date or last reflection date]" -- [files next phase touches]`
4. Update the Current State table if anything changed.

### Phase Lifecycle

For each phase, follow this sequence:

```
R1 → Implement → Ship Gate → R2 → Commit → Next Phase
```

**R1 (Pre-Phase Reflection)** — before writing any code, ask yourself:
1. In one sentence, what does this phase deliver? Does that still match the plan?
2. Has any file this phase modifies changed since the plan was written? (`git diff`)
3. What did research assume about this code? Read the actual files — does reality match?
4. Are any deferred items now blocking? Should any be un-deferred?
5. Does this phase produce outputs consumed by later phases — are those still correct?
6. Read this phase's **Reflection Focus → R1** for phase-specific checks.

**Implementation** — write the code. If you encounter something unexpected, assess immediately:
- Minor (extra param, moved lines, non-blocking bug): note it, continue
- Major (file deleted, assumption invalidated, need >2× planned files): stop, write a discovery note in Reflections, revise the plan, present to user

**Ship Gate** — run all checks. Binary pass/fail. Fix failures before proceeding.

**R2 (Post-Phase Reflection)** — after the gate passes, ask yourself:
1. Did the implementation match the plan? If not, what changed and why?
2. Did I notice anything fragile or problematic? (Name it: file and line.)
3. Does anything I built or discovered change later phases?
4. Review deferred items — still correctly deferred? New items to add?
5. Did I build anything not in the plan? Was it necessary?
6. Does any Knowledge/ doc now contain stale info?
7. Read this phase's **Reflection Focus → R2** for phase-specific checks.

**Commit** — commit after each phase passes its ship gate. Use `@commit`. Reference the plan and phase in the commit scope (e.g., `feat(user-settings): phase 2 — context wiring`).

### Recording Reflections

Write a snapshot to the phase's `### Reflections` section:

```
#### [R1/R2/Discovery] — Phase [N] — [date]

| Dimension      | Status |
|----------------|--------|
| Goal alignment | ✅ / ⚠️ [reason] / ❌ [reason] |
| Assumptions    | ✅ / ⚠️ [what changed] |
| Deferred items | ✅ / ⚠️ [item] should move |
| Downstream     | ✅ / ⚠️ Phase [M] needs [change] |
| Codebase state | ✅ / ⚠️ [file] changed |

**Findings**: [One sentence per finding. Max 5.]
**Decision**: [Continue / Adjust: {what} / Revise plan: {sections}]
```

Rules: 5 rows exactly. One-sentence findings. One-sentence decision. Never edit after writing.

### Status Tracking

Update the plan's Status header as you work:

| Marker | Meaning |
|--------|---------|
| ⬜ | Not started |
| ▶️ | In progress |
| ✅ | Ship gate passed, R2 clean |
| ⚠️ | Ship gate passed, R2 found issues |
| ❌ | Blocked (with reason) |

Update Current State, Latent Issues, and Deferred Work tables after each R2.

### Parallel Phases

When the dependency graph shows parallel phases:

- **Sequential execution** (default): execute each phase in order within one session. Simpler, no merge conflicts.
- **Parallel delegation**: when phases are self-contained (all file paths, code snippets, research findings, and gates inlined), each can be dispatched to a separate subagent. Each subagent gets exactly one phase — no need to read the full plan. Each parallel phase gets its own R1/R2 cycle.
- **Separate worktrees**: if the user requests it. Each parallel phase gets its own worktree and R1/R2 cycle.

For parallel delegation, the delegating agent must verify each subagent's output meets the ship gate before marking the phase ✅.

### Completion

When all phases are ✅:
1. **Doc-impact scan** — grep across `Knowledge/` for mentions of what changed. Update any stale references.
2. **Diagnostic scripts** — if data shapes or API patterns changed, check diagnostic scripts (e.g., `capture-l1.ts`) for consistency.
3. **Knowledge audit** — for each item in Latent Issues and Deferred Work, verify it exists in a canonical `Knowledge/` doc. If not, migrate it now. The plan is about to be deleted — anything only in the plan will be lost.
4. Update Status header to `> **Status**: Complete — [date]`
5. Run `@verify` as a final gate
6. **Plan disposition** — if all knowledge has been migrated to canonical docs (types in code, patterns in Knowledge/ md, items in Backlog.md), delete the plan file. Otherwise, keep as historical reference.

### Context Compression (for long-running plans)

After 3+ phases complete, compress older reflection snapshots:
```
#### R1 — Phase 1 — 2026-04-14 — ✅ All clear.
```
Keep full tables for: last 2 phases + any with ⚠️ / ❌.
Collapse completed phase details to a one-paragraph summary. Keep ship gate checklists.
