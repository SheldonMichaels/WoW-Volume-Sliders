# Volume Sliders Agent Guide

Use this guide for Google Antigravity, OpenAI Codex, and Claude Code. Keep tool-specific files short and point them here for shared rules.

## Project Snapshot

- **Addon:** World of Warcraft quick-access volume sliders for **WoW Retail (12.x)** and **WoW Forever (1.x / 16001)**.
- **Language & Layout:** Lua 5.1 and XML UI templates under `VolumeSliders/`. Vendored libraries live in `VolumeSliders/Libs/`.
- **Tests:** Busted specs in `spec/` with mocked WoW APIs in `spec/setup.lua`.
- **Private Local Context:** Keep personal notes, screenshots, and backups in `local_dev_assets/` and transient agent output in `.agents/artifacts/`. Record repository decisions in tracked docs.

## Read On Demand

- [Architecture & module boundaries](docs/ARCHITECTURE.md)
- [Saved-variable schema & migrations](docs/DATA_SCHEMA.md)
- [Preset state stack & automation rules](docs/PRESET_BEHAVIOR.md)
- [Automated test harness & offline limits](docs/TESTING_INFRA.md)
- [Live client checklist](docs/IN_GAME_TESTING.md)
- [CI gates, versioning, and release flow](docs/CI_AND_RELEASE.md)

## Code & Module Rules

- Target **Lua 5.1** syntax only. Never use Lua 5.2+ features.
- Share module state via `local _, VS = ...` and initialize through `PLAYER_LOGIN` in `VolumeSliders/Init.lua`.
- Follow the module boundaries in the architecture guide.
- Never modify `VolumeSliders/Libs/` unless the task explicitly asks for a library update.
- Preserve comments, LDoc, and notes on taint and secure execution. Update stale comments and document new public functions or non-obvious behavior with LDoc.
- Verify unfamiliar WoW API signatures, events, CVars, and taint risks for the target client (Retail and/or Forever) before coding. Use [WoW API discovery](.agents/skills/wow-api-discovery/SKILL.md).
- `.toc` `## Interface:` values must match the targeted WoW build(s), and `embeds.xml` must load LibStub before CallbackHandler and dependent libs.

## Saved Variables (`VolumeSlidersMMDB`)

Any structural schema change requires all of the following in the same PR:

1. Increment `schemaVersion` and update the schema tree and migration contract in `docs/DATA_SCHEMA.md`.
2. Add sequential migration logic in `VolumeSliders/Init.lua` and stamp the final version after migration completes.
3. Add or update migration specs in `spec/`.

Use this migration path for any change to persisted key names, namespaces, or value types.

## Validation

For code, source-comment, or test changes, run from the repository root:

```powershell
luacheck VolumeSliders spec
busted . --verbose
```

Use [WoW validation](.agents/skills/wow-validation/SKILL.md) for a full review. Exercise real module handlers in specs. Report mocked tests and live-client checks separately. For offline work, follow the [maintenance scope](docs/TESTING_INFRA.md#maintenance-without-in-game-testing).

## Git, Windows & Release Gates

- Work on a `dev/*` branch. Start PR work from current `origin/master` unless the maintainer requests a stacked branch. Never commit directly to `master`.
- Assume Windows paths and PowerShell unless the active tool provides another shell.
- Run git commands one at a time and inspect output before the next command.
- Before opening a PR, verify `git log origin/master...HEAD` contains only intended commits.
- For multi-line `gh pr create` or `gh issue comment` bodies, write to a temporary ignored markdown file and pass `--body-file`.
- Keep secrets and ignored local files out of commits.
- **Human merge gate:** Never merge pull requests. Only the human maintainer may merge PRs.
- **Human tag gate:** After the maintainer confirms a squash merge, sync `master` and clean up the merged local branch. Ask explicit permission before creating or pushing an annotated release tag for the exact version.
- Follow `docs/CI_AND_RELEASE.md` when preparing a release PR. Keep `CHANGELOG.md` user-facing and jargon-free.
