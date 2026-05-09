---
name: wow-docs-overhaul
description: Updates Volume Sliders AI assistant documentation, Cursor rules, Antigravity workflows, and agent context structure. Use when changing AGENTS.md, .cursor/rules, .agents, or docs/AGENT_WORKFLOW.md.
compatibility: Designed for documentation and agent-infrastructure work in this repository.
---

# WoW Docs Overhaul

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, and relevant repository docs.
2. Keep one canonical copy of each policy:
   - universal rules in `AGENTS.md`
   - detailed operating guide in `docs/AGENT_WORKFLOW.md`
   - Cursor routing in `.cursor/rules/`
   - Antigravity personas, skills, and workflows in `.agents/`
3. Avoid duplicating long policy blocks across tool-specific files.
4. Keep generated artifacts and local machine overrides ignored.
5. Update `README.md`, `CONTRIBUTING.md`, and `.gitignore` when structure changes.
6. Verify no private local files are accidentally exposed in the diff.

## Output

Return a concise summary of structure changes and any manual verification still needed in Cursor or Antigravity.
