#!/bin/bash
# ENG-POMAR-RELOGIN, 11 Nov 2026, zeo-rescue: restart pomar (session pomar-maintainer) on ENG-UK in place once more, so that its Codex reads
# the operator's new login (auth.json written 17:01Z). The process started at 16:23Z kept the old token (17:02Z: token could not be refreshed).
# It is ENG-POMAR-UPGRADE (b6081acc) with two changes: the seat must already run 0.167.1, and it is ALREADY DONE once its process started
# after the login file was last written. Run from the Mac mini: ssh ENG-UK /bin/bash -s < this file. This line:
#   checks the place, the six staged files, the installed Codex and that the seat is live, on 0.167.1, started before the login, idle and the only holder of its rollout;
#   stops it (its session, then its process if needed) and waits until no process holds its rollout;
#   resumes it with the staged rescue.sh exactly as 7 Nov line 2, with this note in place of the cleanup note, then --check;
#   waits up to 10 minutes for its model's answer (model-answered.sh, bootstrap's ec8a6f65, written here from this file).
# It changes nothing else: no config, no mail, no other seat, no file outside its own state folder.
{
D=/Users/rodbot/.local/share/zeo/runtime-pomar-resume-20261107
S=/Users/rodbot/.local/state/zeo-rescue/eng-uk-relogin-20261111
PLACE="rodbot 503 ENG-UK-0006"
T=/opt/homebrew/bin/tmux
SOCK=zeo2
CODEX=/Users/rodbot/.local/bin/codex
NEW_VERSION="codex-cli 0.167.1"
NEW_BIN=/Users/rodbot/.codex/packages/standalone/releases/0.167.1-aarch64-apple-darwin/bin/codex
SEAT=pomar SESS=pomar-maintainer
SID=01a101bc-0986-79e1-b3bd-b3bbc2a05da2
ROLL=/Users/rodbot/.codex/sessions/2026/10/03/rollout-2026-10-03T13-27-42-01a101bc-0986-79e1-b3bd-b3bbc2a05da2.jsonl
LSOF=/usr/sbin/lsof
AUTH=/Users/rodbot/.codex/auth.json
NOTE_SHA=de90ae394013498f3d61a15a75e443522d8a46c7f41acf0d2e1fad94f8f711c2
MA_SHA=ec8a6f65e245aac98a2c34ef84ecd2f8926b041b150bbdaac83f32fdc5d925d1
WAIT=600

sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/cut -d ' ' -f 1; }
ck() { h=$(sha "$D/$2"); [ "$h" = "$1" ] || { echo "HASH MISMATCH, nothing was run: $D/$2 is ${h:-missing}"; bad=1; }; }
holders() { "$LSOF" -t "$ROLL" 2>/dev/null | /usr/bin/sort -u | /usr/bin/paste -sd ' ' -; }
alive() { /bin/kill -0 "$1" 2>/dev/null; }
R() { /usr/bin/env -u ZEO_RESCUE_DEFAULT_MARKER ZEO_RESCUE_JQ=/usr/bin/jq ZEO_RESCUE_CLAUDE=/opt/homebrew/bin/claude /bin/bash "$D/rescue.sh" --host ENG-UK --chart "$D/ORG-CHART.json" --note-file "$S/relogin-note.txt" --no-loader "$@"; }

