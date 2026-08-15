# Environment & Configuration Contract

This document lists all environment variables required or optionally supported
by this project. It acts as the single source of truth for configuration
parameters.

> [!IMPORTANT]
> If you add a new environment variable to a manifest (like `.env.example` or
> `docker-compose.yml`), you **must** document it in this file in the same pull
> request. `constitution/scripts/check_env_vars.sh` cross-checks root-level
> manifests against this document.

## Current State

The compose stack lives at `compose/docker-compose.yml` and declares one
environment variable (`TZ`). `constitution/scripts/check_env_vars.sh` only
reads **root-level** `docker-compose.yml`, so it still reports "no declared
environment variables found" for this repo — that is a tooling limitation,
not an oversight. The variables below are documented here for human accuracy
and stay in sync with the compose file by hand.

## Required Variables

None — the compose file uses no mandatory variables.

## Optional Variables

| Variable | Purpose | Sensitive | Notes |
| --- | --- | --- | --- |
| `TZ` | Container timezone; keeps automation schedules and log timestamps aligned with local time | No | Home Assistant automations are time-driven, so a wrong `TZ` produces silently wrong behavior rather than an error. Currently set to `America/Los_Angeles` in `compose/docker-compose.yml`; edit to your local timezone. |

## Anticipated Variables

These are **not yet in effect**. They are recorded here so the compose file and
this document can drift together rather than apart, and so the secret-handling
decision is made before a secret exists.

| Variable | Purpose | Sensitive | Notes |
| --- | --- | --- | --- |
| `HA_CONFIG_PATH` | Host path bind-mounted to the Home Assistant config directory | No | Defaults to `./config`; lets the stack be relocated without editing the compose file |
| `PUID` / `PGID` | Ownership of bind-mounted config files | No | Prevents root-owned files appearing in the working tree |
| `MQTT_USERNAME` | Mosquitto broker account, if MQTT is adopted | No | Pairs with `MQTT_PASSWORD` |
| `MQTT_PASSWORD` | Mosquitto broker credential | **Yes** | Must come from an untracked `.env`, never a committed compose file |

## Secret Handling

Rules that apply the moment the first sensitive value above becomes real:

- Secrets live in `.env`, which is gitignored. `.env.example` is committed and
  holds **placeholder values only** — never a working credential.
- Home Assistant's own secrets belong in `config/secrets.yaml`, which is
  gitignored, and are referenced from tracked YAML with `!secret`.
- The Home Assistant backup encryption key is stored **off the hub**. A backup
  encrypted with a key that only exists on the machine the backup protects is
  not a backup. See `docs/OPERATIONS.md`.
- `constitution/scripts/check_secrets.sh` runs as a pre-push hook and sweeps
  for credential-shaped filenames and content patterns.
