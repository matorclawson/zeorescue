# Running zeo-rescue with either harness

The rescuer is a role, not a Claude session. Codex and Claude Code use the same
recovery scripts, identity, evidence, rules and handoff. Neither requires the
other harness to be the rescuer. Target seats retain their own harness and history.

| Rescuer | Target | Mechanism |
|---|---|---|
| Codex | Codex | `rescue.sh` selects recorded Codex thread; target CLI uses `--no-daemon` |
| Codex | Claude Code | same planner, Claude transcript and Claude CLI |
| Claude Code | Codex | same planner, Codex thread and isolated Codex CLI |
| Claude Code | Claude Code | same planner, Claude transcript and Claude CLI |

This table describes implemented routing, not four real-host qualifications.
The council's bulk-recovery blockers remain open.

## If the rescuer was never provisioned

`make agent` refuses without the record below, and that must not stop a rescue. In a
collapse, `cd` to this repo and run `claude` or `codex --no-daemon` directly. You get
no marker and the caller's environment, so report that and do not use network git.

## Provision the rescuer once

The operator must establish zeo-rescue's **own** marker. The old implementation
started a shell with no marker and inherited its caller's environment. The new
launcher refuses to invent `master` or borrow another seat's marker.

The default record is `~/.local/state/zeo-rescue/rescuer.json`. Copy the example
and replace `null` with the marker assigned to zeo-rescue in its provisioning
record: `master`, `sparring`, `principal`, or `inactive`. Its `seat_id` must be
`zeo-rescue`. `inactive` deliberately keeps network git off. Do not choose a more
privileged marker just to make a check pass. `--record /absolute/path.json` can
select another operator-provisioned record. The null-valued example cannot launch.

Install both target CLIs if recovery must resume both kinds of seat. Only the
selected CLI is necessary to start the rescuer; missing target CLIs are reported
by doctor rather than preventing diagnosis. Complete normal CLI login as the
operator using the standard HOME/configuration, without exposing credentials to
the rescuer. Confirm the repo and each target's historical files are readable.

The existing CLI defaults are `~/.local/bin/codex` and `~/.local/bin/claude`.
Explicit executable-path overrides are `ZEO_RESCUE_CODEX` and
`ZEO_RESCUE_CLAUDE`; paths must be absolute. The selected Codex installation must
advertise `--no-daemon` in its help, or startup refuses. This capability check does
not certify its compatibility with history written by another release.

## Start and attach

From the reviewed checkout, after normal integration approval:

```sh
make agent RESCUER=codex
# Alternatively, after the first rescuer has ended:
make agent RESCUER=claude
# Attach to either:
tmux -L zeo-rescue attach
```

`make agent` preserves the previous default of Claude. There is one logical
rescuer, on the separate `zeo-rescue` socket. An existing session is never replaced
or restarted by this command. A launch lock serializes cooperating starts; tmux's
unique session name rejects races even across different state directories. A stale
lock requires inspection; it is not automatically deleted. This does not prevent
someone manually starting an unrelated CLI outside the launcher: do not run a
second active rescuer that way.

The pane starts on sleep, receives the provisioned marker and harness metadata,
then runs the selected CLI. The launcher prints START REQUESTED, not recovered or
ready. A trust/login prompt, permission refusal or model failure still needs the
operator. Do not type into a target's terminal to resolve it.

## Shared context, tools and capabilities

- `AGENTS.md` is canonical; `CLAUDE.md` imports it for compatibility across Claude
  versions. The startup prompt explicitly names the same documents for both.
- `STATE.md` is durable task memory; `RUNBOOK.md` describes recovery. Chat history
  and auto-memory supplement them but are not the shared state. `RECORDS.md` describes
  automatically generated target mappings; the rescuer never writes that cache by hand.
- `make doctor` reports local capabilities. `make doctor ARGS=--json` emits schema
  version 1 with named status/detail checks. `inspection_tools_ready` only means
  required local utilities and context passed those checks. Always inspect all
  statuses; missing histories, target CLIs, authentication and authorizations have
  their own entries. `restart_cleared` is always false.
- Core tools: bash, zsh, make, jq, tmux, sqlite3, ps, lsof, Perl and standard Unix
  utilities. The JSON doctor reports executable paths and read/inspection results,
  not secrets or process command lines. It makes no model or Messenger request.
- Existing `ZEO_RESCUE_*` path overrides for state, chart, history, tools and pins
  are explicitly carried from the launcher. Stale copies in the tmux server are
  removed. Git, gh and zmsg are optional for inspection but necessary for workflows
  that use them. Their presence is not proof of authorization.
- The clean environment drops borrowed identities, harness session variables,
  inherited Git restrictions and credentials. It retains standard HOME for the
  CLI's own saved login/configuration and builds a known utility PATH. It does not
  read or print credentials. It does not carry arbitrary custom config directories,
  environment-only authentication, proxy settings or SSH agent sockets. If those
  are required on the host, provision and qualify an explicit adapter before use;
  do not re-enable arbitrary environment inheritance.
- Hooks, plugins and MCP integrations already configured in standard HOME/repo
  remain the selected CLI's responsibility. Required capabilities are exposed by
  local scripts, so recovery inspection does not depend on harness-specific plugins.
  Audit host hooks before the first real run: clean process environment does not
  prevent later tool startup files or configured hooks from changing behavior.
- No forced Claude auto mode, Codex approval policy, blanket tool allowlist or
  permission bypass is installed. The operator must grant the harness's ordinary
  permitted access when needed. A tool refusal is a reported blocker, not a reason
  to switch identity or bypass restrictions.

Inside the actual rescuer, first read the documents and run doctor, then the
read-only plan/check commands. Verify its actual tool shell reports
`ZMAIL_INSTANCE=zeo-rescue`, the provisioned marker, the correct working directory
and expected Git policy. Never dump the entire environment because it can contain
credentials loaded later by host configuration. An inactive rescuer cannot perform
network Git; local recovery inspection can still be useful.

The mailbox is not assumed registered. Use only the zeo-rescue identity. If it is
unregistered, relay through the operator; do not adopt the Architect's mailbox.
The shared recovery tools need no Messenger connection to inspect and plan.

## Handoff between Codex and Claude Code

Write current facts and timestamps, exact seat/thread/pane mappings, inspected
files, commands and outcomes, pending approvals, failed/unknown checks and the next
safe step to STATE.md. Preserve evidence logs in the existing rescue state directory.
End the old rescuer before the operator starts the other harness. The new harness
begins a new native conversation and reads that handoff. It must refresh live facts.
It does not translate the previous harness's native transcript or resume a target
as a different harness. Do not use “most recent session” to guess identity.

Host operator commands are ordinary shell commands with saved output. Neither
harness's `!` shortcut, native memory format nor chat UI is required.

## Qualification still required on the Mac mini

Run `make test-rescuer` and the original host suite after integration. Then start
each rescuer separately, confirm normal login/trust, actual tool identity/marker,
readable histories, tmux/ps/lsof visibility, and the same read-only inspection
results. Missing native permissions cannot be qualified with fake harnesses.
For target resumes, independently qualify both real target CLIs and their recorded
policy variants under the council's controlled proof procedure. Never interpret
these new bootstrap tests as permission for the currently blocked bulk reseat.

Official CLI/instruction references checked 2026-11-05:
- https://learn.chatgpt.com/docs/cli/reference
- https://code.claude.com/docs/en/cli-reference
- https://code.claude.com/docs/en/memory
