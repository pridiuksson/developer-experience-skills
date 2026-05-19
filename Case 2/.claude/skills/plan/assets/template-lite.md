# [Feature Name]

> **Status**: Planning | **Created**: [date] | **Tier**: Lite

---

## Overview
[1–2 sentences: what we're building and why.]

## Current State vs Desired State

### Desired State — High-Level Overview
[2–4 sentences: paint the picture of what the system looks like after all phases ship. What can a user do? What changed for developers? Keep it concrete — no "improved experience" without saying what improves.]

### Current State
_Verified [date]._

| Aspect | Status | Notes |
|--------|--------|-------|
| [Aspect] | ✅ / ⚠️ / ❌ | [Status] |

### Desired State — Detailed

| Aspect | Current | Desired | Gap |
|--------|---------|---------|-----|
| [Aspect] | [What exists now] | [What should exist] | [What needs to change] |

## Research Findings
_Optional — delete if unused._

- **R1**: [Question] — ✅/❌ [One-line finding or "Unresolved — blocks Phase N"]
- **R2**: [Question] — ✅/❌ [One-line finding]

## Dependency Graph
_Serial plans: just list the chain. Only use wave notation if phases can run in parallel._

```
Phase 1 → Phase 2 → Phase 3
```

_Or, if parallelism exists:_

```
Wave 1: Phase 1 — [name]
Wave 2: Phase 2 — [name] (depends on Phase 1)
Wave 3: Phase 3 — [name] (depends on Phase 2)
```

---

## Phase 1: [Descriptive Name — What Ships]

**Ships**: [What's working after this phase]
**Depends on**: Nothing
**Research basis**: R1 _(delete if no research findings apply)_
**Scope**: ~[N] files

### Changes
- `path/to/file.ts` — [what changes and why]

### Ship Gate
_Pick the gate pattern that matches this phase's deliverable:_

**Code changes** (touches `.ts`, `.tsx`, etc.):
- [ ] `npx tsc --noEmit && npm run lint && npm run build` — clean
- [ ] [Phase-specific proof — use `curl` against the PR preview deployment (`curl https://<preview>/api/…`), or defer to manual verification on preview. If preview URL is unknown, write as placeholder: the executing agent fills it in once the preview is live.]
- [ ] Previous phase's gate still passes (skip for Phase 1)

**Config/docs changes** (touches `.md`, `.yml`, `.claude/skills/*`, workflows):
- [ ] Read the file end-to-end after editing and verify the logic flow is correct
- [ ] Previous phase's gate still passes (skip for Phase 1)

### Reflections
_Populated during execution._

---

## Phase 2: [Descriptive Name — What Ships]

**Ships**: [What's working after this phase]
**Depends on**: Phase 1 — [specific artifact consumed]
**Research basis**: R1 _(delete if no research findings apply)_
**Scope**: ~[N] files

### Changes
- `path/to/file.ts` — [what changes and why]

### Ship Gate
_Pick the gate pattern that matches this phase's deliverable:_

**Code changes** (touches `.ts`, `.tsx`, etc.):
- [ ] `npx tsc --noEmit && npm run lint && npm run build` — clean
- [ ] [Phase-specific proof]
- [ ] Previous phase's gate still passes

**Config/docs changes** (touches `.md`, `.yml`, `.claude/skills/*`, workflows):
- [ ] Read the file end-to-end after editing and verify the logic flow is correct
- [ ] Previous phase's gate still passes

### Reflections
_Populated during execution._

---

## Phase 3: [Descriptive Name — What Ships] _(optional)_

**Ships**: [What's working after this phase]
**Depends on**: Phase 2 — [specific artifact consumed]
**Research basis**: R1 _(delete if no research findings apply)_
**Scope**: ~[N] files

### Changes
- `path/to/file.ts` — [what changes and why]

### Ship Gate
_Pick the gate pattern that matches this phase's deliverable:_

**Code changes** (touches `.ts`, `.tsx`, etc.):
- [ ] `npx tsc --noEmit && npm run lint && npm run build` — clean
- [ ] [Phase-specific proof]
- [ ] Previous phase's gate still passes

**Config/docs changes** (touches `.md`, `.yml`, `.claude/skills/*`, workflows):
- [ ] Read the file end-to-end after editing and verify the logic flow is correct
- [ ] Previous phase's gate still passes

### Reflections
_Populated during execution._

---

## Notes

### Latent Issues
_Optional — pre-existing bugs discovered during research.
Each must be assigned to a phase or explicitly scoped out — no unassigned items. Delete if unused._

- **L1** ([High/Med/Low]): [file — what's wrong] — Fix In: Phase [N] (or "Scoped out: {rationale}") — ⬜/✅ Fixed

### Deferred Work
_Optional — items considered but postponed. Delete if unused._

- [Item] — [Why not now] — [Condition for un-deferring]

---

## Execution Protocol

For each phase: **R1 → Implement → Ship Gate → R2 → Commit**.

**R1 (before coding)**: What does this phase deliver? Has anything changed since the plan was written? (`git diff`)

**Ship Gate**: Binary pass/fail. Fix before proceeding.

**R2 (after gate passes)**: Did implementation match plan? Anything fragile? Does anything change later phases?

**Commit**: Use `@commit` after each phase. Reference plan + phase in scope.

**Status markers**: ⬜ Not started → ▶️ In progress → ✅ Complete → ⚠️ Issues found → ❌ Blocked

**Completion**:
1. **Doc-impact scan** — grep across `Knowledge/` for mentions of what changed. Update any stale references.
2. **Diagnostic scripts** — if data shapes or API patterns changed, check diagnostic scripts for consistency.
3. **Knowledge audit** — for each item in Latent Issues and Deferred Work, verify it exists in a canonical `Knowledge/` doc. If not, migrate it now.
4. Update Status to `Complete — [date]`.
5. Run `@verify` as final gate.
6. **Plan disposition** — if all knowledge has been migrated to canonical docs, delete the plan file. Otherwise, keep as historical reference.

### Self-Review

Before presenting, spawn a review subagent with the 8 checks (or apply the 5 Micro checks yourself for very small plans). See `@plan` Step 6 for the full checklist and subagent prompt template.

Quick reference — check all 8:

- [ ] No orphan code — every change serves the stated goal
- [ ] No vague gates — every gate is independently verifiable
- [ ] No deferred testing — if code runs, it's tested in the same phase
- [ ] No unresolved research blocks — all open questions answered
- [ ] No overengineering — could any phase be removed or simplified without losing core value? Would a human engineer plan it this way?
- [ ] No horizontal slicing — each phase ships something testable end-to-end
- [ ] No foundation-only phases — no phase that only creates types/stubs
- [ ] No giant phases — no phase mixing independent subsystems
