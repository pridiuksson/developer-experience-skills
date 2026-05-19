# Ship Gates Reference

A ship gate is the **minimum evidence** that a phase works. Not "tests pass" — evidence. Each gate answers: _"If I stopped here and never came back, would this phase hold up?"_

---

## Gate Decision Tree

Start here. Select which archetype(s) your phase needs — a single phase may combine multiple. See [Gate Archetypes](#gate-archetypes) for detailed proof checklists.

```
What does this phase deliver?
│
├─ New/modified DB schema
│  └─ Schema gate + Build gate
│
├─ Code restructure (move, rename, extract)
│  └─ Refactor gate + Build gate
│
├─ New API route or server action
│  ├─ Connects to external service?
│  │  ├─ Yes → Integration gate + API gate + Build gate
│  │  └─ No  → API gate + Build gate
│  └─ Has a cron trigger?
│     └─ Add: idempotency check + auth guard check
│
├─ New/modified UI component
│  ├─ Purely visual change (styles, layout)?
│  │  └─ Visual gate (screenshot diff) + Build gate
│  ├─ Interactive behavior (clicks, forms)?
│  │  └─ Visual gate + functional test + Build gate
│  └─ New tab?
│     └─ Visual gate (Playbook 1) + test suite + Build gate
│
├─ Data pipeline or cache change
│  └─ Data pipeline gate + Build gate
│
├─ Feature that touches existing behavior
│  └─ [Appropriate gate from above] + Regression gate
│
├─ Config / docs / workflow only (.md, .yml, skill files, CI)
│  └─ Config/docs gate (no build gate needed)
│
└─ Multiple of the above
   └─ Compose: one gate per concern, all must pass
```

**When in doubt**: More verification is better than less. A phase that takes 5 minutes to verify saves hours of debugging in later phases built on broken foundations.

---

## Gate Composition

Every ship gate is built from **layers**. Stack the layers your phase needs — don't skip lower layers to get to the exciting ones.

```
Layer 5: Phase-Specific Proof   ← unique to what this phase ships
Layer 4: Anti-Regression         ← previous phase's gate still passes
Layer 3: Functional Tests        ← automated test suites for touched code
Layer 2: Build                   ← tsc + lint + build (catches 80% of issues)
Layer 1: Type Check              ← npx tsc --noEmit (fast, run constantly)
```

**Layer 1–2 are mandatory for every phase.** Layer 3+ depends on what the phase touches. Layer 5 is what makes a gate meaningful — without it, you're just verifying the build, not the feature.

---

## Anti-Patterns

Gates that look rigorous but aren't:

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| "Verify it works" | Not actionable — what does "works" mean? | Specify exact input → expected output |
| Build-only gate for a feature phase | Build proves compilation, not behavior | Add phase-specific proof (Layer 5) |
| "Run all tests" for every phase | Slow, hides which tests are relevant, masks failures in noise | Select the minimal suite that covers the changed code |
| Visual check without baseline | "It looks right" is subjective and unrepeatable | Take a baseline before changes, diff after |
| Skipping anti-regression for "small changes" | Small changes in shared code paths cause the worst regressions | Always re-run the previous gate, especially for small changes |
| Testing on local dev instead of preview | Local dev lacks KV, Postgres, preview auth, proper env vars | **Mandatory rule — see § "No Local Dev Server in Ship Gates" below** |
| Manual-only gate for automatable checks | Future phases can't re-verify efficiently | If you can script it, script it. Save manual for what requires human judgment. |
| Phase-specific check that passes trivially | "Exported function exists" — yes, but does it return correct data? | Each check must be falsifiable: it would fail if the implementation were wrong |

---

## No Local Dev Server in Ship Gates (Mandatory)

Ship gates must **never** use `http://localhost:3000` or a local dev server for verification. Local dev lacks KV, Postgres, preview auth bypass, and production env vars — results are unreliable and non-repeatable.

### What to do instead

| Scenario | Verification approach |
|----------|-----------------------|
| API route (HTTP) | `curl https://<preview-url>/api/endpoint` with `x-vercel-protection-bypass` header. Write gate as: "On PR preview, `curl` returns expected status + fields." |
| Server action / complex auth | Defer to manual verification on the PR preview deployment. |
| Automated tests (Layer 3) | Exception — these run in CI with proper env vars and don't need a running server. |
| Preview URL unknown at plan time | Write gate with a placeholder: `curl https://<preview>/api/endpoint` — the executing agent fills in the URL once the preview is live. |

### How to curl a preview deployment

Preview deployments are protected by Vercel Deployment Protection. Include the bypass header:

```bash
curl -H "x-vercel-protection-bypass: $VERCEL_AUTOMATION_BYPASS_SECRET" \
     https://<preview-deployment-url>/api/endpoint
```

The bypass secret is injected automatically in CI (`VERCEL_AUTOMATION_BYPASS_SECRET`). For local use, set it once in your shell profile:

```bash
# Add to ~/.zshrc or ~/.bashrc
export VERCEL_AUTOMATION_BYPASS_SECRET="<value from Vercel Dashboard → Settings → Deployment Protection>"
```

See `Knowledge/Plans/browser-agent.md` Quick Start for the full setup guide.

---

## Composing Gates in the Plan

When writing the Ship Gate section of a phase, use this structure.

**Prerequisites**: If the plan's Latent Issues or Research Findings flag items that block this phase, they must be resolved before the phase starts. This is not part of the gate (which verifies the phase's output) — it's a precondition. Add a prerequisite checklist when applicable:

