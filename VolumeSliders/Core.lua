-------------------------------------------------------------------------------
-- Core.lua
--
-- Addon bootstrapping, library retrieval, layout constants, lookup tables,
-- and shared helper functions.
--
-- This is the first addon file loaded (after libraries).  It creates the
-- shared addon table that all other modules receive via the (...) varargs,
-- and exposes constants and utilities they depend on.
--
-- Author:  Sheldon Michaels
-- Version: 2.0.0
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Localized Globals (Optimization 2)
--
-- Caching frequently-used Lua and WoW globals as file-scope locals avoids
-- repeated _G table lookups on every call.
-------------------------------------------------------------------------------
local math_floor = math.floor
local math_max   = math.max
local math_min   = math.min
local math_ceil  = math.ceil
local tonumber   = tonumber
local tostring   = tostring
local pairs      = pairs
local ipairs     = ipairs
local GetCVar    = GetCVar
local SetCVar    = SetCVar

-------------------------------------------------------------------------------
-- Addon Bootstrapping
-------------------------------------------------------------------------------

-- The vararg (...) passed to every addon file is (addonName, addonTable).
-- WoW provides the same addonTable to every file listed in the TOC, making
-- it the standard mechanism for sharing state across modules.
local _addonName, VS = ...

-- Retrieve broker libraries used for minimap icon and data-broker display.
VS.LDB     = LibStub("LibDataBroker-1.1", true)
VS.LDBIcon = LibStub("LibDBIcon-1.0", true)

-- Setup Global Binding Strings
_G.BINDING_HEADER_VOLUMESLIDERS = "Volume Sliders"
_G.BINDING_NAME_VOLUMESLIDERS_TOGGLE = "Toggle Volume Sliders Window"
_G.BINDING_NAME_VOLUMESLIDERS_MUTE_MASTER = "Toggle Master Mute"

-------------------------------------------------------------------------------
-- Saved Variables
-------------------------------------------------------------------------------

-- VolumeSlidersMMDB is declared as a SavedVariable in the TOC file.
-- LibDBIcon stores the minimap button's angular position and visibility flag
-- inside this table.  We initialize it here so it exists on first load.
VolumeSlidersMMDB = VolumeSlidersMMDB or {
    minimapPos   = 180,   -- Degrees around the minimap (0 = top, 180 = bottom)
    hide         = false, -- Whether the minimap button is hidden
    minimalistMinimap = nil, -- Smart auto-detect if nil
    bindToMinimap     = true,
    minimalistOffsetX = -35, -- Default X offset for minimalist drag
    minimalistOffsetY = -5,  -- Default Y offset for minimalist drag
    enableTriggers    = true,-- Global master toggle for zone triggers
}

-------------------------------------------------------------------------------
-- Module-Level State
-------------------------------------------------------------------------------

