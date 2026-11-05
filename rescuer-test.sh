#!/bin/bash
# Offline bootstrap and cross-harness environment tests. No real model, tmux server or seats.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home" "$T/state"
JQ=$(command -v jq) || { echo 'jq required'; exit 1; }
pass=0
ok() { pass=$((pass+1)); echo "ok $pass - $1"; }
fail() { echo "FAIL: $1"; exit 1; }
cat > "$T/bin/harness" <<S
#!/bin/bash
if [ "\${1:-}" = --help ]; then
  if [ -f '$T/no-flag' ]; then echo 'usage'; else echo 'usage --no-daemon'; fi
  exit 0
fi
printf '%s\n' "\$@" > '$T/args'
env | sort > '$T/env'
pwd > '$T/cwd'
S
cat > "$T/bin/tmux" <<S
#!/bin/bash
printf '%s\n' "\$*" >> '$T/tmux.log'
case "\$3" in
 new-session) [ ! -f '$T/existing' ] || exit 1; echo %42;;
 set-option) [ ! -f '$T/marker-fail' ] || exit 1;;
 respawn-pane)
   while [ "\$1" != -- ]; do shift; done; shift
   export TMUX='/fake/zeo-rescue,1,0' TMUX_PANE=%42 ZEO_RESCUE_CHART=/stale-from-server
   export BASH_ENV='$T/poison'
   exec "\$@";;
 kill-pane) exit 0;;
 *) exit 2;;
esac
S
printf 'echo POISONED > "%s"\n' "$T/poisoned" > "$T/poison"
chmod +x "$T/bin/"*
export HOME="$T/home" ZEO_RESCUE_STATE="$T/state" ZEO_RESCUE_TMUX="$T/bin/tmux" ZEO_RESCUE_JQ="$JQ"
export ZEO_RESCUE_CODEX="$T/bin/harness" ZEO_RESCUE_CLAUDE="$T/bin/harness"
printf '{"seat_id":"zeo-rescue","marker":"master"}\n' > "$T/state/rescuer.json"
for h in codex claude; do
  : > "$T/tmux.log"
  CLAUDECODE=caller CODEX_THREAD_ID=caller ZMAIL_INSTANCE=borrowed GIT_ALLOW_PROTOCOL=file SECRET_LEAK=secret \
    "$HERE/agent.sh" --harness "$h" > "$T/out" 2>&1 || fail "$h launch: $(cat "$T/out")"
  grep -qx 'ZMAIL_INSTANCE=zeo-rescue' "$T/env" || fail "$h identity"; ok "$h uses own identity"
  grep -Eq '^(CLAUDECODE|CODEX_THREAD_ID|SECRET_LEAK|GIT_ALLOW_PROTOCOL|BASH_ENV)=' "$T/env" && fail "$h contamination"
  [ ! -e "$T/poisoned" ] || fail 'startup injection'; ok "$h drops caller identity, restrictions and shell injection"
  grep -qx "HOME=$T/home" "$T/env" && grep -qx 'TMUX_PANE=%42' "$T/env" || fail "$h home/pane"; ok "$h retains home and its actual pane"
  grep -q '^ZEO_RESCUE_CHART=' "$T/env" && fail 'stale server override survived'; ok "$h drops stale tmux tool configuration"
  grep -qx "ZEO_RESCUE_TMUX=$T/bin/tmux" "$T/env" || fail 'explicit tools lost'; ok "$h receives explicit tools"
  [ "$(cat "$T/cwd")" = "$HERE" ] || fail 'wrong cwd'; ok "$h starts in shared checkout"
  mark=$(grep -n 'set-option .*@zeo_seat master' "$T/tmux.log" | cut -d: -f1)
  launch=$(grep -n respawn-pane "$T/tmux.log" | cut -d: -f1)
  [ "$mark" -lt "$launch" ] || fail 'marker order'; ok "$h marker precedes launch"
  grep -q 'Read AGENTS.md, STATE.md, RESCUER.md and RUNBOOK.md' "$T/args" || fail 'shared boot'; ok "$h gets shared boot prompt"
  if [ "$h" = codex ]; then grep -qx -- '--no-daemon' "$T/args" || fail 'no daemon flag'; ok 'Codex rescuer cannot silently join shared daemon'
  else grep -q -- '--permission-mode\|--dangerously-skip-permissions' "$T/args" && fail 'permission override'; ok 'Claude inherits configured permissions without bypass flags'; fi
  grep -q '^START REQUESTED:' "$T/out" || fail 'false ready'; ok "$h reports startup request, not proven recovery"
