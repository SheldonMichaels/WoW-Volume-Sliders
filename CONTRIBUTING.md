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

- Use a feature branch for each logical change.
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

## Documentation References

- `docs/ARCHITECTURE.md`
- `docs/TESTING_INFRA.md`
- `docs/CI_AND_RELEASE.md`
- `docs/AGENT_WORKFLOW.md`
