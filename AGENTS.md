# Volume Sliders Agent Guide

This is the universal, tracked instruction file for AI coding agents working on Volume Sliders. Tool-specific rules and workflows must extend this file instead of duplicating it.

## Project Snapshot

- **Project:** World of Warcraft Retail addon for quick-access volume controls.
- **Runtime:** WoW Retail 12.x, Lua 5.1, XML UI templates.
- **Addon root:** `VolumeSliders/`
- **Tests:** Busted specs in `spec/`
- **Public docs:** `README.md`, `CONTRIBUTING.md`, `docs/`
- **Private local context:** `local_dev_assets/` is git-ignored and may contain screenshots, backups, dev changelogs, and research notes.

## Source of Truth

- Treat this file and committed docs as the project contract.
- Use `docs/AGENT_WORKFLOW.md` for the full AI-assisted development lifecycle.
- Use `docs/DATA_SCHEMA.md` before changing `VolumeSlidersMMDB`.
- Use `docs/TESTING_INFRA.md` before changing tests, mocks, or validation commands.
- Use `docs/CI_AND_RELEASE.md` before changing CI, packaging, versioning, or release flow.
- Use `docs/PRESET_BEHAVIOR.md` before changing preset evaluation, automation triggers, baseline/mute state, or manual toggle behavior.
- Local-only files may provide extra context, but repository decisions must be reflected in tracked docs.

## Repository Map

```text
WoW-Volume-Sliders/
|-- AGENTS.md                  # universal tracked agent baseline
|-- .agents/                   # tracked Antigravity personas, skills, workflows
|   `-- artifacts/             # ignored agent execution artifacts (plans, logs, reports)
|-- .cursor/rules/             # tracked Cursor project rules
|-- .github/workflows/         # CI/CD
|-- docs/                      # architecture, schema, testing, release, AI docs
|-- local_dev_assets/          # ignored private notes and scratch files
|-- spec/                      # Busted unit tests
`-- VolumeSliders/             # packaged addon source
```

The release package is built from `VolumeSliders/`; docs and AI configuration are repository support files and are not shipped as addon code.

## Development Rules

- Work on a `dev/*` branch for repository modifications. Do not commit directly to `master`.
- For PR-bound work, start from current `origin/master` unless the user explicitly asks for a stacked branch.
- Keep changes scoped to the user's request and the established module boundaries.
- Preserve existing comments, LDoc, taint notes, and security breadcrumbs unless they are stale. Update misleading comments when touching related logic.
- New Lua functions must use LDoc comments when they introduce non-obvious behavior or public module surface.
- Do not modify `VolumeSliders/Libs/` unless the task is explicitly about library updates.
- Do not commit secrets, screenshots, database backups, scratch PR bodies, or other ignored local files.

## WoW Addon Boundaries

- Use Lua 5.1 syntax only. Do not use Lua 5.2+ features.
- Share module state through the addon table pattern: `local _, VS = ...`.
- Initialization happens through the `PLAYER_LOGIN` flow in `VolumeSliders/Init.lua`.
- Keep UI construction, styling, persistence, presets, automation, and minimap behavior in their existing modules unless the requested change requires a new boundary.
- Verify WoW API signatures before relying on unfamiliar functions, events, secure execution behavior, or CVar semantics.

## Saved Variable Contract

`VolumeSlidersMMDB` is user-owned persisted state. Any structural schema change requires all of the following in the same change set:

1. Increment the root `schemaVersion` documented in `docs/DATA_SCHEMA.md`.
2. Update the schema tree in `docs/DATA_SCHEMA.md`.
3. Add a migration contract section to `docs/DATA_SCHEMA.md`.
4. Implement sequential migration logic in `VolumeSliders/Init.lua`.
5. Stamp the final schema version after migration completes.
6. Add or update migration test coverage.

Never change persisted key names, namespaces, or value types without this migration path.

## Validation

For code changes, run and pass:

```powershell
luacheck VolumeSliders spec
busted . --verbose
```

Documentation-only changes do not require the Lua test suite unless they alter documented commands, CI behavior, schema contracts, or release behavior. Still review diffs carefully.

## Agent Workflow Layers

- **Cursor:** `.cursor/rules/*.mdc` contains short, scoped project rules. Cursor rules should point back to this file or committed docs instead of copying large sections.
- **Antigravity:** `.agents/agents.md`, `.agents/skills/`, and `.agents/workflows/` define project personas and lifecycle commands.
  - Workflows use named personas (`@planner`, `@api-researcher`, `@implementer`, `@validator`, `@debugger`, `@release-manager`) defined in `.agents/agents.md`.
- **Artifacts:** Generated planning, research, implementation, validation, or release artifacts belong in the ignored `.agents/artifacts/` directory unless the user explicitly asks to commit them.

## Windows and GitHub CLI

- Assume Windows paths and PowerShell unless a tool explicitly provides another shell.
- Run git commands one at a time and inspect their output before the next git action.
- Before opening a PR, verify `git log origin/master...HEAD` contains only intended commits.
- For `gh pr create`, `gh issue comment`, or other long GitHub CLI bodies, write the body to an ignored markdown file first and use `--body-file`.
- Do not merge pull requests. Only the human user may merge PRs.
- After the human confirms a squash merge, sync local `master`, clean up the local dev branch, and ask explicit permission before creating or pushing the annotated release tag for the exact version.

## Documentation Style

- `CHANGELOG.md`: user-facing, non-technical release notes.
- `local_dev_assets/dev_changelog.md`: private technical history, if present and relevant.
- Pull request descriptions: bridge technical summary and public changelog.
- `README.md` and `CONTRIBUTING.md`: human onboarding, not exhaustive agent instructions.

## Common Pitfalls

- `.toc` `## Interface:` must match the targeted WoW build.
- `embeds.xml` must load LibStub first, then CallbackHandler, then dependent libraries.
- Preserve secure execution and taint-related notes.
- Prefer real module behavior in specs; do not duplicate production algorithms inside tests.
