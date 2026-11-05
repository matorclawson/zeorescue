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
# --session ID (with exactly one --seat) names the session to resume. Use it when the newest transcript in a seat's directory is not
# the seat's own, such as after someone ran another session there.
# session-pins holds the same answer, durably: a line "SEAT SESSION-ID" for a seat whose newest transcript is known not to be its own.
# --before limits the search for a recorded marker to files older than that local time, when newer ones were written during a fault.
#
# Three things are read from the seat's own record and never chosen here:
#   the session     its newest transcript or thread, or --session
#   the mode        Claude's permissionMode; Codex's approval and sandbox policies (3 of 35 Codex seats ran workspace-write)
#   the git marker  @zeo_seat, from its newest shell snapshot. Without a pane marker the seat loader turns git and gh off, so a seat
#                   recorded as inactive stays inactive. Seats with no record (all Claude seats: their snapshots keep no exports) get
#                   ZEO_RESCUE_DEFAULT_MARKER, except a workspace-write seat, which stays inactive.
#
# A Codex seat starts only when no process holds its rollout. Its own client going away proves little: the shared daemon keeps every
# thread open, so a seat started beside it would be a second writer. A seat refused this way stays down, and the run says who holds it.
# A first seat that fails its proof is stopped again and loses @zeo_rescue, so the next run plans it again; RECOVERY says what is down.
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
DEFAULT_MARKER=${ZEO_RESCUE_DEFAULT_MARKER:-master}
PROOF_TRIES=${ZEO_RESCUE_PROOF_TRIES:-24}
PROOF_PAUSE=${ZEO_RESCUE_PROOF_PAUSE:-5}
STOP_TRIES=${ZEO_RESCUE_STOP_TRIES:-30}
SOCKET=zeo2 HOST_NAME=matormini HARNESS=all STAGGER=20 APPLY=0 ONLY=" " RESEAT=0 CHECK=0 SESSION="" SESSION_ARG="" NOTE_FILE="" BEFORE=""
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
    --host) [ $# -ge 2 ] || usage; HOST_NAME=$2; shift 2;;
    --socket) [ $# -ge 2 ] || usage; SOCKET=$2; shift 2;;
    --stagger) [ $# -ge 2 ] || usage; STAGGER=$2; shift 2;;
    --chart) [ $# -ge 2 ] || usage; CHART=$2; shift 2;;
    *) usage;;
  esac
done
case "$HARNESS" in claude|codex|all) ;; *) usage;; esac
[[ "$STAGGER" =~ ^[0-9]+$ ]] || usage
[ -z "$BEFORE" ] || [[ "$BEFORE" =~ ^[0-9]{12}$ ]] || usage
[ $CHECK -eq 0 ] || { [ $APPLY -eq 0 ] && [ $RESEAT -eq 0 ]; } || usage
ID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
if [ -n "$SESSION_ARG" ]; then
  [[ "$SESSION_ARG" =~ $ID_RE ]] || usage
  n=0; for w in $ONLY; do n=$((n+1)); done
  [ "$n" -eq 1 ] || { echo "rescue: --session needs exactly one --seat" >&2; exit 2; }
fi
[ -z "$NOTE_FILE" ] || [ -r "$NOTE_FILE" ] || { echo "rescue: cannot read $NOTE_FILE" >&2; exit 2; }
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
  "$PS_BIN" -axo pid=,command= | awk -v id="$1" '($2 ~ /(^|\/)(claude|codex)$/ || $2 ~ /\/(claude|codex)\/versions\//) && index($0, id) {f=1} END {exit !f}'
}

