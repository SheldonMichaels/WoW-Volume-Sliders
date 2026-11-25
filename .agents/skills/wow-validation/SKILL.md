---
name: wow-validation
description: Runs Volume Sliders linting, Busted tests, schema migration checks, and documentation verification. Supports both read-only review and fix-and-recheck workflows.
---

# WoW Validation

## Instructions

1. Determine scope from the user request: if asked for a read-only check or review, preserve the working tree and report findings only.
2. Inspect the current diff and classify changes as code, tests, schema, CI/release, docs-only, or mixed.
3. For code, source-comment, or test changes, check tool availability and run from the repository root:
   ```powershell
   luacheck VolumeSliders spec
   busted . --verbose
   ```
   Report any missing tools and which checks could run.
4. For `VolumeSlidersMMDB` changes, confirm sequential migration logic in `VolumeSliders/Init.lua`, migration specs in `spec/`, and updated schema/migration contracts in `docs/DATA_SCHEMA.md`.
5. For docs-only changes, verify relative links, documented commands, and alignment with actual files.
6. For CI or release changes, verify consistency with `docs/CI_AND_RELEASE.md` and `.github/workflows/`.
7. Report automated results and live-client testing separately. Mark in-game checks as **not performed** unless actually run, and reference `docs/IN_GAME_TESTING.md` for follow-up.

## Failure Handling

- In read-only mode, list failures, root causes, and recommended fixes without editing files.
- When authorized to fix failures, apply minimal targeted fixes, add regression specs where testable, and re-run `luacheck` and `busted` before reporting completion.
