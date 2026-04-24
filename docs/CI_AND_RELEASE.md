# CI and Release Pipeline

This repository uses three GitHub Actions workflows.

## 1) Luacheck (`.github/workflows/luacheck.yml`)

- Triggered on pushes to `master` and `dev/*`
- Triggered on all pull requests
- Runs:
  - `luacheck VolumeSliders spec`

## 2) Busted + Coverage (`.github/workflows/busted.yml`)

- Triggered on pushes to `master` and `dev/*`
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

## Local Equivalents

Run these before opening a PR:

- `luacheck VolumeSliders spec`
- `busted . --verbose`
