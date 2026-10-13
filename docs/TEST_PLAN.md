# Test Plan

This document defines how this repository is tested, what coverage it targets,
and where coverage gaps currently exist.

It is a living document. Update it whenever the test strategy, targets, or
known gaps change.

## What "Testing" Means Here

This repository contains no application code of its own. It holds
configuration, documentation, and operational procedure for one physical
machine. Line coverage is meaningless — there are no lines to cover.

What *can* fail here is different, so that is what gets tested:

- A governance document silently drifts into a placeholder.
- A credential gets committed.
- A compose file is syntactically invalid and the stack will not start.
- The hub is not actually serving after a change.

The suite is therefore split by what it needs to run:

| Tier | What it checks | Needs hardware | Runs in CI |
| --- | --- | --- | --- |
| Static | Governance docs, secrets sweep, OTS inventory, env-var contract, architecture, gbrain block staleness, unit tests for both checkers we own | No | Yes (gbrain staleness is advisory — see below) |
| Configuration | `docker-compose.yml` parses and resolves | Docker only | Yes, once Docker is present |
| Host config | Live logind lid policy, sleep targets masked, Docker and SSH enabled, XFCE power manager (`scripts/check_host_config.sh`) | Yes — runs only on the `MacBook8,1` (or `HUB_LOCAL=1`) | No (SKIPs) |
| Smoke (end-to-end) | Host reachable, Home Assistant answering on `:8123`, container running | Yes — the hub | No |

The host-config and smoke tiers are the only checks that touch the real
machine. Both **skip** rather than pass when they cannot run (off-hub, or
`HUB_HOST` unset), so a green suite elsewhere never implies the hub was
verified. On the hub itself the host-config tier is **blocking**: a lid switch
that still suspends is a real failure of FR-001, and the suite says so.

## Test Strategy

The standard unit/integration/e2e pyramid maps onto this repository as
follows:

- **Unit tests**: `scripts/test_check_gbrain_state.sh` — exercises
  `scripts/check_gbrain_state.sh` against eight fixture CLAUDE.md files with
  isolated PATH and HOME, covering: in-sync (local-stdio and remote-http),
  stale-MCP-unregistered, stale-config-missing, stale-no-gbrain-cli,
  stale-no-claude-cli, block-absent, and CLAUDE.md-absent. Each fixture
  asserts the checker's exit code and a substring of its output.
  `scripts/test_check_host_config.sh` does the same for
  `scripts/check_host_config.sh`: nineteen cases drive fake `busctl`,
  `systemctl`, `docker`, `id` and `xfconf-query` binaries through `PATH`,
  covering the all-good case, the empty-inherits-parent rule and explicit
  values for `HandleLidSwitchExternalPower`, `busctl` failing, and one
  negative case per check (lid
  suspend, sleep target unmasked, docker absent, compose absent, docker
  service disabled, user not in group, ssh absent, ssh.service-only hosts accepted, XFCE lid/idle set, xfconf
  unreachable → SKIP). These are the two pieces of logic we own with
  branch-worthy behavior, so they are the two with unit tests.
- **Integration tests**: `docker compose config` — does the declared stack
  resolve into something Docker will accept? Command:
  `bash scripts/run_tests.sh` (the compose tier). And
  `scripts/check_host_config.sh` — does the live host carry the always-on
  configuration the stack assumes? Runs inside `run_tests.sh` on the hub.
- **End-to-end tests**: `scripts/smoke_check.sh` — against a running hub.
  Command: `HUB_HOST=<hub-ip> bash scripts/smoke_check.sh`.

### gbrain block staleness check

`scripts/check_gbrain_state.sh` reads the `## GBrain Configuration` block
from `CLAUDE.md` and verifies its machine-checkable claims (Mode, Config
file path, MCP registered) against the actual machine state. The block is
written by `/setup-gbrain` and records machine state; when the repo is
cloned on a machine without gbrain (CI, a new laptop), the block's claims
drift from reality. The checker reports `STALE` and exits 1; a clean match
or absent block exits 0.

In `scripts/run_tests.sh` this checker runs **advisory** (like the
traceability gate): on CI it will always report STALE because CI runners
have no gbrain, and that is the expected cross-machine signal, not a suite
failure. Re-running `/setup-gbrain` on the stale machine rewrites the block
in place via its HTML-comment delimiters. The unit tests for the checker
run as a **blocking** check because they use fixtures with isolated
PATH/HOME and pass on any machine.

## How to Run Tests

- Full suite: `bash scripts/run_tests.sh`
- With coverage: not applicable — see "Coverage Targets" below.
- A single test or subset: `bash constitution/scripts/check_secrets.sh` (or any
  other single script under `constitution/scripts/`)
- On the hub: `bash scripts/run_tests.sh` (host-config tier runs automatically
  on the `MacBook8,1`; `HUB_LOCAL=1` forces it elsewhere)
- Against the hub from another machine: `HUB_HOST=<hub-ip> bash scripts/run_tests.sh`

