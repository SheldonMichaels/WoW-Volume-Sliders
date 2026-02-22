# Volume Sliders

A World of Warcraft addon that provides quick-access vertical volume sliders for all five sound channels, right from your minimap.

![WoW](https://img.shields.io/badge/WoW-12.0.1-blue)

## Current Features

- **Five vertical sliders** — one for each channel and last used volume values persist between mute/unmute
- **Per-channel mute toggles** — mute each channel individually
- **Minimap button** — left-click to open the panel, right-click to quick-toggle master mute
- **Scroll wheel** — over the minimap icon to adjust master volume (hold Ctrl for fine 1% steps)
- **Stepper arrows** (▲/▼) — snap volume to the nearest 5% increment
- **Sound output device selector** — change your active audio device, with a saved master volume value per device
- **"Sound at Character" toggle** — positional audio at your character (checked) or at the camera location (unchecked)
- **Addon Compartment & Data Broker** — works with the built-in compartment menu (tested) and LDB displays like Titan Panel (untested) or ChocolateBar (untested)
- **Native look & feel** — uses native Blizzard UI assets

## Possible Future Features

- Movable slider window
- Toggle for persistent slider window if desired
- Hotkey to show/hide the slider window
- Settings page, to include:
  - Toggle to show/hide elements in the volume slider window such as output selector
  - Configure what mouse buttons and modifiers perform which actions on the minimap button and sliders
  - Change element spacing in the slider window for more or less empty space
  - Change slider order
  - Show/hide specific sliders

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