main() {
  bad=0
  if [ "$(/usr/bin/id -un) $(/usr/bin/id -u) $(/bin/hostname -s)" != "$PLACE" ]; then echo "WRONG PLACE, nothing was run: this is $(/usr/bin/id -un) $(/usr/bin/id -u) $(/bin/hostname -s)"; return 2; fi
  ck af7405e29faaaeb0fa4bf2a6a1846f6ae93a3c6f17356e3d45dbcabecbc30987 rescue.sh; ck 9350ecf29e596aa0c3e3c3cc0578780a954842d4f9020c0e351a3ac9cab51810 seat-exec.sh
  ck 889dcaf03b7e41aba917cb2b64dcbdb344d222d0e8b9ad1109e70fe24982eaaa session-pins; ck cd5fc3d4a60aa33bd64bf2726e7a756c35381a8e2a3936d85555fe69a8cfdb97 folder-moves
  ck 0fce7366248f3cd2bb7262eb9d7bd0047e01ec63c9f61de5d140af99ac3da690 ORG-CHART.json; ck 098a85e65bb0e1d92f6095d77e79d7192bd2115526c7a6f7fcb56a9044253d7d cleanup-note.txt
  [ -x "$D/seat-exec.sh" ] || { echo "NOT EXECUTABLE, nothing was run: $D/seat-exec.sh"; bad=1; }
  [ $bad = 0 ] || return 2

  # The installed Codex is the one this line was written for.
  v=$("$CODEX" --version 2>/dev/null); rb=$(/bin/realpath "$CODEX" 2>/dev/null)
  [ "$v" = "$NEW_VERSION" ] && [ "$rb" = "$NEW_BIN" ] || { echo "REFUSED, nothing was run: $CODEX is '${v:-no version}' at ${rb:-nothing}, not $NEW_VERSION at $NEW_BIN. Tell zeo-rescue."; return 2; }

  # The seat is live, holds its own thread, and runs an older binary.
  "$T" -L "$SOCK" has-session -t "=$SESS" 2>/dev/null || { echo "DOWN, nothing was run: no session $SESS. Tell zeo-rescue: a down seat is resumed by its own line."; return 2; }
  pids=$("$T" -L "$SOCK" list-panes -s -t "=$SESS" -F '#{pane_pid}' 2>/dev/null)
  [ "$(printf '%s\n' "$pids" | /usr/bin/grep -c .)" = 1 ] || { echo "REFUSED, nothing was run: $SESS has not exactly one pane (${pids//$'\n'/ })"; return 2; }
  P=$pids; cmd=$(/bin/ps -o command= -p "$P" 2>/dev/null)
  case "$cmd" in *" resume "*"--no-daemon"*"$SID"*) ;; *) echo "REFUSED, nothing was run: pid $P in $SESS is not codex resume --no-daemon $SID: ${cmd:0:160}"; return 2;; esac
  run=$("$LSOF" -a -p "$P" -d txt -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p' | /usr/bin/grep -m1 '/bin/codex$')
  [ -n "$run" ] || { echo "REFUSED, nothing was run: cannot read which binary pid $P runs"; return 2; }
  [ "$run" = "$NEW_BIN" ] || { echo "REFUSED, nothing was run: pid $P runs $run, not $NEW_BIN. Tell zeo-rescue."; return 2; }
  st=$(LC_ALL=C /bin/date -j -f "%a %b %e %T %Y" "$(LC_ALL=C /bin/ps -o lstart= -p "$P" | /usr/bin/sed "s/  */ /g; s/^ //; s/ $//")" +%s 2>/dev/null); au=$(/usr/bin/stat -f %m "$AUTH" 2>/dev/null)
  [ -n "$st" ] && [ -n "$au" ] || { echo "REFUSED, nothing was run: cannot read when pid $P started or when $AUTH was written"; return 2; }
  [ "$st" -le "$au" ] || { echo "ALREADY DONE: $SEAT (pid $P) started after the login was last written"; return 0; }
  echo "RELOGIN $SEAT: pid $P started $(/bin/date -u -r "$st" +%H:%M:%SZ), before the login was written at $(/bin/date -u -r "$au" +%H:%M:%SZ)"

  # Idle: its last turn ended, nothing written for a minute, and it alone holds its rollout.
  last=$(/usr/bin/tail -c 200000 "$ROLL" 2>/dev/null | /usr/bin/tail -1)
  case "$last" in *'"type":"task_complete"'*|*'"type":"turn_aborted"'*) ;; *) echo "BUSY, nothing was run: its last record is not the end of a turn. Run the line again when it is idle."; return 2;; esac
  age=$(( $(/bin/date +%s) - $(/usr/bin/stat -f %m "$ROLL") ))
  [ "$age" -ge 60 ] || { echo "BUSY, nothing was run: its rollout was written ${age}s ago. Run the line again in a minute."; return 2; }
  h=$(holders); [ "$h" = "$P" ] || { echo "REFUSED, nothing was run: the rollout is held by '${h:-nobody}', not pid $P alone. Tell zeo-rescue."; return 2; }
  echo "IDLE $SEAT: last turn ended, rollout untouched for ${age}s, held by pid $P only"

  # Its own files for this run, written from this line and checked.
  /bin/mkdir -p -m 700 "$S" || { echo "FAILED, nothing was run: cannot make $S"; return 1; }
  /bin/cat > "$S/relogin-note.txt" <<'NOTE_EOF'
