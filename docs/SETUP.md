# Setup

How to set up this repository and provision the hub.

> **Provisioning status: in progress, partly verified.** The `MacBook8,1`
> (`peppermint-patty`) was imaged with Linux Mint 22.3 XFCE on 2026-10-12 and
> Part 2 below was run on it the same day, from inside the machine. Steps 1–3
> and 5 are **observed**; step 4's user-level half was done by hand. Step 4's
> system-level half and the whole of step 6 are packaged as `scripts/provision_host.sh`, which needs `sudo` and is run by the
> operator — what it does is recorded, whether it has run is checked by
> `scripts/check_host_config.sh`. Step 7 has not been run yet.

## Part 1: Repository (works today)

### Prerequisites

| Tool | Purpose | Notes |
| --- | --- | --- |
| `git` 2.13+ | Clone and submodules | `--recurse-submodules` support |
| `bash` 4+ | Constitution check scripts | Preinstalled on Linux and macOS |
| `pre-commit` | Commit and pre-push hooks | `uv tool install pre-commit` (see below) |
| Bun 1.0+ | gstack runtime (optional) | Only if using gstack skills |

There is no application runtime to pin — this repository holds configuration,
documentation, and shell checks. No `package.json`, no `requirements.txt`.

### Clone

```bash
git clone --recurse-submodules <repository-url>
cd macbook-home-hub
```

If you already cloned without submodules, `constitution/` will be empty:

```bash
git submodule update --init --recursive
```

### Verify prerequisites

This should pass on a correct checkout and name exactly what is missing
otherwise:

```bash
test -d constitution/scripts || echo "FAIL: constitution submodule not initialized"
bash constitution/scripts/check_compliance.sh
bash constitution/scripts/check_secrets.sh
```

### Activate the hooks

Stock Mint 22.3 ships no `pip`, and its system Python is externally managed,
so install `pre-commit` as a `uv` tool (what both machines so far have done):

```bash
curl -fsSL https://astral.sh/uv/install.sh -o /tmp/uv-install.sh && sh /tmp/uv-install.sh   # installs to ~/.local/bin
uv tool install pre-commit
pre-commit install
pre-commit install --hook-type pre-push   # required: the secrets sweep is a pre-push hook
pre-commit run --all-files                # should pass clean
```

Also set a Git identity if the machine is new (`git config --global user.name`
/ `user.email`) — a fresh install has none, and the first merge fails without
it.

### Optional: gstack tooling

