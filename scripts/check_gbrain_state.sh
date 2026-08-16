#!/usr/bin/env bash
set -uo pipefail

# Detect drift between the `## GBrain Configuration` block in CLAUDE.md and
# the actual machine state. The block is written by `/setup-gbrain` and
# records: Mode, Engine, Config file path, Setup date, MCP registered
# (yes/no), Artifacts sync, Current repo policy. When the repo is cloned on a
# different machine (e.g. CI, a new laptop) the block's claims can drift from
# that machine's reality — "MCP registered: yes" on a machine with no gbrain
# MCP entry, or "Config file: ~/.gbrain/config.json" on a machine where that
# file doesn't exist.
#
# This checker reads the block, parses its key/value claims, and verifies
# each claim that is machine-checkable. Drift is reported as STALE and the
# script exits 1. A clean match (or no block at all) exits 0.
#
# Exit codes:
#   0  OK — block is absent, or every machine-checkable claim matches
#   1  STALE — one or more claims do not match the machine
#
# Usage:
#   bash scripts/check_gbrain_state.sh                 # checks ./CLAUDE.md
#   bash scripts/check_gbrain_state.sh --claude-md path/to/CLAUDE.md
#
# Testability: the checker probes `command -v gbrain`, `command -v claude`,
# `claude mcp list`, and file existence under $HOME. Unit tests control all
# of these by setting PATH (to include fake binaries) and HOME (to a temp
# dir), then passing --claude-md to a fixture.

claude_md="CLAUDE.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --claude-md)
      claude_md="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$claude_md" ]; then
  echo "SKIP: $claude_md not found (no CLAUDE.md to check)"
  exit 0
fi

# Extract the `## GBrain Configuration` block. The block starts at a line
# matching `^## GBrain Configuration` and ends at the next `^## ` heading
# or EOF. We do not rely on the HTML-comment delimiters here — those belong
# to the Search Guidance block, not the Configuration block.
block=$(awk '
  /^## GBrain Configuration/ { in_block=1; next }
  in_block && /^## / { in_block=0 }
  in_block { print }
' "$claude_md")

if [ -z "$block" ]; then
  echo "OK: no GBrain Configuration block in $claude_md (gbrain not configured on this machine)"
  exit 0
fi

# Parse key: value pairs from the block. Lines look like:
#   - Mode: local-stdio
#   - MCP registered: yes (user scope; ...)
# We strip the leading `- ` and take everything before the first `;` or `(` as
# the value, to handle parenthetical notes.
get_value() {
  local key="$1"
  echo "$block" | grep -E "^- $key:" | head -1 | sed -E \
    -e "s/^- $key: //" \
    -e "s/ *(;|\\().*//" \
    -e "s/ *$//"
}

mode=$(get_value "Mode")
engine=$(get_value "Engine")
config_file_claim=$(get_value "Config file")
mcp_registered=$(get_value "MCP registered")
repo_policy=$(get_value "Current repo policy")

drifts=0
report_drift() {
  echo "STALE: $1"
  drifts=$((drifts + 1))
}

# --- Verify Mode claim -------------------------------------------------------
# local-stdio requires the gbrain CLI on PATH (the MCP runs `gbrain serve`).
# remote-http does not require a local CLI — the brain is on another machine.
if [ -n "$mode" ]; then
  if [ "$mode" = "local-stdio" ]; then
    if ! command -v gbrain >/dev/null 2>&1; then
      report_drift "Mode is 'local-stdio' but \`gbrain\` is not on PATH (re-run /setup-gbrain or install gbrain)"
    fi
  elif [ "$mode" = "remote-http" ]; then
    : # remote-http doesn't need a local gbrain CLI; verified via MCP below
  else
    report_drift "Mode is '$mode' — expected 'local-stdio' or 'remote-http'"
  fi
fi

# --- Verify Config file claim ------------------------------------------------
# The block names the config file path (e.g. ~/.gbrain/config.json). Expand
# ~ to $HOME and check it exists. Absent config means gbrain isn't actually
# initialized on this machine, even if the block claims it is.
if [ -n "$config_file_claim" ]; then
  # Expand leading ~ to $HOME
  expanded="${config_file_claim/#\~/$HOME}"
  if [ ! -f "$expanded" ]; then
    report_drift "Config file '$config_file_claim' does not exist on this machine (gbrain not initialized here)"
  fi
fi

# --- Verify MCP registered claim ---------------------------------------------
# The block says "MCP registered: yes" or "no". If yes, verify `claude mcp
# list` shows a gbrain entry. If `claude` isn't on PATH, we can't verify —
# treat as drift since the claim is uncheckable and likely stale.
if [ -n "$mcp_registered" ]; then
  case "$mcp_registered" in
    yes*)
      if ! command -v claude >/dev/null 2>&1; then
        report_drift "MCP registered: yes but \`claude\` CLI is not on PATH (cannot verify; likely stale from a cross-machine clone)"
      elif ! claude mcp list 2>/dev/null | grep -q gbrain; then
        report_drift "MCP registered: yes but \`claude mcp list\` shows no gbrain entry (re-run /setup-gbrain to re-register)"
      fi
      ;;
    no)
      : # no claim to verify
      ;;
  esac
fi

if [ "$drifts" -gt 0 ]; then
  echo "---"
  echo "Found $drifts drift(s). Re-run /setup-gbrain on this machine to rewrite the block."
  exit 1
fi

echo "OK: GBrain Configuration block matches machine state (mode=$mode, mcp=$mcp_registered)"
exit 0
