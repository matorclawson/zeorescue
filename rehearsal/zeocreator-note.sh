#!/bin/bash
# zeo-rescue: the zeocreator-note step rehearsed without touching the seat. Usage: zeocreator-note.sh [PORT]
# A copy of zeocreator's real transcript (session id and folder rewritten) and its real memory, under a private folder, private config and a
# private tmux socket; the API is a local listener. The seat is started by the copy of rescue.sh, so it reads as right, the case that failed
# on 8 Nov 04:27. Then the copy of reseat-lines.sh runs zeocreator-note on the installed Claude. The seat is named rzc in the copies, so
# nothing runs as zeocreator. The copies refuse to start if they could reach zeo2. Nothing leaves this machine. KEEP=1 keeps the working folder.
set -uo pipefail
port=${1:-39051}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
orig=84bd8e22-bfe4-4e9e-85e4-bbcc3959c34c sid=ffffffff-bfe4-4e9e-85e4-bbcc3959c34c
RF=/Volumes/AIPEMedia1/code/ducktyper-ai/dt-creator/main RK=-Volumes-AIPEMedia1-code-ducktyper-ai-dt-creator-main
RP=$HOME/.claude/projects/$RK TM=/opt/homebrew/bin/tmux S=rzc$$
INSTALLED=$("$HOME/.local/bin/claude" --version | awk 'NR==1 {print $1}')
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
real() { # the real seat as this read it: it must read the same at the end
  "$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12
  find "$RP/memory" -type f -exec stat -f "%N %z %m" {} + | LC_ALL=C sort | shasum
  ls "$HOME/.claude/projects" | grep -c zeroemployeeorg-zeocreator; ls "$HOME/.local/state/zeo-rescue" | grep -c zeocreator-note.*done
}
real_before=$(real)
P=$(mktemp -d "${TMPDIR:-/tmp}/rzc.XXXXXX"); P=$(cd "$P" && pwd -P); F=$P/w/creator
clean() { kill "$L" 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; if [ -z "${KEEP:-}" ]; then rm -rf "$P"; else echo "kept in $P: it holds a copy of the transcript, so delete it when you are done"; fi; }
L=""; trap clean EXIT
show() { sed "s#$P#<P>#g" | cut -c1-150; }
echo "== the shape, copied read-only"
mkdir -p "$F" "$P/cfg/projects" "$P/home" "$P/cap" "$P/state" "$P/run/notes"
git -C "$F" init -q && git -C "$F" -c user.email=r@r -c user.name=r commit -q --allow-empty -m rehearsal || { echo "NO FOLDER: this proves nothing"; exit 1; }
pe=$P/cfg/projects/$(key "$F"); mkdir -p "$pe"
was=$(tail -n 2000 "$RP/$orig.jsonl" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | tail -1); [ "$was" = "$RF" ] || { echo "THE TRANSCRIPT'S FOLDER IS ${was:-none}: this proves nothing"; exit 1; }
LC_ALL=C sed -e "s/$orig/$sid/g" -e "s#$RF#$F#g" "$RP/$orig.jsonl" > "$pe/$sid.jsonl"; [ ! -d "$RP/$orig" ] || cp -Rp "$RP/$orig" "$pe/$sid"
cp -Rp "$RP/memory" "$pe/memory"; tok=ZEOTOKEN-MEMORY-SEEN-$$; printf -- '- [rehearsal marker](rehearsal-marker.md) — %s\n' "$tok" >> "$pe/memory/MEMORY.md"
words=$(awk -F'"' '/^ZEOCREATOR_PROOF=/ {print $2}' "$R0/reseat-lines.sh")
LC_ALL=C grep -qF -e "$words" "$pe/$sid.jsonl" && { echo "THE TRANSCRIPT ALREADY HOLDS THE NOTE: this proves nothing"; exit 1; }
echo "transcript $(stat -f %z "$pe/$sid.jsonl") bytes; memory $(find "$pe/memory" -type f | wc -l | tr -d ' ') files; its saved prompt names: $(LC_ALL=C grep -ao 'file-based memory at `[^`]*`' "$pe/$sid.jsonl" | tail -1)"
k=sk-ant-not-a-real-key
jq -n --arg o "$F" --arg k "${k: -20}" --arg v "$INSTALLED" '{hasCompletedOnboarding:true,lastOnboardingVersion:$v,customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($o):{hasTrustDialogAccepted:true}}}' > "$P/cfg/.claude.json"; chmod 600 "$P/cfg/.claude.json"
cat > "$P/claude" <<W
#!/bin/sh
exec env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "$HOME/.local/bin/claude" "\$@"
W
chmod +x "$P/claude"
# The copies of the operator's scripts: the seat is rzc, the socket private; checked before anything starts.
cp "$R0/seat-exec.sh" "$R0/Makefile" "$P/run/"; cp "$R0/notes/zeocreator-memory-20261108.txt" "$P/run/notes/"
sed -e "s/^SOCKET=zeo2 HOST_NAME=matormini /SOCKET=$S HOST_NAME=h /" "$R0/rescue.sh" > "$P/run/rescue.sh"
sed -e '/^pin [0-9a-f]\{64\} /d' -e "s/-L zeo2/-L $S/g" -e 's/--seat zeocreator/--seat rzc/g' -e 's/\$1=="zeocreator"/$1=="rzc"/g' -e 's/RESEAT zeocreator: /RESEAT rzc: /' "$R0/reseat-lines.sh" > "$P/run/reseat-lines.sh"
chmod +x "$P/run/rescue.sh" "$P/run/reseat-lines.sh"
[ "$(cat "$P/run/rescue.sh" "$P/run/reseat-lines.sh" | grep -c zeo2)" = 0 ] && [ "$(sed -n '/^  zeocreator-note)/,/;;$/p' "$P/run/reseat-lines.sh" | grep -c -e '--seat zeocreator' -e '"zeocreator"')" = 0 ] \
  || { echo "THE COPY CAN REACH THE ORG OR NAME THE SEAT: stopped before anything started"; exit 1; }
