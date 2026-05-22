# Agent Workflow

This document is the tracked, repository-visible operating guide for AI-assisted development on Volume Sliders. `AGENTS.md` is the concise universal baseline; this file is the detailed workflow contract.

## Canonical Guidance

- Treat `AGENTS.md` and committed docs as the source of truth for project behavior.
- Keep Cursor rules and Antigravity skills thin. They should route work and reference canonical docs rather than copying long policies.
- Local-only guidance may exist in ignored files, but any rule that affects repository decisions belongs in tracked docs.
- If an instruction conflicts with a direct user request, ask for clarification before changing behavior-critical files.

## Standard Delivery Pattern

For non-trivial code changes, follow this sequence:

1. **Plan:** Read the relevant modules, docs, and tests. Identify file boundaries and risk.
2. **Discover APIs:** Verify unfamiliar WoW APIs, events, CVar behavior, secure execution constraints, and library behavior before implementation.
3. **Implement:** Make the smallest coherent change that fits existing module ownership.
4. **Validate:** Run focused checks during development and full checks before completion when code changed.
5. **Harden:** Add regression coverage for bug fixes and risky behavior changes.
6. **Document:** Update schema, architecture, testing, release, or user docs when contracts change.

Documentation-only changes may skip Lua test execution unless they alter documented commands, CI behavior, schema rules, or release flow.

## Mandatory Checks

For code changes, run:

```powershell
luacheck VolumeSliders spec
busted . --verbose
```

If CI or workflow files change, review `docs/CI_AND_RELEASE.md` and ensure the docs still describe the actual behavior.

## Phase Contracts

### Planning

- Identify affected modules and whether the change touches Lua, XML, docs, tests, CI, saved variables, or release metadata.
- Create or use a `dev/*` branch for repository modifications.
- For PR-bound work, start from current `origin/master` unless the user explicitly asks to stack on another branch.
- Do not write implementation code before the boundaries are clear.
- For large or risky work, produce an architecture artifact in the ignored `.agents/artifacts/` directory.

### API Discovery

- Verify patch-accurate WoW API signatures before using unfamiliar functions or events.
- Research taint, protected frame, combat-lockdown, CVar, and settings behavior when relevant.
- Use the `wow-api` MCP server tools for signature verification when available. Supplement with reputable live documentation relevant to the current WoW Retail version.
- Capture verified signatures and risks in an ignored research artifact in `.agents/artifacts/` for complex changes.

### Implementation

- Target Lua 5.1 and the existing plain-table addon pattern: `local _, VS = ...`.
- Keep module responsibilities intact:
  - `Core.lua`: shared constants, helpers, localized globals.
  - `SliderWidgets.lua`: widget factory functions for sliders and checkboxes, used by `PopupFrame.lua` and `Settings_*.lua`.
  - `Appearance.lua`: layout, styling, anchoring.
  - `Presets.lua`: preset registration, priority ordering, and state refresh. See `docs/PRESET_BEHAVIOR.md` for the full behavioral contract.
  - `Fishing.lua`, `LFGQueue.lua`: automation domains.
  - `Settings_*.lua`: Blizzard Settings pages by feature area.
  - `PopupFrame.lua`: popup construction and slider instantiation.
  - `MinimapBroker.lua`: LibDataBroker, minimap icon, CVar listener.
  - `Init.lua`: login, migrations, addon compartment setup.
- Preserve comments, LDoc, and taint notes. Update stale comments when touching related logic.
- Do not introduce compatibility shims for unshipped branch-only behavior; replace in-progress designs cleanly.

### Validation

- Use `luacheck VolumeSliders spec` for static checks.
- Use `busted . --verbose` for behavioral tests.
- Add or update specs for bug fixes and stateful behavior changes.
- Use `spec/setup.lua` only to emulate WoW runtime boundaries.
- Do not duplicate production algorithms in tests; assert behavior through real module handlers and state transitions.

### Debugging

- Start from the failing behavior, diagnostic logs, screenshots, stack traces, or validation artifacts.
- Make minimal targeted fixes and loop back through validation.
- For taint or secure execution issues, preserve and add breadcrumbs explaining the constraint.

### Release

- Follow `docs/CI_AND_RELEASE.md` and the tracked Antigravity release workflow.
- Treat normal user-facing bug fixes and features as release PRs for this one-maintainer addon unless the user explicitly says not to ship the change yet.
- Version bumping must keep these files synchronized:
  - `VolumeSliders/VolumeSliders.toc`
  - `CHANGELOG.md`
  - `local_dev_assets/dev_changelog.md` when present and relevant
  - `README.md` only when user-facing feature status changes
- Before opening a PR, verify the branch contains only intended commits with `git log origin/master...HEAD`.
- All merges into `master` must go through a GitHub PR.
- The agent must not merge PRs.
- After the human confirms a squash merge, fetch/prune, fast-forward local `master`, delete the local dev branch, verify the release version on `master`, and ask explicit permission before creating or pushing the annotated release tag for that exact version.
- Once tags are pushed, clean up agent scratch files and temporary artifacts in `.agents/artifacts/` created during the completed branch's work. Always verify the contents of a file before deleting it to ensure it is safe to remove (e.g., delete scratch PR bodies or temporary logs, but preserve persistent history, documentation, and screenshots).

## Saved Variable Rules

Any `VolumeSlidersMMDB` structural change requires:

- migration logic in `VolumeSliders/Init.lua`
- sequential migration behavior for older schema versions
- migration test coverage
- `docs/DATA_SCHEMA.md` schema update
- a migration contract section in `docs/DATA_SCHEMA.md`

Do not change persisted boundaries through implicit defaults alone.

## Documentation Rules

- `CHANGELOG.md` is public and user-facing. Avoid internal filenames and code jargon.
- `docs/` is contributor-facing and should describe stable contracts.
- `local_dev_assets/` is private and ignored. Do not reference its scratch files in public release notes.
- Keep README and CONTRIBUTING links aligned with the current docs.

## Tool-Specific Layers

### Cursor

- Project rules live in `.cursor/rules/`.
- Use `.mdc` frontmatter to scope rules by `alwaysApply`, `description`, or `globs`.
- Keep rules short and point to `AGENTS.md` or this file for details.

### Google Antigravity

- Project personas, skills, and workflows live in `.agents/`.
- Skills should prefer `SKILL.md` directory packages with `name` and `description` metadata.
- Workflows should orchestrate the lifecycle phases and save generated artifacts to the `.agents/artifacts/` directory.

### Local Overrides

- Use ignored local files for machine-specific or private context only.
- Do not let local overrides become the only copy of repository policy.
