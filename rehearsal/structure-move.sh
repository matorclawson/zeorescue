#!/bin/bash
# zeo-rescue: the first seat's move into the one code structure (zeoarchitect, a clone at <org>/<repo> that becomes <org>/<repo>/main),
# rehearsed in its exact shape without touching the seat. Usage: structure-move.sh [PORT]
# A copy of the seat's real transcript (session id and folder rewritten), its tool results and its real memory, under the key of a clone of
# the same shape: an ordinary clone with a commit, an untracked and an ignored file, one live linked worktree outside it and one prunable.
# Private folder, config and tmux socket; the API is a local listener. The seat starts there on the version it runs today, by the copy of
# rescue.sh. Then the operator's own steps run, on copies of the real scripts: structure-trust, structure-first on the installed version,
# structure-clear, and second runs. The seat is named rza in the copies, so nothing runs as zeoarchitect, and the copies refuse to start if
# they could reach zeo2 or a real folder. Nothing leaves this machine. KEEP=1 keeps the working folder.
set -uo pipefail
port=${1:-39082}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
orig=766f4d22-bf17-4513-b068-514a9bf46d00 sid=ffffffff-bf17-4513-b068-514a9bf46d00
RO=/Volumes/AIPEMedia1/code/zeroemployeeorg/zeoarchitect RN=$RO/main RW=/Volumes/ZeoWorkCS/zeoarchitect/za-ci
key() { printf %s "$1" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g'; }
RP=$HOME/.claude/projects/$(key "$RO") TM=/opt/homebrew/bin/tmux S=rza$$
INSTALLED=$("$HOME/.local/bin/claude" --version | awk 'NR==1 {print $1}'); RUNNING=${RUNNING:-2.1.318}
[ -x "$HOME/.local/share/claude/versions/$RUNNING" ] || { echo "NO BINARY for $RUNNING: this proves nothing"; exit 1; }
real() { # the real seat as this read it: it must read the same at the end
  "$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12
  stat -f '%i' "$RO"; [ -e "$RN" ] && echo "main there" || echo "no main"; git -C "$RO" rev-parse --absolute-git-dir
  /usr/bin/shasum < "$RW/.git"; find "$RP/memory" -type f -exec stat -f "%N %z %m" {} + | LC_ALL=C sort | shasum
  ls "$HOME/.claude/projects" | grep -c -e 'zeoarchitect-main'; ls "$HOME/.local/state/zeo-rescue" | grep -c structure-move
  jq -r --arg d "$RN" '.projects | has($d)' "$HOME/.claude.json"; grep -c zeoarchitect "$R0/folder-moves"
}
real_before=$(real)
P=$(mktemp -d "${TMPDIR:-/tmp}/rza.XXXXXX"); P=$(cd "$P" && pwd -P); OLD=$P/w/org/zarch NEW=$OLD/main WT=$P/w/ext/za-ci
clean() { kill "$L" 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; if [ -z "${KEEP:-}" ]; then rm -rf "$P"; else echo "kept in $P: it holds a copy of the transcript, so delete it when you are done"; fi; }
L=""; trap clean EXIT
show() { sed -e "s#$(key "$P")#<P>#g" -e "s#$P#<P>#g" | cut -c1-160; }
echo "== the shape, copied read-only"
mkdir -p "$P/w/org" "$P/w/ext" "$P/cfg/projects" "$P/home" "$P/cap" "$P/state" "$P/run/notes"
[ ! -e "$RN" ] && [ "$(git -C "$RO" rev-parse --absolute-git-dir 2>/dev/null)" = "$RO/.git" ] || { echo "THE REAL CLONE IS NOT IN THE SHAPE READ: this proves nothing"; exit 1; }
g() { git -c user.email=rehearsal@invalid -c user.name=rehearsal -c init.defaultBranch=main "$@"; }
g init -q "$OLD" && printf 'x\n' > "$OLD/README.md" && printf 'ignored/\n' > "$OLD/.gitignore" && g -C "$OLD" add -A && g -C "$OLD" commit -qm one \
  && g -C "$OLD" worktree add -q "$WT" -b za-ci 2>/dev/null && g -C "$OLD" worktree add -q "$P/w/ext/za-gone" -b za-gone 2>/dev/null && rm -rf "$P/w/ext/za-gone" \
  && mkdir "$OLD/ignored" && echo i > "$OLD/ignored/i" && echo u > "$OLD/untracked" || { echo "COULD NOT MAKE THE CLONE: this proves nothing"; exit 1; }
head0=$(git -C "$OLD" rev-parse HEAD) ino0=$(stat -f %i "$OLD")
oe=$P/cfg/projects/$(key "$OLD"); ne=$P/cfg/projects/$(key "$NEW"); mkdir -p "$oe"
was=$(tail -n 2000 "$RP/$orig.jsonl" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | tail -1); [ "$was" = "$RO" ] || { echo "THE TRANSCRIPT'S FOLDER IS ${was:-none}: this proves nothing"; exit 1; }
LC_ALL=C sed -e "s/$orig/$sid/g" -e "s#$RO#$OLD#g" "$RP/$orig.jsonl" > "$oe/$sid.jsonl"; [ ! -d "$RP/$orig" ] || cp -Rp "$RP/$orig" "$oe/$sid"
cp -Rp "$RP/memory" "$oe/memory"; nmem=$(find "$oe/memory" -type f | wc -l | tr -d ' ')
tok=ZEOTOKEN-MEMORY-SEEN-$$; printf -- '- [rehearsal marker](rehearsal-marker.md) — %s\n' "$tok" >> "$oe/memory/MEMORY.md"
words=$(awk -F'"' '/^PROOF=/ {print $2}' "$R0/structure-move.sh")
LC_ALL=C grep -qF -e "$words" "$oe/$sid.jsonl" && { echo "THE TRANSCRIPT ALREADY HOLDS THE NOTE: this proves nothing"; exit 1; }
LC_ALL=C grep -qF -e "$tok" "$oe/$sid.jsonl" && { echo "THE TRANSCRIPT ALREADY HOLDS THE MARKER: this proves nothing"; exit 1; }
echo "transcript $(stat -f %z "$oe/$sid.jsonl") bytes; memory $nmem files; its saved prompt names: $(LC_ALL=C grep -ao 'file-based memory at `[^`]*`' "$oe/$sid.jsonl" | tail -1 | show)"
echo "clone at $(echo "$OLD" | show), inode $ino0, at $head0; worktrees: $(git -C "$OLD" worktree list | wc -l | tr -d ' ') listed, $(git -C "$OLD" worktree list --porcelain | grep -c '^prunable') prunable"
k=sk-ant-not-a-real-key
jq -n --arg o "$OLD" --arg k "${k: -20}" --arg v "$INSTALLED" '{hasCompletedOnboarding:true,lastOnboardingVersion:$v,customApiKeyResponses:{approved:[$k],rejected:[]},projects:{($o):{hasTrustDialogAccepted:true}}}' > "$P/cfg/.claude.json"; chmod 600 "$P/cfg/.claude.json"
echo "$HOME/.local/share/claude/versions/$RUNNING" > "$P/use"
cat > "$P/claude" <<W
#!/bin/sh
exec env HOME="$P/home" CLAUDE_CONFIG_DIR="$P/cfg" ANTHROPIC_API_KEY=$k ANTHROPIC_BASE_URL=http://127.0.0.1:$port DISABLE_TELEMETRY=1 DISABLE_ERROR_REPORTING=1 DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 "\$(cat "$P/use")" "\$@"
W
chmod +x "$P/claude"
# The copies of the operator's scripts: the seat is rza, the socket and folders private; checked before anything starts.
cp "$R0/seat-exec.sh" "$R0/Makefile" "$R0/structure-move.sh" "$P/run/"; cp "$R0/notes/structure-move-claude.txt" "$P/run/notes/"
sed -e "s/^SOCKET=zeo2 HOST_NAME=matormini /SOCKET=$S HOST_NAME=h /" "$R0/rescue.sh" > "$P/run/rescue.sh"
sed -e '/^pin [0-9a-f]\{64\} /d' -e "s/-L zeo2/-L $S/g" "$R0/reseat-lines.sh" > "$P/run/reseat-lines.sh"
chmod +x "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/structure-move.sh"
printf 'rza claude rza-s %s %s %s %s\n' "$sid" "$OLD" "$NEW" "$ino0" > "$P/run/structure-moves"
[ "$(cat "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/structure-move.sh" | grep -c zeo2)" = 0 ] && ! grep -q /Volumes "$P/run/structure-moves" \
  && [ "$(grep -c '^SOCKET='"$S"' HOST_NAME=h ' "$P/run/rescue.sh")" = 1 ] || { echo "THE COPY CAN REACH THE ORG OR A REAL FOLDER: stopped before anything started"; exit 1; }
printf '{"seats":[{"seat_id":"rza","mailbox":"rza","desired_agent":"claude","desired_host":"h","desired_tmux":{"session":"rza-s"},"desired_folder":"%s"}]}' "$OLD" > "$P/chart.json"
echo "rza $sid" > "$P/run/session-pins"; : > "$P/run/folder-moves"
export ZEO_RESCUE_CHART=$P/chart.json ZEO_RESCUE_STATE=$P/state STATE=$P/state ZEO_RESCUE_PROJECTS=$P/cfg/projects ZEO_RESCUE_CLAUDE=$P/claude ZEO_RESCUE_CLAUDE_JSON=$P/cfg/.claude.json ZEO_RESCUE_PROOF_TRIES=60 ZEO_RESCUE_PROOF_PAUSE=1
R() { "$P/run/rescue.sh" "$@"; }; Ln() { "$P/run/reseat-lines.sh" "$@"; }
perl "$HERE/capture.pl" "$port" "$P/cap" & L=$!; perl -e 'select(undef,undef,undef,0.4)'
newest() { ls "$P/cap" | sed -n 's/^req\.//p' | sort -n | tail -1; }
pane() { "$TM" -L "$S" list-panes -t '=rza-s' -F "$1"; }
turn() { "$TM" -L "$S" send-keys -t '=rza-s:' -l "$1"; "$TM" -L "$S" send-keys -t '=rza-s:' Enter; perl -e 'select(undef,undef,undef,10)'; }
projs() { echo "  projects $1: $(ls "$P/cfg/projects" | show | paste -sd' ' -)"; }
echo "== the seat starts in its clone on $RUNNING"
R --apply 2>&1 | grep -E '^(FIRST SEAT OK|STOPPED|FAILED|rescue:)' | show
perl -e 'select(undef,undef,undef,8)'; pid=$(pane '#{pane_pid}'); printf 'running %s, pid %s, in %s\n' "$(pane '#{pane_current_command}')" "$pid" "$(pane '#{pane_current_path}' | show)"
turn 'a wake before the move'; projs "after a wake"
echo "== the lines go in: structure-moves, folder-moves and session-pins as the commit has them"
echo "rza $NEW carry" > "$P/run/folder-moves"
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
Ln structure-first rza 2>&1 | grep -E '^(REFUSED|the Claude)' | head -3 | show
echo "== structure-trust, then structure-first on $INSTALLED"
Ln structure-trust rza 2>&1 | grep -E '^(NOTHING|ADDED|REFUSED|FAILED)' | show
echo "$HOME/.local/bin/claude" > "$P/use"; before=$(newest); b2=$(stat -f %z "$oe/$sid.jsonl")
s=$(perl -MTime::HiRes -e 'print Time::HiRes::time()')
Ln structure-first rza 2>&1 | grep -E '^(the Claude|the note|claude |RESEAT|MOVE|CARRIED|RESUMED|FIRST SEAT OK|MOVED OK|NOTE|STOPPED|FAILED|UNRESOLVED|RECOVERY|OK|WRONG|check:|rescue:|NOT|REFUSED|BUSY|ALREADY|work:)' | show
e=$(perl -MTime::HiRes -e 'print Time::HiRes::time()'); perl -e 'printf "seconds through the restart: %.1f\n", $ARGV[1]-$ARGV[0]' "$s" "$e"
perl -e 'select(undef,undef,undef,4)'
printf 'running %s, pid %s, a new process: %s, in %s\n' "$(pane '#{pane_current_command}')" "$(pane '#{pane_pid}')" "$([ "$(pane '#{pane_pid}')" != "$pid" ] && echo yes || echo NO)" "$(pane '#{pane_current_path}' | show)"
echo "processes naming the session:"; ps -axo pid=,command= | grep -F -e "$sid" | grep -v -e grep -e "ps -axo" | cut -c1-110 | show
echo "== what the model would receive after the move"
last=""; for f in "$P"/cap/req.*; do n=${f##*.}; [ "$n" -gt "${before:-0}" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
[ -n "$last" ] || { echo "NO REQUEST AFTER THE MOVE: this proves nothing"; exit 1; }
jq -r '[.messages[]|.content|if type=="array" then map(.text//"")|join(" ") else . end]|join(" ")' "$last" > "$P/all.txt"
printf 'the note reached it: %s; its words on the memory folder: %s; the memory index read from the new key: %s\n' "$(LC_ALL=C grep -c "your clone was moved whole from $OLD to $NEW" "$P/all.txt")" "$(LC_ALL=C grep -cF -e "$words" "$P/all.txt")" "$(LC_ALL=C grep -cF -e "$tok" "$last")"
printf 'the memory path its saved prompt names: %s\n' "$(jq -r '.system | if type=="array" then map(.text)|join("\n") else . end' "$last" | grep -o 'file-based memory at `[^`]*`' | head -1 | show)"
printf 'the working directory the harness tells it last: %s\n' "$(LC_ALL=C grep -ao 'orking directory: [^ "\\]*' "$last" | tail -1 | show)"
printf 'the turn before the move reached it: %s\n' "$(LC_ALL=C grep -c 'a wake before the move' "$P/all.txt")"
turn 'a wake after the carry'; [ -n "$(pane '#{pane_pid}')" ] && echo "the moved seat is still up after a wake" || echo "THE SEAT IS GONE"
echo "== on disk and in git"
printf 'the same folder at main: %s; HEAD the same: %s; untracked and ignored files with it: %s; the old path holds only main: %s, mode %s\n' "$([ "$(stat -f %i "$NEW")" = "$ino0" ] && echo yes || echo NO)" \
  "$([ "$(git -C "$NEW" rev-parse HEAD)" = "$head0" ] && echo yes || echo NO)" "$([ -f "$NEW/untracked" ] && [ -f "$NEW/ignored/i" ] && echo yes || echo NO)" "$([ "$(ls -A "$OLD")" = main ] && echo yes || echo NO)" "$(stat -f %Lp "$OLD")"
printf 'the linked worktree reaches it: %s; git status works there: %s; the prunable entry left as it was: %s; main is an ordinary clone: %s\n' "$([ "$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)" = "$NEW/.git" ] && echo yes || echo NO)" \
  "$(git -C "$WT" status --porcelain >/dev/null 2>&1 && echo yes || echo NO)" "$([ "$(git -C "$NEW" worktree list --porcelain | grep -c '^prunable')" = 1 ] && echo yes || echo NO)" "$([ "$(git -C "$NEW" rev-parse --absolute-git-dir)" = "$NEW/.git" ] && echo yes || echo NO)"
