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

**Human action required:** steps 1, 3, 4, 6 and 7.

1. [ ] **HUMAN** — Reboot the hub
   - **Why a human:** a reboot ends every session on the machine, including the agent's; only the operator should choose the moment.
   - **You need:** to be at `peppermint-patty`, the sudo password.
   - **Procedure:**
     1. `sudo reboot`
     2. Wait 2 minutes, then from the hub (or over SSH) `cd ~/macbook-home-hub && bash scripts/check_host_config.sh`.
     3. `HUB_HOST=192.168.1.192 bash scripts/run_tests.sh`
   - **Done when:** `check_host_config.sh` prints `Host configuration check PASSED` and the suite reports 0 failed.
2. [ ] **AGENT** — Record the reboot result: promote `FR-003` (stack returned unattended; note `uptime` and time-to-302), move `FR-001`'s AC-2/AC-3 to verified, update the gap log and coverage row _(blocked by step 1)_
3. [ ] **HUMAN** — Lid-closed reachability test (FR-001-AC-1) _(blocked by step 1)_
   - **Why a human:** someone has to physically close the lid and SSH in from another machine.
   - **You need:** a second machine on the LAN with an SSH client.
   - **Procedure:**
     1. From the other machine: `ssh esanacore@192.168.1.192`, leave it open.
     2. Also run `HUB_HOST=192.168.1.192 bash scripts/smoke_check.sh` there (or `curl -sI http://192.168.1.192:8123/`) — this satisfies `FR-002-AC-1` from a second host.
     3. Close the lid. Wait 30 minutes. Run `uptime` in the SSH session.
   - **Done when:** SSH answered after 30+ minutes lid-closed and the curl from the second host returned 2xx/3xx. Tell the next agent so `FR-001` and `FR-002` can be marked Verified.
4. [ ] **HUMAN** — Complete Home Assistant onboarding
   - **Why a human:** creates the owner account, a credential the agent must not hold.
   - **Done when:** `http://192.168.1.192:8123` shows the dashboard after login.
5. [ ] **AGENT** _(suggestion)_ — Decide root-owned `config/` files vs `PUID`/`PGID`; harden SSH to key-only auth once a key is on the box; set up a backup job (FR-007).
6. [ ] **HUMAN** — Run `/setup-gbrain` in this repository on the hub
   - **Why a human:** needs the Supabase password, which lives only in the other machine's `~/.gbrain/config.json`.
   - **Done when:** `bash scripts/check_gbrain_state.sh` reports OK on `peppermint-patty`.
7. [ ] **HUMAN** — Review and merge PR #17, then delete `docs/broadcom-driver-correction` (its commits are included)
   - **Why a human:** merges and branch deletion are the maintainer's decision.
   - **Done when:** merged, and `origin/docs/broadcom-driver-correction` is gone.
8. [ ] **AUTOMATED** — CI (`constitution-*.yml`) runs on the PR; watch `constitution-tests`, `constitution-doc-freshness` and the traceability gate (now gating four IDs).
