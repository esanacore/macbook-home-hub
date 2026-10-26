# Command Reference

Quick reference for the commands used to operate this project. This is a
configuration and operations repository — there is no build step and no
application code of our own, so the commands here are Docker, systemd, and
governance checks rather than a language toolchain.

Commands marked **(not yet run)** exist in the repository but have not been
executed on the hub yet; see `TODO.md`.

## Repository

```bash
# Clone with the constitution submodule in one step
git clone --recurse-submodules <repository-url>

# Existing clone missing the constitution/ directory
git submodule update --init --recursive
```

## Governance Checks

These run today and need no hardware. Run them from the repository root.

```bash
bash constitution/scripts/check_compliance.sh              # required/recommended docs present and filled
bash constitution/scripts/check_secrets.sh                 # credential sweep + .gitignore coverage
bash constitution/scripts/check_traceability.sh            # requirements -> verifying tests
bash constitution/scripts/check_ots_inventory.sh           # manifest deps vs docs/OTS_SOFTWARE.md
bash constitution/scripts/check_env_vars.sh                # declared env vars vs docs/ENV_VARS.md
bash constitution/scripts/check_architecture.sh            # layer boundaries (opt-in; N/A here)
bash constitution/scripts/check_version_alignment.sh       # stale constitution version references
bash constitution/scripts/check_constitution_freshness.sh  # submodule vs upstream release
bash constitution/scripts/run_declared_tests.sh            # runs the suite declared in docs/TEST_PLAN.md
```

Doc freshness compares two refs, so it takes arguments:

```bash
bash constitution/scripts/check_doc_freshness.sh --base origin/master --head HEAD
```

## Pre-commit Hooks

```bash
uv tool install pre-commit                # Mint ships no pip; uv installs to ~/.local/bin
pre-commit install                        # commit-stage hooks
pre-commit install --hook-type pre-push   # required for the secrets sweep
pre-commit run --all-files                # run everything once
```

The secrets sweep is bound to the **pre-push** stage, so the second `install`
is not optional — without it, the sweep never runs.

## Host Provisioning

Run from the repository root, on the hub.

```bash
sudo bash scripts/provision_host.sh     # logind drop-in, mask sleep targets, install ssh + docker (idempotent)
bash scripts/check_host_config.sh       # verify the live state, no root needed
bash scripts/test_check_host_config.sh  # the checker's own unit tests (run anywhere)
```

## Service Stack (not yet run)

Run from the repository root; the `-f` keeps the config bind mount pointed at
the root `config/` directory.

```bash
docker compose -f compose/docker-compose.yml up -d                    # bring the stack up
docker compose -f compose/docker-compose.yml ps                       # what is running
docker compose -f compose/docker-compose.yml logs -f home-assistant   # follow HA logs
docker compose -f compose/docker-compose.yml pull && docker compose -f compose/docker-compose.yml up -d   # update to the pinned tags
docker compose -f compose/docker-compose.yml down                     # stop the stack (volumes preserved)
docker compose -f compose/docker-compose.yml config --quiet           # validate compose syntax without starting
```

Rollback is a git operation, not a Docker one: revert the compose file to the
previous commit and re-run `docker compose up -d`. See `docs/OPERATIONS.md`.

## Host Operations

```bash
# Always-on verification
systemd-inhibit --list                  # confirm nothing will suspend the box
systemctl status systemd-logind

# Lid-switch config lives in /etc/systemd/logind.conf.d/50-macbook-home-hub.conf
# (written by scripts/provision_host.sh). Applies at next boot, or sooner with:
sudo systemctl restart systemd-logind   # may end the graphical session; use SSH or a console
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch   # live value

# Block idle sleep entirely
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Health
journalctl -u docker --since "1 hour ago"
free -h                                 # 8 GB soldered; watch for pressure
upower -i $(upower -e | grep BAT)       # battery-as-UPS state
```

## Reachability

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://<hub-ip>:8123   # expect 200
ssh <user>@<hub-ip>                     # this hub: esanacore@192.168.1.192 (peppermint-patty)
```
