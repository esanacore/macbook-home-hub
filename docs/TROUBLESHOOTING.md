# Troubleshooting

Diagnosing this project means diagnosing one physical machine. The failures
below are the ones this specific hardware and install method are known to
produce.

Entries marked **(anticipated)** are drawn from the hardware's documented
behavior and the Container install method's known limits, not yet from a run
on this machine. Entries marked **(observed)** have been seen on the hub.
Anticipated entries are corrected with observed detail as the hub is built —
see `TODO.md`.

## Host and Hardware

### No Wi-Fi during or after installation (observed: did not happen)

> **Correction, 2026-09-04.** This entry previously prescribed
> `broadcom-sta-dkms`. That is the **wrong driver for this chip** — see
> "Do not install `broadcom-sta-dkms`" below.
>
> **Confirmed on the hardware, 2026-10-12.** Mint 22.3 XFCE booted with
> working Wi-Fi in the live session and after install, with no driver
> installed and no USB Ethernet adapter. `lspci -nnk` reports `[14e4:43a3]`,
> `Kernel driver in use: brcmfmac`; the interface is `wlp1s0`. The kernel
> picked `brcmfmac4350c2-pcie` firmware, logged `Direct firmware load for
> brcm/brcmfmac4350c2-pcie.Apple Inc.-MacBook8,1.bin failed` and `no clm_blob
> available ... limited channels`, then associated anyway (OTP fallback, as
> predicted below). Kernel `7.0.0-38-generic`. The rest of this entry is kept
> as the diagnostic path for the day it *does* fail.

- **Symptoms**: The live session shows no wireless networks. `ip link` lists no
  `wl*` interface.
- **Cause**: The `MacBook8,1` uses a Broadcom **BCM4350** (PCI `14e4:43a3`).
  The long-standing advice for Broadcom-on-Linux is the proprietary
  `broadcom-sta` (`wl`) driver, but that driver does not support this chip.
  BCM4350 is handled by the **in-tree `brcmfmac`** driver plus firmware.
- **Expectation (now observed)**: On Mint 22.3 XFCE, Wi-Fi works in the live
  session with no driver install and no dongle. The required pieces ship on the
  ISO and are preinstalled in the live filesystem:

  | Component | Present on Mint 22.3 XFCE ISO |
  | --- | --- |
  | `brcmfmac4350-pcie.bin` | yes — `/usr/lib/firmware/brcm/` in the squashfs |
  | `brcmfmac4350c2-pcie.bin` | yes (C2 stepping variant) |
  | `linux-firmware` 20240318 | yes — preinstalled |
  | `brcmfmac` module | yes — in-tree, kernel 6.14.0-37 HWE |

- **First diagnostic**: confirm the chip before doing anything else.
  ```bash
  lspci -nn | grep -i network      # expect [14e4:43a3]
  lsmod | grep brcmfmac            # expect the module loaded
  dmesg | grep -i brcmfmac         # firmware load success or failure
  ```
  If `lspci` reports something other than `14e4:43a3`, this entry does not
  apply and the driver question must be re-derived from the actual ID.

- **If `brcmfmac` loads but the interface never appears**: the most likely
  cause is missing NVRAM. Mint 22.3 ships **no Apple-specific NVRAM blob** for
  this chip (no `brcmfmac4350-pcie.Apple*.txt` among the 108 files in
  `/usr/lib/firmware/brcm/`), so the driver must read calibration data from the
  card's own OTP. That normally works on Macs, but it is the one identified way
  this can still fail. Check `dmesg | grep -i brcmfmac` for an NVRAM
  complaint before concluding anything else is wrong.

- **Do not install `broadcom-sta-dkms`.** It is present in `pool/` on the ISO,
  so it looks like the right answer, but its own supported-hardware table
  (`/usr/share/doc/broadcom-sta-dkms/README`) ends at:
  ```
  4331  Dualband    0x14e4  0x4331
  4360  Dualband    0x14e4  0x43a0
  4352  Dualband    0x14e4  0x43a0
  ```
  `0x43a3` is absent. Installing it will not bind the chip, and its
  `/etc/modprobe.d` blacklist can suppress the driver that does work.

