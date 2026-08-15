# ADR: Record Architecture Decisions

Status: Accepted

Date: 2026-08-15

## Relationships

- Extends: none
- Supersedes: none
- Related: ADR-0002 (Linux base OS and Home Assistant install method — the first ADR recorded under this decision)

## Context

This project mixes hardware decisions (host OS, install method, battery-as-UPS
strategy), operational decisions (lid-switch handling, backup policy), and
software decisions (companion services, device protocols). Several of these
choices constrain each other — the install method rules out the add-on store,
the fanless hardware rules out heavy desktops, the LAN-only exposure posture
rules out certain broker configs — and the reasoning is hard to recover from
code or commit messages alone. A consistent, discoverable record lets a future
contributor or AI agent see *why* a choice was made before changing it.

## Decision

Use Architecture Decision Records in `docs/adr/`, following the template and
lifecycle defined in `constitution/templates/ADR.md` (Proposed → Accepted →
Superseded or Deprecated, with explicit relationships and promotion criteria).

## Consequences

Major decisions are easier to review, revisit, and explain to future
contributors and AI agents. The constitution's `check_compliance.sh` treats
`docs/adr/` as a recommended doc, so its presence is also a governance signal.
Each ADR is one file, numbered, append-only in spirit — superseding a decision
records the relationship rather than rewriting history.

## Alternatives Considered

- Keep decisions only in issue comments or pull requests. Rejected because
  those records are harder to discover from a fresh clone and have no
  enforced lifecycle, so a superseded choice can sit next to the current one
  with no signal of which is in force.
- A single `docs/DECISIONS.md` roll-up. Rejected because one growing file
  loses the per-decision lifecycle (Proposed/Accepted/Superseded) that the
  ADR template enforces.
