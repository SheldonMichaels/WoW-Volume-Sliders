# In-Game Test Checklist

Use this when a tester has access to the target WoW Retail client. None of these checks were performed during the offline maintenance review.

Record the addon commit/version, WoW version/build and interface number, locale, UI scale, other enabled addons, audio devices, and test date. Back up SavedVariables before testing upgrades; keep backups and screenshots in ignored local storage.

| Check | Procedure and expected result | Result |
| --- | --- | --- |
| Fresh install | Start with a separate clean configuration. Login, open settings and popup, reload; defaults initialize and persist without Lua errors. | Not run |
| Upgrade | Load a backed-up older configuration. Login and reload; preset bindings, layout, custom minimap settings and volumes remain intact; schema reaches 10. | Not run |
| Volume and mute | Adjust each enabled channel, mute and unmute it, then use Blizzard sound settings. Values and labels stay synchronized; unrelated channels do not change. | Not run |
| Overlapping presets | Activate overlapping automatic/manual presets, adjust a channel, then deactivate presets in reverse order. Compare restoration and mute behavior with `PRESET_BEHAVIOR.md`. | Not run |
| Reload and logout | Reload/logout with active manual presets and muted channels. Confirm active state and baseline restoration match the documented contract. | Not run |
| Output devices | Switch between two devices with distinct stored master levels; repeat with memory disabled and during a preset. Confirm intended levels return after restart and other channels remain correct. | Not run |
| Fishing | Start, cancel and finish casts; enter combat during a cast; disable automation while active. Temporary boosts restore correctly and do not unmute manually muted channels. | Not run |
| LFG | Exercise queue pop, accept, decline, timeout and unrelated ready checks. Boost only for LFG proposals and restore afterward. | Not run |
| Minimap | Test standard/minimalist styles, bound/detached positioning, lock, dragging, clamp mode, scale, tint and both fades; reload and move/resize the minimap. Confirm click, scroll and tooltip behavior. | Not run |
| Settings/window | Resize, reorder sliders/footer items, toggle visibility, lock/unlock, use Escape/click-away and addon compartment. Inspect clipping at multiple UI scales. | Not run |
| Voice/PTT | With a second participant, test voice sliders, soft mute and PTT press/release/leave behavior. Confirm the previous voice mode returns. | Not run |
| Combat and integrations | Repeat key interactions in and out of combat, first with only Volume Sliders, then supported minimap/broker addons. Record Lua errors, blocked actions and visual differences. | Not run |

Mark each row pass, fail, or not run and attach reproduction steps for failures. A partial checklist must identify untested features. Update compatibility declarations only after target-client results have been reviewed.