- **Fallback, only if the above genuinely fails**: a USB Ethernet adapter
  through the USB-C hub gives wired connectivity to work from. Note that a
  DKMS build can be done fully offline from the stick if ever needed —
  `dkms`, `gcc`, `libc6-dev`, and `linux-headers-6.14.0-37-generic` are all
  preinstalled in the live filesystem.

### Hub becomes unreachable when the lid is closed (anticipated; defaults observed)

- **Symptoms**: SSH and `:8123` stop answering shortly after the lid shuts.
  The machine recovers when opened.
- **Cause**: Default laptop power policy suspends on lid close. Correct for a
  laptop, wrong for a hub. Observed defaults on the fresh Mint 22.3 install
  (2026-10-12): logind `HandleLidSwitch=suspend`,
  `HandleLidSwitchExternalPower=` (empty, inherits suspend),
  `HandleLidSwitchDocked=ignore`; XFCE power manager `lid-action-on-battery=1`
  with the AC action unset. Both layers have to be changed — see "Keep running
  with the lid closed" in `docs/OPERATIONS.md`.
- **Fix**: `sudo bash scripts/provision_host.sh` for the logind drop-in and
  sleep-target masking; the `xfconf-query` lines in `docs/SETUP.md` step 4 for
  the desktop session. Then `bash scripts/check_host_config.sh` — it reads the
  *live* logind properties, so a drop-in that has been written but not applied
  (no reboot or logind restart yet) still shows FAIL. That is the signal to
  reboot, not a broken script. Finish with a real lid-close test over SSH.

### Machine suspends on idle despite the lid setting (anticipated)

- **Symptoms**: The box drops off the network after a period of no activity,
  lid open.
- **Cause**: The lid switch and idle suspend are separate policies. Fixing one
  does not fix the other, and the XFCE power manager can re-assert idle
  suspend independently of `logind`.
- **Fix**: Mask the sleep targets (`scripts/provision_host.sh`) *and* set the
  XFCE power manager's `inactivity-on-ac` / `inactivity-on-battery` to `14`
  ("never") — `xfconf-query` commands in `docs/SETUP.md` step 4, or the GUI.
  `bash scripts/check_host_config.sh` checks both.

### Battery will not hold a charge limit (observed)

- **Symptoms**: No charge-threshold control appears under
  `/sys/class/power_supply/BAT*/`.
- **Cause**: Confirmed 2026-10-12: `BAT0` exposes `charge_full`,
  `charge_full_design` and `charge_now` only. No `charge_control_*_threshold`
  exists on this model under Linux.
- **Fix**: None. The finding and a wear baseline (397 cycles, 73% of design
  capacity) are recorded in `docs/OPERATIONS.md`; plan on replacing the cell
  rather than preventing the wear. Do not install third-party tools that claim
  to set a threshold on unsupported hardware.

## Docker and Home Assistant

### Home Assistant does not answer on :8123 (anticipated; healthy baseline observed)

- **Symptoms**: `curl http://<hub-ip>:8123` refuses the connection.
- **Baseline (observed 2026-10-12)**: on first start the container answered
  HTTP 302 within about 10 seconds of `Started`. Minutes of silence is *not*
  normal on this machine.
- **Cause**: Usually the container is not running, is still starting, or is
  bound to the wrong network mode.
- **Fix**: Work outward from the container:
  ```bash
  docker compose ps                       # is it up, or restarting?
  docker compose logs --tail=100 home-assistant
  ss -tlnp | grep 8123                    # is anything listening on the host?
  ```
  A container stuck in a restart loop is a configuration error — read the log
  before restarting it again. Local device discovery generally requires
  `network_mode: host`; on a bridge network HA will start but find nothing.

### Red Bluetooth traceback in the Home Assistant log (observed)

