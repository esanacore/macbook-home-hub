#!/usr/bin/env bash
set -uo pipefail

# Unit tests for scripts/check_gbrain_state.sh.
#
# The checker verifies that the `## GBrain Configuration` block in CLAUDE.md
# matches the actual machine state. These tests exercise five fixture states
# by controlling PATH (fake gbrain/claude binaries) and HOME (fake
# ~/.gbrain/config.json), then asserting the checker's exit code and a
# substring of its output.
#
# Run:
#   bash scripts/test_check_gbrain_state.sh
#
# Exit codes:
#   0  all fixtures passed
#   1  one or more fixtures failed

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
checker="$root/scripts/check_gbrain_state.sh"

if [ ! -f "$checker" ]; then
  echo "FATAL: $checker not found" >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

passed=0
failed=0

# run_fixture <name> <expected_exit> <expected_substring> <setup_commands...>
# The setup commands run in a subshell with PATH and HOME pointing at the
# fixture's temp bin/ and home/. The fixture's CLAUDE.md is at
# "$tmp/<name>/CLAUDE.md".
run_fixture() {
  local name="$1"
  local expected_exit="$2"
  local expected_substring="$3"
  local fixture_dir="$tmp/$name"

  mkdir -p "$fixture_dir/bin" "$fixture_dir/home"

  # Source the fixture setup script to populate fixture_dir.
  # Each fixture is defined as a function below.
  "setup_$name" "$fixture_dir"

  local output exit_code
  # Isolate PATH to fixture bin + minimal system paths so the real gbrain
  # (e.g. /home/eric/.bun/bin/gbrain) doesn't satisfy `command -v gbrain`
  # when the fixture deliberately omits it. awk/grep/sed live in /usr/bin.
  output=$(PATH="$fixture_dir/bin:/usr/bin:/bin" HOME="$fixture_dir/home" \
    bash "$checker" --claude-md "$fixture_dir/CLAUDE.md" 2>&1)
  exit_code=$?

  if [ "$exit_code" = "$expected_exit" ] && echo "$output" | grep -qF "$expected_substring"; then
    echo "PASS: $name (exit $exit_code, matched \"$expected_substring\")"
    passed=$((passed + 1))
  else
    echo "FAIL: $name"
    echo "  expected exit $expected_exit, got $exit_code"
    echo "  expected substring: \"$expected_substring\""
    echo "  actual output:"
    echo "$output" | sed 's/^/    /'
    failed=$((failed + 1))
  fi
}

# --- Fixture: in_sync --------------------------------------------------------
# gbrain on PATH, claude shows gbrain connected, config file exists, block
# claims all of the above. Expected: exit 0, "OK: GBrain Configuration block
# matches".
setup_in_sync() {
  local d="$1"
  cat > "$d/bin/gbrain" <<'EOF'
#!/usr/bin/env bash
echo "gbrain 0.46.2.0"
EOF
  chmod +x "$d/bin/gbrain"

  cat > "$d/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "mcp" ] && [ "$2" = "list" ]; then
  echo "gbrain: /home/fake/.bun/bin/gbrain serve - ✔ Connected"
  exit 0
fi
exit 0
EOF
  chmod +x "$d/bin/claude"

  mkdir -p "$d/home/.gbrain"
  echo '{"database_url":"postgresql://example"}' > "$d/home/.gbrain/config.json"

  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

Some preamble.

## GBrain Configuration (configured by /setup-gbrain)

- Mode: local-stdio
- Engine: postgres
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-08-15
- MCP registered: yes (user scope)
- Artifacts sync: off
- Current repo policy: read-write

## GBrain Search Guidance (configured by /sync-gbrain)

Some guidance text.

## Other Section

Other content.
EOF
}

# --- Fixture: stale_mcp_unregistered -----------------------------------------
# gbrain on PATH, config exists, but claude mcp list shows no gbrain. Block
# claims "MCP registered: yes". Expected: exit 1, "STALE: MCP registered: yes
# but".
setup_stale_mcp_unregistered() {
  local d="$1"
  cat > "$d/bin/gbrain" <<'EOF'
#!/usr/bin/env bash
echo "gbrain 0.46.2.0"
EOF
  chmod +x "$d/bin/gbrain"

  # claude exists but mcp list shows no gbrain
  cat > "$d/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "mcp" ] && [ "$2" = "list" ]; then
  echo "other-mcp: something - ✔ Connected"
  exit 0
fi
exit 0
EOF
  chmod +x "$d/bin/claude"

  mkdir -p "$d/home/.gbrain"
  echo '{"database_url":"postgresql://example"}' > "$d/home/.gbrain/config.json"

  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

## GBrain Configuration (configured by /setup-gbrain)

- Mode: local-stdio
- Engine: postgres
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-08-15
- MCP registered: yes (user scope)
- Artifacts sync: off
- Current repo policy: read-write
EOF
}

