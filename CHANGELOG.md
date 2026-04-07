# Changelog (v3.2.0)

## v3.2.0 — 2026-04-07

### Added
- **Mute & Volume Independence**: Muting a channel while a preset is active no longer locks the slider into "manual override" mode. Mutes behave fully independently, allowing presets to seamlessly take control of standard volume values tracking behind the scenes.
- **Preset Stacking (Most-Recent-Wins)**: Replaced the fixed priority layers for manual presets. When multiple overlapping presets are activated manually, the most recently activated preset will dynamically take absolute control. Turning it off elegantly falls back to the previous preset. 
- **Registry Shift Integrity**: Hardened the Settings Preset panel so deleting or re-prioritizing presets out of order natively shifts indexing algorithms immediately without corrupting your active automation trackers.

### Known Bugs
- **Preset Selection Dropdown in Settings**:
    - Does not currently update the dropdown text when a preset is saved until the dropdown is activated again.
    - The displayed preset is wrongly displayed after the selected preset's list order is changed.

## v3.1.1 — 2026-04-06

### Fixed
- **Baseline Volume Persistence**: Resolved a high-severity bug where logging in while standing in a zone with an active volume preset would permanently erase your normal baseline volumes. The addon now uses intelligent 3-way merge tracking to seamlessly reconstruct your intended volumes upon logging in under passive automation restraints.

## v3.1.0 — 2026-04-02
### Added
- **Preset Mathematical Limiting**: Presets can now act as a **Floor** (minimum) or **Ceiling** (maximum). 
    - *Example*: A Fishing preset can ensure your SFX adjusts to at *least* 80%, leaving it as is if it is already above 80%.
    - *Example*: A silencer preset can ensure Ambience stays *below* 20%, leaving it untouched if it is already less than 20%.
- **Unified State Stack Architecture**: Completely refactored preset management to ensure consistent volume behavior across overlapping automations.
- **V3 Database Migration**: Upgraded the internal data schema to V3. Legacy presets are automatically initialized for the new mathematical limiting system.
- **Persistent Baseline & Manual Overrides**: Manual slider adjustments now take absolute priority over active automated presets and are automatically cleaned up once automation ends.
- **Improved Voice Sync**: Voice Chat channels now correctly participate in the preset state stack.

## v3.0.1 — 2026-03-31

### Changed
- **Tooltip Label Refinement**: Renamed "Active Zone Presets" to "Active Presets" in the Minimap Icon settings for a cleaner look and terminology consistency.

## v3.0.0 — 2026-03-30

### SPECIAL NOTE
Running this version will migrate your existing settings to the new database schema. Please back up your settings before running this version. Once migrated your settings will not be backwards compatible with older versions of the addon.

Location of the addon's saved settings files:
- `World of Warcraft\_retail_\WTF\Account\<ACCOUNT_NAME>\SavedVariables\VolumeSliders.lua`
- `World of Warcraft\_retail_\WTF\Account\<ACCOUNT_NAME>\SavedVariables\VolumeSliders.lua.bak`

### Added
- **V2 Database Schema Overhaul**: Migrated the monolithic flat-key registry into isolated, modular tables (`appearance`, `channels`, `toggles`, `minimap`, `layout`, `hardware`, `automation`, `voice`). This provides optimized data parsing and structured state management for future expansion.
- **Preset Automation Refinement**: Integrated a mandatory bypass for legacy user presets that ensures newly added sound channels (Gameplay, Pings, Warnings) are automatically marked as "ignored" on first login, preventing unintended adjustment of newly added channels in the preset configuration.
- **Persistent Manual Toggles**: Toggling a preset via the main window dropdown or minimap hotkeys now persists across sessions and UI reloads, ensuring your manual override remains active as intended.
- **Minimap Mouse Consolidation**: Unified all minimap mouse behavior (Scroll Wheel, Middle-Click, etc.) into a single section in the settings UI under "Mouse Actions".

### Fixed
- **Redundant UI Overhead**: Eliminated duplicate refresh calls in the appearance layout logic that could cause layout flickering on slow systems.

## v2.16.0 — 2026-03-28

