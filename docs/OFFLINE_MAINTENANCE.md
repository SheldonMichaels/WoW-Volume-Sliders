# Maintenance Without In-Game Testing

The maintainer currently has no active WoW subscription. Until in-game testing is available, the approved maintenance scope is documentation, source comments, tests of existing behavior, and backlog review.

## Safe scope

- Correct stale comments without changing executable Lua.
- Keep contributor instructions, links, module maps, and AI guidance consistent with the repository.
- Add regression tests through real module entry points using the existing mocked runtime.
- Review issues and record proposed disposition with code or documentation evidence.
- Prepare the [in-game test checklist](IN_GAME_TESTING.md) for a future tester.

Do not change runtime behavior, saved-variable defaults or migrations, embedded libraries, UI assets/layout, `.toc` compatibility declarations, or release versions as part of this work. If a new test exposes a production bug, record it for later work rather than expanding the scope into a runtime fix. Passing mocks does not establish compatibility with a new WoW patch.

Run `luacheck VolumeSliders spec` and `busted . --verbose` for test or source-comment changes. Review documentation links and diffs. Report in-game checks as **not performed**, never as passed. These maintenance changes do not require a release tag or a new addon version.

## Repository AI configuration audit — 2026-09-05

| Surface reviewed | Finding and disposition |
| --- | --- |
| Root `AGENTS.md`, `docs/AGENT_WORKFLOW.md` | Shared contract retained; added offline scope and Codex routing. |
| `.agents/README.md`, `agents.md` | Shared skills distinguished from persona descriptions and tool-specific workflow discovery. |
| All seven `.agents/skills/` packages and five reference templates | Instructions remain reusable; validation guidance now distinguishes automated evidence from in-game results. |
| All four `.agents/workflows/` files | Retained Antigravity procedures; documented explicit file-based use and offline scope. |
| `.agent/`, `GEMINI.md`, `.codex/`, `AGENTS.local.md`, `AGENTS.override.md` | Absent at review time. `.agent/` remains an ignored compatibility location, not a second tracked policy tree. |
| All five `.cursor/rules/` files | Reviewed routing; corrected wording that could allow an agent to merge a PR. |
| `.cursor/mcp.json` | Optional `wow-api-mcp` configuration exists for Cursor. No connection or package installation was tested. |
| `.vscode/settings.json`, workspace file, both `.luarc.json` files | Editor/Lua tooling includes machine-specific paths; documented local setup limitations. Not a Codex instruction source. |
| `.gitignore`, `.github/workflows/`, `.pkgmeta`, `.busted`, `.luacheckrc`, `.luacov` | Reviewed tooling/package boundaries; local coverage reports and Codex overrides are ignored. CI and packaging behavior unchanged. |
| README, CONTRIBUTING, architecture, schema, testing, release and Antigravity docs | Updated onboarding and testing limits; retained historical changelog entries. |

This is a repository configuration review, not a test of Antigravity, Cursor, Gemini, or user-global assistant settings. Shared skills were visible in the Codex session used for this review. Personal settings and private historical notes are not copied into tracked documentation.

## Deferred schema cleanup

`Core.lua` still declares `DEFAULT_DB.schemaVersion = 9`, while `Init.lua` migrates persisted databases to version 10. This maintenance pass clarifies the comment and tests migration preservation; it does not change either value or the migration order. Aligning defaults requires a separate review of fresh installs, existing version-10 databases, and missing-field recovery.

## Open-issue review — 2026-09-05

All 11 open issues were reviewed. No issues were posted to, edited, or closed. No clear duplicate feature requests were identified. The following are proposed dispositions, not claims of in-game verification.

| Issue | Evidence and proposed next step |
| --- | --- |
| [#6 Preset rules](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/6) | Much of the ruleset is now in `docs/PRESET_BEHAVIOR.md`. Reconcile remaining differences before marking the documentation request complete; retain the tracked document as the contract. |
| [#17 Slider separators](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/17) | UI enhancement; defer rendering and layout work until in-game checks are possible. |
| [#19 Mount automation](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/19) | New event/state behavior; defer pending API research and mounted/combat testing. |
| [#20 Cutscene automation](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/20) | New event timing and audio restoration behavior; defer until cutscenes can be tested. |
| [#21 Voice presets](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/21) | The description that voice is excluded is stale: `Presets.lua` has voice getters/setters and soft-mute handling. Candidate for scope reconciliation, not closure without voice-session verification. |
| [#22 Profile import/export](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/22) | Design discussion can happen offline; implementation touches user-owned data and UI, outside current scope. |
| [#23 Responsive settings](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/23) | Broad layout work; defer until multiple window sizes and UI scales can be tested. |
| [#25 Artwork](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/25) | Asset/layout enhancement; defer until visuals can be checked in-client. |
| [#27 Dynamic speaker icon](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/27) | Mute/unmute icon changes exist; requested low/medium/high volume stages are additional work. Keep open. |
| [#28 Dedicated push-to-talk button](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/28) | Minimap PTT handling exists, addressing one proposed option. A dedicated configurable button and live voice behavior still need review/testing. Keep open. |
| [#32 Per-channel device memory](https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues/32) | Current device memory handles master volume; the request explicitly extends this to selectable channels. Keep open; defer hardware/state changes. |
