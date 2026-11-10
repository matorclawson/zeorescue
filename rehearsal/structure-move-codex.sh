#!/bin/bash
# zeo-rescue: a Codex seat's move into the one code structure (a clone at <org>/<repo> that becomes <org>/<repo>/main), rehearsed on the real
# Codex without touching a seat. Usage: structure-move-codex.sh [--real THREAD] [PORT]
# --real THREAD: the seat runs on a copy of that real thread instead: its rollout and its thread record only, the real folder written as the
# private clone; the auth file, the config and the rest of the real CODEX_HOME are never copied.
# A private CODEX_HOME that this script writes itself: no auth file, a model provider on a local listener that keeps each request and answers
# 400, and a fake key, so nothing leaves this machine and no credential is read. The seat's thread is made there by the real Codex in a clone
# of the seats' shape: an ordinary clone with a commit, an untracked and an ignored file, one live linked worktree outside it and one prunable.
# The seat starts there by a copy of rescue.sh, on a private tmux socket. Then the operator's own steps run, on copies of the real scripts:
# structure-trust, structure-first, structure-clear, and second runs. The seat is rcx, the kill that stops a daemon is a stub that kills
# nothing, and the copies refuse to start if they could reach zeo2 or a real folder. KEEP=1 keeps the working folder.
set -uo pipefail
RT=""; if [ "${1:-}" = --real ]; then RT=${2:-}; shift 2; [[ "$RT" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] || { echo "usage: structure-move-codex.sh [--real THREAD] [PORT]"; exit 2; }; fi
port=${1:-39093}; HERE=$(cd "$(dirname "$0")" && pwd -P); R0=$(dirname "$HERE")
CX=$HOME/.local/bin/codex TM=/opt/homebrew/bin/tmux S=rcx$$
VERSION=$("$CX" --version | awk 'NR==1 {print $2}')
real() { # the real side as this read it: it must read the same at the end
  "$TM" -L zeo2 list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | /usr/bin/shasum | cut -c1-12
  /usr/bin/shasum < "$HOME/.codex/config.toml"; ls "$HOME/.local/state/zeo-rescue" | grep -c -e structure-move -e codex-config.before
  ps -axo command= | grep -c '/app-server-daemon/releases/'
}
real_before=$(real)
P=$(mktemp -d "${TMPDIR:-/tmp}/rcx.XXXXXX"); P=$(cd "$P" && pwd -P); OLD=$P/w/org/cx NEW=$OLD/main WT=$P/w/ext/cx-wt CH=$P/codexhome
clean() { kill "$L" 2>/dev/null; "$TM" -L "$S" kill-server 2>/dev/null; if [ -z "${KEEP:-}" ]; then rm -rf "$P"; else echo "kept in $P"; fi; }
L=""; trap clean EXIT
show() { sed -e "s#$P#<P>#g" | cut -c1-170; }
echo "== the shape, made private"
mkdir -p "$P/w/org" "$P/w/ext" "$CH" "$P/home" "$P/cap" "$P/state" "$P/run/notes"
g() { git -c user.email=rehearsal@invalid -c user.name=rehearsal -c init.defaultBranch=main "$@"; }
g init -q "$OLD" && printf 'x\n' > "$OLD/README.md" && printf 'ignored/\n' > "$OLD/.gitignore" && g -C "$OLD" add -A && g -C "$OLD" commit -qm one \
  && g -C "$OLD" worktree add -q "$WT" -b cx-wt 2>/dev/null && g -C "$OLD" worktree add -q "$P/w/ext/cx-gone" -b cx-gone 2>/dev/null && rm -rf "$P/w/ext/cx-gone" \
  && mkdir "$OLD/ignored" && echo i > "$OLD/ignored/i" && echo u > "$OLD/untracked" || { echo "COULD NOT MAKE THE CLONE: this proves nothing"; exit 1; }
head0=$(git -C "$OLD" rev-parse HEAD) ino0=$(stat -f %i "$OLD")
cat > "$CH/config.toml" <<C
model = "gpt-5"
model_provider = "rehearsal"
check_for_update_on_startup = false

[model_providers.rehearsal]
name = "rehearsal"
base_url = "http://127.0.0.1:$port/v1"
env_key = "REHEARSAL_KEY"
wire_api = "responses"

[projects."$OLD"]
trust_level = "trusted"
C
[ ! -e "$CH/auth.json" ] || { echo "AN AUTH FILE IS THERE: stopped"; exit 1; }
cat > "$P/codex" <<W
#!/bin/sh
exec env HOME="$P/home" CODEX_HOME="$CH" REHEARSAL_KEY=not-a-key "$CX" "\$@"
W
printf '#!/bin/sh\necho "$*" >> "%s/kills"\n' "$P" > "$P/nokill"; chmod +x "$P/codex" "$P/nokill"
perl -e 'use IO::Socket::INET; my ($port,$dir)=@ARGV; my $s=IO::Socket::INET->new(LocalAddr=>"127.0.0.1",LocalPort=>$port,Listen=>16,ReuseAddr=>1) or die; my $n=0;
  while (my $c=$s->accept) { my $h=""; while(<$c>){ $h.=$_; last if /^\r?\n$/ } my ($l)=$h=~/content-length: *(\d+)/i; my $b=""; if($l){ my $r=0; while($r<$l){ my $k=read($c,$b,$l-$r,$r); last unless $k; $r+=$k } }
  $n++; if($h=~/^POST \S*responses/){ open F,">","$dir/req.$n"; binmode F; print F $b; close F } my $e=q({"error":{"type":"invalid_request_error","message":"rehearsal","code":"rehearsal"}});
  print $c "HTTP/1.1 400 Bad Request\r\ncontent-type: application/json\r\ncontent-length: ".length($e)."\r\nconnection: close\r\n\r\n$e"; close $c }' "$port" "$P/cap" & L=$!
perl -e 'select(undef,undef,undef,0.4)'
echo "== the thread, made by the real Codex $VERSION in the clone"
(cd "$OLD" && perl -e 'alarm shift; exec @ARGV' 90 "$P/codex" exec -s danger-full-access -C "$OLD" "the seat's first turn" >/dev/null 2>&1)
db() { sqlite3 "file:$CH/state_5.sqlite?mode=ro" "$1" 2>/dev/null || sqlite3 "file:$CH/state_5.sqlite?mode=ro&immutable=1" "$1"; }
sid=$(db "select id from threads where cwd = '$OLD' and thread_source = 'user' order by updated_at desc limit 1;"); roll=$(db "select rollout_path from threads where id = '$sid';")
[ -n "$sid" ] && [ -f "$roll" ] || { echo "NO THREAD: this proves nothing"; exit 1; }
# rescue.sh now reads a copy with the -wal; the checkpoint still makes the private database whole before the real thread record goes in.
sqlite3 "$CH/state_5.sqlite" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null || { echo "COULD NOT CHECKPOINT THE PRIVATE DATABASE: this proves nothing"; exit 1; }
if [ -n "$RT" ]; then
  echo "== a copy of the real thread $RT: its rollout and its thread record only (the Architect, 9 Nov 11:28Z)"
  # Read from a private copy of the real database with its -wal; nothing else of the real CODEX_HOME is copied, and no auth or config.
  RDB=$P/realdb; mkdir -m 700 "$RDB"; cp "$HOME/.codex/state_5.sqlite" "$RDB/s" && { [ ! -e "$HOME/.codex/state_5.sqlite-wal" ] || cp "$HOME/.codex/state_5.sqlite-wal" "$RDB/s-wal"; } \
    || { echo "COULD NOT COPY THE REAL DATABASE: this proves nothing"; exit 1; }
  rroll=$(sqlite3 "$RDB/s" "select rollout_path from threads where id = '$RT';") rcwd=$(sqlite3 "$RDB/s" "select cwd from threads where id = '$RT';")
  # Copied by column name: the real database can be at another schema than the one this Codex made, and the columns that differ are named.
  rcols=$(sqlite3 "$RDB/s" "select name from pragma_table_info('threads');" | sort) pcols=$(sqlite3 "$CH/state_5.sqlite" "select name from pragma_table_info('threads');" | sort)
  common=$(comm -12 <(printf '%s\n' "$rcols") <(printf '%s\n' "$pcols") | sed 's/.*/"&"/' | paste -sd, -)
  printf 'thread record columns only in the real database: %s; only in the private one: %s; real schema migration %s, private %s\n' "$(comm -23 <(printf '%s\n' "$rcols") <(printf '%s\n' "$pcols") | paste -sd' ' - | sed 's/^$/none/')" \
    "$(comm -13 <(printf '%s\n' "$rcols") <(printf '%s\n' "$pcols") | paste -sd' ' - | sed 's/^$/none/')" "$(sqlite3 "$RDB/s" 'select max(version) from _sqlx_migrations;')" "$(sqlite3 "$CH/state_5.sqlite" 'select max(version) from _sqlx_migrations;')"
  sqlite3 "$RDB/s" ".headers on" ".mode insert threads" "select $common from threads where id = '$RT';" > "$P/row.sql"; rm -f "$RDB/s" "$RDB/s-wal" "$RDB/s-shm"
  [ -f "$rroll" ] && [ -n "$rcwd" ] && [ -s "$P/row.sql" ] || { echo "NO REAL THREAD $RT: this proves nothing"; exit 1; }
  case "$rroll" in "$HOME/.codex/sessions/"*) ;; *) echo "THE REAL ROLLOUT IS NOT UNDER sessions: stopped"; exit 1;; esac
  # The copy gets a thread id of its own, so no check here can take the live seat that holds the real one for it, and the real folder is
  # written as the private clone, so nothing in the copy names it. A last line still being written is left out.
  NID=$(uuidgen | tr "A-F" "a-f"); nroll=$CH/sessions/$(dirname "${rroll#"$HOME/.codex/sessions/"}")/$(basename "$rroll" | sed "s/$RT/$NID/"); mkdir -p "$(dirname "$nroll")"
  F="$rcwd" T="$OLD" A="$RT" B="$NID" perl -ne 's/\Q$ENV{F}\E/$ENV{T}/g; s/\Q$ENV{A}\E/$ENV{B}/g; s/"(model_provider(?:_id)?)":"[^"]*"/"$1":"rehearsal"/g; print if /\n\z/' "$rroll" > "$nroll"
  # Its model provider becomes the local listener too: the real record and rollout name the real provider, which a resume would use.
  ! LC_ALL=C grep -qF -e "$rcwd" -e "$RT" "$nroll" || { echo "THE COPY STILL NAMES THE REAL FOLDER OR THREAD: stopped"; exit 1; }
  [ -z "$(LC_ALL=C grep -o '"model_provider[_id]*":"[^"]*"' "$nroll" | grep -v ':"rehearsal"$')" ] || { echo "THE COPY NAMES ANOTHER MODEL PROVIDER: stopped"; exit 1; }
  sqlite3 "$CH/state_5.sqlite" "update threads set archived = 1 where id = '$sid';" < /dev/null && sqlite3 "$CH/state_5.sqlite" < "$P/row.sql" \
    && sqlite3 "$CH/state_5.sqlite" "update threads set id = '$NID', cwd = '$OLD', rollout_path = '$nroll', model_provider = 'rehearsal' where id = '$RT';" || { echo "COULD NOT COPY THE THREAD RECORD: this proves nothing"; exit 1; }
  [ "$(sqlite3 "$CH/state_5.sqlite" "select count(*) from threads where model_provider <> 'rehearsal';")" = 0 ] || { echo "A THREAD RECORD NAMES ANOTHER MODEL PROVIDER: stopped"; exit 1; }
  sqlite3 "$CH/state_5.sqlite" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null
  printf 'real rollout %s bytes, copy %s bytes; its records: %s\n' "$(stat -f %z "$rroll")" "$(stat -f %z "$nroll")" \
    "$(jq -r '[.type, (.payload.type // "-")] | join(" ")' "$nroll" 2>/dev/null | sort | uniq -c | sort -rn | awk '{printf "%s%s %s %s", s, $1, $2, $3; s=", "}')"
  printf 'the exec-made thread %s, archived; its records: %s\n' "$sid" "$(jq -r '[.type, (.payload.type // "-")] | join(" ")' "$roll" 2>/dev/null | sort | uniq -c | sort -rn | awk '{printf "%s%s %s %s", s, $1, $2, $3; s=", "}')"
  echo "the copy is thread $NID"; sid=$NID roll=$nroll
fi
echo "thread $sid, rollout $(stat -f %z "$roll") bytes; clone inode $ino0 at $head0; worktrees: $(git -C "$OLD" worktree list | wc -l | tr -d ' ') listed, $(git -C "$OLD" worktree list --porcelain | grep -c '^prunable') prunable"
# The copies of the operator's scripts: the seat is rcx, the socket and folders private; checked before anything starts.
cp "$R0/seat-exec.sh" "$R0/Makefile" "$R0/structure-move.sh" "$R0/structure-move-codex.sh" "$P/run/"; cp "$R0/notes/structure-move-codex.txt" "$R0/notes/structure-move-claude.txt" "$P/run/notes/"
# The copy says "rehearsed on" the installed Codex, because this run is that rehearsal; the real script changes only after it passes.
sed -i '' "s/^REHEARSED=.*/REHEARSED=$VERSION/" "$P/run/structure-move-codex.sh"
sed -e "s/^SOCKET=zeo2 HOST_NAME=matormini /SOCKET=$S HOST_NAME=h /" "$R0/rescue.sh" > "$P/run/rescue.sh"
sed -e '/^pin [0-9a-f]\{64\} /d' -e "s/-L zeo2/-L $S/g" "$R0/reseat-lines.sh" > "$P/run/reseat-lines.sh"
chmod +x "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/structure-move.sh" "$P/run/structure-move-codex.sh"
printf 'rcx codex rcx-s %s %s %s %s\n' "$sid" "$OLD" "$NEW" "$ino0" > "$P/run/structure-moves"
[ "$(cat "$P/run/rescue.sh" "$P/run/reseat-lines.sh" "$P/run/structure-move.sh" "$P/run/structure-move-codex.sh" | grep -c zeo2)" = 0 ] && ! grep -q /Volumes "$P/run/structure-moves" \
  && [ "$(grep -c '^SOCKET='"$S"' HOST_NAME=h ' "$P/run/rescue.sh")" = 1 ] || { echo "THE COPY CAN REACH THE ORG OR A REAL FOLDER: stopped before anything started"; exit 1; }
printf '{"seats":[{"seat_id":"rcx","mailbox":"rcx","desired_agent":"codex","desired_host":"h","desired_tmux":{"session":"rcx-s"},"desired_folder":"%s"}]}' "$OLD" > "$P/chart.json"
echo "rcx $sid" > "$P/run/session-pins"; : > "$P/run/folder-moves"
export ZEO_RESCUE_CHART=$P/chart.json ZEO_RESCUE_STATE=$P/state STATE=$P/state ZEO_RESCUE_CODEX=$P/codex ZEO_RESCUE_CODEX_DB=$CH/state_5.sqlite ZEO_RESCUE_SESSIONS=$CH/sessions \
  ZEO_RESCUE_SNAPSHOTS=$CH/shell_snapshots ZEO_RESCUE_CODEX_CONFIG=$CH/config.toml ZEO_RESCUE_KILL=$P/nokill ZEO_RESCUE_PROJECTS=$P/claude-projects ZEO_RESCUE_CLAUDE_JSON=$P/claude.json \
  ZEO_RESCUE_PROOF_TRIES=60 ZEO_RESCUE_PROOF_PAUSE=1
echo '{"projects":{}}' > "$P/claude.json"; mkdir -p "$P/claude-projects"
R() { "$P/run/rescue.sh" "$@"; }; Ln() { "$P/run/reseat-lines.sh" "$@"; }
pane() { "$TM" -L "$S" list-panes -t '=rcx-s' -F "$1"; }
newest() { ls "$P/cap" | sed -n 's/^req\.//p' | sort -n | tail -1; }
echo "== the seat starts in its clone"
R --apply 2>&1 | grep -E '^(RESUME|FIRST SEAT OK|STOPPED|FAILED|UNRESOLVED|rescue:)' | show
perl -e 'select(undef,undef,undef,8)'; pid=$(pane '#{pane_pid}'); printf 'running %s, pid %s, in %s\n' "$(pane '#{pane_current_command}')" "$pid" "$(pane '#{pane_current_path}' | show)"
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
echo "== the lines go in: structure-moves, folder-moves and session-pins as a commit would have them"
echo "rcx $NEW carry" > "$P/run/folder-moves"
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
Ln structure-first rcx 2>&1 | grep -E '^(REFUSED|the Codex)' | head -3 | show
echo "== structure-trust, then structure-first"
cp -p "$CH/config.toml" "$P/config.before"
Ln structure-trust rcx 2>&1 | grep -E '^(NOTHING|ADDED|REFUSED|FAILED)' | show
printf 'the config is the old one with exactly the entry added: %s\n' "$([ "$(diff "$P/config.before" "$CH/config.toml" | grep -c '^>')" = 3 ] && [ "$(diff "$P/config.before" "$CH/config.toml" | grep -c '^<')" = 0 ] && echo yes || echo NO)"
(cd "$P" && "$P/codex" mcp list >/dev/null 2>&1) && echo "Codex reads the new config" || echo "CODEX CANNOT READ THE NEW CONFIG"
# A seat resumed on months of history can be at work for a while after it starts; the batch skips a busy seat, so this waits for idle.
w0=$(date +%s) quiet=0 busy=""; while [ $quiet -lt 3 ] && [ $(($(date +%s) - w0)) -lt 300 ]; do
  if R --reseat --relaunch 2>&1 | grep -q '^WORK rcx'; then quiet=0; [ -n "$busy" ] || busy=$("$TM" -L "$S" capture-pane -p -t '=rcx-s' | grep 'esc to interrupt' | tail -1 | show); else quiet=$((quiet+1)); fi
  perl -e 'select(undef,undef,undef,2)'; done
[ -z "$busy" ] || echo "busy after it started, on its screen: $busy"
echo "idle $(($(date +%s) - w0)) s after the trust step; requests it had sent the model: $(ls "$P/cap" | wc -l | tr -d ' ')"
before=$(newest); b2=$(stat -f %z "$roll"); s=$(perl -MTime::HiRes -e 'print Time::HiRes::time()')
Ln structure-first rcx 2>&1 | grep -E '^(the Codex|the note|codex |RESEAT|MOVE|CARRIED|RESUMED|FIRST SEAT OK|MOVED OK|NOTE|STOPPED|FAILED|UNRESOLVED|RECOVERY|OK|WRONG|check:|rescue:|NOT|REFUSED|BUSY|ALREADY|work:|DAEMON)' | show
e=$(perl -MTime::HiRes -e 'print Time::HiRes::time()'); perl -e 'printf "seconds through the restart: %.1f\n", $ARGV[1]-$ARGV[0]' "$s" "$e"
perl -e 'select(undef,undef,undef,6)'
printf 'running %s, pid %s, a new process: %s, in %s\n' "$(pane '#{pane_current_command}')" "$(pane '#{pane_pid}')" "$([ "$(pane '#{pane_pid}')" != "$pid" ] && echo yes || echo NO)" "$(pane '#{pane_current_path}' | show)"
echo "processes naming the thread:"; ps -axo pid=,command= | grep -F -e "$sid" | grep -v -e grep -e "ps -axo" | cut -c1-150 | show
echo "== what the model would receive after the move"
last=""; for f in "$P"/cap/req.*; do n=${f##*.}; [ "$n" -gt "${before:-0}" ] || continue; if [ -z "$last" ] || [ "$(stat -f %z "$f")" -gt "$(stat -f %z "$last")" ]; then last=$f; fi; done
words=$(awk -F'"' '/^PROOF=/ {print $2}' "$R0/structure-move-codex.sh")
if [ -n "$last" ]; then
  printf 'the note reached it: %s; its proof words: %s; the first turn before the move: %s; the folder in its environment context: %s\n' "$(LC_ALL=C grep -c "your clone was moved whole from $OLD to $NEW" "$last")" "$(LC_ALL=C grep -cF -e "$words" "$last")" \
    "$(LC_ALL=C grep -c "the seat's first turn" "$last")" "$(LC_ALL=C grep -o "<cwd>[^<]*</cwd>" "$last" | tail -1 | show)"
else echo "NO REQUEST AFTER THE MOVE"; fi
echo "== on disk, in git and in Codex's records"
printf 'the same folder at main: %s; HEAD the same: %s; untracked and ignored files with it: %s; the old path holds only main: %s, mode %s\n' "$([ "$(stat -f %i "$NEW")" = "$ino0" ] && echo yes || echo NO)" \
  "$([ "$(git -C "$NEW" rev-parse HEAD)" = "$head0" ] && echo yes || echo NO)" "$([ -f "$NEW/untracked" ] && [ -f "$NEW/ignored/i" ] && echo yes || echo NO)" "$([ "$(ls -A "$OLD")" = main ] && echo yes || echo NO)" "$(stat -f %Lp "$OLD")"
printf 'the linked worktree reaches it: %s; git status works there: %s; the prunable entry left as it was: %s\n' "$([ "$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)" = "$NEW/.git" ] && echo yes || echo NO)" \
  "$(git -C "$WT" status --porcelain >/dev/null 2>&1 && echo yes || echo NO)" "$([ "$(git -C "$NEW" worktree list --porcelain | grep -c '^prunable')" = 1 ] && echo yes || echo NO)"
printf 'rollouts for the thread: %s; the same rollout file: %s; new threads in either folder: %s\n' "$(find "$CH/sessions" -name "*$sid*" | wc -l | tr -d ' ')" "$([ "$(db "select rollout_path from threads where id = '$sid';")" = "$roll" ] && echo yes || echo NO)" \
  "$(db "select count(*) from threads where id <> '$sid' and cwd in ('$OLD', '$NEW');")"
printf "after the restart, in the rollout: the note's words %s, turns in the new folder %s, turns in the old one %s; the thread record's folder: %s\n" "$(tail -c +$((b2+1)) "$roll" | LC_ALL=C grep -cF -e "$words")" \
  "$(tail -c +$((b2+1)) "$roll" | LC_ALL=C grep -c "\"cwd\":\"$NEW\"")" "$(tail -c +$((b2+1)) "$roll" | LC_ALL=C grep -c "\"cwd\":\"$OLD\"")" "$(db "select cwd from threads where id = '$sid';" | show)"
printf 'the daemon stub was asked to kill: %s\n' "$(cat "$P/kills" 2>/dev/null || echo nothing)"
R --check 2>&1 | grep -E '^(OK|WRONG|check:)' | show
echo "== structure-clear, then second runs"
Ln structure-clear rcx 2>&1 | grep -E '^(DELETED|NOTHING|OUT OF ORDER|FAILED|REFUSED)' | show
printf 'the backup gone: %s\n' "$([ -e "$P/state/codex-config.before-rcx" ] && echo NO || echo yes)"
p2=$(pane '#{pane_pid}'); for st in structure-trust structure-first structure-clear; do Ln "$st" rcx 2>&1 | grep -E '^(ALREADY|NOTHING|REFUSED|NOT READY|OUT OF ORDER|RESEAT|NOTE)' | show; done
[ -n "$p2" ] && [ "$(pane '#{pane_pid}')" = "$p2" ] && echo "the same process is still up" || echo "IT WAS RESTARTED AGAIN"
R --reseat --relaunch 2>&1 | grep -E '^(OK|RESEAT|MOVE|UNRESOLVED)' | show
[ "$real_before" = "$(real)" ] && echo "the real Codex config, the rescue state, the daemons and the org's panes are the same as before this ran" || echo "THE REAL SIDE CHANGED while this ran: read why"
