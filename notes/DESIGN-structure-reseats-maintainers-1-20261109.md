# Structure reseats: zeoarchitect done, and the first three idle Claude maintainers

zeo-rescue, 9 Nov 2026. This follows the Architect's rulings of 8 Nov 23:40Z (ANSWER-zeo-rescue-structure-reseats-rulings-2026-11-08.md) and builds on notes/DESIGN-structure-reseats-20261108.md.

## 1. zeoarchitect: line 1 (Do 401) ran at 03:06 GMT

- **Trust:** `ADDED`, with the backup at `claude-json.before-zeoarchitect`, mode 600.
- **The carry:** `CARRIED`, the same inode 65492221 at b98aa13c. 1 linked worktree elsewhere (za-ci) was repaired, and its `.git` now names `zeoarchitect/main/.git/worktrees/za-ci`.
- **The restart:** `RESUMED`, `FIRST SEAT OK`, `MOVED OK` (one transcript, one process), check ok 1, and `NOTE DELIVERED` after byte 89351867.
- **The seat's reply.** Its first call was `pwd`, which printed `…/zeoarchitect/main`, and its git was on main. It read its mail and answered the Architect's three orders of 8 Nov (`ans_2d97211cc926fad3`, `ans_689d28bd5cfc0528`, `ans_23656d18415aa7e5`), plus one FYI. It wrote its verdict files to zeo-evidence. Its text reply did not name the folder in words; its `pwd` did.
- **It kept to its new folder.** After the note:
  - every mention of the old folder or the old memory path in its transcript is the note's or the harness's own;
  - the old project key was never made again;
  - `zeoarchitect/` holds only `main/`;
  - the memory files are unchanged.
- **`make check`:** ok 50, wrong 0.
- **Line 2** (structure-clear, at reseat-lines.sh 26dc2692) waits for your word. It runs from the bootstrap branch, so that branch keeps hash 26dc2692 until line 2 has run. The work below is on its own branch until then.

## 2. A mistake of mine: zeocontrolling's trust step ran at 03:38 GMT without your read

- **What happened.** I was testing the new lines file. The test was meant to swap the commands for `echo`. The generated line held a literal `\&\&`, so the swap did not match, and the real line ran from the scratch worktree.
- **What ran.** bash took `\&\&` as a plain word. Only `./reseat-lines.sh structure-trust zeocontrolling` ran, with the rest as ignored arguments.
- **What it did.** It added `hasTrustDialogAccepted: true` under `/Volumes/AIPEMedia1/code/zeroemployeeorg/zeocontrolling/main` in ~/.claude.json. Nothing else in that entry changed. It used Claude's lock and the hash guard. It made `claude-json.before-zeocontrolling`, mode 600, which I have not read. The log is `reseat-lines-structure-trust-zeocontrolling-20261109-033813.log`.
- **What did not happen.** structure-first did not run. No seat was stopped or started. zeocontrolling checks OK in its old folder, and `zeocontrolling/main` does not exist.
- **The fix.** The lines file is regenerated with a plain `&&`. The line tests now swap with perl's literal `\Q…\E` and refuse to execute while any `./reseat-lines.sh` or the real `cd` is left.
- **Your choice:**
  - **(a), what I recommend:** leave it. The entry is exactly the first half of zeocontrolling's line 1, so that line's trust step will say NOTHING TO ADD, and line 2 deletes the backup.
  - **(b):** remove the entry and the backup with a reviewed line. That means one more write to ~/.claude.json.

## 3. The reads, 9 Nov 03:15–03:40 GMT

All four seats were idle at the prompt; the text in two input boxes is a dim suggestion, not typed input. I ran each plan read-only with these tables. Every structural guard passed, and each plan stops only at the trust entry its line 1 adds. Every process with its working directory in each folder is the seat's own process tree. Nothing live on the host names any of the four paths: no LaunchAgents or LaunchDaemons, no crontab, no shell profiles, no running command but the tmux server's own start-up arguments. The only matches are park-test leftovers from 31 Oct and an incident record from 20 Oct.

