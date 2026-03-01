-------------------------------------------------------------------------------
-- Triggers.lua
--
-- Logic for Zone Specific Triggers. Registers for zone change events,
-- evaluates triggers by priority, and dynamically adjusts volume levels.
-- Uses O(1) zone lookups and unregisters events when triggers are disabled.
--
-- Author: Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-- Expose a central table for trigger logic and state
VS.Triggers = {}

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
local triggerFrame = CreateFrame("Frame")

-- Lookup table for O(1) matching: activeZones[lowerZoneName] = {triggerIndex1, triggerIndex2, ...}
local activeZones = {}
-- Maintain a list of original CVars before they were overridden by triggers.
-- originalVolumes[channel] = originalValue
VolumeSlidersMMDB.originalVolumes = VolumeSlidersMMDB.originalVolumes or {}

-------------------------------------------------------------------------------
-- Logic Implementation
-------------------------------------------------------------------------------

--- Sort function for triggers based on priority. High priority applies last (overwrites).
-- Triggers are assumed to have a 'priority' field (number).
local function SortTriggersByPriority(a, b)
    local pA = a.priority or 0
    local pB = b.priority or 0
    return pA < pB
end

--- Apply a list of active triggers to the game state.
-- Restores unmodified channels to their original values.
local function ApplyTriggers(activeTriggerList)
    local db = VolumeSlidersMMDB
    
    -- We want to track which channels are currently overridden so we can restore the rest
    local overriddenChannels = {}
    local finalVolumes = {}

    -- Apply triggers in priority ascending order
    table_sort(activeTriggerList, SortTriggersByPriority)

    for _, trigger in ipairs(activeTriggerList) do
        for channel, vol in pairs(trigger.volumes) do
            -- Ignore specific channels in a trigger if they are marked ignored
            if not trigger.ignored or not trigger.ignored[channel] then
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
            -- No active trigger is overriding this channel. Restore if it was overridden previously.
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

--- Event handler for all registered zone/login events.
local function OnTriggerEvent()
    local db = VolumeSlidersMMDB
    if not db.enableTriggers or not db.triggers or #db.triggers == 0 then return end

    local realZone = GetRealZoneText() and string_lower(GetRealZoneText()) or ""
    local subZone = GetSubZoneText() and string_lower(GetSubZoneText()) or ""
    local miniZone = GetMinimapZoneText() and string_lower(GetMinimapZoneText()) or ""

    local matchedTriggers = {}
    local matchedTriggerIndices = {} -- deduplication map

    -- Helper to safely add matched triggers
    local function AddMatchedTriggers(zoneStr)
        local ids = activeZones[zoneStr]
        if ids then
            for _, id in ipairs(ids) do
                if not matchedTriggerIndices[id] then
                    matchedTriggerIndices[id] = true
                    table.insert(matchedTriggers, db.triggers[id])
                end
            end
        end
    end

    AddMatchedTriggers(realZone)
    AddMatchedTriggers(subZone)
    AddMatchedTriggers(miniZone)

    ApplyTriggers(matchedTriggers)
end

triggerFrame:SetScript("OnEvent", OnTriggerEvent)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Rebuilds the O(1) zone lookup table and registers/unregisters events based
-- on load-on-demand principles to guarantee zero CPU drag when idle.
function VS.Triggers:RefreshEventState()
    local db = VolumeSlidersMMDB
    
    -- Ensure required tables exist (for users upgrading from older versions)
    db.originalVolumes = db.originalVolumes or {}
    db.triggers = db.triggers or {}
    
    -- Wipe lookup
    for k in pairs(activeZones) do activeZones[k] = nil end

    if not db.enableTriggers or not db.triggers or #db.triggers == 0 then
        -- Complete shutdown, unregister events
        triggerFrame:UnregisterAllEvents()
        
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

    -- If enabled, build map
    for i, trigger in ipairs(db.triggers) do
        if trigger.zones and type(trigger.zones) == "table" then
            for _, z in ipairs(trigger.zones) do
                local lowerZ = string_lower(z)
                if not activeZones[lowerZ] then
                    activeZones[lowerZ] = {}
                end
                table.insert(activeZones[lowerZ], i)
            end
        end
    end

    -- Register events
    triggerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    triggerFrame:RegisterEvent("ZONE_CHANGED")
    triggerFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    triggerFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    
    -- Evaluate immediately in case we just enabled it while standing in a zone
    OnTriggerEvent()
end