Correction to the line above: this host's login session was not torn down. This is a planned restart by the operator, on the Architect's read, so that your Codex picks up the operator's new Codex login on this host (17:01Z on 11 Nov). Your turns since 13:31Z ended in model_not_found or a token error and did nothing, so anything they were for is still owed. Same thread, same folder, same settings, same orders.
NOTE_EOF
  /bin/cat > "$S/model-answered.sh" <<'MA_EOF'
#!/bin/bash
# model-answered.sh LOG [WAIT_SECONDS]: did each seat a run restarted get an answer from its model? It reads only.
# A seat is every "RESUMED SEAT: HARNESS SESSION" line of LOG; the restart time is LOG's birth, so only records written after it count.
#   ANSWERED  an assistant message after the restart
#   ERROR     a turn that ended in an error after it, or an API error message; the error is shown
#   WAITING   neither yet, after WAIT_SECONDS (default 0)
# A process that is up proves nothing about the model: on 10 Nov every Codex seat was up and every request failed.
# Exit: 0 every seat ANSWERED, or none was restarted; 1 any ERROR; 2 any still WAITING; 3 a seat's record cannot be found.
set -uo pipefail
log=${1:-} wait=${2:-0}
[ -r "$log" ] && [[ "$wait" =~ ^[0-9]+$ ]] || { echo "usage: model-answered.sh LOG [WAIT_SECONDS]" >&2; exit 2; }
SESSIONS=${ZEO_RESCUE_CODEX_SESSIONS:-$HOME/.codex/sessions}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
TAIL=${ZEO_RESCUE_ANSWER_TAIL:-8000000} # the end of a rollout is enough, and one is 1.7 GB
PAUSE=${ZEO_RESCUE_ANSWER_PAUSE:-5}
since=$(TZ=UTC /bin/date -r "$(/usr/bin/stat -f %B "$log")" +%Y-%m-%dT%H:%M:%S) || exit 3

seats=() harn=() files=()
missing=0
while read -r _ seat h sid _; do
  seat=${seat%:}
  case "$h" in
    codex) f=$(/usr/bin/find "$SESSIONS" -name "rollout-*-$sid.jsonl" 2>/dev/null | head -1);;
    claude) f=$(/usr/bin/find "$PROJECTS" -maxdepth 2 -name "$sid.jsonl" 2>/dev/null | head -1);;
    *) f="";;
  esac
  if [ -z "$f" ]; then echo "NO RECORD $seat: no $h record for $sid"; missing=1; continue; fi
  seats+=("$seat") harn+=("$h") files+=("$f")
