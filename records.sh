#!/bin/bash
# Deterministic recovery inventory: no model, harness invocation, mail or target mutation.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
STORE=${ZEO_RESCUE_RECORDS:-$STATE/recovery-records.json}
CHART=${ZEO_RESCUE_CHART:-/Volumes/ZeoWork/zeo-evidence/zeo-rt-seats/org-chart/ORG-CHART.json}
JQ=${ZEO_RESCUE_JQ:-/opt/homebrew/bin/jq}
TM=${ZEO_RESCUE_TMUX:-/opt/homebrew/bin/tmux}
PS=${ZEO_RESCUE_PS:-/bin/ps}
LSOF=${ZEO_RESCUE_LSOF:-/usr/sbin/lsof}
SQL=${ZEO_RESCUE_SQLITE:-/usr/bin/sqlite3}
DB=${ZEO_RESCUE_CODEX_DB:-$HOME/.codex/state_5.sqlite}
PROJECTS=${ZEO_RESCUE_PROJECTS:-$HOME/.claude/projects}
SESSIONS=${ZEO_RESCUE_CLAUDE_SESSIONS:-$HOME/.claude/sessions}
HOST_NAME=${ZEO_RESCUE_HOST:-matormini}
SOCKET=${ZEO_RESCUE_SOCKET:-zeo2}
UUID='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
fail() { echo "records: $*" >&2; return 1; }
[ -x "$JQ" ] || { fail 'jq unavailable'; exit 1; }
# Read native structured events, never strings inside assistant/user messages.
# Large files are bounded to the last 5000 complete JSONL lines for policy lookup.
history() { # HARNESS SESSION CWD -> {path,mode_args,policy}; no newest-session query
  local h=$1 sid=$2 cwd=$3 path row data dir meta
  [[ "$sid" =~ $UUID ]] || { fail 'invalid native session id'; return 1; }
  if [ "$h" = codex ]; then
    row=$("$SQL" "file:$DB?mode=ro" "select rollout_path from threads where id = '$sid' and cwd = '$(printf %s "$cwd" | sed "s/'/''/g")' and archived = 0 and thread_source = 'user';") || return 1
    [ -n "$row" ] && [[ "$row" != *$'\n'* ]] || { fail 'exact Codex thread/cwd is missing or ambiguous'; return 1; }
    path=$row
    [ -r "$path" ] || { fail 'Codex rollout unreadable'; return 1; }
    meta=$(head -n 1 "$path" | "$JQ" -ce --arg sid "$sid" --arg cwd "$cwd" 'select(.type=="session_meta" and .payload.id==$sid and .payload.cwd==$cwd)') || { fail 'Codex rollout metadata disagrees'; return 1; }
    data=$(tail -n 5000 "$path" | "$JQ" -sce '
      [.[] | select(.type=="turn_context") | (.payload // .)] | last |
      select(.approval_policy as $a | ["never","on-request","untrusted","on-failure"] | index($a)) |
      select(.sandbox_policy.type as $s | ["danger-full-access","workspace-write","read-only"] | index($s)) |
      {mode_args:["-a",.approval_policy,"-s",.sandbox_policy.type],policy:{approval_policy,sandbox_policy}}') || { fail 'no supported structured Codex policy in recent history'; return 1; }
  elif [ "$h" = claude ]; then
    dir=$PROJECTS/$(printf %s "$cwd" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')
    path=$dir/$sid.jsonl
    [ -r "$path" ] || { fail 'exact Claude transcript unreadable'; return 1; }
    data=$(tail -n 5000 "$path" | "$JQ" -sce --arg sid "$sid" --arg cwd "$cwd" '
      ([.[] | select(.sessionId != null)] | last | .sessionId) as $actual |
      ([.[] | select(.sessionId==$sid and .cwd != null)] | last | .cwd) as $actual_cwd |
      select($actual==$sid and $actual_cwd==$cwd) |
      ([.[] | select(.sessionId==$sid and .permissionMode != null)] | last | .permissionMode) as $m |
      select(["default","manual","auto","acceptEdits","plan"] | index($m)) |
      {mode_args:["--permission-mode",$m],policy:{permissionMode:$m}}') || { fail 'Claude identity/cwd/policy missing or conflicting'; return 1; }
  else fail 'unsupported harness'; return 1; fi
  "$JQ" -cn --arg path "$path" --argjson data "$data" '$data + {path:$path}'
}
valid_store() {
  "$JQ" -e --arg host "$HOST_NAME" --arg socket "$SOCKET" '
    .schema_version==1 and .host==$host and .socket==$socket and
    (.records|type=="array") and (.issues|type=="array") and
    ([.records[].seat]|length== (unique|length)) and
    ([.records[].session_id]|length== (unique|length)) and
    ([.records[].tmux_session]|length== (unique|length))' "$STORE" >/dev/null 2>&1
}
get_record() { # SEAT HARNESS SESSION_NAME CWD; validates saved identity and current exact history
  local seat=$1 h=$2 sess=$3 cwd=$4 r sid hist
  valid_store || { fail 'saved records unavailable/invalid; run records capture while the mapping is observable'; return 1; }
  r=$("$JQ" -ce --arg seat "$seat" --arg h "$h" --arg sess "$sess" --arg cwd "$cwd" '
    select(any(.issues[]; .seat==$seat and .blocking==true)|not) |
    [.records[] | select(.seat==$seat and .mailbox==$seat and .harness==$h and .tmux_session==$sess and .cwd==$cwd)] |
    select(length==1) | .[0] |
    select(.marker as $m | ["master","sparring","principal","inactive"] | index($m))' "$STORE") || { fail "$seat: no unambiguous matching recovery record"; return 1; }
  sid=$("$JQ" -r .session_id <<< "$r")
  hist=$(history "$h" "$sid" "$cwd") || return 1
  # Policy is read from the exact native history, including changes after the last sample.
  "$JQ" -cn --argjson r "$r" --argjson hist "$hist" '$r + {history_path:$hist.path,mode_args:$hist.mode_args,policy:$hist.policy}'
}
seed_record() { # SEAT HARNESS TMUX_SESSION CWD SESSION MARKER: a seat no capture could record. The caller's reviewed seed names it; the exact native history must still agree.
  local seat=$1 h=$2 sess=$3 cwd=$4 sid=$5 mark=$6 hist
  case "$mark" in master|sparring|principal|inactive) ;; *) fail "$seat: bad marker in seed"; return 1;; esac
  hist=$(history "$h" "$sid" "$cwd") || return 1
  "$JQ" -cn --arg seat "$seat" --arg h "$h" --arg sess "$sess" --arg cwd "$cwd" --arg sid "$sid" --arg mark "$mark" --argjson hist "$hist" \
    '{seat:$seat,mailbox:$seat,harness:$h,tmux_session:$sess,cwd:$cwd,session_id:$sid,marker:$mark,source:"seed",history_path:$hist.path,mode_args:$hist.mode_args,policy:$hist.policy}'
}
health() { # health [MAX_AGE_SECONDS]: is this cache fit to recover from? 0 fresh and clear; 3 fresh with blocked seats; 1 stale or unusable
  local max=${1:-300} now
  [[ "$max" =~ ^[0-9]+$ ]] || return 2
  valid_store || { echo 'records: UNUSABLE: no valid cache at '"$STORE"; return 1; }
  now=$(date -u +%s)
  "$JQ" -r --argjson now "$now" --argjson max "$max" '
    ($now - (.generated_at|fromdateiso8601)) as $age | ([.issues[]|select(.blocking)]) as $b |
    (if $age > $max then "records: STALE: last capture \($age)s ago, limit \($max)s; the collector is not running or is failing"
     else "records: fresh, \($age)s old" end) + ", \(.records|length) mappings, \($b|length) blocked",
    ($b|group_by(.reason)[]|"BLOCKED \(length) seats: \(.[0].reason)")' "$STORE"
  "$JQ" -e --argjson now "$now" --argjson max "$max" '($now - (.generated_at|fromdateiso8601)) <= $max' "$STORE" >/dev/null || return 1
  "$JQ" -e 'any(.issues[]; .blocking)|not' "$STORE" >/dev/null || return 3
}
take_lock() { # A capture killed by the teardown it exists to survive leaves its lock behind, so a dead owner's lock is taken over. A live one is refused.
  local lock=$1 owner
  if mkdir "$lock" 2>/dev/null; then echo $$ > "$lock/pid"; return 0; fi
  owner=$(cat "$lock/pid" 2>/dev/null)
  if [ -z "$owner" ]; then # between another capture's mkdir and its pid, or left by a version without one
    [ -n "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ] || { fail 'collector already running'; return 1; }
  elif kill -0 "$owner" 2>/dev/null; then fail "collector already running as pid $owner"; return 1; fi
  mv "$lock" "$lock.dead.$$" 2>/dev/null || { fail 'lost the race for a dead lock'; return 1; }
  rm -rf "$lock.dead.$$"
  mkdir "$lock" 2>/dev/null || { fail 'lost the race for a dead lock'; return 1; }
  echo $$ > "$lock/pid"
  echo 'records: took over the lock of a dead capture' >&2
}
collect() {
  local chart rows old tree tmp lock now seat h sess cwd mailbox panes pane pid mark cmd sid env hist r matches found prev actual line source status=0
  umask 077
  mkdir -p "$STATE" "$(dirname "$STORE")" || return 1
  lock=$STORE.lock
  take_lock "$lock" || return 1
  CAPTURE_LOCK=$lock
  trap 'rm -rf "$CAPTURE_LOCK" 2>/dev/null || true' EXIT
  chart=$CHART
  if ! "$JQ" -e '.seats|type=="array"' "$chart" >/dev/null 2>&1; then chart=$STATE/ORG-CHART.last-good.json; fi
  # One bad row blocks its own seat. It must not stop capture for the other 49.
  local good='.seat_id==.mailbox and ((.seat_id//"")|test("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")) and ((.desired_tmux.session? // "")|test("^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")) and ((.desired_folder//"")|startswith("/"))'
  local mine='[.seats[] | select(.desired_host==$host and (.desired_agent=="codex" or .desired_agent=="claude") and .seat_id!="zeo-rescue")]'
  rows=$("$JQ" -ce --arg host "$HOST_NAME" "$mine | map(select($good)) | select(length>0) |
    select(([.[].seat_id]|length)==([.[].seat_id]|unique|length)) |
    select(([.[].desired_tmux.session]|length)==([.[].desired_tmux.session]|unique|length))" "$chart") || { fail 'chart invalid, duplicate or unavailable; previous records untouched'; return 1; }
  local badrows
  badrows=$("$JQ" -c --arg host "$HOST_NAME" "$mine | map(select(($good)|not) | .seat_id)" "$chart") || badrows='[]'
  old='{"records":[],"issues":[]}'
  if [ -e "$STORE" ]; then valid_store || { fail 'existing records invalid; refusing overwrite'; return 1; }; old=$(cat "$STORE"); fi
  tree=$("$PS" -axo pid=,command=) || { fail 'process enumeration failed; previous records untouched'; return 1; }
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  tmp=$(mktemp "$STORE.tmp.XXXXXX") || return 1
  local output='[]' issues='[]' issue=""
  [ "$badrows" = '[]' ] || { status=3; issues=$("$JQ" -c '[.[]|{seat:.,blocking:true,reason:"chart row is invalid for this seat"}]' <<< "$badrows"); }
  while IFS= read -r row; do
    seat=$("$JQ" -r .seat_id <<< "$row"); h=$("$JQ" -r .desired_agent <<< "$row")
    sess=$("$JQ" -r .desired_tmux.session <<< "$row"); cwd=$("$JQ" -r .desired_folder <<< "$row")
    prev=$("$JQ" -c --arg seat "$seat" '[.records[] | select(.seat==$seat)] | first // null' <<< "$old")
    found=0; r=""; issue=""
    # Failure here may mean the entire tmux server is gone. Preserve records, never infer new mappings.
    panes=$("$TM" -L "$SOCKET" list-panes -s -t "=$sess" -F '#{pane_id}|#{pane_pid}|#{@zeo_seat}' 2>/dev/null) || panes=""
    while IFS='|' read -r pane pid mark; do
      [ -n "$pane" ] || continue
      cmd=$(printf '%s\n' "$tree" | awk -v p="$pid" '$1==p { $1=""; sub(/^ /,""); print }')
      # Recognize only the actual pane harness; wrappers/children require explicit lifecycle integration.
      if ! awk -v h="$h" '{n=split($1,a,"/"); exit !(a[n]==h || index($1,"/"h"/versions/")>0)}' <<< "$cmd"; then continue; fi
      found=$((found+1))
      sid=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$cmd" | sort -u)
      source=live-resume-process
      local fdpaths fdpath fdid fdids="" fdhist
      # Claude keeps no file open on its transcript, but it does keep an exact pid-to-session file. It also names a session with nothing in argv.
      if [ "$h" = claude ] && [ -r "$SESSIONS/$pid.json" ]; then
        fdid=$("$JQ" -r --arg pid "$pid" 'select((.pid|tostring)==$pid) | .sessionId // empty' "$SESSIONS/$pid.json" 2>/dev/null)
        if [[ "$fdid" =~ $UUID ]]; then sid=$fdid; source=native-pid-session; fi
      fi
      # A new native CLI may not name a session in argv. Inspect its open native
      # history files and validate exact metadata/DB ownership, never directory mtime.
      fdpaths=$("$LSOF" -a -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p')
      while IFS= read -r fdpath; do
        case "$fdpath" in *.jsonl) ;; *) continue;; esac
        fdid=$(basename "$fdpath" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
        [[ "$fdid" =~ $UUID ]] || continue
        fdhist=$(history "$h" "$fdid" "$cwd" 2>/dev/null) || continue
        [ "$("$JQ" -r .path <<< "$fdhist")" = "$fdpath" ] || continue
        fdids="${fdids}${fdid}"$'\n'
      done <<< "$fdpaths"
      fdids=$(printf '%s' "$fdids" | sed '/^$/d' | sort -u)
      if [ -n "$fdids" ]; then
        if ! [[ "$fdids" =~ $UUID ]]; then issue='multiple open native histories for this seat'; continue; fi
        sid=$fdids; source=native-history-file-descriptor
      fi
      if ! [[ "$sid" =~ $UUID ]]; then issue='native session id missing or ambiguous in live process/history descriptors'; continue; fi
      case "$mark" in master|sparring|principal|inactive) ;; *) issue='pane has no recorded marker'; continue;; esac
      if [ "$h" = codex ] && [[ " $cmd " != *' --no-daemon '* ]]; then issue='Codex is attached to an unqualified shared daemon'; continue; fi
      env=$("$PS" -Ewwp "$pid" -o command= 2>/dev/null) || { issue='cannot inspect process identity'; continue; }
      case "$env" in *" ZMAIL_INSTANCE=$seat "*|*" ZMAIL_INSTANCE=$seat") ;; *) issue='process identity does not match seat'; continue;; esac
      actual=$("$LSOF" -a -d cwd -Fn -p "$pid" 2>/dev/null | sed -n 's/^n//p')
      if [ "$actual" != "$cwd" ]; then issue='process cwd does not match chart or is unreadable'; continue; fi
      hist=$(history "$h" "$sid" "$cwd") || { issue='exact native history could not be validated'; continue; }
      # Re-read volatile pane and process evidence before committing the observation.
      if [ "$panes" != "$("$TM" -L "$SOCKET" list-panes -s -t "=$sess" -F '#{pane_id}|#{pane_pid}|#{@zeo_seat}' 2>/dev/null)" ] ||
         [ "$cmd" != "$("$PS" -axo pid=,command= | awk -v p="$pid" '$1==p {$1="";sub(/^ /,"");print}')" ]; then issue='pane/process changed while sampled'; continue; fi
      r=$("$JQ" -cn --arg seat "$seat" --arg h "$h" --arg sess "$sess" --arg cwd "$cwd" --arg sid "$sid" --arg mark "$mark" --arg now "$now" --arg pane "$pane" --arg pid "$pid" --arg source "$source" --argjson hist "$hist" \
        '{seat:$seat,mailbox:$seat,harness:$h,tmux_session:$sess,cwd:$cwd,session_id:$sid,marker:$mark,captured_at:$now,source:$source,pane:$pane,pid:$pid,history_path:$hist.path,mode_args:$hist.mode_args,policy:$hist.policy}')
    done <<< "$panes"
    if [ "$found" -gt 1 ]; then issue='multiple harness panes for one seat'; fi
    if [ "$found" -eq 0 ]; then
      r=$prev
      if [ -n "$panes" ]; then issue='tmux session exists but its native harness mapping cannot be verified'
      elif [ "$prev" = null ]; then issue='no saved record and no observable live resume mapping'
      elif "$JQ" -e --arg seat "$seat" 'any(.issues[]; .seat==$seat and .blocking)' <<< "$old" >/dev/null; then issue='prior conflicting observation remains unresolved'
      elif ! "$JQ" -e --arg h "$h" --arg sess "$sess" --arg cwd "$cwd" '.harness==$h and .tmux_session==$sess and .cwd==$cwd' <<< "$prev" >/dev/null; then issue='chart changed since saved mapping'; fi
    fi
    if [ -n "$issue" ]; then
      status=3; r=$prev
      issues=$("$JQ" -c --arg seat "$seat" --arg reason "$issue" '. + [{seat:$seat,blocking:true,reason:$reason}]' <<< "$issues")
    fi
    if [ -n "$r" ] && [ "$r" != null ]; then output=$("$JQ" -c --argjson r "$r" '.+[$r]' <<< "$output"); fi
  done < <("$JQ" -c '.[]' <<< "$rows")
  # A chart that loses a seat must not erase the mapping that would bring it back. A partial chart would otherwise empty the cache within two captures.
  local kept
  kept=$("$JQ" -c --argjson rows "$rows" '($rows|map(.seat_id)) as $ids | [.records[] | select(.seat as $s | $ids|index($s)|not)]' <<< "$old")
  if [ "$kept" != '[]' ]; then
    output=$("$JQ" -c --argjson kept "$kept" '. + $kept' <<< "$output")
    issues=$("$JQ" -c --argjson kept "$kept" --argjson bad "$badrows" '. + [$kept[] | select(.seat as $s | $bad|index($s)|not) | {seat,blocking:false,reason:"absent from the chart; mapping kept"}]' <<< "$issues")
  fi
  # Two seats on one session block those two, not the org: after an outage no later capture could clear it.
  local dups
  dups=$("$JQ" -c '[group_by(.session_id)[] | select(length>1) | .[].seat]' <<< "$output")
  if [ "$dups" != '[]' ]; then
    status=3
    output=$("$JQ" -c --argjson d "$dups" '[.[] | select(.seat as $s | $d|index($s)|not)]' <<< "$output")
    issues=$("$JQ" -c --argjson d "$dups" '. + [$d[] | {seat:.,blocking:true,reason:"duplicate native session observed; refresh after resolving ownership"}]' <<< "$issues")
    fail 'duplicate native session across seats; those seats are blocked'
  fi
  "$JQ" -n --arg host "$HOST_NAME" --arg socket "$SOCKET" --arg now "$now" --argjson records "$output" --argjson issues "$issues" \
    '{schema_version:1,host:$host,socket:$socket,generated_at:$now,records:$records,issues:$issues}' > "$tmp" || { rm -f "$tmp"; return 1; }
  [ ! -f "$STORE" ] || cp -p "$STORE" "$STORE.previous" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$STORE" || return 1
  # Cache chart during healthy operation; recovery need not have run before the outage.
  tmp=$(mktemp "$STATE/.chart.XXXXXX") && cp "$chart" "$tmp" && mv -f "$tmp" "$STATE/ORG-CHART.last-good.json" || return 1
  "$JQ" -c '{schema_version,generated_at,record_count:(.records|length),issues}' "$STORE"
  return "$status"
}
service() {
  # Generate, do not install. launchd executes one finite capture every 30 seconds and at login.
  local file=$STATE/zeo-rescue-records.plist key envjson='{}' args
  mkdir -p "$STATE" || return 1
  for key in ZEO_RESCUE_STATE ZEO_RESCUE_RECORDS ZEO_RESCUE_CHART ZEO_RESCUE_PROJECTS ZEO_RESCUE_CODEX_DB ZEO_RESCUE_TMUX ZEO_RESCUE_JQ ZEO_RESCUE_SQLITE ZEO_RESCUE_PS ZEO_RESCUE_LSOF ZEO_RESCUE_HOST ZEO_RESCUE_SOCKET; do
    [ -z "${!key:-}" ] || envjson=$("$JQ" -c --arg k "$key" --arg v "${!key}" '.+{($k):$v}' <<< "$envjson")
  done
  "$JQ" -nr --arg script "$HERE/records.sh" --arg dir "$HERE" --arg out "$STATE/records-collector.log" --argjson env "$envjson" '
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict><key>Label</key><string>ac.zeo.rescue-records</string><key>ProgramArguments</key><array><string>/bin/bash</string><string>"+($script|@html)+"</string><string>capture</string></array><key>WorkingDirectory</key><string>"+($dir|@html)+"</string><key>RunAtLoad</key><true/><key>StartInterval</key><integer>30</integer><key>StandardOutPath</key><string>"+($out|@html)+"</string><key>StandardErrorPath</key><string>"+($out|@html)+"</string><key>EnvironmentVariables</key><dict>"+($env|to_entries|map("<key>"+(.key|@html)+"</key><string>"+(.value|@html)+"</string>")|join(""))+"</dict></dict></plist>"' > "$file" || return 1
  printf '%s\n' "$file"
}
install_service() {
  [ "$(uname -s)" = Darwin ] || { fail 'launchd installation requires macOS'; return 1; }
  local domain="gui/$(id -u)" destination="$HOME/Library/LaunchAgents/ac.zeo.rescue-records.plist" file
  if /bin/launchctl print "$domain/ac.zeo.rescue-records" >/dev/null 2>&1; then
    fail 'collector already installed; inspect the existing job rather than replacing it'; return 1
  fi
  file=$(service) || return 1
  /usr/bin/plutil -lint "$file" || return 1
  mkdir -p "$HOME/Library/LaunchAgents" || return 1
  [ ! -e "$destination" ] || { fail "existing plist at $destination; inspect before changing it"; return 1; }
  cp "$file" "$destination" && /bin/launchctl bootstrap "$domain" "$destination" || {
    fail 'install/bootstrap failed; inspect generated plist and launchctl state'; return 1;
  }
  echo 'Installed ac.zeo.rescue-records: finite local captures every 30 seconds and at login; no harness/model involved.'
}
case "${1:-}" in
  capture) collect;;
  get) [ $# -eq 5 ] || exit 2; get_record "$2" "$3" "$4" "$5";;
  status) valid_store || { fail 'saved records unavailable/invalid'; exit 1; }; cat "$STORE";;
  health) health "${2:-300}";;
  seed) [ $# -eq 7 ] || exit 2; seed_record "$2" "$3" "$4" "$5" "$6" "$7";;
  service) service;;
  install) install_service;;
  *) echo 'usage: records.sh capture|status|health [MAX_AGE]|service|install|get SEAT HARNESS TMUX_SESSION CWD|seed SEAT HARNESS TMUX_SESSION CWD SESSION MARKER' >&2; exit 2;;
esac
