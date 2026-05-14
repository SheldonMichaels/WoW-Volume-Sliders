# VolumeSliders Data Schema

**Database:** `VolumeSlidersMMDB`
**Scope:** Global / Account-wide
**Format:** Serialized Lua Table (Pseudo-JSON representation below)
**Last Audited:** 2026-05-13 (SchemaVersion 10)

This document defines the exact shape of the saved variables used by Volume Sliders. It acts as the single source of truth for the data layer, distinguishing between user-configurable options, transient session states, and deprecated keys.

> **Contract:** Any contributor changing persisted-vs-transient boundaries, migration behavior, or namespace keys MUST update this document in the same PR. See `docs/AGENT_WORKFLOW.md` for workflow requirements.

## Root Structure

As of version 3.0.0, the monolithic flat-key structure has been deprecated in favor of nested functional namespaces to optimize data bounding and Settings UI integration.

```json
{
  "schemaVersion": 10,

  // ---------------------------------------------------------
  // 1. APPEARANCE & WINDOW STYLING
  // ---------------------------------------------------------
  "appearance": {
    // Window Dimensions & Positioning
    "windowWidth": "number",  // Default: 375 (Set when user resizes; nil = use VS.DEFAULT_WINDOW_WIDTH)
    "windowHeight": "number", // Default: 440 (Set when user resizes; nil = use VS.DEFAULT_WINDOW_HEIGHT)
    "customX": "number",      // Default: nil (X coordinate for custom anchor; set when window is dragged)
    "customY": "number",      // Default: nil (Y coordinate for custom anchor; set when window is dragged)

    // Background Color
    "bgColor": {
      "r": "number", // Default: 0.05 (Float 0.0 - 1.0)
      "g": "number", // Default: 0.05 (Float 0.0 - 1.0)
      "b": "number", // Default: 0.05 (Float 0.0 - 1.0)
      "a": "number"  // Default: 0.95 (Opacity 0.0 - 1.0)
    },

    // Widget Styling Enums
    "knobStyle": "string",  // Default: "Diamond" (Enum e.g., "Diamond", "Silver")
    "arrowStyle": "string", // Default: "GoldPlusMinus" (Enum e.g., "GoldPlusMinus")
    "titleColor": "string", // Default: "White" (Enum e.g., "White", "Gold")
    "valueColor": "string", // Default: "Gold" (Enum e.g., "Gold")
    "highColor": "string",  // Default: "White" (Enum e.g., "White")
    "lowColor": "string",   // Default: "White" (Enum e.g., "White")
    "sampleSound": "number|string", // Default: 856 (SoundKit ID for slider chimes)
    "sampleSoundMinimap": "number|string", // Default: 856 (SoundKit ID for minimap chimes)
    "volumeDisplayFormat": "string" // Default: "percentage" (Enum: "percentage", "decimal", "decibel")
  },

  // ---------------------------------------------------------
  // 2. LAYOUT ORCHESTRATION & BINDINGS
  // ---------------------------------------------------------
  "layout": {
    // Structural Ordering
    "sliderOrder": ["string"], // Default: VS.DEFAULT_CVAR_ORDER (Ordered array of CVar channel names)
    "footerOrder": ["string"], // Default: VS.DEFAULT_FOOTER_ORDER (Ordered array of footer visibility keys)
    
    // Layout Constraints
    "maxFooterCols": "number",    // Default: 3 (Maximum items per footer row)
    "limitFooterCols": "boolean", // Default: true (Whether to enforce maxFooterCols)

    // Defines what happens when clicking or scrolling on specific UI boundaries
    "mouseActions": {
      "sliders": [
        { 
          "trigger": "string",      // e.g., "LeftButton", "MiddleButton"
          "effect": "string",       // e.g., "ADJUST_5", "TOGGLE_WINDOW", "TOGGLE_PRESET"
          "stringTarget": "string", // [Optional] Target identifier (e.g., "Sound_MasterVolume" or "1" for Preset #1)
          "numStep": "number"       // [Optional] Numeric magnitude for adjustable effects (e.g., 0.05 for 5% scroll)
        }
      ], // Default: {}
      "scrollWheel": [
        { 
          "trigger": "string",      // e.g., "None", "Shift", "Ctrl"
          "effect": "string",       // e.g., "ADJUST_1", "SCROLL_VOLUME"
          "stringTarget": "string", 
          "numStep": "number"
        }
      ] // Default: {}
    }
  },

  // ---------------------------------------------------------
  // 3. TOGGLES & ELEMENT VISIBILITY
  // ---------------------------------------------------------
  "toggles": {
    // General Window State
    "persistentWindow": "boolean", // Default: false (True if clicking outside doesn't close the menu)
    "isLocked": "boolean",         // Default: false (True if the main window cannot be moved)
    "playSampleSound": "boolean",  // Default: false (True for slider chimes)
    "playSampleSoundMinimap": "boolean", // Default: false (True for minimap chimes)

    // Widget Components (Parts of a single slider row)
    "showTitle": "boolean",     // Default: true
    "showValue": "boolean",     // Default: true
    "showHigh": "boolean",      // Default: false
    "showUpArrow": "boolean",   // Default: true
    "showSlider": "boolean",    // Default: true
    "showDownArrow": "boolean", // Default: true
    "showLow": "boolean",       // Default: false
    "showMute": "boolean",      // Default: true
    
    // UI Elements (Parts of the main frame popup)
    "showWarnings": "boolean",       // Default: true
    "showBackground": "boolean",     // Default: true
    "showCharacter": "boolean",      // Default: true (Shows the "Sound at Character" toggle) TODO: change to false
    "showOutput": "boolean",         // Default: true (Shows output device dropdown) TODO: change to false
    "showPresetsDropdown": "boolean", // Default: true (Shows quick-apply presets dropdown)
    "showLfgPop": "boolean",         // Default: true (Shows LFG Pop Boost toggle in footer)
    "showZoneTriggers": "boolean",   // Default: true (Shows Zone Triggers toggle in footer) TODO: change to false
    "showFishingSplash": "boolean",  // Default: true (Shows Fishing Splash Boost toggle in footer) TODO: change to false
    "showHelpText": "boolean",       // Default: true (Shows help instructions in header)
    "showEmoteSounds": "boolean",    // Default: false (Shows Emote Sounds toggle in footer)
    "showVoiceMode": "boolean"       // Default: true (Shows Voice Chat Mode toggle in footer) TODO: change to false
  },

  // ---------------------------------------------------------
  // 4. CHANNELS (Visibility Configuration)
  // ---------------------------------------------------------
  // Determines which audio channels are rendered as sliders in the UI.
  "channels": {
    "Sound_MasterVolume": "boolean",            // Default: true
    "Sound_SFXVolume": "boolean",               // Default: true
    "Sound_MusicVolume": "boolean",             // Default: true
    "Sound_AmbienceVolume": "boolean",          // Default: true
    "Sound_DialogVolume": "boolean",            // Default: true
    "Sound_GameplaySFX": "boolean",             // Default: false
    "Sound_PingVolume": "boolean",              // Default: false
    "Sound_EncounterWarningsVolume": "boolean", // Default: false
    "Voice_ChatVolume": "boolean",              // Default: false
    "Voice_ChatDucking": "boolean",             // Default: false
    "Voice_MicVolume": "boolean",               // Default: false
    "Voice_MicSensitivity": "boolean"           // Default: false
  },

  // ---------------------------------------------------------
  // 5. MINIMAP CONFIGURATION
  // ---------------------------------------------------------
  "minimap": {
    "minimapPos": "number",        // Default: 180 (Radial degree placement 0-360, owned by LibDBIcon)
    "hide": "boolean",             // Default: false (Master visibility toggle for the addon icon)
    "minimapIconLocked": "boolean",// Default: true (Locks minimap icon dragging)
    "bindToMinimap": "boolean",    // Default: true (True if minimalist icon fades in on minimap hover)
    "minimalistMinimap": "boolean",// Default: nil (Toggles custom minimalist speaker icon style; nil = auto-detect)
    "minimalistOffsetX": "number", // Default: -35 (X offset for minimalist icon)
    "minimalistOffsetY": "number", // Default: -5 (Y offset for minimalist icon)
    "iconScale": "number",         // Default: 1.0 (Scale of minimalist icon)
    "iconColor": {                 // Default: {r=1, g=1, b=1, a=1} (Color tint for minimalist icon)
      "r": "number", "g": "number", "b": "number", "a": "number"
    },
    "useCustomTint": "boolean",    // Default: false (When true, apply iconColor; false uses atlas color)
    "fadeInSpeed": "number",        // Default: 0.1 (Fade-in duration in seconds)
    "fadeOutSpeed": "number",       // Default: 0.5 (Fade-out duration in seconds)
    "minimalistClampMode": "boolean", // Default: false (True to clamp radially, false for free X/Y)
    "minimalistAngle": "number",   // Default: 225 (Radial angle 0-360 if clamped)
    "minimalistRadius": "number",  // Default: 10 (Radial offset if clamped)
    
    // Tooltip and Click Bindings specific to the Minimap Icon
    "showMinimapTooltip": "boolean", // Default: true (Enables/disables minimap icon tooltip)
    "minimapTooltipOrder": [
      {
        "type": "string",   // "ChannelVolume", "MouseActions", "OutputDevice", "ActivePresets"
        "channel": "string" // Optional: specific CVar if type is "ChannelVolume"
      }
    ], // Default: {OutputDevice, MouseActions, ChannelVolume:Master, ActivePresets}
    "minimapScrollBindings": {
      "None": "string",  // Default: "Sound_MasterVolume" (Maps to CVar or "Disabled")
      "Shift": "string", // Default: "Disabled"
      "Ctrl": "string",  // Default: "Disabled"
      "Alt": "string"    // Default: "Disabled"
    },
    // Minimap-specific mouse click interactions.
    "mouseActions": [
      { 
        "trigger": "string", 
        "effect": "string",
        "stringTarget": "string",
        "numStep": "number"
      }
    ] // Default: {None+Scroll, SCROLL_VOLUME, Sound_MasterVolume, 0.05}
  },

  // ---------------------------------------------------------
  // 6. HARDWARE SPECIFICS
  // ---------------------------------------------------------
  "hardware": {
    // Stores preferred master volume per hardware output device name
    "deviceVolumes": {
      "[deviceName]": "number" // Default: {} (e.g., "Realtek Digital Output": 0.81)
    }
  },

  // ---------------------------------------------------------
  // 7. AUTOMATION & PRESETS
  // ---------------------------------------------------------
  "automation": {
    "persistedBaseline": {},           // Default: {} ({ [channel] = volume } The user's true intended volumes)
    "lastAppliedState": {},            // Default: {} ({ [channel] = volume } The last state written by EvaluateAllPresets)
    "enableTriggers": "boolean",       // Default: false (Master toggle for zone-triggered preset automation)
    "enableFishingVolume": "boolean",  // Default: false (Enables fishing splash boost automation)
    "enableLfgVolume": "boolean",      // Default: false (Enables LFG queue pop boost automation)
    "enableDeviceVolumes": "boolean",  // Default: true (Enables per-hardware-device master volume tracking)
    "fishingPresetIndex": "number",    // Default: 0 (Index in `presets` array for the fishing automation profile)
    "lfgPresetIndex": "number",        // Default: 0 (Index in `presets` array for the LFG automation profile)
    
    // User-defined volume states that can be triggered manually or automatically by zone.
    "presets": [
      {
        "name": "string",
        "priority": "number",        // Lower number = higher priority override
        "showInDropdown": "boolean", // True if manually selectable from UI drop-down
        "zones": ["string"],         // Array of sub/zone names that automatically trigger this
        "volumes": {
          "[cvarName]": "number"     // The volume to enforce (0.0 - 1.0)
        },
        "ignored": {
          "[cvarName]": "boolean"    // True if the channel shouldn't be touched by the preset
        },
        "mutes": {
          "[cvarName]": "boolean"    // True if the channel should be force-muted
        },
        "modes": {
          "[cvarName]": "string"     // Mathematical operation: "absolute" (default), "floor", or "ceiling"
        }
      }
    ], // Default: [] (Sunwell Silencer injected if empty on login)
    // Tracks manually toggled presets and their exact activation timestamp.
    "activeManualPresets": {
      "[presetIndex]": "number" // Default: {} (GetTime() timestamp when toggled ON)
    }
  },

  // ---------------------------------------------------------
  // 8. VOICE CHANNEL SOFT-MUTE STATE
  // ---------------------------------------------------------
  // Voice Chat channels do not have hardware enable/disable CVars like the
  // standard sound channels. We implement a "soft mute" by zeroing the value
  // and caching the original. These are INTENTIONAL user state.
  "voice": {
    // Default: {}
    // Dynamic key pattern: "MuteState_" + voice channel CVar name
    // e.g., "MuteState_Voice_ChatVolume": boolean
    
    // Dynamic key pattern: "SavedVol_" + voice channel CVar name
    // Stores the pre-mute volume level (0-100 scale) so unmuting restores correctly.
    // e.g., "SavedVol_Voice_ChatVolume": number
  }
}
```

