# Product Requirements

This document translates product intent into concrete implementation
requirements.

Each requirement carries a stable ID and explicit acceptance criteria. The
mapping from requirement to verifying test is tracked in
`docs/REQUIREMENTS_TRACEABILITY.md`.

## Requirement Levels

- `MUST`: Required for the current release or MVP.
- `SHOULD`: Important, but can be deferred if needed.
- `COULD`: Useful future enhancement.
- `WON'T`: Explicitly out of scope for the current release or MVP.

## Requirement Identifiers

- Functional requirements use the prefix `FR-` (for example, `FR-001`).
- Non-functional requirements use the prefix `NFR-` (for example, `NFR-001`).
- Acceptance criteria may carry sub-identifiers (for example, `FR-001-AC-1`).
- IDs are stable and never reused for a different requirement, even after one
  is removed or superseded.

## Active vs Deferred: How to Read This Document

Requirements here are split into two sections, and the difference is
mechanical, not cosmetic.

**Active requirements** declare their ID in bold (`**NFR-001**`).
`constitution/scripts/check_traceability.sh` reads bold declarations, so every
active requirement **must** have a verifying test in the matrix or CI fails.
This gate is blocking.

**Deferred requirements** write their ID in backticks (`` `FR-001` ``) instead.
The checker does not treat these as declarations — the same convention it
already uses to exclude acceptance-criteria sub-IDs. They are therefore
outside the gate.

This is not a way to hide untested requirements. Deferring is a claim that a
requirement **cannot be verified yet**, and it carries obligations:

- The full requirement text and acceptance criteria stay in this document,
  unchanged and readable.
- It keeps its row in `docs/REQUIREMENTS_TRACEABILITY.md`.
- It keeps its entry in the gap log in `docs/TEST_PLAN.md`.
- It appears in `TODO.md` with the concrete action that unblocks it.

Every requirement deferred today is blocked on the same thing: **the hub
hardware does not exist yet.** None is deferred because writing a test would be
inconvenient. If a requirement could be verified now and is not, it belongs in
the active section, failing CI until someone tests it.

### Promoting a Deferred Requirement

When the blocker clears, in a single change:

1. Move the requirement into the Active section and change its ID from
   backtick-wrapped to bold-wrapped (surround it with double asterisks
   instead of backticks). Note that writing a bold ID *anywhere* in this
   file — including as an example — declares it to the checker, so keep
   illustrative IDs in backticks.
2. Fill the Verifying Tests cell for it in
   `docs/REQUIREMENTS_TRACEABILITY.md` with a check that has actually run.
3. Close its gap-log row in `docs/TEST_PLAN.md`.

Step 1 without step 2 fails CI. That is the intended safety property: you
cannot promote a requirement into the gate without also proving it.

## Product Summary

A 2015 12-inch Retina MacBook (`MacBook8,1`) converted into a silent,
always-on Linux box that runs Home Assistant in Docker as a home-automation
hub. The user is a single operator — Eric — who administers it over SSH and
the Home Assistant web UI.

The distinguishing property is the built-in battery, which acts as a free UPS:
the hub rides through power blips that would hard-cut a Raspberry Pi or NUC.
The MVP is reached when the hub runs unattended on a shelf with the lid closed,
survives a power blip and a reboot without human intervention, and its
configuration is recoverable from backup.

---

# Active Requirements

These are enforced by CI. Each has a verifying check that has actually
executed.

## Security

**NFR-001** `MUST` No credential, token, or private key is ever committed to
this repository.

- Level: `MUST`
- Acceptance criteria:
  - `NFR-001-AC-1`: `constitution/scripts/check_secrets.sh` reports 0 filename
    hits, 0 content-pattern hits, and 0 `.gitignore` coverage gaps.
  - `NFR-001-AC-2`: The sweep runs automatically as a pre-push hook, so
    passing it is not dependent on anyone remembering.
  - `NFR-001-AC-3`: Home Assistant secrets are referenced via `!secret` from
    a gitignored `config/secrets.yaml`, never inlined in tracked YAML.

