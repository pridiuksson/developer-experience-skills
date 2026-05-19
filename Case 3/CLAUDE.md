## Core Workflow

Follow this sequence for every non-trivial change:

**Grill** *(if high-stakes or external deps)* — `.claude/skills/grill/SKILL.md` — Adversarial research, web-verified claims
**Peer review** *(quick gut check)* — [`.claude/skills/peer-review/SKILL.md`](.claude/skills/peer-review/SKILL.md) — Second opinion from a different LLM
**Ticket** *(backlog management)* — [`.claude/skills/ticket/SKILL.md`](.claude/skills/ticket/SKILL.md) — Create agent-ready tickets with peer review
**Work** *(ticket execution)* — [`.claude/skills/work/SKILL.md`](.claude/skills/work/SKILL.md) — Execute a ticket end-to-end: verify, implement, peer-review, complete
**Commit** — `.claude/skills/commit/SKILL.md` — Structured commits (never `git commit` directly)
**Create PR** — `.claude/skills/create-pr/SKILL.md` — Branch + PR without checkout

## Domain Skills

Self-contained, externally-deployable skills. Each owns its own code (no imports from `src/lib/`).

| Skill | Purpose | Invocation |
|-------|---------|------------|
| **@score-invoice** | PDF → GLM-OCR → LLM extraction → deterministic routing → auto_post or flag_for_review | `@score-invoice <pdf-path-or-dir> [--json] [--summary]` |
| **@generate-pdf** | Natural language → CraftMyPDF → invoice PDF | `@generate-pdf <description>` |

Skills are the authoritative implementations. `src/lib/` is legacy prototype code from the Next.js scaffolding phase.

---

## Working Style

- **You are the manager.** Plan before implementing — present the plan, get approval, then delegate. Questions ≠ requests: discuss ideas, don't implement them. Smallest change, biggest impact.
- **Delegate well.** Over-provide context in prompts — subagents can't see your skill system or conversation history. Inject key commands and skills so they never guess. One spawn, verify after, no re-spawn loops. IT IS YOU WHO OWNS quality — run @eval on their output yourself.
- **Skills are self-contained.** Each skill owns its own `lib/`, `scripts/`, and `assets/`. No imports from `src/lib/`. When modifying a skill, edit files within its directory only. When adding a rule or provider, update both the skill's code AND its `assets/` markdown.
- **Stay lean.** Offload discoveries to `Knowledge/` between phases — don't carry Phase 1 context to Phase 4. Note in your created docs gaps and out-of-scope work — park, don't chase. Periodically reassess: rabbit hole? simpler path? use your decision aids:
  - **@peer-review** — quick second opinion from a different LLM (~15s). Use liberally: stuck on an approach, unsure about a design choice, rubber-ducking mid-task.
  - **@grill** — systematic adversarial analysis. Use when the stakes are high: model selection, confidence scoring design, architecture decisions, any proposal that smells too good to be true.
- **Done when:** every phase's ship gate passes → run remaining Core Workflow steps (update `Knowledge/*.md` → @commit → @create-pr). When updating `Knowledge/*.md`, also fix what slowed you down: unclear naming, missing docs, stale templates.

---

## Knowledge Base (read before touching code)

**Core pillars:**

| Doc | Covers |
|-----|--------|
| `Knowledge/project.md` | **Full project reference**: product brief, architecture, tech stack, extraction pipeline, confidence scoring, UI design, eval strategy, implementation phases |
| `Knowledge/objective.md` | **Interview format & expectations**: system design case, coding case, evaluation criteria, product brief |
| `Knowledge/ai-scoring.md` | **Confidence scoring deep-dive**: four-signal composite scorer, deliverables in execution order, eval harness design, what to borrow from Steep Dashboard |
| `Knowledge/infra.md` | **Infrastructure**: env vars, API keys, external services |
| `Knowledge/eval.md` | **Eval harness**: ground truth format, scoring metrics, regression detection, running evals |

---