## Transient State (VS.session)

The following properties have been removed from the database and now live exclusively in the in-memory `VS.session` table:
- `layoutDirty`
- `originalVolumes`
- `originalMutes`

## Migration Contract (`Init.lua:Migrate_V1_to_V2`)

Any V1 keys remaining in the root namespace are aggressively routed into their V2 namespaces and `nil`'d out upon `PLAYER_LOGIN`. Legacy automation parameters from the pre-preset era (e.g., `fishingTargetMaster`, `enableFishingSFX`) are purged unconditionally during migration to ensure a clean V2 namespace. Additionally, any existing legacy presets will automatically have previously non-existent channels ("Sound_GameplaySFX", "Sound_PingVolume", "Sound_EncounterWarningsVolume") added to their `.ignored` lists as `true` to prevent accidental volume zeroing upon migration.

## Migration Contract (`Init.lua:Migrate_V2_to_V3`)

Ensures that all V2-compliant presets are upgraded with the mathematical limiting engine introduced in v3.1.0. All existing presets have an empty `.modes` table initialized. New installs receive the `modes` table via `DEFAULT_DB` or the "Sunwell Silencer" factory.

## Migration Contract (`Init.lua:Migrate_V3_to_V4`)

Initializes the `automation.persistedBaseline` and `automation.lastAppliedState` tables to support baseline volume preservation across sessions. This additive migration does not alter any existing user presets. On first run of V4, baseline state is transparently captured from current CVars to seed the new DB tracking maps.