printf 'old project gone: %s; transcripts for the session: %s; an old-key folder made again: %s\n' "$([ -e "$oe" ] && echo NO || echo yes)" "$(find "$P/cfg/projects" -name "$sid.jsonl" | wc -l | tr -d ' ')" "$([ -e "$oe" ] && echo YES || echo no)"
printf 'memory in the new project: %s files, the same bytes as the real memory (its MEMORY.md without the marker): %s\n' "$(find "$ne/memory" -type f | wc -l | tr -d ' ')" \
  "$([ "$(cd "$ne/memory" && find . -type f ! -name MEMORY.md | LC_ALL=C sort | xargs shasum; grep -vF -e "$tok" "$ne/memory/MEMORY.md" | shasum)" = "$(cd "$RP/memory" && find . -type f ! -name MEMORY.md | LC_ALL=C sort | xargs shasum; shasum < "$RP/memory/MEMORY.md")" ] && echo yes || echo NO)"
printf "the note's words in the transcript after the restart: %s; trust for the new folder: %s\n" "$(tail -c +$((b2+1)) "$ne/$sid.jsonl" | LC_ALL=C grep -cF -e "$words")" "$(jq -r --arg d "$NEW" '.projects[$d].hasTrustDialogAccepted' "$P/cfg/.claude.json")"
tail -c +$((b2+1)) "$ne/$sid.jsonl" | jq -r 'select(.cwd) | [.sessionId,.cwd]|@tsv' 2>/dev/null | show | sort | uniq -c | head -4
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
echo "== structure-clear, then second runs"
Ln structure-clear rza 2>&1 | grep -E '^(DELETED|NOTHING|OUT OF ORDER|FAILED|REFUSED)' | show
printf 'the backup gone: %s\n' "$([ -e "$P/state/claude-json.before-rza" ] && echo NO || echo yes)"
p2=$(pane '#{pane_pid}'); for st in structure-trust structure-first structure-clear; do Ln "$st" rza 2>&1 | grep -E '^(ALREADY|NOTHING|REFUSED|NOT READY|OUT OF ORDER|RESEAT|NOTE)' | show; done
[ "$(pane '#{pane_pid}')" = "$p2" ] && echo "the same process is still up" || echo "IT WAS RESTARTED AGAIN"
R --reseat --relaunch 2>&1 | grep -E '^(OK|RESEAT|MOVE|UNRESOLVED)' | show
[ "$real_before" = "$(real)" ] && echo "the real seat, its clone, its worktree's link, its memory, the real config and the org's panes are the same as before this ran" || echo "THE REAL SIDE CHANGED while this ran: read why"
