---
name: wow-api-discovery
description: Verifies WoW Retail API signatures, event payloads, CVar behavior, and taint risks before Volume Sliders code changes. Use before implementing unfamiliar addon behavior.
compatibility: Designed for Google Antigravity and compatible agent-skill runners in this repository.
---

# WoW API Discovery

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, and any planning artifact.
2. Identify every API, event, CVar, library function, or secure execution path that must be verified.
3. Use the `wow-api` MCP server tools (`lookup_api`, `search_api`, `get_event`, `get_enum`, `get_namespace`, `get_widget_methods`) for precise, patch-current signature verification when available.
4. Supplement with reputable live documentation when MCP tools are unavailable or insufficient. Always verify information is current and relevant to the targeted WoW Retail version.
5. Cross-reference existing addon code and tests for usage patterns.
6. Record exact signatures, event payloads, return values, deprecation status, and taint/combat-lockdown risks.
7. For non-trivial work, write `.agents/artifacts/API_Research_Artifact.md` using `references/API_Research_Template.md`.
8. Do not write implementation code in this phase.

## Output

Return verified facts, uncertainty, and implementation warnings. Clearly mark anything not verified.
