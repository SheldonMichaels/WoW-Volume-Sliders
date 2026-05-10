---
name: wow-planning
description: Plans Volume Sliders feature work before implementation. Use for non-trivial addon changes, architecture decisions, module boundary mapping, or when a request has trade-offs.
compatibility: Designed for Google Antigravity and compatible agent-skill runners in this repository.
---

# WoW Planning

## Instructions

1. Read `AGENTS.md`, `docs/AGENT_WORKFLOW.md`, and the modules or docs relevant to the request.
2. Identify whether the work touches Lua, XML, tests, docs, saved variables, CI, or release metadata.
3. Map affected files to existing module responsibilities. Prefer existing boundaries over new modules.
4. Identify required WoW API, event, CVar, library, or taint research.
5. For non-trivial work, write `.agents/artifacts/Architecture_Design_Artifact.md` using `references/Architecture_Design_Template.md`.
6. Do not write source code in this phase.

## Output

Return a concise plan with:

- objective
- affected files
- required research
- validation plan
- open questions or approval gates
