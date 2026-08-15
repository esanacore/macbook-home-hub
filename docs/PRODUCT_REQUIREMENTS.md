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

## Functional Requirements

### Always-On Host

**FR-001** `MUST` The host continues running and stays reachable on the network
with the lid closed and no user logged in.

- Level: `MUST`
- Acceptance criteria:
  - `FR-001-AC-1`: With the lid closed for at least 30 minutes, the host
    answers SSH on port 22.
  - `FR-001-AC-2`: `systemd-inhibit --list` shows no pending sleep or suspend
    inhibitor that would suspend the machine.
  - `FR-001-AC-3`: `sleep.target`, `suspend.target`, `hibernate.target`, and
    `hybrid-sleep.target` all report `masked`.

**FR-003** `MUST` The service stack returns automatically after a host reboot
or unclean power loss, with no manual step.

- Level: `MUST`
- Acceptance criteria:
  - `FR-003-AC-1`: After `sudo reboot`, Home Assistant answers on `:8123`
    within 5 minutes with no human intervention.
  - `FR-003-AC-2`: Every service in the compose file declares a restart policy
    of `unless-stopped` or `always`.

### Home Assistant Service

**FR-002** `MUST` Home Assistant is reachable over HTTP on port 8123 from the
LAN.

- Level: `MUST`
- Acceptance criteria:
  - `FR-002-AC-1`: `curl http://<hub-ip>:8123/` returns a 2xx or 3xx status
    from another machine on the LAN.
  - `FR-002-AC-2`: The `home-assistant` container reports a `running` state,
    not a restart loop.

**FR-004** `MUST` The hub's configuration is declared in version-controlled
files in this repository, not configured ad hoc on the machine.

- Level: `MUST`
- Acceptance criteria:
  - `FR-004-AC-1`: `compose/docker-compose.yml` exists, is committed, and
    passes `docker compose config`.
  - `FR-004-AC-2`: Every image is pinned to a dated stable tag, never
    `latest`.
  - `FR-004-AC-3`: The Home Assistant config directory is a bind mount from
    the repository-adjacent `config/` path.

**FR-005** `SHOULD` An MQTT broker is available for devices that speak MQTT
rather than a native integration.

- Level: `SHOULD`
- Acceptance criteria:
  - `FR-005-AC-1`: A Mosquitto container is running and Home Assistant's MQTT
    integration reports connected.
  - `FR-005-AC-2`: The broker requires authentication; anonymous access is
    disabled.

**FR-006** `COULD` Node-RED is available as a visual flow editor alongside Home
Assistant.

- Level: `COULD`
- Acceptance criteria:
  - `FR-006-AC-1`: Node-RED is reachable on its port and can read and write
    Home Assistant entities.

### Recoverability

**FR-007** `MUST` The Home Assistant configuration is backed up to a machine
other than the hub, and the backup has been restored at least once.

- Level: `MUST`
- Acceptance criteria:
  - `FR-007-AC-1`: A scheduled job copies the config volume to a separate
    machine, and its last run is verifiable.
  - `FR-007-AC-2`: A restore has been performed from that backup onto a clean
    target and produced a working Home Assistant instance. An untested restore
    does not satisfy this requirement.
  - `FR-007-AC-3`: The Home Assistant backup encryption key is stored off the
    hub.

## Non-Functional Requirements

### Security

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

**NFR-005** `SHOULD` The hub is not exposed directly to the public internet.

- Level: `SHOULD`
- Acceptance criteria:
  - `NFR-005-AC-1`: No port forward to `:8123` or `:22` exists on the router.
    Remote access, if wanted, goes through a VPN or an authenticated tunnel.

### Reliability

**NFR-002** `MUST` The hub survives a mains power interruption on battery
without an unclean shutdown.

- Level: `MUST`
- Acceptance criteria:
  - `NFR-002-AC-1`: With mains power removed for 10 minutes, the hub continues
    serving `:8123` uninterrupted.
  - `NFR-002-AC-2`: The battery reports a charge level sufficient to bridge a
    typical outage, and `upower` shows it discharging rather than the host
    powering off.

### Performance

**NFR-003** `SHOULD` The hub runs within the machine's fixed 8 GB of RAM with
headroom, and stays passively cool.

- Level: `SHOULD`
- Acceptance criteria:
  - `NFR-003-AC-1`: At steady state with the full stack running, used memory
    stays below 6 GB and the machine is not swapping continuously.
  - `NFR-003-AC-2`: The host remains responsive over SSH while Home Assistant
    is processing normal automation load.

### Testability

**NFR-004** `MUST` The hub's health is verifiable by running a single command
rather than by manual inspection.

- Level: `MUST`
- Acceptance criteria:
  - `NFR-004-AC-1`: `bash scripts/run_tests.sh` executes the full declared
    suite and returns a non-zero exit status if any executed check fails.
  - `NFR-004-AC-2`: Checks that cannot run in the current environment report
    `SKIP` and are never counted as passes.

## Explicit Non-Goals

- `WON'T` Home Assistant OS or the deprecated Supervised install method. The
  machine stays a general-purpose Linux box — see ADR-0002.
- `WON'T` High availability, clustering, or failover. This is deliberately one
  machine; the battery is the redundancy story.
- `WON'T` Multi-user access control. There is one operator.
- `WON'T` Public internet exposure of the Home Assistant UI (see NFR-005).
- `WON'T` Cloud dependencies for core automation. Automations should continue
  working with the internet down.

## Acceptance Criteria Summary

Release-level acceptance criteria roll up the per-requirement criteria above.
A release is ready when every `MUST` requirement is `Verified` in the
traceability matrix.

- [ ] All `MUST` requirements have verifying tests and are marked `Verified` in
      `docs/REQUIREMENTS_TRACEABILITY.md`.
- [ ] The hub has run unattended for 7 consecutive days with the lid closed.
- [ ] A restore from backup has been performed successfully at least once
      (FR-007-AC-2).
- [ ] `bash scripts/run_tests.sh` passes on the hub with `HUB_HOST` set.

## Traceability

Each requirement above is tracked to its verifying tests and status in
`docs/REQUIREMENTS_TRACEABILITY.md`. Keep the two documents in sync: when a
requirement is added or changed here, update the matrix in the same change.