printf '{"seats":[{"seat_id":"rzc","mailbox":"rzc","desired_agent":"claude","desired_host":"h","desired_tmux":{"session":"rzc-s"},"desired_folder":"%s"}]}' "$F" > "$P/chart.json"
echo "rzc $sid" > "$P/run/session-pins"; echo "rzc $F" > "$P/run/folder-moves"
# The kill that stops a shared Codex daemon is a stub that only writes down what it was asked (the Architect, 9 Nov 11:28Z): a rehearsal stops no real daemon.
printf '#!/bin/sh\necho "$*" >> "%s/kills"\n' "$P" > "$P/nokill"; chmod +x "$P/nokill"
export ZEO_RESCUE_KILL=$P/nokill ZEO_RESCUE_CHART=$P/chart.json ZEO_RESCUE_STATE=$P/state STATE=$P/state ZEO_RESCUE_PROJECTS=$P/cfg/projects ZEO_RESCUE_CLAUDE=$P/claude ZEO_RESCUE_CLAUDE_JSON=$P/cfg/.claude.json ZEO_RESCUE_PROOF_TRIES=60 ZEO_RESCUE_PROOF_PAUSE=1
R() { "$P/run/rescue.sh" "$@"; }; Ln() { "$P/run/reseat-lines.sh" "$@"; }
perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!; perl -e 'select(undef,undef,undef,0.4)'
pane() { "$TM" -L "$S" list-panes -t '=rzc-s' -F "$1"; }
echo "== the seat starts by rescue on $INSTALLED, so it reads as right"
R --apply 2>&1 | grep -E '^(FIRST SEAT OK|STOPPED|FAILED|rescue:)' | show
perl -e 'select(undef,undef,undef,8)'; pid=$(pane '#{pane_pid}'); printf 'running %s, pid %s\n' "$(pane '#{pane_current_command}')" "$pid"
R --reseat --relaunch --harness claude --seat rzc 2>&1 | grep -E '^(OK|RESEAT)' | show
echo "== zeocreator-note"
b=$(stat -f %z "$pe/$sid.jsonl"); n0=$(ls "$P/cap" | sed -n "s/^req\.//p" | sort -n | tail -1); n0=${n0:-0}
Ln zeocreator-note 2>&1 | grep -E '^(the Claude|claude |VERSION|RESEAT|RESUMED|FIRST SEAT OK|STOPPED|FAILED|UNRESOLVED|RECOVERY|OK|WRONG|check:|rescue:|NOT|REFUSED|BUSY|NOTE DELIVERED|ALREADY)' | show
perl -e 'select(undef,undef,undef,4)'
printf 'a new process: %s (was %s, now %s)\n' "$([ "$(pane '#{pane_pid}')" != "$pid" ] && echo yes || echo NO)" "$pid" "$(pane '#{pane_pid}')"
echo "processes naming the session:"; ps -axo pid=,ppid=,command= | grep -F -e "$sid" | grep -v -e grep -e "ps -axo" | cut -c1-140 | show
echo "== what the model would receive"
last=""; for f in "$P"/cap/req.*; do [ "${f##*.}" -gt "$n0" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
[ -n "$last" ] || { echo "NO REQUEST AFTER THE RESTART: this proves nothing"; exit 1; }
jq -r '[.messages[]|.content|if type=="array" then map(.text//"")|join(" ") else . end]|join(" ")' "$last" > "$P/all.txt"
printf 'the note reached it: %s; its words on the memory folder: %s; the memory index read from its own key: %s\n' "$(LC_ALL=C grep -c 'to correct one thing' "$P/all.txt")" "$(LC_ALL=C grep -cF -e "$words" "$P/all.txt")" "$(LC_ALL=C grep -cF -e "$tok" "$last")"
printf 'the memory path its saved prompt names: %s\n' "$(jq -r '.system | if type=="array" then map(.text)|join("\n") else . end' "$last" | grep -o 'file-based memory at `[^`]*`' | head -1)"
echo "== on disk"
printf "the note's words in the transcript after the restart: %s; transcripts for the session: %s; an old-key memory folder made: %s\n" "$(tail -c +$((b+1)) "$pe/$sid.jsonl" | LC_ALL=C grep -cF -e "$words")" "$(find "$P/cfg/projects" -name "$sid.jsonl" | wc -l | tr -d ' ')" "$(ls "$P/cfg/projects" | grep -c zeroemployeeorg)"
printf 'the done mark: %s\n' "$(cat "$P/state/zeocreator-note-20261108.done" 2>/dev/null || echo NONE)"
echo "== a second run"
p2=$(pane '#{pane_pid}'); Ln zeocreator-note 2>&1 | grep -E '^(ALREADY|REFUSED|RESEAT|RESUMED|NOTE)' | show
[ "$(pane '#{pane_pid}')" = "$p2" ] && echo "the same process is still up" || echo "IT WAS RESTARTED AGAIN"
[ "$real_before" = "$(real)" ] && echo "the real seat, its memory and the org's panes are the same as before this ran" || echo "THE REAL SIDE CHANGED while this ran: read why"
