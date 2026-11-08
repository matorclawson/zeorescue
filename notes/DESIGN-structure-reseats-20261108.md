# Design: moving the live seats into the one code structure

**Created:** 2026-11-08 · **Status:** for the Architect's read. Nothing has run on any seat.

On the Architect's order of 8 Nov 22:10Z (threads/ANSWER-zeo-rescue-structure-reseats-2026-11-08.md), under the operator's direction threads/DIRECTION-one-consistent-code-structure-2026-11-08.md. The list is threads/STRUCTURE-INVENTORY-2026-11-08/per-seat-reseat.tsv.

## 1. What I read, 8 Nov 22:15 to 22:30Z (read-only)

Of the 23 rows, 20 are seats and 3 are nested folders. 13 of the seats are Claude and 7 are Codex. Every pane was up, and only zeoapp showed running work.

| seat (tmux) | harness | shape now | to | read |
|---|---|---|---|---|
| zeoarchitect | claude | clone at zeroemployeeorg/zeoarchitect | …/zeoarchitect/main | clean, on main; Go, no venv; only the seat in it; 1 live linked worktree outside (za-ci), 7 prunable. **The first seat.** |
| zeoconnect | claude | clone | …/zeoconnect/main | clean, detached HEAD; .venv and node_modules; 2 live linked worktrees outside |
| zeocore | claude | clone | …/zeocore/main | clean, 1 ahead; four .venv folders; settings.local.json names its own path; 11 linked worktrees outside |
| zeomessenger | claude | clone | …/zeomessenger/main | clean, detached HEAD; Go; its waker runs in the folder as a child of the seat; 11 linked worktrees outside |
| zeocontrolling | claude | clone | …/zeocontrolling/main | clean; Go; its waker is a child of the seat; no linked worktrees |
| zeocouncil | claude | clone | …/zeocouncil/main | **11 uncommitted entries**, and a shell pipeline was running in the folder; settings.local.json names its own path; 11 prunable worktrees |
| zeonewsroom (dt-newsroom-maintainer) | claude | clone at zeroemployeeorg/zeonewsroom | ducktyper-ai/dt-newsroom/main | clean, 1 behind; .venv; 5 prunable worktrees. Its target folder does not exist yet, and the carry makes it. |
| dt-brandedimage-maintainer | codex | clone | …/dt-brandedimage/main | clean; 5 live linked worktrees on ZeoWorkCS |
| rasa (rasa-community-maintainer) | codex | clone | …/rasa-community/main | clean, 343 behind; 1 linked worktree in a recovery folder |
| rasa-bench | codex | clone | …/rasa-community-benchmarks/main | clean; 5 linked worktrees in a recovery folder, 3 prunable |
| zeroemployee (zeo-site-maintainer) | codex | clone | …/zeo-site/main | clean |
| zeoapp | codex | clone | …/zeoapp/main | **busy**: a gate run (python and ssh) in the folder |
| ducktyper-ops | claude | ducktyper-ai/ducktyper-ops, non-git, **moved there 18:29Z** | ducktyper-ai/dt-animationstudio/worktrees/ducktyper-ops | now holds **doorbells**, a git repository the seat made at 18:32, with its waker running in it |
| profrod-ops | claude | zeroemployeeorg/profrod-ops, non-git | profrodai/profrod-site/worktrees/profrod-ops | holds .claude and a profrod-site clone |
| rasa-ops | claude | zeroemployeeorg/rasa-ops, non-git | rasahq/rasa-community/worktrees/rasa-ops | holds .claude and two repositories, fork and resources |
| zeoconnect-ops | claude | zeroemployeeorg/zeoconnect-ops, non-git | zeroemployeeorg/zeoconnect/worktrees/zeoconnect-ops | holds .claude, .cloudflare and **org**, a clone whose waker runs in it |
| zeo-ledger (org-ledger) | claude | linked worktree of /Users/rodbot/code/zeroemployeeorg/org | org-zeroemployeeorg/worktrees/org-ledger | 1 uncommitted entry; 19 ahead |
| architect | claude | linked worktree of the same store | org-zeroemployeeorg/worktrees/architect | 1 uncommitted entry; ssh sessions running in the folder |
| profrod (profrod-site-maintainer) | codex | worktree whose store is another worktree's .git | the same path | not a folder move |
| zeo-rt (zeoruntime-maintainer) | codex | an independent clone inside worktrees/ | the same path | not a folder move |

None of the seat clones has git config naming its own path, and none has a linked worktree inside itself. Nothing on the host names zeoarchitect's path: no launch agent, crontab, bin link, shell profile, zeo config or Codex trust entry does.

## 2. The method