- **Symptoms**: Right after start, `docker compose logs home-assistant` shows
  `ERROR ... [habluetooth.manager] Missing required permissions for Bluetooth
  management` and a `PermissionError: Missing NET_ADMIN/NET_RAW capabilities`
  traceback.
- **Cause**: `default_config:` loads the Bluetooth integration, which probes
  for an adapter it can manage; the container has no extra capabilities and
  no D-Bus socket mounted. Observed on first start 2026-10-12; Home Assistant
  served normally regardless.
- **Fix**: None needed unless Bluetooth devices are adopted. If they are, the
  Container install needs `cap_add: [NET_ADMIN, NET_RAW]` and
  `/run/dbus:/run/dbus:ro` in the compose file — record that as an ADR-level
  change, since it widens the container's privileges.

### Devices are not discovered (anticipated)

- **Symptoms**: HA runs fine, but no LAN devices appear.
- **Cause**: Container network isolation blocks the mDNS/broadcast traffic
  discovery depends on.
- **Fix**: Use `network_mode: host` for the Home Assistant service. This is a
  deliberate trade-off of the Container install method (ADR-0002), not a bug.

### Configuration changes have no effect

- **Symptoms**: Edits to files under `config/` do not change behavior.
- **Cause**: Either the bind mount does not point where you think, or HA has
  not reloaded the YAML.
- **Fix**: Confirm the mount with `docker compose config`, then restart:
  `docker compose restart home-assistant`. Validate YAML before restarting —
  a syntax error can leave HA refusing to start.

### An upgrade broke the install

- **Symptoms**: HA fails to start, or entities disappear, after an image pull.
- **Cause**: Home Assistant upgrades can migrate the config database, and the
  migration is not reversible by downgrading the image.
- **Fix**: Restore the config volume snapshot taken before the upgrade and pin
  the previous dated tag. If no snapshot was taken, the database migration may
  be unrecoverable — which is exactly why `docs/OPERATIONS.md` requires the
  snapshot first.

## Repository and Tooling

### `constitution/` is empty

- **Symptoms**: The directory exists but has no files; the required reading in
  `CLAUDE.md` and `AGENTS.md` resolves to nothing, and every
  `constitution/scripts/*.sh` command fails.
- **Cause**: `constitution/` is a git submodule and a plain `git clone` leaves
  it uninitialized.
- **Fix**: `git submodule update --init --recursive`. Clone with
  `--recurse-submodules` to avoid it entirely.

### `sudo` from an AI agent session hangs or fails

- **Symptoms**: An agent (Claude Code or similar) running on the hub cannot
  install packages or edit `/etc`; `sudo -n true` prints
  `sudo: a password is required`.
- **Cause**: The operator account needs a password for `sudo` and the agent
  has no terminal to type it into. This is the intended security posture
  (constitution `SECURITY.md`, "Agent Runtime Security"), not a fault.
- **Fix**: The root-level steps are collected in `scripts/provision_host.sh`
  so a human runs them deliberately: `sudo bash scripts/provision_host.sh`.
  Everything else in `docs/SETUP.md` runs unprivileged.

### The secrets sweep never runs

- **Symptoms**: `pre-commit` passes, but `check_secrets.sh` is never invoked.
- **Cause**: The sweep is bound to the pre-push stage, and pre-commit does not
  install pre-push hooks unless asked.
- **Fix**: `pre-commit install --hook-type pre-push`. If `pre-commit` itself
  is missing, stock Mint has no `pip` — install it with
  `uv tool install pre-commit` (see `docs/SETUP.md`).

### gstack skills are unavailable

- **Symptoms**: Skills listed in `CLAUDE.md` (`/browse`, `/ship`, ...) do not
  resolve.
- **Cause**: gstack is installed per machine, not per repository.
- **Fix**: Check with
  `test -d ~/.claude/skills/gstack/bin && echo GSTACK_OK || echo GSTACK_MISSING`.
  If missing, run `bash constitution/scripts/setup-machine.sh`.
