---
id: volume-sliders-release-pr
name: Volume Sliders Release PR
slug: release-pr
category: release
description: Prepare a PR-based release while preserving human merge and tag gates.
---

# Release PR Workflow

Use this workflow only when the user explicitly asks to prepare a release.

1. Act as `@release-manager` and run the `wow-release` skill.
2. Review the current branch, diff, issue links, changelog needs, and validation status.
3. Synchronize required version and changelog files according to `docs/CI_AND_RELEASE.md`.
4. Run required validation for code changes before committing or pushing.
5. Create a PR body in an ignored local markdown file and use `gh pr create --body-file` if using the GitHub CLI.
6. Push the dev branch and open a PR targeting `master`.
7. Wait for CI to pass.
8. Instruct the human user to manually squash and merge the PR on GitHub.
9. Stop until the user confirms the PR has been merged.
10. After user confirmation, pull `master`, verify `HEAD`, and ask explicit permission before creating any release tag.
