---
name: plan
description: "Create implementation plans with vertically-sliced, independently-verifiable phases. Each phase ships working, testable functionality. Research → slice → gate → reflect."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - Write
  - Edit
argument-hint: "<feature-description | ticket-file | existing-plan-path>"
---

# Implementation Planner

Create a plan where every phase is independently shippable and verifiable. The plan must be self-contained — any agent can pick it up and execute it without needing this skill.

---

## Why This Skill Exists

Monolithic plans fail silently — you build on broken foundations because nothing was testable until the end. This skill enforces **vertical slicing**: each phase delivers one complete, working path that can be deployed, tested, and verified before the next phase starts.

**Bad** (horizontal): schema → API → UI → tests (nothing testable until the end)
**Good** (vertical): one feature end-to-end → verify → reflect → next feature end-to-end

---

## Process

### Step 1: Understand the Ask

Read `$ARGUMENTS`:
- If it's a file path → read it fully, extract the feature description
- If it's free text → use it as the feature description
- If empty → ask the user what they want to build, then proceed

**Do NOT start planning yet.** Confirm understanding first:

> "I understand you want to [summary]. I'll research the codebase to understand what exists and what's needed. This is read-only — no code changes."

### Step 1.5: Select Revision Mode

Plans aren't always greenfield. Choose the right mode based on what you're given:

| Mode | When | Process |
|------|------|---------|
| **Greenfield** | New feature from a description or ticket | Full process: Research → Slice → Gate → Write → Subagent Review |
| **Revise** | Existing plan needs phase adjustments (add/remove/reorder) | Read existing plan → re-evaluate Step 3 validation table → adjust phases → update dependency graph → re-gate → present delta |
| **Merge** | Combine Plan A + Plan B into one plan | Read both plans → extract research findings from both → re-slice combined scope vertically → single dependency graph → single set of gates → present |
| **Split** | Existing plan is too large, break into sub-plans | Read plan → identify natural seams (cross-plan deps already noted) → split at seam → each sub-plan gets its own Context sections + Execution Protocol → present |

For **Revise/Merge/Split**, skip redundant research — only investigate what changed since the original plan was written. Re-read files the plan references to catch phantom dependencies (Step 6 review subagent, check 9 — Dependency integrity). **Additionally, re-verify every concrete claim carried from source plans** — counts, memberships, type literals, and naming. The existing re-read for phantom deps checks that code exists; this adds checking that claims about that code are still accurate. Mark each inherited claim with its source plan; only claims verified against current code are accepted.

When merging, the merged plan's Dependency Graph replaces both originals. When splitting, each sub-plan must reference its sibling in Cross-Plan Dependencies.

### Step 2: Research

Before spawning agents, identify **3–8 specific research questions** that must be answered before planning. Label them R1, R2, ... For each question, define:
- The exact question
- Where to start looking (files, dirs, docs)
- What a satisfactory answer looks like

Common research question patterns:

| Pattern | Example |
|---------|---------|
| **Code path trace** | "What is the end-to-end call path from settings modal to DB write? Trace from UI → action → data layer." |
| **Library/API verification** | "Does `@chat-adapter/state-pg` export `createPostgresState`? What's its API surface?" |
| **Invariant discovery** | "What constraints exist on the MCP route? What must never change?" |
| **Interface audit** | "What does `composeMcpContext` accept today? How many call sites exist?" |
| **Existing pattern** | "How does the project create server actions? Find 2–3 examples to follow." |
| **Cross-plan check** | "Does any existing plan in Knowledge/Plans/ depend on or provide what this feature needs?" |

#### Agent vs. Single-Agent Research

Not every plan needs sub-agents. Use this decision tree:

| Plan tier | Questions | Approach |
|-----------|-----------|----------|
| **Micro** | Any count | Research yourself — read the relevant files directly. Sub-agent overhead exceeds time saved for ≤3 files. |
| **Lite** | ≤3 questions | Research yourself. |
| **Lite** | 4+ questions | Spawn sub-agents for questions that explore separate code areas. Combine questions about the same file into one sub-agent task. |
| **Full** | Any count | Spawn sub-agents for all questions unless two questions explore the same file (combine those into one sub-agent task). |

