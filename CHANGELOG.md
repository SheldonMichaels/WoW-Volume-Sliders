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
