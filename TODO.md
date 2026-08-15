# TODO

This file is the living roadmap for the project.

Keep entries specific, actionable, and current.

## Provisioning (host)

- [ ] Flash Linux Mint XFCE live USB; confirm boot on the MacBook8,1 via USB-C hub.
- [ ] Have a USB Ethernet or known-good USB Wi-Fi dongle ready for the install
      (Broadcom BCM4350 driver gap in the live installer).
- [ ] Install to internal SSD; install the `broadcom-wl` / `wl` driver post-install.
- [ ] Apply always-on config: `HandleLidSwitch*=ignore`, mask sleep targets
      (see `docs/OPERATIONS.md`); verify box stays reachable with lid closed.
- [ ] Check whether a battery charge-limit control is exposed under Linux on
      this model; record the answer in `docs/OPERATIONS.md`.

## Services (stack)

- [ ] Install Docker Engine + Compose plugin.
- [ ] Author `compose/docker-compose.yml` with Home Assistant Container,
      pinned to a dated stable image tag; bind-mount `config/`.
- [ ] Bring HA up, complete onboarding, confirm reachable at `:8123`.
- [ ] Decide whether Mosquitto (MQTT) is needed based on chosen devices; add
      container if so.
- [ ] Evaluate Node-RED as optional flow editor.

## Home automation (decisions still open)

- [ ] Decide the first real automation use case (the "not sure how yet" item).
- [ ] Choose initial devices (candidates already in play: Shelly Pro 4PM,
      Kauf PLF12 smart plugs).

## Operations

- [ ] Stand up a backup job for the HA config volume to another machine; store
      the HA backup encryption key off the hub.
- [ ] Decide on basic alerting (even just "hub unreachable") — none yet.

## Testing

- [x] Define what "tests" mean for a config repo — declared in
      `docs/TEST_PLAN.md`, implemented as `scripts/run_tests.sh` (static +
      config tiers) and `scripts/smoke_check.sh` (host tier).
- [ ] Execute `scripts/smoke_check.sh` against the real hub. It is written but
      has never run against hardware, so FR-002 stays a gap (GAP-002).
- [ ] Close GAP-001: verify the host stays reachable 30+ min with the lid
      closed (FR-001).
- [ ] Close GAP-003: verify the stack returns unattended after `sudo reboot`
      (FR-003).
- [ ] Close GAP-004: author `compose/docker-compose.yml` so the compose tier
      of the suite stops skipping (FR-004).
- [ ] Close GAP-005: perform a real restore from backup onto a clean target
      (FR-007). An untested restore is not a backup.
- [ ] Close GAP-006: pull mains power for 10 minutes and confirm the hub keeps
      serving on battery (NFR-002).
- [ ] Close GAP-007: measure steady-state memory under real automation load
      and record the baseline (NFR-003).
- [ ] Close GAP-008: confirm no router port-forward exposes `:8123` or `:22`
      (NFR-005).

## Documentation

- [ ] Replace `docs/SETUP.md` Part 2 (currently marked **unverified**) with
      the commands actually typed during the first real provisioning run, not
      the anticipated ones.
- [ ] Rewrite the **(anticipated)** entries in `docs/TROUBLESHOOTING.md` with
      observed symptoms once the machine has been through a real install.
- [ ] Record the battery charge-limit finding in `docs/OPERATIONS.md` once
      checked (either way — confirming its absence is a valid result).
- [ ] Move `docs/OTS_SOFTWARE.md` entries from `Evaluating` to `Active` as
      each component is actually deployed and its verification observed.

## Tooling & Compliance

- [ ] Install and activate the pre-commit hooks on this machine:
      `pip install pre-commit && pre-commit install && pre-commit install --hook-type pre-push`.
      The config exists but the hooks are inactive, so the secrets sweep is
      not currently enforced on push.
- [ ] Enable branch protection and "Automatically delete head branches" in the
      hosting platform settings (see `constitution/INTEGRATION.md`,
      "Repository Settings Checklist"). Not yet done.
- [ ] Run `/setup-gbrain` once in this repository to initialize the gstack
      project brain.
- [ ] Decide whether to keep `.constitution-bootstrap/` now that adoption is
      complete, or delete it as the report itself suggests.

## Nice-to-Have

- [ ] Tie in existing hardware interests (e.g. the CleverPet/hackerpet cat
      setup) as HA integrations once the hub is stable.
