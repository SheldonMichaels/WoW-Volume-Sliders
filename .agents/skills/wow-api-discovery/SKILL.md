---
name: wow-api-discovery
description: Verifies WoW Retail (12.x) and WoW Forever (16001) API signatures, event payloads, CVar behavior, and taint risks before Volume Sliders code changes.
---

# WoW API Discovery

## Instructions

1. Identify the target WoW client(s) and build/interface version (`VolumeSliders/VolumeSliders.toc` declares both Retail 12.x and Forever 16001).
2. List every API function, event, enum, CVar, widget method, library call, or secure execution path that needs verification.
3. If a `wow-api` MCP server is available in the active session, use its lookup tools first. Verify findings against client-specific documentation or UI source for the target build. Use those sources directly when the server is unavailable.
4. Cross-reference existing usage in `VolumeSliders/` and mocks in `spec/setup.lua`.
5. Report exact signatures, event payloads, return values, client-specific differences (Retail vs. Forever), deprecation status, and taint or combat-lockdown risks.
6. Clearly mark anything that could not be verified. Do not edit source code during this research step.
