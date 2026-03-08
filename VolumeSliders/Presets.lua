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
-- Track active automation states (e.g., "fishing", "lfg").
-- These are set externally by Fishing.lua and LFGQueue.lua.
local activeStates = {}

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
-- This is the central orchestrator that applies overrides based on priority
-- and restores original volumes for any channel not governed by an active preset.
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
--- Event handler for all registered zone/login events.
-- Also called manually by RefreshEventState/SetStateActive when automation triggers.
local function OnPresetEvent()
    local db = VolumeSlidersMMDB
    if not db.presets or #db.presets == 0 then return end

    local matchedPresets = {}
    local matchedPresetIndices = {} -- deduplication map

    -- 1. Helper to safely add matched presets by index
    local function AddMatchedPresetByIndex(id)
        -- id is the 1-based index in db.presets as selected by the user in Settings.
        if id and db.presets[id] and not matchedPresetIndices[id] then
            matchedPresetIndices[id] = true
            table.insert(matchedPresets, db.presets[id])
        end
    end

    -- 2. Check Area/Zone Triggers
    if db.enableTriggers then
        local realZone = GetRealZoneText() and string_lower(GetRealZoneText()) or ""
        local subZone = GetSubZoneText() and string_lower(GetSubZoneText()) or ""
        local miniZone = GetMinimapZoneText() and string_lower(GetMinimapZoneText()) or ""

        -- Guard against "secret" values introduced in Midnight (13.x)
        if not (VS:IsSecret(realZone) or VS:IsSecret(subZone) or VS:IsSecret(miniZone)) then
            local function AddZoneMatches(zoneStr)
                local ids = activeZones[zoneStr]
                if ids then
                    for _, id in ipairs(ids) do
                        AddMatchedPresetByIndex(id)
                    end
                end
            end
            AddZoneMatches(realZone)
            AddZoneMatches(subZone)
            AddZoneMatches(miniZone)
        end
    end

    -- 3. Check Fishing Automation
    if db.enableFishingVolume and activeStates["fishing"] then
        AddMatchedPresetByIndex(db.fishingPresetIndex)
    end

    -- 4. Check LFG Automation
    if db.enableLfgVolume and activeStates["lfg"] then
        AddMatchedPresetByIndex(db.lfgPresetIndex)
    end

    ApplyAutomationPresets(matchedPresets)
end

presetFrame:SetScript("OnEvent", OnPresetEvent)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Toggles an automation state (like "fishing" or "lfg") on or off.
-- Triggers a re-evaluation of all presets.
function VS.Presets:SetStateActive(stateName, isActive)
    activeStates[stateName] = isActive
    self:RefreshEventState()
end

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

    -- Automation is "active" if zones are being monitored OR if an automation state is triggered
    local anyActiveStates = false
    for _, active in pairs(activeStates) do
        if active then anyActiveStates = true; break end
    end

    if not anyActiveStates and (not db.enableTriggers or not hasZonePresets) then
        -- Complete shutdown of zone events
        presetFrame:UnregisterAllEvents()
        
        -- Evaluate one last time to restore volumes if necessary
        OnPresetEvent()
        
        -- If no volumes are overridden anymore, we can clear the originalVolumes table safety
        local stillOverridden = false
        for _ in pairs(db.originalVolumes) do stillOverridden = true; break end
        
        if not stillOverridden then
            -- Optional cleanup
        end
        return
    end

    -- If zone triggers are enabled, build map for presets with zones
    if db.enableTriggers then
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
        
        -- Register zone events
        presetFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        presetFrame:RegisterEvent("ZONE_CHANGED")
        presetFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        presetFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    else
        -- Zone triggers disabled, unregister events
        presetFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        presetFrame:UnregisterEvent("ZONE_CHANGED")
        presetFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        presetFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
    end
    
    -- Evaluate immediately
    OnPresetEvent()
end
