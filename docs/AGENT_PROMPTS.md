# Agent Prompts

This document provides copyable prompts to help humans interact effectively
with AI agents in this repository. Each prompt is scoped to a real task this
project actually has, not a generic placeholder.

## Provision the hub

```text
Image the MacBook8,1 following docs/SETUP.md Part 2. After each step, paste
back the actual commands you typed and their output. When provisioning is
done, replace the "unverified" section of docs/SETUP.md with the captured
commands and update docs/TROUBLESHOOTING.md (anticipated) entries with
observed symptoms. Mark TODO.md Provisioning items complete as you go.
```

## Run the hub smoke check

```text
Run HUB_HOST=<hub-ip> bash scripts/smoke_check.sh against the running hub.
If any check fails, open docs/TROUBLESHOOTING.md and propose a fix rooted in
the specific symptom (not a generic restart). Do not mark FR-002 or NFR-002
Verified in docs/REQUIREMENTS_TRACEABILITY.md unless the smoke check actually
passed — a check that has never executed has proven nothing.
```

## Perform a restore drill

```text
Perform a real restore of the Home Assistant config volume onto a clean
target per FR-007. Record the steps in docs/OPERATIONS.md, mark GAP-005 in
docs/TEST_PLAN.md as closed only after the restored target serves :8123, and
add a TODO.md item to repeat the drill at a regular cadence.
```

## Draft an ADR

```text
Draft an ADR for [decision] using constitution/templates/ADR.md. Status
Proposed, with concrete promotion criteria. When ratified, set Status to
Accepted and remove the Promotion Criteria section. Reference any related
ADRs under Relationships. Do not edit existing ADRs to reflect a new
decision — supersede them with a new numbered ADR instead.
```

## Review a config change against the constitution

```text
Review my staged changes against Eric's Engineering Constitution. Confirm
Principle 2 (tests added or updated), Principle 5 (security impact considered,
no secrets, no new public exposure), and Principle 9 (operational impact
documented). Run bash scripts/run_tests.sh and report any non-SKIP failures.
Update TODO.md, CHANGELOG.md, and docs/OTS_SOFTWARE.md if dependencies
changed, in the same change.
```

## Bring the stack up

```text
Run docker compose -f compose/docker-compose.yml up -d and confirm the
home-assistant container is in running state. Verify the image tag is a
dated pin (never latest) per FR-004-AC-2, restart policy is unless-stopped
per FR-003-AC-2, and the config volume is a bind mount per FR-004-AC-3.
Update docs/REQUIREMENTS_TRACEABILITY.md only after the smoke check passes.
```
