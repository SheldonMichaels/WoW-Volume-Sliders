# Testing Infrastructure (Busted & LuaLS)

This project uses `lua-language-server` for strict static typing and `busted` for headless behavioral unit testing.

## Overview

- **Static Analysis:** The `.luarc.json` files define the workspace boundaries and configure global annotations to recognize World of Warcraft API signatures to ensure clean typing prior to execution.
- **Dynamic Tests:** Busted specs reside in the `spec/` folder and execute against the `VolumeSliders/` target source via the `.busted` config.

## The Mock Environment (`spec/setup.lua`)

Since WoW addons inherently depend on the `_G` table containing native game engine functions (e.g., `CreateFrame`, `GetCVar`, `UIParent`), these dependencies are mocked inside `spec/setup.lua`. This file is automatically injected as a helper via the `.busted` defaults, executing before any test logic is compiled.

### Penetrating the Mock Environment

When writing new tests natively or via autonomous agents, you **must** understand how `setup.lua` mimics Blizzard's engine behavior:

1. **Variables and CVars:** 
   Functions like `GetCVar` and `SetCVar` interact with a local `cvars` state table. If you need to simulate a CVar change or test fallback logic, mutate state directly via `_G.SetCVar("Name", "Value")`.
2. **UI Frames (`CreateFrame`):**
   `CreateFrame` intercepts UI method requests and returns a mock UI object containing lightweight table implementations of `SetParent`, `IsShown`, `SetScript`, `SetPoint`, `SetHitRectInsets`, etc., completely circumventing hardware rendering logic.
3. **Libraries (`LibStub`):**
   `LibStub` uses a recursive metatable caller to automatically return dummy registries simulating valid `NewLibrary` and `GetLibrary` calls.
4. **State Restructuring:**
   Because state variables (like `VolumeSlidersMMDB`) persist in `_G` across different test blocks (`it`), ensure you reset mutable global parameters in a `before_each()` block if isolated test state is required.

**Tip:** Use `setup.lua` as an architectural reference to see exactly which WoW API pieces are currently available to the test runners. If your new volume logic utilizes a new WoW UI component or API call (such as a new `C_VoiceChat` enum), you **must natively mock it in `setup.lua` first.**
