---
name: wow-validation
description: Runs Volume Sliders linting, Busted tests, migration checks, and documentation verification. Use after code changes or before PR handoff.
compatibility: Requires Lua 5.1 tooling, luacheck, busted, and repository test dependencies.
---

# WoW Validation

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, and the current diff.
2. Classify the change as code, docs-only, schema, CI, release metadata, or mixed.
3. For code changes, run:
   ```powershell
   luacheck VolumeSliders spec
   busted . --verbose
   ```
4. For saved variable changes, confirm migration logic, migration tests, and `docs/DATA_SCHEMA.md` updates.
5. For docs-only changes, verify links, commands, and described behavior.
6. For CI/release changes, verify `docs/CI_AND_RELEASE.md` and relevant workflow files.
7. Save `.agents/artifacts/Validation_Report_Artifact.md` for Antigravity workflow runs.

## Failure Handling

- Fix straightforward failures when the cause is clear.
- If failures reveal a design flaw, hand off to `wow-debugging`.
- Do not report validation as complete until failures are fixed or explicitly documented as blockers.