done
: > "$T/tmux.log"; touch "$T/no-flag"
if "$HERE/agent.sh" --harness codex > "$T/out" 2>&1; then fail 'unsupported codex accepted'; fi
[ ! -s "$T/tmux.log" ] || fail 'unsupported codex touched tmux'; ok 'unsupported Codex fails before tmux mutation'
rm "$T/no-flag"
for record in '{"seat_id":"other","marker":"master"}' '{"seat_id":"zeo-rescue","marker":null}'; do
  printf '%s\n' "$record" > "$T/state/rescuer.json"; : > "$T/tmux.log"
  if "$HERE/agent.sh" > "$T/out" 2>&1; then fail 'invalid record accepted'; fi
  [ ! -s "$T/tmux.log" ] || fail 'invalid record touched tmux'; ok 'missing/foreign marker record refused'
done
printf '{"seat_id":"zeo-rescue","marker":"inactive"}\n' > "$T/state/rescuer.json"
"$HERE/agent.sh" --harness codex > "$T/out" 2>&1 || fail 'inactive launch'
grep -qx 'GIT_ALLOW_PROTOCOL=file' "$T/env" || fail 'inactive git'; ok 'recorded inactive remains restricted'
touch "$T/existing"; : > "$T/tmux.log"
if "$HERE/agent.sh" > "$T/out" 2>&1; then fail 'existing rescuer replaced'; fi
grep -q 'respawn-pane\|kill-pane' "$T/tmux.log" && fail 'existing rescuer mutated'; ok 'existing rescuer is never replaced'
rm "$T/existing"; touch "$T/marker-fail"; : > "$T/tmux.log"
if "$HERE/agent.sh" > "$T/out" 2>&1; then fail 'marker failure accepted'; fi
grep -q respawn-pane "$T/tmux.log" && fail 'started before marker'; grep -q 'kill-pane -t %42' "$T/tmux.log" || fail 'no cleanup'; ok 'marker failure cleans only newly created pane'
rm "$T/marker-fail"
mkdir "$T/state/agent-launch.lock"; : > "$T/tmux.log"
if "$HERE/agent.sh" > "$T/out" 2>&1; then fail 'concurrent launch accepted'; fi
[ ! -s "$T/tmux.log" ] || fail 'lock ignored'; ok 'concurrent/stale launch lock refuses'
rmdir "$T/state/agent-launch.lock"
# Existing target adapter must not care which harness is doing the rescuing.
printf 'read only proof' > "$T/prompt"
for rescuer in codex claude; do
  for target in codex claude; do
    ZMAIL_INSTANCE=wrong CLAUDECODE="$rescuer" CODEX_THREAD_ID="$rescuer" SECRET_LEAK=yes TMUX=/fake TMUX_PANE=%99 \
      sh "$HERE/seat-exec.sh" target-seat "$target" "$T/prompt" "$T/bin/harness" --resume target-history
    grep -qx 'ZMAIL_INSTANCE=target-seat' "$T/env" || fail "$rescuer to $target identity"
    grep -Eq '^(CLAUDECODE|CODEX_THREAD_ID|SECRET_LEAK)=' "$T/env" && fail "$rescuer to $target contamination"
    grep -qx 'target-history' "$T/args" && grep -qx 'read only proof' "$T/args" || fail 'target argv'
    ok "$rescuer rescuer -> $target target: isolated identity, history argument and prompt"
  done
done
# Diagnostic JSON must never confer permission to restart.
ZEO_RESCUE_SQLITE=/missing ZEO_RESCUE_LSOF=/missing "$HERE/doctor.sh" --json > "$T/doctor.json" 2> "$T/doctor.err" && fail 'missing dependencies accepted'
"$JQ" -e '.schema_version == 1 and .restart_cleared == false and .inspection_tools_ready == false' "$T/doctor.json" >/dev/null || fail 'doctor JSON'
ok 'diagnostics emit structured missing capabilities without clearing recovery'
grep -q '^@AGENTS.md$' "$HERE/CLAUDE.md" || fail 'Claude instructions drift'; ok 'Claude imports canonical policy'
echo "PASS: $pass offline checks; no real harness or host recovery qualified"
