#!/bin/bash
# zeo-rescue: hermetic tests for junk-stub-logs.sh, on a private state folder. It never reads or writes the real one.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P); T=$(mktemp -d "${TMPDIR:-/tmp}/junk.XXXXXX"); T=$(cd "$T" && pwd -P); trap 'rm -rf "$T"' EXIT
fails=0; ok() { echo "ok   $*"; }; bad() { echo "FAIL $*"; fails=$((fails+1)); }
S=$T/state; mkdir -p "$S" "$T/else"; J() { ZEO_RESCUE_STATE=$S "$HERE/junk-stub-logs.sh" "$@" 2>&1; }
row() { printf '%s\t%s\t%s\n' "$1" "$(stat -f %z "$1" 2>/dev/null || echo 0)" "$(/usr/bin/shasum -a 256 "$1" 2>/dev/null | cut -d ' ' -f 1)"; }
mk() { printf '%s\n' "$2" > "$S/$1"; }
mk reseat-20261108-000001.log 'RESUMED zeocreator: stub'; mk reseat-20261108-000002.log 'STOPPED: stub'
mk reseat-20261108-000003.log 'MOVED OK ducktyper-ops: stub'          # its size will be wrong in the list
mk reseat-20261108-000004.log 'RESUMED x: stub'                       # its sha will be wrong in the list
printf 'RESUMED a: real\nline two: stub\n' > "$S/reseat-20261108-000005.log"   # two lines: a real log
mk reseat-20261108-000006.log 'RESUMED real: resumed'                 # one line, not a stub
mk reseat-20261108-000007.log 'STOPPED: stub'; ln -s "$S/reseat-20261108-000007.log" "$S/reseat-20261108-000008.log"
mk notes.log 'X: stub'; printf 'X: stub\n' > "$T/else/reseat-20261108-000009.log"; mk reseat-20261108-000010.log 'GONE: stub'
L=$T/list.tsv; { printf 'path\tsize\tsha256\n'; row "$S/reseat-20261108-000001.log"; row "$S/reseat-20261108-000002.log"
  printf '%s\t%s\t%s\n' "$S/reseat-20261108-000003.log" 999 "$(/usr/bin/shasum -a 256 "$S/reseat-20261108-000003.log" | cut -d ' ' -f 1)"
  printf '%s\t%s\t%064d\n' "$S/reseat-20261108-000004.log" "$(stat -f %z "$S/reseat-20261108-000004.log")" 0
  row "$S/reseat-20261108-000005.log"; row "$S/reseat-20261108-000006.log"; row "$S/reseat-20261108-000008.log"; row "$S/notes.log"
  row "$T/else/reseat-20261108-000009.log"; row "$S/reseat-20261108-000010.log"; } > "$L"; rm "$S/reseat-20261108-000010.log"
before=$(ls -l "$S" | shasum)
out=$(J "$L"); rc=$?
[ $rc -eq 1 ] && [ "$(grep -c '^WOULD DELETE' <<< "$out")" = 2 ] && [ "$before" = "$(ls -l "$S" | shasum)" ] && ok "without --apply it changes nothing and names the two it would delete" || bad "dry: $rc $out"
for want in "000003.log: its size is not 999" "000004.log: its sha256 is not the listed one" "000005.log: its content is not one line" "000006.log: its content is not one line" \
  "000008.log: not an ordinary file" "notes.log: not a reseat log in" "000009.log: not a reseat log in" "000010.log: not an ordinary file"; do
  grep -q "^SKIPPED .*$want" <<< "$out" || bad "skip: $want"; done; [ "$(grep -c '^SKIPPED' <<< "$out")" = 8 ] && ok "it skips, with the reason, a wrong size, a wrong sha, a real log, a link, a file outside, a name not a reseat log, and one gone" || bad "skips: $out"
out=$(J "$L" --apply); rc=$?
[ $rc -eq 1 ] && [ ! -e "$S/reseat-20261108-000001.log" ] && [ ! -e "$S/reseat-20261108-000002.log" ] && [ "$(grep -c '^DELETED' <<< "$out")" = 2 ] && ok "with --apply it deletes exactly the two that read as listed" || bad "apply: $rc $out"
n=0; for f in 3 4 5 6 7; do [ -f "$S/reseat-20261108-00000$f.log" ] && n=$((n+1)); done
[ $n = 5 ] && [ -L "$S/reseat-20261108-000008.log" ] && [ -f "$S/notes.log" ] && [ -f "$T/else/reseat-20261108-000009.log" ] && ok "and leaves every other file, the link and its target" || bad "kept: $n"
r=$(ls "$S"/junk-stub-logs-*.receipt 2>/dev/null | head -1); [ -n "$r" ] && [ "$(grep -c '^DELETED\|^SKIPPED' "$r")" = 10 ] && tail -1 "$r" | grep -q '^junk-stub-logs: deleted 2, skipped 8, of 10 listed' && ok "its receipt has one line per row and the totals" || bad "receipt: $(cat "$r" 2>/dev/null)"
out=$(J "$L" --apply); grep -q '000001.log: not an ordinary file' <<< "$out" && grep -q '^junk-stub-logs: deleted 0' <<< "$out" && ok "a second run deletes nothing" || bad "twice: $out"
G=$T/good.tsv; mk reseat-20261109-000001.log 'STOPPED: stub'; { printf 'path\tsize\tsha256\n'; row "$S/reseat-20261109-000001.log"; } > "$G"
out=$(J "$G" --apply); rc=$?; [ $rc -eq 0 ] && [ ! -e "$S/reseat-20261109-000001.log" ] && ok "a list whose every row reads as listed exits 0" || bad "all good: $rc $out"
printf 'path size sha256\n' > "$T/h.tsv"; out=$(J "$T/h.tsv"); [ $? -eq 2 ] && grep -q '^REFUSED, nothing was done: .* does not start with the header' <<< "$out" && ok "a list with another header is refused" || bad "header: $out"
{ printf 'path\tsize\tsha256\n'; printf 'a\tb\n'; } > "$T/r.tsv"; out=$(J "$T/r.tsv"); [ $? -eq 2 ] && grep -q '^REFUSED, nothing was done: a row of' <<< "$out" && ok "a row that is not three fields is refused" || bad "row: $out"
{ printf 'path\tsize\tsha256\n'; tail -1 "$G"; tail -1 "$G"; } > "$T/d.tsv"; out=$(J "$T/d.tsv"); [ $? -eq 2 ] && grep -q 'is listed twice' <<< "$out" && ok "a file listed twice is refused" || bad "dup: $out"
out=$(J "$G" --force); [ $? -eq 2 ] && grep -q '^usage' <<< "$out" && ok "any other flag is refused" || bad "flag: $out"
[ $fails = 0 ] && echo PASS || { echo "FAILED: $fails"; exit 1; }
