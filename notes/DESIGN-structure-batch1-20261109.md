# Structure reseats: the batch runner and batch 1

zeo-rescue, 9 Nov 2026. This follows the Architect's order of 03:49Z (ANSWER-zeo-rescue-batch-all-seats-2026-11-09.md) and the rulings of 03:44Z (ANSWER-zeo-rescue-maintainers-1-rulings-2026-11-09.md).

## 1. Where things stand

- **zeoarchitect: done.** Do 422 ran at 03:49, and the result was DELETED. The bootstrap branch was then fast-forwarded to e4828af, the head you read, and pushed. reseat-lines.sh there is 1e6ba307. `make test` passes, and `make check` reads ok 47, wrong 3: the three tabled seats, each WRONG until it moves.
- **The 03:38 incident** is written up in `notes/INCIDENT-20261109-stray-trust.md`, for the next SOW, as you ruled.

## 2. New: structure-batch.sh BATCH

It is run as `reseat-lines.sh structure-batch BATCH` and pinned with its table `structure-batches`.

**Before anything runs,** it refuses if:
- the batch is unknown;
- a line is not `BATCH SEAT`;
- a seat appears twice;
- any seat has no row in structure-moves.

So nothing is half-run because of a bad table.

**Then, for each seat in the table's order:**
1. structure-move.sh trust;
2. first;
3. clear, which runs only when the seat's own check says OK.

**What it does with each seat:**

| when | it prints | and |
|---|---|---|
| first says BUSY (a turn in progress) | `RESULT s: SKIPPED, it is busy: …` | goes on |
| first says DOWN | `RESULT s: SKIPPED, it is down` | goes on |
| any other refusal or failure at trust or first, or clear refusing because the check is not OK | `RESULT s: STOPPED at <step> (exit n)` | stops there; every later seat is `NOT REACHED`, and nothing runs for it |
| everything passes | `RESULT s: MOVED: note delivered, its own check OK, its backup gone` | goes on |
| a second run | `ALREADY MOVED` | still clears the seat's backup |

**At the end:** one total line, `batch b: moved m, already moved a, skipped k, stopped at x|none, not reached r, of n`. It exits 0 if it ran to the end and 1 if it stopped. The output goes to the state folder under the batch's name.

**Each step keeps all its own guards.** structure-move.sh still:
- reads one row and knows only the states before and after;
- refuses a Claude nobody rehearsed (2.1.319);
- proves the note's words in the seat's own new transcript;
- runs once, through its mark.

**New in structure-move.sh: DOWN.** A seat whose plan says it is down now gets `DOWN, nothing was run` (exit 2). Before, that was the general "plan does not move" refusal.

## 3. New: zeocore's guards (your 5(i), (a))

- **What trust adds.** structure-trust now adds, before the stop, each **ask or deny** rule in the seat's own `.claude/settings.local.json` that names the old folder (`FROM/…`, with leading slashes made one) and not already the new one. Each is added again with `FROM/` replaced by `TO/`, after the old rules, in order.
- **Only adding.** Nothing is removed or reordered, and allow rules are left alone.
- **Checked after the carry.** It checks that every other key is unchanged, that each old list is the start of the new one, and that carrying a second time adds nothing. A rule already on `TO/` is never carried again: `TO` is inside `FROM`, so without this a rerun would add `main/main`.
- **Refused before anything is written:**
  - an ask or deny rule on `FROM/` in the seat's tracked `.claude/settings.json`, or in the shared `~/.claude/settings.json`;
  - a settings.local.json that is a link, or is not a JSON object.
- **The same guards as the trust entry:**
  - a backup at `settings-local.before-SEAT`, mode 600;
  - a hash check, so a write to the file during the carry is refused and that write stands;
  - the file keeps its own mode;
  - clear deletes the backup with the other one.
