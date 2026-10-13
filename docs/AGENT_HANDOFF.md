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

### Session: 2026-10-12 — Claude (Claude Code), on the hub

**Accomplishments**

- First session run **on the MacBook itself** (`peppermint-patty`, Linux Mint
  22.3 XFCE, kernel 7.0.0-38). Repository tooling from `docs/SETUP.md` Part 1
  is in place on this machine: constitution submodule, Git identity,
  `pre-commit` (via `uv`) with commit and pre-push hooks, Bun + gstack.
- Observed and recorded: Wi-Fi works out of the box via `brcmfmac` (no dongle,
  no `broadcom-sta-dkms`); no battery charge-limit control exists (baseline
  397 cycles / 73% health); the fresh install's lid defaults suspend at both
  the logind and XFCE layers.
- XFCE power manager set to never suspend (user level, no root). The system
  level is packaged, not applied: `scripts/provision_host.sh` (needs `sudo`),
  verified by `scripts/check_host_config.sh` (no root; 19 unit tests), wired
  into `scripts/run_tests.sh` as a host tier.
- Moved the compose bind mount from `./config` (`compose/config/`, which had
  its own ignore-everything `.gitignore`) to `../config`, the repository-root
  `config/` that README, `.gitignore` and `docs/ENV_VARS.md` describe. Root
  `config/` ignores runtime state selectively so hand-authored YAML can be
  tracked; added `.HA_VERSION` and `blueprints/` to that list.
- Merged the orphaned 2026-09-04 branch `docs/broadcom-driver-correction`.
- Docs brought from "planned" to "observed" where observation happened:
  `SETUP.md`, `OPERATIONS.md`, `TROUBLESHOOTING.md`, `OTS_SOFTWARE.md`,
  `TEST_PLAN.md`, `COMMAND_REFERENCE.md`, `README.md`.

**Pending Work**

- `provision_host.sh` has **not run**. `sudo` requires a password on this
  machine and the agent has no terminal for it — by design.
- Nothing promoted in `docs/REQUIREMENTS_TRACEABILITY.md`. `FR-001`'s check
  has executed on the hub and *failed* (pre-provisioning); `FR-004`'s and
  `FR-002`'s have not executed. Promotion waits for passes.
- gbrain is not configured on this machine; `check_gbrain_state.sh` reports
  STALE here (advisory). Needs `/setup-gbrain` with the Supabase password.
- `docs/SETUP.md` step 7 and the Docker/HA troubleshooting entries are still
  plans.

**Verification Run**

- Ran on the hub: `bash scripts/run_tests.sh` — static tier PASS;
  `test_check_host_config.sh` 19/19; host-config tier **FAIL** (expected:
  logind suspend, sleep targets static, docker/ssh not installed); compose
  tier SKIP (no Docker); smoke SKIP. `pre-commit run --all-files` clean.
  `check_next_steps.sh` on this file.
- Not run: `provision_host.sh` (needs root), any lid-close, reboot, or
  power-cut test, `docker compose config`, `smoke_check.sh`.

**Instructions for Next Agent**

After the human has run `provision_host.sh` and rebooted, run
`bash scripts/check_host_config.sh`. If it passes, that is the first moment
`FR-001-AC-2/AC-3` have evidence — but `FR-001` still needs AC-1 (30 minutes
lid-closed over SSH) before promotion. Then `docker compose -f
compose/docker-compose.yml config --quiet` closes GAP-004 and `FR-004` can be
promoted per "Promoting a Deferred Requirement". Do not promote on the basis
of the script existing.

## Next Steps

**Human action required:** steps 1, 3, 5, 7 and 8.

1. [ ] **HUMAN** — Run the root-level provisioning script on the hub
   - **Why a human:** `sudo` requires the operator's password; the agent has no terminal to enter it and must not have one.
   - **You need:** to be logged in on `peppermint-patty` (locally or over the console), the sudo password.
   - **Procedure:**
     1. `cd ~/macbook-home-hub && git checkout provision/first-host-run` (or `master` once merged).
     2. Read `scripts/provision_host.sh` once — it installs an SSH server and Docker and changes power policy.
     3. `sudo bash scripts/provision_host.sh`
     4. `sudo reboot` (applies the logind drop-in; this is also the FR-003 reboot test once the stack is up).
     5. After reboot: `bash scripts/check_host_config.sh` — must end with `Host configuration check PASSED` (the XFCE lines may read SKIP over SSH; that is fine).
   - **Done when:** `check_host_config.sh` prints `Host configuration check PASSED`.
2. [ ] **AGENT** — With `check_host_config.sh` passing (step 1), move OTS-002 and OTS-006 to Active; run `docker compose -f compose/docker-compose.yml config --quiet` on the hub, close GAP-004, promote `FR-004` to Active in `docs/PRODUCT_REQUIREMENTS.md` / `docs/REQUIREMENTS_TRACEABILITY.md` / `docs/TEST_PLAN.md` in one change _(blocked by step 1)_
3. [ ] **HUMAN** — Lid-closed reachability test (FR-001-AC-1) _(blocked by step 1)_
   - **Why a human:** someone has to physically close the lid and SSH in from another machine.
   - **You need:** a second machine on the LAN with an SSH client.
   - **Procedure:**
     1. From the other machine: `ssh esanacore@192.168.1.192` and leave the session open.
     2. Close the MacBook's lid. Wait 30 minutes.
     3. In the SSH session run `uptime`; it should still answer, with no gap.
   - **Done when:** SSH answered after 30+ minutes lid-closed. Tell the next agent so `FR-001` can be promoted.
4. [ ] **AGENT** — Bring up the stack (`docker compose -f compose/docker-compose.yml up -d`), run `HUB_HOST=192.168.1.192 bash scripts/smoke_check.sh` (from the hub itself is fine for the HTTP check; FR-002-AC-1 wants it from another LAN host too), close GAP-002, promote `FR-002`; rewrite `docs/SETUP.md` step 7 and the Docker/HA troubleshooting entries from observation _(blocked by step 1)_
5. [ ] **HUMAN** — Complete Home Assistant onboarding in the browser _(blocked by step 4)_
   - **Why a human:** creates the owner account; a credential the agent must not hold.
   - **Done when:** `http://192.168.1.192:8123` shows the Home Assistant dashboard after login.
6. [ ] **AGENT** _(suggestion)_ — Harden SSH to key-only auth with an `/etc/ssh/sshd_config.d/` drop-in once a key is on the box; add the drop-in to `provision_host.sh` behind a flag.
7. [ ] **HUMAN** — Run `/setup-gbrain` in this repository on the hub
   - **Why a human:** it needs the Supabase database password, which lives only in the other machine's `~/.gbrain/config.json`.
   - **Done when:** `bash scripts/check_gbrain_state.sh` reports OK on `peppermint-patty`.
8. [ ] **HUMAN** — Review and merge the pull request for `provision/first-host-run`, then delete the merged `docs/broadcom-driver-correction` branch (its commits are included)
   - **Why a human:** merges and branch deletion are the maintainer's decision.
   - **Done when:** the PR shows as merged and `git branch -r` no longer lists `origin/docs/broadcom-driver-correction`.
9. [ ] **AUTOMATED** — CI (`constitution-*.yml`) runs on the PR; watch `constitution-tests` and `constitution-doc-freshness` for a red run.

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
