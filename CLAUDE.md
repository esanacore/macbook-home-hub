# CLAUDE.md

This repository follows Eric's Engineering Constitution.

## Required Reading

Before making changes, read:

- `constitution/CONSTITUTION.md`
- `constitution/AI_WORKFLOW.md`
- `constitution/TESTING.md`
- `constitution/DOCUMENTATION.md`
- `constitution/SECURITY.md`
- `constitution/CODE_STYLE.md`
- `README.md`
- `TODO.md`
- `CHANGELOG.md`
- `docs/MEMORY.md`

## gstack (Optional — delete this section if unused)

This section applies only if this project has adopted
[gstack](https://github.com/garrytan/gstack) for AI-assisted workflows.
gstack is a third-party skill suite, not a constitution requirement — if
this project doesn't use it, delete this entire section (through "Available
gstack skills" below).

If this project *does* use gstack, verify it's installed before relying on
any skill below:

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If `GSTACK_MISSING`, the one-shot fix is `bash constitution/scripts/setup-machine.sh`
(installs Bun, gstack, goose, and goosetown together, idempotently, run
once per machine — see `constitution/INTEGRATION.md` "Provisioning a
Machine in One Step"). Or install gstack alone (requires [Bun](https://bun.sh)
v1.0+ — install with `curl -fsSL https://bun.sh/install | bash` first if
`bun --version` fails):

```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup
```

On a Linux distro Playwright doesn't officially recognize yet (its browser
install fails with `Playwright does not support chromium on <distro>-x64`),
`/browse` and other browser-driving skills need one more step — a same-family
fallback build still works:

```bash
cd ~/.claude/skills/gstack/browse
PLAYWRIGHT_HOST_PLATFORM_OVERRIDE=ubuntu24.04-x64 bunx playwright install chromium chromium-headless-shell
```

(Swap `ubuntu24.04-x64` for the newest Ubuntu Playwright's installer actually
lists as supported at the time — check the error message it prints.)

- Use the `/browse` skill from gstack for **all** web browsing.
- **Never** use `mcp__claude-in-chrome__*` tools.
- Run `/setup-gbrain` once in this repository to initialize the project brain.

Available gstack skills:

- `/office-hours`
- `/plan-ceo-review`
- `/plan-eng-review`
- `/plan-design-review`
- `/design-consultation`
- `/design-shotgun`
- `/design-html`
- `/review`
- `/ship`
- `/land-and-deploy`
- `/canary`
- `/benchmark`
- `/browse`
- `/connect-chrome`
- `/qa`
- `/qa-only`
- `/design-review`
- `/setup-browser-cookies`
- `/setup-deploy`
- `/setup-gbrain`
- `/retro`
- `/investigate`
- `/document-release`
- `/document-generate`
- `/codex`
- `/cso`
- `/autoplan`
- `/plan-devex-review`
- `/devex-review`
- `/careful`
- `/freeze`
- `/guard`
- `/unfreeze`
- `/gstack-upgrade`
- `/learn`

## Completion Checklist

Before completing work:

- Confirm the requested change is implemented.
- Add or update relevant tests.
- Evaluate coverage against targets and record any gaps.
- Update requirements traceability for product-facing repositories.
- Update the OTS software inventory (`docs/OTS_SOFTWARE.md`) when third-party dependencies changed.
- Update documentation when needed.
- Update TODO.md with discovered or completed work.
- Update CHANGELOG.md for user-facing changes.
- Consider security impact.
- Propose new codebase learnings, user preferences, or major decisions to the user and (upon approval) record them in `docs/MEMORY.md`.
- Identify useful follow-up work.
- Clear or archive `docs/SESSION_PLAN.md`.
- Summarize changes and verification.

## GBrain Configuration (configured by /setup-gbrain)

- Mode: local-stdio
- Engine: postgres (Supabase session pooler, project `yvamohixcwjchhxufrcm`, region us-west-1)
- Config file: ~/.gbrain/config.json (mode 0600)
- Setup date: 2026-08-15
- MCP registered: yes (user scope; `claude mcp list` shows gbrain ✔ Connected)
- Artifacts sync: off
- Current repo policy: read-write (github.com/esanacore/macbook-home-hub)

The Supabase database password and the pooler URL live only in
`~/.gbrain/config.json` (mode 0600) — they are never committed to this repo.
If this block's claims drift from the actual machine state (e.g. after a
cross-machine clone), `scripts/check_gbrain_state.sh` reports the drift and
re-running `/setup-gbrain` rewrites the block in place via its HTML-comment
delimiters.

## GBrain Search Guidance (configured by /sync-gbrain)
<!-- gstack-gbrain-search-guidance:start -->

GBrain is set up and synced on this machine. The agent should prefer gbrain
over Grep when the question is semantic or when you don't know the exact
identifier yet. Two indexed corpora available via the `gbrain` CLI:
- This repo's code (registered as `gstack-code-<repo>` source).
- `~/.gstack/` curated memory (registered as `gstack-brain-<user>` source via
  the existing federation pipeline).

Prefer gbrain when:
- "Where is X handled?" / semantic intent, no exact string yet:
    `gbrain search "<terms>"` or `gbrain query "<question>"`
- "Where is symbol Y defined?" / symbol-based code questions:
    `gbrain code-def <symbol>` or `gbrain code-refs <symbol>`
- "What calls Y?" / "What does Y depend on?":
    `gbrain code-callers <symbol>` / `gbrain code-callees <symbol>`
- "What did we decide last time?" / past plans, retros, learnings:
    `gbrain search "<terms>" --source gstack-brain-<user>`

Grep is still right for known exact strings, regex, multiline patterns, and
file globs. The brain auto-syncs incrementally on every gstack skill start.
Run `/sync-gbrain` to force-refresh, `/sync-gbrain --full` for full reindex.

<!-- gstack-gbrain-search-guidance:end -->
