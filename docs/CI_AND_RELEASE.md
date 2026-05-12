# CI and Release Pipeline

This repository uses three GitHub Actions workflows.

## 1) Luacheck (`.github/workflows/luacheck.yml`)

- Triggered on pushes to `master`
- Triggered on all pull requests
- Runs:
  - `luacheck VolumeSliders spec`

## 2) Busted + Coverage (`.github/workflows/busted.yml`)

- Triggered on pushes to `master`
- Triggered on all pull requests
- Runs:
  - `busted . --verbose --coverage`
  - `luacov`
  - coverage parser gate (minimum **80%** line coverage)

Coverage config is defined in `.luacov`.
The initial 80% gate is applied to the core module scope declared there.

## 3) Package and Release (`.github/workflows/release.yml`)

- Triggered on tags matching `v*` and manual dispatch
- Uses a two-job flow:
  1. `validate` (lint + tests)
  2. `release` (packager publish), which depends on `validate`

Release packaging uses `BigWigsMods/packager@v2`.

## Changelog Extraction Behavior

The release workflow trims `CHANGELOG.md` down to the latest `## v...` section before packaging so release notes contain only the newest version entry.

## Release Policy

Volume Sliders is a small one-maintainer addon. In normal maintenance, every user-facing bug fix or feature PR is also a release PR unless the user explicitly says it should not ship yet.

Before opening a release PR:

1. Start from a clean `dev/*` branch based on current `origin/master`.
2. Apply the code, docs, and test changes.
3. Choose the next semantic version for the scope:
   - Patch (`x.y.Z`) for bug fixes and small documentation/release workflow corrections.
   - Minor (`x.Y.0`) for user-facing features or notable behavior changes.
   - Major (`X.0.0`) only for breaking saved-variable or compatibility changes.
4. Synchronize release metadata:
   - `VolumeSliders/VolumeSliders.toc` `## Version:`
   - `CHANGELOG.md` title and newest release section
   - `local_dev_assets/dev_changelog.md` when present and relevant
   - `README.md` only when user-facing feature status or install guidance changes
5. Run local validation:
   - `luacheck VolumeSliders spec`
   - `busted . --verbose`
6. Verify the PR will contain only intended commits with `git log origin/master...HEAD`.
7. Open a PR targeting `master` and include the validation results, manual in-game testing when applicable, and linked issue closure text.

The human maintainer performs the squash merge on GitHub.

After the maintainer confirms the merge:

1. Run `git fetch origin --prune`.
2. Switch to `master` and run `git pull --ff-only`.
3. Verify `HEAD`, `CHANGELOG.md`, and `VolumeSliders/VolumeSliders.toc` match the intended release version.
4. Delete the merged local `dev/*` branch. Squash merges usually require `git branch -D` because the exact branch commit is not an ancestor of `master`.
5. Ask explicit permission before creating and pushing the annotated release tag for the exact version, for example `v3.9.1`.

## Local Equivalents

Run these before opening a PR:

- `luacheck VolumeSliders spec`
- `busted . --verbose`
