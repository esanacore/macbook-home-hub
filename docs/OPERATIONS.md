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
every time it is tucked on a shelf. In `/etc/systemd/logind.conf` set:

```ini
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

Then `sudo systemctl restart systemd-logind` (note: restarting logind can end
the current graphical session — do it from a console or over SSH). Verify with
`systemd-inhibit --list` and by closing the lid and confirming the box stays
reachable over SSH.

### Battery longevity

The built-in battery is the hub's UPS, which is the reason to run on this
machine at all. But a laptop held at 100% on constant AC ages the cell fast.
On this Broadwell MacBook a charge-limit control is **not** reliably exposed
under Linux, so do not assume one exists — check for it during setup and, if
absent, treat battery wear as expected and plan to replace the cell rather than
prevent the wear. Track the outcome of that check in `TODO.md`.

### Disable unnecessary sleep/hibernate

Beyond the lid switch, confirm the system does not auto-suspend on idle:
`sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`
(reversible with `unmask`).

## Deployment

- **Deployment procedure**: the service stack is defined in `compose/`
  (planned). Deploy with `docker compose up -d`; update with
  `docker compose pull && docker compose up -d`.
- **Rollback**: keep the previous known-good image tags pinned in the compose
  file. Roll back by reverting the compose file to the previous commit and
  re-running `docker compose up -d`.

## Monitoring & Observability

- **Logs**: `docker compose logs -f home-assistant`; host logs via
  `journalctl`.
- **Reachability**: Home Assistant UI on `http://<hub-ip>:8123`; SSH on 22.
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
