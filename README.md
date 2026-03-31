# Volume Sliders

A World of Warcraft addon that provides quick-access vertical volume sliders for all 12 sound channels, right from your minimap.

![WoW](https://img.shields.io/badge/WoW-12.0.1-blue)

## Current Features

### Core Sound Control
- **12 Vertical Volume Sliders** — Master, Effects, Music, Ambience, Dialog, Warnings, Gameplay, Pings, Voice Chat, Voice Ducking, Mic Volume, and Mic Sensitivity.
- **Precision Snapping** — Use the (▲/▼) stepper arrows to snap volume to the nearest 5% increment.
- **Per-Channel Mutes** — Mute individual channels; last-used volume values persist between toggle states.
- **Output Device Selector** — Quickly swap audio output devices; the addon remembers your preferred Master volume for every unique device.
- **Positional Audio Toggle** — Toggle "Sound at Character" to alternate between camera-based and character-based acoustics.

### Minimap & Navigation
- **Two Visual Styles** — Choose the classic ringed button or a "minimalist" speaker icon that automatically fades out when not in use.
- **Customizable Tooltips** — Use a drag-and-drop list to decide exactly what displays on hover and in what order (Master Volume, Active Presets, Output Device, etc.).
- **Smart Scroll Wheel** — Scroll over the icon to adjust volume for a selected channel. Configure unique `Shift/Ctrl/Alt` modifiers for additional channels.
- **PTT Shortcut** — Press and hold the minimalist icon to temporarily force "Open Mic" mode if you have Push-to-Talk enabled for the in game voice chat.

### Automation & Presets
- **Volume Presets** — Save custom volume profiles and apply them instantly via the in window dropdown or automated triggers.
- **Preset Toggles** — Manual presets (dropdown and minimap hotkeys) work as toggles: the first press applies; the second restores your original volumes. Presets support opt-in per-channel muting.
- **Zone Automation** — Configure presets to automatically activate when entering specific zones (e.g., muting Ambience in the Isle of Quel'Danas) and revert when leaving the zone.
- **LFG & Fishing Boosts** — Apply a preset during Queue Pops or Fishing casts, with automatic restoration afterwards.

### UI & Aesthetics
- **2D Dynamic Resizing** — Grab edges or corners to freely resize the main slider window; sliders and footers automatically reflow to fit your layout.
- **Custom Backgrounds** — Adjust window colors and opacity levels using the native Blizzard color picker.
- **Movable & Persistent** — Slider window can locked in place or movable. Window persistence can be toggled on/off.

### Integration
- **Addon Compartment** — Fully integrated with the native WoW 10.x+ AddOn compartment menu.
- **Data Broker (LDB)** — Compatible with display addons like Titan Panel, ChocolateBar, and ElvUI. (Mostly untested)

## Planned Future Features

### Visuals & Personalization
- **Interactive Element Overhaul** — Replacing text buttons with modern, thematic icons (e.g., swapping the lock/unlock text for functional padlock or chain-link assets).
- **Expanded Texture Library** — More choices for slider tracks, knobs, and background textures to further match your personal UI aesthetic.
- **Minimap Icon Refinement** — Full customization of the minimap button size, colors, fade speeds, and rotation, plus a fuzzy drop shadow upgrade for better visibility.

### Audio & Preset Depth
- **Expanded Channel Control** — Adding support for "Emote Sounds" and other hidden game audio channels.
- **Dynamic Volume Units** — Choose your preferred display unit between percentages (Default), decimals (0.0-1.0), or raw decibels (dB).
- **Contextual Automation** — New triggers for automatic volume "ducking" when mounting specific creatures or during cinematic cutscenes.
- **Advanced Preset Logic** — Implementation of directional rules (e.g., "Only lower volume") and "hard mutes" that cannot be overridden by automation.

### UI & UX Improvements
- **Profile Export/Import** — Share your complex automation setups and UI layouts with the community or sync them across multiple accounts.
- **Responsive Settings Overhaul** — A complete refactor of the options menu to ensure every slider, checkbox, and dropdown fluidly adapts to any window size.
- **Standalone PTT Frame** — An optional, freely-movable button frame designed specifically for Push-to-Talk use, with its own independent show/hide automations.

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
| **Scroll wheel** on minimap icon | Adjust mapped volume (Customizable) |
| **Hold Left-click** (Minimalist) | Push-to-Talk Bypass (Forces Open Mic) |
| **Ctrl + scroll** | Fine adjustment (1% steps - Default) |
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