### Added
- **Preset Toggle System**: Manual preset application (via the main window dropdown or minimap hotkeys) now works as a toggle. The first activation applies the preset, and the second restores your original channel values — unless you've manually changed them, in which case it re-applies with a fresh snapshot.
- **Per-Channel Mute Control**: Presets can now optionally mute specific channels. Enable the "Mute" checkbox on individual channels in the Automation preset editor. Presets will never silently unmute a channel you muted manually — only channels the preset itself muted are restored.
- **Expanded Preset Channels**: The preset editor now supports all 8 CVar-based channels: Master, SFX, Music, Ambience, Dialog, Warnings, Gameplay, and Pings.
- **Help Text**: Added informational explainers on the Automation settings page ("How Presets Work") and under the Minimap Icon section on the Mouse Actions page describing toggle hotkey behavior.
- **Lock Icon Position**: Replaced the old "Shift+Drag to move" minimap icon behavior with a dedicated "Lock Icon Position" toggle on the Minimap Icon settings page. Uncheck it to drag the icon freely.

### Fixed
- **Dropdown Text After Deletion**: Fixed a bug on the Mouse Actions page where deleting a minimap icon action caused the remaining rows' dropdown labels to display incorrect effect names.

## v2.15.1 — 2026-03-26

### Fixed
- **Minimalist Icon Click Handler**: Fixed a regression where clicking the custom speaker icon did nothing.

## v2.15.0 — 2026-03-26

### Added
- **Minimap Customization Page**: The General settings page was getting too loud, so all Minimap-related options have been formally evicted and given their own dedicated Subcategory tab!
- **Dynamic Tooltips & Reordering**: You now have complete authoritative control over what information displays when hovering the minimap icon (Output Device, Active Presets, Master Volume, etc). Use the new Drag-and-Drop list in the settings panel to enable, disable, and rearrange your tooltip lines!
- **Strict Scroll Wheel Binds**: Scroll wheel controls applied over the Minimap no longer blindly piggyback off the primary slider bindings. You can now configure entirely unique `Shift/Ctrl/Alt` constraint matrices exclusively tailored for hovering the icon. 
- **Push-to-Talk Bypass (UNTESTED)**: Added a fast shortcut to in-game Voice Chat controls. You can now press and hold the custom Minimalist Map Icon to temporarily force open your microphone if you have PTT toggled, bypassing complex keybind requirements during chaotic encounters.

## v2.14.1 — 2026-03-22

### Fixed
- **LDB Scroll Wheel Issue:** Resolved an issue where scrolling to adjust volume on third-party broker frames (like ElvUI datatexts) only worked after the popup window was opened once.
- **Scroll Scale Configuration:** Using the mouse wheel over the minimap icon or LDB datatext will now accurately respect the custom step lengths configured under the "Slider Scroll Wheel" settings page.

## v2.14.0 — 2026-03-20

### Added
- **Expanded Mouse Actions**: Added two new quick-increment values (Change by 15%, Change by 20%) to the Mouse Actions section.
- **Dynamic Dropdown Selection**: Converted the Mouse Actions binding interfaces into structured Dropdown menus to cleanly prevent string malformations and provide explicit access to the full Modifier mapping list.

## v2.13.0 — 2026-03-18

### Added
- **Multi-Directional Resizing**: You can now grab the bottom-left and bottom-right corners of the main volume window to resize width and height simultaneously.
- **Visual Edge Highlights**: Replaced standard bounding areas with a soft golden outer glow that  highlights resizable edges and corners when your mouse hovers over them.

### Fixed
- **Automatic Expansion Bug**: Fixed the known issue where enabling new sliders (like Pings or Dialog) from the Settings menu would cause them to bleed off the edge of the window. The volume window will now automatically expand its width to instantly accommodate newly toggled channels.

## v2.12.1 — 2026-03-12

### Fixed
- **Combat Taint Error**: Resolved an issue where a "secret value" returned by the game engine during LFG Queue Pops or Fishing casts could trigger a Lua taint error (`attempt to compare local soundID`) while in combat.
- **Safety Rollback**: Restored explicit `issecretvalue` checks in `LFGQueue.lua` and `Fishing.lua` to properly filter opaque engine payloads before they cause comparison errors in secure execution paths.

## v2.12.0 — 2026-03-11

