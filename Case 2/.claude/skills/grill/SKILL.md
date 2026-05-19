---
name: grill
description: "Stress-test proposals through adversarial research with built-in fact-checking — verifies external claims via web research and internal claims against the codebase. Default answer is NO; research must prove YES. Use when evaluating tool/framework adoption, architecture decisions, plan reviews, or any decision where confirmation bias is a risk."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - Write
  - Edit
argument-hint: "<plan-path | idea-description | decision-to-evaluate> [--standard | --deep]"
---

# Grill

Stress-test proposals through adversarial research. **Default answer is NO — research must prove YES.**

## Scope

Light is the default. Upgrade when the decision warrants it.

| Scope | Flag | Agents | Interview |
|-------|------|--------|------------|
| **Light** | *(default)* | Adversary (CLI) + External Researcher (if external tools) | No |
| **Standard** | `--standard` | + Builder + Pragmatist | If tensions |
| **Deep** | `--deep` | + Integrator | Mandatory |

## Process

### Step 1: Frame

Read `$ARGUMENTS` (file path → read it, URL → fetch it, text → use it). Extract `--standard` / `--deep` flag.

Internally establish:
- **Decision question**: one sentence ("Should we adopt X for Y?")
- **Null hypothesis**: default is NO
- **Kill condition**: what single finding ends this?
- **Fact claims**: every verifiable assertion (file paths, counts, API names, versions)
- **External claims**: any claims about external tools, libraries, or services

Present the kill condition to the user: *"The kill condition for this analysis is: [X]. If I find this, I'll stop immediately without running further agents."*

### Step 2: Probe

Fire all agents **in parallel**. The Adversary runs through an external LLM via CLI (different model = genuine independence). All other agents use `spawn_agent`.

Every agent is told: *null hypothesis is NO; for every idea, state the simplest alternative.*

#### The Adversary *(always — via CLI)*

The core agent. Combines fact-checking with adversarial analysis. **Routed through an external LLM via CLI** for genuine model independence — different blind spots, different biases than the head agent running grill.

Mission: Verify claims against the codebase AND knowledge docs, then argue against adoption. For each idea: find the simplest alternative, estimate value retained. Identify the 3 strongest reasons to reject. Find underplayed risks and internal contradictions. Rate the cost of undoing.

**CLI invocation** — fill the Adversary prompt template from [REFERENCE.md](REFERENCE.md) with `{COMMON_PREAMBLE}`, `{PROPOSAL_SUMMARY}` and `{FACT_CLAIMS}` (numbered list of atomic, verifiable assertions from Step 1), then pipe through `adversary.sh`:

```bash
cat << 'ADV_EOF' | .claude/skills/grill/scripts/adversary.sh
{ADVERSARY_PROMPT}
ADV_EOF
```

**Critical**: Set `cd` to the project root directory (e.g. `"Steep Dashboard"`) when calling the `terminal` tool. The script path is relative to the project root — without `cd`, the shell won't find it.

- Run via the **Bash** tool (the `terminal` call for CLI and `spawn_agent` calls run concurrently when fired in the same response).
- If exit code is **2** (no CLI found), fall back to `spawn_agent` with the same prompt, label **Adversary (fallback)**.
- If exit code is **1** (CLI found but failed — rate limit, API error, timeout), surface the error to the user before falling back to `spawn_agent`.
- Model independence is guaranteed by CLI config — `command-code` and `claude` are configured to use a different LLM than the IDE agent.

Tools (available to the CLI agent): Read, Grep, Glob, Bash.

#### The External Researcher *(spawn when external tools/frameworks involved)*

**The hallucination killer.** The only agent with web access. Prevents the skill from confidently recommending adoption of a tool that doesn't exist or doesn't work as described.

Mission: Fetch the tool's repository, documentation, npm/registry page. Verify every external claim — does this feature exist? Is it maintained? What's the maturity level? Find known issues, breaking changes, deprecation warnings. Report with confidence level.

Tools: **Read, Grep, Glob, fetch** — read-only. No Bash, Write, Edit, or Agent. Security is tool-enforced, not instruction-dependent.

⚠️ **If this agent cannot reach the external resource** (network error, 404, private repo), mark ALL external claims as ❓ Unverified and report what was attempted.

