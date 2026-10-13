# Operations

Operational runbook for running the `MacBook8,1` as an always-on Home
Assistant hub. The recurring theme: this is laptop hardware doing server duty,
so the defaults that make sense for a laptop (sleep on lid close, charge to
100% and hold) are wrong here and must be overridden.

## Environments

- **local (the hub itself)**: the single production environment. There is no
  staging; changes to the compose stack are tested by bringing containers up
  on the same box and rolling back the compose file if they misbehave.

## Always-On Configuration

These are prerequisites for the machine to function as a hub, not optional
tuning.

### Keep running with the lid closed

By default the machine suspends when the lid closes, which would kill the hub
every time it is tucked on a shelf. Two policies are involved and both must be
set:

1. **logind** (system-wide; the only policy in force when nobody is logged
   in). `scripts/provision_host.sh` installs the drop-in
   `/etc/systemd/logind.conf.d/50-macbook-home-hub.conf`:

   ```ini
   [Login]
   HandleLidSwitch=ignore
   HandleLidSwitchExternalPower=ignore
   HandleLidSwitchDocked=ignore
   ```

   A drop-in survives package upgrades of `logind.conf` and is removed with
   one `rm`. It takes effect at the next boot; `sudo systemctl restart
   systemd-logind` applies it sooner but can end the current graphical
   session, so only do that from a console or over SSH.
2. **XFCE power manager** (per user; active whenever that user's desktop
   session is up). It takes a `handle-lid-switch` inhibitor on logind and
   applies its own lid action instead, so it has to be told "nothing" too:
   `lid-action-on-ac=0`, `lid-action-on-battery=0`, `inactivity-on-*=14`
   (never), `logind-handle-lid-switch=false`. Exact commands in
   `docs/SETUP.md` step 4.

Verify the live state with `bash scripts/check_host_config.sh` (reads logind's
properties over D-Bus and the systemd unit states — a drop-in that was written
but not yet applied shows as FAIL, which is correct), with
`systemd-inhibit --list`, and finally by closing the lid and confirming the
box stays reachable over SSH for 30 minutes (FR-001-AC-1).

### Battery longevity

The built-in battery is the hub's UPS, which is the reason to run on this
machine at all. But a laptop held at 100% on constant AC ages the cell fast.
**Checked 2026-10-12 on the installed machine: no charge-limit control is
exposed.** `/sys/class/power_supply/BAT0/` offers `charge_full`,
`charge_full_design` and `charge_now` only — no `charge_control_start_threshold`
/ `charge_control_end_threshold`, and no vendor platform driver provides one for
this model. So battery wear is expected, not preventable: plan to replace the
cell rather than prevent the wear.

Baseline at install, for trend-watching:

| Field | Value |
| --- | --- |
| Pack | SMP `bq20z451` |
| Cycle count | 397 |
| `charge_full` | 3885 mAh |
| `charge_full_design` | 5297 mAh |
| Health | 73% of design |

Re-read `cycle_count` and `charge_full` a few times a year; a steep drop means
the UPS story (NFR-002) is weakening and the 10-minute outage test should be
repeated.

### Disable unnecessary sleep/hibernate

Beyond the lid switch, confirm the system does not auto-suspend on idle:
`sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`
(reversible with `unmask`). `scripts/provision_host.sh` does this;
`scripts/check_host_config.sh` confirms all four report `masked`.

## Deployment

- **Host provisioning**: `sudo bash scripts/provision_host.sh` (idempotent;
  refuses to run on anything but a `MacBook8,1` without `--force`). Verify with
  `bash scripts/check_host_config.sh`.
- **Privilege note**: `provision_host.sh` adds the operator to the `docker`
  group, which is root-equivalent (the daemon runs as root). Acceptable here
  because that one account already holds `sudo` and nobody else has a login;
  do not add further accounts to `docker` without the same reasoning.
- **Deployment procedure**: the service stack is defined in
  `compose/docker-compose.yml`. From the repository root, deploy with
  `docker compose -f compose/docker-compose.yml up -d`; update with
  `docker compose -f compose/docker-compose.yml pull && docker compose -f compose/docker-compose.yml up -d`.
- **Rollback**: keep the previous known-good image tags pinned in the compose
  file. Roll back by reverting the compose file to the previous commit and
  re-running `docker compose up -d`.

## Monitoring & Observability

- **Logs**: `docker compose logs -f home-assistant`; host logs via
  `journalctl`.
- **Reachability**: Home Assistant UI on `http://<hub-ip>:8123`; SSH on 22.
  This hub: `peppermint-patty`, `192.168.1.192` (DHCP; pin a reservation on
  the router so the address stops being an assumption).
- **Alerts**: none configured yet. Tracked in `TODO.md`.

## Safe Operations

- **Backup/Restore**: the Container install has no built-in backup manager, so
  this is manual and **must** be arranged before the hub holds anything you
  care about. At minimum, back up the Home Assistant config volume (the
  `config/` bind mount) on a schedule to another machine. Store the Home
  Assistant backup encryption key somewhere off the hub. Tracked in `TODO.md`.
- **Stateful changes**: Home Assistant version upgrades can migrate the config
  database. Snapshot the config volume before a major upgrade.

## Incident Response

1. Confirm scope: is the host down, or just a container?
   `ping` the host, then `docker ps`.
2. If the host is unreachable but powered, connect a USB-C hub with keyboard
   and check locally — Wi-Fi driver drops are the usual suspect on this
   hardware.
3. Check `docker compose logs` and recent commits to the compose/config files.
4. Roll back the compose/config change if a recent one correlates.
