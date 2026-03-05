# Volume Sliders

A World of Warcraft addon that provides quick-access vertical volume sliders for all five sound channels, right from your minimap.

![WoW](https://img.shields.io/badge/WoW-12.0.1-blue)

## Current Features

- **LFG Queue Pop Boost** — dynamically adjusts your volume when a Dungeon, Raid, or PvP queue prompt appears, automatically restoring your original levels after the sound finishes.
- **Fishing Splash Boost** — dynamically adjusts your volume while fishing, so you never miss a catch.
- **Volume Presets & Automation** — Save volume profiles to quickly apply them from a dropdown menu in the main window, or automate them to trigger in specific zones! Comes with an example Sunwell Silencer profile.
- **Nine vertical volume sliders** — Master, Effects, Music, Ambience, Dialog, Warnings, Voice Chat Volume, Voice Ducking, Mic Volume, and Mic Sensitivity. Last used volume values persist between mute/unmute
- **Per-channel mute** — mute each channel individually
- **Two Minimap styles** — choose between the classic ringed minimap button or a "minimalist" bare gold speaker icon that gracefully fades out when your mouse leaves the minimap.
- **Scroll wheel** — scroll over the minimap icon to adjust master volume (hold Ctrl for fine 1% steps)
- **Stepper arrows** (▲/▼) — snap volume to the nearest 5% increment
- **Sound output device selector** — change your active audio device, with a saved master volume value per device
- **Voice Chat mode toggle** — change between Push to Talk and Open Mic modes on the fly
- **"Sound at Character" toggle** — positional audio at your character (checked) or at the camera location (unchecked)
- **Addon Compartment & Data Broker** — works with the built-in compartment menu (tested) and LDB displays like Titan Panel (untested) or ChocolateBar (untested)
- **Native look & feel** — uses native Blizzard UI assets
- **Movable window** — detach the window from the minimap and place it anywhere
- **Dynamic Footer Elements** — quick-access toggles in the main window for Output, Voice Mode, Fishing, Triggers, and more. Highly customizable with drag-and-drop reordering and column limits.
- **Extensive Customization Options** — access via the WoW Interface options to customize slider height, toggle visibility of any channel or UI element (including the help text), change visual themes (gold/silver, diamond/minimal knobs, text colors), and freely drag-to-reorder the sliders to your preference.
- **Mouse Actions** — Configure what mouse buttons, modifiers, and scroll wheel behaviors perform on the minimap button, slider buttons, and slider scroll wheel from a dedicated settings page.

## Planned Future Features

- Toggle for persistent slider window if desired
- More texture choices
- Fully dynamic and resizable main slider window with dynamic elements
- More customization options for minimap button
- Control for "emote" sounds and specifically combat only sound effects

## Installation

### Manual
1. Download or clone this repository
2. Open the repository contents and copy the inner `VolumeSliders/` folder into your WoW addons directory:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Restart WoW or type `/reload` in chat

### CurseForge
Available at: [curseforge.com/wow/addons/volume-sliders](https://www.curseforge.com/wow/addons/volume-sliders)

## Usage

| Action | Result |
|--------|--------|
| **Left-click** minimap icon | Open/close the slider panel |
| **Right-click** minimap icon | Toggle master mute |
| **Scroll wheel** on minimap icon | Adjust master volume |
| **Ctrl + scroll** | Fine adjustment (1% steps) |
| **▲ / ▼ arrows** on sliders | Snap to nearest 5% |
| **Click outside** panel | Close the panel |
| **Escape** | Close the panel |

## Libraries

This addon bundles the following libraries (included in `Libs/`):

- [LibStub](https://www.wowace.com/projects/libstub)
- [CallbackHandler-1.0](https://www.wowace.com/projects/callbackhandler)
- [LibDataBroker-1.1](https://www.wowace.com/projects/libdatabroker-1-1)
- [LibDBIcon-1.0](https://www.wowace.com/projects/libdbicon-1-0)

## License

All Rights Reserved © 2026 Sheldon Michaels — free for personal, non-commercial use. See [LICENSE](LICENSE) for details.
