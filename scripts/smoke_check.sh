#!/usr/bin/env bash
set -uo pipefail

# Smoke check for the running hub: is the stack up, and is Home Assistant
# actually serving?
#
# This is the closest thing this repository has to an end-to-end test. It
# verifies the two facts everything else depends on (FR-002, NFR-002 in
# docs/PRODUCT_REQUIREMENTS.md): the host answers, and Home Assistant returns
# HTTP on :8123.
#
# It checks a *running* system and cannot be run in CI against nothing — it
# requires HUB_HOST to name a reachable hub.
#
# Usage:
#   HUB_HOST=192.168.1.50 bash scripts/smoke_check.sh
#   HUB_HOST=hub.local HA_PORT=8123 bash scripts/smoke_check.sh
#
# Exit status:
#   0  host reachable and Home Assistant answered
#   1  a check failed
#   2  usage error (HUB_HOST not set)

host=${HUB_HOST:-}
port=${HA_PORT:-8123}
timeout=${SMOKE_TIMEOUT:-10}

if [ -z "$host" ]; then
  echo "usage: HUB_HOST=<hub-ip-or-name> bash scripts/smoke_check.sh" >&2
  exit 2
fi

failures=0

echo "Smoke check against ${host}:${port}"

# 1. Host reachable. Ping can be blocked by firewall without the hub being
#    down, so a failure here is a warning that contextualizes step 2 rather
#    than a failure on its own.
if ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
  echo "  OK    host responds to ping"
else
  echo "  WARN  host does not respond to ping (may be firewalled; continuing)"
fi

# 2. Home Assistant serves HTTP. This is the check that matters.
#    HA redirects unauthenticated requests to onboarding or the login page, so
#    any 2xx/3xx means the application is up. A connection refusal means it is
#    not.
code=$(curl -sS -o /dev/null -w '%{http_code}' \
  --max-time "$timeout" "http://${host}:${port}/" 2>/dev/null) || code="000"

case "$code" in
  2??|3??)
    echo "  OK    Home Assistant answered on :${port} (HTTP ${code})"
    ;;
  000)
    echo "  FAIL  no HTTP response from :${port} (connection refused or timed out)"
    failures=$((failures + 1))
    ;;
  *)
    echo "  FAIL  Home Assistant returned HTTP ${code} on :${port}"
    failures=$((failures + 1))
    ;;
esac

# 3. If we are running ON the hub, also confirm the containers are up. Off-host
#    this is not knowable, so it is skipped rather than assumed.
if [ -f compose/docker-compose.yml ] && command -v docker >/dev/null 2>&1; then
  if docker compose -f compose/docker-compose.yml ps --status running 2>/dev/null | grep -q home-assistant; then
    echo "  OK    home-assistant container is running"
  else
    echo "  FAIL  home-assistant container is not in a running state"
    failures=$((failures + 1))
  fi
else
  echo "  SKIP  container state (not on the hub, or compose file absent)"
fi

if [ "$failures" -gt 0 ]; then
  echo "Smoke check FAILED (${failures} failure(s))"
  exit 1
fi

echo "Smoke check PASSED"
