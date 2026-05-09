---
id: volume-sliders-validate
name: Volume Sliders Validation
slug: validate
category: quality
description: Run the repository validation checklist and summarize results.
---

# Validation Workflow

Use this workflow before handing code changes back to the user or before preparing a PR.

1. Act as `@validator`.
2. Review the current diff and identify whether changes are code, docs-only, CI, schema, or release metadata.
3. For code changes, run:
   ```powershell
   luacheck VolumeSliders spec
   busted . --verbose
   ```
4. For schema changes, verify migration coverage and `docs/DATA_SCHEMA.md`.
5. For CI or release changes, verify `docs/CI_AND_RELEASE.md`.
6. Save a concise report to `.agents/artifacts/Validation_Report_Artifact.md` during Antigravity workflow runs.
7. Do not mark validation complete until failures are fixed or clearly reported as blockers.
