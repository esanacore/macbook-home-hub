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
| OTS-001 | Linux Mint XFCE | 22.x (leading) / Fedora XFCE fallback | Linux Mint / Fedora projects | Host operating system for the hub | Medium | Runs the whole stack; validated by the machine booting, networking, and staying up with lid closed | Distro security advisories; last reviewed 2026-08-15 | Track LTS; manual major-version upgrades | Evaluating |
| OTS-002 | Docker Engine | latest stable | Docker, Inc. | Container runtime hosting all services | Medium | Runs with elevated privileges; verified by containers coming up and surviving reboot | Docker security advisories / CVE feed; last reviewed 2026-08-15 | Distro or Docker apt repo, manual review before major bumps | Evaluating |
| OTS-003 | ghcr.io/home-assistant/home-assistant | stable (pinned tag once deployed) | Open Home Foundation | The home-automation platform itself | Medium | Parses device input on the LAN; verified via first-boot onboarding and integration smoke test | HA release notes / breaking-change notices; last reviewed 2026-08-15 | Pin to a dated stable tag; upgrade deliberately with a config snapshot | Evaluating |
| OTS-004 | eclipse-mosquitto | latest stable | Eclipse Foundation | MQTT broker for device messaging (planned) | Medium | Not yet deployed | Eclipse security advisories | Pin stable tag when adopted | Evaluating |
| OTS-005 | nodered/node-red | latest stable | OpenJS Foundation | Automation flow editor (planned, optional) | Medium | Not yet deployed | Node-RED advisories | Pin stable tag when adopted | Evaluating |

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

The Verification column above describes how each component's fitness *will* be
established. Nothing has been deployed yet, so no entry is `Active` and none of
the stated verification has actually been performed. Status moves from
`Evaluating` to `Active` only once the component is running on the hub and its
verification has been observed.