## Migration Contract (`Init.lua:Migrate_V4_to_V5`)

Tears down the deprecated snapshot-based `manualToggleState` payload system in favor of the stateless, timestamp-based unified stack model. The `db.automation.manualToggleState` table is destroyed unconditionally. A new tracking map, `db.automation.activeManualPresets`, is initialized to persist session-to-session manual preset activation and stack order.

## Migration Contract (`Init.lua:Migrate_V5_to_V6`)

Adds the `automation.enableDeviceVolumes` flag to support per-hardware-output-device master volume tracking. For existing users upgrading to V6, this is set to `true` by default to preserve the legacy behavior of the addon, but can now be disabled via the Automation settings panel.

## Migration Contract (`Init.lua:Migrate_V6_to_V7`)

Adds the `showEmoteSounds` toggle to the `toggles` namespace and injects it into the `footerOrder` array for existing users. By default, this toggle is set to `false`, meaning it remains hidden from the main popup footer until manually enabled via the settings window.

## Migration Contract (`Init.lua:Migrate_V7_to_V8`)

Adds the `playSampleSound` and `playSampleSoundMinimap` booleans to the `toggles` namespace (default `false`), and the `sampleSound` and `sampleSoundMinimap` properties to the `appearance` namespace (default `856`) to support auditory feedback when sliders or the minimap icon are scrolled.

## Migration Contract (`Init.lua:Migrate_V8_to_V9`)

Adds the `appearance.volumeDisplayFormat` string enum (default `"percentage"`) to control how current volume values are rendered in the popup, minimap broker text, minimap tooltip, and preset editor sliders. Existing users retain percentage output until they choose a different format.

## Migration Contract (`Init.lua:Migrate_V9_to_V10`)

Injects default values for the new `minimap` customization fields (`iconScale`, `iconColor`, `useCustomTint`, `fadeInSpeed`, `fadeOutSpeed`, `minimalistClampMode`, `minimalistAngle`, `minimalistRadius`) introduced in v3.11.0 to support the extended minimalist minimap icon feature. Migrates any legacy `fadeSpeed` to the split `fadeInSpeed`/`fadeOutSpeed` fields.