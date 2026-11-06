#!/bin/bash
# The operator's one change to ~/.zshenv, so an inactive seat's gh stays off in tool shells. That file runs in every zsh of every seat,
# so this changes it only if it is exactly the file the Architect read, tries the new text in a private copy first, and swaps it in whole.
# A running zsh reads the old file or the new one, never half of one. It needs bash only, so it works even if a change broke zsh.
#
#   zshenv-lines.sh verify     says which file is there; changes nothing
#   zshenv-lines.sh apply      changes the two lines, keeping a backup; puts the file back if a shell then disagrees
#   zshenv-lines.sh rollback   restores the backup, only if the file is exactly what apply left
set -uo pipefail
WANT=rodbot@Mac-mini
OLD1='export GH_CONFIG_DIR="$HOME/.config/gh-matorclawson"'
OLD2='unset GH_TOKEN GITHUB_TOKEN'
NEW1='export GH_CONFIG_DIR="${GH_CONFIG_DIR:-$HOME/.config/gh-matorclawson}"'
NEW2='[ "${GH_TOKEN:-}" = zeo-seat-disabled ] || unset GH_TOKEN; unset GITHUB_TOKEN'
OLD_SHA=f519538e482e131efc38b8ed54636d3e435f2d9fa3ad78e15ecad90c9ad44eeb
NEW_SHA=d33b59306ff3c3694ee161990a9d8fc611e13ae9b2b78e8e5f31cf783c62f8ca
F=${ZEO_RESCUE_ZSHENV:-$HOME/.zshenv}
STATE=${ZEO_RESCUE_STATE:-$HOME/.local/state/zeo-rescue}
BACKUP=$STATE/zshenv.before-20261106
step=${1:-}
case "$step" in verify|apply|rollback) ;; *) echo "usage: zshenv-lines.sh verify|apply|rollback; nothing was changed"; exit 2;; esac
place="$(id -un)@$(hostname -s)"
[ "$place" = "$WANT" ] || { echo "WRONG PLACE, nothing was changed: you are $place. Open the rodbot terminal on the Mac mini."; exit 2; }
sha() { /usr/bin/shasum -a 256 "$1" 2>/dev/null | /usr/bin/cut -d " " -f 1; }
ask() { # ask DIR FLAG NAME=VALUE...: what a shell started from the .zshenv in DIR ends up with. It reports whether a token is set, never its value.
  local d=$1 f=$2; shift 2
  (cd / && /usr/bin/env -i HOME="$HOME" ZDOTDIR="$d" PATH=/usr/bin:/bin "$@" /bin/zsh "$f" 'print -r -- "${GH_CONFIG_DIR##*/}|${GH_TOKEN:+token}|${GIT_AUTHOR_EMAIL:+author}"' 2>/dev/null | tail -1)
}
right() { # right DIR: the four kinds of shell, in both kinds of startup, get what this change is for
  local d=$1 f
  for f in -c -lc; do
    [ "$(ask "$d" "$f" GH_TOKEN=zeo-seat-disabled GH_CONFIG_DIR="$HOME/.config/zeo-tmux-seats/disabled" ZEO_TMUX_SEAT=inactive ZEO_TMUX_ACCOUNT=none)" = "disabled|token|" ] || { echo "an inactive seat's gh is not off ($f)"; return 1; }
    [ "$(ask "$d" "$f" GH_CONFIG_DIR="$HOME/.config/gh-master" ZEO_TMUX_SEAT=master ZEO_TMUX_ACCOUNT=matorclawson)" = "gh-master||author" ] || { echo "a master seat lost its gh or its author ($f)"; return 1; }
    [ "$(ask "$d" "$f")" = "gh-matorclawson||" ] || { echo "a shell with no seat changed ($f)"; return 1; }
    [ "$(ask "$d" "$f" GH_TOKEN=not-the-sentinel)" = "gh-matorclawson||" ] || { echo "a real token would survive ($f)"; return 1; }
  done
}
now=$(sha "$F")
case "$step" in
  verify)
    case "$now" in
      "$OLD_SHA") echo "ORIGINAL: $F is the file the Architect read; nothing was changed";;
      "$NEW_SHA") echo "CHANGED: $F has the two new lines; nothing was changed";;
      *) echo "UNKNOWN: $F is ${now:-missing}, neither file the Architect read; nothing was changed"; exit 1;;
    esac;;
  apply)
    [ ! -L "$F" ] && [ -f "$F" ] || { echo "NOT A PLAIN FILE, nothing was changed: $F"; exit 2; }
    [ "$now" != "$NEW_SHA" ] || { echo "ALREADY CHANGED, nothing was changed: $F has the two new lines"; exit 0; }
    [ "$now" = "$OLD_SHA" ] || { echo "HASH MISMATCH, nothing was changed: $F is ${now:-missing}, not the file the Architect read"; exit 2; }
    [ "$(/usr/bin/grep -cxF -- "$OLD1" "$F")" = 1 ] && [ "$(/usr/bin/grep -cxF -- "$OLD2" "$F")" = 1 ] || { echo "LINES NOT FOUND, nothing was changed: each must appear exactly once in $F"; exit 2; }
    mkdir -p "$STATE" || { echo "FAILED, nothing was changed: cannot use $STATE"; exit 1; }
    if [ -e "$BACKUP" ] && [ "$(sha "$BACKUP")" != "$OLD_SHA" ]; then echo "BACKUP IN THE WAY, nothing was changed: $BACKUP is not the original"; exit 2; fi
    cp -p "$F" "$BACKUP" && [ "$(sha "$BACKUP")" = "$OLD_SHA" ] || { echo "FAILED, nothing was changed: the backup did not verify"; exit 1; }
    d=$(mktemp -d "$(dirname "$F")/.zshenv-trial.XXXXXX") || { echo "FAILED, nothing was changed: no private copy"; exit 1; }
    trap 'rm -f "$d/.zshenv"; rmdir "$d" 2>/dev/null' EXIT
    OLD1=$OLD1 OLD2=$OLD2 NEW1=$NEW1 NEW2=$NEW2 awk '$0 == ENVIRON["OLD1"] {print ENVIRON["NEW1"]; next} $0 == ENVIRON["OLD2"] {print ENVIRON["NEW2"]; next} {print}' "$F" > "$d/.zshenv"
    chmod "$(stat -f %Lp "$F")" "$d/.zshenv"
    [ "$(sha "$d/.zshenv")" = "$NEW_SHA" ] || { echo "HASH MISMATCH, nothing was changed: the new text is not what the Architect read"; exit 2; }
    why=$(right "$d") || { echo "REFUSED, nothing was changed: on the private copy, $why"; exit 1; }
    mv -f "$d/.zshenv" "$F" || { echo "FAILED, nothing was changed: could not swap the file"; exit 1; }
    if ! why=$(right "$(dirname "$F")"); then
      cp -p "$BACKUP" "$F.zeo-back" && mv -f "$F.zeo-back" "$F"
      echo "PUT BACK: installed, $why. $F is $(sha "$F"), which should be $OLD_SHA."; exit 1
    fi
    echo "APPLIED: $F changed, backup at $BACKUP. Tell zeo-rescue: done.";;
  rollback)
    [ "$now" != "$OLD_SHA" ] || { echo "ALREADY ORIGINAL, nothing was changed"; exit 0; }
    [ "$now" = "$NEW_SHA" ] || { echo "HASH MISMATCH, nothing was changed: $F is ${now:-missing}, not what apply left. Someone changed it since; bring this to zeo-rescue."; exit 2; }
    [ "$(sha "$BACKUP")" = "$OLD_SHA" ] || { echo "NO GOOD BACKUP, nothing was changed: $BACKUP"; exit 2; }
    cp -p "$BACKUP" "$F.zeo-back" && mv -f "$F.zeo-back" "$F" || { echo "FAILED: could not restore $F"; exit 1; }
    [ "$(sha "$F")" = "$OLD_SHA" ] || { echo "FAILED: $F is $(sha "$F") after the restore"; exit 1; }
    echo "ROLLED BACK: $F is the original again. Tell zeo-rescue: done.";;
esac