## Coverage Targets

Percentage-based code coverage does not apply to this repository. Substituting
a fabricated number would be worse than declaring none, so coverage is
expressed as **check completeness**: every requirement in
`docs/PRODUCT_REQUIREMENTS.md` should have at least one executable verifying
check.

| Scope | Metric | Floor |
| --- | --- | --- |
| Requirements with an executable verifying check | Count | 100% of `MUST` requirements |
| Governance checks passing | Count | 100% (no WARN in `check_compliance.sh`) |
| Committed secrets | Count | 0, enforced pre-push |

If application code is ever added to this repository — for example a Python
helper bridging a device protocol — this table is replaced with real line and
branch floors (80% line default, 90% branch on critical modules, 95% on
security-sensitive code) at that time.

## Continuous Coverage Evaluation

| Date | Requirements with executable checks | Governance checks | Notes |
| --- | --- | --- | --- |
| 2026-08-15 | 2 of 12 executed (2 of 8 `MUST`); 2 more written but unproven | 0 WARN, 0 MISSING | Baseline. Hardware not yet provisioned, so all host-dependent requirements are unverified by construction. |
| 2026-10-12 | 2 of 12 executed (unchanged); 3 written but unproven (`FR-001` joins `FR-002`, `FR-004`) | 0 WARN, 0 MISSING | First run **on the hub** (Mint 22.3 installed). `check_host_config.sh` executed and reported FAIL on every root-level item because `provision_host.sh` has not been run yet — recorded as the honest state, not a pass. Nothing promoted. |

A downward trend is a signal to investigate, even when the number stays above
the floor.

## Coverage Gap Log

Known unverified behavior. Every gap below is a **requirement whose
verification needs the hub** — they are not oversights, and they close as
provisioning proceeds rather than by writing more code. As of 2026-10-12 the
hub exists and the gaps are blocked on root-level provisioning and physical
tests, not on hardware.

| Gap ID | Area / behavior | Risk | Related requirement | Status | TODO ref |
| --- | --- | --- | --- | --- | --- |
| GAP-001 | Host stays reachable with the lid closed. Machine now exists; `scripts/check_host_config.sh` covers AC-2/AC-3 mechanically and ran 2026-10-12 — FAIL until `provision_host.sh` is run and the box rebooted. AC-1 (30 min lid-closed over SSH) remains a manual test. | High | FR-001 | Open | TODO.md → Provisioning |
| GAP-002 | Home Assistant answers on `:8123`. `scripts/smoke_check.sh` exists but has never executed against a real hub. | High | FR-002 | Open | TODO.md → Services |
| GAP-003 | Stack returns automatically after an unclean reboot. No restart-policy test. | High | FR-003 | Open | TODO.md → Services |
| GAP-004 | Compose file validity. `docker compose config` is wired into the suite but skips — Docker is not installed yet (`provision_host.sh` installs it). | Medium | FR-004 | Open | TODO.md → Services |
| GAP-005 | Backup and restore actually round-trip. No backup job exists, so restore has never been exercised. An untested restore is not a backup. | High | FR-007 | Open | TODO.md → Operations |
| GAP-006 | Battery carries the hub through a power cut. Requires deliberately pulling power. | Medium | NFR-002 | Open | TODO.md → Operations |
| GAP-007 | Resource headroom under real automation load on 8 GB. No baseline measured. | Low | NFR-003 | Open | TODO.md → Operations |
| GAP-008 | Hub is not exposed to the public internet. Requires manual router inspection; no check runnable from this repository. | Medium | NFR-005 | Open | TODO.md → Operations |

`FR-005` (MQTT) and `FR-006` (Node-RED) also have no verifying test, but they
are `Deferred` by choice rather than open gaps — neither has been adopted, and
device selection is still open. They are excluded from the log above so it
stays a list of things that need doing.

## Requirement Coverage

Every requirement ID maps to its verifying check in
`docs/REQUIREMENTS_TRACEABILITY.md`. Requirements with no verifying test are
gaps and appear in the gap log above.

Current state: 12 requirements, 2 with an executed verifying check (NFR-001,
NFR-004), 10 gaps. Three of those gaps (`FR-001`, `FR-002`, `FR-004`) have a
check written but not yet passed on the hub — counted as gaps on purpose,
because a check that has not passed has proven nothing. (`FR-001`'s check has
*executed* on the hub and failed, which is the expected pre-provisioning
result.)

The 10 gapped requirements are **Deferred** in `docs/PRODUCT_REQUIREMENTS.md`
(backticked IDs), which places them outside the blocking CI gate while keeping
them fully documented here and in the matrix. The 2 verified ones are
**Active** and gated: CI fails if either loses its verifying test, or if a new
requirement is promoted to Active without one.

`constitution/scripts/check_traceability.sh` prints the deferred set on every
run under "matrix rows with no matching declared requirement," so the gap
count stays visible in CI output rather than being suppressed by it.
