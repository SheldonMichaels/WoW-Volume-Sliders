# Changelog

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
