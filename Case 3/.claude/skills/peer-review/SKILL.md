---
name: peer-review
description: "Quick gut check from a different LLM via CLI (command-code or Claude Code `claude -p`). Bounce ideas, catch blind spots, find simpler alternatives. Lighter than @grill. Invoke explicitly when you want a second opinion."
allowed-tools:
  - Bash
  - Read
  - Grep
argument-hint: "<question-or-idea>"
disable-model-invocation: true
---

# Peer-Review — Quick AI Gut Check

Bounce an idea off a different LLM. Quick sanity check, not deep adversarial analysis (`@grill`).

## Do this

Substitute `$ARGUMENTS` with a **short** idea (no wall of code — state the idea; the peer can read files if its tooling allows). Construct the prompt using this template:

```text
You are a peer programmer pair-programming with an AI agent. The agent is thinking: $ARGUMENTS. What would you do differently? Where are the hidden traps? What's the simplest alternative? What questions should they ask themselves? Be direct, no hedging.
```

Feel free to adjust the persona and framing to fit the situation (security reviewer, product critic, rubber duck, etc.).

### 1) Run the peer-review script via Bash tool

Use your Bash tool (`terminal`) to run:

```bash
.claude/skills/peer-review/peer-review.sh "<YOUR_PROMPT>"
```

**Critical**: Set `cd` to the project root directory (`"Pit 1"`) when calling the `terminal` tool. The script path is relative to the project root — without `cd`, the shell won't find it.

- Set `timeout_ms` to **300000** (5 minutes).
- If exit code is **2**, no CLI was found — fall back to step 2.

### 2) ONLY if no CLI found — use `spawn_agent` (last resort)

Use `spawn_agent` with the peer prompt as the user message, label **Peer review**, same 5-minute budget. This is weaker than a real second CLI (same stack, less independence) but better than skipping.

### After the peer replies

Report the peer's **main** insight in your own words. If you disagree, say why briefly.

### Follow-up rounds

- **CLI**: run `peer-review.sh` again with a follow-up prompt; up to **3** short rounds.
- **Subagent**: reuse `session_id` if your runner supports it.

## When

- Before `@plan` — sanity check an approach
- During implementation — rubber-duck when stuck
- Before committing to a design — second opinion on trade-offs
- Before committing to a technology choice (e.g., VLM vs Textract, Zod schema design)
- When evaluating extraction accuracy approaches or scoring algorithms
