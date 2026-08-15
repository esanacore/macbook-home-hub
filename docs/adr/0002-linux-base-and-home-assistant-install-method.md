# ADR: Linux base OS and Home Assistant installation method

Status: Accepted

Date: 2026-08-15

## Relationships

- Extends: none
- Supersedes: none
- Related: ADR-0001 (record architecture decisions)

## Context

The `MacBook8,1` is a fanless, dual-core Core M (Broadwell) machine with 8 GB
of soldered RAM and a single USB-C port. It will serve two overlapping roles:
a general Linux box to tinker on, and an always-on Home Assistant hub. Those
roles pull in opposite directions — a tinkering box wants a full, mutable,
general-purpose OS; an appliance hub wants something locked down and
hands-off.

Constraints and forces:

- Weak CPU and limited, non-upgradeable RAM favor a lightweight desktop and
  minimal background services.
- The Broadcom BCM4350 Wi-Fi chip needs a proprietary driver not present in
  most live installers, so first-boot networking is a known friction point.
- Home Assistant, as of 2026, officially supports only two install methods:
  Home Assistant OS (a dedicated appliance image that takes the whole disk)
  and Home Assistant Container (a Docker container on a host you manage). The
  older Supervised method was deprecated in 2025 and is now unsupported.

## Decision

Run a lightweight general-purpose Linux distribution — **Linux Mint XFCE** as
the leading choice, with Fedora XFCE as the fallback — as the host OS, and run
**Home Assistant via the Container (Docker) method** on top of it.

Mint XFCE is chosen over Fedora primarily for smoother out-of-the-box handling
of the Broadcom Wi-Fi driver; Fedora remains an acceptable substitute if a
newer kernel or package set is wanted.

## Consequences

Positive:

- The machine stays a real, mutable Linux box: SSH in, break things, rebuild,
  run other containers alongside Home Assistant.
- Home Assistant is one container in a `docker-compose` stack, versioned in
  this repo, rather than an opaque appliance image.
- XFCE keeps idle resource use low on the weak CPU and small RAM.

Negative / trade-offs:

- The Container method omits the Supervisor, so there is no add-on store, no
  built-in backup manager, and no one-click updates. Companion services
  (MQTT broker, Node-RED, Zigbee/Z-Wave bridges) become separately managed
  containers, and backups must be arranged explicitly. This is tracked in
  `TODO.md` and `docs/OPERATIONS.md`.
- Maintaining a full host OS is more surface area than an appliance image.

## Alternatives Considered

- **Home Assistant OS (appliance) on bare metal.** Rejected: it turns the
  machine into a single-purpose appliance, which defeats the tinkering goal.
  It is the right call for a dedicated Pi/NUC, not for this box.
- **Home Assistant Supervised.** Rejected: deprecated in 2025 and unsupported
  going forward; issue reports against it are no longer accepted.
- **Home Assistant Core in a Python venv.** Rejected: manual everything, no
  isolation, and awkward to reproduce; aimed at contributors, not operators.
