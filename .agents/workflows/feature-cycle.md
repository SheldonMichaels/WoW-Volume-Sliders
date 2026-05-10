---
id: volume-sliders-feature-cycle
name: Volume Sliders Feature Cycle
slug: feature-cycle
category: development
description: Plan, research, implement, validate, and document a non-trivial feature.
---

# Feature Cycle

Use this workflow when the user asks for a new feature or substantial enhancement.

1. Act as `@planner` and run the `wow-planning` skill.
   - Save complex output to `.agents/artifacts/Architecture_Design_Artifact.md`.
   - Pause for user approval when the design has meaningful trade-offs.
2. Act as `@api-researcher` and run the `wow-api-discovery` skill for any unfamiliar WoW APIs, events, CVars, secure execution paths, or library behavior.
   - Save output to `.agents/artifacts/API_Research_Artifact.md`.
3. Act as `@implementer` and run the `wow-implementation` skill.
   - Save output to `.agents/artifacts/Implementation_Handoff_Artifact.md`.
4. Act as `@validator` and run the `wow-validation` skill.
   - Save output to `.agents/artifacts/Validation_Report_Artifact.md`.
5. If validation fails, act as `@debugger`, fix only the failing behavior, and repeat validation.
6. Update relevant tracked docs before completion.
