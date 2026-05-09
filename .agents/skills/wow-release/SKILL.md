---
name: wow-release
description: Prepares Volume Sliders PR-based releases, version synchronization, changelogs, validation, PR creation, and tag gates. Use only when the user asks for release work.
compatibility: Requires git, GitHub access, gh or GitHub MCP, and repository validation tooling.
---

# WoW Release

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, `docs/CI_AND_RELEASE.md`, and the current diff.
2. Confirm the user explicitly asked for release preparation.
3. Review completed work, linked issues, validation status, and release scope.
4. Draft release notes using `references/Release_Notes_Template.md`.
5. Synchronize required version and changelog files.
6. Run required validation before committing, pushing, or opening a PR when code changed.
7. Use an ignored markdown file plus `--body-file` for GitHub CLI PR bodies.
8. Open a PR targeting `master` and wait for CI.
9. Instruct the human user to manually squash and merge on GitHub.
10. Stop until the user confirms the PR was merged.
11. Ask explicit permission before creating or pushing any release tag.

## Hard Constraints

- Run git commands one at a time and inspect output.
- Never merge PRs.
- Never force-push to `master`.
- Never create or push a release tag without explicit permission for that exact tag.
