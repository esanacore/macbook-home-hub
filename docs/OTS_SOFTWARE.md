# OTS Software Inventory

This inventory tracks every off-the-shelf (OTS) software component this project depends on: third-party libraries, frameworks, runtimes, databases, and any other software the project uses but did not develop. It answers, for each component: what it is, why we use it, how risky it is, how we verified it is fit for use, and how it stays current.

The structure follows the intent of the FDA's OTS software guidance and IEC 62304's SOUP (Software of Unknown Provenance) requirements, generalized for any repository — regulated or not. For most projects it is simply the auditable answer to "what third-party software are we shipping, and is anyone watching it?"

It is a living document. Update it in the same change that adds, removes, or upgrades a dependency.

Related documents:

- `SECURITY.md` (constitution) — dependency risk review expectations and threat-modeling triggers.
- `docs/TEST_PLAN.md` — where verification evidence (test suites exercising a component) is declared.

## Conventions

- **Component ID**: a stable identifier, `OTS-001`, `OTS-002`, ... Once assigned, an ID is never reused, even after the component is removed. When a component is removed, set its Status to `Removed` rather than deleting the row.
- **Name**: the component's name **exactly as it is declared in the dependency manifest** (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, ...). The automated checker (`constitution/scripts/check_ots_inventory.sh`) matches manifest entries against this cell by exact value (case-insensitive), so a paraphrased or prettified name counts as undocumented.
- **Risk**: `Low`, `Medium`, or `High`. A component is at least `Medium` when it sits in a trust-sensitive position — handling credentials, parsing untrusted input, or running with elevated privileges (see `SECURITY.md`'s "Threat Modeling Triggers").
- **Verification**: how fitness for use was established — for example, the project's own integration tests that exercise it, upstream test-suite maturity, vendor certification, or a manual validation record.
- **Anomaly Review**: known-issue posture — where known defects/CVEs for this component are tracked, and the date they were last reviewed.
- **Update Policy**: how the version moves — pinned exactly, pinned to a range, Dependabot/Renovate-managed, vendored, etc.
- **Status**: `Active`, `Evaluating`, or `Removed`.

## Managed Dependencies

Components declared in a dependency manifest in this repository. `constitution/scripts/check_ots_inventory.sh` cross-checks the manifests against this table, so a dependency added without a row here is flagged.

None yet. This project currently declares no manifest-based dependencies
(no `package.json`, `requirements.txt`, etc.). The stack is composed of
system-level components and container images, tracked below. Add rows here if
a manifest is ever introduced (for example, a Python helper script with
`requirements.txt`).

## System-Level OTS

Software the project depends on that is **not** declared in a dependency manifest: operating systems, language runtimes, databases, message brokers, container base images, and similar. The checker cannot discover these automatically — keep this section honest by hand.

| Component ID | Name | Version | Supplier / Maintainer | Purpose | Risk | Verification | Anomaly Review | Update Policy | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| OTS-001 | Linux Mint XFCE | 22.3 "Zena", kernel 7.0.0-38-generic | Linux Mint project | Host operating system for the hub | Medium | Observed 2026-10-12: installed on the `MacBook8,1`, boots, Wi-Fi up via in-tree `brcmfmac`, ran this repository's full static test tier. Lid-closed uptime (FR-001) still to be observed. | Distro security advisories; last reviewed 2026-10-12 | Track LTS; manual major-version upgrades | Active |
| OTS-002 | Docker Engine (`docker.io` + `docker-compose-v2`) | 29.1.3 / Compose 2.40.3 (Mint 22 repo candidates as of 2026-10-12) | Docker, Inc. via Ubuntu/Mint packaging | Container runtime hosting all services | Medium | Runs with elevated privileges. Observed 2026-10-12: installed by `scripts/provision_host.sh`, daemon enabled, `docker compose config` passes, `home-assistant` container running and returned unattended after a reboot (FR-003, same day). | Docker security advisories / CVE feed; last reviewed 2026-10-12 | Distro apt repo (not Docker's), manual review before major bumps | Active |
| OTS-003 | ghcr.io/home-assistant/home-assistant | 2026.8.0 | Open Home Foundation | The home-automation platform itself | Medium | Parses device input on the LAN. Observed 2026-10-12: first start answered HTTP 302 on `:8123` within ~10 s of container start; `scripts/smoke_check.sh` PASS. Onboarding (owner account) not yet completed. | HA release notes / breaking-change notices; last reviewed 2026-10-12 | Pinned to a dated tag in `compose/docker-compose.yml`; upgrade deliberately with a config snapshot | Active |
| OTS-004 | eclipse-mosquitto | latest stable | Eclipse Foundation | MQTT broker for device messaging (planned) | Medium | Not yet deployed | Eclipse security advisories | Pin stable tag when adopted | Evaluating |
| OTS-005 | nodered/node-red | latest stable | OpenJS Foundation | Automation flow editor (planned, optional) | Medium | Not yet deployed | Node-RED advisories | Pin stable tag when adopted | Evaluating |
| OTS-006 | openssh-server | 1:9.6p1 (Mint 22 repo candidate as of 2026-10-12) | OpenBSD / Ubuntu packaging | Remote administration of the hub (FR-001-AC-1 is defined in terms of SSH answering) | Medium | Listens on the LAN with distro defaults (password auth enabled). Observed 2026-10-12: installed by `scripts/provision_host.sh`, `ssh.socket` enabled, sshd answering on :22 (local connection reached authentication). Hardening to key-only auth is tracked in `TODO.md`. | Ubuntu security advisories; last reviewed 2026-10-12 | Distro apt repo | Active |

### Risk Note

Every component above is rated `Medium`, and none is `Low`. That is not score
inflation — each one either runs with elevated privileges (Docker), parses
untrusted input arriving from the LAN (Home Assistant, Mosquitto), or is the
trust root the others sit on (the host OS). Per `SECURITY.md`'s "Threat
Modeling Triggers," any of those positions puts a component at `Medium` or
above on its own.

No component is rated `High` today because the hub is not exposed to the public
internet (NFR-005) and holds no third-party data. If either changes —
particularly if Home Assistant becomes reachable from outside the LAN — Home
Assistant and any broker in front of it move to `High`, and this inventory must
be revisited in the same change.

### Verification Caveat

For every `Evaluating` row the Verification column describes how fitness
*will* be established. OTS-001 (host OS), OTS-002 (Docker), OTS-003 (Home
Assistant) and OTS-006 (OpenSSH) are `Active`: each was observed running on
the hub on 2026-10-12 and its stated check ran. Mosquitto and Node-RED remain
`Evaluating` because they have not been adopted. Status moves to `Active` only
once a component is running on the hub and its verification has been observed.
