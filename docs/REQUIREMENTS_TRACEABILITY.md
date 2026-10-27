# Requirements Traceability Matrix

This matrix links each requirement to its acceptance criteria, the tests that
verify it, and its current verification status. It provides a single,
auditable view from product intent to evidence of completion.

It is a living document. Update it in the same change that adds, modifies, or
verifies a requirement.

Related documents:

- `docs/PRODUCT_REQUIREMENTS.md` — the source of requirement definitions and IDs.
- `docs/TEST_PLAN.md` — coverage targets, continuous evaluation, and the gap log.

## Conventions

- **Requirement ID**: matches the ID in `docs/PRODUCT_REQUIREMENTS.md` (for
  example, `FR-001`, `NFR-001`).
- **Level**: `MUST`, `SHOULD`, `COULD`, or `WON'T`.
- **Acceptance criteria**: the verifiable conditions for the requirement.
- **Verifying tests**: the test names, files, or IDs that exercise the
  requirement.
- **Status**: `Not Started`, `In Progress`, `Verified`, or `Deferred`.

A requirement with no verifying test is a coverage gap. It is recorded in
`docs/TEST_PLAN.md` (gap log) and in `TODO.md` under Testing.

## Reading This Matrix Honestly

The hub was provisioned on 2026-10-12, the stack is running, and it has come
back unattended from a reboot. Six requirements are now **Active** (bold IDs in
`docs/PRODUCT_REQUIREMENTS.md`, inside the blocking CI gate): `NFR-001`,
`NFR-004`, and — promoted that day on the strength of checks that actually ran
on the hub — `FR-001`, `FR-002`, `FR-003` and `FR-004`.

Two of the Active ones are `In Progress` rather than `Verified`, and the
distinction is kept on purpose: `FR-001`'s mechanical criteria pass but the
30-minute lid-closed test has not been done, and `FR-002` has been checked from
the hub's own LAN address but not yet from a second machine. Their gap-log rows
stay open for exactly those residuals.

The other six are **Deferred** — IDs backticked rather than bold, outside the
gate. They keep their rows below, their gap-log entries in `docs/TEST_PLAN.md`,
and their items in `TODO.md`. `check_traceability.sh` lists every one of them
on each run under "matrix rows with no matching declared requirement," so the
deferred set is printed in CI rather than hidden by it. What blocks them is a
pulled plug, a restore onto a second machine, a router inspection, and two
adoption decisions (MQTT, Node-RED).

The temptation is to name a planned script in the Verifying Tests column to
turn the report green. That would make the matrix lie about what has been
verified, which is the one thing this document exists to prevent. A requirement
becomes Active only when a check has actually run and passed.

Status values below are unchanged by deferral: `Not Started` means not started,
whether or not the requirement is currently gated.

## Functional Requirements

