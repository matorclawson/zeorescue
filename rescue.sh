#!/bin/bash
# zeo-rescue: bring the org's seats back after a crash, from system tools alone.
#
# It runs only when asked. It needs bash, jq, tmux, sqlite3, ps, lsof and the harness CLIs, and it does NOT need Messenger, the
# wake daemons or the collector: those are what may be down. Without --apply it starts nothing and prints the plan.
#
#   rescue.sh [--apply] [--reseat] [--check] [--harness claude|codex|all] [--seat ID]... [--session ID] [--note-file F] [--before YYYYMMDDHHMM] [--host H] [--socket S] [--stagger SECONDS] [--chart FILE]
#
# For each seat of the chart on this host it decides one of:
#   LIVE        its tmux session exists                         left alone
#   RUNNING     a process of its harness runs in its directory  left alone: two processes on one transcript corrupt each other
#   RESUME      dead, with a session and a recorded mode        resumed with --apply
#   UNRESOLVED  dead, and something needed is missing           left alone and named: this is the agent stage's work
#
# --reseat also restarts LIVE seats that rescue did not start the right way: RESEAT, or OK when the pane already carries @zeo_rescue.
# --check starts nothing and judges every seat: OK or WRONG, with the reason.
# It lists what a restart would cut first, as WORK lines, in the plan and again just before --apply stops anything.
# --session and session-pins can assert the expected session; they never override the saved mapping.
# --seed FILE names seats that have no usable record: lines "SEAT MARKER SESSION". It is a reviewed file for one named incident, never a default:
# the exact native history must agree, a live pane must hold that session, and a captured record that disagrees wins by refusing.
# records.sh captures exact native session/identity/cwd/policy/marker during normal operation,
# without an agent or model call. Run its generated launchd job or call capture from the seat lifecycle.
# Recovery uses the saved local records and exact native histories; it never chooses the newest thread
# or invents a git marker. --before is refused because timestamp-based snapshot selection is removed.
# Ordinary recovery never stops a live seat or the daemon. --reseat is the separate operator repair path.
# Missing records are named UNRESOLVED; other independently resolvable dead seats may still recover.
#
# Either harness starts only after process inspection and a free native-history file check. Its own client going away proves little: the shared daemon keeps every
# thread open, so a seat started beside it would be a second writer. A seat refused this way stays down, and the run says who holds it.
# Any seat that fails its proof is stopped again and loses @zeo_rescue, so the next run plans it again; RECOVERY says what is down.
#
# Exit: 0 every seat fine or resumable; 1 a failure, or a --check found WRONG; 2 usage; 3 at least one seat UNRESOLVED.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd -P)
CHART=${ZEO_RESCUE_CHART:-/Volumes/ZeoWork/zeo-evidence/zeo-rt-seats/org-chart/ORG-CHART.json}
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
CODEX_DB=${ZEO_RESCUE_CODEX_DB:-$HOME/.codex/state_5.sqlite}
SNAPSHOTS=${ZEO_RESCUE_SNAPSHOTS:-$HOME/.codex/shell_snapshots}
TMUX_BIN=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
JQ=${ZEO_RESCUE_JQ:-/opt/homebrew/bin/jq}
SQLITE=${ZEO_RESCUE_SQLITE:-/usr/bin/sqlite3}
PS_BIN=${ZEO_RESCUE_PS:-/bin/ps}
LSOF=${ZEO_RESCUE_LSOF:-/usr/sbin/lsof}
KILL_BIN=${ZEO_RESCUE_KILL:-/bin/kill}
CLAUDE=${ZEO_RESCUE_CLAUDE:-$HOME/.local/bin/claude}
CODEX=${ZEO_RESCUE_CODEX:-$HOME/.local/bin/codex}
PROOF_TRIES=${ZEO_RESCUE_PROOF_TRIES:-24}
PROOF_PAUSE=${ZEO_RESCUE_PROOF_PAUSE:-5}
STOP_TRIES=${ZEO_RESCUE_STOP_TRIES:-30}
# Thread release and process termination have different deadlines. A timeout refuses, never forces.
ROLLOUT_TRIES=${ZEO_RESCUE_ROLLOUT_TRIES:-90}
CLAUDE_SESSIONS=${ZEO_RESCUE_CLAUDE_SESSIONS:-$HOME/.claude/sessions}
WORK_WINDOW=${ZEO_RESCUE_WORK_WINDOW:-120}
SOCKET=zeo2 HOST_NAME=matormini HARNESS=all STAGGER=20 APPLY=0 ONLY=" " RESEAT=0 CHECK=0 SESSION="" SESSION_ARG="" NOTE_FILE="" BEFORE="" SEED=""
PINS=${ZEO_RESCUE_PINS:-$HERE/session-pins}
PROMPT="You were restarted: this host's login session was torn down and your session was lost. Your history is resumed. Check your mail (zmsg inbox), answer what is owed (zmsg pending), then continue the work you were doing. Do not repeat any outward action your history shows you already completed."

