<h1 align="center">gavel 👨‍⚖️</h1>

<p align="center">
  <b>Multi-model fusion for Claude Code.</b><br>
  Ask claude + codex + agy in parallel, then judge their answers into one and act on it.
</p>

---

`/gavel:fuse <task>` asks **three** models the same thing: the **Claude Code model you're running**, **OpenAI Codex**, and **`agy`**. Codex and agy are **read-only advisors**; Claude is **panelist #3 and the actor** — the three answers are judged and synthesized into a single fused answer, which is then **acted on**. Only Claude writes to your workspace.

It runs the models through their **local CLIs** (`codex`, `agy`), reusing your existing logins. No API keys to wire up, no MCP servers, no background jobs.

## Inspiration

Gavel is inspired by OpenRouter's [**Fusion beats Frontier**](https://openrouter.ai/blog/announcements/fusion-beats-frontier/): dispatch a prompt to a panel of models, then have a judge synthesize their answers into one response that beats any single frontier model. Gavel brings that pattern into Claude Code — Codex and agy answer as advisors, and their answers are judged and fused into one before it acts.

<p align="center">
  <img src="assets/fusion-benchmark-chart.png" alt="Fused model panels outscore individual frontier models on OpenRouter's DRACO deep-research benchmark" width="720">
</p>

<sub>Benchmark chart from OpenRouter's "Fusion beats Frontier" announcement (© OpenRouter), included for reference and attribution.</sub>

## Install

In Claude Code:

```text
/plugin marketplace add junkim100/gavel
/plugin install gavel@gavel
```

(Reload/restart if prompted.)

**Local development** — clone the repo and point the marketplace at the clone instead:

```text
git clone https://github.com/junkim100/gavel.git
/plugin marketplace add /path/to/gavel    # the cloned directory
/plugin install gavel@gavel
```

## Setup

```text
/gavel:setup
```

Reports whether `codex` and `agy` are installed, authenticated, and recent enough, and offers to install codex if it's missing. Authentication:

- **Codex** — `!codex login` (install: `npm install -g @openai/codex`).
- **agy** — run `!agy` once to sign in (Google OAuth). Install the `agy` CLI from <https://antigravity.google> (it isn't an npm package).

Gavel needs **at least one** advisor usable, but works best with both.

## Commands

| Command | What it does |
| --- | --- |
| `/gavel:fuse <task>` | Ask Claude + Codex + agy in parallel, synthesize one fused answer, then act on it. |
| `/gavel:ask <codex\|agy> <prompt>` | Send a prompt to a single model and show its answer verbatim (no fusing, no edits). |
| `/gavel:setup` | Check/install/auth the Codex and agy CLIs. |
| `/gavel:config [show \| set <key> <value> \| unset <key>]` | View or change settings (model, timeout, panel) in the user or `--project` config file. |

## How advisors stay read-only

Only Claude modifies your workspace. The two advisors are constrained differently because their CLIs differ:

- **Codex** runs in your project under its OS read-only sandbox (`-s read-only`) — a hard boundary: it reads your code but cannot change it.
- **agy** has no equivalent read-only sandbox (`--sandbox` only restricts the terminal, and `--dangerously-skip-permissions` would auto-approve writes), so gavel runs it **isolated**: in a throwaway directory with `PWD`/`OLDPWD` scrubbed, so it can't discover your repo path or make relative writes into it. It answers from the task text — include any code agy should see directly in your task. Note this is isolation, **not a hardened sandbox**: agy still inherits `$HOME` and could act on an absolute path you hand it, so don't paste untrusted content into a fuse expecting confinement.
- Prompts are passed via a temp file and **never go through a shell** — gavel runs each CLI with `spawn` (no shell), so quotes / `$(...)` / backticks in a task stay literal and can't inject. Codex receives the prompt on **stdin**; agy has no stdin prompt input, so its prompt is passed as a direct process argument (still no shell, so the same injection-safety holds — but it's briefly visible in `ps`, so don't put secrets in an advisor prompt).

## Configuration

Defaults: Codex `gpt-5.5-pro`, agy `gemini-3-pro`, per-model timeout `1800s` (30 min). These are the *preferred* defaults — if your account can't use them, gavel automatically falls back to whatever model the codex/agy CLI itself defaults to (a model you explicitly set is always respected, never swapped). Override via env vars (`GAVEL_CODEX_MODEL`, `GAVEL_AGY_MODEL`, `GAVEL_TIMEOUT`) or a settings file — `~/.gavel/config.json` (user) or `./.gavel.json` (project).

Easiest way to change settings is the `config` command (no hand-editing JSON):

```bash
/gavel:config show                       # effective settings + which file each comes from
/gavel:config set timeout 600            # 10-min timeout, for all projects (~/.gavel/config.json)
/gavel:config set codex.model gpt-5.5    # pin a model (opts that provider out of auto-fallback)
/gavel:config set agy.model gemini-3-pro --project       # this repo only (./.gavel.json)
/gavel:config unset codex.model          # restore the preferred default + auto-fallback
```

Keys: `timeout` (seconds), `panel` (comma-separated), `<provider>.model`, `<provider>.enabled`. Or edit the file directly:

```json
{
  "providers": {
    "codex": { "enabled": true, "model": "gpt-5.5-pro" },
    "agy":   { "enabled": true, "model": "gemini-3-pro" }
  },
  "panel": ["codex", "agy"],
  "timeout": 1800
}
```

- Set a provider `"enabled": false` to skip it everywhere with **no repeated warnings**.
- `panel` selects which providers `/gavel:fuse` queries (default: all enabled).

> agy model availability depends on your account/tier. If a model isn't available, set `GAVEL_AGY_MODEL` to one you can access (run `agy models` to list them).

## Adding another model

`scripts/gavel.mjs` is built around a `PROVIDERS` registry. To add a CLI (e.g. a future `qwen`), add one entry — its binary, default model, auth check, and a `run()` that invokes it read-only with the prompt fed via stdin or a process argument (never a shell) — and leave it `isolated` (the default) unless it has a real OS read-only sandbox like Codex. It then appears in `/gavel:setup` and the `/gavel:fuse` panel automatically; to also expose it via `/gavel:ask`, add its name to the one-line allow-list in `commands/ask.md`. (Providers are CLI-based today; an API-key-only provider would need a small tweak to the `usable` check.)

## Requirements & versions

`node`, the `codex` CLI (logged in), and the `agy` CLI (logged in). Tested with **codex ≥ 0.133.0** and **agy ≥ 1.0.9**; older versions may lack required flags — `/gavel:setup` warns if your CLI is older than tested.

## Testing

`bash scripts/smoke-test.sh` runs the deterministic checks (read-only enforcement, prompt injection-safety, strict exit codes, degraded/disabled readiness). The in-Claude-Code behavior of the slash commands (`/gavel:fuse` synthesizing then acting) is best verified live in a scratch repo.

## License

MIT — see [LICENSE](./LICENSE).