#### Research Protocol

**Directory prerequisite**: All research outputs go in `/tmp/plan-research/`. The main agent **must** create this directory (`mkdir -p /tmp/plan-research`) **before spawning any sub-agents**. If this directory does not exist, sub-agents will fail to write their output files.

**File naming**: Each question gets `R{N}.md` (e.g., `R1.md`, `R2.md`). The number matches the Research Findings table ID.

**Output format** (each file must follow this exactly):

```markdown
---
## R{N}: {question}

**Status**: Resolved / Blocked / Needs-more-info
**Affects**: {which phases or decisions depend on this}

### Finding
{One paragraph: the answer to the question, with specifics — file paths with line numbers, function signatures, exact export names.}

### Verifiable Claims
- "{e.g. 33 entries in FIELD_DEFINITIONS_MAP}" → `file.ts:L{start}–L{end}`

_Omit if no concrete claims to verify._

### Impact on Plan
{How this finding constrains or informs the plan structure.}
---
```

**Sub-agent instructions template**:

```
Your deliverable is the file /tmp/plan-research/R{N}.md.
The directory already exists — you do not need to create it.

Task: Answer the following question by reading code, then write your findings to that file.

Question: R{N} — {exact question}
Why it matters: {what planning decision depends on this answer}
Start in: {specific files, dirs, or docs to read first}

Use the Write tool to create /tmp/plan-research/R{N}.md with this format:

--- (start of file)
## R{N}: {question}

**Status**: Resolved / Blocked / Needs-more-info
**Affects**: {which phases or decisions depend on this}

### Finding
{One paragraph: the answer to the question, with specifics — file paths with line numbers, function signatures, exact export names.}

### Verifiable Claims
- "{e.g. 33 entries in FIELD_DEFINITIONS_MAP}" → `file.ts:L{start}–L{end}`

_Omit if no concrete claims to verify._

### Impact on Plan
{How this finding constrains or informs the plan structure.}
--- (end of file)

Be specific: file paths with line numbers, function signatures, exact export names.
Do not return your findings as prose — your only output should be the file you write.
```

**Aggregation**: After all sub-agents complete, read each `/tmp/plan-research/R{N}.md`. Synthesize into the plan's Research Findings table. Unresolved questions = blockers for affected phases.

#### Fact Verification of Research Findings (Full tier only)

Before synthesizing research into the plan, fact-check every concrete claim in the "Verifiable Claims" bullets against the actual source code. This catches errors at their origin — before they're woven into the plan.

For each R{N}.md that contains Verifiable Claims, read the evidence location cited for each claim and confirm it:

| Category | What to verify | Method |
|----------|---------------|--------|
| **Count** | "N fields", "N entries", "N values", "N tools" | Read the actual data structure and count. `grep -c` for simple cases. |
| **Membership** | "X is in Y", "X belongs to Z", "field appears in [A, B]" | Read the actual array/object/map. Grep for the specific item within the specific container. |
| **Type literal** | Enum values like `"poc" \| "paying"`, constant keys | Read the actual type definition. Compare every literal value. |
| **Attribution** | "X is on type Y", "X is defined in file Z" | Read the actual file/type. Confirm X exists where claimed. |

Append a verification result to each R{N}.md:

```
### Fact Verification
| Claim | Category | Verified | Notes |
|-------|----------|:--------:|-------|
| {claim from Verifiable Claims} | count/membership/literal/attribution | ✅ / ❌ | {actual value if mismatch} |
```

**Block rule**: Any ❌ must be resolved in the Finding section before the research is considered "Resolved." Unresolved fact-check failures are blockers, not warnings.

**Scope**: Full tier only. Lite and Micro plans don't involve multi-subsystem data model analysis where these errors arise.

**Cleanup**: Research files are temporary. Don't commit them.

#### Knowledge Migration During Research

