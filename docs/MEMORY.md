# Project Memory

This file contains durable memories, codebase learnings, user preferences, and key architectural decisions. AI agents read this file at the start of each session to align with past context, and update it (at the user's discretion) at the end of a session.

> [!IMPORTANT]
> **User Discretion**: Do not add or edit entries in this file without presenting them to the user for review. The user has absolute discretion over what memories are retained.

## User Preferences & Styling Choices

<!--
  Record the user's development preferences, styling decisions, and custom choices.
  Examples:
  - "User prefers TailwindCSS for styling, styled-components for theme overrides."
  - "User prefers HSL values for colors in stylesheets."
  - "Avoid verbose inline comments; document code using JSDoc type definitions."
-->

- Verification claims must distinguish "a check is written" from "a check has
  run." Naming a planned script in a traceability matrix to turn a report green
  is not acceptable — gaps stay gaps until a check actually executes and
  passes. Approved 2026-08-15.

## Codebase Learnings & Gotchas

<!--
  Record critical codebase quirks, system anomalies, test runner behaviors, or API gotchas.
  Examples:
  - "Database port must be forwarded to localhost:5432 during integration tests."
  - "The mock auth service in test environment times out after 30 seconds."
  - "Ensure Git CRLF conversion is disabled when modifying binary images."
-->

- `constitution/` is a git submodule. A plain `git clone` leaves the directory
  present but **empty**, which silently disables every governance script and
  makes the required-reading lists in `CLAUDE.md` and `AGENTS.md` resolve to
  nothing. The repository looks compliant from a file listing while no check
  can actually run. Clone with `--recurse-submodules`, or recover with
  `git submodule update --init --recursive`. This was the actual state of the
  repo until 2026-08-15.
- The constitution secrets sweep is bound to the **pre-push** stage, so plain
  `pre-commit install` is a no-op for it. Both commands are required:
  `pre-commit install && pre-commit install --hook-type pre-push`.
- `check_secrets.sh` respects `.gitignore`. A credential-shaped file that is
  gitignored produces no finding — correct behavior, but it means dropping a
  test file like `id_rsa` into the tree is *not* a valid way to prove the sweep
  works.

## Active Project Decisions

<!--
  Record major technical and architectural decisions approved by the user that govern current work.
  Examples:
  - "Approved using SQLite for local development and PostgreSQL for production."
  - "Adopted the Compliance Validation Triad to gate pull requests."
-->

- Test coverage in this repository is measured as **check completeness**, not
  line percentage. There is no application code, so a coverage percentage would
  be fabricated. Every requirement should have at least one executable
  verifying check; checks that cannot run in the current environment report
  `SKIP` and are never counted as passes. If application code is ever added,
  real line/branch floors replace this. Approved 2026-08-15. See
  `docs/TEST_PLAN.md`.
