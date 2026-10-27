#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/smoke_check.sh.
#
# The smoke check only talks to the outside world through `ping`, `curl` and
# `docker`. Each test builds a directory of fake binaries whose answers are
# driven by FAKE_* environment variables, prepends it to PATH, runs the check
# from a scratch directory holding an empty compose/docker-compose.yml (the
# "am I on the hub" marker), and asserts the exit code plus a substring of the
# output. The case that motivated these tests: on 2026-10-25 Home Assistant
# had been in recovery mode for ten days — serving HTTP 200 — while the smoke
# check passed. "recovery mode -> FAIL" is that regression.

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/smoke_check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fakebin="$tmp/bin"
work="$tmp/work"
mkdir -p "$fakebin" "$work/compose"
: > "$work/compose/docker-compose.yml"

cat > "$fakebin/ping" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_PING_OK:-1}" = 1 ]
FAKE

cat > "$fakebin/curl" <<'FAKE'
#!/usr/bin/env bash
# smoke_check only uses curl for -w '%{http_code}'
code=${FAKE_HTTP_CODE:-200}
[ "$code" = 000 ] && exit 7
printf '%s' "$code"
FAKE

cat > "$fakebin/docker" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
  compose)
    # compose -f <file> ps --status running
    [ "${FAKE_RUNNING:-1}" = 1 ] && echo "home-assistant  ghcr.io/home-assistant/home-assistant:2026.8.0  Up 2 hours"
    exit 0 ;;
  inspect)
    [ "${FAKE_INSPECT_FAIL:-0}" = 1 ] && exit 1
    echo "2026-10-25T00:11:04.386735993Z" ;;
  logs)
    [ "${FAKE_LOGS_FAIL:-0}" = 1 ] && { echo "Error response from daemon: configured logging driver does not support reading" >&2; exit 1; }
    echo "s6-rc: info: service legacy-services successfully started"
    if [ "${FAKE_RECOVERY:-0}" = 1 ]; then
      printf '\033[31m2026-10-24 17:11:10.042 ERROR (MainThread) [homeassistant.bootstrap] Failed to parse configuration.yaml: Secret firestick_hub_auth not defined. Activating recovery mode\033[0m\n'
    fi ;;
  exec)
    if [ "${FAKE_CONFIG_OK:-1}" = 1 ]; then
      echo "Testing configuration at /config"; exit 0
    fi
    echo "Testing configuration at /config"
    echo "Failed config"
    echo "  General Errors:"
    echo "    - Secret firestick_hub_auth not defined"
    exit 1 ;;
  *) exit 1 ;;
esac
FAKE
chmod +x "$fakebin"/*

pass=0; fail=0
# run_case <name> <expected-exit> <expected-substring> [VAR=value ...]
run_case() {
  local name=$1 want_exit=$2 want_text=$3; shift 3
  local out rc
  out=$(cd "$work" && env -i HOME="$tmp" PATH="$fakebin:/usr/bin:/bin" HUB_HOST=hub.test "$@" bash "$checker" 2>&1); rc=$?
  if [ "$rc" -eq "$want_exit" ] && grep -qF -- "$want_text" <<<"$out"; then
    echo "PASS: $name"; pass=$((pass+1))
  else
    echo "FAIL: $name (exit=$rc want=$want_exit; looking for '$want_text')"; echo "$out" | sed 's/^/    /'; fail=$((fail+1))
  fi
}

# Docker absent: the fakes minus docker, plus only the coreutils the check
# needs and no /usr/bin, so a real docker on the test machine (the hub) cannot
# leak in.
no_docker_bin="$tmp/bin-nodocker"; mkdir -p "$no_docker_bin"
for f in ping curl; do ln -s "$fakebin/$f" "$no_docker_bin/$f"; done
for f in bash sed grep head cat; do ln -s "$(command -v $f)" "$no_docker_bin/$f"; done
# Where no real docker sits in /usr/bin or /bin (Windows Git Bash, a bare CI
# image) the system dirs can stay on PATH — and must, because a symlinked
# MSYS bash.exe cannot find its DLLs and exits 127.
no_docker_path="$no_docker_bin"
if [ ! -e /usr/bin/docker ] && [ ! -e /bin/docker ]; then
  no_docker_path="$no_docker_bin:/usr/bin:/bin"
fi

run_case "healthy -> PASSED"                         0 "Smoke check PASSED"
run_case "healthy reports not in recovery"           0 "OK    Home Assistant not in recovery mode"
run_case "recovery mode (HTTP 200) -> FAIL"          1 "FAIL  Home Assistant is in recovery mode: Failed to parse configuration.yaml: Secret firestick_hub_auth not defined." FAKE_RECOVERY=1 FAKE_CONFIG_OK=0
run_case "config broken, not yet restarted -> FAIL"  1 "check_config rejects the configuration on disk" FAKE_CONFIG_OK=0
run_case "check_config error lines shown"            1 "Secret firestick_hub_auth not defined" FAKE_CONFIG_OK=0
run_case "logs unreadable -> FAIL, not PASS"         1 "could not read home-assistant logs" FAKE_LOGS_FAIL=1
run_case "inspect fails -> FAIL"                     1 "could not read home-assistant start time" FAKE_INSPECT_FAIL=1
run_case "container stopped -> FAIL, recovery SKIP"  1 "SKIP  recovery mode (container not running)" FAKE_RUNNING=0
run_case "no HTTP -> FAIL"                           1 "no HTTP response" FAKE_HTTP_CODE=000
run_case "ping blocked -> WARN only"                 0 "WARN  host does not respond to ping" FAKE_PING_OK=0

# docker binary absent entirely: container and recovery checks SKIP, HTTP
# alone decides.
out=$(cd "$work" && env -i HOME="$tmp" PATH="$no_docker_path" HUB_HOST=hub.test bash "$checker" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && grep -qF "SKIP  recovery mode and config validity" <<<"$out" && grep -qF "Smoke check PASSED" <<<"$out"; then
  echo "PASS: docker absent -> recovery SKIP, still PASS"; pass=$((pass+1))
else
  echo "FAIL: docker absent -> recovery SKIP, still PASS (exit=$rc)"; echo "$out" | sed 's/^/    /'; fail=$((fail+1))
fi

echo
echo "smoke_check tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