```markdown
### Prerequisites (if applicable)
- [ ] [Latent issue that must be fixed before this phase — e.g., "L1: wrap getUserSettings in try/catch"]
- [ ] [Unresolved research item — e.g., "R3: confirm Redis URL is available"]
```

These are resolved during R1 (pre-phase reflection). If a prerequisite can't be resolved, the phase is blocked.

```markdown
### Ship Gate

**Phase-specific:** ← Layer 5 (from the archetype that matches)
- [ ] [Unique proof that THIS phase's deliverable works]
- [ ] [Second specific check if needed]

**Automated:** ← Layers 1–3
- [ ] `npx tsc --noEmit` — clean
- [ ] `npm run build` — clean
- [ ] `npx tsx tests/run.ts <suite>` — passes
- [ ] `/test-new <function>` — new tests created and passing (if new exports)

**Visual / Manual:** ← Layer 5 for UI phases (if applicable)
- [ ] [Specific user action → expected visual result]
- [ ] [Playbook reference if using browser-agent]

**Anti-regression:** ← Layer 4
- [ ] Previous phase's gate still passes: [command]
- [ ] [Specific adjacent feature check if regression risk]

**Do not proceed to Phase N+1 until this gate passes.**
```

---

# Reference

Detailed layer descriptions and archetype proof checklists. Read the sections the Decision Tree pointed you to.

---

## Archetype: Config / Docs / Workflow

_Phase delivers: changes to non-code files — skill definitions, CI workflows, documentation, YAML configs._

**Why it needs its own gate**: These files aren't exercised by `tsc`, `lint`, or `build`. A typo or logic error in a workflow file or skill definition won't surface until someone tries to use it. The build gate is irrelevant here — replace it with direct verification.

**When to use**: Phase touches only `.md`, `.yml`, `.yaml`, `.json` (config), or files under `.claude/skills/`, `.github/workflows/`, `Knowledge/`. If the phase also touches code (`.ts`, `.tsx`), use the appropriate code archetype instead.

**Proof required**:
- [ ] Read the file end-to-end after editing and verify the logic flow is correct
- [ ] For YAML workflows: validate syntax (`actionlint` if available, or a YAML linter)
- [ ] For skill files: trace the decision tree / protocol steps — does the flow make sense given the skill's purpose?
- [ ] For documentation: verify all file paths, command names, and function signatures referenced in the docs actually exist
- [ ] Previous phase's gate still passes (skip for Phase 1)

**What NOT to include**:
- Build gate (`tsc`, `lint`, `build`) — these files aren't compiled
- `curl` against preview — there's no endpoint to curl
- Functional test suite — no code to test

---

## Layer Reference

### Layer 1–2: Build Gate (every phase)

```bash
npx tsc --noEmit && npm run lint && npm run build
```

This is the floor. If this fails, nothing else matters. Run it first, fix it first.

**When to use `/verify` instead**: Final phase of any plan, or when the phase touches critical files (`proxy.ts`, `auth.ts`, `vercel.json`, `next.config.ts`, `api/mcp/route.ts`). `/verify` runs build + lint + full smoke suite + critical file risk assessment.

### Layer 3: Functional Tests