| Requirement ID | Level | Description | Acceptance Criteria | Verifying Tests | Status |
| --- | --- | --- | --- | --- | --- |
| FR-001 | MUST | Host stays running and reachable with the lid closed | FR-001-AC-1 SSH answers after 30 min lid-closed; FR-001-AC-2 no sleep inhibitor pending; FR-001-AC-3 sleep targets masked | `scripts/check_host_config.sh` (host tier of `run_tests.sh`) covers AC-2/AC-3 — executed on the hub 2026-10-12 after the post-provisioning reboot, PASS. AC-1 (30 min lid-closed over SSH) is manual and still pending; residual tracked in `docs/TEST_PLAN.md` row 001 | In Progress (AC-2, AC-3 verified; AC-1 pending) |
| FR-002 | MUST | Home Assistant reachable over HTTP on :8123 from the LAN | FR-002-AC-1 curl returns 2xx/3xx from another LAN host; FR-002-AC-2 container in running state, not restart-looping, and **not in recovery mode** | `scripts/smoke_check.sh` via `HUB_HOST=192.168.1.192 bash scripts/run_tests.sh` — executed on the hub 2026-10-12, PASS (HTTP 302, container running). Since 2026-10-25 it also fails on recovery mode (container log since start) and on `check_config` rejecting the config; unit-tested by `scripts/test_smoke_check.sh` (blocking). Executed on the hub 2026-10-25: **FAIL** — recovery mode since 2026-10-15, `Secret firestick_hub_auth not defined` | In Progress (**AC-2 failing on the hub** since 2026-10-15 — recovery mode, previously undetected; AC-1 passed from the hub's own LAN address, pending a run from a second LAN host) |
| FR-003 | MUST | Stack returns automatically after reboot or power loss | FR-003-AC-1 HA answers within 5 min of reboot unattended; FR-003-AC-2 all services declare unless-stopped/always | `sudo reboot` 2026-10-12, then `HUB_HOST=192.168.1.192 bash scripts/run_tests.sh` ~1 min after boot: smoke PASS (HTTP 302), container started 14 s after boot; compose declares `unless-stopped` | Verified |
| FR-004 | MUST | Hub configuration is version-controlled, not ad hoc | FR-004-AC-1 compose file committed and passes validation; FR-004-AC-2 images pinned to dated tags, never latest; FR-004-AC-3 config is a bind mount | `scripts/run_tests.sh` compose tier (`docker compose -f compose/docker-compose.yml config --quiet`) — executed on the hub 2026-10-12, PASS | Verified |
| FR-005 | SHOULD | MQTT broker available for MQTT-speaking devices | FR-005-AC-1 Mosquitto running and HA reports connected; FR-005-AC-2 anonymous access disabled | none — GAP (device selection still open) | Deferred |
| FR-006 | COULD | Node-RED available as a visual flow editor | FR-006-AC-1 reachable and can read/write HA entities | none — GAP (optional; not adopted) | Deferred |
| FR-007 | MUST | Config backed up off-hub, with a restore actually exercised | FR-007-AC-1 scheduled off-host copy with verifiable last run; FR-007-AC-2 restore performed onto a clean target; FR-007-AC-3 encryption key stored off the hub | none — GAP (no backup job exists; see GAP-005) | Not Started |

## Non-Functional Requirements

| Requirement ID | Level | Description | Acceptance Criteria | Verifying Tests | Status |
| --- | --- | --- | --- | --- | --- |
| NFR-001 | MUST | No credential, token, or private key is ever committed | NFR-001-AC-1 secrets sweep reports 0/0/0; NFR-001-AC-2 sweep runs as a pre-push hook; NFR-001-AC-3 HA secrets via !secret from gitignored file | `constitution/scripts/check_secrets.sh` via `scripts/run_tests.sh`; pre-push hook in `.pre-commit-config.yaml` | Verified |
| NFR-002 | MUST | Hub survives mains interruption on battery | NFR-002-AC-1 serves :8123 through a 10-min outage; NFR-002-AC-2 battery discharges rather than host powering off | none — GAP (needs hardware and a deliberate power cut; see GAP-006) | Not Started |
| NFR-003 | SHOULD | Runs within 8 GB with headroom, passively cool | NFR-003-AC-1 steady-state memory below 6 GB, not continuously swapping; NFR-003-AC-2 host responsive over SSH under load | none — GAP (no baseline measured; see GAP-007) | Not Started |
| NFR-004 | MUST | Hub health verifiable by a single command | NFR-004-AC-1 `run_tests.sh` runs the declared suite and fails non-zero on any failed check; NFR-004-AC-2 unrunnable checks report SKIP, never counted as passes | `scripts/run_tests.sh` (executed 2026-08-15; suite runs, reports pass/fail/skip correctly) | Verified |
| NFR-005 | SHOULD | Hub not directly exposed to the public internet | NFR-005-AC-1 no router port forward to :8123 or :22 | none — GAP (manual router inspection; no automated check possible from this repo) | Not Started |

## Coverage Summary

| Metric | Count |
| --- | --- |
| Total requirements | 12 |
| Verified | 4 |
| In progress | 2 |
| Not started | 4 |
| Deferred | 2 |
| Requirements without a passing executed verifying test (gaps) | 6 |
| — of which Active with a residual manual criterion | 2 (FR-001 lid test, FR-002 second host) |
| Active (gated by blocking CI) | 6 (NFR-001, NFR-004, FR-001, FR-002, FR-003, FR-004) |
| Deferred (outside the gate, blocked on physical tests or decisions) | 6 |

`MUST` requirements: 8 total (FR-001, FR-002, FR-003, FR-004, FR-007,
NFR-001, NFR-002, NFR-004), of which 4 are verified (NFR-001, NFR-004,
FR-003, FR-004), 2 are in progress with a passing executed check and one
manual criterion left (FR-001 lid test; FR-002 second LAN host), and 2 have
no check at all (FR-007 backup/restore, NFR-002 power cut). Every unverified
`MUST` needs a person at the machine — none is blocked on missing repository
work.