# --- Fixture: stale_config_missing -------------------------------------------
# gbrain on PATH, claude shows gbrain connected, but ~/.gbrain/config.json is
# absent. Block claims it exists. Expected: exit 1, "STALE: Config file".
setup_stale_config_missing() {
  local d="$1"
  cat > "$d/bin/gbrain" <<'EOF'
#!/usr/bin/env bash
echo "gbrain 0.46.2.0"
EOF
  chmod +x "$d/bin/gbrain"

  cat > "$d/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "mcp" ] && [ "$2" = "list" ]; then
  echo "gbrain: /home/fake/.bun/bin/gbrain serve - ✔ Connected"
  exit 0
fi
exit 0
EOF
  chmod +x "$d/bin/claude"

  # No ~/.gbrain/config.json — deliberately absent

  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

## GBrain Configuration (configured by /setup-gbrain)

- Mode: local-stdio
- Engine: postgres
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-08-15
- MCP registered: yes (user scope)
- Artifacts sync: off
- Current repo policy: read-write
EOF
}

# --- Fixture: stale_no_gbrain_cli --------------------------------------------
# gbrain NOT on PATH. Block claims "Mode: local-stdio". Expected: exit 1,
# "STALE: Mode is 'local-stdio' but".
setup_stale_no_gbrain_cli() {
  local d="$1"
  # No gbrain binary in bin/

  cat > "$d/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "mcp" ] && [ "$2" = "list" ]; then
  echo "gbrain: something - ✔ Connected"
  exit 0
fi
exit 0
EOF
  chmod +x "$d/bin/claude"

  mkdir -p "$d/home/.gbrain"
  echo '{"database_url":"postgresql://example"}' > "$d/home/.gbrain/config.json"

  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

## GBrain Configuration (configured by /setup-gbrain)

- Mode: local-stdio
- Engine: postgres
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-08-15
- MCP registered: yes (user scope)
- Artifacts sync: off
- Current repo policy: read-write
EOF
}

# --- Fixture: stale_no_claude_cli --------------------------------------------
# claude NOT on PATH. Block claims "MCP registered: yes". Expected: exit 1,
# "STALE: MCP registered: yes but".
setup_stale_no_claude_cli() {
  local d="$1"
  cat > "$d/bin/gbrain" <<'EOF'
#!/usr/bin/env bash
echo "gbrain 0.46.2.0"
EOF
  chmod +x "$d/bin/gbrain"

  # No claude binary in bin/

  mkdir -p "$d/home/.gbrain"
  echo '{"database_url":"postgresql://example"}' > "$d/home/.gbrain/config.json"

  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

## GBrain Configuration (configured by /setup-gbrain)

- Mode: local-stdio
- Engine: postgres
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-08-15
- MCP registered: yes (user scope)
- Artifacts sync: off
- Current repo policy: read-write
EOF
}

# --- Fixture: block_absent ---------------------------------------------------
# CLAUDE.md exists but has no GBrain Configuration block. Expected: exit 0,
# "OK: no GBrain Configuration block".
setup_block_absent() {
  local d="$1"
  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

This repo has not adopted gbrain. No block here.
EOF
}

# --- Fixture: claude_md_absent -----------------------------------------------
# No CLAUDE.md at all. Expected: exit 0, "SKIP:".
setup_claude_md_absent() {
  local d="$1"
  # No CLAUDE.md created — the checker will look for $d/CLAUDE.md and not find it
  # But we need the dir to exist for the fixture runner. Create an empty marker.
  : # do nothing
}

# --- Fixture: remote_http_in_sync --------------------------------------------
# remote-http mode: no local gbrain CLI needed, claude shows gbrain connected,
# config file claim is absent (remote mode doesn't have a local config).
# Expected: exit 0, "OK: GBrain Configuration block matches".
setup_remote_http_in_sync() {
  local d="$1"
  # No gbrain binary — remote mode doesn't need it

  cat > "$d/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "mcp" ] && [ "$2" = "list" ]; then
  echo "gbrain: https://example.com/mcp - ✔ Connected"
  exit 0
fi
exit 0
EOF
  chmod +x "$d/bin/claude"

  cat > "$d/CLAUDE.md" <<'EOF'
# CLAUDE.md

## GBrain Configuration (configured by /setup-gbrain)

- Mode: remote-http
- MCP URL: https://example.com/mcp
- Server version: gbrain v0.27.1
- Setup date: 2026-08-15
- MCP registered: yes (user scope)
- Artifacts sync: off
- Current repo policy: read-write
EOF
}

# --- Run all fixtures --------------------------------------------------------

echo "Running check_gbrain_state.sh unit tests..."
echo

run_fixture "in_sync"                  0 "OK: GBrain Configuration block matches"
run_fixture "stale_mcp_unregistered"   1 "STALE: MCP registered: yes but"
run_fixture "stale_config_missing"     1 "STALE: Config file"
run_fixture "stale_no_gbrain_cli"      1 "STALE: Mode is 'local-stdio' but"
run_fixture "stale_no_claude_cli"      1 "STALE: MCP registered: yes but"
run_fixture "block_absent"             0 "OK: no GBrain Configuration block"
run_fixture "claude_md_absent"         0 "SKIP:"
run_fixture "remote_http_in_sync"      0 "OK: GBrain Configuration block matches"

echo
echo "========================================"
echo " passed: $passed   failed: $failed"
echo "========================================"

[ "$failed" -eq 0 ]
