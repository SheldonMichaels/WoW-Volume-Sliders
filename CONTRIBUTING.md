# Contributing

Thanks for helping improve Volume Sliders.

## Development Setup

1. Install Lua 5.1 and Luarocks.
2. Install tooling:
   - `luarocks install busted`
   - `luarocks install luacheck`
   - `luarocks install luacov` (for coverage runs)
3. Run local validation:
   - `luacheck VolumeSliders spec`
   - `busted . --verbose`

## Branch and PR Workflow

- Use a `dev/*` branch based on current `origin/master` for each logical change.
- Keep PRs focused and reviewable (one theme per PR).
- Include regression tests for any bug fix.
- Update relevant docs in the same PR when contracts change.

## Required Quality Checks

Every PR should pass:

- `luacheck` on `VolumeSliders` and `spec`
- full `busted` test suite
- CI coverage gate (80% line coverage)

## Migration and Schema Changes

If you change saved variable structure:

1. Add/adjust migration logic in `VolumeSliders/Init.lua`.
2. Add tests covering old and new schema paths.
3. Update `docs/DATA_SCHEMA.md`.
4. Call out migration impact in the PR description.

## Testing Guidance

- Prefer behavior tests against real module handlers.
- Do not copy production logic into test files.
- Extend `spec/setup.lua` when new WoW APIs are used.
- Tests use mocked WoW APIs; passing them does not establish in-game compatibility. See [testing limits](docs/TESTING_INFRA.md) and the [in-game checklist](docs/IN_GAME_TESTING.md).
- When in-game testing is unavailable, use the [offline maintenance scope](docs/OFFLINE_MAINTENANCE.md).

## Editor Setup

Run validation commands from the repository root with Lua 5.1 tooling available on `PATH`. The checked-in `.luarc.json` files reference a maintainer-specific WoW annotation directory; that directory is not a dependency of Busted or Luacheck. Configure annotation locations in your local editor settings when using another machine. Keep local paths and credentials out of shared assistant configuration.

## Documentation References

- `docs/ARCHITECTURE.md`
- `docs/DATA_SCHEMA.md`
- `docs/PRESET_BEHAVIOR.md`
- `docs/TESTING_INFRA.md`
- `docs/CI_AND_RELEASE.md`

## AI-Assisted Development

- `AGENTS.md` is the tracked baseline for AI coding agents.
- `docs/AGENT_WORKFLOW.md` is the detailed operating guide.
- `.cursor/rules/` contains scoped Cursor project rules.
- `.agents/skills/` contains shared project skills; `.agents/agents.md` and `.agents/workflows/` describe Antigravity roles and processes.
- [Codex Guide](docs/CODEX_GUIDE.md) covers Codex discovery and moving between assistants.
- `docs/ANTIGRAVITY_GUIDE.md` explains how to operate Google Antigravity with this project.
- Generated artifacts and local-only overrides must stay ignored.
