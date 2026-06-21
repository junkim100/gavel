# gavel

Claude Code plugin that fuses the running Claude model with **OpenAI Codex** and **`agy`**:
`/gavel:fuse` asks all three in parallel, Claude judges + synthesizes one answer, then acts on it.
Local CLIs only; synchronous (no background jobs).

## Layout
- `commands/` — slash commands (`fuse`, `ask`, `setup`, `config`); thin Claude-side wrappers.
- `scripts/gavel.mjs` — zero-dependency Node runner: a **provider registry** + config layer.
  Subcommands: `setup | run | fuse | config`.
- `skills/gavel-synthesis/SKILL.md` — the judge/synthesis contract.
- `.claude-plugin/` — `plugin.json` + `marketplace.json` (repo is its own single-plugin marketplace).

## How fuse works
Runs in the main Claude context. Claude is **panelist #3 + judge + actor**. To keep it a genuine
third input and not just a referee of the two advisors, step 1 is **blind drafting**: Claude writes
its own complete answer to a temp file (`/tmp/gavel-claude-<ts>.md`) *before* the panel runs, then
runs the advisor panel in parallel, then synthesizes all three committed submissions per
`gavel-synthesis` (its draft is co-equal, not silently rewritten), then takes action. **Only Claude
writes** to the workspace. The runner (`gavel.mjs fuse`) only queries Codex + agy — Claude's
contribution is the in-process draft, so there is intentionally **no "claude" provider**.

## Read-only is a per-provider capability (`PROVIDERS[name].isolation`)
- `codex` → `readonly-sandbox`: runs in the project dir under `-s read-only` (a real OS sandbox), so
  it reads the repo but genuinely cannot write — a hard boundary.
- `agy` → `isolated` (also the safe DEFAULT for any provider not marked
  `readonly-sandbox`): agy has **no** OS read-only sandbox — `--sandbox` only adds terminal
  restrictions and `--dangerously-skip-permissions` would auto-approve writes. So `runProvider` runs it
  in a **throwaway temp cwd** with `PWD`/`OLDPWD`/`INIT_CWD` scrubbed, which stops it discovering the
  repo path or making relative/cwd writes into it. This is **isolation, not a hardened sandbox**: agy
  still inherits `$HOME` (needed for auth) and will act on any absolute path it's handed — do NOT feed
  advisors untrusted content expecting confinement. Put context agy needs into the prompt.
- The `runProvider` harness creates/scrubs/deletes the throwaway dir; unknown isolation values default
  to isolated (fail safe).

## Prompts never travel through the shell
Prompts reach the runner via `--prompt-file` (or stdin), never a shell-quoted argument, and every CLI
is launched with `spawn` (no shell) so `$(...)` / quotes / backticks in a task stay literal. **codex**
gets the prompt on **stdin** (never argv). **agy** has no stdin/file prompt input — `--print` takes the
prompt as its argument — so gavel passes it as a single `spawn` argv element (still no shell → same
injection-safety; the tradeoffs vs stdin are `ps` visibility and the `ARG_MAX` length cap, so don't put
secrets in an advisor prompt). Slash commands write the task to a temp file with the Write tool, then
pass `--prompt-file`. (`--prompt` exists for tests/programmatic use only.)

## CLI invocations (verified; flags vary by version — re-verify before changing)
- Codex (tested 0.133.0): `codex exec --color never -s read-only --skip-git-repo-check --ephemeral -m <model> -C <cwd> -o <tmp>`, prompt on stdin → read `<tmp>`.
- agy (tested 1.0.9): `agy --print <prompt> --print-timeout <secs>s [--model <model>]`, prompt passed as the `--print` argv argument (agy has no stdin prompt input), in a throwaway cwd → trimmed stdout. `--print-timeout` is set to the gavel timeout (agy's own default is only 5m).
- A provider is `ok` only on **exit code 0** with non-empty output; otherwise a structured error.
  **agy can exit 0 even when it failed** (it prints its OAuth prompt to stdout when not signed in, or
  `unknown model name <m>` for a bad model), so its `run()` detects those signatures instead of
  trusting the exit code — otherwise they'd be laundered into a fake answer and the model fallback
  (which only fires on a failed run) would never trigger.

## Config / settings (precedence low→high)
defaults < `~/.gavel/config.json` < `./.gavel.json` < env < CLI flags. Shape:
`{ "providers": { "<name>": { "enabled": bool, "model": str } }, "panel": ["<name>"...], "timeout": sec }`
- Disabled provider → skipped in fuse, not counted "missing" in setup, no warning.
- Models: `GAVEL_CODEX_MODEL` / `GAVEL_AGY_MODEL`; timeout `GAVEL_TIMEOUT` (seconds, per provider). Default timeout 1800s (30 min).
- `gavel config` (subcommand + `/gavel:config`) reads/writes ONE settings file: `set`/`unset <key>` edits `~/.gavel/config.json` by default, or `./.gavel.json` with `--project`; `show` prints the merged effective view + sources. Keys: `timeout`, `panel`, `<provider>.model`, `<provider>.enabled`. It edits a single scope (never the merged view) and refuses to clobber a file that is already invalid JSON.
- Preferred defaults are codex `gpt-5.5-pro` / agy `gemini-3-pro`. Model availability is account/tier dependent — if the resolved default isn't usable for the account (e.g. `gpt-5.5-pro` is rejected on a ChatGPT account; an agy model the account lacks errors with `unknown model name`), `runProvider` retries once with the model flag omitted so the CLI uses its own default. This fallback fires ONLY for the built-in default (`resolveModel().isDefault`); an explicit flag/env/config model is never swapped. Detection is heuristic (`looksLikeModelError`) and the fallback is logged to stderr.

## setup readiness
`ready` = at least one provider **in the resolved panel** is usable (so a panel/config that excludes
every usable provider reports not-ready, not a false positive). `degraded` = ready but some enabled
provider unusable. `missingProviders` = enabled-but-unusable. `configErrors` surfaces invalid settings
files (they're reported, not silently fail-open). `tooOld`/`versionUnknown` flag CLI version problems.

## Adding a provider
Add one entry to `PROVIDERS` in `scripts/gavel.mjs`:
`{ bin, tested, isolation, defaultModel, modelEnv, installHint, authHint, checkAuth(), run({prompt,model,cwd,timeoutMs,env}) }`.
Use `isolation: "readonly-sandbox"` ONLY if it has a real OS read-only sandbox (like codex `-s
read-only`); otherwise leave it `"isolated"` (the safe default). setup / run / fuse / panel / config
are data-driven off the map; to also expose it via `/gavel:ask`, add its name to the allow-list in
`commands/ask.md` (one line). Providers are CLI-based today — an API-key-only provider would need a
small change to the `usable` check (which currently requires a local binary).

## Conventions
- `scripts/gavel.mjs`: Node ESM, **zero npm deps** (`node:child_process`, `node:fs`, `node:os`, `node:path`).
- Advisors must never be able to write the workspace; only Claude acts. Keep it synchronous — no jobs/broker/MCP.
- Keep command markdown thin; logic/parsing lives in `gavel.mjs`. Reference plugin files via `${CLAUDE_PLUGIN_ROOT}`.
- Node project — the global "use uv for Python" rule doesn't apply (no Python here).

## Test
- `node scripts/gavel.mjs setup` (or `--json`); `bash scripts/smoke-test.sh` for the full gate.
- Per-finding regression tests are documented in the README.
