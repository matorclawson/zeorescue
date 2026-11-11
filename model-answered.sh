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