usage() { sed -n '/^#   rescue.sh/p' "$0" >&2; exit 2; }
pause() { perl -e "select(undef,undef,undef,$1)"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --reseat) RESEAT=1; shift;;
    --check) CHECK=1; shift;;
    --harness) [ $# -ge 2 ] || usage; HARNESS=$2; shift 2;;
    --seat) [ $# -ge 2 ] || usage; ONLY="$ONLY$2 "; shift 2;;
    --session) [ $# -ge 2 ] || usage; SESSION_ARG=$2; shift 2;;
    --note-file) [ $# -ge 2 ] || usage; NOTE_FILE=$2; shift 2;;
    --before) [ $# -ge 2 ] || usage; BEFORE=$2; shift 2;;
    --seed) [ $# -ge 2 ] || usage; SEED=$2; shift 2;;
    --host) [ $# -ge 2 ] || usage; HOST_NAME=$2; shift 2;;
    --socket) [ $# -ge 2 ] || usage; SOCKET=$2; shift 2;;
    --stagger) [ $# -ge 2 ] || usage; STAGGER=$2; shift 2;;
    --chart) [ $# -ge 2 ] || usage; CHART=$2; shift 2;;
    *) usage;;
  esac
done
case "$HARNESS" in claude|codex|all) ;; *) usage;; esac
[[ "$STAGGER" =~ ^[0-9]+$ ]] || usage
for tries in "$STOP_TRIES" "$ROLLOUT_TRIES"; do [[ "$tries" =~ ^[1-9][0-9]*$ ]] || usage; done
[ -z "$BEFORE" ] || { echo "rescue: --before snapshot guessing was replaced by exact saved recovery records; no action" >&2; exit 2; }
[ $CHECK -eq 0 ] || { [ $APPLY -eq 0 ] && [ $RESEAT -eq 0 ]; } || usage
ID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
if [ -n "$SESSION_ARG" ]; then
  [[ "$SESSION_ARG" =~ $ID_RE ]] || usage
  n=0; for w in $ONLY; do n=$((n+1)); done
  [ "$n" -eq 1 ] || { echo "rescue: --session needs exactly one --seat" >&2; exit 2; }
fi
[ -z "$NOTE_FILE" ] || [ -r "$NOTE_FILE" ] || { echo "rescue: cannot read $NOTE_FILE" >&2; exit 2; }
[ -z "$SEED" ] || [ -r "$SEED" ] || { echo "rescue: cannot read $SEED" >&2; exit 2; }
[[ "$SOCKET" =~ ^[a-z0-9][a-z0-9_-]{0,39}$ ]] || { echo "rescue: bad socket name $SOCKET" >&2; exit 2; }
for t in "$JQ" "$TMUX_BIN" "$PS_BIN"; do [ -x "$t" ] || { echo "rescue: missing tool $t" >&2; exit 1; }; done

# The chart: the live one when it parses, and it becomes the last good copy; otherwise the last good copy, said out loud.
seats_of() { "$JQ" -e -r --arg h "$HOST_NAME" '.seats | map(select(.desired_host == $h and (.desired_agent == "claude" or .desired_agent == "codex"))) | if length == 0 then error("no seats") else .[] end | [.seat_id, .mailbox, .desired_agent, .desired_tmux.session, .desired_folder] | map(. // "-") | join("\u001f")' "$1" 2>/dev/null; }
mkdir -p "$STATE/prompts" && chmod 700 "$STATE" "$STATE/prompts" || { echo "rescue: cannot use $STATE" >&2; exit 1; }
GOOD=$STATE/ORG-CHART.last-good.json
if rows=$(seats_of "$CHART"); then
  tmp=$(mktemp "$STATE/.chart.XXXXXX") && cp "$CHART" "$tmp" && mv -f "$tmp" "$GOOD"
elif rows=$(seats_of "$GOOD"); then
  echo "rescue: WARNING: $CHART is unreadable; using the last good copy from $(date -r "$GOOD" '+%F %T')" >&2
else
  echo "rescue: no readable org chart at $CHART or $GOOD" >&2; exit 1
fi

