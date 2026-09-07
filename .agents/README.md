# Shared Agent Skills and Antigravity Workflows

This directory contains shared project skills and the existing Google Antigravity workflow documents for Volume Sliders. Start with `../AGENTS.md`; see `../docs/CODEX_GUIDE.md` for Codex and `../docs/ANTIGRAVITY_GUIDE.md` for Antigravity/Gemini.

- `agents.md` defines written project personas, not native subagent registrations.
- `skills/` contains Agent Skills-compatible `SKILL.md` packages.
- `workflows/` contains workflow definitions that can also be read and followed as ordinary Markdown procedures.

Generated artifacts belong in `.agents/artifacts/`, which is ignored.

Confirm discovery in the installed Antigravity version. If it only recognizes singular `.agent/`, use a local ignored compatibility link or copy pointing to this tracked content; refresh copies after changes. Do not commit duplicated `.agent/` configuration. Explicitly asking the assistant to read the workflow file is a fallback when commands are not discovered.

For work without in-game testing, follow `../docs/OFFLINE_MAINTENANCE.md`. Tool discovery and successful mocks do not establish live WoW compatibility.
