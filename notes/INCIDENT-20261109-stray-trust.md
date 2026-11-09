# Incident, 9 Nov 2026 03:38 GMT: a lines test ran a real trust step

For the next SOW of zeo-rescue, on the Architect's ruling of 9 Nov 03:44Z ("name the incident in your next SOW with its cause, so the guard has a paid failure behind it").

## What happened

- **What I was doing.** zeo-rescue was testing a new lines file. The test was meant to swap each line's commands for `echo`, and then run the line.
- **The bug.** The generator had passed `\&\&` to `printf '%s'`. printf doesn't unescape `%s` arguments, so the line held a literal `\&\&`.
- **Why the test missed it.** The swap's pattern expected `&&`, so it did not match. Nothing checked that the swap had happened before the line ran.
- **What ran.** bash read `\&\&` as a plain word. It ran `./reseat-lines.sh structure-trust zeocontrolling` for real, from the scratch worktree, and passed the rest along as ignored arguments.

## What it changed

- **The trust entry.** It added `hasTrustDialogAccepted: true` for `/Volumes/AIPEMedia1/code/zeroemployeeorg/zeocontrolling/main` in ~/.claude.json, under Claude's lock and the hash guard.
- **A backup.** It made `claude-json.before-zeocontrolling`, mode 600, which nobody has read. The log is `reseat-lines-structure-trust-zeocontrolling-20261109-033813.log`.
- **Nothing else.** structure-first did not run, and no seat was stopped or started.
- **The ruling.** The Architect chose (a), leave it. It is exactly the first half of zeocontrolling's line 1.

## The cause

A test that could run a real command, with nothing to stop it when its substitution did not apply.

## The guard

- **The swap.** Line tests now swap with perl's literal `\Q…\E` patterns.
- **The refusal.** They refuse to execute while any `./reseat-lines.sh`, the real `cd` or `git switch` is left in the line.
- **No blind runs.** No generated line is run unless it has been checked like this. Every line test since has used this guard.
