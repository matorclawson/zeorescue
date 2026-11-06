#!/bin/bash
# zeo-rescue: a Claude seat moving folder, through the real code, without touching a seat. Usage: claude-move.sh SESSION TRANSCRIPT [PORT]
# The whole path through the real code: real rescue.sh, seat-exec.sh, seat loader and Claude binary, on a clone of a real transcript.
# Private tmux socket and config; the API is a local listener. No seat is touched and nothing leaves this machine.
set -uo pipefail
orig=$1 src0=$2 port=${3:-39031} sid=ffffffff${orig:8}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
P=$(mktemp -d "${TMPDIR:-/tmp}/rf.XXXXXX"); P=$(cd "$P" && pwd -P); OLD=$P/w/old; NEW=$P/w/repo/main; mkdir -p "$OLD" "$NEW" "$P/cfg/projects" "$P/home" "$P/cap" "$P/state"; git -C "$NEW" init -q
src=$P/source.jsonl; LC_ALL=C sed "s/$orig/$sid/g" "$src0" > "$src"
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
oe=$P/cfg/projects/$(key "$OLD"); ne=$P/cfg/projects/$(key "$NEW"); mkdir -p "$oe/memory" "$oe/$sid/subagents"
mv "$src" "$oe/$sid.jsonl"; b=$(stat -f %z "$oe/$sid.jsonl"); echo x > "$oe/$sid/subagents/keep.txt"
printf -- '- [marker](marker.md) — ZEOTOKEN-MEMORY-SEEN\n' > "$oe/memory/MEMORY.md"; echo x > "$oe/memory/marker.md"; printf '{"sessionId":"other"}\n' > "$oe/11111111-2222-4333-8444-555555555555.jsonl"
k=sk-ant-not-a-real-key
jq -n --arg o "$OLD" --arg n "$NEW" --arg k "${k: -20}" '{hasCompletedOnboarding:true,lastOnboardingVersion:"2.1.318",customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($o):{hasTrustDialogAccepted:true},($n):{hasTrustDialogAccepted:true}}}' > "$P/cfg/.claude.json"
cat > "$P/claude" <<W
#!/bin/sh
exec env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "$HOME/.local/bin/claude" "\$@"
W
chmod +x "$P/claude"
S=rf$$; TM=/opt/homebrew/bin/tmux
printf '{"seats":[{"seat_id":"rc","mailbox":"rc","desired_agent":"claude","desired_host":"h","desired_tmux":{"session":"rc-s"},"desired_folder":"%s"}]}' "$OLD" > "$P/chart.json"
echo "rc $sid" > "$P/pins"; : > "$P/moves"; printf 'moved for a rehearsal' > "$P/note"
export ZEO_RESCUE_PINS=$P/pins ZEO_RESCUE_MOVES=$P/moves ZEO_RESCUE_STATE=$P/state ZEO_RESCUE_PROJECTS=$P/cfg/projects ZEO_RESCUE_CLAUDE=$P/claude ZEO_RESCUE_CLAUDE_JSON=$P/cfg/.claude.json ZEO_RESCUE_PROOF_TRIES=40 ZEO_RESCUE_PROOF_PAUSE=1
R() { "$R0/rescue.sh" --host h --socket "$S" --stagger 0 --chart "$P/chart.json" "$@"; }
perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!; trap 'kill $L 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null' EXIT; perl -e 'select(undef,undef,undef,0.4)'
tail -n 4000 "$oe/$sid.jsonl" | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null | grep -v '^$' | tail -1 | cut -c1-48 > "$P/lastwords"
[ -s "$P/lastwords" ] || { echo "NO LAST WORDS: this proves nothing"; exit 1; }
echo "== transcript $b bytes; the seat starts in its old folder"
R --apply 2>&1 | grep -E '^(FIRST SEAT OK|STOPPED|FAILED|rescue:)' | cut -c1-120
perl -e 'select(undef,undef,undef,6)'; b2=$(stat -f %z "$oe/$sid.jsonl"); before=$(ls "$P"/cap/req.* 2>/dev/null | wc -l | tr -d ' ')
echo "== it moves, through --reseat --relaunch --apply"
echo "rc $NEW" > "$P/moves"; s=$(perl -MTime::HiRes -e 'print Time::HiRes::time()')
R --reseat --relaunch --apply --note-file "$P/note" 2>&1 | grep -E '^(RESEAT|MOVE|RESUMED|FIRST SEAT OK|MOVED OK|NOTE|STOPPED|FAILED|UNRESOLVED|RECOVERY|rescue:)' | sed "s#$P#<P>#g" | cut -c1-135
perl -e 'printf "seconds through the move: %.1f\n", Time::HiRes::time()-'"$s" -MTime::HiRes
perl -e 'select(undef,undef,undef,6)'
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | sed "s#$P#<P>#g" | cut -c1-120
echo "== what the model would receive after the move"
last=""; for f in $(ls -t "$P"/cap/req.* 2>/dev/null); do n=${f##*.}; [ "$n" -gt "$before" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
[ -n "$last" ] || { echo "NO REQUEST AFTER THE MOVE: this proves nothing"; exit 1; }
jq -r '"messages=\(.messages|length)"' "$last"; printf 'memory token: '; LC_ALL=C /usr/bin/fgrep -c ZEOTOKEN-MEMORY-SEEN "$last"
jq -r '[.messages[]|.content|if type=="array" then map(.text//"")|join(" ") else . end]|join(" ")' "$last" > "$P/all.txt"; printf 'last words [%s] found: ' "$(cat "$P/lastwords")"; LC_ALL=C /usr/bin/grep -oF -f "$P/lastwords" "$P/all.txt" | wc -l | tr -d ' '
printf 'note reached it: '; LC_ALL=C /usr/bin/grep -c 'moved for a rehearsal' "$P/all.txt"
echo "== on disk"
printf 'old project gone: '; [ -e "$oe" ] && echo NO || echo yes
printf 'transcripts for the session: %s; new project grew by %s\n' "$(find "$P/cfg/projects" -maxdepth 2 -name "$sid.jsonl" | wc -l | tr -d ' ')" "$(( $(stat -f %z "$ne/$sid.jsonl") - b2 ))"
printf 'came with it: memory=%s subagent=%s other session=%s\n' "$(ls "$ne/memory" | wc -l | tr -d ' ')" "$(ls "$ne/$sid/subagents" | wc -l | tr -d ' ')" "$(ls "$ne" | grep -c '^11111111')"
printf 'top-level sessions in the new project: '; ls "$ne"/*.jsonl | wc -l | tr -d ' '
tail -c +$((b2+1)) "$ne/$sid.jsonl" | jq -r 'select(.cwd) | [.sessionId,.cwd]|@tsv' 2>/dev/null | sed "s#$P#<P>#" | sort | uniq -c | cut -c1-100 | head -4
echo "== a second run, then a crash"
R --reseat --relaunch 2>&1 | grep -E '^(OK|RESEAT)' | cut -c1-80
"$TM" -L "$S" kill-session -t '=rc-s'; perl -e 'select(undef,undef,undef,1)'
R 2>&1 | grep -E '^(RESUME|MOVE|UNRESOLVED)' | sed "s#$P#<P>#g" | cut -c1-110
echo "kept in $P: it holds a copy of the transcript, so delete it when you are done"
