# Volume Sliders

A World of Warcraft addon that provides quick-access vertical volume sliders for all five sound channels, right from your minimap.

![WoW](https://img.shields.io/badge/WoW-12.0.1-blue)

## Features

- **Five Channel Sliders** — Master, Effects, Music, Ambience, and Dialog, each with a vertical slider and percentage readout
- **Per-Channel Mute** — Individual mute checkbox below each slider
- **Minimap Button** — Left-click to open the panel, right-click to toggle master mute
- **Scroll to Adjust** — Mouse-wheel on the minimap/broker icon adjusts master volume (fine control with Ctrl held or at low volumes)
- **Stepper Arrows** — ▲/▼ buttons snap volume to the nearest 5% increment
- **Sound Output Device** — Dropdown to select your active audio output device
- **Sound at Character** — Toggle whether audio is positioned at your character or the camera
- **Addon Compartment** — Also accessible from the minimap Addon Compartment menu
- **Data Broker Support** — Compatible with LDB display addons (Titan Panel, ChocolateBar, etc.)
- **Modern UI** — Uses Blizzard's `SettingsFrameTemplate` and `MinimalSlider` atlas assets for a native feel

## Installation

### Manual
1. Download or clone this repository
2. Copy the `VolumeSliders` folder into your WoW addons directory:
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
