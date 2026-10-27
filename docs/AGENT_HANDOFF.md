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

### Session: 2026-10-12 (after reboot) — Claude (Claude Code), on the hub

**Accomplishments**

- The operator rebooted; the session resumed with `claude --continue`.
  `check_host_config.sh` PASS (all 16 lines OK) and
  `HUB_HOST=192.168.1.192 bash scripts/run_tests.sh` **11 PASS / 0 FAIL /
  0 SKIP** — first fully green run on the hub. Boot 14 s, container up 14 s
  after boot, HTTP 302 about a minute after boot, nobody touched it.
- Promoted `FR-003` (Active, Verified) and `FR-001` (Active, In Progress —
  AC-2/AC-3 verified, lid test pending). Closed GAP-003; GAP-001 reduced to its
  AC-1 residual. Matrix, test plan, inventory, TODO, README, CHANGELOG updated.

**Pending Work**

- Manual residuals: FR-001-AC-1 (30 min lid-closed over SSH) and FR-002-AC-1
  (curl from a second LAN host). Onboarding. gbrain on this machine.
- Constitution bumped 1.52.0 → 1.53.0 in PR #20 (operator chose to fold it
  into that PR on 2026-10-26 instead of a separate bump PR). 1.53.0 is
  documentation-standard only (per-platform README blocks, `<details>`
  progressive disclosure); adopting it in `README.md` is open in TODO.md.
- Release: `CHANGELOG.md` Unreleased is large and the hub is verifiably
  serving — cut `0.2.0` after PR #17 merges (see Next Steps).

**Verification Run**

- Ran on the hub after reboot: `check_host_config.sh`, full `run_tests.sh`
  with `HUB_HOST`, `check_traceability.sh`, `pre-commit run --all-files`,
  `check_next_steps.sh`.
- Not run: lid-close, power-cut, restore, router inspection, onboarding.

**Instructions for Next Agent**

The host side is done. The next substantive work is operational: a backup
job for `config/` to another machine with a tested restore (FR-007,
GAP-005), and the root-owned-files decision (`PUID`/`PGID`). Promote
`FR-001` to Verified only when the operator reports the lid test, and
`FR-002` only after a second-host curl. Do not touch the lid policy from a
desktop session.

### Session: 2026-10-12 (continued) — Claude (Claude Code), on the hub

**Accomplishments**

- The operator ran `sudo bash scripts/provision_host.sh` in a terminal window
  the agent opened (the `!` prefix has no TTY for sudo). Exit 0: logind
  drop-in written, four sleep targets masked, `openssh-server` / `docker.io` /
  `docker-compose-v2` installed, `ssh.socket` + `docker` enabled, user added
  to `docker`.
- Without re-login (`sg docker -c`), validated the compose file (PASS), pulled
  and started Home Assistant 2026.8.0; `:8123` answered HTTP 302 ~10 s after
  start; `smoke_check.sh` PASS against `192.168.1.192`; full suite with
  `HUB_HOST`: 10 PASS / 1 FAIL (host config, pending reboot) / 0 SKIP.
- Promoted `FR-002` (In Progress) and `FR-004` (Verified) to Active; closed
  GAP-002, GAP-004; OTS-002/003/006 → Active; committed HA's starter YAML;
  `.ha_run.lock` gitignored; SETUP step 7 and the HA troubleshooting entries
  rewritten from observation; new Bluetooth-traceback entry.
- `ufw` is installed but disabled (`ENABLED=no`), so nothing filters 22/8123.

**Pending Work**

- **Reboot not done.** logind still reports `suspend` live, and the shell's
  group list lacks `docker`. `check_host_config.sh` therefore still FAILs on
  those two lines — correct, not a bug. The reboot also serves as the FR-003
  test now that the stack is up.
- `FR-002-AC-1` from a second LAN host; onboarding; lid test; gbrain setup.
- HA writes `config/` files as root — decision on `PUID`/`PGID` pending.

**Verification Run**

- Ran on the hub: `provision_host.sh` (operator), `check_host_config.sh`,
  `docker compose config`, `smoke_check.sh`, full `run_tests.sh` with
  `HUB_HOST`, `check_traceability.sh` (4 Active IDs, all with executed checks),
  `pre-commit run --all-files`, `check_secrets.sh`, `check_next_steps.sh`.
- Not run: reboot, lid-close, power-cut, restore, router inspection.

**Instructions for Next Agent**

First command: `bash scripts/check_host_config.sh`. If the reboot has
happened it should PASS; then promote `FR-003` (HA answered within 5 min of an
unattended reboot — confirm with `uptime` and `smoke_check.sh`) and, once the
operator reports the 30-minute lid test, `FR-001`. If it still FAILs on the
logind lines, the reboot has not happened — ask for it rather than restarting
logind from inside a desktop session.

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

**Human action required:** steps 1, 2, 4, 5 and 6.

1. [ ] **HUMAN** — Lid-closed reachability test (FR-001-AC-1) and second-host check (FR-002-AC-1)
   - **Why a human:** someone has to physically close the lid and connect from another machine.
   - **You need:** a second machine on the LAN with an SSH client.
   - **Procedure:**
     1. From the other machine: `ssh esanacore@192.168.1.192`, leave it open.
     2. There too: `curl -sI http://192.168.1.192:8123/ | head -1` — expect `HTTP/1.1 302`.
     3. Close the hub's lid. Wait 30 minutes. Run `uptime` in the SSH session.
   - **Done when:** SSH answered after 30+ minutes lid-closed and the curl returned 2xx/3xx. Tell the next agent so `FR-001` and `FR-002` can be marked Verified and GAP-001 closed.
2. [ ] **HUMAN** — Complete Home Assistant onboarding
   - **Why a human:** creates the owner account, a credential the agent must not hold.
   - **Done when:** `http://192.168.1.192:8123` shows the dashboard after login.
3. [ ] **AGENT** — Mark `FR-001`/`FR-002` Verified and close GAP-001 once step 1 is reported; then cut release `0.2.0` (bump `VERSION`, move `Unreleased` to a dated section, tag) _(blocked by step 1)_
4. [ ] **HUMAN** — Review and merge PR #17, then close PR #10 as superseded (its three commits are merged into #17) and delete `docs/broadcom-driver-correction`
   - **Why a human:** merges, PR closure and branch deletion are the maintainer's decision.
   - **Done when:** #17 merged, #10 closed, and `origin/docs/broadcom-driver-correction` is gone.
5. [ ] **HUMAN** — Run `/setup-gbrain` in this repository on the hub
   - **Why a human:** needs the Supabase password, which lives only in the other machine's `~/.gbrain/config.json`.
   - **Done when:** `bash scripts/check_gbrain_state.sh` reports OK on `peppermint-patty`.
6. [x] **HUMAN** — Approve the constitution bump to 1.53.0 — approved 2026-10-26, landed with PR #20
   - **Why a human:** the bump is a separate PR that needs review and merge.
   - **Done when:** `version-gate` is green on master.
7. [ ] **AGENT** _(suggestion)_ — Backup job for `config/` to another machine with a tested restore (FR-007); decide `PUID`/`PGID` vs root-owned config files; key-only SSH.
8. [ ] **AUTOMATED** — CI (`constitution-*.yml`) runs on the PR; the traceability gate now covers six IDs.
