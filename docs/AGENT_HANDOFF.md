# Agent Handoff

This document helps transition work between AI agent sessions or different
agents.

**Before starting your session**, check `docs/SESSION_PLAN.md` for the previous
agent's planned work and resumption notes, and `docs/MEMORY.md` to load durable
codebase learnings and user preferences. The session plan captures *intent
before work*; this handoff captures *state after work*.

## How to Handoff

When finishing a task or session, append an entry to the log below:

1. **Accomplishments**: what actually changed.
2. **Pending Work**: what was deliberately left, and why.
3. **Verification Run**: what was executed, with results. Also state what was
   *not* run.
4. **Instructions for Next Agent**: the specific first thing to do.

Keep entries append-only and newest-first. Do not rewrite history — a handoff
that gets edited after the fact stops being evidence.

## Handoff Log

### Session: 2026-08-15 — Claude (Claude Code)

**Accomplishments**

- Initialized the `constitution/` submodule. It was registered in
  `.gitmodules` but never checked out, so every path in the required-reading
  list in `CLAUDE.md` and `AGENTS.md` resolved to nothing and no
  `constitution/scripts/*.sh` check could run. This was the single largest
  compliance gap and it was invisible from a file listing.
- Installed the gstack toolchain (Bun 1.3.14 + gstack) per machine, so the
  skills referenced in `CLAUDE.md` resolve.
- Added `.gitignore`, closing all six `.gitignore` coverage gaps reported by
  `check_secrets.sh` and covering Home Assistant runtime state
  (`config/secrets.yaml`, `.storage/`, the SQLite database, backup archives).
- Replaced Node/npm boilerplate with project-real content in `docs/SETUP.md`,
  `docs/COMMAND_REFERENCE.md`, `docs/TROUBLESHOOTING.md`, and
  `docs/ENV_VARS.md`. These previously instructed the reader to run
  `npm install` and `rm -rf node_modules` in a repository that has no
  JavaScript.
- Defined what "tests" mean for a configuration repository
  (`docs/TEST_PLAN.md`) and implemented the suite: `scripts/run_tests.sh` and
  `scripts/smoke_check.sh`. This closed a standing TODO item.
- Wrote 12 real requirements (`docs/PRODUCT_REQUIREMENTS.md`) and a matching
  traceability matrix, replacing 7 template placeholders.

**Pending Work**

- No provisioning was performed. The MacBook has not been imaged. Every
  host-dependent requirement is unverified by construction — see the gap log
  in `docs/TEST_PLAN.md` (GAP-001 through GAP-008).
- `compose/docker-compose.yml` still does not exist, so the compose tier of
  the test suite SKIPs.
- `pre-commit` is not installed on this machine, so the hooks in
  `.pre-commit-config.yaml` are configured but inactive.

**Verification Run**

- Ran: all ten `constitution/scripts/check_*.sh` checkers, and
  `bash scripts/run_tests.sh`. Results are recorded in `CHANGELOG.md` and
  summarized in `docs/SESSION_PLAN.md`.
- Not run: anything requiring the hub. `scripts/smoke_check.sh` has never
  executed against real hardware — it is written but unproven. Do not treat it
  as a passing test.

**Instructions for Next Agent**

Do not mark any host-dependent requirement `Verified` in
`docs/REQUIREMENTS_TRACEABILITY.md` on the basis of a script existing. The
matrix distinguishes "a check is written" from "a check has run," and that
distinction is the point of the document. The next substantive work is
physical: image the machine per `docs/SETUP.md` Part 2, then replace that
section's planned commands with what was actually typed.
