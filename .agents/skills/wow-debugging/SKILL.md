---
name: wow-debugging
description: Diagnoses and fixes Volume Sliders bugs, validation failures, CI failures, UI taint, and event-ordering issues with minimal targeted changes.
compatibility: Designed for Google Antigravity and compatible agent-skill runners in this repository.
---

# WoW Debugging

## Instructions

1. Read the user report, failing logs, screenshots, tests, implementation handoff, and validation report when available.
2. Reproduce or localize the failure from evidence before editing.
3. Identify the smallest affected function, event handler, XML template, or docs contract.
4. Verify unfamiliar WoW API behavior through `wow-api-discovery`.
5. Apply a targeted fix. Avoid broad rewrites.
6. Add regression tests when the bug is testable in the Busted harness.
7. Loop back to `wow-validation`.

## Focus Areas

- UI taint and combat-lockdown behavior
- event ordering and stale state
- saved variable migrations
- mocked WoW runtime boundaries
- CI command drift
