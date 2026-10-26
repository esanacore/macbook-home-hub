#!/usr/bin/env bash
set -uo pipefail

# Verify the always-on host configuration this hub depends on, without root.
#
# This is the executable form of FR-001-AC-2/AC-3 (sleep targets masked, lid
# switch ignored) plus the two services the rest of the stack assumes (SSH for
# administration, Docker for the compose stack). It reads the *live* state —
# logind's properties over D-Bus, systemd unit states — not config files, so
# a drop-in that was written but never applied is reported as not applied.
#
# Checks:
#   logind    HandleLidSwitch, HandleLidSwitchExternalPower and
#             HandleLidSwitchDocked all resolve to "ignore". An empty
#             ExternalPower value inherits HandleLidSwitch, so empty is accepted
#             only when HandleLidSwitch is already "ignore".
#   sleep     sleep/suspend/hibernate/hybrid-sleep targets are masked.
#   docker    `docker` on PATH, `docker compose` works, docker.service enabled,
#             current user in the docker group.
#   ssh       ssh.socket (Mint 22 default) or ssh.service enabled.
#   xfpm      (informational) XFCE power manager lid actions are "nothing" and
#             idle inactivity is "never". SKIPs when xfconf is not reachable.
#
# Usage:
#   bash scripts/check_host_config.sh
#
# Exit status:
#   0  every executed check passed
#   1  at least one check failed
#
# Testability: everything external goes through `busctl`, `systemctl`,
# `docker`, `id` and `xfconf-query` found on PATH, so unit tests substitute
# fakes by prepending a directory to PATH (see test_check_host_config.sh).

fail=0
ok()   { echo "  OK    $*"; }
bad()  { echo "  FAIL  $*"; fail=1; }
skip() { echo "  SKIP  $*"; }

echo "Host configuration check"

# --- logind -----------------------------------------------------------------
lid_prop() {
  busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
    org.freedesktop.login1.Manager "$1" 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p'
}
if ! command -v busctl >/dev/null 2>&1; then
  bad "busctl not available; cannot read logind lid policy"
else
  lid=$(lid_prop HandleLidSwitch)
  ext=$(lid_prop HandleLidSwitchExternalPower)
  dock=$(lid_prop HandleLidSwitchDocked)
  [ "$ext" = "" ] && ext=$lid
  for pair in "HandleLidSwitch=$lid" "HandleLidSwitchExternalPower=$ext" "HandleLidSwitchDocked=$dock"; do
    if [ "${pair#*=}" = ignore ]; then
      ok "logind ${pair}"
    else
      bad "logind ${pair} (want ignore; written drop-ins apply after reboot or logind restart)"
    fi
  done
fi

# --- sleep targets ----------------------------------------------------------
for t in sleep.target suspend.target hibernate.target hybrid-sleep.target; do
  state=$(systemctl is-enabled "$t" 2>/dev/null || true)
  if [ "$state" = masked ]; then
    ok "$t masked"
  else
    bad "$t is '${state:-unknown}' (want masked)"
  fi
done

# --- docker -----------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  ok "docker on PATH"
  if docker compose version >/dev/null 2>&1; then
    ok "docker compose available"
  else
    bad "docker compose not available (install docker-compose-v2)"
  fi
else
  bad "docker not installed"
fi
state=$(systemctl is-enabled docker 2>/dev/null || true)
if [ "$state" = enabled ]; then ok "docker.service enabled"; else bad "docker.service is '${state:-unknown}' (want enabled)"; fi
if id -nG | tr ' ' '\n' | grep -qx docker; then
  ok "current user in docker group"
else
  bad "current user not in docker group (usermod -aG docker, then log in again)"
fi

# --- ssh --------------------------------------------------------------------
# Mint 22 / Ubuntu 24.04 enable ssh.socket (socket activation) rather than
# ssh.service; older or hand-configured hosts enable ssh.service. Either is a
# server that answers on :22 at boot.
sock=$(systemctl is-enabled ssh.socket 2>/dev/null || true)
svc=$(systemctl is-enabled ssh 2>/dev/null || true)
if [ "$sock" = enabled ]; then
  ok "ssh.socket enabled (socket-activated sshd)"
elif [ "$svc" = enabled ]; then
  ok "ssh.service enabled"
else
  bad "sshd not enabled at boot (ssh.socket is '${sock:-unknown}', ssh.service is '${svc:-unknown}')"
fi

# --- XFCE power manager (informational) ------------------------------------
if command -v xfconf-query >/dev/null 2>&1 \
   && xfconf-query -c xfce4-power-manager -l >/dev/null 2>&1; then
  xq() { xfconf-query -c xfce4-power-manager -p "/xfce4-power-manager/$1" 2>/dev/null; }
  for p in lid-action-on-ac lid-action-on-battery; do
    v=$(xq "$p"); if [ "$v" = 0 ]; then ok "xfpm $p=0 (nothing)"; else bad "xfpm $p='${v:-unset}' (want 0)"; fi
  done
  for p in inactivity-on-ac inactivity-on-battery; do
    v=$(xq "$p"); if [ "$v" = 14 ]; then ok "xfpm $p=14 (never)"; else bad "xfpm $p='${v:-unset}' (want 14)"; fi
  done
else
  skip "xfce4-power-manager settings (xfconf not reachable from this session)"
fi

if [ "$fail" -ne 0 ]; then
  echo "Host configuration check FAILED"
  exit 1
fi
echo "Host configuration check PASSED"