SID="" MODE_ARGS="" WHY="" SANDBOX="" ROLL=""
plan_claude() { # sets SID and MODE_ARGS for a Claude seat, or WHY
  local dir f m; dir=$PROJECTS/$(printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')
  # newest top-level transcript by name-safe glob; subagent transcripts live one level down
  if [ -n "$SESSION" ]; then f=$dir/$SESSION.jsonl; [ -f "$f" ] || { WHY="no transcript $f"; return 1; }
  else f=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1); fi
  [ -n "$f" ] || { WHY="no transcript in $dir"; return 1; }
  SID=$(basename "$f" .jsonl)
  [[ "$SID" =~ $ID_RE ]] || { WHY="newest transcript has no session id: $f"; return 1; }
  m=$(tail -c 5000000 "$f" | grep -o '"permissionMode":"[^"]*"' | tail -1 | sed -E 's/.*:"([^"]*)"/\1/')
  case "$m" in
    default|auto|acceptEdits|plan) MODE_ARGS="--permission-mode $m";;
    *) WHY="transcript records no permission mode I may reuse ('$m')"; return 1;;
  esac
}
plan_codex() { # sets SID, MODE_ARGS and SANDBOX for a Codex seat, or WHY
  local q row a s lines where roll
  where="cwd = '$(printf %s "$1" | sed "s/'/''/g")'"
  [ -z "$SESSION" ] || where="id = '$SESSION'"
  q="select id || ' ' || rollout_path from threads where $where and archived = 0 and thread_source = 'user' order by updated_at desc limit 1;"
  row=$("$SQLITE" "file:$CODEX_DB?mode=ro&immutable=1" "$q" 2>/dev/null) || { WHY="cannot read $CODEX_DB"; return 1; }
  [ -n "$row" ] || { WHY="no Codex thread for this directory"; return 1; }
  # a space, not a control byte: the sqlite3 shell escapes control characters in values, so char(31) arrives as a literal ^_
  SID=${row%% *}; roll=${row#* }
  [[ "$SID" =~ $ID_RE ]] || { WHY="unexpected thread id $SID"; return 1; }
  [ -f "$roll" ] || { WHY="no rollout file $roll"; return 1; }
  lines=$(tail -c 5000000 "$roll" | grep -o '"approval_policy":"[^"]*"\|"sandbox_policy":{"type":"[^"]*"')
  a=$(printf '%s\n' "$lines" | grep approval_policy | tail -1 | sed -E 's/.*:"([^"]*)"/\1/')
  s=$(printf '%s\n' "$lines" | grep sandbox_policy | tail -1 | sed -E 's/.*:"([^"]*)"/\1/')
  case "$a" in never|on-request|untrusted|on-failure) ;; *) WHY="rollout records no approval policy ('$a')"; return 1;; esac
  case "$s" in danger-full-access|workspace-write|read-only) ;; *) WHY="rollout records no sandbox ('$s')"; return 1;; esac
  MODE_ARGS="-a $a -s $s"; SANDBOX=$s ROLL=$roll
}

MARK="" MARK_WHY=""
marker_of() { # marker_of HARNESS SID: sets MARK (empty means no marker, so git stays off) and MARK_WHY
  local f m t
  if [ "$1" = codex ]; then
    for f in $(ls -t "$SNAPSHOTS/$2".* 2>/dev/null); do
      if [ -n "$BEFORE" ]; then t=$(date -r "$f" +%Y%m%d%H%M); [ "$t" -lt "$BEFORE" ] || continue; fi
      m=$(grep -o 'ZEO_TMUX_SEAT=[^ ]*' "$f" | tail -1 | tr -d "\"'"); m=${m#ZEO_TMUX_SEAT=}
      case "$m" in
        master|sparring|principal) MARK=$m MARK_WHY=recorded; return 0;;
        inactive) MARK="" MARK_WHY="recorded inactive"; return 0;;
      esac
    done
    if [ "$SANDBOX" = workspace-write ]; then MARK="" MARK_WHY="no record, workspace-write"; return 0; fi
  fi
  MARK=$DEFAULT_MARKER MARK_WHY="no record, default"
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

prove_codex() { # the first Codex seat must show the loader worked before any other starts
  local seat=$1 sid=$2 mark=$3 pf=$4 i snap=""
  for ((i = 0; i < PROOF_TRIES; i++)); do
    snap=$(find "$SNAPSHOTS" -name "$sid.*" -newer "$pf" 2>/dev/null | head -1)
    # a snapshot exists before it is written, so judge it only once it holds an identity
    if [ -n "$snap" ] && grep -q 'ZMAIL_INSTANCE=' "$snap"; then break; fi
    pause "$PROOF_PAUSE"
  done
  [ -n "$snap" ] || { echo "STOPPED: no shell snapshot for $seat; no other seat was started"; return 1; }
  grep -q "ZMAIL_INSTANCE=.\{0,1\}$seat.\{0,1\}\$" "$snap" || { echo "STOPPED: $seat did not get its own identity; no other seat was started"; return 1; }
  if [ -n "$mark" ]; then
    grep -q "ZEO_TMUX_SEAT=.\{0,1\}$mark.\{0,1\}\$" "$snap" || { echo "STOPPED: $seat lacks marker $mark; no other seat was started"; return 1; }
    if grep -q 'GIT_ALLOW_PROTOCOL=.\{0,1\}file.\{0,1\}$' "$snap"; then echo "STOPPED: $seat still has network git off; no other seat was started"; return 1; fi
  fi
  echo "FIRST SEAT OK $seat: own identity${mark:+, marker $mark, git on}"
}
prove_claude() { # the same for the first Claude seat, from the environment of the running process
  local seat=$1 mark=$2 sess=$3 i id pid opt cmd env=""
  for ((i = 0; i < PROOF_TRIES; i++)); do
    IFS='|' read -r id pid opt cmd < <(panes_of "$sess")
    env=$("$PS_BIN" -Ewwp "$pid" -o command= 2>/dev/null)
    case "$env" in *"ZMAIL_INSTANCE=$seat"*) break;; esac
    pause "$PROOF_PAUSE"
  done
  case "$env" in *"ZMAIL_INSTANCE=$seat "*|*"ZMAIL_INSTANCE=$seat") ;; *) echo "STOPPED: $seat did not get its own identity; no other seat was started"; return 1;; esac
  if [ -n "$mark" ]; then
    case "$env" in *"ZEO_TMUX_SEAT=$mark"*) ;; *) echo "STOPPED: $seat lacks marker $mark; no other seat was started"; return 1;; esac
    case "$env" in *"GIT_ALLOW_PROTOCOL=file "*) echo "STOPPED: $seat still has network git off; no other seat was started"; return 1;; esac
  fi
  echo "FIRST SEAT OK $seat: own identity${mark:+, marker $mark, git on}"
}

