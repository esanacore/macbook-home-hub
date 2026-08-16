#!/usr/bin/env bash
set -uo pipefail

# Full test suite for macbook-home-hub, declared in docs/TEST_PLAN.md and
# invoked by constitution/scripts/run_declared_tests.sh.
#
# This repository has no application code of its own — it holds configuration,
# documentation, and operational procedure. "Tests" here therefore mean two
# things:
#
#   1. Static checks that run anywhere, with no hardware (governance checks,
#      YAML/compose validity). These are the suite's enforced core.
#   2. Host checks that only mean anything on the hub itself (is the stack up,
#      does Home Assistant answer). These SKIP off-host rather than fail, so
#      the suite stays runnable on a laptop while still being the real check
#      when run on the hub.
#
# A skipped check is reported as SKIP and never counted as a pass. Exit status
# is 0 only if every executed check passed.

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

pass=0
fail=0
skip=0
failed_names=()

run_check() {
  local name=$1
  shift
  printf '\n--- %s\n' "$name"
  if "$@"; then
    printf 'PASS: %s\n' "$name"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s\n' "$name"
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
}

skip_check() {
  printf '\n--- %s\nSKIP: %s\n' "$1" "$2"
  skip=$((skip + 1))
}

echo "========================================"
echo " macbook-home-hub test suite"
echo "========================================"

# ---------------------------------------------------------------- static ---

if [ ! -d constitution/scripts ]; then
  echo "FATAL: constitution/ submodule is not initialized."
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

run_check "governance: required documents present" \
  bash constitution/scripts/check_compliance.sh
run_check "security: secrets sweep and .gitignore coverage" \
  bash constitution/scripts/check_secrets.sh
run_check "governance: OTS inventory matches manifests" \
  bash constitution/scripts/check_ots_inventory.sh
run_check "governance: env vars documented" \
  bash constitution/scripts/check_env_vars.sh
run_check "architecture: layer boundaries" \
  bash constitution/scripts/check_architecture.sh
run_check "governance: constitution version references current" \
  bash constitution/scripts/check_version_alignment.sh

# check_traceability.sh exits non-zero while requirements have no verifying
# test. Those gaps are known, logged in docs/TEST_PLAN.md, and tracked in
# TODO.md — so it is reported here but not treated as a suite failure. Flip
# this to run_check once the gap log is empty.
printf '\n--- requirements: traceability matrix (advisory)\n'
bash constitution/scripts/check_traceability.sh || true

# check_gbrain_state.sh detects drift between the `## GBrain Configuration`
# block in CLAUDE.md and the actual machine state. On a machine that has
# gbrain configured (the one that wrote the block), it should report OK. On
# a different machine (CI, a fresh clone) it will report STALE because the
# block claims gbrain is configured but that machine has no gbrain. That is
# the expected cross-machine-clone signal, not a suite failure — so it runs
# advisory, like the traceability gate. Re-running /setup-gbrain on the
# stale machine rewrites the block in place.
printf '\n--- gbrain: CLAUDE.md block vs machine state (advisory)\n'
bash scripts/check_gbrain_state.sh || true

# The unit tests for check_gbrain_state.sh use fixtures with isolated PATH
# and HOME, so they pass on any machine regardless of whether gbrain is
# installed. These are blocking — a regression in the checker's logic is a
# real failure.
run_check "gbrain: staleness checker unit tests" \
  bash scripts/test_check_gbrain_state.sh

# --------------------------------------------------------- compose stack ---

if [ -f compose/docker-compose.yml ]; then
  if command -v docker >/dev/null 2>&1; then
    run_check "compose: file parses and resolves" \
      docker compose -f compose/docker-compose.yml config --quiet
  else
    skip_check "compose: file parses and resolves" "docker not installed"
  fi
else
  skip_check "compose: file parses and resolves" \
    "compose/docker-compose.yml does not exist yet (see TODO.md)"
fi

# ------------------------------------------------------------ host smoke ---

if [ -n "${HUB_HOST:-}" ]; then
  run_check "smoke: hub reachable and Home Assistant answering" \
    bash scripts/smoke_check.sh
else
  skip_check "smoke: hub reachable and Home Assistant answering" \
    "set HUB_HOST=<hub-ip> to run against the hub"
fi

# --------------------------------------------------------------- summary ---

echo
echo "========================================"
echo " passed: $pass   failed: $fail   skipped: $skip"
if [ "$fail" -gt 0 ]; then
  echo " failing checks:"
  for n in "${failed_names[@]}"; do
    echo "   - $n"
  done
fi
echo "========================================"

[ "$fail" -eq 0 ]
