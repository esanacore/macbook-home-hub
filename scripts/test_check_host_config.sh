#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/check_host_config.sh.
#
# The checker only talks to the outside world through `busctl`, `systemctl`,
# `docker`, `id` and `xfconf-query`. Each test builds a directory of fake
# binaries whose answers are driven by FAKE_* environment variables, prepends
# it to PATH, and asserts the checker's exit code plus a substring of its
# output. Negative cases matter most: a checker that can only pass is worse
# than none (constitution TESTING.md, "Governance Tooling Must Be Tested").

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/check_host_config.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fakebin="$tmp/bin"
mkdir -p "$fakebin"

cat > "$fakebin/busctl" <<'FAKE'
#!/usr/bin/env bash
# args: get-property ... <PropertyName>
[ "${FAKE_BUSCTL_FAIL:-0}" = 1 ] && exit 1
case "${!#}" in
  HandleLidSwitch)              echo "s \"${FAKE_LID:-ignore}\"" ;;
  HandleLidSwitchExternalPower) echo "s \"${FAKE_LID_EXT-}\"" ;;
  HandleLidSwitchDocked)        echo "s \"${FAKE_LID_DOCK:-ignore}\"" ;;
  *) exit 1 ;;
esac
FAKE

cat > "$fakebin/systemctl" <<'FAKE'
#!/usr/bin/env bash
# args: is-enabled <unit>
unit=${2:-}
case "$unit" in
  *sleep.target|suspend.target|hibernate.target) echo "${FAKE_SLEEP_STATE:-masked}" ;;
  docker)     echo "${FAKE_DOCKER_STATE:-enabled}" ;;
  ssh.socket) echo "${FAKE_SSH_SOCKET_STATE:-enabled}" ;;
  ssh)        echo "${FAKE_SSH_STATE:-not-found}" ;;
  *) echo not-found; exit 1 ;;
esac
FAKE

cat > "$fakebin/docker" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_COMPOSE_OK:-1}" = 1 ] && exit 0
exit 1
FAKE

cat > "$fakebin/id" <<'FAKE'
#!/usr/bin/env bash
echo "${FAKE_GROUPS:-esanacore docker}"
FAKE

cat > "$fakebin/xfconf-query" <<'FAKE'
#!/usr/bin/env bash
# -l  -> list (reachability probe); -p <path> -> value
[ "${FAKE_XFCONF_REACHABLE:-1}" = 1 ] || exit 1
for ((i=1;i<=$#;i++)); do
  if [ "${!i}" = -p ]; then j=$((i+1)); path=${!j}; fi
done
case "${path:-}" in
  */lid-action-*)   echo "${FAKE_XFPM_LID:-0}" ;;
  */inactivity-on-*) echo "${FAKE_XFPM_IDLE:-14}" ;;
  "") exit 0 ;;
esac
FAKE
chmod +x "$fakebin"/*

pass=0; fail=0
# run_case <name> <expected-exit> <expected-substring> [VAR=value ...]
run_case() {
  local name=$1 want_exit=$2 want_text=$3; shift 3
  local out rc
  out=$(env -i HOME="$tmp" PATH="$fakebin:/usr/bin:/bin" "$@" bash "$checker" 2>&1); rc=$?
  if [ "$rc" -eq "$want_exit" ] && grep -qF -- "$want_text" <<<"$out"; then
    echo "PASS: $name"; pass=$((pass+1))
  else
    echo "FAIL: $name (exit=$rc want=$want_exit; looking for '$want_text')"; echo "$out" | sed 's/^/    /'; fail=$((fail+1))
  fi
}

# Docker absent is modelled by a PATH that holds the other fakes plus just the
# coreutils the checker needs — and no /usr/bin, so a real docker installed on
# the test machine (CI runner, or the hub after provisioning) cannot leak in.
no_docker_bin="$tmp/bin-nodocker"; mkdir -p "$no_docker_bin"
for f in busctl systemctl id xfconf-query; do ln -s "$fakebin/$f" "$no_docker_bin/$f"; done
for f in bash sed grep tr cat; do ln -s "$(command -v $f)" "$no_docker_bin/$f"; done

run_case "all good -> PASSED"                     0 "Host configuration check PASSED"
run_case "empty ExternalPower inherits ignore"    0 "HandleLidSwitchExternalPower=ignore" FAKE_LID_EXT=
run_case "lid suspend -> FAIL"                    1 "HandleLidSwitch=suspend" FAKE_LID=suspend
run_case "empty ExternalPower inherits suspend"   1 "HandleLidSwitchExternalPower=suspend" FAKE_LID=suspend FAKE_LID_EXT=
run_case "explicit ExternalPower suspend -> FAIL"  1 "HandleLidSwitchExternalPower=suspend" FAKE_LID=ignore FAKE_LID_EXT=suspend
run_case "explicit ExternalPower ignore kept"      1 "OK    logind HandleLidSwitchExternalPower=ignore" FAKE_LID=suspend FAKE_LID_EXT=ignore
run_case "docked lid not ignore -> FAIL"          1 "HandleLidSwitchDocked=lock" FAKE_LID_DOCK=lock
run_case "busctl returns nothing -> FAIL"         1 "HandleLidSwitch= (want ignore" FAKE_BUSCTL_FAIL=1
run_case "sleep targets static -> FAIL"           1 "sleep.target is 'static'" FAKE_SLEEP_STATE=static
run_case "compose missing -> FAIL"                1 "docker compose not available" FAKE_COMPOSE_OK=0
run_case "docker.service disabled -> FAIL"        1 "docker.service is 'disabled'" FAKE_DOCKER_STATE=disabled
run_case "user not in docker group -> FAIL"       1 "not in docker group" FAKE_GROUPS="esanacore adm"
run_case "ssh not installed -> FAIL"              1 "sshd not enabled at boot (ssh.socket is 'not-found'" FAKE_SSH_SOCKET_STATE=not-found
run_case "ssh.service enabled, no socket -> PASS" 0 "ssh.service enabled" FAKE_SSH_SOCKET_STATE=disabled FAKE_SSH_STATE=enabled
run_case "ssh socket+service both disabled -> FAIL" 1 "ssh.service is 'disabled'" FAKE_SSH_SOCKET_STATE=disabled FAKE_SSH_STATE=disabled
run_case "xfpm lid action suspend -> FAIL"        1 "xfpm lid-action-on-ac='1'" FAKE_XFPM_LID=1
run_case "xfpm idle timeout set -> FAIL"          1 "xfpm inactivity-on-ac='30'" FAKE_XFPM_IDLE=30
run_case "xfconf unreachable -> SKIP, still PASS" 0 "SKIP  xfce4-power-manager" FAKE_XFCONF_REACHABLE=0

# docker binary absent entirely
out=$(env -i HOME="$tmp" PATH="$no_docker_bin" "$no_docker_bin/bash" "$checker" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && grep -qF "docker not installed" <<<"$out"; then
  echo "PASS: docker absent -> FAIL"; pass=$((pass+1))
else
  echo "FAIL: docker absent -> FAIL (exit=$rc)"; echo "$out" | sed 's/^/    /'; fail=$((fail+1))
fi

echo
echo "check_host_config tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
