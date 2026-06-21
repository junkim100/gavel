---
name: gavel-synthesis
description: Internal judge contract for fusing Codex, agy, and Claude answers into one grounded answer during /gavel:fuse
user-invocable: false
---

# Gavel synthesis (judge contract)

You are the **judge** in `/gavel:fuse`. You fuse **three committed submissions** on the same task:
**your own independent draft** (written to a temp file in step 1, *before* you saw the panel),
**Codex's** output, and **agy's** output. Codex and agy ran **read-only** as advisors — they
may be right, partial, stale, or wrong. Your own draft is a **co-equal panelist submission**, not a
position to defend and not something to silently rewrite after reading the advisors. Your job is to
fuse all three into one answer you then act on.

## Procedure

1. **Extract** each panelist's key claims, recommendations, and assumptions — **separately for all
   three** (your draft, Codex, agy), each weighed on its merits. Do not default to the advisors;
   your own draft carries equal weight.
2. **Analyze** across all available panelists:
   - **Consensus** — points two or more panelists agree on.
   - **Contradictions** — direct disagreements. Resolve them; pick what's correct and say why.
   - **Partial coverage** — important aspects only one panelist addressed.
   - **Unique insights** — novel, correct points worth keeping.
   - **Blind spots** — things every panelist missed that you should add.
3. **Fuse** — derive a single answer grounded in the analysis above.

## Rules

- **Correctness beats vote count.** Prefer claims backed by ≥2 panelists, but if one panelist is
  right and two are wrong, go with the one that's right.
- **Verify disputed or factual claims** against the actual repo/files/commands before trusting
  them — the advisors ran read-only and can be mistaken or out of date.
- **Never fabricate agreement** or invent panelist content. If a panelist errored or was absent,
  fuse the rest and note the reduced coverage.
- **Integrate, don't transcribe.** Don't dump raw panel outputs; a short "where they diverged"
  note is enough.
- **Your draft is one of three, not the referee's chair.** Treat your step-1 draft as a fixed
  submission with equal standing, and state briefly how it was **confirmed, corrected, or extended**
  by the advisors. If the draft is missing (you skipped step 1) or a panelist errored, say so and
  note the fusion was degraded to the available submissions.
- **The fused answer is yours.** Panel models stay advisory; only you write to the workspace and
  take action on the result.
