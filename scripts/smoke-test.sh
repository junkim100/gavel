#!/usr/bin/env bash
# Deterministic smoke tests for gavel's runner. Makes real Codex/agy calls, so both should be
# authenticated (run /gavel:setup first); tests for an unusable provider are skipped. Exits non-zero
# on any failure. Usage: bash scripts/smoke-test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAVEL="$ROOT/scripts/gavel.mjs"
pass=0; fail=0
ok()  { echo "PASS: $1"; pass=$((pass + 1)); }
bad() { echo "FAIL: $1"; fail=$((fail + 1)); }
# read a (possibly nested) field from JSON on stdin: get <dotted.path>
get() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let v=JSON.parse(s);for(const k of process.argv[1].split("."))v=v==null?v:v[k];process.stdout.write(v==null?"":typeof v==="object"?JSON.stringify(v):String(v));})' "$1"; }

REPORT="$(node "$GAVEL" setup --json)"
if printf '%s' "$REPORT" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s))' 2>/dev/null; then
  ok "setup --json is valid JSON"
else
  bad "setup --json is valid JSON"; echo "== aborting: setup failed =="; exit 1
fi
CODEX_USABLE="$(printf '%s' "$REPORT" | get providers.codex.usable)"
AGY_USABLE="$(printf '%s' "$REPORT" | get providers.agy.usable)"
echo "(codex usable=$CODEX_USABLE, agy usable=$AGY_USABLE)"

# 1. exit-code: a bad model must error, not be a fake success
if node "$GAVEL" run --provider agy --model not-a-real-model-xyz --prompt "hi" --timeout 45 >/dev/null 2>&1; then
  bad "bad model errors (no fake [ok])"
else
  ok "bad model errors (no fake [ok])"
fi

# 2. injection: shell metacharacters in a prompt file must NOT execute (codex on stdin, agy on argv)
rm -f /tmp/GAVEL_INJ_1 /tmp/GAVEL_INJ_2
D="$(mktemp -d)"; printf '%s' 'literal, do not run: $(touch /tmp/GAVEL_INJ_1) `touch /tmp/GAVEL_INJ_2`' > "$D/p.txt"
[ "$CODEX_USABLE" = "true" ] && node "$GAVEL" run --provider codex --cwd "$D" --prompt-file "$D/p.txt" --timeout 120 >/dev/null 2>&1
[ "$AGY_USABLE" = "true" ] && node "$GAVEL" run --provider agy --cwd "$D" --prompt-file "$D/p.txt" --timeout 120 >/dev/null 2>&1
if [ -e /tmp/GAVEL_INJ_1 ] || [ -e /tmp/GAVEL_INJ_2 ]; then bad "prompt metacharacters did not execute"; else ok "prompt metacharacters did not execute"; fi
rm -f /tmp/GAVEL_INJ_1 /tmp/GAVEL_INJ_2; rm -rf "$D"

# 3. read-only: advisors must not create files in the project dir
if [ "$CODEX_USABLE" = "true" ]; then
  D="$(mktemp -d)"; printf '%s' 'Create a file named W.txt in your working directory using any tool, then say DONE.' > "$D/p.txt"
  node "$GAVEL" run --provider codex --cwd "$D" --prompt-file "$D/p.txt" --timeout 120 >/dev/null 2>&1
  [ -e "$D/W.txt" ] && bad "codex did not write the project" || ok "codex did not write the project"
  rm -rf "$D"
fi
if [ "$AGY_USABLE" = "true" ]; then
  D="$(mktemp -d)"; printf '%s' 'Create a file named W.txt in your current working directory using any tool available, then say DONE.' > "$D/p.txt"
  node "$GAVEL" run --provider agy --cwd "$D" --prompt-file "$D/p.txt" --timeout 120 >/dev/null 2>&1
  [ -e "$D/W.txt" ] && bad "agy did not write the project" || ok "agy did not write the project"
  rm -rf "$D"
fi

# 4. degraded readiness: codex forced unusable -> still ready via agy, degraded:true
if [ "$AGY_USABLE" = "true" ]; then
  DR="$(env CODEX_HOME=/nonexistent node "$GAVEL" setup --json)"
  R="$(printf '%s' "$DR" | get ready)"; DEG="$(printf '%s' "$DR" | get degraded)"
  { [ "$R" = "true" ] && [ "$DEG" = "true" ]; } && ok "degraded readiness (codex down, agy up)" || bad "degraded readiness (ready=$R degraded=$DEG)"
fi

# 5. disabled provider is skipped, not reported 'missing'
D="$(mktemp -d)"; printf '%s' '{"providers":{"codex":{"enabled":false}}}' > "$D/.gavel.json"
GR="$(node "$GAVEL" setup --cwd "$D" --json)"
EN="$(printf '%s' "$GR" | get providers.codex.enabled)"; MISS="$(printf '%s' "$GR" | get missingProviders)"
{ [ "$EN" = "false" ] && ! printf '%s' "$MISS" | grep -q codex; } && ok "disabled provider skipped (not 'missing')" || bad "disabled provider skipped (enabled=$EN missing=$MISS)"
rm -rf "$D"

# 6. readiness reflects the resolved panel (panel naming only a disabled provider -> not ready)
D="$(mktemp -d)"; printf '%s' '{"panel":["agy"],"providers":{"agy":{"enabled":false}}}' > "$D/.gavel.json"
RD="$(node "$GAVEL" setup --cwd "$D" --json | get ready)"
[ "$RD" = "false" ] && ok "empty-panel => ready:false (no false-positive dead-end)" || bad "panel readiness (ready=$RD)"
rm -rf "$D"

# 7. run refuses a config-disabled provider (no fake execution)
D="$(mktemp -d)"; printf '%s' '{"providers":{"codex":{"enabled":false}}}' > "$D/.gavel.json"
if node "$GAVEL" run --provider codex --cwd "$D" --prompt "hi" >/dev/null 2>&1; then bad "disabled provider rejected by run"; else ok "disabled provider rejected by run"; fi
rm -rf "$D"

# 8. malformed config is surfaced, not silently fail-open
D="$(mktemp -d)"; printf '%s' '{"providers":{"codex":{"enabled":false},}}' > "$D/.gavel.json"
case "$(node "$GAVEL" setup --cwd "$D" --json | get configErrors)" in *invalid*) ok "malformed config surfaced";; *) bad "malformed config surfaced";; esac
rm -rf "$D"

# 9. non-positive timeout is clamped to the default
D="$(mktemp -d)"; printf '%s' '{"timeout":-5}' > "$D/.gavel.json"
TS="$(node "$GAVEL" setup --cwd "$D" --json | get timeoutSeconds)"
[ "$TS" = "1800" ] && ok "negative timeout clamped to default" || bad "timeout clamp (got $TS)"
rm -rf "$D"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
