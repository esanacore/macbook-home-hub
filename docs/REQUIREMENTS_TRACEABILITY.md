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

The hub hardware has not been provisioned yet. Ten of twelve requirements
describe behavior of a machine that does not exist, so they have no *executed*
verifying test. `constitution/scripts/check_traceability.sh` reports exactly
those ten, and that report is correct.

Two of the ten (FR-002, FR-004) do have a check written — `smoke_check.sh` and
the compose tier of `run_tests.sh` — but neither has ever run against real
hardware. They are still counted as gaps, deliberately. A check that has never
executed has proven nothing, and the checker's "GAP" verdict on them is the
honest one.

The temptation is to name a planned script in the Verifying Tests column to
turn the report green. That would make the matrix lie about what has been
verified, which is the one thing this document exists to prevent. Gaps stay
gaps until a check actually runs and passes.

## Functional Requirements

| Requirement ID | Level | Description | Acceptance Criteria | Verifying Tests | Status |
| --- | --- | --- | --- | --- | --- |
| FR-001 | MUST | Host stays running and reachable with the lid closed | FR-001-AC-1 SSH answers after 30 min lid-closed; FR-001-AC-2 no sleep inhibitor pending; FR-001-AC-3 sleep targets masked | none — GAP (needs hardware; see GAP-001) | Not Started |
| FR-002 | MUST | Home Assistant reachable over HTTP on :8123 from the LAN | FR-002-AC-1 curl returns 2xx/3xx from another LAN host; FR-002-AC-2 container in running state, not restart-looping | `scripts/smoke_check.sh` (written; never executed against a hub — see GAP-002) | Not Started |
| FR-003 | MUST | Stack returns automatically after reboot or power loss | FR-003-AC-1 HA answers within 5 min of reboot unattended; FR-003-AC-2 all services declare unless-stopped/always | none — GAP (needs hardware; see GAP-003) | Not Started |
| FR-004 | MUST | Hub configuration is version-controlled, not ad hoc | FR-004-AC-1 compose file committed and passes validation; FR-004-AC-2 images pinned to dated tags, never latest; FR-004-AC-3 config is a bind mount | `scripts/run_tests.sh` compose tier (`docker compose config`) — currently SKIPs, file absent; see GAP-004 | Not Started |
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
| Verified | 2 |
| In progress | 0 |
| Not started | 8 |
| Deferred | 2 |
| Requirements without an executed verifying test (gaps) | 10 |
| — of which a check is written but unproven | 2 (FR-002, FR-004) |

`MUST` requirements: 8 total (FR-001, FR-002, FR-003, FR-004, FR-007,
NFR-001, NFR-002, NFR-004), of which 2 are verified (NFR-001, NFR-004) and 6
remain unverified. FR-002 and FR-004 have a written check that has never
executed; the other four have no check at all. Every unverified `MUST` needs
the physical hub — none is blocked on missing repository work.