Plans are transient documents. Any discovery with lasting value must be written to canonical `Knowledge/` docs during research — not accumulated in the plan and migrated at completion.

**Rule**: When research discovers latent issues, codebase invariants, or deferred-work items that represent permanent knowledge:

1. **Write them to the relevant `Knowledge/` doc immediately** — e.g., a bug in `development.md` § Gotchas, a missing constraint in the relevant architecture section.
2. **Reference them from the plan** — the plan's Latent Issues table says "see `development.md` § Gotchas → L1" instead of being the source of truth.

**What stays in the plan**: plan-scoped orchestration context — which phase fixes what, which items are explicitly scoped out of this plan. The plan is a work order, not a knowledge repository.

**Why**: When a plan is deleted after completion, anything that only exists in the plan is lost. Writing to canonical docs during research ensures nothing is lost even if the plan is abandoned mid-execution.

### Step 3: Slice Vertically

Using the research, identify the vertical slices. Each slice must:

1. **Ship something working** — a user-visible feature, a testable API, a working UI, or a verifiable connection
2. **Be verifiable in isolation** — has its own test or check that passes without later phases
3. **Have no orphan dependencies** — doesn't leave stubs, TODOs, or dead code that only a later phase completes
4. **Leave the system in a good state** — all existing functionality still works

**Order by dependency**: build foundations first, but even foundations must be testable (e.g., a schema migration verified with a round-trip insert/query, or a webhook route verified with a URL challenge).

**Integration plans** (connecting to external systems) may not have user-visible output at every phase. That's fine — the key requirement is **verifiability**, not user-visibility. A phase that verifies "Slack events reach our webhook" is valid even though no user sees it.

**Validate each slice** — check every phase against these rules before proceeding:

| Signal | Action |
|--------|--------|
| Phase modifies more than one independently-testable subsystem | Split — a failure in one change should not obscure the other |
| Phase title contains "and" | Probably two phases — split |
| Phase depends on a later phase | Reorder or merge |
| Ship gate can't pass without next phase | Merge |
| Phase is "set up for later" with no testable output | Add something testable or merge with its consumer |
| Phase only creates types/interfaces with no behavior | Merge with the phase that uses them |
| Phase modifies a shared export without identifying its consumers | Grep for all importers — add them to the phase scope or verify they're unaffected |

**Code anchors must be concrete.** Every change in a phase must include:
- The **current code** — an actual snippet copied from the file, with the line range noted
- The **replacement intent** — what the new code should do, with pattern references (e.g., "follow the pattern in `settings-tab.tsx:L45`")

The plan consumer (the implementing agent) should never need to read a file to understand what exists today — the plan already contains the relevant code. If a phase changes 6 locations, include all 6 current snippets.

**Exception**: new files have no "current" code. For these, include the target file path and what it should export.

File count is a **hint**, not a rule — a 2-file phase that changes a schema and a canonical resolver is riskier than a 10-file rename.

#### Phase Sizing Heuristics

Use this ruler to calibrate phase scope:

| Size | Files | Risk | Example |
|------|-------|------|---------|
| **Small** | 1–3 | Low — single concern, easy to revert | Rename an export, add a column to schema + its CRUD function, create a new tab config entry |
| **Medium** | 4–7 | Moderate — touches multiple concerns but they're coupled | New API route + its handler + DB query + test, extract a module + update all import sites |
| **Large** | 8–12 | High — only justified when files are tightly coupled (e.g., shared UI refactor touching many components) | Full vertical slice: schema + API + UI + cache warming + tests |
| **Too large** | 12+ | Split — almost always contains independent concerns | — |

**Hard limits**:
- **>8 files**: justify why they can't be split. If any file belongs to an independently-testable subsystem, split there.
- **>2 subsystems**: a "subsystem" is a layer (DB, API, UI, cache, external service). If a phase touches 3+ layers, verify the gate covers each layer independently.
- **Title contains "and"**: probably two phases. "Add schema and API route" → split into "Add schema + CRUD" and "Add API route using CRUD."

