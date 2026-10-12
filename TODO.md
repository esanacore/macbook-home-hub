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
- [ ] Boot the MacBook8,1 from the T7: shut down fully, hold `Option`/`Alt`,
      select **EFI Boot**. The T7 is USB-C native, so it can connect directly
      without the hub — one less variable at Apple's boot picker.
- [ ] Reclaim the T7's capacity after the install. `dd` replaced its partition
      table, so 1.8 TB currently presents as a 2.8 GB volume; repartition and
      reformat once the MacBook no longer needs the media.
- [ ] Have a USB-C hub in hand as a fallback (single port on the machine). A
      USB Ethernet adapter is optional insurance rather than a hard
      prerequisite; see the Broadcom finding below. Note the MacBook has no
      built-in Ethernet, so the adapter only helps via the hub.
- [ ] **Confirm the Broadcom finding on real hardware.** ISO inspection on
      2026-09-04 shows `brcmfmac` + `brcmfmac4350-pcie.bin` ship in the Mint
      22.3 live filesystem, and that `broadcom-sta-dkms` does **not** support
      BCM4350 (`14e4:43a3`) — its supported table stops at `0x43a0`. The docs
      have been corrected accordingly. Verify at first boot with
      `lspci -nn | grep -i network`, `lsmod | grep brcmfmac`, and `ip link`,
      then downgrade the entries in `docs/TROUBLESHOOTING.md` and
      `docs/SETUP.md` from "ISO-verified" to observed. If `lspci` reports an ID
      other than `14e4:43a3`, the whole analysis needs redoing.
- [ ] Install to internal SSD. Do **not** install `broadcom-sta-dkms`.
- [ ] Apply always-on config: `HandleLidSwitch*=ignore`, mask sleep targets
      (see `docs/OPERATIONS.md`); verify box stays reachable with lid closed.
- [ ] Check whether a battery charge-limit control is exposed under Linux on
      this model; record the answer in `docs/OPERATIONS.md`.

## Services (stack)

- [ ] Install Docker Engine + Compose plugin.
- [x] Author `compose/docker-compose.yml` with Home Assistant Container,
      pinned to a dated stable image tag (`2026.8.0`); bind-mount `config/`.
      File exists; `docker compose config` validation still pending Docker
      being installed (GAP-004 stays open until then).
- [ ] Bring HA up, complete onboarding, confirm reachable at `:8123`.
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
- [ ] Execute `scripts/smoke_check.sh` against the real hub. It is written but
      has never run against hardware, so FR-002 stays a gap (GAP-002).
- [ ] Close GAP-001: verify the host stays reachable 30+ min with the lid
      closed (FR-001).
- [ ] Close GAP-003: verify the stack returns unattended after `sudo reboot`
      (FR-003).
- [ ] Close GAP-004: author `compose/docker-compose.yml` so the compose tier
      of the suite stops skipping (FR-004).
- [ ] Close GAP-005: perform a real restore from backup onto a clean target
      (FR-007). An untested restore is not a backup.
- [ ] Close GAP-006: pull mains power for 10 minutes and confirm the hub keeps
      serving on battery (NFR-002).
- [ ] Close GAP-007: measure steady-state memory under real automation load
      and record the baseline (NFR-003).
- [ ] Close GAP-008: confirm no router port-forward exposes `:8123` or `:22`
      (NFR-005).

## Documentation

- [ ] Replace `docs/SETUP.md` Part 2 (currently marked **unverified**) with
      the commands actually typed during the first real provisioning run, not
      the anticipated ones.
- [ ] Rewrite the **(anticipated)** entries in `docs/TROUBLESHOOTING.md` with
      observed symptoms once the machine has been through a real install.
- [ ] Record the battery charge-limit finding in `docs/OPERATIONS.md` once
      checked (either way — confirming its absence is a valid result).
- [ ] Move `docs/OTS_SOFTWARE.md` entries from `Evaluating` to `Active` as
      each component is actually deployed and its verification observed.

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