-- Reference to the broker frame that was most recently clicked (used to
-- anchor the popup relative to the broker icon's position on screen).
VS.brokerFrame = nil

-- Lookup table mapping CVar name → slider widget.  Populated during
-- CreateOptionsFrame() and used to sync slider positions when CVars change
-- externally (e.g., via the Blizzard Sound settings panel).
VS.sliders = {}

-----------------------------------------
-- Layout Constants
--
-- These values define the dimensions and spacing of the popup frame and its
-- child elements.  They are used to compute the overall frame size so that
-- changes to slider count or spacing automatically propagate.
-----------------------------------------

-- Insets of the SettingsFrameTemplate's NineSlice border.  Content is placed
-- inside these margins to avoid overlapping the frame's decorative edges.
VS.TEMPLATE_CONTENT_OFFSET_LEFT   = 7
VS.TEMPLATE_CONTENT_OFFSET_RIGHT  = 3
VS.TEMPLATE_CONTENT_OFFSET_TOP    = 18
VS.TEMPLATE_CONTENT_OFFSET_BOTTOM = 3

-- Each slider occupies a column of this width.
VS.SLIDER_COLUMN_WIDTH = 60

-- Padding around the content area inside the NineSlice border.
VS.CONTENT_PADDING_X      = 20
VS.SLIDER_PADDING_X       = 10  -- Tighter inset for slider columns only
VS.CONTENT_PADDING_TOP    = 15
VS.CONTENT_PADDING_BOTTOM = 15

-- Resize constraints — floors for dynamic layout during window resize.
VS.MIN_SLIDER_SPACING_TITLED   = -5   -- Floor when titles are shown (wider columns)
VS.MIN_SLIDER_SPACING_UNTITLED = -20  -- Floor when titles are hidden (narrower columns)
VS.MIN_SLIDER_TRACK_HEIGHT = 60  -- Minimum px for slider track height
VS.RESIZE_HANDLE_THICKNESS = 6   -- Edge handle hit area width/height

-- Default window dimensions (initial size before user resizes).
VS.DEFAULT_WINDOW_WIDTH  = 375
VS.DEFAULT_WINDOW_HEIGHT = 440

-----------------------------------------
-- Lookup Tables
-----------------------------------------

-- Maps sound CVar names to their corresponding visibility flag key in
-- VolumeSlidersMMDB.  Used by UpdateAppearance() to determine which sliders
-- to show based on user settings.
VS.CVAR_TO_VAR = {
    ["Sound_MasterVolume"]          = "showMaster",
    ["Sound_SFXVolume"]             = "showSFX",
    ["Sound_MusicVolume"]           = "showMusic",
    ["Sound_AmbienceVolume"]        = "showAmbience",
    ["Sound_DialogVolume"]          = "showDialog",
    ["Sound_GameplaySFX"]           = "showGameplay",
    ["Sound_PingVolume"]            = "showPings",
    ["Sound_EncounterWarningsVolume"] = "showWarnings",
    ["Voice_ChatVolume"]            = "showVoiceChat",
    ["Voice_ChatDucking"]           = "showVoiceDucking",
    ["Voice_MicVolume"]             = "showMicVolume",
    ["Voice_MicSensitivity"]        = "showMicSensitivity",
}

-- Default ordering of sliders in the popup panel.  Saved to the user's
-- database on first load and persisted across sessions.
VS.DEFAULT_CVAR_ORDER = {
    "Sound_MasterVolume",
    "Sound_SFXVolume",
    "Sound_MusicVolume",
    "Sound_AmbienceVolume",
    "Sound_DialogVolume",
    "Sound_GameplaySFX",
    "Sound_PingVolume",
    "Sound_EncounterWarningsVolume",
    "Voice_ChatVolume",
    "Voice_ChatDucking",
    "Voice_MicVolume",
    "Voice_MicSensitivity",
}

-- Default ordering of footer elements in the popup panel.
VS.DEFAULT_FOOTER_ORDER = {
    "showZoneTriggers",
    "showFishingSplash",
    "showLfgPop",
    "showCharacter",
    "showBackground",
    "showOutput",
    "showVoiceMode",
}

-----------------------------------------
-- Helper Functions
-----------------------------------------

--- Read the current master volume from the CVar and return it as a number
--- in the range [0, 1].  Falls back to 1 (full volume) if the CVar is
--- missing or unparseable.
function VS:GetMasterVolume()
    local volStr = GetCVar("Sound_MasterVolume") or "1"
    return tonumber(volStr) or 1
end

--- Return a human-readable percentage string for the current master volume.
--- Example: "75%"
function VS:GetVolumeText()
    local vol = self:GetMasterVolume()
    vol = vol * 100
    return tostring(math_floor(vol + 0.5)) .. "%"
end

--- Adjust the master volume by one increment in the given direction.
--- @param delta  number  Positive = volume up, negative = volume down.
---
--- The default step is 5% (0.05).  When the volume is below 20%, the step
--- shrinks to 1% for finer control at low levels.  Holding Ctrl also forces
--- the 1% step regardless of current level.
function VS:AdjustVolume(delta)
    local increment = 0.05
    local current = self:GetMasterVolume()

    -- Use a finer step at low volumes or when Ctrl is held.
    if current < 0.2 then
        increment = 0.01
    end
    if IsControlKeyDown() then
        increment = 0.01
    end

    -- Apply the delta direction.
    if delta > 0 then
        current = current + increment
    else
        current = current - increment
    end

    -- Clamp to the valid [0, 1] range and persist.
    current = math_max(0, math_min(1, current))
    SetCVar("Sound_MasterVolume", current)

    -- Update the broker text (the percentage shown on the LDB display).
    if VS.VolumeSlidersObject then
        VS.VolumeSlidersObject.text = self:GetVolumeText()
    end

    -- If the slider panel is open, sync the Master slider to the new value.
    -- Note: sliders use *inverted* values (0 at top = max volume, 1 at
    -- bottom = min volume) so we set `1 - current`.
    if VS.sliders and VS.sliders["Sound_MasterVolume"] then
         local sliderVal = 1 - current
         VS.sliders["Sound_MasterVolume"]:SetValue(sliderVal)
         VS.sliders["Sound_MasterVolume"].valueText:SetText(math_floor(current * 100 + 0.5) .. "%")
    end
end

--- Toggle the master mute state by flipping the Sound_EnableAllSound CVar.
--- Also updates the minimap icon texture and the Master slider's mute
--- checkbox if the panel is open.
function VS:VolumeSliders_ToggleMute()
    local soundEnabled = GetCVar("Sound_EnableAllSound")
    if soundEnabled == "1" then
        SetCVar("Sound_EnableAllSound", 0)
    else
        SetCVar("Sound_EnableAllSound", 1)
    end
    VS:UpdateMiniMapVolumeIcon()

    -- Sync the Master slider's mute checkbox if the panel is visible.
    if VS.sliders and VS.sliders["Sound_MasterVolume"] and VS.sliders["Sound_MasterVolume"].muteCheck then
        local isEnabled = GetCVar("Sound_EnableAllSound") == "1"
        VS.sliders["Sound_MasterVolume"].muteCheck:SetChecked(not isEnabled)
    end
end

-----------------------------------------
-- UI Utility Functions
-----------------------------------------

--- Safely identifies "secret" or protected values introduced in the Midnight (13.x) expansion.
--- Addons cannot directly compare or manipulate these values in an unprotected context.
--- @param value any The value to check.
--- @return boolean True if the value is "secret", false otherwise.
function VS:IsSecret(value)
    if issecretvalue then
        return issecretvalue(value)
    end
    return false
end

--- Disable the HoverBackgroundTemplate that ships with SettingsCheckboxTemplate.
---
--- The template anchors a white overlay texture to $parent.$parent (the
--- grandparent frame), which causes the entire popup background to flash
--- white when the cursor enters any checkbox.  We hide that overlay and
--- clear the enter/leave scripts that toggle it.
---
--- @param check  CheckButton  The checkbox frame to patch.
function VS:DisableCheckboxHoverBackground(check)
    if check.HoverBackground then
        check.HoverBackground:Hide()
        check.HoverBackground:SetParent(nil)
    end
    check:SetScript("OnEnter", nil)
    check:SetScript("OnLeave", nil)
end

--- Set a texture to display a Blizzard atlas rotated 90° clockwise.
---
--- Blizzard's slider atlas assets are designed for horizontal use.  This
--- addon repurposes them for vertical sliders by rotating the texture
--- coordinates.  The function:
---   1. Retrieves the atlas sub-region from the master texture.
---   2. Remaps the four UV corners so the image renders rotated 90° CW.
---   3. Swaps width/height so the rotated piece has the correct dimensions.
---
--- @param tex        Texture   The texture object to modify.
--- @param atlasName  string    Blizzard atlas identifier (e.g., "Minimal_SliderBar_Left").
--- @return boolean   true on success, false if the atlas was not found.
function VS:SetAtlasRotated90CW(tex, atlasName)
    local info = C_Texture.GetAtlasInfo(atlasName)
    if not info then return false end

    -- Atlas sub-region corners in normalized texture-space.
    local L, R = info.leftTexCoord, info.rightTexCoord
    local T, B = info.topTexCoord, info.bottomTexCoord

    -- Apply the atlas texture file, then remap UVs for a 90° CW rotation.
    tex:SetTexture(info.file)
    tex:SetTexCoord(
        L, B,   -- Upper-left  ← original Bottom-left
        R, B,   -- Upper-right ← original Bottom-right
        L, T,   -- Lower-left  ← original Top-left
        R, T    -- Lower-right ← original Top-right
    )

    -- Swap dimensions: original width becomes height and vice-versa.
    tex:SetSize(info.height, info.width)
    return true
end

-----------------------------------------
-- Mouse Action Processors
-----------------------------------------

function VS:GetActiveTriggerString(button, delta)
    local isShift = IsShiftKeyDown()
    local isCtrl = IsControlKeyDown()
    local isAlt = IsAltKeyDown()
    
    local mods = ""
    if isShift and isCtrl and isAlt then mods = "Shift+Ctrl+Alt+"
    elseif isShift and isCtrl then mods = "Shift+Ctrl+"
    elseif isShift and isAlt then mods = "Shift+Alt+"
    elseif isCtrl and isAlt then mods = "Ctrl+Alt+"
    elseif isShift then mods = "Shift+"
    elseif isCtrl then mods = "Ctrl+"
    elseif isAlt then mods = "Alt+"
    end
    
    if delta then
        return mods .. (delta > 0 and "WheelUp" or "WheelDown")
    elseif button then
        return mods .. button
    end
    return nil
end

function VS:ProcessMinimapAction(triggerStr, clickedFrame)
    local db = VolumeSlidersMMDB
    if not db.mouseActions or not db.mouseActions.minimap then return false end
    
    for _, action in ipairs(db.mouseActions.minimap) do
        if action.trigger == triggerStr and action.effect then
            local eff = action.effect
            if eff == "TOGGLE_WINDOW" then
                VS.brokerFrame = clickedFrame
                VolumeSliders_ToggleWindow()
            elseif eff == "MUTE_MASTER" then
                VolumeSliders_ToggleMuteMaster()
            elseif eff == "OPEN_SETTINGS" then
                if VS.settingsCategory and VS.settingsCategory.ID then
                    Settings.OpenToCategory(VS.settingsCategory.ID)
                else
                    Settings.OpenToCategory("Volume Sliders")
                end
            elseif eff == "RESET_POSITION" then
                VolumeSlidersMMDB.minimalistOffsetX = -35
                VolumeSlidersMMDB.minimalistOffsetY = -5
                if VS.minimalistButton then
                    VS.minimalistButton:ClearAllPoints()
                    VS.minimalistButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -35, -5)
                end
            elseif eff == "TOGGLE_TRIGGERS" then
                VolumeSlidersMMDB.enableTriggers = not VolumeSlidersMMDB.enableTriggers
                if VS.Presets and VS.Presets.RefreshEventState then VS.Presets:RefreshEventState() end
                if VS.triggerCheck then VS.triggerCheck:SetChecked(VolumeSlidersMMDB.enableTriggers) end
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            elseif string.match(eff, "^PRESET_") then
                local idx = tonumber(string.match(eff, "%d+"))
                if idx and db.presets[idx] then
                    if VS.Presets and VS.Presets.ApplyPreset then
                        VS.Presets:ApplyPreset(db.presets[idx])
                        if VS.sliders then
                            for _, slider in pairs(VS.sliders) do
                                if slider.RefreshValue then slider:RefreshValue() end
                            end
                        end
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                end
            end
            return true
        end
    end
    return false
