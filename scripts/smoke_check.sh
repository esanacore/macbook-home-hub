#!/usr/bin/env bash
set -uo pipefail

# Smoke check for the running hub: is the stack up, and is Home Assistant
# actually serving?
#
# This is the closest thing this repository has to an end-to-end test. It
# verifies the facts everything else depends on (FR-002, NFR-002 in
# docs/PRODUCT_REQUIREMENTS.md): the host answers, Home Assistant returns
# HTTP on :8123, and — on the hub — it is running its real configuration
# rather than recovery mode.
#
# It checks a *running* system and cannot be run in CI against nothing — it
# requires HUB_HOST to name a reachable hub.
#
# Usage:
#   HUB_HOST=192.168.1.50 bash scripts/smoke_check.sh
#   HUB_HOST=hub.local HA_PORT=8123 bash scripts/smoke_check.sh
#
# Exit status:
#   0  host reachable and Home Assistant answered (and, on the hub, is not in
#      recovery mode and its config passes check_config)
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
#
# 4. Recovery mode. When configuration.yaml fails to load (a missing !secret,
#    a YAML error), Home Assistant does not exit: it starts a stripped-down
#    "recovery mode" that still serves the frontend with HTTP 200, so step 2
#    passes. Checked against 2026.8.0 on 2026-10-25: no unauthenticated
#    endpoint differs between a healthy and a recovery-mode instance
#    (/, /manifest.json, /auth/providers, /auth/authorize, /api/ and
#    /api/onboarding returned identical bytes), so this needs the container.
#    Two facts, both blocking:
#      a. the running instance logged "Activating recovery mode" since its
#         last start — HA is broken *now*;
#      b. check_config rejects the config on disk — HA will be broken after
#         the next restart, even if the running instance predates the edit.
#    Like step 3, these only run on the hub and SKIP elsewhere.
container=home-assistant
if [ -f compose/docker-compose.yml ] && command -v docker >/dev/null 2>&1; then
  if docker compose -f compose/docker-compose.yml ps --status running 2>/dev/null | grep -q "$container"; then
    echo "  OK    ${container} container is running"

    started=$(docker inspect -f '{{.State.StartedAt}}' "$container" 2>/dev/null) || started=""
    if [ -z "$started" ]; then
      echo "  FAIL  could not read ${container} start time (docker inspect failed)"
      failures=$((failures + 1))
    elif ! logs=$(docker logs --since "$started" "$container" 2>&1); then
      echo "  FAIL  could not read ${container} logs since ${started}"
      failures=$((failures + 1))
    elif grep -q 'Activating recovery mode' <<<"$logs"; then
      reason=$(grep -m1 'Activating recovery mode' <<<"$logs" | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^.*\] //')
      echo "  FAIL  Home Assistant is in recovery mode: ${reason}"
      failures=$((failures + 1))
    else
      echo "  OK    Home Assistant not in recovery mode (no recovery entry since ${started})"
    fi

    if cc_out=$(docker exec "$container" python -m homeassistant --script check_config -c /config 2>&1); then
      echo "  OK    check_config accepts the configuration on disk"
    else
      echo "  FAIL  check_config rejects the configuration on disk (HA will enter recovery mode on restart):"
      sed 's/\x1b\[[0-9;]*m//g' <<<"$cc_out" | grep -iE 'error|failed|not defined|invalid' | head -5 | sed 's/^/          /'
      failures=$((failures + 1))
    fi
  else
    echo "  FAIL  ${container} container is not in a running state"
    echo "  SKIP  recovery mode (container not running)"
    failures=$((failures + 1))
  fi
else
  echo "  SKIP  container state (not on the hub, or compose file absent)"
  echo "  SKIP  recovery mode and config validity (not on the hub, or compose file absent)"
fi

if [ "$failures" -gt 0 ]; then
  echo "Smoke check FAILED (${failures} failure(s))"
  exit 1
fi

echo "Smoke check PASSED"
