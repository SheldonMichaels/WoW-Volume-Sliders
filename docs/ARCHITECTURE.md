# Architecture Overview

## Runtime Composition

The addon is split into focused modules under `VolumeSliders/`:

- `Core.lua`: shared constants, helpers, default schema, and cross-module utilities
- `Init.lua`: `PLAYER_LOGIN` bootstrap, schema migrations, baseline restoration, and module initialization
- `PopupFrame.lua`: main in-game slider window
- `Settings_*.lua`: Blizzard Settings UI sections (window, sliders, automation, minimap, mouse actions)
- `Presets.lua`: preset registration, priority ordering, and state refresh
- `MinimapBroker.lua`: LibDataBroker / LibDBIcon integration and icon interactions
- `Fishing.lua` / `LFGQueue.lua`: event-driven automation adapters

## Data Model

Saved variables live in account-scoped `VolumeSlidersMMDB` and are namespaced by responsibility:

- `appearance`
- `layout`
- `toggles`
- `channels`
- `minimap`
- `automation`
- `hardware`
- `voice`

See `docs/DATA_SCHEMA.md` for canonical structure.

## Startup Flow

1. Migrate schema (versioned migration chain in `Init.lua`)
2. Merge missing defaults
3. Capture baseline volume/mute state
4. Restore active manual preset registry
5. Register minimap broker/icon integration
6. Initialize settings and event modules

## Key Invariants

- Migration functions must be additive and safe to run once on login.
- `schemaVersion` only advances via explicit migration code.
- Preset index operations must keep automation pointers and bindings synchronized.
- UI state changes that affect layout should flag layout dirty before redraw.

## Third-Party Libraries

Bundled libraries live in `VolumeSliders/Libs/`:

- LibStub
- CallbackHandler-1.0
- LibDataBroker-1.1
- LibDBIcon-1.0
