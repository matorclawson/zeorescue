#!/bin/bash
# Start either rescuer on a separate socket; never stop or replace an existing rescuer.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
JQ=${ZEO_RESCUE_JQ:-/opt/homebrew/bin/jq}
harness=claude
record=$STATE/rescuer.json
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) [ $# -ge 2 ] || exit 2; harness=$2; shift 2;;
    --record) [ $# -ge 2 ] || exit 2; record=$2; shift 2;;
    *) echo 'usage: agent.sh [--harness codex|claude] [--record FILE]' >&2; exit 2;;
  esac
done
case "$harness" in
  codex) binary=${ZEO_RESCUE_CODEX:-$HOME/.local/bin/codex};;
  claude) binary=${ZEO_RESCUE_CLAUDE:-$HOME/.local/bin/claude};;
  *) echo 'REFUSED: harness must be codex or claude' >&2; exit 2;;
esac
for tool in "$TMUX_BIN" "$JQ" "$binary"; do
  [[ "$tool" = /* ]] && [ -x "$tool" ] || { echo "REFUSED: missing absolute executable $tool" >&2; exit 2; }
done
# This is the rescuer's own provisioned record, not a target seat's marker or an inferred default.
marker=$("$JQ" -er 'select(.seat_id == "zeo-rescue") | .marker | select(. == "master" or . == "sparring" or . == "principal" or . == "inactive")' "$record") || {
  echo "REFUSED: provision zeo-rescue's own marker record at $record; see RESCUER.md" >&2; exit 2;
}
[[ "$marker" != *$'\n'* ]] || { echo 'REFUSED: ambiguous rescuer record' >&2; exit 2; }
# Check the selected installed CLI, using the same clean environment as launch. No model request.
help=$("$HERE/rescuer-exec.sh" --help-check "$harness" "$binary" "$marker") || {
  echo "REFUSED: cannot inspect $harness help" >&2; exit 2;
}
if [ "$harness" = codex ] && ! grep -q -- '--no-daemon' <<< "$help"; then
  echo 'REFUSED: this Codex CLI does not advertise --no-daemon; do not fall back to shared mode' >&2; exit 2
fi
mkdir -p "$STATE"
lock=$STATE/agent-launch.lock
mkdir "$lock" 2>/dev/null || { echo 'REFUSED: another launch or stale launch lock exists; inspect before retry' >&2; exit 1; }
trap 'rmdir "$lock" 2>/dev/null || true' EXIT
# Session creation is atomic: competing invocations cannot replace one another, even with different STATE paths.
if ! pane=$(env -u TMUX "$TMUX_BIN" -L zeo-rescue new-session -d -s zeo-rescue -c "$HERE" -P -F '#{pane_id}' -- sleep 3600); then
  echo 'REFUSED: rescuer already exists or tmux failed; inspect/attach with tmux -L zeo-rescue attach' >&2; exit 1
fi
[[ "$pane" =~ ^%[0-9]+$ ]] || { echo 'REFUSED: tmux returned no unique pane; inspect zeo-rescue socket' >&2; exit 1; }
cleanup() {
  echo "FAILED: rescuer bootstrap; stopping only newly created pane $pane" >&2
  "$TMUX_BIN" -L zeo-rescue kill-pane -t "$pane" || echo 'WARNING: cleanup failed; inspect before retry' >&2
  exit 1
}
"$TMUX_BIN" -L zeo-rescue set-option -p -t "$pane" @zeo_seat "$marker" || cleanup
"$TMUX_BIN" -L zeo-rescue set-option -p -t "$pane" @zeo_rescuer_harness "$harness" || cleanup
# Pass a bounded tool/path configuration explicitly. Never trust the tmux server's inherited environment.
config=(); clear_config=()
for name in ZEO_RESCUE_RECORDS ZEO_RESCUE_HOST ZEO_RESCUE_SOCKET ZEO_RESCUE_STATE ZEO_RESCUE_CHART ZEO_RESCUE_PROJECTS ZEO_RESCUE_CODEX_DB ZEO_RESCUE_SNAPSHOTS ZEO_RESCUE_TMUX ZEO_RESCUE_JQ ZEO_RESCUE_SQLITE ZEO_RESCUE_PS ZEO_RESCUE_LSOF ZEO_RESCUE_KILL ZEO_RESCUE_CLAUDE ZEO_RESCUE_CODEX ZEO_RESCUE_PINS; do
  clear_config+=(-u "$name")
  [ -z "${!name:-}" ] || config+=("$name=${!name}")
done
"$TMUX_BIN" -L zeo-rescue respawn-pane -k -t "$pane" -c "$HERE" -- /usr/bin/env "${clear_config[@]}" "HOME=$HOME" "${config[@]}" \
  "$HERE/rescuer-exec.sh" --launch "$harness" "$binary" "$marker" || cleanup
echo "START REQUESTED: $harness as zeo-rescue, marker $marker. Attach: tmux -L zeo-rescue attach"
echo 'Authentication, tool permissions and live readiness must be checked inside the rescuer with make doctor.'
