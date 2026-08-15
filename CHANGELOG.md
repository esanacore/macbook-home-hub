# Changelog

All notable user-facing changes to this project should be documented in this file.

This project follows semantic versioning.

## Unreleased

### Added

- Initial changelog.
- Repository initialized and bootstrapped with Eric's Engineering Constitution
  (constitution submodule, governance files, CI workflows, doc templates).
- Project README with system overview and component diagram.
- ADR-0002: Linux base OS (Mint XFCE) and Home Assistant Container install
  method; Home Assistant OS and the deprecated Supervised method rejected.
- Operations runbook covering always-on config (lid-switch, sleep masking),
  battery-as-UPS longevity, and manual backup expectations.
- Off-the-shelf software inventory for the system-level stack (host OS, Docker,
  Home Assistant, planned Mosquitto/Node-RED).
- Architecture overview with data flow and a documented layer-enforcement N/A.
- Initial project roadmap in TODO.md.
- `.gitignore` covering credentials, SSH keys, Terraform state, and Home
  Assistant runtime state (`config/secrets.yaml`, `.storage/`, the SQLite
  database, and backup archives).
- Test suite for a configuration repository: `scripts/run_tests.sh` (governance
  and compose tiers) and `scripts/smoke_check.sh` (host reachability and Home
  Assistant liveness). Checks that cannot run in the current environment report
  `SKIP` and are never counted as passes.
- Twelve real product requirements (`docs/PRODUCT_REQUIREMENTS.md`) with a
  matching traceability matrix, replacing the seven template placeholders.
- Coverage gap log (GAP-001 through GAP-008) recording every requirement that
  cannot be verified until the hardware exists.

### Changed

- `docs/SETUP.md`, `docs/COMMAND_REFERENCE.md`, `docs/TROUBLESHOOTING.md`, and
  `docs/ENV_VARS.md` rewritten for this project. They previously carried the
  template's Node/npm boilerplate — instructing the reader to run
  `npm install`, `npm run dev`, and `rm -rf node_modules` in a repository that
  contains no JavaScript.
- `docs/TEST_PLAN.md` now defines testing in terms of what can actually fail
  here (doc drift, committed secrets, invalid compose, an unresponsive hub)
  rather than line coverage, which does not apply.
- `docs/SETUP.md` Part 2 is explicitly marked **unverified**: the machine has
  not been imaged, so the provisioning steps are the planned path, not a
  captured run.

### Fixed

- Initialized the `constitution/` submodule. It was registered in
  `.gitmodules` but never checked out, so the entire required-reading list in
  `CLAUDE.md` and `AGENTS.md` pointed at an empty directory and no compliance
  script could run.
- Corrected the stale project name (`Project Name`) and path
  (`/home/claude/...`) in the bootstrap adoption report, and marked it as a
  historical record rather than a live status page.

### Removed

### Security

- Closed all six `.gitignore` coverage gaps reported by
  `constitution/scripts/check_secrets.sh` (now 0 filename hits, 0
  content-pattern hits, 0 coverage gaps).
- Documented secret-handling rules in `docs/ENV_VARS.md` ahead of the first
  real secret existing: `.env` untracked, Home Assistant secrets via `!secret`
  from a gitignored `config/secrets.yaml`, and the backup encryption key held
  off the hub.
- Added NFR-001 (no committed credentials) and NFR-005 (no public internet
  exposure) as tracked requirements. NFR-001 is verified; NFR-005 is not.
