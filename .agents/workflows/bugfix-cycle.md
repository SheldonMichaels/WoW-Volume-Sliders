---
id: volume-sliders-bugfix-cycle
name: Volume Sliders Bugfix Cycle
slug: bugfix-cycle
category: debugging
description: Diagnose a bug report, apply a targeted fix, and validate the regression.
---

# Bugfix Cycle

Use this workflow when the user reports broken behavior, screenshots, errors, failed tests, or CI failures.

1. Act as `@debugger` and gather the failing behavior, logs, screenshots, current tests, and affected modules.
2. If the fix requires unfamiliar WoW API behavior, act as `@api-researcher` and run `wow-api-discovery`.
3. Apply the smallest targeted source change using `wow-implementation` only when code needs editing.
4. Add or update regression tests that prove the failure is fixed.
5. Act as `@validator` and run `wow-validation`.
6. If validation fails, repeat the debugging and validation loop until clean or blocked.
7. Update comments or docs when the bug reveals a stable contract or non-obvious invariant.