**Coupling exceptions**: A medium phase that modifies 6 files in the same directory is safer than a small phase that modifies 1 file in each of 3 directories. Proximity of changes matters — colocated changes fail together and are easier to reason about.

#### Close-Out Consideration

After slicing vertical phases, consider whether the plan needs a **close-out** — a final phase (or expanded Completion checklist) that handles knowledge migration: updating `Knowledge/` docs, diagnostic scripts, stale references, and deciding plan disposition. This is warranted when the plan affects shared documentation or data shapes that diagnostic tools depend on. Skip when all knowledge is captured in code (types, tests, implementation). For Lite plans, the Completion checklist is usually sufficient; for Full plans with multi-file `Knowledge/` impact, a dedicated phase may be appropriate.

#### Dependency Validation

After slicing phases, validate the dependency graph. The flat "Phase 1 → Phase 2 → Phase 3 → ..." chain is almost always wrong for plans with 5+ phases — it hides parallelism and creates artificial serialization.

**Validation prompt** — ask yourself for each phase:

> "Does Phase N actually depend on Phase N-1's output, or could it start independently?"

For each phase where the answer is "no real dependency on the previous phase":

1. **Mark it as a parallel candidate** — it can run concurrently with the phase before it (or the phase it actually depends on).
2. **Identify its true dependency** — which phase's output does it actually consume? If none, it can start in Wave 1.
3. **Group into waves** — phases that can start simultaneously form a wave. A serial plan is just "each wave has 1 phase."

**Wave notation**: Express the graph as waves, not a flat chain:
```
Wave 1: Phase 1 (foundation — no deps)
Wave 2: Phase 2, Phase 3 (both depend only on Phase 1)
Wave 3: Phase 4 (depends on Phase 2 + Phase 3)
Wave 4: Phase 5 (depends on Phase 4)
```

This makes parallelism explicit from the start. The executing agent can still run phases sequentially within a session, but the plan honestly represents what can be parallelized.

**Minimum check**: If your graph is a straight line with no branches, at least two phases should have parallel candidates. If not, you've either correctly identified serial dependencies, or you haven't looked hard enough. For 5+ phase plans, assume the latter until proven wrong.

#### Artifact Dependency Analysis

**Skip this subsection if**: ≤3 phases AND serial-only (no parallel waves) AND no cross-plan dependencies. A 2-phase serial plan has one obvious dependency edge — the table adds no insight. **Required when**: 4+ phases, parallel waves, cross-plan dependencies, or any plan where the dependency graph has branches.

For each phase, list **concrete artifacts** (exports, functions, files, env vars, DB tables, config changes) it **produces** and **consumes**. This table is the source of truth for the dependency graph — build the graph from artifacts, not from intuition.

**Produced artifacts** are things a phase creates or materially changes that later phases (or external systems) consume.

**Consumed artifacts** must trace to either:
- An existing codebase artifact → no phase dependency (the artifact already exists)
- A specific earlier phase's Produced artifact → creates a dependency edge

#### Dependency Analysis Table

| Phase | Consumes (artifact → source) | Produces (artifact → used by) |
|-------|------------------------------|-------------------------------|
| 1 | (nothing — foundation) | `chat@4.26.0` package, env vars, `vercel.json` config |
| 2 | existing `ai` SDK (codebase) | `mcpTools` export → P4, P7 |
| 3 | `chat`, `@chat-adapter/*` (P1) | `bot` export → P4, P8; webhook route → Slack |
| 6 | `user_settings` schema (codebase) | `getUserSettingsBySlackId` → P9 |
| 7 | `mcpTools` (P2) | `daily_digests` table → P8, P10; `generateDailyDigest()` → P8 |

**Validation rules**:
1. Every Consumed artifact must have a traceable source (codebase or earlier phase)
2. Every Produced artifact must have at least one consumer (a later phase, or an external system like Slack/Vercel). Orphaned productions = unnecessary work.
3. Phases with no Consumed artifacts from other phases are **Wave 1 parallel candidates** — they only need existing codebase.
4. If a phase Consumes from multiple earlier phases, it starts in the wave after the latest producer completes.
5. Cross-plan dependencies appear as Consumed artifacts whose source is another plan's Produced artifact — mark these explicitly.

