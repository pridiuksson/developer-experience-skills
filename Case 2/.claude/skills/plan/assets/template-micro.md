# [Feature Name]

> **Status**: Planning | **Created**: [date] | **Tier**: Micro

---

## Overview
[1–2 sentences: what we're changing and why.]

## State Transition

**Current**: [What exists today — one sentence.]
**Desired**: [What should exist after this plan — one sentence.]

---

## Phase 1: [Descriptive Name — What Ships]

**Ships**: [What's done after this phase]
**Scope**: ~[N] files

### Changes
- `path/to/file` — [what changes and why]

### Ship Gate
- [ ] Read the file end-to-end after editing and verify the logic flow is correct
- [ ] Previous phase's gate still passes (skip for Phase 1)

### Reflections
_Populated during execution._

---

## Phase 2: [Descriptive Name — What Ships] _(optional)_

**Ships**: [What's done after this phase]
**Scope**: ~[N] files

### Changes
- `path/to/file` — [what changes and why]

### Ship Gate
- [ ] Read the file end-to-end after editing and verify the logic flow is correct
- [ ] Previous phase's gate still passes

### Reflections
_Populated during execution._

---

## Execution Protocol

For each phase: **R1 → Implement → Ship Gate → R2 → Commit**.

**R1 (before editing)**: What does this phase deliver? Has anything changed since the plan was written? (`git diff`)

**Ship Gate**: Binary pass/fail. Fix before proceeding.

**R2 (after gate passes)**: Did implementation match plan? Anything fragile? Does anything change later phases?

**Commit**: Use `@commit` after each phase. Reference plan + phase in scope.

**Status markers**: ⬜ Not started → ▶️ In progress → ✅ Complete → ⚠️ Issues found → ❌ Blocked

**Completion**:
1. **Doc-impact scan** — grep across `Knowledge/` for mentions of what changed. Update any stale references.
2. Update Status to `Complete — [date]`.
3. **Plan disposition** — if all knowledge has been migrated to canonical docs, delete the plan file. Otherwise, keep as historical reference.

### Self-Review

Before final commit, check:

- [ ] No orphan code — every change serves the stated goal
- [ ] No vague gates — every gate is independently verifiable
- [ ] No deferred testing — if code runs, it's tested
- [ ] No unresolved research blocks — all open questions answered
- [ ] No overengineering — could any phase be removed or simplified without losing core value? Would a human engineer plan it this way?
