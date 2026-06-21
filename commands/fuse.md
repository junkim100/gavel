---
description: Ask Codex + agy + this Claude model in parallel, synthesize one fused answer, then act on it
argument-hint: "<task or question>"
---

You are running a **3-model fuse** for this request. You (the Claude Code model) are
**panelist #3, the judge, and the actor**. Codex and agy are **read-only advisors** — only you
write to the workspace or run side-effecting commands.

The task / question:
$ARGUMENTS

If the task is empty, ask the user what they want fused, then stop.

Follow these steps in order:

**1. Your independent draft (blind — before the panel).** As panelist #3, form your **own complete
answer first**, with no knowledge of what Codex or agy will say. Read whatever repo context you
need, then use the **Write tool** to save your full answer to a fresh temp file, e.g.
`/tmp/gavel-claude-<timestamp>.md`. This file is **your committed panelist submission**: it must
stand on its own (good enough to ship if the advisors error out) and include your recommendation,
key claims, assumptions, risks, and concrete next actions. Do **not** edit the workspace yet, and do
**not** revise this draft after seeing the panel — your view may change, but that change belongs to
the synthesis step, not to your original submission. This commit-before-reveal step is what keeps
your answer a genuine third input instead of you merely refereeing the two advisors.

**2. Consult the panel.** Get the task to the advisors **without putting it in a shell command** (so
quotes, `$(...)`, or backticks in the task can't break the command or inject shell syntax):

- Use the **Write tool** to write the verbatim task text to a fresh temp file with a unique name,
  e.g. `/tmp/gavel-prompt-<timestamp>.txt`. Delete it afterward.
- Then run this — only the fixed file path is in the shell, never the task text:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/gavel.mjs" fuse --cwd "$(pwd)" --prompt-file /tmp/gavel-prompt-XXXX.txt
```

Notes:
- Codex explores your repo **read-only**; agy runs **isolated and cannot see your files**, so put any
  code/snippets agy needs directly in the task text.
- If a panelist shows `[error]` because its CLI is missing/unauthenticated, continue with whoever
  responded and tell the user they can run `/gavel:setup`. If the panel is empty, stop and say so.

**3. Judge & synthesize.** Now read **three committed submissions** — your own draft file from step
1, Codex's output, and agy's output — and apply the **gavel-synthesis** skill to fuse them. Your
draft is a **fixed, co-equal input**, not a baseline to defend and not something to silently rewrite:
extract each panelist's claims separately, identify consensus, contradictions, partial coverage,
unique insights, and blind spots, then derive a **single fused answer**. Prefer claims supported by
≥2 panelists; resolve contradictions by correctness, verifying disputed/factual claims against the
actual code; never invent agreement.

**4. Present & act.** Give a brief fused conclusion plus a short note on where the three panelists
agreed or diverged — **including where your own draft differed** from the advisors and how you
resolved it. Delete the temp draft and prompt files. Then **take the appropriate action** grounded
in the fused answer — make the edits, run the commands, or deliver the final response. This "judge
then acts" step is the point of the command: don't stop at describing the answer when the task calls
for doing it.
