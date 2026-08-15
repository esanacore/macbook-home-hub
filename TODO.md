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

- [ ] Define what "tests" mean for a config repo: a smoke check that the
      compose stack comes up and HA answers on `:8123` (declare in
      `docs/TEST_PLAN.md`).

## Documentation

- [ ] Fill `docs/SETUP.md` with the concrete step-by-step install once the
      first real provisioning run is done (capture actual commands, not
      assumptions).

## Nice-to-Have

- [ ] Tie in existing hardware interests (e.g. the CleverPet/hackerpet cat
      setup) as HA integrations once the hub is stable.