### Added
- **Gameplay & Pings Sliders**: Added two optional new sliders to the main window supporting the "Gameplay Sound Effects" (combat rotational acoustics) and "Ping System" channels. You can toggle their visibility inside the Settings > Window page.
- **Improved Settings Sections**: The settings UI has been refined. Categories are now appropriately labeled "Slider Customization" and "Window Customization".

### Known Issues
- The main volume window may not automatically expand its width when new sliders are enabled in the settings. You may need to manually drag the window edge to resize it so the new slider fits correctly.

## v2.11.0 — 2026-03-10

### Added
- **Midnight Compatibility**: Added explicit support for "Void Hole Fishing" in the Midnight expansion.
- **Performance Optimization**: Optimized high-frequency event listeners by leveraging native engine taint protections, reducing CPU overhead during combat and fishing.

## v2.10.0 — 2026-03-07

### Added
- **Automation Preset Overhaul**: Fishing and LFG Queue Pop boosts now use the Preset Profile system. You can now select specific profiles for these automations in the settings panel.
- **Prioritized Automation Engine**: Improved the backend logic to handle multiple concurrent automations (Zones, Fishing, LFG) with a robust priority system.
- **LEGACY Migration**: Existing Fishing and LFG boost settings are automatically converted to new "LEGACY" preset profiles upon login.

## v2.9.2 — 2026-03-06

### Added
- **Minimap Performance Optimization**: Significantly reduced CPU overhead for users who have the minimap button disabled or un-bound. Native Minimap and zoom button hooks are now deferred and only applied when actually needed.

### Improved
- **Settings Transparency**: Added "Requires Reload" notifications to the Minimap Icon settings to clearly inform users when a UI reload is necessary to fully purge deferred hooks.

## v2.9.1 — 2026-03-06

### Fixed
- **Midnight Compatibility (WoW 13.x)**: Resolved a critical taint error where the `PlaySound` hook could crash the UI when encountering "secret" sound identifiers.
- **Safety Guards**: Implemented `issecretvalue` protection across the LFG, Fishing, and Presets modules to ensure stability in protected game contexts.

## v2.9.0 — 2026-03-05

### Added
- **Dynamic Window Resizing**: The popup window now supports free-form resizing. Handles on edges and corners allow for custom width and height.
- **Dynamic Layout Engine**: Sliders now automatically reflow and adjust their spacing based on the window width. 
- **Adaptive Spacing Floor**: Intelligently switches between tight packing (-20px) when titles are hidden and cleaner spacing (-5px) when titles are shown.
- **Background Color Picker**: Accessible via Settings > Window, allowing for custom background colors and opacity levels.
- **Persistent Window Toggle**: A new "Keep Open" option prevents the window from closing when clicking outside of it.
- **Automated Resize Bounds**: The window's minimum size is now dynamically calculated based on the number of visible sliders to prevent layout breakage.

### Fixed
- Fixed a crash when canceling the Background Color Picker.
- Fixed an issue where the background color preview swatch had incorrect draw layering.
- Fixed a visibility bug where the preview slider in the settings was hidden by default.
- Corrected various padding and spacing inconsistencies in the footer and slider columns.

## v2.8.0

- **Under the Hood:** Completely overhauled the internal rendering and event tracking engine to dramatically improve performance. 
- **Optimization:** The custom minimalist minimap icon now dynamically reduces its polling rate while the mouse is away, saving CPU cycles during gameplay.
- **Optimization:** Eliminated garbage collection spikes triggered during rapid mouse wheel volume adjustments.
- **Optimization:** Rewrote the main sliding panel rendering loop to use a "dirty-flag" model, preventing the game from executing thousands of unnecessary math calculations when the UI hasn't structurally changed.

## v2.7.0

### Added
- **Mouse Actions Settings Page** — The former "Click Actions" page has been completely overhauled and renamed to "Mouse Actions". Configure custom modifier + mouse button combinations for the Minimap Icon, Slider Buttons, and now the Slider Scroll Wheel!
- **Slider Scroll Wheel Modifiers** — A brand new column on the Mouse Actions page lets you assign modifier keys (Shift, Ctrl, Alt, or combinations) to change the scroll wheel step size on your volume sliders. For example, hold Shift while scrolling for 10% steps instead of the default 1%.
- **Duplicate Binding Prevention** — The Mouse Actions page now prevents you from accidentally assigning the same modifier combination to multiple actions in the same column.
- **Show Tooltip Toggle** — Added a new "Show Tooltip" checkbox under the Minimap Icon settings. Turn it off to hide the tooltip when hovering over the minimap icon.

