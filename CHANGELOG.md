# Changelog

All notable user-facing changes to this project should be documented in this file.

This project follows semantic versioning.

## Unreleased

### Added

- `compose/docker-compose.yml` declaring the Home Assistant container with a
  pinned dated image tag (`ghcr.io/home-assistant/home-assistant:2026.8.0`),
  `unless-stopped` restart policy, host networking, and a `./config` bind
  mount. Companions (Mosquitto, Node-RED) are deliberately absent — they are
  Deferred in `docs/REQUIREMENTS_TRACEABILITY.md` until adoption is decided.
  The compose tier of the test suite now finds the file; `docker compose
  config` validation still requires Docker to be installed (GAP-004 stays
  open until then).

### Changed

- Filled `docs/adr/0001-record-architecture-decisions.md` (was the unfilled
  template). Now an Accepted ADR recording the decision to use ADRs, with
  ADR-0002 noted as Related.
- Filled `docs/AGENT_PROMPTS.md` with six project-real prompts (provision,
  smoke check, restore drill, ADR drafting, constitution review, stack bring
  up); was template boilerplate.
- Filled `docs/HELP.md` Primary Maintainers and Asking for Help placeholders.
- `docs/OTS_SOFTWARE.md` OTS-003 version updated from `stable (pinned tag
  once deployed)` to `2026.8.0`, with the update policy note pointing at
  `compose/docker-compose.yml`. Status stays `Evaluating` until the component
  is observed running on the hub.
- `docs/ENV_VARS.md` `TZ` promoted from Anticipated to Optional Variables
  (now declared in the compose file). `HA_CONFIG_PATH`, `PUID`, `PGID`, and
  the MQTT pair stay Anticipated.
- `.devcontainer/devcontainer.json` no longer installs the Node feature —
  this repo has no JavaScript.

### Removed

- `docs/MVP_BACKLOG.md` — not in the constitution compliance list and carried
  only stale template milestones.
- `.constitution-bootstrap/` — adoption complete. Not read by any
  parent-repo script; `constitution/scripts/bootstrap.sh` recreates it if
  ever rerun.

### Fixed

- pre-commit hooks installed and active (`pre-commit install` plus
  `pre-commit install --hook-type pre-push` for the secrets sweep). First
  `pre-commit run --all-files` trimmed trailing whitespace and normalized
  end-of-file on `CLAUDE.md`, `docs/MEMORY.md`, `docs/AGENT_PROMPTS.md`, and
  `docs/adr/0001-record-architecture-decisions.md`.

## [0.1.0] - 2026-08-15

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
- The requirements-traceability step in
  `.github/workflows/constitution-compliance.yml` is now **advisory rather
  than blocking**, a documented deviation from the constitution template. Ten
  of twelve requirements describe a machine that does not exist yet, so the
  gate would be red on every pull request until the hub is provisioned —
  which trains readers to ignore CI rather than adding rigor. The findings
  still print in full and land in the job summary on every run, the gaps are
  enumerated as GAP-001 through GAP-008 in `docs/TEST_PLAN.md`, and restoring
  the gate to blocking is tracked in `TODO.md`.

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
