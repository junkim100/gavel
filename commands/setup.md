---
description: Check whether the Codex and agy CLIs are installed and authenticated for gavel
argument-hint: ""
allowed-tools: Bash(node:*), Bash(npm:*), AskUserQuestion
---

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/gavel.mjs" setup --json
```

Read the JSON report. It lists each provider under `providers.<name>` with `enabled`, `installed`,
`authed`, `usable`, `version`, `tooOld`, and `isolation`, plus top-level `ready`, `degraded`,
`missingProviders`, and `panel`. Then:

- **Codex** is npm-installable: if it is **enabled but not installed** (`installed: false`) while
  `npm.available` is true, use `AskUserQuestion` **once** to offer to install it now (label suffixed
  with `(Recommended)`), run `npm install -g @openai/codex`, then rerun the setup report. If npm is
  unavailable, don't offer to install — just report and point to the install docs.
- **agy** is **not** an npm package: if it is enabled but not installed, don't offer an npm install —
  tell the user to install the `agy` CLI from https://antigravity.google, then rerun setup.

Then present the final report, preserving guidance:
- If a provider is installed but not authenticated, give its auth step: Codex → run `!codex login`;
  agy → run `!agy` once to sign in (Google OAuth).
- If any provider has `tooOld: true`, warn that the installed CLI is older than the tested version and
  some required flags may be unsupported (suggest upgrading).
- A provider `disabled` in settings is intentionally skipped — do not nag about it.

Note: gavel needs **at least one** usable advisor (`ready: true`); it works best with both. Codex
explores the repo read-only; agy runs isolated. Model/timeout defaults and per-provider settings
live in `~/.gavel/config.json` or a project `./.gavel.json`.
