-------------------------------------------------------------------------------
-- Core.lua
--
-- Addon bootstrapping, library retrieval, layout constants, lookup tables,
-- and shared helper functions.
--
-- This is the first addon file loaded (after libraries). It creates the
-- shared addon table that all other modules receive via the (...) varargs,
-- and exposes constants and utilities they depend on.
--
-- Author:  Sheldon Michaels
-- Version: 3.0.0
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
-- We initialize it as an empty table here so it exists on first load.
-- The true population of V2 schema defaults occurs during PLAYER_LOGIN in Init.lua.
VolumeSlidersMMDB = VolumeSlidersMMDB or {}

-------------------------------------------------------------------------------
-- Module-Level State
-------------------------------------------------------------------------------

-- The VS.session table houses all transient runtime state that should NEVER
-- be saved to the database (e.g., dynamic layout flags, automation caches).
VS.session = {
    layoutDirty = true,
    
    -- UNIFIED STATE STACK:
    -- baselineVolumes[channel] = user intended volume (0.0-1.0)
    baselineVolumes = {},
    -- baselineMutes[channel] = user intended enabled state ("0" or "1")
    baselineMutes = {},
    -- manualOverrides[channel] = true (preset should ignore this channel)
    manualOverrides = {},
    -- registry[type][id] = preset object (flattened during evaluation)
    activeRegistry = {},
    -- Semaphore to prevent recursive infinite loops in CVAR_UPDATE handler.
    isSettingInternal = false,

    -- [DEPRECATED] To be removed in v3.1.0/Cleanup Phase
    originalVolumes = {},
    originalMutes = {},
}

-------------------------------------------------------------------------------
-- Module-Level State
-------------------------------------------------------------------------------

