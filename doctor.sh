#!/bin/bash
# Read-only capability inventory. No credentials, model calls, mail calls, starts or stops.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
JQ=${ZEO_RESCUE_JQ:-/opt/homebrew/bin/jq}
format=${1:-text}
case "$format" in text|--json) ;; *) echo 'usage: doctor.sh [--json]' >&2; exit 2;; esac
if [ ! -x "$JQ" ]; then
  echo '{"schema_version":1,"inspection_tools_ready":false,"restart_cleared":false,"error":"jq unavailable; set ZEO_RESCUE_JQ to its absolute path"}'
  exit 1
fi
records=(); missing=0
add() { records+=("$("$JQ" -cn --arg name "$1" --arg status "$2" --arg detail "$3" '{name:$name,status:$status,detail:$detail}')"); }
tool() {
  if [ -x "$2" ]; then add "$1" available "$2"; else add "$1" missing "$2"; missing=$((missing+1)); fi
}
TM=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
SQL=${ZEO_RESCUE_SQLITE:-/usr/bin/sqlite3}
PS=${ZEO_RESCUE_PS:-/bin/ps}
LSOF=${ZEO_RESCUE_LSOF:-/usr/sbin/lsof}
for name in bash zsh make perl awk sed grep find sort tail head cut paste date mktemp shasum; do
  p=$(command -v "$name" 2>/dev/null) || p=""
  if [ -n "$p" ]; then add "$name" available "$p"; else add "$name" missing 'required local utility'; missing=$((missing+1)); fi
done
tool tmux "$TM"; tool sqlite3 "$SQL"; tool ps "$PS"; tool lsof "$LSOF"
if "$PS" -axo pid=,command= >/dev/null 2>&1; then add process_inventory observed 'ps enumeration succeeded; visibility still depends on host permissions'
else add process_inventory blocked 'ps failed; no stop/start may rely on this inventory'; missing=$((missing+1)); fi
if "$LSOF" -a -d cwd -p $$ >/dev/null 2>&1; then add self_lsof observed 'can inspect this process; does not prove visibility of every writer'
else add self_lsof unknown 'could not inspect own cwd; investigate lsof permissions'; fi
for harness in codex claude; do
  if [ "$harness" = codex ]; then binary=${ZEO_RESCUE_CODEX:-$HOME/.local/bin/codex}; else binary=${ZEO_RESCUE_CLAUDE:-$HOME/.local/bin/claude}; fi
  if [ ! -x "$binary" ]; then add "$harness" missing "$binary; targets using this harness cannot be resumed"; continue; fi
  help=$("$HERE/rescuer-exec.sh" --help-check "$harness" "$binary" inactive 2>/dev/null); rc=$?
  if [ "$rc" -ne 0 ]; then add "$harness" blocked 'CLI help failed'; continue; fi
  if [ "$harness" = codex ] && ! grep -q -- '--no-daemon' <<< "$help"; then
    add "$harness" blocked 'required --no-daemon capability missing'
  else add "$harness" available 'CLI help works; login, model access and actual resume not tested'; fi
done
for file in AGENTS.md CLAUDE.md STATE.md RUNBOOK.md RESCUER.md RECORDS.md records.sh rescue.sh seat-exec.sh reseat-lines.sh; do
  if [ -r "$HERE/$file" ]; then add "$file" readable 'shared recovery context/mechanism'; else add "$file" missing 'restore the reviewed checkout'; missing=$((missing+1)); fi
done
state=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
chart=${ZEO_RESCUE_CHART:-/Volumes/ZeoWork/zeo-evidence/zeo-rt-seats/org-chart/ORG-CHART.json}
if "$JQ" -e '.seats | type == "array"' "$chart" >/dev/null 2>&1; then add chart readable "$chart"
elif "$JQ" -e '.seats | type == "array"' "$state/ORG-CHART.last-good.json" >/dev/null 2>&1; then add chart fallback 'last-good chart only; freshness and target identity require review'
else add chart missing 'neither live nor last-good chart readable'; fi
db=${ZEO_RESCUE_CODEX_DB:-$HOME/.codex/state_5.sqlite}
if [ -f "$db" ] && "$SQL" "file:$db?mode=ro" 'select id from threads limit 0;' >/dev/null 2>&1; then add codex_history readable 'read-only threads query succeeded; not a compatibility or ownership proof'
else add codex_history unavailable 'Codex recovery needs readable state DB and the selected rollouts'; fi
projects=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
if [ -d "$projects" ] && [ -r "$projects" ] && [ -x "$projects" ]; then add claude_history readable 'projects directory accessible; selected transcripts still need validation'
else add claude_history unavailable 'Claude recovery needs the original project transcripts'; fi
if [ "${ZMAIL_INSTANCE:-}" = zeo-rescue ]; then add identity observed 'ZMAIL_INSTANCE=zeo-rescue'
else add identity unknown 'run doctor inside the rescuer; never borrow another identity'; fi
if [ -n "${TMUX_PANE:-}" ]; then
  marker=$("$TM" display-message -p -t "$TMUX_PANE" '#{@zeo_seat}' 2>/dev/null) || marker=""
  case "$marker" in master|sparring|principal|inactive) add pane_marker observed "$marker";; *) add pane_marker unknown 'missing/unrecognized current-pane marker';; esac
else add pane_marker unknown 'not in a tmux pane'; fi
for optional in git gh zmsg; do
  p=$(command -v "$optional" 2>/dev/null) || p=""
  if [ -n "$p" ]; then add "$optional" available 'executable found; authorization/network/mail registration untested'
  else add "$optional" unavailable 'optional for core inspection; required for its corresponding workflow'; fi
done
if record_status=$("$HERE/records.sh" status 2>/dev/null); then
  count=$("$JQ" -r '.records|length' <<< "$record_status")
  issues=$("$JQ" -r '[.issues[]|select(.blocking)]|length' <<< "$record_status")
  add recovery_records observed "$count saved mappings; $issues blocking capture issues; inspect make records-status"
else add recovery_records unavailable 'no valid local recovery records; enable capture during normal operation'; fi
health=$("$HERE/records.sh" health 2>&1); rc=$?
case "$rc" in
  0) add records_health observed "$(head -1 <<< "$health")";;
  3) add records_health blocked "$(head -1 <<< "$health")";;
  *) add records_health stale "$(head -1 <<< "$health")";;
esac
if [ -d "${ZEO_RESCUE_RECORDS:-$state/recovery-records.json}.lock" ]; then
  add records_lock unknown 'capture in progress or stale lock; inspect collector before clearing'
fi
add authentication unknown 'Use the selected CLI login normally; doctor never reads or prints credentials'
add tool_permissions unknown 'Verify from the actual harness; no blanket allowlists or approval bypasses installed'
add shell_loader unknown 'Marker and identity must also be checked in actual tool shells on this host'
add mailbox unknown 'No mail call made; use only zeo-rescue if registered, otherwise operator relay'
add live_restart operator_only 'Requires reviewed operator action; diagnostics never clear a restart'
report=$(printf '%s\n' "${records[@]}" | "$JQ" -s --argjson ready "$([ "$missing" -eq 0 ] && echo true || echo false)" '{schema_version:1,inspection_tools_ready:$ready,restart_cleared:false,checks:.}') || exit 1
if [ "$format" = --json ]; then printf '%s\n' "$report"
else printf '%s\n' "$report" | "$JQ" -r '.checks[] | "\(.status | ascii_upcase) \(.name): \(.detail)"'; fi
[ "$missing" -eq 0 ]
