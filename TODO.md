# TODO

This file is the living roadmap for the project.

Keep entries specific, actionable, and current.

## Provisioning (host)

- [x] **Install media written and verified 2026-09-04.**
      `linuxmint-22.3-xfce-64bit.iso` downloaded and verified end to end
      (SHA-256 matched Mint's GPG-signed `sha256sum.txt`), written to a
      **Samsung PSSD T7** (serial `S6XGNS0TC00592P`) at 317 MB/s. All 1294
      files pass Mint's own `md5sum.txt` manifest. The Verbatim stick that was
      tried first is dead — see the media item under Testing below.
- [x] Boot the MacBook8,1 from the T7 and install. Done 2026-10-12: Linux
      Mint 22.3 XFCE on the internal 256 GB NVMe, hostname `peppermint-patty`,
      kernel `7.0.0-38-generic`, Wi-Fi `wlp1s0` at `192.168.1.192`.
- [x] **Broadcom finding confirmed on real hardware 2026-10-12.**
      `lspci -nnk` shows `[14e4:43a3]` with `brcmfmac` in use; Wi-Fi worked in
      the live session and after install with no dongle and no
      `broadcom-sta-dkms`. The Apple-specific NVRAM/CLM files the ISO lacks did
      fail to load (kernel log) and the OTP fallback carried it, exactly as
      predicted. `docs/SETUP.md` and `docs/TROUBLESHOOTING.md` now say
      "observed". No USB Ethernet adapter was needed.
- [x] Check whether a battery charge-limit control is exposed. Done
      2026-10-12: it is not (`charge_full*`/`charge_now` only, no
      `charge_control_*`). Baseline 397 cycles / 73% health recorded in
      `docs/OPERATIONS.md`.
- [x] XFCE power manager set to never suspend (lid = nothing, idle = never,
      keeps its own lid inhibitor). Done 2026-10-12 via `xfconf-query`; see
      `docs/SETUP.md` step 4.
- [x] **`sudo bash scripts/provision_host.sh` run on the hub 2026-10-12**
      (operator, in a terminal window). Logind drop-in written, four sleep
      targets masked, `openssh-server` 9.6p1 / `docker.io` 29.1.3 /
      `docker-compose-v2` 2.40.3 installed, `ssh.socket` + `docker` enabled,
      user added to `docker`. `check_host_config.sh` afterwards: sleep
      targets, docker, ssh OK; logind still `suspend` and group membership
      not yet in the session — both clear at the first reboot.
- [x] **Reboot the hub.** Done 2026-10-12: boot in 14 s, container up 14 s
      later, `check_host_config.sh` PASS, full suite with `HUB_HOST` 11/11
      PASS. FR-003 Verified; FR-001 Active with AC-2/AC-3 verified.
- [ ] Verify the box stays reachable over SSH with the lid closed for 30 min
      (FR-001-AC-1, GAP-001). Only meaningful after the reboot above.
- [ ] Set a DHCP reservation for `peppermint-patty` on the router so
      `192.168.1.192` stops being an assumption in the docs.
- [ ] Harden SSH after it is installed: key-only auth
      (`PasswordAuthentication no` in a `/etc/ssh/sshd_config.d/` drop-in) once
      a key is on the box. `provision_host.sh` installs distro defaults on
      purpose so the first login is not locked out.
- [ ] Set up gbrain on this machine: run `/setup-gbrain` here (needs the
      Supabase password, which lives only in the other machine's
      `~/.gbrain/config.json`). Until then `scripts/check_gbrain_state.sh`
      reports STALE on the hub — the expected cross-machine signal.
- [ ] Reclaim the T7's capacity now that the install is done. `dd` replaced
      its partition table, so 1.8 TB currently presents as a 2.8 GB volume;
      repartition and reformat.

## Services (stack)

- [x] Author `compose/docker-compose.yml` with Home Assistant Container,
      pinned to a dated stable image tag (`2026.8.0`); bind-mount `config/`.
      Bind mount moved 2026-10-12 from `./config` (`compose/config/`, which
      had its own ignore-everything `.gitignore`) to `../config`, the
      repository-root `config/` that README and `.gitignore` describe, so
      hand-authored YAML can be tracked while runtime state is ignored.
      `docker compose config` PASS on the hub 2026-10-12; GAP-004 closed.
- [x] Bring HA up and confirm reachable at `:8123`. Done 2026-10-12:
      `ghcr.io/home-assistant/home-assistant:2026.8.0` pulled and started,
      HTTP 302 within ~10 s, `smoke_check.sh` PASS against `192.168.1.192`.
      Starter YAML (`configuration.yaml`, `automations.yaml`, `scenes.yaml`,
      `scripts.yaml`) committed as the hand-authored layer.
- [ ] Complete Home Assistant onboarding in a browser at
      `http://192.168.1.192:8123` (creates the owner account — human).
- [ ] Run `HUB_HOST=192.168.1.192 bash scripts/smoke_check.sh` from a
      **second** LAN machine to satisfy FR-002-AC-1 literally; then mark
      FR-002 Verified.
- [ ] HA writes `config/` files as root (`default_config` starter files are
      `root:root 644`). Decide whether to run the container with `PUID`/`PGID`
      or accept root-owned files and edit via `sudo`; see `docs/ENV_VARS.md`
      Anticipated Variables.
- [ ] Decide whether Mosquitto (MQTT) is needed based on chosen devices; add
      container if so.
- [ ] Evaluate Node-RED as optional flow editor.

## Home automation (decisions still open)

- [ ] Decide the first real automation use case (the "not sure how yet" item).
- [ ] Choose initial devices (candidates already in play: Shelly Pro 4PM,
      Kauf PLF12 smart plugs).

## Operations

- [ ] Stand up a backup job for the HA config volume to another machine; store
      the HA backup encryption key off the hub.
- [ ] Decide on basic alerting (even just "hub unreachable") — none yet.

## Testing

- [x] **Install-media write failure diagnosed and resolved 2026-09-04:
      failing USB stick, since discarded.** Three writes of the verified ISO to
      the Verbatim STORE_N_GO (29.3 GB, serial `F6FE8AE03B513808`) each failed
      verification on `casper/filesystem.squashfs` (1293 of 1294 files OK),
      including one after `wipefs -a` with buffered I/O instead of
      `oflag=direct`. Every write reported success and the kernel logged **no
      I/O errors** — the corruption was entirely silent.

      What identified the stick rather than the host: the first differing byte
      **moved** between attempts (330420225, then 305254401), ruling out a
      fixed bad block, and three cold reads of one unchanged 64 MB region —
      unmounting and remounting between each to defeat the page cache —
      returned **three different MD5s**. A device that cannot reproduce its own
      contents on read cannot store data.

      Everything else was exonerated by evidence: the source ISO re-hashed
      correctly twice (so the download and RAM were fine), the pristine ISO
      matched its own manifest (`fc2e8a25f449b1ec36dc09bbed38b69d`, so the
      manifest was not stale), and the Samsung T7 then wrote and verified
      1294/1294 through the same USB subsystem, RAM, and `dd` invocation.

      Lesson worth keeping: `dd` exiting 0 is not evidence that media is good,
      and neither is a clean `dmesg`. Verify written media against a manifest
      before trusting it — Mint ships `md5sum.txt` on the ISO for exactly this.
      An unverified live USB fails later, on unfamiliar hardware, in ways that
      look like problems with that hardware.

      Note also that `dd` was originally killed mid-write when Xorg segfaulted
      in `nvidia_drv.so` and took the session down. Long writes should run
      detached (`systemd-run --unit=... --service-type=oneshot`) so a desktop
      crash cannot truncate them.
- [x] Define what "tests" mean for a config repo — declared in
      `docs/TEST_PLAN.md`, implemented as `scripts/run_tests.sh` (static +
      config tiers) and `scripts/smoke_check.sh` (host tier).
- [x] Execute `scripts/smoke_check.sh` against the real hub. Done
      2026-10-12 — PASS; GAP-002 closed, FR-002 promoted to Active (In
      Progress until the second-host run).
- [ ] Close GAP-001's residual: verify the host stays reachable 30+ min with
      the lid closed (FR-001-AC-1); then mark FR-001 Verified.
- [x] Close GAP-003. Done 2026-10-12 — stack returned unattended after
      `sudo reboot`; FR-003 Verified.
- [x] Close GAP-004. Done 2026-10-12 — compose tier PASS on the hub; FR-004
      promoted to Active and Verified.
- [x] Executable check for FR-001-AC-2/AC-3 written and unit-tested:
      `scripts/check_host_config.sh` + `scripts/test_check_host_config.sh`
      (19 cases), wired into `scripts/run_tests.sh` as a blocking host-tier
      check on the hub, SKIP elsewhere. Done 2026-10-12. After provisioning
      it passes everything except the two items that need a reboot (logind
      live value, docker group in session).
- [ ] Close GAP-005: perform a real restore from backup onto a clean target
      (FR-007). An untested restore is not a backup.
- [ ] Close GAP-006: pull mains power for 10 minutes and confirm the hub keeps
      serving on battery (NFR-002).
- [ ] Close GAP-007: measure steady-state memory under real automation load
      and record the baseline (NFR-003).
- [ ] Close GAP-008: confirm no router port-forward exposes `:8123` or `:22`
      (NFR-005).

## Documentation

- [x] Replace `docs/SETUP.md` Part 2 with what was actually observed and
      typed. Done 2026-10-12 for steps 1–6; step 7 (bring up Home Assistant)
      still reads as a plan until it has been run.
- [~] Rewrite the **(anticipated)** entries in `docs/TROUBLESHOOTING.md` with
      observed symptoms. Done 2026-10-12 for Wi-Fi, battery, and the lid
      defaults; the Docker/Home Assistant entries stay anticipated until the
      stack has run.
- [x] Record the battery charge-limit finding in `docs/OPERATIONS.md`. Done
      2026-10-12 (absent; baseline recorded).
- [~] Move `docs/OTS_SOFTWARE.md` entries from `Evaluating` to `Active` as
      each component is actually deployed. OTS-001 (Mint 22.3) is Active as of
      2026-10-12; Docker, OpenSSH (new row OTS-006) and Home Assistant wait.
- [ ] Rewrite `docs/SETUP.md` step 7 and the Docker/HA troubleshooting entries
      from observation after the stack's first start.

## Tooling & Compliance

- [x] **Restore the traceability gate to blocking.** Done — the `|| true` and
      step-summary block are gone. Rather than waiting for the gap log to
      empty, the requirement set was split: 2 verifiable requirements are
      Active (bold IDs, gated), and the 10 hardware-blocked ones are Deferred
      (backticked IDs, outside the gate) in `docs/PRODUCT_REQUIREMENTS.md`.
- [ ] **Re-evaluate the constitution pin when upstream fixes `v1.44.0`.**
      Currently pinned to `v1.43.0`. The `v1.44.0` tag points at a commit whose
      `VERSION` reads `1.25.0`, so it was skipped. That malformed tag also
      makes `constitution-version.yml` report "diverged" and pass instead of
      "BEHIND" and fail — do not trust a green `version-gate` to mean the
      submodule is current until this is resolved. Worth reporting upstream.
- [ ] **Adopt `constitution-wiki.yml` if a `wiki/` is ever introduced.** Not
      adopted at 1.43.0 because this repository has no wiki and the template's
      publish job fails until a GitHub wiki is initialized by hand.
- [ ] **Promote each deferred requirement as its blocker clears.** Follow
      "Promoting a Deferred Requirement" in `docs/PRODUCT_REQUIREMENTS.md`:
      bold the ID, fill its Verifying Tests cell with a check that actually
      ran, and close its gap-log row — in one change. Bolding without a
      verifying test fails CI, which is the intended safety property.
      Never resolve a CI failure here by moving a requirement back to
      Deferred; deferral means "cannot be checked yet", not "the check is
      inconvenient".
- [x] Install and activate the pre-commit hooks on this machine
      (`uv tool install pre-commit && pre-commit install && pre-commit install --hook-type pre-push`).
      Hooks installed 2026-08-15; `pre-commit run --all-files` passes clean.
- [x] Enable branch protection and "Automatically delete head branches" in the
      hosting platform settings (see `constitution/INTEGRATION.md`,
      "Repository Settings Checklist"). Done by user 2026-08-15.
- [x] Run `/setup-gbrain` once in this repository to initialize the gstack
      project brain. Done 2026-08-15 — Supabase engine (project
      `yvamohixcwjchhxufrcm`, us-west-1), MCP registered at user scope, repo
      policy read-write. CLAUDE.md carries the `## GBrain Configuration` and
      `## GBrain Search Guidance` blocks. See `docs/TEST_PLAN.md` for the
      staleness checker that gates the block against cross-machine clone drift.
- [x] Delete `.constitution-bootstrap/` — adoption is complete; the directory
      is not read by any parent-repo script and `bootstrap.sh` recreates it if
      ever needed. Done 2026-08-15.

## Nice-to-Have

- [ ] Tie in existing hardware interests (e.g. the CleverPet/hackerpet cat
      setup) as HA integrations once the hub is stable.
