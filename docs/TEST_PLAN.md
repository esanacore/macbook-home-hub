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
| Static | Governance docs, secrets sweep, OTS inventory, env-var contract, architecture | No | Yes |
| Configuration | `docker-compose.yml` parses and resolves | Docker only | Yes, once the file exists |
| Smoke (end-to-end) | Host reachable, Home Assistant answering on `:8123`, container running | Yes — the hub | No |

The smoke tier is the only real end-to-end test, and it cannot run against a
machine that does not exist yet. It **skips** rather than passes when
`HUB_HOST` is unset, so a green suite never implies the hub was verified.

## Test Strategy

The standard unit/integration/e2e pyramid maps onto this repository as
follows:

- **Unit tests**: not applicable. No functions of our own to isolate. The
  shell helpers in `scripts/` are thin orchestration over external commands;
  the constitution's own scripts are tested upstream in
  `constitution/scripts/test_*.sh`.
- **Integration tests**: `docker compose config` — does the declared stack
  resolve into something Docker will accept? Command:
  `bash scripts/run_tests.sh` (the compose tier).
- **End-to-end tests**: `scripts/smoke_check.sh` — against a running hub.
  Command: `HUB_HOST=<hub-ip> bash scripts/smoke_check.sh`.

## How to Run Tests

- Full suite: `bash scripts/run_tests.sh`
- With coverage: not applicable — see "Coverage Targets" below.
- A single test or subset: `bash constitution/scripts/check_secrets.sh` (or any
  other single script under `constitution/scripts/`)
- Against the hub: `HUB_HOST=<hub-ip> bash scripts/run_tests.sh`

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

A downward trend is a signal to investigate, even when the number stays above
the floor.

## Coverage Gap Log

Known unverified behavior. Every gap below is a **requirement whose
verification needs hardware that does not exist yet** — they are not
oversights, and they close as provisioning proceeds rather than by writing
more code.

| Gap ID | Area / behavior | Risk | Related requirement | Status | TODO ref |
| --- | --- | --- | --- | --- | --- |
| GAP-001 | Host stays reachable with the lid closed. Cannot be verified without the machine. | High | FR-001 | Open | TODO.md → Provisioning |
| GAP-002 | Home Assistant answers on `:8123`. `scripts/smoke_check.sh` exists but has never executed against a real hub. | High | FR-002 | Open | TODO.md → Services |
| GAP-003 | Stack returns automatically after an unclean reboot. No restart-policy test. | High | FR-003 | Open | TODO.md → Services |
| GAP-004 | Compose file validity. `docker compose config` is wired into the suite but skips — `compose/docker-compose.yml` does not exist. | Medium | FR-004 | Open | TODO.md → Services |
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
NFR-004), 10 gaps. Two of those gaps (FR-002, FR-004) have a check written but
never executed — counted as gaps on purpose, because an unexecuted check has
proven nothing.

`constitution/scripts/check_traceability.sh` reports those 10. That report is
accurate and expected, not a tooling failure. It goes quiet as the hub is
built, and `scripts/run_tests.sh` runs it as advisory until then rather than
failing the suite on a state that cannot currently be improved.