HOLDER=""
rollout_free() { # rollout_free FILE: sets HOLDER and fails while any process has the rollout open. Run it after the daemon stop.
  local i
  [ -x "$LSOF" ] || { HOLDER="unknown (no lsof)"; return 1; }
  for ((i = 0; i < STOP_TRIES; i++)); do
    HOLDER=$("$LSOF" -t -- "$1" 2>/dev/null | paste -sd' ' -)
    [ -n "$HOLDER" ] || return 0
    pause 1
  done
  return 1
}

children() { # children TREE PID: a process's children as "pid etime command", without what every seat runs: mail hooks, caffeinate and the daemon's own processes
  printf '%s\n' "$1" | awk -v p="$2" '$2==p { c=$0; sub(/^ *[0-9]+ +[0-9]+ +[^ ]+ +/, "", c); i=index(c, " && eval "); if (i) c=substr(c, i+9)
    if (c !~ /\/\.local\/share\/zeo\/messenger\/hooks\// && c !~ /^caffeinate / && c !~ /\/app-server-daemon\/releases\//) print $1, $3, substr(c, 1, 110) }'
}
work_list() { # what a restart would cut: it reads only, and a quiet result is what could be seen, not a promise that nothing is in progress
  local tree i seats=0 busy=0 hit kids daemon line pid
  tree=$("$PS_BIN" -axo pid=,ppid=,etime=,command=) || { echo "WORK: ps failed, so running work is unknown"; return 0; }
  for ((i = 0; i < ${#P_SEAT[@]}; i++)); do
    [ -n "${P_PANE[$i]}" ] || continue
    seats=$((seats+1)) hit=0
    if "$TMUX_BIN" -L "$SOCKET" capture-pane -p -t "${P_PANE[$i]}" 2>/dev/null | grep -q 'esc to interrupt'; then echo "WORK ${P_SEAT[$i]}: a turn is in progress on its screen"; hit=1; fi
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
  echo "RECOVERY: $left seats are down, counting the one that failed. Each thread is intact and nothing is lost. Start none of them by hand. Tell zeo-rescue what you see; once the cause is fixed, the same line brings them back, whether or not their sleep has run out."
}

stop_seat() { # stop_seat PANE CWD SID: replace the harness with a sleep, and wait until nothing holds the session
  local i
  "$TMUX_BIN" -L "$SOCKET" respawn-pane -k -t "$1" -c "$2" -- sleep 3600 || return 1
  for ((i = 0; i < STOP_TRIES; i++)); do holds "$3" || return 0; pause 1; done
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
  # shellcheck disable=SC2086  # pids holds only numbers from ps
  "$KILL_BIN" $pids 2>/dev/null
  pause "${ZEO_RESCUE_DAEMON_WAIT:-5}"
  for p in $pids; do
    if "$PS_BIN" -axo pid=,command= | awk -v p="$p" '$1==p {f=1} END {exit !f}'; then "$KILL_BIN" -9 "$p" 2>/dev/null; echo "DAEMON KILLED: pid $p ignored SIGTERM"; fi
  done
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
  else "$TMUX_BIN" -L "$SOCKET" set-option -pu -t "$pane" @zeo_seat 2>/dev/null; fi
  "$TMUX_BIN" -L "$SOCKET" set-option -p -t "$pane" @zeo_rescue 1 || return 1
  # shellcheck disable=SC2086  # the mode holds only words validated by plan_claude and plan_codex
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
    if ! "plan_$harness" "$cwd"; then echo "UNRESOLVED $seat: $WHY"; unresolved=$((unresolved+1)); continue; fi
    find_pane "$sess" "$SID"
    case "$PANE_STATE" in
      done) echo "OK $seat: started by rescue"; ok=$((ok+1)); continue;;
      none) echo "UNRESOLVED $seat: no pane in $sess holds $SID"; unresolved=$((unresolved+1)); continue;;
    esac
    marker_of "$harness" "$SID"
    echo "RESEAT $seat: $harness $SID ($MODE_ARGS; $(marker_label)) in $sess"; reseat=$((reseat+1))
    planned "$seat" "$sess" "$cwd" "$harness" "$PANE"
    continue
  fi
  [ $CHECK -eq 0 ] || { echo "WRONG $seat ($harness): no session $sess"; wrong=$((wrong+1)); continue; }
  running_in "$harness" "$cwd"; rc=$?
  [ $rc -eq 0 ] && { echo "RUNNING $seat: a $harness process is in $cwd"; running=$((running+1)); continue; }
  [ $rc -eq 2 ] && { echo "UNRESOLVED $seat: could not tell whether a process runs in $cwd"; unresolved=$((unresolved+1)); continue; }
  [ -d "$cwd" ] || { echo "UNRESOLVED $seat: no directory $cwd"; unresolved=$((unresolved+1)); continue; }
  if ! "plan_$harness" "$cwd"; then echo "UNRESOLVED $seat: $WHY"; unresolved=$((unresolved+1)); continue; fi
  marker_of "$harness" "$SID"
  echo "RESUME $seat: $harness $SID ($MODE_ARGS; $(marker_label)) in $sess"; resume=$((resume+1))
  planned "$seat" "$sess" "$cwd" "$harness" ""
done <<< "$rows"

if [ $CHECK -eq 1 ]; then
  echo "check: ok $ok, wrong $wrong"
  [ $wrong -eq 0 ] || exit 1
  exit 0
fi

stopped=1
[ $RESEAT -eq 0 ] || work_list
if [ $APPLY -eq 1 ]; then
  n=${#P_SEAT[@]}
  # Every harness is stopped first, then the daemon, and only then does any seat start: a thread must never have two writers.
  for ((i = 0; i < n; i++)); do
    [ -n "${P_PANE[$i]}" ] || continue
    if ! stop_seat "${P_PANE[$i]}" "${P_CWD[$i]}" "${P_SID[$i]}"; then echo "FAILED ${P_SEAT[$i]}: its old process would not stop, so it was not restarted"; P_SEAT[$i]=""; failed=$((failed+1)); fi
  done
  [ $RESEAT -eq 0 ] || stop_daemon
  proved_codex=0 proved_claude=0
  for ((i = 0; i < n; i++)); do
    seat=${P_SEAT[$i]}; [ -n "$seat" ] || continue
    if [ "${P_HARNESS[$i]}" = codex ] && ! rollout_free "${P_ROLL[$i]}"; then echo "FAILED $seat: pid $HOLDER still holds its rollout, so it was not started: that would be two writers"; failed=$((failed+1)); continue; fi
    [ $resumed -eq 0 ] || [ "$STAGGER" -eq 0 ] || pause "$STAGGER"
    if ! launch "$i"; then echo "FAILED $seat: tmux could not start it"; unseat "$i"; failed=$((failed+1)); continue; fi
    echo "RESUMED $seat: ${P_HARNESS[$i]} ${P_SID[$i]} (${P_MODE[$i]}; ${P_WHY[$i]}) in ${P_SESS[$i]}"; resumed=$((resumed+1))
    if [ "${P_HARNESS[$i]}" = codex ] && [ $proved_codex -eq 0 ]; then
      prove_codex "$seat" "${P_SID[$i]}" "${P_MARK[$i]}" "$STATE/prompts/$seat.txt" || { stopped=0; unseat "$i"; recovery "$i"; break; }
      proved_codex=1
    elif [ "${P_HARNESS[$i]}" = claude ] && [ $proved_claude -eq 0 ]; then
      prove_claude "$seat" "${P_MARK[$i]}" "${P_SESS[$i]}" || { stopped=0; unseat "$i"; recovery "$i"; break; }
      proved_claude=1
    fi
  done
fi

echo "rescue: live $live, ok $ok, running $running, to resume $resume, to reseat $reseat, resumed $resumed, unresolved $unresolved, failed $failed"
[ $stopped -eq 1 ] || exit 1
[ $failed -eq 0 ] || exit 1
[ $unresolved -eq 0 ] || exit 3
exit 0
