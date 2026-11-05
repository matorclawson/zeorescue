# Integration of the council return

Return: `zeorescue-council-return-20261105.zip`, sha256 `529c5b54...d409fd428`, on baseline `af45115`.
Verified on the Mac mini on 2026-11-05. Nothing was installed, no seat was started or stopped, and the Architect has not read this.

## Evidence

| Council claim | Independently verified result | Evidence | Required correction |
|---|---|---|---|
| Source and patches match | **True.** 34 hashes match; the cumulative patch reproduces `source/` exactly | `shasum -c`, `git apply`, `diff -r` | None |
| 81 offline checks pass | **Partly.** 33 + 30 reproduced on this Mac. The 18 are Python, forbidden on this host, so they were ported and all pass, plus one more | `guard-test.sh` | Ported, Python removed |
| "Real SQLite WAL fixture" | **Overstated.** The CLI was a Python shim, so `/usr/bin/sqlite3` was never run. The behaviour is true when tested with the real CLI | `guard-test.sh` 1 | Ported to the real CLI |
| Both rescuers work from a clean environment | **False on this host.** Bash 3.2 with `set -u`: `config[@]: unbound variable`. Neither started unless an override was set, and every test set one | `rescuer-exec.sh`, `agent.sh` | Fixed |
| "Exact mapping" | **Sound where it can see, and stricter than the host allows.** History reader passed 48 of 48 real seats, under 0.5s each. A real capture gave 1 record and 49 issues, because the seats are wrong | Real capture and `get` | Added the native Claude map |
| Claude history holder check | **Cannot fire.** Claude holds no file open on a transcript (0 on a live seat). The test passes only on a stub | `lsof` on a live seat | Docs corrected; `holds()` now reads the pid file |
| Automatic capture | **Implemented, not running.** Polling only, nothing installed, and no lifecycle hook | `launchctl print`: absent | Operator's to install |
| Stale locks handled | **Refused, so fatal.** A capture killed by the teardown stops all later ones, with no alarm | Reading, then test | Fixed: dead owner taken over |
| Failures visible | **No.** `status` never checked age, so a dead collector looked healthy | Reading, then test | Added `health`, wired into doctor |
| Duplicates are blocked | **Overbroad.** One pair blocked all 50 seats, and after an outage nothing could clear it | Reading, then test | Fixed: those seats only |
| Chart problems are safe | **Two faults.** One bad row stopped all capture, and a partial chart erased records within two captures | Tests | Fixed |
| "Verified seat" | **Means little.** It proves the environment at start only, so a seat at a trust prompt can pass. Not git, not health | `prove_*` | Kept; wording corrected here |
| "Clean environment" | **True for the process.** `env -i` is real, but `~/.zshrc` runs after it and hooks load from HOME, so it does not mean an isolated seat | `seat-exec.sh` | Stated |
| Ordinary recovery does not stop live seats | **True.** Test fails if the guard is removed | Mutation check | None |
| Live repair is separate and works | **False as delivered.** On the real org: `unresolved 49`, and `--apply` refuses. It could not repair the seats it was reviewed for | Real plan | Added `--seed`: `unresolved 0` |

## Tests that only mirror the implementation

- `test_no_automatic_sigkill` and `test_no_unconditional_lossless_claim` check source text. Kept, and labelled as wording only.
- The Claude transcript holder test stubs `lsof` to report a holder that real Claude never produces.
- Several tests extract blocks with `sed` and stub every function around them.

## Changes

| Change | Status |
|---|---|
| Fail-closed guards, no SIGKILL, `immutable=1` removed, separate rollout wait | Accepted |
| `records.sh`: exact selection, policy from structured history, atomic store | Accepted |
| Crash recovery without stops; proof of every seat; `starting` flag | Accepted |
| Dual-harness rescuer, `doctor.sh`, `CLAUDE.md`, `--no-daemon` check | Accepted, fixed for bash 3.2 |
| `--before` and the default marker removed | Accepted, with `--seed` for this incident |
| Lock, duplicate scope, chart handling, doctor | Adapted |
| 5-second daemon wait | Changed: polls for 30s, because with no SIGKILL a slow exit would leave the org down |
| Python guard suite | Rejected: ported to bash |
| Legacy tests shelved | Changed: real-tmux suite restored to `make test` |
| Claude pid map, `health`, `--seed`, history-age busy signal | Added |
| Collector install; lifecycle integration; pins | Not done, see below |

## Tests run

Rescuer 35, records 48, guard 19, real tmux 25, all on this Mac. 13 of 13 mutations caught.
Real tools used: `sqlite3`, `lsof`, tmux, the seat loader. Fake harnesses throughout: **no native resume has been qualified.**

## Installed versus implemented

Installed: nothing. The launchd job is generated and passes `plutil -lint` only. Installing it is the operator's, after review.

## Open

- No real Codex resume has run on this path, including the 0.164 CLI reading 0.166 history.
- An in-UI session switch is unproven: Claude's pid file, and Codex under `--no-daemon`.
- Proof of every seat stops the run at the first failure, so one slow snapshot leaves the rest down. Line 3 also takes longer than the 18 minutes stated.
- Lifecycle capture needs the seat loader or Runtime, which are not in this repo.
- Launchd job: access to the volume from launchd is unproven, though three existing agents already run from `/Volumes`.
- `zeo-rescue` has no marker record, so `make agent` refuses until the operator provisions one.
- The teardown's cause is unknown.
