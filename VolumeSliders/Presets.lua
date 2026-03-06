-------------------------------------------------------------------------------
-- Presets.lua
--
-- Logic for Automation Presets (formerly Zone Triggers). Registers for zone 
-- change events, evaluates presets by priority, and dynamically adjusts 
-- volume levels. Uses O(1) zone lookups and unregisters events when 
-- automation is disabled.
--
-- Author: Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-- Expose a central table for preset logic and state
VS.Presets = {}

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local GetRealZoneText = GetRealZoneText
local GetSubZoneText = GetSubZoneText
local GetMinimapZoneText = GetMinimapZoneText
local GetCVar = GetCVar
local SetCVar = SetCVar
local pairs = pairs
local ipairs = ipairs
local type = type
local table_sort = table.sort
local string_lower = string.lower

-------------------------------------------------------------------------------
-- Module State
-------------------------------------------------------------------------------

-- Frame for listening to zone transitions.
local presetFrame = CreateFrame("Frame")

-- Lookup table for O(1) matching: activeZones[lowerZoneName] = {presetIndex1, presetIndex2, ...}
local activeZones = {}
-- Maintain a list of original CVars before they were overridden by presets.
-- originalVolumes[channel] = originalValue
VolumeSlidersMMDB.originalVolumes = VolumeSlidersMMDB.originalVolumes or {}

-------------------------------------------------------------------------------
-- Logic Implementation
-------------------------------------------------------------------------------

--- Sort function for presets based on priority. High priority applies last (overwrites).
local function SortPresetsByPriority(a, b)
    local pA = a.priority or 0
    local pB = b.priority or 0
    return pA < pB
end

--- Apply a list of active automation presets to the game state.
-- Restores unmodified channels to their original values.
local function ApplyAutomationPresets(activePresetList)
    local db = VolumeSlidersMMDB
    
    -- We want to track which channels are currently overridden so we can restore the rest
    local overriddenChannels = {}
    local finalVolumes = {}

    -- Apply presets in priority ascending order
    table_sort(activePresetList, SortPresetsByPriority)

    for _, preset in ipairs(activePresetList) do
        for channel, vol in pairs(preset.volumes) do
            -- Ignore specific channels in a preset if they are marked ignored
            if not preset.ignored or not preset.ignored[channel] then
                finalVolumes[channel] = vol
                overriddenChannels[channel] = true
            end
        end
    end

    -- Known valid channels from CVAR_TO_VAR mapping
    for channel, _ in pairs(VS.CVAR_TO_VAR) do
        if overriddenChannels[channel] then
            -- We need to apply an override
            local currentCVarVol = tonumber(GetCVar(channel)) or 1
            -- Save the original volume ONLY IF it hasn't already been saved
            if not db.originalVolumes[channel] then
                db.originalVolumes[channel] = currentCVarVol
            end
            
            local wantVol = finalVolumes[channel]
            if currentCVarVol ~= wantVol then
                SetCVar(channel, wantVol)
            end
        else
            -- No active preset is overriding this channel. Restore if it was overridden previously.
            if db.originalVolumes[channel] then
                local restoreVol = db.originalVolumes[channel]
                local currentCVarVol = tonumber(GetCVar(channel)) or 1
                if currentCVarVol ~= restoreVol then
                    SetCVar(channel, restoreVol)
                end
                -- Clear original since we restored it
                db.originalVolumes[channel] = nil
            end
        end
    end

    -- Refresh slider UI if open
    if VS.sliders then
        for channel, slider in pairs(VS.sliders) do
            if slider.RefreshValue then
                slider:RefreshValue()
            end
        end
    end
    -- Refresh LDB object if master volume changed
    if VS.VolumeSlidersObject then
        VS.VolumeSlidersObject.text = VS:GetVolumeText()
    end
end

