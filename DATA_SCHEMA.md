# VolumeSliders Data Schema

**Database:** `VolumeSlidersMMDB`
**Scope:** Global / Account-wide
**Format:** Serialized Lua Table (Pseudo-JSON representation below)
**Last Audited:** 2026-03-30 (V2 Namespace Migration)

This document defines the exact shape of the saved variables used by Volume Sliders. It acts as the single source of truth for the data layer, distinguishing between user-configurable options, transient session states, and deprecated keys.

> **Contract:** Any agent modifying the boundaries of persisted configuration versus transient state MUST update this document. See `AGENTS.md` for enforcement details.

## Root Structure (V2 Schema)

As of version 2.17.0, the monolithic flat-key structure has been deprecated in favor of nested functional namespaces to optimize data bounding and Settings UI integration.

```json
{
  "schemaVersion": 2,

  // ---------------------------------------------------------
  // 1. APPEARANCE & WINDOW STYLING
  // ---------------------------------------------------------
  "appearance": {
    // Window Dimensions & Positioning
    "windowWidth": "number",  // Set when user resizes; nil = use VS.DEFAULT_WINDOW_WIDTH
    "windowHeight": "number", // Set when user resizes; nil = use VS.DEFAULT_WINDOW_HEIGHT
    "customX": "number",      // X coordinate for custom anchor (set when window is dragged)
    "customY": "number",      // Y coordinate for custom anchor (set when window is dragged)

    // Background Color
    "bgColor": {
      "r": "number", // Float 0.0 - 1.0
      "g": "number", // Float 0.0 - 1.0
      "b": "number", // Float 0.0 - 1.0
      "a": "number"  // Opacity (0.0 - 1.0)
    },

    // Widget Styling Enums
    "knobStyle": "string",  // Enum (e.g., "Diamond", "Silver")
    "arrowStyle": "string", // Enum (e.g., "GoldPlusMinus")
    "titleColor": "string", // Enum (e.g., "White", "Gold")
    "valueColor": "string", // Enum (e.g., "Gold")
    "highColor": "string",  // Enum (e.g., "White")
    "lowColor": "string"    // Enum (e.g., "White")
  },

  // ---------------------------------------------------------
  // 2. LAYOUT ORCHESTRATION & BINDINGS
  // ---------------------------------------------------------
  "layout": {
    // Structural Ordering
    "sliderOrder": ["string"], // Ordered array of CVar channel names
    "footerOrder": ["string"], // Ordered array of footer visibility keys
    
    // Layout Constraints
    "maxFooterCols": "number",    // Maximum items per footer row
    "limitFooterCols": "boolean", // Whether to enforce maxFooterCols

    // Defines what happens when clicking or scrolling on specific UI boundaries
    "mouseActions": {
      "sliders": [
        { 
          "trigger": "string",      // e.g., "LeftButton", "MiddleButton"
          "effect": "string",       // e.g., "ADJUST_5", "TOGGLE_WINDOW", "TOGGLE_PRESET"
          "stringTarget": "string", // [Optional] Target identifier (e.g., "Sound_MasterVolume" or "1" for Preset #1)
          "numStep": "number"       // [Optional] Numeric magnitude for adjustable effects (e.g., 0.05 for 5% scroll)
        }
      ],
      "scrollWheel": [
        { 
          "trigger": "string",      // e.g., "None", "Shift", "Ctrl"
          "effect": "string",       // e.g., "ADJUST_1", "SCROLL_VOLUME"
          "stringTarget": "string", 
          "numStep": "number"
        }
      ]
    }
  },

  // ---------------------------------------------------------
  // 3. TOGGLES & ELEMENT VISIBILITY
  // ---------------------------------------------------------
  "toggles": {
    // General Window State
    "persistentWindow": "boolean", // True if clicking outside doesn't close the menu
    "isLocked": "boolean",         // True if the main window cannot be moved

    // Widget Components (Parts of a single slider row)
    "showTitle": "boolean",
    "showValue": "boolean",
    "showHigh": "boolean",
    "showUpArrow": "boolean",
    "showSlider": "boolean",
    "showDownArrow": "boolean",
    "showLow": "boolean",
    "showMute": "boolean",
    
    // UI Elements (Parts of the main frame popup)
    "showWarnings": "boolean",
    "showBackground": "boolean",
    "showCharacter": "boolean",      // Shows the "Sound at Character" toggle
    "showOutput": "boolean",         // Shows output device dropdown
    "showPresetsDropdown": "boolean", // Shows quick-apply presets dropdown
    "showLfgPop": "boolean",         // Shows LFG Pop Boost toggle in footer
    "showZoneTriggers": "boolean",   // Shows Zone Triggers toggle in footer
    "showFishingSplash": "boolean",  // Shows Fishing Splash Boost toggle in footer
    "showHelpText": "boolean",       // Shows help instructions in header
    "showVoiceMode": "boolean"       // Shows Voice Chat Mode toggle in footer
  },

  // ---------------------------------------------------------
  // 4. CHANNELS (Visibility Configuration)
  // ---------------------------------------------------------
  // Determines which audio channels are rendered as sliders in the UI.
  "channels": {
    "Sound_MasterVolume": "boolean",
    "Sound_SFXVolume": "boolean",
    "Sound_MusicVolume": "boolean",
    "Sound_AmbienceVolume": "boolean",
    "Sound_DialogVolume": "boolean",
    "Sound_GameplaySFX": "boolean",
    "Sound_PingVolume": "boolean",
    "Sound_EncounterWarningsVolume": "boolean",
    "Voice_ChatVolume": "boolean",
    "Voice_ChatDucking": "boolean",
    "Voice_MicVolume": "boolean",
    "Voice_MicSensitivity": "boolean"
  },

  // ---------------------------------------------------------
  // 5. MINIMAP CONFIGURATION
  // ---------------------------------------------------------
  "minimap": {
    "minimapPos": "number",        // Radial degree placement (0-360), owned by LibDBIcon
    "hide": "boolean",             // Master visibility toggle for the addon icon
    "minimapIconLocked": "boolean",// Locks minimap icon dragging
    "bindToMinimap": "boolean",    // True if minimalist icon fades in on minimap hover
    "minimalistMinimap": "boolean",// Toggles custom minimalist speaker icon style (nil = auto-detect)
    "minimalistOffsetX": "number", // X offset for minimalist icon
    "minimalistOffsetY": "number", // Y offset for minimalist icon
    
    // Tooltip and Click Bindings specific to the Minimap Icon
    "showMinimapTooltip": "boolean", // Enables/disables minimap icon tooltip
    "minimapTooltipOrder": [
      {
        "type": "string",   // "ChannelVolume", "MouseActions", "OutputDevice", "ActivePresets"
        "channel": "string" // Optional: specific CVar if type is "ChannelVolume"
      }
    ],
    "minimapScrollBindings": {
      "None": "string",  // Maps to CVar (e.g., "Sound_MasterVolume") or "Disabled"
      "Shift": "string",
      "Ctrl": "string",
      "Alt": "string"
    },
    // Minimap-specific mouse click interactions.
    "mouseActions": [
      { 
        "trigger": "string", 
        "effect": "string",
        "stringTarget": "string",
        "numStep": "number"
      }
    ]
  },

  // ---------------------------------------------------------
  // 6. HARDWARE SPECIFICS
  // ---------------------------------------------------------
  "hardware": {
    // Stores preferred master volume per hardware output device name
    "deviceVolumes": {
      "[deviceName]": "number" // e.g., "Realtek Digital Output": 0.81
    }
  },

  // ---------------------------------------------------------
  // 7. AUTOMATION & PRESETS
  // ---------------------------------------------------------
  "automation": {
    "enableTriggers": "boolean",       // Master toggle for zone-triggered preset automation
    "enableFishingVolume": "boolean",  // Enables fishing splash boost automation
    "enableLfgVolume": "boolean",      // Enables LFG queue pop boost automation
    "fishingPresetIndex": "number",    // Index in `presets` array for the fishing automation profile
    "lfgPresetIndex": "number",        // Index in `presets` array for the LFG automation profile
    
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
        }
      }
    ],
    // Tracks the snapshot of pre-toggled channels for a given manual preset application.
    "manualToggleState": {
      "[presetIndex]": {
        "volumes": {
          "[cvarName]": "number"     // The original volume before the preset was toggled
        },
        "mutes": {
          "[cvarName]": "string"     // The original mute state ("0" or "1") before toggle
        }
      }
    }
  },

  // ---------------------------------------------------------
  // 8. VOICE CHANNEL SOFT-MUTE STATE
  // ---------------------------------------------------------
  // Voice Chat channels do not have hardware enable/disable CVars like the
  // standard sound channels. We implement a "soft mute" by zeroing the value
  // and caching the original. These are INTENTIONAL user state.
  "voice": {
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

Any V1 keys remaining in the root namespace are aggressively routed into their V2 namespaces and `nil`'d out upon `PLAYER_LOGIN`. Legacy automation parameters from the pre-preset era (e.g., `fishingTargetMaster`, `enableFishingSFX`) are purged unconditionally during migration to ensure a clean V2 namespace. Additionally, any existing legacy presets will automatically have previously non-existent channels ("Sound_GameplaySFX", "Sound_PingVolume", "Sound_EncounterWarningsVolume") added to their `.ignored` lists as `true` to prevent accidental volume zeroing upon migration to V2.