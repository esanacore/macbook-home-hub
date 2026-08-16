# Home

Welcome to the **macbook-home-hub** wiki. Wiki pages are authored under
`wiki/` in this repository and reviewed through normal pull requests.

## What this project does

Turns a 2015 12-inch Retina MacBook (`MacBook8,1`, fanless Core M, 8 GB
soldered RAM, single USB-C) into a silent, always-on Linux tinkering box that
doubles as a home-automation hub running Home Assistant in Docker. The
machine's quirk is its strength: the built-in battery acts as a free UPS, so
the hub rides through power blips that would hard-cut a Pi or NUC.

## Current status

Early. The Linux base and the Home Assistant install method are decided (see
`docs/adr/`) — lightweight Linux base + Home Assistant Container, not Home
Assistant OS. The repo documents the hardware's Linux-specific gotchas
(Broadcom BCM4350 Wi-Fi, lid-switch suspend, battery longevity), holds the
operational runbook, and defines 12 requirements with acceptance criteria
tracked to verifying checks. Not yet: an actual `docker-compose.yml` or
provisioning scripts.

## Getting started

See `docs/SETUP.md`, and run the check suite with
`bash scripts/run_tests.sh` (governance and secret sweeps today).

## Where things live

- `docs/` — ADRs, runbook, requirements, and traceability
- `scripts/` — the check suite and future smoke checks
- `constitution/` — Eric's Engineering Constitution submodule (read-only)

## See also

- `docs/HELP.md` — common questions and troubleshooting
- `docs/PRODUCT_REQUIREMENTS.md` — the 12 requirements