This analysis feeds directly into the Dependency Graph (wave grouping) and the "Depends on" field in each phase. If the graph doesn't match the artifact table, the artifact table wins.

### Step 4: Define Ship Gates and Reflection Points

Read `.claude/skills/plan/assets/ship-gates.md` for the full gate reference. Use it to compose each phase's gate.

For each phase:

1. **Classify the phase** using the gate decision tree in `ship-gates.md`. A phase may combine multiple archetypes (e.g., schema + API route + UI = three gate layers composed).

2. **Compose the ship gate** by stacking layers:
   - **Layers 1–2** (build gate): `npx tsc --noEmit && npm run lint && npm run build`. Mandatory for phases that touch code. **Skip for config/docs-only phases** (`.md`, `.yml`, `.claude/skills/*.md`) — the build won't exercise these files.
   - **Layer 3** (functional tests): select the right suite via `/test` skill's decision tree. Create new tests with `/test-new <function>` for new exports.
   - **Layer 4** (anti-regression): re-run the previous phase's gate
   - **Layer 5** (phase-specific proof): the unique verification that proves THIS phase works — not just that the build is clean. This is what makes a gate meaningful.

   **Config/docs phases**: when a phase only modifies non-code files (skill definitions, CI workflows, documentation), Layers 1–3 don't apply. The gate is: _read the file end-to-end after editing and verify the logic flow is correct._ For YAML workflows, also validate syntax if a linter is available.

3. **No local dev server in ship gates** — Phase-specific proofs (Layer 5) must never use `http://localhost:3000` or a local dev server. Local dev lacks KV, Postgres, preview auth, and production env vars, so results are unreliable. Instead:
   - **Prefer `curl` against the preview deployment** — after the PR is created, `curl` the Vercel preview URL with the `x-vercel-protection-bypass` header (see `Knowledge/infra.md` § Preview Environment Auth Bypass).
   - **Defer to PR preview** — if the preview URL isn't known at plan time, write the gate as: "On the PR preview deployment, `curl https://<preview>/api/endpoint` returns expected response." The executing agent fills in the URL once the preview is live.
   - **Automated tests** (Layer 3) are the exception — they run in CI with proper env vars and don't need a running server.
   - **If curl is not possible** (e.g., server actions, complex auth flows), defer to manual verification on the PR preview deployment.

4. **Write the gate** in the plan using the format from `ship-gates.md` § "Composing Gates in the Plan": phase-specific checks first, then automated, then visual/manual, then anti-regression.

5. **Define reflection focus** — for each phase, write a one-liner noting what the executing agent should pay extra attention to during pre-phase (R1) and post-phase (R2) reflections:
   - "R1: verify `composeMcpContext` signature hasn't changed since research"
   - "R2: check if this phase's new export affects the MCP route's import map"

The generic reflection protocol is embedded in the plan template (see Step 5). Per-phase focus notes tailor it to what matters for that specific phase.

### Step 5: Write the Plan

Create `Knowledge/Plans/<kebab-case-name>.md`. Select the template based on plan complexity:

| Tier | When | Template | Phase Format |
|------|------|----------|--------------|
| **Micro** | ≤3 files, ≤3 phases, no schema/code changes (config, docs, workflows, skill files only), single subsystem | `assets/template-micro.md` | Inline (plan is small enough) |
| **Lite** | ≤3 phases, no cross-plan deps, no schema changes, single subsystem | `assets/template-lite.md` | Inline (≤3 phases) |
| **Full** | 4+ phases, cross-plan deps, schema changes, multi-subsystem, or any plan with latent issues | `assets/template.md` | Inline by default; **self-contained phases** when parallel dispatch is expected |