`CLAUDE.md` references the gstack skill suite. It installs per machine, not
per repository:

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
bash constitution/scripts/setup-machine.sh   # installs Bun + gstack (idempotent)
```

### IDE setup

This project follows Eric's Engineering Constitution. To have it applied
automatically in **Visual Studio**, **VS Code**, or a **JetBrains IDE**,
install an AI coding assistant (GitHub Copilot, Continue.dev, or Cursor) and
open the repository — the assistant reads the instruction files committed here
and picks up the constitution with no extra configuration. See `docs/HELP.md`,
"Using This Project in Your IDE," for the per-IDE file mapping and
`constitution/INTEGRATION.md` for full details.

## Part 2: Host Provisioning

Observed on the hardware on 2026-10-12 unless a step says otherwise.

### Before you start

Have a **USB-C hub** in hand — the machine has a single USB-C port and you
need it to attach the install stick at all.

A **USB Ethernet adapter was not needed.** Wi-Fi worked in the live session
and after install with no driver work (see step 3). Keep one as insurance if
you have it; do not buy one for this.

### 1. Create install media

Done 2026-09-04: `linuxmint-22.3-xfce-64bit.iso`, SHA-256 verified against
Mint's signed manifest, written to a Samsung PSSD T7 and verified file by file
with the ISO's own `md5sum.txt`. The first stick tried was silently corrupting
data — the diagnosis is in `TODO.md` under Testing and the lessons in
`docs/MEMORY.md`. **Verify the media before trusting it.**

Boot holding `Option`/`Alt` and pick **EFI Boot**. The T7 is USB-C native and
booted without the hub.

### 2. Install to the internal SSD

Standard guided install onto the 256 GB Apple NVMe (`APPLE SSD AP0256H`,
`/dev/nvme0n1`). Result: Mint 22.3 "Zena", kernel `7.0.0-38-generic`, XFCE,
hostname `peppermint-patty`. Wi-Fi was available during the install.

### 3. Confirm networking

Nothing to install. What this machine shows:

```bash
lspci -nnk -s 01:00.0        # Broadcom BCM4350 [14e4:43a3], "Kernel driver in use: brcmfmac"
lsmod | grep brcmfmac        # brcmfmac, brcmfmac_wcc, brcmutil loaded
ip -br addr                  # wlp1s0 UP with a 192.168.1.x address
```

Note the interface is `wlp1s0`, not `wl*` — the earlier docs guessed the
proprietary driver's naming. The kernel log is worth reading once because it
looks alarming and is not:

```
brcmfmac: using brcm/brcmfmac4350c2-pcie for chip BCM4350/5
brcmfmac: Direct firmware load for brcm/brcmfmac4350c2-pcie.Apple Inc.-MacBook8,1.bin failed with error -2
brcmfmac: Direct firmware load for brcm/brcmfmac4350c2-pcie.txt failed with error -2
brcmfmac: no clm_blob available (err=-2), device may have limited channels available
brcmfmac: Firmware: BCM4350/5 wl0: Nov 26 2015 ... version 7.35.180.133
brcmfmac 0000:01:00.0 wlp1s0: renamed from wlan0
```

The missing Apple-specific NVRAM and CLM files are exactly the residual risk
the 2026-09-04 ISO inspection called out. The driver fell back to the card's
OTP and the interface came up and associated (WPA2) regardless. "Limited
channels" has not mattered on the home network.

**Do not install `broadcom-sta-dkms`.** It does not support `14e4:43a3`
(its table stops at `0x43a0`) and its modprobe blacklist can suppress
`brcmfmac`, which is the driver that works. `dpkg -l broadcom-sta-dkms`
confirms it is not installed here.

### 4. Apply always-on configuration

This is a prerequisite for hub duty, not optional tuning. Rationale in
`docs/OPERATIONS.md`. Two layers, because a laptop has two sleep policies:

**User level — the XFCE power manager** (done 2026-10-12, no root needed).
While a desktop session is logged in, `xfce4-power-manager` holds a
`handle-lid-switch` inhibitor on logind and applies its *own* lid policy, so
logind's setting alone is not enough:

```bash
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lid-action-on-ac       -n -t uint -s 0    # 0 = do nothing
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lid-action-on-battery  -n -t uint -s 0
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-ac       -n -t uint -s 14   # 14 = never
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-on-battery  -n -t uint -s 14
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/logind-handle-lid-switch -n -t bool -s false
systemd-inhibit --list | grep xfce4      # expect ...:handle-lid-switch in the WHAT column
```

Leaving `logind-handle-lid-switch=false` is deliberate: with it `true`, the lid
is handed to logind, which still suspends until the system half below has been
applied *and* taken effect.

**System level — logind and the sleep targets** (needs root; covers the
no-session case and headless boots). Packaged in `scripts/provision_host.sh`
together with step 6, so there is one reviewable command to run:

```bash
sudo bash scripts/provision_host.sh
```

It writes `/etc/systemd/logind.conf.d/50-macbook-home-hub.conf` (a drop-in,
not an edit of `logind.conf`) with `HandleLidSwitch*=ignore`, and runs
`systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`.
It does **not** restart `systemd-logind`, because that can end the session you
are typing in; the drop-in takes effect at the next boot, which is the next
step of this procedure anyway. Then verify, without root:

```bash
bash scripts/check_host_config.sh        # reads the live logind/systemd state
```

and finally close the lid for 30 minutes and confirm SSH still answers
(FR-001-AC-1).

### 5. Check for a battery charge limit

```bash
ls /sys/class/power_supply/BAT0/ | grep -i -E 'charge|threshold'
```

Observed 2026-10-12: `charge_full`, `charge_full_design`, `charge_now` only.
**No `charge_control_*_threshold` is exposed**, so there is no charge limit to
set on this model. Battery state at install: SMP `bq20z451`, 397 cycles,
`charge_full` 3885 mAh of 5297 mAh design (73%). Recorded in
`docs/OPERATIONS.md`; treat wear as expected.

### 6. Install SSH and Docker

Part of `scripts/provision_host.sh` (step 4). What it runs:

```bash
sudo apt-get install -y openssh-server docker.io docker-compose-v2
sudo systemctl enable --now ssh.socket docker   # Mint 22 ships sshd socket-activated
sudo usermod -aG docker "$USER"          # log out and back in for this to take effect
```

`docker-compose-v2` is the Mint 22 / Ubuntu 24.04 package that provides
`docker compose`; `docker-compose-plugin` (the name the earlier draft used)
only exists in Docker's own apt repository, which this host does not add.
Afterwards:

```bash
docker run --rm hello-world
bash scripts/check_host_config.sh        # docker + ssh items should now be OK
```

### 7. Bring up Home Assistant

Run 2026-10-12, from the repository root. Until you have logged out and back
in after step 6, prefix Docker commands with `sg docker -c '...'` so the new
group applies to that command without a new session:

```bash
docker compose -f compose/docker-compose.yml config --quiet   # validate first — PASS
docker compose -f compose/docker-compose.yml up -d            # pulls ~2 GB; a few minutes on this Wi-Fi
docker compose -f compose/docker-compose.yml logs -f home-assistant
```

Observed: `:8123` answered **HTTP 302** (redirect to onboarding) about 10
seconds after the container started — much faster than the "several minutes"
the earlier draft expected. The first log lines include a red
`habluetooth ... Missing NET_ADMIN/NET_RAW capabilities for Bluetooth
management` traceback; it is harmless (no Bluetooth integration is configured;
see `docs/TROUBLESHOOTING.md`). Home Assistant wrote its starter files into
`config/` as **root**: `configuration.yaml`, `automations.yaml`,
`scenes.yaml`, `scripts.yaml` (tracked — they are the hand-authored layer),
and `secrets.yaml`, `.storage/`, the SQLite database, logs and `.ha_run.lock`
(all gitignored). Then the smoke check:

```bash
HUB_HOST=192.168.1.192 bash scripts/smoke_check.sh    # PASS: ping OK, HTTP 302, container running
```

That run was from the hub itself against its LAN address. `FR-002-AC-1` wants
the same result from a second machine on the LAN — do that once from your
laptop. Complete onboarding in a browser at `http://192.168.1.192:8123`.

## Environment Variables

The compose stack declares one variable, `TZ`, documented in
`docs/ENV_VARS.md`. Any variable added to a manifest must be documented there
in the same change — `constitution/scripts/check_env_vars.sh` enforces this
for root-level manifests.
