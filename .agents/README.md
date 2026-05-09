# Antigravity Configuration

This directory contains the tracked Google Antigravity configuration for Volume Sliders.

- `agents.md` defines project personas.
- `skills/` contains Agent Skills-compatible `SKILL.md` packages.
- `workflows/` contains slash-command workflow definitions.

Generated artifacts belong in `.agents/artifacts/`, which is ignored.

If a local Antigravity build only recognizes the legacy singular `.agent/` directory, create a local ignored compatibility copy or symlink from `.agents/` to `.agent/` on that machine. Do not commit duplicated `.agent/` configuration.