done < <(/usr/bin/grep -E '^RESUMED [^ ]+: (codex|claude) [0-9a-f-]+ ' "$log")
[ ${#seats[@]} -gt 0 ] || { [ $missing -eq 0 ] || exit 3; echo "no seat was restarted in $log, so there is no answer to wait for"; exit 0; }

verdict() { # verdict HARNESS FILE: prints ANSWERED, ERROR <text>, or WAITING, from records after $since
  tail -c "$TAIL" "$2" | /usr/bin/awk -v s="$since" -v h="$1" '
    { if (!match($0, /"timestamp":"[0-9T:.-]+/)) next; t = substr($0, RSTART + 13, RLENGTH - 13); if (t <= s) next }
    h == "codex" && /"type":"response_item"/ && /"role":"assistant"/ { a = 1 }
    h == "codex" && /"type":"task_complete"/ && /"error":\{/ { e = $0 }
    h == "claude" && /"type":"assistant"/ { if (/"isApiErrorMessage":true/) e = $0; else a = 1 }
    END {
      if (a) { print "ANSWERED"; exit }
      if (e != "") { m = e; if (match(e, /"message":"[^"]*/)) m = substr(e, RSTART + 11, RLENGTH - 11); if (match(e, /The [^\\"]*/)) m = substr(e, RSTART, RLENGTH); print "ERROR " substr(m, 1, 200); exit }
      print "WAITING" }'
}

deadline=$(( $(/bin/date +%s) + wait ))
while :; do
  answered=0 errors=0 waiting=0 out=""
  for i in "${!seats[@]}"; do
    v=$(verdict "${harn[$i]}" "${files[$i]}")
    case "$v" in ANSWERED) answered=$((answered+1));; ERROR*) errors=$((errors+1));; *) waiting=$((waiting+1));; esac
    case "$v" in ERROR*) out+="ERROR ${seats[$i]} (${harn[$i]}): ${v#ERROR }"$'\n';; *) out+="$v ${seats[$i]} (${harn[$i]})"$'\n';; esac
  done
  [ $waiting -gt 0 ] && [ "$(/bin/date +%s)" -lt "$deadline" ] || break
  sleep "$PAUSE"
done
printf '%s' "$out"
echo "answered: $answered of ${#seats[@]}, error $errors, waiting $waiting, since $since UTC"
[ $errors -eq 0 ] || exit 1
[ $missing -eq 0 ] || exit 3
[ $waiting -eq 0 ] || exit 2
exit 0
MA_EOF
  [ "$(sha "$S/relogin-note.txt")" = "$NOTE_SHA" ] && [ "$(sha "$S/model-answered.sh")" = "$MA_SHA" ] || { echo "HASH MISMATCH, nothing was run: the note or model-answered.sh in $S"; return 2; }

  # Stop: the session first (SIGHUP to codex), then the process if it stays; nothing starts while anything holds the rollout.
  "$T" -L "$SOCK" kill-session -t "=$SESS" || { echo "FAILED, nothing was changed: tmux could not end $SESS"; return 1; }
  for _ in $(/usr/bin/jot 20); do alive "$P" || break; /bin/sleep 1; done
  if alive "$P"; then /bin/kill "$P" 2>/dev/null; for _ in $(/usr/bin/jot 10); do alive "$P" || break; /bin/sleep 1; done; fi
  alive "$P" && { echo "STILL RUNNING: pid $P did not stop; nothing was started. Its session is gone. Tell zeo-rescue."; return 1; }
  for _ in $(/usr/bin/jot 10); do h=$(holders); [ -z "$h" ] && break; /bin/sleep 1; done
  [ -z "$h" ] || { echo "STILL HELD: pid $h holds the rollout; nothing was started. Tell zeo-rescue."; return 1; }
  echo "STOPPED $SEAT: pid $P is gone and nothing holds its rollout"

  log=$S/relogin-$(/bin/date -u +%Y%m%d-%H%M%S).log
  { R --apply --seat "$SEAT" && R --check --seat "$SEAT" && /bin/bash "$S/model-answered.sh" "$log" "$WAIT"; } 2>&1 | /usr/bin/tee "$log"
  rc=${PIPESTATUS[0]}
  [ "$rc" = 0 ] || echo "NOT FINISHED (exit $rc): if $SEAT did not resume, it is down with its history intact. Bring this output to zeo-rescue; run nothing else."
  return "$rc"
}
main
exit $?
} </dev/null
