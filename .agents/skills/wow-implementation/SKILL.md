---
name: wow-implementation
description: Implements approved Volume Sliders Lua 5.1, XML, docs, and tests from planning and API research artifacts. Use when source or repository files need editing.
compatibility: Designed for Google Antigravity and compatible agent-skill runners in this repository.
---

# WoW Implementation

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, and any available planning or API research artifacts.
2. Confirm the affected module boundaries before editing.
3. Implement the smallest coherent change using Lua 5.1-compatible code.
4. Preserve comments, LDoc, taint notes, and security breadcrumbs. Update stale comments when related logic changes.
5. Update tests and docs when behavior, schema, commands, or user-facing contracts change.
6. For non-trivial code changes, write `.agents/artifacts/Implementation_Handoff_Artifact.md` using `references/Implementation_Handoff_Template.md`.
7. Hand off to `wow-validation` before completion.

## Constraints

- Do not guess unfamiliar WoW APIs; return to `wow-api-discovery`.
- Do not change `VolumeSlidersMMDB` structure without the full schema migration contract.
- Do not refactor unrelated modules.
