# Agent Workflow

This document defines the tracked, repository-visible workflow for AI-assisted development.

## Canonical Guidance

- Treat this file and committed docs as the source of truth for agent behavior.
- Local machine-only guidance files may exist, but repository decisions must be reflected in tracked docs.

## Required Delivery Pattern

For non-trivial changes, follow this sequence:

1. **Read context**: relevant module(s), docs, and current tests
2. **Implement**: smallest coherent code change
3. **Validate**: run lint/tests locally where possible
4. **Harden**: add regression tests for bug fixes
5. **Document**: update architecture/schema/testing docs when contracts change

## Mandatory Checks Before Completion

- `luacheck VolumeSliders spec`
- `busted . --verbose`
- If CI/workflow changes are touched, ensure docs match new behavior

## Saved Variable Rules

Any schema boundary change requires:

- migration updates in `Init.lua`
- migration test coverage
- `docs/DATA_SCHEMA.md` update

## Test Integrity Rules

- Do not duplicate production algorithms inside specs.
- Prefer assertions against real module handlers and state transitions.
- Use `spec/setup.lua` mocks only to emulate WoW runtime boundaries.

## Comment and Docs Rules

- Refresh stale comments when touching related logic.
- Add comments only for non-obvious invariants or edge-case intent.
- Keep user-facing and contributor-facing docs synchronized with behavior.