PSOUT=$("$PS_BIN" -axo pid=,command=) || { echo "rescue: ps failed" >&2; exit 1; }
ps_line() { printf '%s\n' "$PSOUT" | awk -v p="$1" '$1==p'; }
running_in() { # running_in HARNESS CWD: 0 yes, 1 no, 2 could not tell
  local pids
  pids=$(printf '%s\n' "$PSOUT" | awk -v h="$1" '{n=split($2,p,"/"); if (p[n]==h || $2 ~ ("/" h "/versions/")) print $1}' | paste -sd, -)
  [ -n "$pids" ] || return 1
  local out rc; out=$("$LSOF" -a -d cwd -Fn -p "$pids" 2>/dev/null); rc=$?
  [ $rc -le 1 ] || return 2
  printf '%s\n' "$out" | grep -qxF "n$2"
}
holds() { # holds SID: does a harness process hold this session? Only harness binaries count: a tmux server keeps the command line of its first client as its title, for life.
  local out
  out=$("$PS_BIN" -axo pid=,command=) || return 2
  printf '%s\n' "$out" | awk -v id="$1" '($2 ~ /(^|\/)(claude|codex)$/ || $2 ~ /\/(claude|codex)\/versions\//) && index($0, id) {f=1} END {exit !f}' && return 0
  # Claude keeps no file open on a transcript, and a session opened from inside the UI is not in argv. Its pid-to-session file still names the holder.
  local f pid
  while IFS= read -r f; do
    pid=${f##*/}; pid=${pid%.json}
    printf '%s\n' "$out" | awk -v p="$pid" '$1==p && ($2 ~ /(^|\/)claude$/ || $2 ~ /\/claude\/versions\//) {f=1} END {exit !f}' && return 0
  done < <(grep -l -E "\"sessionId\": *\"$1\"" "$CLAUDE_SESSIONS"/*.json 2>/dev/null)
  return 1
}

SID="" MODE_ARGS="" WHY="" SANDBOX="" ROLL="" MARK="" MARK_WHY=""
load_record() { # exact saved seat mapping; policy is read from that native history
  local record seeded="" why=recorded
  [ -z "$SEED" ] || seeded=$(awk -v s="$seat" '$1==s {print $2, $3}' "$SEED")
  if ! record=$(ZEO_RESCUE_HOST="$HOST_NAME" ZEO_RESCUE_SOCKET="$SOCKET" "$HERE/records.sh" get "$seat" "$harness" "$sess" "$cwd"); then
    # A seat started before any collector, or started wrong, can have no record. Only an explicit reviewed seed may name it, and its native history must agree.
    [ -n "$seeded" ] || { WHY="no usable programmatically captured recovery record"; return 1; }
    record=$(ZEO_RESCUE_HOST="$HOST_NAME" ZEO_RESCUE_SOCKET="$SOCKET" "$HERE/records.sh" seed "$seat" "$harness" "$sess" "$cwd" "${seeded#* }" "${seeded%% *}") || {
      WHY="seed does not match the seat's native history"; return 1;
    }
    why="seed file"
  fi
  SID=$("$JQ" -r .session_id <<< "$record")
  if [ -n "$seeded" ] && [ "${seeded#* }" != "$SID" ]; then WHY="seed session conflicts with captured record"; return 1; fi
  if [ -n "$SESSION" ] && [ "$SESSION" != "$SID" ]; then WHY="requested/pinned session conflicts with captured record"; return 1; fi
  MODE_ARGS=$("$JQ" -r '.mode_args | join(" ")' <<< "$record")
  SANDBOX=$("$JQ" -r '.policy.sandbox_policy.type // ""' <<< "$record")
  ROLL=$("$JQ" -r .history_path <<< "$record")
  MARK=$("$JQ" -r .marker <<< "$record")
  [ "$MARK" != inactive ] || MARK=""
  MARK_WHY=$([ "$why" = recorded ] && echo "captured recovery record" || echo "$why")
}
marker_label() { if [ -n "$MARK" ]; then echo "marker $MARK, $MARK_WHY"; else echo "no marker, $MARK_WHY"; fi; }

panes_of() { "$TMUX_BIN" -L "$SOCKET" list-panes -s -t "=$1" -F '#{pane_id}|#{pane_pid}|#{@zeo_rescue}|#{pane_current_command}' 2>/dev/null; }
PANE="" PANE_PID="" PANE_STATE=""
find_pane() { # find_pane SESSION SID: sets PANE, PANE_PID and PANE_STATE (done, held, sleeping or none). A session can hold other windows.
  local id pid opt cmd
  PANE="" PANE_PID="" PANE_STATE=none
  while IFS='|' read -r id pid opt cmd; do
    if [ "$opt" = 1 ]; then PANE=$id PANE_PID=$pid PANE_STATE=done; return 0; fi
    case "$(ps_line "$pid")" in *"$2"*) PANE=$id PANE_PID=$pid PANE_STATE=held; return 0;; esac
    if [ "$cmd" = sleep ]; then PANE=$id PANE_PID=$pid PANE_STATE=sleeping; return 0; fi
  done < <(panes_of "$1")
}

check_seat() { # check_seat SEAT SESSION HARNESS: prints OK or WRONG with the reason
  local id pid opt cmd line env snap why="" sid
  IFS='|' read -r id pid opt cmd < <(panes_of "$2")
  [ "$opt" = 1 ] || why="not started by rescue"
  # Nobody may type into a seat's terminal, so a seat stopped at a harness question waits for the operator. It is not resumed.
  if "$TMUX_BIN" -L "$SOCKET" capture-pane -p -t "$id" 2>/dev/null | grep -q -E 'Yes, I trust this folder|Do you trust the files'; then
    why="${why:+$why; }waiting at the trust prompt: the operator must answer it"
  fi
  if [ "$3" = codex ]; then
    line=$(ps_line "$pid")
    case "$line" in *--no-daemon*) ;; *) why="${why:+$why; }no --no-daemon";; esac
    sid=$(printf '%s\n' "$line" | grep -o -E '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
    snap=$(ls -t "$SNAPSHOTS/$sid".* 2>/dev/null | head -1)
    if [ -z "$snap" ]; then why="${why:+$why; }no snapshot"
    else grep -q "ZMAIL_INSTANCE=.\{0,1\}$1.\{0,1\}\$" "$snap" || why="${why:+$why; }snapshot has another identity"; fi
  else
    env=$("$PS_BIN" -Ewwp "$pid" -o command= 2>/dev/null)
    case "$env" in *"ZMAIL_INSTANCE=$1 "*|*"ZMAIL_INSTANCE=$1") ;; *) why="${why:+$why; }environment has another identity";; esac
  fi
  if [ -z "$why" ]; then echo "OK $1 ($3)"; return 0; fi
  echo "WRONG $1 ($3): $why"; return 1
}

prove_codex() { # every Codex seat must show the loader worked before proceeding
  local seat=$1 sid=$2 mark=$3 pf=$4 i snap=""
  for ((i = 0; i < PROOF_TRIES; i++)); do
    snap=$(find "$SNAPSHOTS" -name "$sid.*" -newer "$pf" 2>/dev/null | head -1)
    # a snapshot exists before it is written, so judge it only once it holds an identity
    if [ -n "$snap" ] && grep -q 'ZMAIL_INSTANCE=' "$snap"; then break; fi
    pause "$PROOF_PAUSE"
  done
  [ -n "$snap" ] || { echo "STOPPED: no shell snapshot for $seat; no further seat will start"; return 1; }
  grep -q "ZMAIL_INSTANCE=.\{0,1\}$seat.\{0,1\}\$" "$snap" || { echo "STOPPED: $seat did not get its own identity; no further seat will start"; return 1; }
  if [ -n "$mark" ]; then
    grep -q "ZEO_TMUX_SEAT=.\{0,1\}$mark.\{0,1\}\$" "$snap" || { echo "STOPPED: $seat lacks marker $mark; no further seat will start"; return 1; }
    if grep -q 'GIT_ALLOW_PROTOCOL=.\{0,1\}file.\{0,1\}$' "$snap"; then echo "STOPPED: $seat still has network git off; no further seat will start"; return 1; fi
  fi
  if [ -z "$mark" ]; then
    grep -q "ZEO_TMUX_SEAT=.\{0,1\}inactive.\{0,1\}\$" "$snap" &&
      grep -q 'GIT_ALLOW_PROTOCOL=.\{0,1\}file.\{0,1\}$' "$snap" || { echo "STOPPED: $seat did not retain inactive Git policy"; return 1; }
  fi
  echo "SEAT OK $seat: own identity${mark:+, marker $mark, git on}"
}
prove_claude() { # every Claude seat is checked from the running process environment
  local seat=$1 mark=$2 sess=$3 i id pid opt cmd env=""
  for ((i = 0; i < PROOF_TRIES; i++)); do
    IFS='|' read -r id pid opt cmd < <(panes_of "$sess")
    env=$("$PS_BIN" -Ewwp "$pid" -o command= 2>/dev/null)
    case "$env" in *"ZMAIL_INSTANCE=$seat"*) break;; esac
    pause "$PROOF_PAUSE"
  done
  case "$env" in *"ZMAIL_INSTANCE=$seat "*|*"ZMAIL_INSTANCE=$seat") ;; *) echo "STOPPED: $seat did not get its own identity; no further seat will start"; return 1;; esac
  if [ -n "$mark" ]; then
    case "$env" in *"ZEO_TMUX_SEAT=$mark"*) ;; *) echo "STOPPED: $seat lacks marker $mark; no further seat will start"; return 1;; esac
    case "$env" in *"GIT_ALLOW_PROTOCOL=file "*) echo "STOPPED: $seat still has network git off; no further seat will start"; return 1;; esac
  fi
  if [ -z "$mark" ]; then
    case "$env" in *"ZEO_TMUX_SEAT=inactive "*|*"ZEO_TMUX_SEAT=inactive") ;; *) echo "STOPPED: $seat lost inactive marker"; return 1;; esac
    case "$env" in *"GIT_ALLOW_PROTOCOL=file "*|*"GIT_ALLOW_PROTOCOL=file") ;; *) echo "STOPPED: $seat lost inactive Git policy"; return 1;; esac
  fi
  echo "SEAT OK $seat: own identity${mark:+, marker $mark, git on}"
}

HOLDER=""
rollout_free() { # rollout_free FILE: sets HOLDER and fails while any process has the rollout open. Run it after the daemon stop.
  local i rc err out
  HOLDER="unknown"
  [ -x "$LSOF" ] && [ -f "$1" ] && [ -r "$1" ] || return 1
  err=$(mktemp "$STATE/.lsof.XXXXXX") || return 1
  for ((i = 0; i < ROLLOUT_TRIES; i++)); do
    # lsof uses status 1 for no matches AND some errors. Diagnostics are uncertainty.
    # Even a clean empty result is an observation, not a lock or a no-future-writer proof.
    out=$("$LSOF" -t -- "$1" 2>"$err"); rc=$?
    if [ -s "$err" ] || [ "$rc" -gt 1 ] || { [ "$rc" -eq 0 ] && [ -z "$out" ]; }; then
      HOLDER="unknown (lsof inspection failed)"; rm -f "$err"; return 1
    fi
    if [ "$rc" -eq 1 ] && [ -z "$out" ]; then rm -f "$err"; HOLDER=""; return 0; fi
    if [ "$rc" -ne 0 ] || printf '%s\n' "$out" | grep -qvE '^[0-9]+$'; then
      HOLDER="unknown (invalid lsof result)"; rm -f "$err"; return 1
    fi
    HOLDER=$(printf '%s\n' "$out" | paste -sd' ' -)
    pause 1
  done
  rm -f "$err"
  return 1
}

children() { # children TREE PID: a process's children as "pid etime command", without what every seat runs: mail hooks, caffeinate and the daemon's own processes
  printf '%s\n' "$1" | awk -v p="$2" '$2==p { c=$0; sub(/^ *[0-9]+ +[0-9]+ +[^ ]+ +/, "", c); i=index(c, " && eval "); if (i) c=substr(c, i+9)
    if (c !~ /\/\.local\/share\/zeo\/messenger\/hooks\// && c !~ /^caffeinate / && c !~ /\/app-server-daemon\/releases\//) print $1, $3, substr(c, 1, 110) }'
}
work_list() { # what a restart would cut: it reads only, and a quiet result is what could be seen, not a promise that nothing is in progress
  local tree i seats=0 busy=0 hit kids daemon line pid now age
  now=$(date +%s)
  tree=$("$PS_BIN" -axo pid=,ppid=,etime=,command=) || { echo "WORK: ps failed, so running work is unknown"; return 0; }
  for ((i = 0; i < ${#P_SEAT[@]}; i++)); do
    [ -n "${P_PANE[$i]}" ] || continue
    seats=$((seats+1)) hit=0
    if "$TMUX_BIN" -L "$SOCKET" capture-pane -p -t "${P_PANE[$i]}" 2>/dev/null | grep -q 'esc to interrupt'; then echo "WORK ${P_SEAT[$i]}: a turn is in progress on its screen"; hit=1; fi
    # History being written is the one sign that holds for both harnesses. The screen text above has only ever been seen on Claude.
    if [ -n "${P_ROLL[$i]}" ] && age=$(date -r "${P_ROLL[$i]}" +%s 2>/dev/null); then
      age=$((now-age))
      if [ "$age" -lt "$WORK_WINDOW" ]; then echo "WORK ${P_SEAT[$i]}: its history was written ${age}s ago"; hit=1; fi
    fi
    kids=$(children "$tree" "${P_PID[$i]}")
    if [ -n "$kids" ]; then hit=1; while IFS= read -r line; do echo "WORK ${P_SEAT[$i]}: $line"; done <<< "$kids"; fi
    busy=$((busy+hit))
  done
  # Under the shared daemon a Codex seat's tools are children of the app-server, not of the seat's pane; the working directory says whose.
  daemon=$(printf '%s\n' "$tree" | awk '$4 ~ /\/app-server-daemon\/releases\// && /app-server --listen/ {print $1}' | head -1)
  if [ -n "$daemon" ]; then
    kids=$(children "$tree" "$daemon")
    if [ -n "$kids" ]; then
      while IFS= read -r line; do pid=${line%% *}; echo "WORK daemon, in $("$LSOF" -a -d cwd -Fn -p "$pid" 2>/dev/null | sed -n 's/^n//p' | head -1): $line"; done <<< "$kids"
    fi
  fi
  echo "work: $busy of $seats seats show running work"
}

unseat() { # unseat INDEX: a seat that failed must not stay up wrong, and must not keep the mark that makes the next run skip it
  local i=$1 pane=${P_PANE[$1]}
  if [ -n "$pane" ]; then
    "$TMUX_BIN" -L "$SOCKET" respawn-pane -k -t "$pane" -c "${P_CWD[$i]}" -- sleep 3600 2>/dev/null || echo "WARNING: could not stop ${P_SEAT[$i]}: stop it before anything else runs"
    "$TMUX_BIN" -L "$SOCKET" set-option -pu -t "$pane" @zeo_rescue 2>/dev/null
  else # it was dead when this run began, so the session is this run's own, and a later run resumes the seat only once it is gone
    "$TMUX_BIN" -L "$SOCKET" kill-session -t "=${P_SESS[$i]}" 2>/dev/null
  fi
}

recovery() { # recovery FROM: after a run that stopped, say what is down and what brings it back
  local i left=0
  for ((i = $1; i < ${#P_SEAT[@]}; i++)); do [ -z "${P_SEAT[$i]}" ] || left=$((left+1)); done
  echo "RECOVERY: $left planned seats from this point need inspection, including the failed seat. Stop/cleanup success, transcript integrity and external effects are NOT proved. Do not restart by hand or blindly rerun. Reconcile live processes, threads and panes before an operator retry."
}

stop_seat() { # stop_seat PANE CWD SID: replace the harness with a sleep, and wait until nothing holds the session
  local i rc
  "$TMUX_BIN" -L "$SOCKET" respawn-pane -k -t "$1" -c "$2" -- sleep 3600 || return 1
  for ((i = 0; i < STOP_TRIES; i++)); do
    holds "$3"; rc=$?
    case "$rc" in 1) return 0;; 0) pause 1;; *) return 1;; esac
  done
  return 1
}

stop_daemon() { # the shared app-server keeps every attached thread open, so it goes only when no seat is attached to it
  local out attached pids p
  out=$("$PS_BIN" -axo pid=,command=) || return 1
  attached=$(printf '%s\n' "$out" | grep -E '/codex resume ' | grep -vc -- '--no-daemon')
  pids=$(printf '%s\n' "$out" | awk '$2 ~ /\/app-server-daemon\/releases\// {print $1}' | paste -sd' ' -)
  [ -n "$pids" ] || return 0
  if [ "$attached" -gt 0 ]; then echo "DAEMON LEFT: $attached Codex seats are still attached to pids $pids"; return 0; fi
  echo "DAEMON STOP: exact pids $pids"
  # No unattended SIGKILL: a timeout requires inspection, not stronger signals.
  # shellcheck disable=SC2086
  "$KILL_BIN" $pids 2>/dev/null || { echo "STOPPED: daemon SIGTERM failed; inspect exact processes"; return 1; }
  # With no SIGKILL behind it, a fixed short wait would turn a slow shutdown of dozens of threads into a stopped run with the org down.
  local i alive
  for ((i = 0; i < ${ZEO_RESCUE_DAEMON_WAIT:-30}; i++)); do
    pause 1
    out=$("$PS_BIN" -axo pid=,command=) || return 1
    alive=0
    for p in $pids; do printf '%s\n' "$out" | awk -v p="$p" '$1==p {f=1} END {exit !f}' && alive=1; done
    [ "$alive" -eq 1 ] || break
  done
  for p in $pids; do
    if printf '%s\n' "$out" | awk -v p="$p" '$1==p {f=1} END {exit !f}'; then
      echo "STOPPED: daemon pid $p still exists after SIGTERM; no launch and no automatic SIGKILL"
      return 1
    fi
  done
  # Detect a replacement daemon too. Supervisor fencing still must be done on the host.
  if printf '%s\n' "$out" | awk '$2 ~ /\/app-server-daemon\/releases\// {f=1} END {exit !f}'; then
    echo "STOPPED: daemon restarted during shutdown"; return 1
  fi
  return 0
}

launch() { # launch INDEX: the marker goes on before any shell starts
  local i=$1 seat=${P_SEAT[$1]} sess=${P_SESS[$1]} cwd=${P_CWD[$1]} harness=${P_HARNESS[$1]} sid=${P_SID[$1]} mark=${P_MARK[$1]} pane=${P_PANE[$1]} pf
  pf=$STATE/prompts/$seat.txt
  { printf '%s' "$PROMPT"; if [ -n "$NOTE_FILE" ]; then printf ' '; cat "$NOTE_FILE"; fi; } > "$pf" || return 1
  if [ -z "$pane" ]; then
    env -u TMUX "$TMUX_BIN" -L "$SOCKET" new-session -d -s "$sess" -c "$cwd" -- sleep 3600 || return 1
    pane=$(panes_of "$sess" | head -1 | cut -d'|' -f1)
    [ -n "$pane" ] || return 1
  fi
  if [ -n "$mark" ]; then "$TMUX_BIN" -L "$SOCKET" set-option -p -t "$pane" @zeo_seat "$mark" || return 1
  else "$TMUX_BIN" -L "$SOCKET" set-option -p -t "$pane" @zeo_seat inactive || return 1; fi
  "$TMUX_BIN" -L "$SOCKET" set-option -p -t "$pane" @zeo_rescue starting || return 1
  LAUNCHED_PANE=$pane
  # shellcheck disable=SC2086  # the mode holds only whitelisted words generated by records.sh history
  if [ "$harness" = claude ]; then
    "$TMUX_BIN" -L "$SOCKET" respawn-pane -k -t "$pane" -c "$cwd" -- "$HERE/seat-exec.sh" "$seat" claude "$pf" "$CLAUDE" --resume "$sid" ${P_MODE[$i]}
  else
    "$TMUX_BIN" -L "$SOCKET" respawn-pane -k -t "$pane" -c "$cwd" -- "$HERE/seat-exec.sh" "$seat" codex "$pf" "$CODEX" resume ${P_MODE[$i]} -C "$cwd" --no-daemon "$sid"
  fi
}

P_SEAT=() P_SESS=() P_CWD=() P_HARNESS=() P_SID=() P_MODE=() P_MARK=() P_PANE=() P_WHY=() P_ROLL=() P_PID=()
live=0 ok=0 wrong=0 running=0 resume=0 resumed=0 reseat=0 unresolved=0 failed=0
planned() { # planned SEAT SESSION CWD HARNESS PANE: record what the plan decided
  local n=${#P_SEAT[@]}
  P_SEAT[$n]=$1 P_SESS[$n]=$2 P_CWD[$n]=$3 P_HARNESS[$n]=$4 P_SID[$n]=$SID P_MODE[$n]=$MODE_ARGS P_MARK[$n]=$MARK P_PANE[$n]=$5 P_WHY[$n]=$(marker_label) P_ROLL[$n]=$ROLL P_PID[$n]=$PANE_PID
}
while IFS=$'\x1f' read -r seat mailbox harness sess cwd; do
  [ -n "$seat" ] || continue
  [ "$seat" != zeo-rescue ] || continue # the rescue seat is started by hand and never by itself
  [ "$HARNESS" = all ] || [ "$HARNESS" = "$harness" ] || continue
  [ "$ONLY" = " " ] || case "$ONLY" in *" $seat "*) ;; *) continue;; esac
  if [ "$sess" = "-" ] || [ "$cwd" = "-" ]; then echo "UNRESOLVED $seat: the chart gives no session or folder"; unresolved=$((unresolved+1)); continue; fi
  [[ "$sess" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || { echo "UNRESOLVED $seat: bad session name $sess"; unresolved=$((unresolved+1)); continue; }
  [ "$mailbox" = "$seat" ] || { echo "UNRESOLVED $seat: mailbox is $mailbox, not the seat id; the identity map must say which it starts as"; unresolved=$((unresolved+1)); continue; }
  SID="" MODE_ARGS="" WHY="" SANDBOX="" ROLL="" MARK="" MARK_WHY="" PANE_PID=""
  SESSION=$SESSION_ARG
  if [ -z "$SESSION" ] && [ -f "$PINS" ]; then
    SESSION=$(awk -v s="$seat" '$1==s {print $2}' "$PINS")
    [ -z "$SESSION" ] || [[ "$SESSION" =~ $ID_RE ]] || { echo "UNRESOLVED $seat: bad pin in $PINS"; unresolved=$((unresolved+1)); continue; }
  fi
  if "$TMUX_BIN" -L "$SOCKET" has-session -t "=$sess" 2>/dev/null; then
    if [ $CHECK -eq 1 ]; then if check_seat "$seat" "$sess" "$harness"; then ok=$((ok+1)); else wrong=$((wrong+1)); fi; continue; fi
    if [ $RESEAT -eq 0 ]; then echo "LIVE $seat ($sess)"; live=$((live+1)); continue; fi
    if ! load_record; then echo "UNRESOLVED $seat: $WHY"; unresolved=$((unresolved+1)); continue; fi
    find_pane "$sess" "$SID"
    case "$PANE_STATE" in
      done) echo "OK $seat: started by rescue"; ok=$((ok+1)); continue;;
      none) echo "UNRESOLVED $seat: no pane in $sess holds $SID"; unresolved=$((unresolved+1)); continue;;
    esac
    echo "RESEAT $seat: $harness $SID ($MODE_ARGS; $(marker_label)) in $sess"; reseat=$((reseat+1))
    planned "$seat" "$sess" "$cwd" "$harness" "$PANE"
    continue
  fi
  [ $CHECK -eq 0 ] || { echo "WRONG $seat ($harness): no session $sess"; wrong=$((wrong+1)); continue; }
  running_in "$harness" "$cwd"; rc=$?
  [ $rc -eq 0 ] && { echo "RUNNING $seat: a $harness process is in $cwd"; running=$((running+1)); continue; }
  [ $rc -eq 2 ] && { echo "UNRESOLVED $seat: could not tell whether a process runs in $cwd"; unresolved=$((unresolved+1)); continue; }
  [ -d "$cwd" ] || { echo "UNRESOLVED $seat: no directory $cwd"; unresolved=$((unresolved+1)); continue; }
  if ! load_record; then echo "UNRESOLVED $seat: $WHY"; unresolved=$((unresolved+1)); continue; fi
  echo "RESUME $seat: $harness $SID ($MODE_ARGS; $(marker_label)) in $sess"; resume=$((resume+1))
  planned "$seat" "$sess" "$cwd" "$harness" ""
done <<< "$rows"

if [ $CHECK -eq 1 ]; then
  echo "check: ok $ok, wrong $wrong"
  [ $wrong -eq 0 ] || exit 1
  [ $unresolved -eq 0 ] || exit 3
  exit 0
fi

stopped=1
[ $RESEAT -eq 0 ] || work_list
if [ $APPLY -eq 1 ]; then
  [ $RESEAT -eq 0 ] || [ $unresolved -eq 0 ] || { echo "STOPPED: unresolved reseat plan; no seat was stopped or started"; exit 3; }
  n=${#P_SEAT[@]}
  # Every harness is stopped first, then the daemon, and only then does any seat start: a thread must never have two writers.
  for ((i = 0; i < n; i++)); do
    [ $RESEAT -eq 1 ] || continue
    [ -n "${P_PANE[$i]}" ] || continue
    if ! stop_seat "${P_PANE[$i]}" "${P_CWD[$i]}" "${P_SID[$i]}"; then echo "FAILED ${P_SEAT[$i]}: its old process could not be proved stopped; no further action"; recovery 0; exit 1; fi
  done
  if [ $RESEAT -eq 1 ] && ! stop_daemon; then recovery 0; exit 1; fi
  for ((i = 0; i < n; i++)); do
    seat=${P_SEAT[$i]}; [ -n "$seat" ] || continue
    holds "${P_SID[$i]}"; holder_rc=$?
    if [ "$holder_rc" -ne 1 ]; then echo "FAILED $seat: native thread still running or process inspection failed; no launch"; failed=$((failed+1)); continue; fi
    if ! rollout_free "${P_ROLL[$i]}"; then echo "FAILED $seat: rollout release is not proved (holder: $HOLDER); no launch"; failed=$((failed+1)); continue; fi
    [ $resumed -eq 0 ] || [ "$STAGGER" -eq 0 ] || pause "$STAGGER"
    if ! launch "$i"; then echo "FAILED $seat: tmux could not start it"; unseat "$i"; failed=$((failed+1)); continue; fi
    echo "RESUMED $seat: ${P_HARNESS[$i]} ${P_SID[$i]} (${P_MODE[$i]}; ${P_WHY[$i]}) in ${P_SESS[$i]}"; resumed=$((resumed+1))
    if [ "${P_HARNESS[$i]}" = codex ]; then
      prove_codex "$seat" "${P_SID[$i]}" "${P_MARK[$i]}" "$STATE/prompts/$seat.txt" || { stopped=0; unseat "$i"; recovery "$i"; break; }
    elif [ "${P_HARNESS[$i]}" = claude ]; then
      prove_claude "$seat" "${P_MARK[$i]}" "${P_SESS[$i]}" || { stopped=0; unseat "$i"; recovery "$i"; break; }
    fi
    if ! "$TMUX_BIN" -L "$SOCKET" set-option -p -t "$LAUNCHED_PANE" @zeo_rescue 1; then
      stopped=0; unseat "$i"; recovery "$i"; break
    fi
  done
fi

if [ $APPLY -eq 1 ] && [ $resumed -gt 0 ]; then
  ZEO_RESCUE_HOST="$HOST_NAME" ZEO_RESCUE_SOCKET="$SOCKET" ZEO_RESCUE_CHART="$CHART" "$HERE/records.sh" capture ||
    echo "WARNING: automatic recovery-record refresh incomplete; inspect make records-status"
fi

echo "rescue: live $live, ok $ok, running $running, to resume $resume, to reseat $reseat, resumed $resumed, unresolved $unresolved, failed $failed"
[ $stopped -eq 1 ] || exit 1
[ $failed -eq 0 ] || exit 1
[ $unresolved -eq 0 ] || exit 3
exit 0