The method is the one built for ducktyper-ops: the seat is never moved while it is live, it restarts once with a note that proves itself, and its project and memory go by one rename. One new thing was needed. A clone that becomes `<repo>/main` has its target inside itself, so no new folder can be made beforehand. The clone itself moves, while the seat is stopped.

**rescue.sh: the carry.** A folder-moves line `SEAT /new carry` (rescue.sh header; code in `carry_ready` and `carry_folder`).
- **The plan reads only.** It refuses unless:
  - the folder is an ordinary clone with its own .git, not a linked worktree;
  - the new path is free, and is either one level inside the clone or in a folder outside any repository (at most one new folder);
  - the new path is on the same volume, so the move is a rename, never a copy;
  - no linked worktree lies inside the clone, and its git config does not name its own path;
  - the trust entry for the new path exists (Claude or Codex);
  - no project is under the new key;
  - every process working in the clone is the seat's own process tree.

  A seat that is down is refused, so the stop is always the run's own. `--check` says `WRONG …: not yet carried to …; the carry is ready`.
- **The apply.** The seat is stopped, in the clone's parent folder. Then:
  - the inode is checked against the plan;
  - the run waits until no process works in the clone;
  - the clone is renamed. For `<repo>/main` this is `<repo>` → `<repo>.carry-SEAT` → mkdir `<repo>` (755) → `<repo>/main`. Each failure puts the clone back where it was;
  - the run checks that the clone at the new path has the same inode and the same HEAD;
  - `git worktree repair` runs on each live linked worktree outside, and each one must then reach the new .git;
  - then come the project's rename, the start in the new folder and the proofs that already exist.

  If a worktree still doesn't reach the clone, the seat runs, and the run fails out loud.
- **Once carried, it is an ordinary move.** If the new path is there and is the carried clone, the line is an ordinary folder move, so a rerun after a failed start simply starts the seat there. A new path that is there but isn't such a clone is refused.

**The generic step: structure-move.sh SEAT trust|first|clear**, which reseat-lines.sh pins and runs as `structure-trust|structure-first|structure-clear SEAT`.
- **It reads one pinned table, structure-moves.** Each row is SEAT HARNESS TMUX-SESSION SESSION-ID FROM TO FROM-INODE. A row is added only after its seat is read, so the row records that read.
- **Each run moves exactly the one seat named.** That seat's row must agree with folder-moves (`SEAT TO carry`, one line) and with session-pins.
- **It knows exactly two states.** "Before" means the clone at FROM with the row's inode and nothing at TO. "After" means that same folder at TO. Every step refuses any other state.
- **trust** works as claude-trust did: under Claude's lock, with a mode-600 backup and the hash guard, before the folder exists.
- **first**, in order:
  - the version check (2.1.319 rehearsed);
  - it refuses if the proof words are already in the transcript;
  - it refuses if the seat is busy;
  - the plan must say `RESEAT SEAT: claude SID … in TSESS` and `MOVE SEAT: from FROM to TO`;
  - it renders the note from the pinned template, with the four paths, into the state folder (mode 700);
  - the reseat and check run;
  - the note's words must reach the new-key transcript after the byte the run started from;
  - it marks itself done, so a second run says ALREADY DONE.
- **clear** works only after the move, and only once the seat checks right.
- **Claude only, for now.** Codex rows are refused until a Codex carry has its own rehearsal.

**Per seat**, the commit adds three things: its row, its folder-moves line, and its pin if it is missing. Then its lines come to you. Each seat has two lines:
- line 1 is `structure-trust` and `structure-first`, chained;
- line 2 is `structure-clear`, after you accept the seat's reply.

A clone carried to `<repo>/main` leaves only `<repo>/` behind, holding main/. A clone carried elsewhere leaves nothing. So no carry has an "old folder" step.

## 3. The first seat: zeoarchitect

It is idle, clean and on main. It's a Claude seat on 2.1.318, and the restart runs 2.1.319 as rehearsed. It is the common shape: 12 rows are a clone becoming `<repo>/main`. It is Go with no virtualenv, only the seat works in it, and nothing else on the host names its path. Its one live linked worktree outside the clone tests the repair. Its session pin (766f4d22) is already in session-pins.

## 4. Proof

- **Tests:** `make test` passes, with 383 checks in rescue-test.sh (319 before this change) and tmux-test PASS.
  - The carry has 31 tests: every refusal in the plan and the apply, a carry into `<repo>/main` and one into another folder, the repair and its failure, --check before and after, and a second run.
  - structure-move.sh has 30, run on a stub rescue.sh. The 3 new pinned files are in the pin-change tests.