-- Reference to the broker frame that was most recently clicked (used to
-- anchor the popup relative to the broker icon's position on screen).
VS.brokerFrame = nil

-- Lookup table mapping CVar name â†’ slider widget.  Populated during
-- CreateOptionsFrame() and used to sync slider positions when CVars change
-- externally (e.g., via the Blizzard Sound settings panel).
VS.sliders = {}

-----------------------------------------
-- UI Layout Constants
--
-- These values define the dimensions and spacing of the popup frame and its
-- child elements. They are used to compute the overall frame size so that
-- changes to slider count or spacing automatically propagate.
-----------------------------------------

-- Insets of the SettingsFrameTemplate's NineSlice border. Content is placed
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

-- (VS.CVAR_TO_VAR removed: V2 schema natively maps channels securely into db.channels)

-- Maps each volume CVar to its corresponding enable/disable CVar.
-- Used by Presets.lua to apply per-channel mute overrides.
-- Voice Chat channels are excluded (they use a DB-backed soft-mute system).
VS.CHANNEL_MUTE_CVAR = {
    ["Sound_MasterVolume"]            = "Sound_EnableAllSound",
    ["Sound_SFXVolume"]               = "Sound_EnableSFX",
    ["Sound_MusicVolume"]             = "Sound_EnableMusic",
    ["Sound_AmbienceVolume"]          = "Sound_EnableAmbience",
    ["Sound_DialogVolume"]            = "Sound_EnableDialog",
    ["Sound_EncounterWarningsVolume"] = "Sound_EnableEncounterWarningsSounds",
    ["Sound_GameplaySFX"]             = "Sound_EnableGameplaySFX",
    ["Sound_PingVolume"]              = "Sound_EnablePingSounds",
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

-------------------------------------------------------------------------------
-- V2 Database Schema Defaults
-------------------------------------------------------------------------------
VS.DEFAULT_DB = {
    schemaVersion = 3,
    
    appearance = {
        bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 },
        knobStyle = "Diamond",
        arrowStyle = "GoldPlusMinus",
        titleColor = "White",
        valueColor = "Gold",
        highColor = "White",
        lowColor = "White",
        windowWidth = VS.DEFAULT_WINDOW_WIDTH,
        windowHeight = VS.DEFAULT_WINDOW_HEIGHT,
    },
    
    layout = {
        maxFooterCols = 3,
        limitFooterCols = true,
        sliderOrder = {}, -- Populated deeply below
        footerOrder = {}, -- Populated deeply below
        customX = nil,
        customY = nil,
        mouseActions = { sliders = {}, scrollWheel = {} },
    },
    
    toggles = {
        showTitle = true,
        showValue = true,
        showHigh = false,
        showUpArrow = true,
        showSlider = true,
        showDownArrow = true,
        showLow = false,
        showMute = true,
        showWarnings = true,
        showBackground = true,
        showCharacter = true,
        showOutput = true,
        showPresetsDropdown = true,
        showLfgPop = true,
        showZoneTriggers = true,
        showFishingSplash = true,
        showHelpText = true,
        showMinimapTooltip = true,
        showVoiceMode = true,
        persistentWindow = false,
        isLocked = false,
    },
    
    channels = {
        ["Sound_MasterVolume"] = true,
        ["Sound_SFXVolume"] = true,
        ["Sound_MusicVolume"] = true,
        ["Sound_AmbienceVolume"] = true,
        ["Sound_DialogVolume"] = true,
        ["Sound_GameplaySFX"] = false,
        ["Sound_PingVolume"] = false,
        ["Sound_EncounterWarningsVolume"] = false,
        ["Voice_ChatVolume"] = false,
        ["Voice_ChatDucking"] = false,
        ["Voice_MicVolume"] = false,
        ["Voice_MicSensitivity"] = false,
    },
    
    minimap = {
        minimapPos = 180,
        hide = false,
        minimalistMinimap = nil, -- Smart auto-detect on first boot
        bindToMinimap = true,
        minimalistOffsetX = -35,
        minimalistOffsetY = -5,
        minimapIconLocked = true,
        mouseActions = {
            { trigger = "None+Scroll", effect = "SCROLL_VOLUME", stringTarget = "Sound_MasterVolume", numStep = 0.05 }
        },
        minimapTooltipOrder = {
            { type = "OutputDevice" },
            { type = "MouseActions" },
            { type = "ChannelVolume", channel = "Sound_MasterVolume" },
            { type = "ActivePresets" }
        },
    },
    
    hardware = {
        deviceVolumes = {},
    },
    
    automation = {
        presets = {},
        manualToggleState = {},
        enableTriggers = true,
        enableFishingVolume = true,
        enableLfgVolume = true,
    },
    
    voice = {},
}

local function copyArray(arr)
    local newArr = {}
    for i, v in ipairs(arr) do newArr[i] = v end
    return newArr
end
VS.DEFAULT_DB.layout.sliderOrder = copyArray(VS.DEFAULT_CVAR_ORDER)
VS.DEFAULT_DB.layout.footerOrder = copyArray(VS.DEFAULT_FOOTER_ORDER)

-----------------------------------------
-- Helper Functions
-----------------------------------------

--- Read the current master volume from the CVar.
-- @return number In the range [0, 1]. Falls back to 1 (full volume) if the CVar is missing or unparseable.
function VS:GetMasterVolume()
    local volStr = GetCVar("Sound_MasterVolume") or "1"
    return tonumber(volStr) or 1
end

--- Return a human-readable percentage string for the current master volume.
-- @return string Example: "75%"
function VS:GetVolumeText()
    local vol = self:GetMasterVolume()
    vol = vol * 100
    return tostring(math_floor(vol + 0.5)) .. "%"
end

--- Adjust a volume channel by one increment in the given direction.
-- @param delta number Positive = volume up, negative = volume down.
-- @param customStep? number Optional. Force a specific increment.
-- @param cvar? string Optional. The audio channel CVar to adjust. Defaults to "Sound_MasterVolume".
function VS:AdjustVolume(delta, customStep, cvar)
    local targetCVar = cvar or "Sound_MasterVolume"
    local increment = customStep
    
    local volStr = GetCVar(targetCVar) or "1"
    local current = tonumber(volStr) or 1

    -- Logic: If no custom step is provided, use dynamic increments based on volume level and modifiers.
    if not increment then
        increment = 0.05
        -- User Experience: Use a finer step (1%) at low volumes to allow precise adjustment.
        if current < 0.2 then
            increment = 0.01
        end
        -- Modifier: Force fine adjustment if Control is held.
        if IsControlKeyDown() then
            increment = 0.01
        end
    end

    -- Apply the delta direction.
    if delta > 0 then
        current = current + increment
    else
        current = current - increment
    end

    -- Safety: Clamp to the valid [0, 1] range and persist to global WoW CVars.
    current = math_max(0, math_min(1, current))
    SetCVar(targetCVar, current)

    -- Broker Sync: Update the DataBroker text ONLY if we adjusted the Master Volume.
    if targetCVar == "Sound_MasterVolume" and VS.VolumeSlidersObject then
        VS.VolumeSlidersObject.text = self:GetVolumeText()
    end

    -- UI Sync: If the popup panel is open, push the new value into the specific slider widget.
    if VS.sliders and VS.sliders[targetCVar] then
         local sliderVal = 1 - current
         VS.sliders[targetCVar]:SetValue(sliderVal)
         VS.sliders[targetCVar].valueText:SetText(math_floor(current * 100 + 0.5) .. "%")
    end

    -- Unified State Sync: Keep the baseline informed of manual user adjustments.
    self:SyncBaseline(targetCVar, current)
end

--- Centralized dispatcher for synchronizing the volume baseline and manual overrides.
-- @param channel string CVar name or Voice Chat identifier.
-- @param value number|string New volume level (0.0-1.0) OR mute state ("0"/"1").
function VS:SyncBaseline(channel, value)
    local sess = self.session
    local targetChannel = channel
    local isMuteCVar = false

    -- Check if this is a mute CVar and map it back to the parent channel
    for volChan, muteChan in pairs(self.CHANNEL_MUTE_CVAR) do
        if muteChan == channel then
            targetChannel = volChan
            isMuteCVar = true
            break
        end
    end

    if isMuteCVar then
        sess.baselineMutes[targetChannel] = value
    else
        sess.baselineVolumes[targetChannel] = tonumber(value) or 1
    end

    -- If any presets are active, this user action constitutes a "Manual Override" 
    local anyActive = false
    for _, typeTable in pairs(sess.activeRegistry) do
        for _, _ in pairs(typeTable) do
            anyActive = true
            break
        end
        if anyActive then break end
    end

    if anyActive then
        sess.manualOverrides[targetChannel] = true
    end

    -- Trigger re-evaluation of the entire stack to merge this new baseline.
    if VS.Presets and VS.Presets.EvaluateAllPresets then
        VS.Presets:EvaluateAllPresets()
    end
end

--- Toggle the master mute state by flipping the Sound_EnableAllSound CVar.
-- Also updates the minimap icon texture and the Master slider's mute checkbox.
function VS:VolumeSliders_ToggleMute()
    local soundEnabled = GetCVar("Sound_EnableAllSound")
    if soundEnabled == "1" then
        SetCVar("Sound_EnableAllSound", 0)
    else
        SetCVar("Sound_EnableAllSound", 1)
    end
    VS:UpdateMiniMapVolumeIcon()

    -- UI Sync: Update the checkbox state in the popup frame if visible.
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

--- Set a texture to display a Blizzard atlas rotated 90Â° clockwise.
---
--- Blizzard's slider atlas assets are designed for horizontal use.  This
--- addon repurposes them for vertical sliders by rotating the texture
--- coordinates.  The function:
---   1. Retrieves the atlas sub-region from the master texture.
---   2. Remaps the four UV corners so the image renders rotated 90Â° CW.
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

    -- Apply the atlas texture file, then remap UVs for a 90Â° CW rotation.
    tex:SetTexture(info.file)
    tex:SetTexCoord(
        L, B,   -- Upper-left  â† original Bottom-left
        R, B,   -- Upper-right â† original Bottom-right
        L, T,   -- Lower-left  â† original Top-left
        R, T    -- Lower-right â† original Top-right
    )

    -- Swap dimensions: original width becomes height and vice-versa.
    tex:SetSize(info.height, info.width)
    return true
end

-----------------------------------------
-- Mouse Action Processors
-----------------------------------------

--- Construct a trigger string based on held modifiers and interaction type.
-- Used to match user inputs against the mouseActions database.
-- @param button? string The mouse button clicked (e.g., "LeftButton").
-- @param delta? number Optional scroll wheel delta.
-- @return string? The trigger string (e.g., "Shift+Scroll") or nil if no input found.
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
        return mods .. "Scroll"
    elseif button then
        return mods .. button
    end
    return nil
end

--- Process a mouse interaction on the minimap button.
-- @param triggerStr string The modifier+input string to look up.
-- @param clickedFrame Frame The frame that received the click (to anchor the popup).
-- @param delta? number Optional scroll wheel delta.
-- @return boolean True if an action was found and processed, false otherwise.
function VS:ProcessMinimapAction(triggerStr, clickedFrame, delta)
    local db = VolumeSlidersMMDB
    if not db.minimap.mouseActions then return false end

    for _, action in ipairs(db.minimap.mouseActions) do
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
                -- Reset the minimalist button to its default corner anchor.
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
            elseif eff == "SCROLL_VOLUME" then
                local channel = action.stringTarget or "Sound_MasterVolume"
                local step = action.numStep or 0.05
                if delta then
                    VS:AdjustVolume(delta, step, channel)
                end
            elseif eff == "TOGGLE_PRESET" then
                local idx = tonumber(action.stringTarget)
                if idx and db.automation.presets[idx] then
                    if VS.Presets and VS.Presets.TogglePreset then
                        VS.Presets:TogglePreset(db.automation.presets[idx], idx)
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                end
            end
            return true
        end
    end
    return false
end

--- Process a mouse action on a slider widget (excluding scroll).
-- @param triggerStr string The modifier+input string to look up.
-- @return number? The increment step if found, or nil.
function VS:ProcessSliderAction(triggerStr)
    local db = VolumeSlidersMMDB
    if not db.layout.mouseActions or not db.layout.mouseActions.sliders then return nil end

    for _, action in ipairs(db.layout.mouseActions.sliders) do
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

--- Process a scroll wheel action on a slider widget.
-- @param triggerStr string The modifier+input string to look up.
-- @return number? The increment step if found, or nil.
function VS:ProcessScrollAction(triggerStr)
    local db = VolumeSlidersMMDB
    if not db.layout.mouseActions or not db.layout.mouseActions.scrollWheel then return nil end

    for _, action in ipairs(db.layout.mouseActions.scrollWheel) do
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
--- Append descriptive lines to a GameTooltip based on custom mouse action bindings.
-- @param tooltip GameTooltip The tooltip object to append to.
-- @param elementKey "minimap"|"sliders"|"scrollWheel" The component being hovered.
-- @param defaultActions table List of {trigger, effectName} to display if not overridden.
-- @return boolean True if any lines were added, false otherwise.
function VS:AppendActionTooltipLines(tooltip, elementKey, defaultActions)
    local db = VolumeSlidersMMDB
    local customActions = {}
    if elementKey == "minimap" then
        customActions = db.minimap.mouseActions or {}
    elseif elementKey == "sliders" or elementKey == "scrollWheel" then
        customActions = (db.layout.mouseActions and db.layout.mouseActions[elementKey]) or {}
    end
    local overriddenTriggers = {}
    local added = false

    -- Internal helper to map internal effect codes to user-friendly strings.
    local function getEffectName(action, key)
        local eff = action.effect
        
        -- 1. Minimap-Specific Effects
        if key == "minimap" then
            if eff == "TOGGLE_WINDOW" then return "Toggle Slider Window" end
            if eff == "MUTE_MASTER" then return "Toggle Master Mute" end
            if eff == "OPEN_SETTINGS" then return "Open Settings Panel" end
            if eff == "RESET_POSITION" then return "Reset Window Position" end
            if eff == "TOGGLE_TRIGGERS" then return "Toggle Zone Triggers" end
            
            if eff == "TOGGLE_PRESET" then
                local idx = tonumber(action.stringTarget)
                if idx and db.automation.presets and db.automation.presets[idx] then
                    return "Toggle Preset: " .. (db.automation.presets[idx].name or "Unnamed")
                end
            end

            if eff == "SCROLL_VOLUME" then
                local chan = action.stringTarget or "Sound_MasterVolume"
                local step = (action.numStep or 0.05) * 100
                local niceNames = {
                    ["Sound_MasterVolume"] = "Master",
                    ["Sound_SFXVolume"] = "SFX",
                    ["Sound_MusicVolume"] = "Music",
                    ["Sound_AmbienceVolume"] = "Ambience",
                    ["Sound_DialogVolume"] = "Dialog",
                    ["Sound_GameplaySFX"] = "Gameplay",
                    ["Sound_PingVolume"] = "Pings",
                    ["Sound_EncounterWarningsVolume"] = "Warnings"
                }
                return string.format("Adjust %s (%d%%)", niceNames[chan] or "Volume", step)
            end
        end

        -- 2. Layout & Volume Adjustment Effects (shared across components)
        if eff == "ADJUST_1" then return "Change by 1%" end
        if eff == "ADJUST_5" then return "Change by 5%" end
        if eff == "ADJUST_10" then return "Change by 10%" end
        if eff == "ADJUST_15" then return "Change by 15%" end
        if eff == "ADJUST_20" then return "Change by 20%" end
        if eff == "ADJUST_25" then return "Change by 25%" end

        return "Unknown Action"
    end

    -- 1. Print all custom actions and record their triggers to block defaults.
    for _, action in ipairs(customActions) do
        if action.trigger and action.effect then
            tooltip:AddLine(string.format("|cff00ff00%s|r to %s", action.trigger, getEffectName(action, elementKey)))
            overriddenTriggers[action.trigger] = true
            added = true
        end
    end

    -- 2. Print default actions only if their specific trigger was not overridden by a custom one.
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