end

function VS:ProcessSliderAction(triggerStr)
    local db = VolumeSlidersMMDB
    if not db.mouseActions or not db.mouseActions.sliders then return nil end
    
    for _, action in ipairs(db.mouseActions.sliders) do
        if action.trigger == triggerStr and action.effect then
            local eff = action.effect
            if eff == "ADJUST_1" then return 0.01 end
            if eff == "ADJUST_5" then return 0.05 end
            if eff == "ADJUST_10" then return 0.10 end
            if eff == "ADJUST_15" then return 0.15 end
            if eff == "ADJUST_20" then return 0.20 end
            if eff == "ADJUST_25" then return 0.25 end
        end
    end
    return nil
end

function VS:ProcessScrollAction(triggerStr)
    local db = VolumeSlidersMMDB
    if not db.mouseActions or not db.mouseActions.scrollWheel then return nil end
    
    for _, action in ipairs(db.mouseActions.scrollWheel) do
        if action.trigger == triggerStr and action.effect then
            local eff = action.effect
            if eff == "ADJUST_1" then return 0.01
            elseif eff == "ADJUST_5" then return 0.05
            elseif eff == "ADJUST_10" then return 0.10
            elseif eff == "ADJUST_15" then return 0.15
            elseif eff == "ADJUST_20" then return 0.20
            elseif eff == "ADJUST_25" then return 0.25
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Dynamic Tooltip Helper
-------------------------------------------------------------------------------
function VS:AppendActionTooltipLines(tooltip, elementKey, defaultActions)
    local db = VolumeSlidersMMDB
    local customActions = (db.mouseActions and db.mouseActions[elementKey]) or {}
    local overriddenTriggers = {}
    local added = false

    local function getEffectName(eff, key)
        if key == "minimap" then
            if eff == "TOGGLE_WINDOW" then return "Toggle Slider Window" end
            if eff == "MUTE_MASTER" then return "Toggle Master Mute" end
            if eff == "OPEN_SETTINGS" then return "Open Settings Panel" end
            if eff == "RESET_POSITION" then return "Reset Window Position" end
            if eff == "TOGGLE_TRIGGERS" then return "Toggle Zone Triggers" end
        elseif key == "sliders" then
            if eff == "ADJUST_1" then return "Change by 1%" end
            if eff == "ADJUST_5" then return "Change by 5%" end
            if eff == "ADJUST_10" then return "Change by 10%" end
            if eff == "ADJUST_15" then return "Change by 15%" end
            if eff == "ADJUST_20" then return "Change by 20%" end
            if eff == "ADJUST_25" then return "Change by 25%" end
        end
        if string.match(eff, "^PRESET_") then
            local idx = tonumber(string.match(eff, "%d+"))
            if idx and db.presets and db.presets[idx] then
                return "Apply Preset: " .. db.presets[idx].name
            end
        end
        return "Unknown Action"
    end

    -- 1. Print all custom actions and record their triggers
    for _, action in ipairs(customActions) do
        if action.trigger and action.effect then
            tooltip:AddLine(string.format("|cff00ff00%s|r to %s", action.trigger, getEffectName(action.effect, elementKey)))
            overriddenTriggers[action.trigger] = true
            added = true
        end
    end

    -- 2. Print default actions if their trigger wasn't overridden
    if defaultActions then
        for _, def in ipairs(defaultActions) do
            if not overriddenTriggers[def.trigger] then
                tooltip:AddLine(string.format("|cff00ff00%s|r to %s", def.trigger, def.effectName))
                added = true
            end
        end
    end

    return added
end