**Self-contained phases for parallel dispatch** (Full plans, optional): When parallel execution is expected, make each phase fully independent — include all file paths, current code snippets, relevant research findings, constraints from other phases, the ship gate, and reflection focus inline in the phase. No cross-references like "see Phase 2" — duplicate the context. This makes each phase independently dispatchable to a subagent. The Research Findings table and Dependency Graph remain in the plan header for the human reviewer.

Read the selected template, then populate each section. For the **Full** template, omit sections that don't apply (the template marks optional sections). The Execution Protocol is always included in both tiers.

The template has three parts:
1. **Context sections** (top) — current state vs desired state (with high-level overview), what we learned, what's in scope
2. **Phases** (middle) — the actual work, with gates and reflection hooks
3. **Execution Protocol** (bottom) — self-contained instructions for the executing agent

**Current State vs Desired State** — every template opens with this section. Populate it from research findings:
- **Desired State — High-Level Overview**: write this first. It's the elevator pitch — what the system looks like after all phases ship. Be concrete (no "improved experience" without saying what improves). This anchors the entire plan.
- **Current State**: fill from research — what exists, what's broken, what's missing.
- **Desired State — Detailed** (Lite and Full only): the per-aspect gap table. Each row's "Gap" column is the delta between current and desired — it should map roughly to one or more phases.

**Code anchors in phases**: use function signatures and export names (e.g., `queryMetric()`, `SteepQuery.breakdownBy`) as the primary identifier — signatures are stable across phases. Line numbers are a secondary reference for the implementing agent's convenience; they may drift as prior phases modify the same file. If a phase includes a code snippet captured during research (Step 3), keep the snippet but note that the line range is a hint, not a guarantee.

### Step 6: Self-Review (Subagent)

**Why a subagent**: Self-review catches hallucinations, factual errors, and misconceptions. A fresh agent with no prior context reviews the plan objectively — it has no investment in the plan's structure and no bias toward preserving what it already wrote.

**Spawn a review subagent** with the plan file path and the checklist below. The subagent reads the plan and verifies each check by reading the actual source files referenced. It reports findings as a structured list.

#### Subagent Prompt Template

```
You are reviewing an implementation plan for correctness. Read the plan at {plan-path}, then verify every check below that applies to this plan's tier.

The plan author cannot see your output — be brutally honest. Report failures with file:line evidence.

Tier: {Micro | Lite | Full}

## Checks

### All tiers (5 checks)

1. **Orphan code** — changes that don't serve the stated goal. For each phase, ask: does this change directly contribute to the plan's stated outcome? → Remove anything that doesn't.
2. **Vague gates** — gates that say "Verify it works" or can't be independently verified. Each gate must specify a concrete action with a pass/fail outcome. → Replace vague gates with specific checks.
3. **Deferred testing** — a phase creates something testable but defers the test to a later phase. → Test in the same phase.
4. **Unresolved research blocks** — a phase starts while a blocking research question is still open. → Flag as blocker.
5. **Overengineering** — phases that exist "just in case" or do more than the stated goal requires. Would a human engineer plan it this way? → Flag for removal or simplification.

### Lite + Full (3 additional checks)

6. **Horizontal slicing** — "Phase 1: all schemas, Phase 2: all APIs, Phase 3: all UI." Nothing testable until the last phase. → Flag for re-slicing.
7. **Foundation-only phases** — "Phase 1: set up types." No ship gate can verify this in isolation. → Merge with the phase that uses the types.
8. **Giant phases** — a phase mixing independent subsystems where a failure in one obscures the other. → Flag for splitting.

### Full only (5 additional checks)

9. **Dependency integrity** — The plan's dependency claims are wrong. Check: (a) phantom dependencies (code referenced is commented out, stubbed, or unimplemented), (b) false serial dependencies (the graph is a flat chain but phases don't actually consume output from their predecessor), (c) unverified "Depends on" fields (imports/code show no consumption of the claimed dependency). For each, read the actual files. → Flag discrepancies.
10. **Scope consistency** — phases, dependency graph, risks, and cross-plan deps are out of sync. For revise/merge/split modes: phases changed without updating downstream sections. → Flag inconsistencies.
11. **Merge integrity** (merge mode only) — two source plans reference the same file with different assumptions. → Read the file, report which assumption is correct.
12. **Blast radius audit** — a phase modifies a shared export without listing its consumers. Grep for all importers. → Report unlisted consumers.
13. **Data model verification** — concrete claims about counts, memberships, type literals, or naming that weren't verified during research. Read the source file for each claim. → Report mismatches.

## Output Format

For each check, report:
- ✅ Pass — one sentence confirming
- ❌ Fail — file:line evidence of the problem and what to fix
- ⬭ Skip — this check doesn't apply (e.g., merge check for a greenfield plan)

End with a summary: total passes, total failures, and whether the plan is ready to present.
```

