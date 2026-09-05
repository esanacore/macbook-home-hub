# Troubleshooting

Diagnosing this project means diagnosing one physical machine. The failures
below are the ones this specific hardware and install method are known to
produce.

Entries marked **(anticipated)** are drawn from the hardware's documented
behavior and the Container install method's known limits, not yet from a
provisioning run on this machine. They are corrected with observed detail once
the hub is actually built — see `TODO.md`.

## Host and Hardware

### No Wi-Fi during or after installation (ISO-verified; boot not yet observed)

> **Correction, 2026-09-04.** This entry previously prescribed
> `broadcom-sta-dkms`. That is the **wrong driver for this chip** — see
> "Do not install `broadcom-sta-dkms`" below. The correction comes from
> inspecting the Mint 22.3 XFCE ISO directly, not from a boot on the hardware.

- **Symptoms**: The live session shows no wireless networks. `ip link` lists no
  `wl*` interface.
- **Cause**: The `MacBook8,1` uses a Broadcom **BCM4350** (PCI `14e4:43a3`).
  The long-standing advice for Broadcom-on-Linux is the proprietary
  `broadcom-sta` (`wl`) driver, but that driver does not support this chip.
  BCM4350 is handled by the **in-tree `brcmfmac`** driver plus firmware.
- **Expectation**: On Mint 22.3 XFCE, Wi-Fi is expected to work in the live
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

### Hub becomes unreachable when the lid is closed (anticipated)

- **Symptoms**: SSH and `:8123` stop answering shortly after the lid shuts.
  The machine recovers when opened.
- **Cause**: Default laptop power policy suspends on lid close. Correct for a
  laptop, wrong for a hub.
- **Fix**: Apply the always-on configuration in `docs/OPERATIONS.md`
  (`HandleLidSwitch*=ignore` plus masking the sleep targets), then verify with
  `systemd-inhibit --list` and a real lid-close test over SSH.

### Machine suspends on idle despite the lid setting (anticipated)

- **Symptoms**: The box drops off the network after a period of no activity,
  lid open.
- **Cause**: The lid switch and idle suspend are separate policies. Fixing one
  does not fix the other, and the XFCE power manager can re-assert idle
  suspend independently of `logind`.
- **Fix**: Mask the sleep targets (see `docs/OPERATIONS.md`) *and* disable
  suspend in the XFCE power manager GUI. Verify with
  `systemctl status sleep.target` showing `masked`.

### Battery will not hold a charge limit

- **Symptoms**: No charge-threshold control appears under
  `/sys/class/power_supply/BAT*/`.
- **Cause**: A charge-limit control is not reliably exposed under Linux on
  this Broadwell model.
- **Fix**: There may be no fix. Confirm the absence, record the finding in
  `docs/OPERATIONS.md`, and plan on replacing the cell rather than preventing
  the wear. Do not install third-party tools that claim to set a threshold on
  unsupported hardware.

## Docker and Home Assistant

### Home Assistant does not answer on :8123 (anticipated)

- **Symptoms**: `curl http://<hub-ip>:8123` refuses the connection.
- **Cause**: Usually the container is not running, is still starting (first
  boot takes minutes), or is bound to the wrong network mode.
- **Fix**: Work outward from the container:
  ```bash
  docker compose ps                       # is it up, or restarting?
  docker compose logs --tail=100 home-assistant
  ss -tlnp | grep 8123                    # is anything listening on the host?
  ```
  A container stuck in a restart loop is a configuration error — read the log
  before restarting it again. Local device discovery generally requires
  `network_mode: host`; on a bridge network HA will start but find nothing.

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

### The secrets sweep never runs

- **Symptoms**: `pre-commit` passes, but `check_secrets.sh` is never invoked.
- **Cause**: The sweep is bound to the pre-push stage, and pre-commit does not
  install pre-push hooks unless asked.
- **Fix**: `pre-commit install --hook-type pre-push`.

### gstack skills are unavailable

- **Symptoms**: Skills listed in `CLAUDE.md` (`/browse`, `/ship`, ...) do not
  resolve.
- **Cause**: gstack is installed per machine, not per repository.
- **Fix**: Check with
  `test -d ~/.claude/skills/gstack/bin && echo GSTACK_OK || echo GSTACK_MISSING`.
  If missing, run `bash constitution/scripts/setup-machine.sh`.