## v2.6.1

- **UI Update:** Replaced the "Settings" button on the main slider window with a modern gear icon.
- **UI Update:** Redesigned the main Settings page header. The title is now larger and gold, and a clean horizontal divider separates the header from the configuration options.
- **UI Update:** Added the CurseForge project URL directly to the Settings page for easier access to updates and documentation.
- **UI Improvement:** Removed the verbose help text from the Settings header to provide a cleaner, more focused configuration experience.

## v2.6.0

- **New Feature:** Added "Zone Triggers", "Fishing Boost", and "LFG Pop Boost" toggles directly to the main slider window's footer for quicker access.
- **Customization:** Added a new "Footer Elements" column to the Window settings page. You can now toggle the visibility of any footer element and drag-and-drop them to reorder how they appear!
- **Customization:** Added a "Limit Footer Columns" option to the Window settings page to restrict the maximum number of items allowed per row in the flexible footer layout.
- **UI Improvement:** The main window footer has been upgraded to a dynamic layout engine that intelligently wraps, left/right aligns, and centers items based on your window width and visible item count.
- **UI Improvement:** Reorganized the "Window" settings page with visual dividers, grouped the "Header Elements" toggles, and improved the layout flow.

## v2.5.0

- **New Feature:** Zone Triggers have been fully expanded and renamed to **Presets**!
- **New Feature:** Added a brand new Preset quick-apply dropdown menu to the main volume slider window for instant access to your saved configurations without opening the options menu.
- **Customization:** Presets can now be freely reordered from the Settings page so your most important setups appear at the top of the list.
- **Customization:** Added visibility toggles to show or hide individual Presets from appearing in the new dropdown menu.
- **Customization:** Added a new element visibility toggle in Settings to completely hide the new Presets dropdown menu if you prefer the classic minimalist look.
- **UI Improvement:** Greatly improved the visual layout of the Automation Settings page with dynamic dropdown resizing, mathematically centered data entry fields, and modern slider alignment.
- **UI Improvement:** Upgraded the stepper arrows in the Settings page to use high-resolution Blizzard texture assets.

## v2.4.0

- **New Feature:** Added an "LFG Queue Pop Boost" toggle to the Settings page! This dynamically maximizes the Master and SFX volumes when your Dungeon, Raid, or PvP queue prompt appears on screen so you never miss it. It automatically restores your original volumes 4.5 seconds later (after the sound finishes playing).
- **UI Improvement:** Greatly improved the "Automation" settings page. The channel inputs are now explicitly clamped to 0-100 values to prevent errors, and their font rendering and visual alignment have been polished.

## v2.3.0

- **New Feature:** Added a "Fishing Splash Boost" toggle to the Settings page! This dynamically maximizes the sound effects volume while you have your fishing bobber cast out, letting you clearly hear the splash without turning up other elements. It safely disables itself if you enter combat.

## v2.2.1


- **Bug Fix:** Fixed an issue where the text entry boxes for slider height and spacing would appear empty the first time you opened the Settings menu.
- **UI Improvement:** Expanded tooltips for the slider height and spacing options to include their allowed minimum and maximum values.
- **UI Improvement:** Reorganized the settings menus to automatically center their columns and space themselves out dynamically on wider screens.
- **UI Improvement:** Relocated several visibility and spacing options around the settings tabs for better logical grouping.
- **UI Improvement:** Fixed a typo where the addon version text would sometimes show two 'v' characters (e.g. vv2.2.0).

## v2.2.0