Full prompt templates → [REFERENCE.md](REFERENCE.md)

#### The Builder *(`--standard` / `--deep`)*

Mission: Can we actually build this? Read the relevant source files. Trace code paths. Realistic effort (optimistic × 1.5–2.0). Hidden dependencies. What existing codebase patterns can be reused? What's the 80% version?

Tools: Read, Grep, Glob, Bash.

#### The Pragmatist *(`--standard` / `--deep`)*

Combined operational + strategic assessment. Replaces separate Operator and Stakeholder roles.

Mission: Can we deploy and maintain this? New infrastructure or platforms? Failure mode at 3am? What's the ACTUAL problem this solves (not the solution)? Is it worth the cost — developer time, infrastructure, maintenance tax, opportunity cost? If this were your money, would you fund it?

Tools: Read, Grep, Glob, Bash.

#### The Integrator *(`--deep` only)*

Mission: Does this follow existing patterns or fight them? Read `Knowledge/development.md` and `Knowledge/infra.md` fully. Audit new touchpoints. Check against Key Invariants. Map blast radius.

Tools: Read, Grep, Glob, Bash.

### Step 3: Synthesize

Main agent only — no spawning.

**Quality gate**: For each agent's output, check: does it contain `file:line` citations or specific evidence? Is it substantive (>100 words)? If not, flag as ❗ unreliable and weight it lower in synthesis.

**Kill condition check**: Did any agent find the kill condition? If yes — **stop here**. Present findings to user. Do not proceed to verdicts or interview.

**Scope sufficiency**: If Light scope was used and the analysis reveals complexity that Light couldn't fully resolve (fundamental unknowns, high-stakes findings, many unresolvable contradictions), note this in the synthesis and recommend `--standard` for deeper analysis.

Then process through three lenses:

**Contradictions**: Where do agents disagree? Where does the proposal contradict itself?

**Simplicity audit**: For every recommendation, did the Adversary or Builder propose a simpler alternative? What % value retained? Is the gap worth the extra complexity?

**Verdicts**:

| Verdict | Means |
|---------|-------|
| **GO** | Verified valuable, no simpler alternative, feasible, no fatal risks |
| **CONDITIONAL-GO** | Valuable but needs conditions met first (list them) |
| **DOWNGRADE** | Simpler alternative retains ≥70% value — use that instead |
| **NO-GO** | Debunked facts, fatal risks, or not worth it |
| **DEFER** | Insufficient info — needs user input or more research |

### Step 4: Present + Interview

Present the synthesis:

```
## 🔥 Grill: {Title}
**Decision**: {GO / CONDITIONAL-GO / DOWNGRADE / NO-GO / DEFER}

### Per-Idea Verdict
| Idea | Verdict | Simpler Alternative | Key Risk |

### Fact Corrections
{what was wrong in the proposal}

### External Verification
{what the External Researcher confirmed or debunked}

### Unverified Claims ❓
{treat as assumptions}
```

**Interview** — if tensions exist (or `--deep`): walk the user through unresolved decision points **one at a time**. Each question: present tension → options with evidence → recommended answer → wait for input. If a question can be answered by reading code, read code instead of asking.

After interview (or if no tensions): offer to save to `Knowledge/Plans/{slug}.md`.

---

## Anti-Patterns

| # | Don't | Do |
|---|-------|----|
| 1 | Ask "How can X help?" | Ask "Should we use X?" with null hypothesis = NO |
| 2 | Skip the Adversary | Always invoke one (via CLI, with spawn_agent fallback). It's the core agent. |
| 3 | Skip External Researcher for external tools | Always spawn it when the proposal mentions external tools. It's the hallucination killer. |
| 4 | Trust AI consensus | 5 AI personas agreeing = 1 bias × 5. The Adversary is routed via a different model to mitigate this. Weight by evidence quality. |
| 5 | Hide uncertainty | Mark ❓ explicitly. Separate facts from assumptions. |
| 6 | No simpler alternatives | Adversary must find them for every idea. |

## When to Use

```
Is the decision high-stakes or hard to reverse?
├── NO → Skip this skill, use your own judgment
└── YES → Adopting something new?
    ├── YES → Obvious simpler alternatives? → light
    │         No? → --standard
    └── NO → Internal architecture? → --standard
              Small thing? → light
```