--- Applies a single preset immediately (called from quick dropdown)
-- Does NOT modify originalVolumes (so it's permanent until changed again).
function VS.Presets:ApplyPreset(preset)
    if not preset or type(preset.volumes) ~= "table" then return end
    
    local changed = false
    for channel, vol in pairs(preset.volumes) do
        if not preset.ignored or not preset.ignored[channel] then
            local currentCVarVol = tonumber(GetCVar(channel)) or 1
            if currentCVarVol ~= vol then
                SetCVar(channel, vol)
                changed = true
            end
        end
    end

    -- Update UI if anything changed
    if changed then
        if VS.sliders then
            for channel, slider in pairs(VS.sliders) do
                if slider.RefreshValue then
                    slider:RefreshValue()
                end
            end
        end
        if VS.VolumeSlidersObject then
            VS.VolumeSlidersObject.text = VS:GetVolumeText()
        end
    end
end

--- Event handler for all registered zone/login events.
local function OnPresetEvent()
    local db = VolumeSlidersMMDB
    -- "enableTriggers" is still the DB key for the Automation (Zone Triggers) feature toggle
    if not db.enableTriggers or not db.presets or #db.presets == 0 then return end

    local realZone = GetRealZoneText() and string_lower(GetRealZoneText()) or ""
    local subZone = GetSubZoneText() and string_lower(GetSubZoneText()) or ""
    local miniZone = GetMinimapZoneText() and string_lower(GetMinimapZoneText()) or ""

    -- Guard against "secret" values introduced in Midnight (13.x)
    if VS:IsSecret(realZone) or VS:IsSecret(subZone) or VS:IsSecret(miniZone) then return end

    local matchedPresets = {}
    local matchedPresetIndices = {} -- deduplication map

    -- Helper to safely add matched presets
    local function AddMatchedPresets(zoneStr)
        local ids = activeZones[zoneStr]
        if ids then
            for _, id in ipairs(ids) do
                if not matchedPresetIndices[id] then
                    matchedPresetIndices[id] = true
                    table.insert(matchedPresets, db.presets[id])
                end
            end
        end
    end

    AddMatchedPresets(realZone)
    AddMatchedPresets(subZone)
    AddMatchedPresets(miniZone)

    ApplyAutomationPresets(matchedPresets)
end

presetFrame:SetScript("OnEvent", OnPresetEvent)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Rebuilds the O(1) zone lookup table and registers/unregisters events based
-- on load-on-demand principles to guarantee zero CPU drag when idle.
function VS.Presets:RefreshEventState()
    local db = VolumeSlidersMMDB
    
    -- Ensure required tables exist
    db.originalVolumes = db.originalVolumes or {}
    db.presets = db.presets or {}
    
    -- Wipe lookup
    for k in pairs(activeZones) do activeZones[k] = nil end

    -- Check if automation is enabled AND if there are any presets that ACTUALLY have zones defined
    local hasZonePresets = false
    if db.presets and #db.presets > 0 then
        for _, preset in ipairs(db.presets) do
            if preset.zones and #preset.zones > 0 then
                hasZonePresets = true
                break
            end
        end
    end

    if not db.enableTriggers or not hasZonePresets then
        -- Complete shutdown, unregister events
        presetFrame:UnregisterAllEvents()
        
        -- Restore ALL original volumes since logic is now defunct
        for channel, restoreVol in pairs(db.originalVolumes) do
            local currentCVarVol = tonumber(GetCVar(channel)) or 1
            if currentCVarVol ~= restoreVol then
                SetCVar(channel, restoreVol)
            end
        end
        for k in pairs(db.originalVolumes) do db.originalVolumes[k] = nil end
        
        if VS.sliders then
            for channel, slider in pairs(VS.sliders) do
                if slider.RefreshValue then slider:RefreshValue() end
            end
        end
        if VS.VolumeSlidersObject then
             VS.VolumeSlidersObject.text = VS:GetVolumeText()
        end
        return
    end

    -- If enabled, build map only for presets with zones
    for i, preset in ipairs(db.presets) do
        if preset.zones and type(preset.zones) == "table" and #preset.zones > 0 then
            for _, z in ipairs(preset.zones) do
                local lowerZ = string_lower(z)
                if not activeZones[lowerZ] then
                    activeZones[lowerZ] = {}
                end
                table.insert(activeZones[lowerZ], i)
            end
        end
    end

    -- Register events
    presetFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    presetFrame:RegisterEvent("ZONE_CHANGED")
    presetFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    presetFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    
    -- Evaluate immediately in case we just enabled it while standing in a zone
    OnPresetEvent()
end