Select the right test suite based on files the phase modifies. Use the `/test` skill's decision tree — it auto-selects the suite:

| Files touched | Suite | Command | Cost |
|---|---|---|---|
| `src/lib/mcp/` or `src/app/api/mcp*/` | MCP smoke | `npx tsx tests/run.ts smoke:mcp` | 0 API, ~2s |
| `tab-configs.ts` or `query-resolver.ts` | Shared smoke | `npx tsx tests/run.ts smoke:shared` | 0 API, ~13s |
| `src/components/` only | Shared smoke | `npx tsx tests/run.ts smoke:shared` | 0 API, ~13s |
| `proactive-insights.ts`, `poc-resolver.ts`, `paying-resolver.ts` | POC smoke | `npx tsx tests/run.ts smoke:poc` | 3 API, ~10s |
| `src/lib/resolvers/` | Regression + POC | `npx tsx tests/run.ts regression` then `smoke:poc` | ~13 API, ~35s |
| Any other `src/` file | Verify | `npm run test:verify` | 3 API, ~60s |

**New exported functions**: If the phase adds `export function` or `export const`, create a test with `/test-new <function>`. The test must be registered in `tests/run.ts` before the gate passes.

### Layer 4: Anti-Regression

Re-run the previous phase's gate. If phase 2 modified what phase 1 delivered, phase 1's specific checks must still pass.

For the first phase, skip this layer. For later phases, include it explicitly in the gate checklist:
```
- [ ] Phase N-1 gate still passes: [exact command from phase N-1]
```

### Layer 5: Phase-Specific Proof

This is the layer that actually proves **your phase works**, not just that the build is clean. See the Gate Archetypes below for templates.

---

## Gate Archetypes

Each archetype is a template for Layer 5. Pick the one the Decision Tree pointed you to, then combine with Layers 1–4.

### Archetype: Schema / Migration

_Phase delivers: new or modified database tables._

**Why it needs its own gate**: Schema mistakes compound silently. Code written against a broken schema produces confusing errors that look like application bugs.

**Proof required**:
- [ ] Migration succeeds: `npx drizzle-kit push` on dev DB — no errors
- [ ] Round-trip CRUD: insert a row → query it back → values match for every column
- [ ] Type verification: each non-standard column type works (test `jsonb` with typed objects, `date` with string mode, `text[]` with arrays, `numeric` with decimal precision)
- [ ] Nullable semantics: insert with null for each nullable column → query returns null (not undefined, not empty string)
- [ ] Unique constraints: insert duplicate → error thrown (not silent overwrite)
- [ ] Default values: insert without optional columns → defaults applied correctly

**Example from chatsdk CP4**:
```
- npx drizzle-kit push succeeds on dev DB
- insertDigest() → getDigestByDate() round-trip succeeds
- insertFeedback() → getFeedbackForDigest() round-trip succeeds
- text[] column works for tags (insert array, query it back)
- date column works for digest_date (insert "2026-04-16", query returns "2026-04-16")
```

**Skill to use**: Manual verification via `npx tsx` one-off scripts or inline `eval` blocks. For CRUD functions, use `/test-new <function>` to create permanent tests.

---

### Archetype: Refactor / Extraction

_Phase delivers: same behavior, different code structure (moved files, extracted modules, renamed exports)._

**Why it needs its own gate**: Refactors are the most dangerous phases — they touch the most code with the highest expectation of "nothing changed." Silent breakage hides here.

**Proof required**:
- [ ] Existing test suite passes: exact same suite that covered the code before the refactor
- [ ] Export surface matches: every symbol the old module exported is still importable from the new location (or re-exported from the old)
- [ ] Manual spot-check: exercise the refactored code path through its primary consumer (MCP route, UI, etc.) — same input → same output
- [ ] No dead imports: `npx tsc --noEmit` catches unused imports, but also grep for the old module path — no stale references should remain

**Example from chatsdk CP1** (MCP tool extraction):
```
- npm run build — no type errors from import changes
- npx tsx tests/run.ts smoke:mcp — all existing MCP tests pass
- Manual: Claude Desktop → call any MCP tool → same response as before
- Verify mcp-tool-defs.ts exports match what the MCP route was importing inline
```

**Skill to use**: `/test` (auto-selects from changed files). No new tests needed — the point is existing tests still pass.

---

### Archetype: API Route / Server Action

_Phase delivers: a new or modified HTTP endpoint or Next.js server action._