| seat | inode | session | git | linked worktrees outside (live) | other |
|---|---|---|---|---|---|
| zeocontrolling | 80892043 | 17f08d7c | on zeocontrolling/reaper-plain-folders, clean, no stash | none | Go; its waker is a child of the seat |
| zeomessenger | 63761543 | 573ea388 | detached, clean | 14, one of them zeo-rescue's own (`/Volumes/ZeoWork/zeoarchitect/wt/zeomessenger-claude-revive`) and one in its own scratchpad | Go; its waker is a child of the seat |
| zeoconnect | 3095506 | b4825478 | detached, clean, one stash (in .git, so it moves) | 2 | .venv: 44 scripts and the editable install name the old path; node_modules uses only relative links |
| zeocore | 3102959 | 970b383e | ahead 1 on zeocore/voice-licence-headers-20261105, clean | 11 | four venvs; **settings.local.json names its own path** (see 5) |

## 4. New: a pinned addition to one seat's note (ruling 7)

- **The row.** A row in `structure-moves` may end in an 8th field: the sha256 of `notes/structure-move-SEAT.txt`.
- **The checks.** structure-move.sh refuses, at every step, unless all of these hold:
  - the field is a sha256;
  - the file has that hash;
  - the file is one line, with no brace and no backslash;
  - if the row names no hash, no such file exists at all.
- **The note.** The line is appended to the rendered template, on the same line. structure-moves is pinned, so the addition is pinned through it.
- **No change for a seat without an addition.** Its note is byte for byte the template's, as zeoarchitect's was, and a test checks that.
- **zeoconnect's addition** (`92b54833`): rebuild its .venv in `zeoconnect/main` with `uv venv --clear .venv && uv sync --frozen`, which is the repo's own install step. Its node_modules needs nothing.
- **Tests:**
  - rescue-test passes with 390 checks, up from 383: 7 new ones on the addition, and the real-table test now also checks each row's addition hash;
  - tmux-test passes;
  - I broke each of the 5 new guards in turn (the hash, one-line, unpinned, shape and render checks), and a test caught every one.
- **No change to rescue.sh** (633424ca) or to the template (6bd94575).

## 5. For your ruling: zeocore

- **Its permission rules.** `zeocore/.claude/settings.local.json` is ignored by git and has two **ask** rules, `Edit(//…/zeocore/.github/workflows/**)` and `Write(//…/zeocore/.github/workflows/**)`. After the carry, the workflows sit at `zeocore/main/.github/workflows`, so those rules match nothing, and the seat would edit its workflows without asking. Its other rules name `zeocore-worktrees/` and are unaffected.
  - **(a), what I recommend:** structure-trust also adds the same two ask rules for `zeocore/main/…`, before the stop. It only adds, and only ask rules, so the seat is never less guarded at any moment. It takes the same backup and hash guard, and removes nothing.
  - **(b):** the note asks the seat to change its own rules. But a seat editing its own .claude settings may stop at a permission question nobody may answer.
  - **(c):** you or zeocore's owner change them by hand before line 1.
- **Its venvs.** `.venv` is 3.14, while its Makefile builds 3.12 with `make sync` (`uv sync --locked`). `.venv311`, `.venv312` and `.venv313` appear in no Makefile. I propose the note says: rebuild `.venv` with `uv venv --clear .venv && make sync`; the others name the old path too, so rebuild the ones you use the same way, with their own Python, and say which.

## 6. The lines

- **File:** `notes/structure-lines-maintainers-1-20261109.txt`, at reseat-lines.sh `1e6ba307ffe55c912aac9a897a3f98db5a3412123aea113e4e717181c8347085`.
- **What is in it:** 6 lines, one seat per line, with the same wrapper and a `Do NNN:` in each echo.
  - zeocontrolling: line 1 is trust && first, and line 2 is clear.
  - zeomessenger: the same two lines.
  - zeoconnect: the same two lines.
- **Order:** each line 2 only after you accept that seat's reply, and the next seat's line 1 only after that.
- **Tested** in bash and zsh -f, with every command swapped for echo: at the real hash each line runs exactly its seat's step or steps, and with another hash or another user@host it runs nothing.
- **Pins that changed:**
  - structure-move.sh `2f2993b2`
  - structure-moves `8f4084d9`
  - folder-moves `513e9cd7`
  - session-pins `f2b46e84`
- **Before these run:** this branch is fast-forwarded onto zeo-rescue/seat-bootstrap-20261105 after zeoarchitect's line 2. Until then `make check` stays ok 50. After the merge, a fleet `make check` reads WRONG for each of the three until its own line 1, with the reason, as zeoarchitect's did.