## Testability

**NFR-004** `MUST` The hub's health is verifiable by running a single command
rather than by manual inspection.

- Level: `MUST`
- Acceptance criteria:
  - `NFR-004-AC-1`: `bash scripts/run_tests.sh` executes the full declared
    suite and returns a non-zero exit status if any executed check fails.
  - `NFR-004-AC-2`: Checks that cannot run in the current environment report
    `SKIP` and are never counted as passes.

---

# Deferred Requirements

**Blocked on hardware.** The MacBook has not been imaged. Every requirement
below describes behavior of a running machine, so none can be verified by any
amount of work in this repository. Each is tracked as an open gap in
`docs/TEST_PLAN.md`.

These are real commitments, not aspirations. They move into the active section
above as the hub is built, following the promotion procedure.

## Always-On Host

`FR-001` `MUST` The host continues running and stays reachable on the network
with the lid closed and no user logged in.

- Level: `MUST`
- Blocked by: no machine to close the lid of. Gap: GAP-001.
- Acceptance criteria:
  - `FR-001-AC-1`: With the lid closed for at least 30 minutes, the host
    answers SSH on port 22.
  - `FR-001-AC-2`: `systemd-inhibit --list` shows no pending sleep or suspend
    inhibitor that would suspend the machine.
  - `FR-001-AC-3`: `sleep.target`, `suspend.target`, `hibernate.target`, and
    `hybrid-sleep.target` all report `masked`.

`FR-003` `MUST` The service stack returns automatically after a host reboot
or unclean power loss, with no manual step.

- Level: `MUST`
- Blocked by: no host to reboot. Gap: GAP-003.
- Acceptance criteria:
  - `FR-003-AC-1`: After `sudo reboot`, Home Assistant answers on `:8123`
    within 5 minutes with no human intervention.
  - `FR-003-AC-2`: Every service in the compose file declares a restart policy
    of `unless-stopped` or `always`.

## Home Assistant Service

`FR-002` `MUST` Home Assistant is reachable over HTTP on port 8123 from the
LAN.

- Level: `MUST`
- Blocked by: `scripts/smoke_check.sh` exists but has never executed against a
  running hub. Gap: GAP-002.
- Acceptance criteria:
  - `FR-002-AC-1`: `curl http://<hub-ip>:8123/` returns a 2xx or 3xx status
    from another machine on the LAN.
  - `FR-002-AC-2`: The `home-assistant` container reports a `running` state,
    not a restart loop.

`FR-004` `MUST` The hub's configuration is declared in version-controlled
files in this repository, not configured ad hoc on the machine.

- Level: `MUST`
- Blocked by: `compose/docker-compose.yml` now exists, but `docker compose
  config` has never been observed passing — Docker is not installed on the
  authoring machine, so the compose tier of the suite still SKIPs. Gap:
  GAP-004.
- Acceptance criteria:
  - `FR-004-AC-1`: `compose/docker-compose.yml` exists, is committed, and
    passes `docker compose config`.
  - `FR-004-AC-2`: Every image is pinned to a dated stable tag, never
    `latest`.
  - `FR-004-AC-3`: The Home Assistant config directory is a bind mount from
    the repository-adjacent `config/` path.

`FR-005` `SHOULD` An MQTT broker is available for devices that speak MQTT
rather than a native integration.

- Level: `SHOULD`
- Blocked by: device selection still open; Mosquitto not adopted. Not in the
  gap log, because this is deferred by choice rather than blocked.
- Acceptance criteria:
  - `FR-005-AC-1`: A Mosquitto container is running and Home Assistant's MQTT
    integration reports connected.
  - `FR-005-AC-2`: The broker requires authentication; anonymous access is
    disabled.