**Why it needs its own gate**: Routes are system boundaries. They accept external input, return structured output, and must handle auth, validation, and error cases. A route that builds but returns wrong shapes is worse than one that doesn't build.

**HTTP route proof required**:
- [ ] Happy path: `curl` (or fetch in test) with valid input → expected status code + expected output fields present
- [ ] Auth guard: request without credentials → 401 or 403 (not 500, not 200)
- [ ] Input validation: malformed input → 400 with error message (not 500, not silent corruption)
- [ ] Error path: simulate upstream failure → returns error response (not hang, not crash)
- [ ] Response shape: output matches the documented/expected schema (check key names, types, nesting)

**Server action proof required** (Next.js actions can't be curled — they go through the framework's action layer with session auth, CSRF, and serialization):
- [ ] Direct import test: call the action's inner logic with mocked session → verify DB write (correct table, correct columns)
- [ ] Round-trip: action writes → page reload → UI reads persisted value (proves hydration path works)
- [ ] Auth guard: action without session → throws or returns error (not silent no-op)
- [ ] If dual-write (DB + localStorage, DB + KV): verify BOTH stores updated — one missing means a desync bug

**Example from chatsdk CP2** (Slack webhook):
```
- npm run build — clean
- Manual: ngrok → set tunnel URL → Slack URL verification challenge succeeds
- Manual: @steep hello in Slack channel → event hits our route (check logs)
- AI response NOT expected yet — just verify event delivery
```

**Example from chatsdk CP5** (cron route):
```
- curl -X POST -H "Authorization: Bearer $CRON_SECRET" /api/cron/daily-digest → 200
- curl without auth header → 401
- Re-run same cron → "already exists" response (idempotency)
```

**Example from user-settings Phase 3.A** (server action — model persistence):
```
- npm run build — clean
- Existing settings-context tests pass (model config structure unchanged)
- Manual: Settings modal → change model → hard reload → model persists (DB hydration works)
- Manual: check user_settings.model_id column updated in DB
- Manual: localStorage also updated (dual-write for offline resilience)
```

**Skill to use**: `/test-new <handler>` for automated checks. Manual curl for HTTP routes. For server actions, test through the UI or via direct import in a test script.

---

### Archetype: Integration / External Service

_Phase delivers: connection to an external service (Slack, webhook consumer, third-party API, cron scheduler)._

**Why it needs its own gate**: Integration phases have the highest uncertainty. The code may be perfect but the external service may reject it. You're proving connectivity, not just correctness.

**Proof required**:
- [ ] Connectivity: external service acknowledges our request (challenge-response, 200 OK, event delivered)
- [ ] Event delivery: trigger an event on the external side → our code receives it (check server logs, not just "no error")
- [ ] Credential verification: env vars are set, tokens are valid, scopes are sufficient
- [ ] Timeout handling: if the external service is slow, our code doesn't hang or crash (Vercel function timeout, Slack 3s ack deadline)
- [ ] Local vs deployed: if behavior differs between local dev and preview deployment, test on the **preview deployment**

**Example from chatsdk CP3** (AI bridge → Slack):
```
- Unit: generateSlackReply() with mock Thread → tool calls happen, returns AsyncIterable
- Integration: @steep how many POC customers? in Slack → real response with data
- Check logs for AI SDK errors, token usage, latency
```

**Skill to use**: Manual verification on preview deployment. Use `vercel logs <url>` for server-side evidence. For webhook-based integrations, use ngrok for local testing or Vercel preview for deployed testing.

---

### Archetype: UI Component / Tab

_Phase delivers: new or modified UI that users see and interact with._

**Why it needs its own gate**: UI bugs are invisible to `tsc` and test suites. A component can type-check, pass all tests, and still render broken. Visual verification is not optional.

**Proof required**:
- [ ] Renders without errors: browser console has no JS exceptions on the page
- [ ] Correct content: expected text, data, and structure appear in the accessibility snapshot
- [ ] Interactive behavior: clicks, expands, navigates — all produce expected state changes
- [ ] Responsive: renders correctly on both desktop and mobile viewports
- [ ] Regression: screenshot diff against baseline shows only intended changes

**Visual verification uses preview deployments** (never local dev). Follow `Knowledge/visual-debugging.md`:

| Phase delivers | Verification approach |
|---|---|
| New tab | Playbook 1: click every tab, verify zero JS exceptions, content renders |
| Settings change | Playbook 2: Settings modal opens, changes persist, model switch works |
| Accordion / collapsible UI | Playbook 3: expand/collapse, content renders inside, no layout shift |
| Auth change | Playbook 4: unauthenticated users redirect to sign-in |
| Any structural change | Playbook 5: snapshot diff before/after — only expected elements changed |
| Style / layout change | Element-specific screenshot + `preview_inspect` for computed styles |

**The visual verification loop**:
1. Push changes, wait for Vercel preview to deploy
2. Open preview with `preview_start` or browser-agent with bypass header
3. Take baseline screenshot/snapshot before the change (or use existing from Phase 1)
4. Navigate to the affected area, take verification screenshot/snapshot
5. Compare: screenshot diff for pixels, snapshot diff for structure, `preview_inspect` for styles

**Skill to use**: `/test` for component logic tests. `Knowledge/visual-debugging.md` recipes for visual proof. `/verify` for the final phase if it's the last UI change.

---

### Archetype: Data Pipeline / Cache

_Phase delivers: data flows from source → transform → storage → consumer._

**Why it needs its own gate**: Pipeline phases have invisible failure modes. Data can flow but be wrong — stale, missing fields, wrong aggregation. The gate must verify data correctness, not just data presence.

**Proof required**:
- [ ] Source data arrives: upstream API/DB returns expected data (not empty, not error)
- [ ] Transform correctness: output matches expected shape and values for known input (use fixtures)
- [ ] Storage verification: data is written to the correct store (KV, DB) with expected key patterns
- [ ] Consumer reads correctly: downstream component renders/uses the stored data as expected
- [ ] Cache invalidation: after refresh/update, stale data is replaced (check timestamps, not just presence)
- [ ] Empty state: pipeline handles no data gracefully (empty array, "no data" message, not crash)
- [ ] Non-blocking (if fire-and-forget): caller must not crash or hang when the pipeline fails — simulate failure (mock DB error, network timeout) and verify the caller still returns normally

**Example from user-settings Phase 2** (fire-and-forget LLM logger):
```
- logLlmRequest() with mock db.insert that throws → no unhandled rejection, caller continues
- Caller (proactive-insights.ts) completes normally even when logger fails
- Successful path: trigger insight refresh → verify row in llm_request_logs with correct interface
```

**Example from chatsdk CP5** (digest generation → Slack → DB):
```
- generateDailyDigest() in isolation → verify markdown output, sections, token counts
- Cron trigger → check Slack channel for posted message
- Check daily_digests table for stored row with correct fields
- Re-run cron → "already exists" response, no duplicate row (idempotency)
```

**Skill to use**: `/test-new <transform-function>` for deterministic transform tests. Manual verification for end-to-end data flow. `npm run check-kv` for KV cache state.

---

### Archetype: Feature with Regression Risk

_Phase delivers: new behavior that might break existing behavior._

**Why it needs its own gate**: The new feature works, but did it break something adjacent? This archetype adds explicit regression checks on top of the feature's own verification.

**Proof required**:
- [ ] New feature works: (use the appropriate archetype above)
- [ ] Adjacent feature still works: exercise the most likely regression target manually
- [ ] Shared code paths: if new and old features share code (handlers, context, state), verify the old path explicitly
- [ ] Error isolation: new feature's error handling doesn't swallow errors from adjacent features
- [ ] Boundary enforcement: if the feature intentionally excludes certain consumers (shared cache, other interfaces, other code paths), verify the exclusion — new data/behavior must NOT reach excluded paths

**Example from user-settings Phase 3.B** (context wiring with shared cache constraint):
```
- New: composeMcpContext("get_poc_customers", {}, undefined, "I focus on retail") includes context
- Isolation: composeAnalystContext("poc") output does NOT contain "retail" (shared cache intact)
- Isolation: composeAnalystContext("paying-customers") output does NOT contain context
- Regression: existing MCP tool calls without context still return same output
```

**Example from chatsdk CP6** (feedback capture added to existing bot):
```
- New: reply to digest with "feedback: ..." → bot acknowledges, DB row created
- New: @steep feedback the analysis is great → capture confirmed, tags classified
- Regression: @steep who's at risk? still works normally (conversation path not broken)
```

**Skill to use**: `/test` for automated regression. Manual walkthrough of the adjacent feature. For UI, take a screenshot of the unmodified area and diff it.
