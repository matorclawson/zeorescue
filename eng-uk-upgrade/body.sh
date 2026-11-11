#!/bin/bash
# ENG-POMAR-UPGRADE, 11 Nov 2026, zeo-rescue: restart pomar (session pomar-maintainer) on ENG-UK in place, from Codex 0.163.0 to the
# installed 0.167.1, which its model needs (13:31Z: model_not_found). Run from the Mac mini: ssh ENG-UK /bin/bash -s < this file.
# ENG-UK has no seat loader and its staged rescue.sh (af7405e2, approved 7 Nov) has --no-loader but no --upgrade, so this line:
#   checks the place, the six staged files, the installed Codex and that the seat is live, on the old binary, idle and the only holder of its rollout;
#   stops it (its session, then its process if needed) and waits until no process holds its rollout;
#   resumes it with the staged rescue.sh exactly as 7 Nov line 2, with this note in place of the cleanup note, then --check;
#   waits up to 10 minutes for its model's answer (model-answered.sh, bootstrap's ec8a6f65, written here from this file).
# It changes nothing else: no config, no mail, no other seat, no file outside its own state folder.
{
D=/Users/rodbot/.local/share/zeo/runtime-pomar-resume-20261107
S=/Users/rodbot/.local/state/zeo-rescue/eng-uk-upgrade-20261111
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
NOTE_SHA=eef4c6664cd660859c42fd01dcf21f450549c6bdbf7ed198d2f07650a2eb81f5
MA_SHA=ec8a6f65e245aac98a2c34ef84ecd2f8926b041b150bbdaac83f32fdc5d925d1
WAIT=600

sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/cut -d ' ' -f 1; }
ck() { h=$(sha "$D/$2"); [ "$h" = "$1" ] || { echo "HASH MISMATCH, nothing was run: $D/$2 is ${h:-missing}"; bad=1; }; }
holders() { "$LSOF" -t "$ROLL" 2>/dev/null | /usr/bin/sort -u | /usr/bin/paste -sd ' ' -; }
alive() { /bin/kill -0 "$1" 2>/dev/null; }
R() { /usr/bin/env -u ZEO_RESCUE_DEFAULT_MARKER ZEO_RESCUE_JQ=/usr/bin/jq ZEO_RESCUE_CLAUDE=/opt/homebrew/bin/claude /bin/bash "$D/rescue.sh" --host ENG-UK --chart "$D/ORG-CHART.json" --note-file "$S/upgrade-note.txt" --no-loader "$@"; }

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
  [ "$run" != "$NEW_BIN" ] || { echo "ALREADY DONE: $SEAT (pid $P) runs $NEW_BIN"; return 0; }
  echo "UPGRADE $SEAT: pid $P runs $run; installed is $NEW_BIN"

  # Idle: its last turn ended, nothing written for a minute, and it alone holds its rollout.
  last=$(/usr/bin/tail -c 200000 "$ROLL" 2>/dev/null | /usr/bin/tail -1)
  case "$last" in *'"type":"task_complete"'*|*'"type":"turn_aborted"'*) ;; *) echo "BUSY, nothing was run: its last record is not the end of a turn. Run the line again when it is idle."; return 2;; esac
  age=$(( $(/bin/date +%s) - $(/usr/bin/stat -f %m "$ROLL") ))
  [ "$age" -ge 60 ] || { echo "BUSY, nothing was run: its rollout was written ${age}s ago. Run the line again in a minute."; return 2; }
  h=$(holders); [ "$h" = "$P" ] || { echo "REFUSED, nothing was run: the rollout is held by '${h:-nobody}', not pid $P alone. Tell zeo-rescue."; return 2; }
  echo "IDLE $SEAT: last turn ended, rollout untouched for ${age}s, held by pid $P only"

  # Its own files for this run, written from this line and checked.
  /bin/mkdir -p -m 700 "$S" || { echo "FAILED, nothing was run: cannot make $S"; return 1; }
  /bin/cat > "$S/upgrade-note.txt" <<'NOTE_EOF'
@@NOTE@@
NOTE_EOF
  /bin/cat > "$S/model-answered.sh" <<'MA_EOF'
@@MA@@
MA_EOF
  [ "$(sha "$S/upgrade-note.txt")" = "$NOTE_SHA" ] && [ "$(sha "$S/model-answered.sh")" = "$MA_SHA" ] || { echo "HASH MISMATCH, nothing was run: the note or model-answered.sh in $S"; return 2; }

  # Stop: the session first (SIGHUP to codex), then the process if it stays; nothing starts while anything holds the rollout.
  "$T" -L "$SOCK" kill-session -t "=$SESS" || { echo "FAILED, nothing was changed: tmux could not end $SESS"; return 1; }
  for _ in $(/usr/bin/jot 20); do alive "$P" || break; /bin/sleep 1; done
  if alive "$P"; then /bin/kill "$P" 2>/dev/null; for _ in $(/usr/bin/jot 10); do alive "$P" || break; /bin/sleep 1; done; fi
  alive "$P" && { echo "STILL RUNNING: pid $P did not stop; nothing was started. Its session is gone. Tell zeo-rescue."; return 1; }
  for _ in $(/usr/bin/jot 10); do h=$(holders); [ -z "$h" ] && break; /bin/sleep 1; done
  [ -z "$h" ] || { echo "STILL HELD: pid $h holds the rollout; nothing was started. Tell zeo-rescue."; return 1; }
  echo "STOPPED $SEAT: pid $P is gone and nothing holds its rollout"

  log=$S/upgrade-$(/bin/date -u +%Y%m%d-%H%M%S).log
  { R --apply --seat "$SEAT" && R --check --seat "$SEAT" && /bin/bash "$S/model-answered.sh" "$log" "$WAIT"; } 2>&1 | /usr/bin/tee "$log"
  rc=${PIPESTATUS[0]}
  [ "$rc" = 0 ] || echo "NOT FINISHED (exit $rc): if $SEAT did not resume, it is down with its history intact. Bring this output to zeo-rescue; run nothing else."
  return "$rc"
}
main
exit $?
} </dev/null
