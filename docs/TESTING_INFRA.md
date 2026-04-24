# Testing Infrastructure

This addon uses a layered testing pipeline:

- `luacheck` for static quality checks.
- `busted` for behavior-focused unit/integration tests in a mocked WoW environment.
- `luacov` in CI for coverage enforcement.

## Local Validation Commands

- `luacheck VolumeSliders spec`
- `busted . --verbose`
- `busted . --verbose --coverage` (requires `luacov`)
- `luacov` (generates `luacov.report.out`)

## CI Gates

The default branch and all pull requests are gated by:

- **Luacheck workflow:** lints both addon code and specs.
- **Busted workflow:** runs tests and enforces a minimum **80% line coverage** threshold using `luacov`.
- **Release workflow:** runs lint + tests before package/release steps.

See `docs/CI_AND_RELEASE.md` for workflow details.

## Test Design Rules

### 1) Behavior over implementation

Tests should validate observable outcomes of production modules, not copied helper logic. Avoid re-implementing internal algorithms inside specs; drive real handlers/functions instead.

### 2) Use regression-style assertions for bugs

When fixing a defect, add a spec that would fail with the old behavior and pass with the new behavior.

### 3) Keep state isolated

Reset `VolumeSlidersMMDB`, session state, and any global hooks in `before_each()` so tests remain deterministic.

## Mock Environment (`spec/setup.lua`)

WoW APIs are mocked in `spec/setup.lua`, which is loaded automatically via `.busted`.

Key mock areas:

- `CreateFrame` and common frame methods
- CVar and voice API shims (`GetCVar`, `SetCVar`, `C_VoiceChat`, etc.)
- `LibStub`, DataBroker stubs, and popup helpers
- Dropdown menu wiring helpers used by settings modules

If new runtime APIs are introduced in production code, add matching mocks before writing assertions.

## Coverage Policy

- CI enforces a minimum of **80% line coverage**.
- Coverage is currently scoped to core logic modules listed in `.luacov` (migration, presets, automation, and related control logic).
- UI-heavy rendering modules are still validated by `luacheck` + behavior tests and can be added to coverage scope incrementally.
- If coverage drops, either improve tests in the same PR or justify/plan follow-up in the PR description.
