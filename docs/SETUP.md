# Setup

How to set up this repository and provision the hub.

> **Provisioning status: unverified.** The `MacBook8,1` has not been imaged
> yet. The repository section below is executed and correct. The host
> provisioning section is the *planned* path derived from ADR-0002 and
> `docs/OPERATIONS.md` — it has not been run end to end on the hardware.
> Replace it with the actual captured commands after the first real run
> (tracked in `TODO.md`).

## Part 1: Repository (works today)

### Prerequisites

| Tool | Purpose | Notes |
| --- | --- | --- |
| `git` 2.13+ | Clone and submodules | `--recurse-submodules` support |
| `bash` 4+ | Constitution check scripts | Preinstalled on Linux and macOS |
| `pre-commit` | Commit and pre-push hooks | `pip install pre-commit` |
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

```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type pre-push   # required: the secrets sweep is a pre-push hook
```

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

## Part 2: Host Provisioning (planned, unverified)

### Before you start

Have a **USB-C hub** in hand — the machine has a single USB-C port and you
need it to attach the install stick at all.

A **USB Ethernet adapter** is worth having as insurance, but is probably not
required. This document previously stated that the Broadcom BCM4350 has no
driver in the live installer and that this was "the most likely thing to
derail a first attempt." Inspection of the Mint 22.3 XFCE ISO on 2026-09-04
contradicts that: the `brcmfmac` driver and its `brcmfmac4350-pcie.bin`
firmware are both present in the live filesystem, so Wi-Fi is expected to work
in the live session unaided. See `docs/TROUBLESHOOTING.md`, "No Wi-Fi during
or after installation," for the evidence and the residual risk (no
Apple-specific NVRAM blob ships, so the driver must read the card's OTP).

This expectation is derived from the image, **not** from a boot on the
hardware. Until someone has actually booted the MacBook, treat the adapter as
cheap insurance rather than dead weight.

### 1. Create install media

Flash Linux Mint XFCE to a USB stick (Fedora XFCE is the documented fallback —
see ADR-0002). Boot the MacBook holding `Option`/`Alt` and select the USB
device through the USB-C hub.

### 2. Install to the internal SSD

Standard guided install. Do not expect Wi-Fi to work during this step.

### 3. Confirm networking

Wi-Fi is expected to already work — verify rather than install:

```bash
lspci -nn | grep -i network   # expect Broadcom [14e4:43a3]
lsmod | grep brcmfmac         # expect the in-tree driver loaded
ip link                       # expect a wl* interface
```

**Do not install `broadcom-sta-dkms`.** Despite years of Broadcom-on-Linux
advice pointing at it, that driver does not support the BCM4350 — its own
supported-device table stops at `0x43a0`, and this chip is `0x43a3`.
Installing it cannot help and its modprobe blacklist can break the driver that
works. If any of the three commands above comes back empty, follow
`docs/TROUBLESHOOTING.md` rather than reaching for `wl`.

### 4. Apply always-on configuration

This is a prerequisite for hub duty, not optional tuning. Full rationale in
`docs/OPERATIONS.md`.

Edit `/etc/systemd/logind.conf`:

```ini
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

Then:

```bash
sudo systemctl restart systemd-logind    # run from a console or over SSH; may end the GUI session
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
systemd-inhibit --list                   # verify
```

Verify by closing the lid and confirming the box still answers over SSH. Also
disable idle suspend in the XFCE power manager — it is a separate policy from
`logind`.

### 5. Check for a battery charge limit

```bash
ls /sys/class/power_supply/BAT*/ | grep -i charge
```

Record the outcome in `docs/OPERATIONS.md` either way. A charge-limit control
is not reliably exposed on this model; confirming its absence is a valid
result.

### 6. Install Docker

```bash
sudo apt install docker.io docker-compose-plugin
sudo usermod -aG docker "$USER"    # log out and back in for this to take effect
docker run --rm hello-world
```

### 7. Bring up Home Assistant

`compose/docker-compose.yml` does not exist yet — authoring it, pinned to a
dated stable tag, is an open item in `TODO.md`. Once it exists:

```bash
docker compose up -d
docker compose logs -f home-assistant
```

Complete onboarding at `http://<hub-ip>:8123`. First start takes several
minutes.

## Environment Variables

This project declares no environment variables yet. When the compose stack
introduces them, document each one in `docs/ENV_VARS.md` in the same change —
`constitution/scripts/check_env_vars.sh` enforces this.
