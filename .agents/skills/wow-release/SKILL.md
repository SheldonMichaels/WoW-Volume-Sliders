---
name: wow-release
description: Prepares Volume Sliders PR-based releases, version synchronization, changelogs, validation, PR creation, and tag gates. Use only when the user asks for release work.
compatibility: Requires git, GitHub access, gh or GitHub MCP, and repository validation tooling.
---

# WoW Release

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, `docs/CI_AND_RELEASE.md`, and the current diff.
2. Treat normal user-facing bug fixes and features as release preparation unless the user explicitly says not to ship the change yet.
3. Review completed work, linked issues, validation status, and release scope.
4. Draft release notes using `references/Release_Notes_Template.md`.
5. Synchronize required version and changelog files before opening the PR.
6. Run required validation before committing, pushing, or opening a PR when code changed.
7. Confirm the branch starts from `origin/master` and `git log origin/master...HEAD` contains only intended commits.
8. Use an ignored markdown file plus `--body-file` for GitHub CLI PR bodies.
9. Open a PR targeting `master` and wait for CI.
10. Instruct the human user to manually squash and merge on GitHub.
11. Stop until the user confirms the PR was merged.
12. After merge confirmation, fetch/prune, fast-forward local `master`, verify the release version on `master`, and clean up the local dev branch.
13. Ask explicit permission before creating or pushing the annotated release tag for the exact version.
14. Finally, clean up agent scratch files and temporary artifacts in `.agents/artifacts/` created during the completed branch's work. Always verify the contents of a file before deleting it to ensure it is safe to remove (e.g., delete scratch PR bodies or temporary logs, but preserve persistent history, documentation, and screenshots).

## Hard Constraints

- Run git commands one at a time and inspect output.
- Never merge PRs.
- Never force-push to `master`.
- Never create or push a release tag without explicit permission for that exact tag.
