# zeo-rescue runbook

## Before an outage

After code review and host qualification, install the finite collector once with
`make records-install`. It generates recovery records automatically every 30 seconds
and at login, without a seat or harness. Check `make records-status` for missing or
conflicting mappings. The normal seat launcher should also call `make records`
after native session changes. See RECORDS.md for observation limits.

## Seats have gone down

1. Start either rescuer as documented in RESCUER.md, or use the scripts directly.
2. Run `make doctor`, `make records-status`, then `make plan`. These do not start seats.
3. Resolve named conflicts from evidence. Do not write a manual manifest, choose the
   newest transcript, or substitute a new session for missing history.
4. After the required review, the operator proves one dead seat with
   `make rescue ARGS='--seat SEAT_ID'`, then inspects its actual resume and tools.
5. The operator runs `make rescue` for the remaining recorded dead seats, then
   `make check`. Every newly launched seat receives a basic proof. Live sessions
   are left alone; normal recovery never stops the daemon or live seats.

Other resolvable dead seats may recover even when one has no valid record; the exit
status and UNRESOLVED lines still report incomplete recovery. Review the summary.
The generated cache and last-good chart remain usable with Runtime, Messenger,
tmux and all harnesses down. Native history must still be accessible on disk.

## Seats are up but wrong

This is repair, not crash recovery. `make reseat-plan` and `--reseat` have a separate
operator-controlled stop path. The original incident's pinned lines do not match
this candidate. The earlier council blockers for live repair remain open; do not
infer clearance from the new record collector or its tests.

## A launch or proof fails

Do not assume cleanup succeeded or that nothing was lost. Inspect actual processes,
panes, history holders and external effects before retry. A `starting` marker is
not a verified seat. `make records-status` reports captured mappings and conflicts;
it is not a writer lock or external-action audit.

For the unknown login teardown, retain relevant system/session-manager logs using
the existing teardown-log helper. The collector does not diagnose the teardown.