- **Mutations:** 34 of the new guards were broken one at a time on a copy, and each one was caught. Two checks turned out to be implied by others, so I removed them: the git-dir half of "ordinary clone" (the common-dir half holds the same condition), and a line count in structure-move.sh (its exact-match comparison already refuses two lines). One guard, a placeholder left in the note, had no test. It has one now.
- **Rehearsal** (rehearsal/structure-move.sh): a copy of zeoarchitect's real transcript (90.8 MB) and its 5 memory files, under the key of a clone of the same shape, on a private socket, folder and config.
  - The seat started on 2.1.318.
  - structure-first first refused the version, and refused before trust.
  - structure-trust ran.
  - structure-first on 2.1.319 printed CARRIED, MOVED OK, check ok 1 and NOTE DELIVERED, in 6.1 s. The harness then told the seat its working directory was main.
  - It is the same inode and the same HEAD, and the untracked and ignored files came along. The old path holds only main/ (755).
  - The linked worktree reaches the new .git and git status works there. The prunable entry was left as it was.
  - The note and the memory under the new key reached the model, and the old key didn't come back.
  - structure-clear ran, and second runs said ALREADY DONE and NOTHING TO ADD or DELETE.
  - The real seat, its clone, za-ci's link, its memory, ~/.claude.json and the org's panes were unchanged.
- **Real state, read-only:** the plan for zeoarchitect today stops only at the missing trust entry, which line 1's first step adds. Every structural guard passes.

## 5. For you to rule, before the seats they touch

1. **ducktyper-ops moves twice.** You accepted ducktyper-ai/ducktyper-ops at 18:15, and the move ran at 18:29 and 18:39. The list now names dt-animationstudio/worktrees/ducktyper-ops. It also holds doorbells, made at 18:32 and live, which the list sends to ducktyper-ai/doorbells/worktrees/doorbells. doorbells' owner reads it first.
2. **What `<repo>/worktrees/<seat>` is for an ops seat**, which has no repository of its own. A plain folder there is not a linked worktree, so the reaper would flag it. A linked worktree would put the seat inside another seat's repository, and rescue.sh refuses any Claude move into a worktree, because none is proved. I propose a plain folder, entered in the register, and I ask which you want.
3. **Order.** rasa-ops and zeoconnect-ops go into rasa-community and zeoconnect, which are still clones. Each can go only after its maintainer's carry. So in step 2 of your order, only ducktyper-ops and profrod-ops can go before the maintainers.
4. **The ops folders are not empty.** profrod-ops holds .claude and a profrod-site clone. rasa-ops holds .claude, fork and resources. zeoconnect-ops holds .claude, .cloudflare and org, a live clone. Each owner reads its own first, as you said at 18:15. Their .claude folders hold project settings that must move with the seat.
5. **The org store.** The list makes zeoconnect-ops/org into org-zeroemployeeorg/main. But org-ledger and org-architect are linked worktrees of /Users/rodbot/code/zeroemployeeorg/org. Which store becomes main? If it is the zeoconnect-ops clone, those two must be re-homed, which is a git change, not a move. They also need a proved Claude move into a worktree, a probe and rehearsal of their own. They go last anyway.
6. **Not folder moves.** profrod (its worktree's store is another worktree) and zeo-rt (an independent clone that must become a linked worktree of zeoruntime/main) keep their paths. Each is a change to a git store. I propose that each gets its own design later.
7. **Virtualenvs.** zeoconnect, zeocore (four of them) and zeonewsroom have .venv folders. Their scripts' first lines and their editable installs name the old path, so they break after a carry. I propose that the note tells the seat to rebuild its own (it is derived content). Or the carry refuses while a .venv is there. Which do you want?
8. **The repair writes one line into other seats' worktrees.** Some live linked worktrees sit in other seats' areas, such as zeomessenger-worktrees with the Architect's PR worktrees. For those, `git worktree repair` rewrites the one-line .git file, and nothing else. Without it they stop working. Do you confirm?
9. **Two more moving seats that the list leaves out.** The rule renames dt-creator to zeocreator and dt-broadcastingstudio to zeobroadcastingstudio. Their seats, zeocreator and zbs, work in main/ under those folders, so a rename moves them too. Which organization folder does each go in? The gold for zeobroadcastingstudio is rodriveracom.
10. **Codex.** Seven seats are Codex. rescue.sh's carry handles Codex (its plan tests pass), but structure-move.sh refuses Codex until a Codex carry is rehearsed. That rehearsal comes before the first Codex line.
11. **zeorescue itself.** It runs outside tmux, in this folder. The operator stops it, one line carries the clone, and the operator starts it again with `claude --resume` in zeorescue/main. Every later line then works in zeorescue/main. It has its own design, second to last.
