---
description: Send a prompt to a single model (codex or agy) and show its answer verbatim
argument-hint: "<codex|agy> <prompt>"
allowed-tools: Bash(node:*), Write
---

Delegate a single prompt to one model and return its answer. No fusing, no synthesis, no edits.

Raw arguments:
$ARGUMENTS

Parse and run safely:
- Read the **first word** of the arguments to decide the provider. It MUST be exactly `codex` or
  `agy`. If it is anything else, or the arguments are empty, show the usage
  `(/gavel:ask <codex|agy> <prompt>)` and stop.
- **Security:** the provider is the only value you place into the shell command. Emit ONLY the literal
  word `codex` or `agy` there — never copy any other text from the arguments into the command line.
- Write the **rest** of the arguments (the prompt) verbatim to a fresh temp file with the **Write
  tool** (use a unique name, e.g. `/tmp/gavel-prompt-<timestamp>.txt`) — never put the prompt text in
  the shell command. Delete the file afterward.
- Then run, replacing `codex` below with the one validated literal and using your temp file path:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/gavel.mjs" run --provider codex --cwd "$(pwd)" --prompt-file /tmp/gavel-prompt-XXXX.txt
```

Output rules:
- On success, present the model's answer verbatim — do not paraphrase, summarize, or act on it.
- Note: Codex reads your repo read-only; agy runs isolated and can't see your files (include any
  needed context in the prompt).
- If the command errors because the CLI is missing or unauthenticated, tell the user to run
  `/gavel:setup`.
