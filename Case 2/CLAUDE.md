## Core Workflow

Follow this sequence for every non-trivial change:

1. **Plan** — `.claude/skills/plan/SKILL.md` — Research → vertical slices → ship gate per phase
1. **Grill** *(if high-stakes or external deps)* — `.claude/skills/grill/SKILL.md` — Adversarial research, web-verified claims
1. **Peer review** *(instead of human feedback)* — `.claude/skills/peer-review/SKILL.md` — Gut check from a different LLM
1. **Test** — `.claude/skills/test/SKILL.md` — Auto-selects suite from changed files, triages failures (never vitest)
1. **Write new tests** *(for new exports)* — `.claude/skills/test-new/SKILL.md` — Create tests following project patterns
1. **Review** — `.claude/skills/review/SKILL.md` — Code review checklist, updates finding registry
1. **Update knowledge** — Update affected `Knowledge/*.md`; fix what slowed you down
1. **Commit** — `.claude/skills/commit/SKILL.md` — Structured commits (never `git commit` directly)
1. **Create PR** — `.claude/skills/create-pr/SKILL.md` — Branch + PR, runs verify gate

---

## Working Style

- **You are the manager.** @plan before implementing — present the plan, get approval, then delegate. Questions ≠ requests: discuss ideas, don't implement them. Smallest change, biggest impact.
- **Delegate well.** Over-provide context in prompts — subagents can't see your skill system or conversation history. Inject key commands and skills so they never guess. One spawn, verify after, no re-spawn loops. IT IS YOU WHO OWNS quality — run @test on their output yourself.
- **Stay lean.** Offload discoveries to `Knowledge/` between phases — don't carry Phase 1 context to Phase 4. Note in your created docs gaps and out-of-scope work — park, don't chase. Periodically reassess: rabbit hole? simpler path? use your decision aids:
  - **@peer-review** — quick second opinion from a different LLM (~15s). Use liberally: stuck on an approach, unsure about a design choice, rubber-ducking mid-task.
  - **@grill** — systematic adversarial analysis. Use when the stakes are high: tool/framework evaluation, irreversible architecture decisions, proposals that smell too good to be true.
- **Done when:** every phase's ship gate passes (defined by @plan) → run remaining Core Workflow steps (@test → @review → update `Knowledge/*.md` → @commit → @create-pr). When updating `Knowledge/*.md`, also fix what slowed you down: unclear naming, missing docs, stale templates, gaps in registration.

---

**Cursor IDE:** Same skill files — `.cursor/rules/steep-ship-workflow.mdc` (`alwaysApply`). No duplicated procedures; open the `SKILL.md` paths above.

## Knowledge Base (read before touching code)

**Core pillars** — guarded by @review (`checks-doc-drift.md`), always reflect current codebase:

| Doc | Covers |
|-----|--------|
| `Knowledge/development.md` | **Primary dev guide**: canonical data architecture (write/read paths, Mermaid diagrams), resolver pattern, canonical types & cache keys, data contracts, module map, key invariants, gotchas. Cookbooks: "Adding a New Resolver" (8 steps), "Adding a New KV Cache Key" (3 touchpoints), modifying tabs/charts |
| `Knowledge/ai-layer.md` | **AI analyst pipeline**: prompt adapters, field/lens/tab registries, system message composition, MCP tools & serialization, eval foundation |
| `Knowledge/steep-api.md` | **Steep API reference**: endpoints, query/response shapes, metric IDs, dimension support, filter patterns, aggregation semantics |
| `Knowledge/infra.md` | **Infrastructure**: env vars, KV (canonical cache model, cascade invalidation, key namespaces), Postgres, database layer, OAuth connector, rate limits, preview auth, deployment |

**Operational guides** — read when relevant:

| Doc | Covers |
|-----|--------|
| `Knowledge/debugging.md` | Recipe book for diagnosing issues across the four data layers (Steep API → resolver transforms → KV cache → UI). Anti-patterns & common bugs, KV inspection, triage workflows, edge-case discovery |
| `Knowledge/visual-debugging.md` | **Visual verification workflow**: 4-phase loop (inventory → edit → verify → diff), post-PR checklist, UI↔code mapping, worked examples |
| `Knowledge/ui-map.md` | **UI element inventory**: stable refs, per-tab element map, settings modal tree. Used by visual-debugging and agent-browser |
| `Knowledge/Plans/browser-agent.md` | **agent-browser tool reference**: commands, screenshots, playbooks, CI integration, gotchas |

---
