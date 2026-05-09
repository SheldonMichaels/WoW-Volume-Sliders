---
name: wow-api-discovery
description: Verifies WoW Retail API signatures, event payloads, CVar behavior, and taint risks before Volume Sliders code changes. Use before implementing unfamiliar addon behavior.
compatibility: Designed for Google Antigravity and compatible agent-skill runners in this repository.
---

# WoW API Discovery

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, and any planning artifact.
2. Identify every API, event, CVar, library function, or secure execution path that must be verified.
3. Prefer local references first:
   - `local_dev_assets/knowledge/` if available
   - `../wow-ui-source`
   - existing code and tests
4. Use live documentation or API search when local references are insufficient.
5. Record exact signatures, event payloads, return values, deprecation status, and taint/combat-lockdown risks.
6. For non-trivial work, write `.agents/artifacts/API_Research_Artifact.md` using `references/API_Research_Template.md`.
7. Do not write implementation code in this phase.

## Output

Return verified facts, uncertainty, and implementation warnings. Clearly mark anything not verified.