- **New Feature:** Added a powerful Zone Triggers system! You can now configure different volume levels for specific zones (like muting the ambient loop in the Isle of Quel'Danas). The addon automatically restores your previous volume when you leave the area.
- **New Feature:** The Zone Triggers system includes a new Settings page to manage your profiles with prioritization for overlapping areas.
- **UI Improvement:** The Addon Version is now visible at the top of the Settings window.
- **UI Improvement:** The window title is now left-aligned.
- **UI Improvement:** The "Settings" text button has been replaced with a clean gear icon positioned next to the Lock button.
- **UI Improvement:** The help text at the top of the panel now wraps dynamically to multiple lines based on the window width.
- **UI Improvement:** Added a visibility toggle for the help text under Element Visibility in the Settings page.
- **UI Improvement:** Footer dropdowns (Output, Voice Mode) now align flush in a clean column when the window is in a narrow, stacked layout.

## v2.1.2
- **UI Improvement:** Added descriptive tooltips to almost all UI elements, including slider tracks, stepper arrows, and footer toggles, explaining their function on hover.

## v2.1.1

- **Bug Fix:** Fixed a floating-point calculation error where clicking the up or down arrows on a volume slider would sometimes cause the volume to get stuck at 44% or other incorrect percentage values.

## v2.1.0

- **New Feature:** Added a modern, "Minimalist" minimap icon! This alternative style uses a clean gold speaker icon and seamlessly integrates with the native minimap zoom controls.
- **New Feature:** The Minimalist icon features an intelligent hover engine — it completely fades out when your mouse leaves the minimap, keeping your UI clean and uncluttered.
- **Customization:** The new Minimalist icon is enabled by default for users without heavy minimap overhauls. You can switch back to the classic ringed button at any time in the AddOn Settings.
- **Customization:** The Minimalist icon can be completely detached from the minimap using the new "Bind to Minimap" toggle, allowing you to SHIFT-drag it anywhere on your screen.
- **UI Improvement:** Added a dark, readable background to the Volume Sliders Settings menu to vastly improve text contrast against the game world.
- **UI Improvement:** The 'High' and 'Low' text labels on the top and bottom of sliders are now hidden by default for a cleaner look. You can re-enable them in the Settings.

## v2.0.0
- **Performance:** Applied multiple optimizations including deduplicated slider construction, localized global lookups, and cached database references.
- **UI Improvement:** When switching audio output devices, the Master slider now briefly displays a "Switching..." indicator while the sound system restarts, giving clear visual feedback instead of silently correcting the volume in the background.
- **Bug Fix:** Fixed inconsistent volume restoration when switching between audio output devices.

## v1.4.0

- **New Feature:** Added four new Voice Chat sliders (Voice Chat Volume, Voice Chat Ducking, Microphone Volume, and Microphone Sensitivity) directly to the main volume control! Voice Chat Volume and Ducking are enabled by default.
- **New Feature:** Added a Voice Chat Mode button (Push to Talk / Open Mic) to the window footer to quickly toggle between speaking modes.
- **Customization:** You can now toggle the visibility of the new Voice Chat sliders from the AddOn Settings tab.
- **UI Improvement:** Added a Settings icon next to the Lock window button to quickly open the AddOn configuration panel.

## v1.3.6
- **New Feature:** The main Volume Sliders window is now movable! Click the "Unlocked" text button in the top right to freely drag the window anywhere on your screen. The window will persist its new position between sessions. Click "Locked" to anchor it back to the minimap button.
- **UI Improvement:** The minimap button will now reliably close the window if it is already open, regardless of its locked state.

## v1.3.5

- **Customization:** Refined the settings panel by replacing the basic text inputs with standard horizontal sliders accompanied by manual numeric entry boxes.
- **Customization:** Added the ability to adjust the horizontal spacing between slider columns (from 5px to 40px).
- **UI Improvement:** Greatly enhanced the main window footer layout logic to intelligently align, stack, and unstack "Sound at Character", "Sound in Background", and the "Output Selector" based on the available window width and your current visibility settings.
- **UI Improvement:** Removed unused padding and tightened the overall visual balance of the Settings panel.

## v1.3.4

- **Customization:** Added **Channel Visibility** toggles to show or hide individual sliders (Master, SFX, Music, Ambience, Dialog).
- **Customization:** You can now freely reorder the sliders! Re-implemented the Channel Visibility list to support modern drag-and-drop reordering logic.
- **Customization:** Users can now customize the vertical **Slider Height** (100px to 250px) via a new text entry in the Settings panel.
- **UI Improvement:** The main window now dynamically calculates its width and height based on the number and size of visible sliders.
- **UI Improvement:** Improved the window footer layout to automatically switch "Sound in Background" and "Sound at Character" to a horizontal layout when the output selector is hidden and space permits.
- **Optimization:** Implemented **On-Demand Settings Loading**. The settings UI now only loads when first requested, significantly reducing login memory footprint.
- **Bug Fix:** Fixed an issue where the master volume would get stuck at 100% when changing audio output devices.
- **Bug Fix:** Resolved an issue where the slider height input box would sometimes appear empty on the initial opening of the Settings panel.

## v1.3.1

- **New Feature:** Added a sixth slider for **Encounter Warnings** (Gameplay Sound Effects channel).
- **New Feature:** Added a **Sound in Background** toggle to the main window footer, stacked neatly with "Sound at Character".
- **Customization:** Added new visibility toggles for the "Sound at Character" checkbox and the "Output Selector" dropdown.
- **User Experience:** Added helpful tooltips to all items in the Settings options panel to explain their function.
- **Dynamic Layout:** Significantly improved the window logic to handle any combination of visible sliders and footer elements, with automatic centering and frame resizing.

## v1.3.0

- **New Feature:** Added a full Settings options panel (via Escape -> Options -> AddOns) allowing for deep customization of the slider appearance.
- **Customization:** Users can now pick between multiple Knob styles (Gold Diamond or Minimal Silver) and Stepper Arrow styles (including new Plus/Minus variations in Silver or Gold).
- **Customization:** Independently control the text colors (Gold or White) for slider titles, percentage values, and High/Low labels.
- **Element Visibility:** Toggle any part of the slider on or off, including titles, buttons, tracks, and mute checkboxes.
- **Dynamic Layout:** The sliders and the main popup window itself now dynamically resize and collapse based on your visibility settings, keeping the UI compact and perfectly tailored.
- **Under the Hood:** Significant refactor of the internal frame structure for improved stability and performance.


## v1.2.4

- **Visual Update:** The slider thumbs have been replaced with the modern "Boss Abilities" golden diamond.
- **Visual Update:** The horizontal stepper arrows have been replaced with the modern minimap Plus `(+)` and Minus `(-)` zoom buttons for better clarity and native vertical alignment.
- **Under the Hood:** Adjusted interactive hitboxes and element spacing for a crisp layout. Future groundwork was laid for a toggle to restore legacy silver aesthetic.

## v1.2.3

- **Documentation:** Updated README.md to match the current description on the CurseForge project page.

## v1.2.2

- **Under the Hood:** Integrated Luacheck static analysis to ensure code quality and prevent Lua errors natively.

## v1.2.1

- **Optimization:** Removed native Blizzard UI dependencies (`Blizzard_Settings`, `Blizzard_SharedXML`) from the addon manifest.

## v1.2.0

### Layout & UI Overhaul
- Narrowed the overall window for a more compact and space-efficient view.
- Re-anchored the exact volume percentages to sit directly under the title texts.
- Widened the audio device selector dropdown.
- Configured audio device names to natively wrap into two lines, preventing UI stacking issues that occurred with excessively long device names.
- Dynamically centered the audio device and "Sound at Character" selections to perfectly align with the content, regardless of user locale translation lengths.

### Audio Device State Persistence
- *Hotfix:* Restored a core feature that was being broken by World of Warcraft itself. When switching output devices natively, WoW asynchronously crashes the Master Volume back to 100%. The addon now remembers your chosen Master Volume per device and aggressively enforces that value for a few seconds following an output swap to override the engine reset.

## v1.1.4

- Restructured repository layout to use a nested AddOn folder for cleaner code management.
- Re-configured CurseForge packager and GitHub release workflows.

## v1.0.0

Initial release.

### Features
- Five vertical volume sliders: Master, Effects, Music, Ambience, and Dialog
- Per-channel mute checkboxes
- Minimap button with left-click (open panel) and right-click (toggle master mute)
- Scroll wheel on minimap icon to adjust master volume (fine control with Ctrl)
- Stepper arrows for snapping to 5% increments
- Sound output device dropdown
- Sound at Character toggle
- Addon Compartment support
- Data Broker (LDB) compatibility
- Click outside or press Escape to close the panel
