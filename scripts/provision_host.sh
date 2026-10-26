#!/usr/bin/env bash
set -euo pipefail

# Root-level host provisioning for the macbook-home-hub (docs/SETUP.md Part 2,
# steps 4 and 6). Everything an agent could do without root has already been
# done by the time this runs; this script is the part that needs sudo, kept in
# one reviewable, idempotent place so it is run on purpose and can be re-run
# safely.
#
# What it does, in order:
#   1. Tell logind to ignore the lid switch (drop-in, not an edit of
#      /etc/systemd/logind.conf, so it survives package upgrades and is
#      removable with one rm).
#   2. Mask the sleep/suspend/hibernate targets.
#   3. Install openssh-server, docker.io, docker-compose-v2 from the distro.
#   4. Enable ssh (socket-activated on Mint 22) and docker to start at boot.
#   5. Add the invoking user to the docker group. Note: membership in
#      `docker` is root-equivalent (the daemon runs as root and will happily
#      bind-mount /). That is accepted here because the same user already
#      holds sudo; see docs/OPERATIONS.md.
#
# What it deliberately does NOT do:
#   - Restart systemd-logind. That can end the graphical session the operator
#     is sitting in. The drop-in takes effect at the next boot, and a reboot is
#     the next step of the procedure anyway (FR-003).
#   - Start the compose stack. That is a separate, visible step.
#
# Usage:
#   sudo bash scripts/provision_host.sh [--force]
#
#   --force  Run on hardware other than a MacBook8,1. Without it the script
#            refuses, because it installs an SSH server and changes power
#            policy — not something to run on the wrong laptop by accident.
#
# Exit status:
#   0  every step applied or already in place
#   1  a step failed (apt, systemctl, ...)
#   2  usage / precondition error (not root, wrong hardware, no SUDO_USER)

force=false
for arg in "$@"; do
  case "$arg" in
    --force) force=true ;;
    -h|--help) awk 'NR>3 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log() { echo "==> $*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo bash $0" >&2
  exit 2
fi

product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
if [ "$product" != "MacBook8,1" ] && [ "$force" != true ]; then
  echo "refusing: this is '$product', not a MacBook8,1 (pass --force to override)" >&2
  exit 2
fi

target_user=${SUDO_USER:-}
if [ -z "$target_user" ] || [ "$target_user" = root ]; then
  echo "SUDO_USER is unset or root; run via sudo from the operator's account" >&2
  exit 2
fi

# --- 1. logind: ignore the lid ---------------------------------------------
dropin_dir=/etc/systemd/logind.conf.d
dropin=$dropin_dir/50-macbook-home-hub.conf
want=$(cat <<'CONF'
# Installed by scripts/provision_host.sh (macbook-home-hub).
# This laptop is an always-on hub; closing the lid must not suspend it.
# Rationale: docs/OPERATIONS.md, "Keep running with the lid closed".
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
CONF
)
if [ -f "$dropin" ] && [ "$(cat "$dropin")" = "$want" ]; then
  log "logind drop-in already in place: $dropin"
else
  log "writing logind drop-in: $dropin"
  mkdir -p "$dropin_dir"
  printf '%s\n' "$want" > "$dropin"
fi

# --- 2. mask sleep targets --------------------------------------------------
targets="sleep.target suspend.target hibernate.target hybrid-sleep.target"
# shellcheck disable=SC2086
log "masking: $targets"
# shellcheck disable=SC2086
systemctl mask $targets

# --- 3. packages ------------------------------------------------------------
# docker-compose-v2 is the Ubuntu 24.04 (Mint 22) package that provides the
# `docker compose` subcommand; the name `docker-compose-plugin` belongs to
# Docker's own apt repository, which this host does not use.
pkgs="openssh-server docker.io docker-compose-v2"
log "installing: $pkgs"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# shellcheck disable=SC2086
apt-get install -y -qq $pkgs

# --- 4. services at boot ----------------------------------------------------
# Ubuntu 24.04 / Mint 22 ship sshd socket-activated: the package enables
# ssh.socket and ssh.service is started on demand (ssh.socket has
# RequiredBy=ssh.service). Enable the unit the distro means, rather than
# forcing ssh.service alongside a socket that is already bound to :22.
log "enabling ssh.socket and docker"
systemctl enable --now ssh.socket docker

# --- 5. docker group --------------------------------------------------------
if id -nG "$target_user" | tr ' ' '\n' | grep -qx docker; then
  log "$target_user already in docker group"
else
  log "adding $target_user to docker group"
  usermod -aG docker "$target_user"
fi

cat <<EOT

Done. Still to do, by hand:
  1. Log out and back in (or reboot) so the docker group membership applies.
  2. sudo reboot — applies the logind drop-in and is the FR-003 test anyway.
  3. After reboot:  bash scripts/check_host_config.sh
  4. Then:          docker compose -f compose/docker-compose.yml up -d
EOT