#### Processing the Review

After the subagent reports:

1. **Fix all ❌ failures** — these are blockers. Update the plan, then re-run the review subagent if changes are significant (new phases added, dependency graph changed).
2. **Present the review summary to the user** alongside the plan in Step 7 — transparency builds trust.

#### When NOT to Use a Subagent

For **Micro** plans (≤3 files, config/docs-only), the subagent overhead may exceed the plan itself. In this case, apply the 5 Micro checks yourself — but still read the plan fresh (close the file and re-read it) to simulate objectivity.

### Step 7: Optimize for Implementation

After the self-review passes, re-evaluate the plan's phase ordering from the perspective of the AI agent who will implement it. Dependency order (Step 3) ensures correctness — this step ensures **execution efficiency**.

Ask yourself these questions and reorder if needed:

1. **Fail-fast ordering** — Can the highest-risk, most uncertain phase move earlier? If it's going to fail, fail before investing work in safe phases.
2. **Context loading** — Do early phases build the mental model (reading files, understanding patterns) that later phases need? If a late phase requires deep codebase understanding that earlier phases don't establish, consider reordering or merging.
3. **File locality** — Are phases that touch the same files/directories grouped close together? Minimizing context-switching between distant code areas reduces errors.
4. **Reversibility** — If a phase might need rollback, is it positioned where rollback is cheapest? Cosmetic/refactoring phases are cheap to roll back; schema changes are expensive.
5. **Cognitive momentum** — Does each phase naturally flow into the next? The implementing agent builds understanding incrementally. If Phase 3 requires forgetting what Phase 2 established, the order is wrong.

**Trade-off with dependency order**: This step must not violate the dependency graph from Step 3 (Artifact Dependency Analysis). If the optimal implementation order conflicts with dependency order, dependency order wins — but flag this to the user in Step 8 so they can decide whether to re-slice.

If reordering changed anything, update:
- Phase numbering throughout the plan
- Dependency Graph (wave grouping)
- "Depends on" fields in each phase
- Cross-references in Research Findings and Latent Issues

Then verify: read the dependency graph and confirm each phase's "Depends on" field matches its wave position. A mismatch here means the reordering introduced an inconsistency.

### Step 8: Present for Review

Present the plan to the user with:

1. **Phase summary** — one line per phase showing what ships and the gate
2. **Risk highlights** — any high-risk phases, unresolved research, or cross-plan blocks
3. **Ask**: "Does this phasing make sense? Any phases too large, too small, or in the wrong order?"

Iterate until the user approves. Common adjustments:
- Split a phase that mixes independent subsystems
- Merge phases that can't be independently verified
- Reorder based on business priority or risk

After approval: evaluate whether this plan warrants a `/grill <plan-path>` review before implementation. **Always suggest grill when** the plan involves any of:

- **External tool adoption** — first use of a library, SDK, service, or framework in this project
- **Hard-to-reverse architecture decisions** — new data domains, schema changes, pattern shifts affecting multiple phases
- **First-of-category work** — the first time this project does something it's never done before (new data source type, new infra platform, new auth flow, new external API integration)

**When in doubt, suggest it.** Running grill unnecessarily is cheaper than shipping an architectural mistake. Skipping grill on a marginal case is worse than running it on a clear one.