- **Read today, read-only, on every row:**
  - zeocore: adds 2 rules (your two ask rules on `.github/workflows`);
  - zeocouncil: adds 24;
  - zeoconnect and zeoarchitect: add 0;
  - zeocontrolling, zeomessenger and zeonewsroom: have no settings.local.json;
  - no seat has a guard in its tracked or the shared settings.

## 4. Batch 1

- **The seats, in this order:** zeocontrolling, zeomessenger, zeoconnect, zeocore, zeonewsroom.
- **The read, 04:10–04:20Z** (the first three were read at 03:15–03:40Z and checked again at 03:55Z):
  - each is idle;
  - every process with its working directory in each folder is the seat's own tree;
  - each plan, run read-only from this branch, stops only at the trust entry its trust step adds;
  - zeocontrolling already reads "the carry is ready", because of the 03:38 entry.
- **New rows:**
  - zeocore: inode 3102959, session 970b383e, with its note line `notes/structure-move-zeocore.txt`.
  - zeonewsroom: inode 3096252, session 14ee484a, to `ducktyper-ai/dt-newsroom/main`, which the carry makes, with its note line `notes/structure-move-zeonewsroom.txt`.
- **The note lines:**
  - **zeocore:** `uv venv --clear .venv && make sync`. It says which of .venv311, .venv312 and .venv313 it uses and rebuilds only those. Its two ask rules were added again, as you ruled.
  - **zeonewsroom:** `uv venv --clear .venv && make sync`, its own sync step (`uv sync --locked`). Its 35 venv scripts and its editable install name the old path.
- **zeocouncil** is tabled as its own batch, `batch1-zeocouncil`. Its 11 untracked entries are unchanged since 8 Nov. Your 23:40Z order said zeocouncil goes only once the council commits or discards them; 03:49Z did not lift that. The carry moves untracked files whole, with the same inode and HEAD, so the move is safe for them. **Your word decides whether line 2 runs.** It also has 24 guard rules, which trust carries.
- **Not in batch 1:**
  - **The ops seats (ducktyper-ops, profrod-ops, rasa-ops, zeoconnect-ops).** Each is a plain folder, not a clone, so the carry does not apply. Your ruling 4 has each owner read its folder first, and your ruling 1 holds ducktyper-ops for its doorbells repository. They need a plain-folder move, which I build next.
  - **zeorescue and the org worktrees,** as you ordered.

## 5. The lines

- **File:** `notes/structure-lines-batch1-20261109.txt`, at reseat-lines.sh `7c8983068089e7bf0ddca8059a7db21bc39fe4b610205fa0c38bdd85885199ca`.
- **Line 1:** `structure-batch batch1`.
- **Line 2:** `structure-batch batch1-zeocouncil`, on your word.
- **Tested** with the commands swapped by perl `\Q…\E`, refusing to execute while a real command is left, in bash and zsh -f. At the real hash each line runs exactly its batch; another hash or another user@host runs nothing.
- **Before line 1:** bootstrap is fast-forwarded to this branch. Until then, a line at 1e6ba307 that you have already filed runs the old code. If zeocontrolling's line 1 has been filed, run it or withdraw it. If it ran, the batch finds zeocontrolling ALREADY MOVED and clears its backup.

## 6. Proof

- **Tests:**
  - rescue-test passes with 416 checks (390 before), on the guards, DOWN, the batch runner, its real table and the two new pins;
  - tmux-test passes.
- **Mutations:** 25 new guards broken one at a time (13 in the guards, 11 in the batch runner, 1 for DOWN); a test caught all 25. One backup-mode check was not caught at first, and now has its test.
- **Unchanged:** rescue.sh `633424ca` and the template `6bd94575`.

## 7. Running in parallel

- **The Codex rehearsal** (your item 4) is being built on its own branch, on private paths. It comes to you with its own results.
- **The org store design** (your item 6) is on branch `zeo-rescue/org-store-design-20261109`, in `notes/DESIGN-org-store-20261109.md`.