`FR-006` `COULD` Node-RED is available as a visual flow editor alongside Home
Assistant.

- Level: `COULD`
- Blocked by: not adopted. Optional.
- Acceptance criteria:
  - `FR-006-AC-1`: Node-RED is reachable on its port and can read and write
    Home Assistant entities.

## Recoverability

`FR-007` `MUST` The Home Assistant configuration is backed up to a machine
other than the hub, and the backup has been restored at least once.

- Level: `MUST`
- Blocked by: no backup job exists, and there is no hub to back up. Gap:
  GAP-005.
- Acceptance criteria:
  - `FR-007-AC-1`: A scheduled job copies the config volume to a separate
    machine, and its last run is verifiable.
  - `FR-007-AC-2`: A restore has been performed from that backup onto a clean
    target and produced a working Home Assistant instance. An untested restore
    does not satisfy this requirement.
  - `FR-007-AC-3`: The Home Assistant backup encryption key is stored off the
    hub.

## Reliability

`NFR-002` `MUST` The hub survives a mains power interruption on battery
without an unclean shutdown.

- Level: `MUST`
- Blocked by: requires the machine and a deliberate power cut. Gap: GAP-006.
- Acceptance criteria:
  - `NFR-002-AC-1`: With mains power removed for 10 minutes, the hub continues
    serving `:8123` uninterrupted.
  - `NFR-002-AC-2`: The battery reports a charge level sufficient to bridge a
    typical outage, and `upower` shows it discharging rather than the host
    powering off.

## Performance

`NFR-003` `SHOULD` The hub runs within the machine's fixed 8 GB of RAM with
headroom, and stays passively cool.

- Level: `SHOULD`
- Blocked by: no baseline can be measured without the machine. Gap: GAP-007.
- Acceptance criteria:
  - `NFR-003-AC-1`: At steady state with the full stack running, used memory
    stays below 6 GB and the machine is not swapping continuously.
  - `NFR-003-AC-2`: The host remains responsive over SSH while Home Assistant
    is processing normal automation load.

## Network Exposure

`NFR-005` `SHOULD` The hub is not exposed directly to the public internet.

- Level: `SHOULD`
- Blocked by: requires manual router inspection; no check is runnable from
  this repository. Gap: GAP-008.
- Acceptance criteria:
  - `NFR-005-AC-1`: No port forward to `:8123` or `:22` exists on the router.
    Remote access, if wanted, goes through a VPN or an authenticated tunnel.

---

## Explicit Non-Goals

- `WON'T` Home Assistant OS or the deprecated Supervised install method. The
  machine stays a general-purpose Linux box — see ADR-0002.
- `WON'T` High availability, clustering, or failover. This is deliberately one
  machine; the battery is the redundancy story.
- `WON'T` Multi-user access control. There is one operator.
- `WON'T` Public internet exposure of the Home Assistant UI (see `NFR-005`).
- `WON'T` Cloud dependencies for core automation. Automations should continue
  working with the internet down.

## Acceptance Criteria Summary

A release is ready when every `MUST` requirement — active **and** deferred — is
`Verified` in the traceability matrix. Deferral is a statement about *when* a
requirement can be checked, never a reduction of what the product must do.

- [ ] All `MUST` requirements have verifying tests and are marked `Verified` in
      `docs/REQUIREMENTS_TRACEABILITY.md`.
- [ ] Every deferred requirement has been promoted to the active section.
- [ ] The hub has run unattended for 7 consecutive days with the lid closed.
- [ ] A restore from backup has been performed successfully at least once
      (`FR-007-AC-2`).
- [ ] `bash scripts/run_tests.sh` passes on the hub with `HUB_HOST` set.

## Traceability

Each requirement above is tracked to its verifying tests and status in
`docs/REQUIREMENTS_TRACEABILITY.md`. Keep the two documents in sync: when a
requirement is added or changed here, update the matrix in the same change.
