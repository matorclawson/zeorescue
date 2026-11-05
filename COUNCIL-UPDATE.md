# Council update — automatic recovery records, 2026-11-05

Implemented on top of the dual-harness candidate. No live seat, Mac configuration,
service, native harness session or external repository was modified or started.

## User requirement delivered

Recovery facts are generated programmatically, without a seat/harness/model. The
operator does not prepare a recovery manifest during an emergency. The normal org
chart remains authoritative desired state; records.sh derives local recovery data.

## Changes in this return

1. Added records.sh capture/status/get/service/install. It joins chart, tmux pane,
   process identity/cwd, exact native session and structured history policy. Native
   session IDs come from explicit process identity or validated open history files,
   never a newest-file or newest-DB-row guess. Codex and Claude are both supported.
2. Saves a versioned local JSON cache via a single-writer lock and atomic replacement,
   retains a forensic previous copy, and captures the last-good org chart before an
   outage. Down seats retain their last observed mappings. Conflicting observations
   are recorded as blockers, not silently accepted.
3. Added a finite macOS launchd collector: every 30 seconds and at login, no agent.
   The installer refuses an existing job/plist. It was implemented, NOT executed.
   Other lifecycle programs can invoke the same capture command immediately after
   native session changes. Integration into other repos is not claimed.
4. Replaced recovery's newest-transcript/session and default-master fallbacks with
   records.sh get. It validates chart agreement and reads current policy from the
   exact saved native history. Pins/--session are assertions only; --before is refused.
5. Made crash recovery explicitly bypass both stop-seat and stop-daemon phases.
   Live-seat repair stays separate behind --reseat. Missing mappings are reported;
   independent recorded dead seats can still be recovered.
6. Added process/history-holder checks for both native harnesses, not Codex only.
   Every new seat receives the existing basic proof, including inactive Git policy.
   The rescue flag is starting until proof passes. Inactive panes are explicitly
   marked inactive, avoiding inherited tmux marker fallback. Capture is attempted
   automatically after launches.
7. Added records status to doctor; propagated records/host/socket settings through
   both rescuer bootstrap paths. Added RECORDS.md and revised operational instructions
   to distinguish generated facts from narrative STATE.md and crash recovery from repair.
8. Replaced the default test target with the current offline suites. Original tests
   were preserved under council/legacy-tests because their assumed newest-session,
   default-marker and automatic-SIGKILL behaviors have intentionally been removed.
   They are historical fixtures, not purported passing tests for the new implementation.

## Validation

`make test`: 81 checks pass (33 rescuer, 30 records/recovery, 18 guard regressions).
The records tests include real script entrypoints with fake tmux/process/harness
observations; both Codex and Claude apply paths are exercised without real clients.
The guard suite includes a real SQLite WAL fixture using Python's SQLite library.
Policy-bearing message text, newer unrelated transcripts, lost upstream chart,
complete outages, contamination, missing markers, stale locks, corrupt caches,
duplicate sessions and every-seat proof behavior are covered.

All shell files pass bash syntax checks. Both patches apply and reproduce the full
source byte-for-byte, including executable modes. The generated launchd plist is
provided by code; actual launchctl installation/behavior is NOT host-qualified.
No real resume, tool-shell loader, authentication or production workload was run.

## Integration and remaining limits

Read RECORDS.md. The collector supports visible native identity in the packet's
tmux topology and directly open unambiguous native histories. Wrappers, unobserved
in-UI switches and native histories held only by untracked children may need a
specific lifecycle adapter. Polling is not an event-complete ledger. There is no
claim that a session change which escaped observation can be recovered exactly.
The current machine incident predates this collector; missing first captures are
reported, not invented or delegated to an AI.

The native policy object is stored, but the launch adapter still has its existing
limited policy flags. Extra native restrictions and real version compatibility
require qualification. lsof and process checks are observations, not exclusive
writer locks. Full outward-work quarantine, stale recovered-flag reconciliation,
ambiguous legacy panes and guaranteed cleanup are not all resolved by this change.
The broader live-reseat clearance is still withheld.

Pinned files changed versus af45115: rescue.sh and Makefile. records.sh is a new
execution dependency and now has an additional hash check in reseat-lines.sh.
The original rescue.sh/Makefile pins intentionally remain stale, so old operator
lines cannot run this candidate. Integration must reconcile ALL reviewed dependency
hashes, then update the runner hash in operator lines after the Architect reads it.
No new operator bulk-launch command or approval receipt is supplied.
