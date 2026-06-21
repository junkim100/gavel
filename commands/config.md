---
description: View or change gavel settings (model, timeout, panel) in the user or project config file
argument-hint: "[show | set <key> <value> | unset <key>] [--project]"
allowed-tools: Bash(node:*)
---

Manage gavel settings via the runner's `config` subcommand. Precedence (low→high):
`~/.gavel/config.json` < `./.gavel.json` < env vars < CLI flags. By default writes go to the **user**
file (`~/.gavel/config.json`, all projects); add `--project` to write `./.gavel.json` (this repo only).

Keys: `timeout` (seconds), `panel` (comma-separated provider list), `codex.model`, `codex.enabled`,
`agy.model`, `agy.enabled`.

Raw arguments:
$ARGUMENTS

Decide the action from the arguments, then run the matching command (pass each token as a separate,
quoted shell argument — never interpolate the value into a larger string):

- **No args, or `show`** → `node "${CLAUDE_PLUGIN_ROOT}/scripts/gavel.mjs" config show`
  (add `--json` if the user wants machine output). This prints the *effective* settings, which file
  each comes from, and whether each model is a falling-back default or a pinned model.
- **`set <key> <value>`** → `node "${CLAUDE_PLUGIN_ROOT}/scripts/gavel.mjs" config set <key> <value>`
  (append `--project` if the user said this repo / project only).
- **`unset <key>`** → `node "${CLAUDE_PLUGIN_ROOT}/scripts/gavel.mjs" config unset <key>` (`--project` as above).

The runner validates keys and values and exits non-zero with a clear message on bad input — relay that
message; do not retry with a guessed value. After a successful change, show the new effective config by
running `config show` so the user sees the result.

Note: pinning a model (`set <provider>.model …`) opts that provider out of the automatic fallback to
the CLI's own default — so only pin a model the account can actually use. Leaving it unset keeps the
preferred default (`gpt-5.5-pro` / `gemini-3-pro`) with auto-fallback. Relay the runner's reminder.
