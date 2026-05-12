---
id: volume-sliders-release-pr
name: Volume Sliders Release PR
slug: release-pr
category: release
description: Prepare a PR-based release while preserving human merge and tag gates.
---

# Release PR Workflow

Use this workflow when the user asks to prepare a release, or when a normal user-facing bug fix or feature is ready for PR unless the user explicitly says not to ship it yet.

1. Act as `@release-manager` and run the `wow-release` skill.
2. Ensure the work is on a clean `dev/*` branch based on current `origin/master`.
3. Review the current branch, diff, issue links, changelog needs, and validation status.
4. Synchronize required version and changelog files according to `docs/CI_AND_RELEASE.md`.
5. Run required validation for code changes before committing or pushing.
6. Verify `git log origin/master...HEAD` contains only intended commits.
7. Create a PR body in an ignored local markdown file and use `gh pr create --body-file` if using the GitHub CLI.
8. Push the dev branch and open a PR targeting `master`.
9. Wait for CI to pass.
10. Instruct the human user to manually squash and merge the PR on GitHub.
11. Stop until the user confirms the PR has been merged.
12. After user confirmation, fetch/prune, fast-forward local `master`, verify `HEAD` and release metadata, clean up the local dev branch, and ask explicit permission before creating any annotated release tag.
