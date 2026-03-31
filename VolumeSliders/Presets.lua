-------------------------------------------------------------------------------
-- Presets.lua
--
-- Logic for Automation Presets (formerly Zone Triggers). Registers for zone
-- change events, evaluates presets by priority, and dynamically adjusts
-- volume levels.
--
-- DESIGN PATTERNS:
-- 1. O(1) Lookup: Zones are mapped to preset IDs in a hash table for speed.
-- 2. Priority Stack: Overlapping presets (e.g. Zone + Fishing) are sorted
--    by user-defined priority before application.
-- 3. Snapshotted Toggles: Manual presets record CVars before applying,
--    allowing for a perfect "undo" toggle.
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
VS.session = VS.session or {}
VS.session.originalVolumes = VS.session.originalVolumes or {}
-- originalMutes[channel] = originalEnableValue ("0" or "1")
VS.session.originalMutes = VS.session.originalMutes or {}

-- Tracks manually toggled presets for the current session and across sessions.
-- Stored in VolumeSlidersMMDB.automation.manualToggleState[presetIndex].

-------------------------------------------------------------------------------
-- Logic Implementation
-------------------------------------------------------------------------------

--- Sort function for presets based on priority. High priority applies last (overwrites).
local function SortPresetsByPriority(a, b)
    local pA = a.priority or 0
    local pB = b.priority or 0
    return pA < pB
end

--- Refresh all slider UI elements and broker text.
-- Ensures the UI reflects external CVar changes made by presets.
local function RefreshUI()
    if VS.sliders then
        for _, slider in pairs(VS.sliders) do
            if slider.RefreshValue then slider:RefreshValue() end
            if slider.RefreshMute then slider:RefreshMute() end
        end
    end
    if VS.VolumeSlidersObject then
        VS.VolumeSlidersObject.text = VS:GetVolumeText()
    end
end

--- Apply a list of active automation presets to the game state.
-- This is the central orchestrator that applies overrides based on priority
-- and restores original volumes for any channel not governed by an active preset.
--
-- @param activePresetList table A list of preset objects to evaluate.
local function ApplyAutomationPresets(activePresetList)
    local db = VolumeSlidersMMDB
    VS.session.originalVolumes = VS.session.originalVolumes or {}
    VS.session.originalMutes = VS.session.originalMutes or {}

    -- We want to track which channels are currently overridden so we can restore the rest
    local overriddenChannels = {}
    local finalVolumes = {}
    local finalMutes = {} -- channel => true (should mute)

    -- Apply presets in priority ascending order
    table_sort(activePresetList, SortPresetsByPriority)

    for _, preset in ipairs(activePresetList) do
        for channel, vol in pairs(preset.volumes) do
            -- Ignore specific channels in a preset if they are marked ignored
            if not preset.ignored or not preset.ignored[channel] then
                finalVolumes[channel] = vol
                overriddenChannels[channel] = true
                -- Only override mute state if explicitly configured
                if preset.mutes and preset.mutes[channel] then
                    finalMutes[channel] = true
                end
            end
        end
    end

    for _, channel in ipairs(VS.DEFAULT_CVAR_ORDER) do
        if overriddenChannels[channel] then
            -- We need to apply an override
            local currentCVarVol = tonumber(GetCVar(channel)) or 1
            -- Save the original volume ONLY IF it hasn't already been saved
            if not VS.session.originalVolumes[channel] then
                VS.session.originalVolumes[channel] = currentCVarVol
            end

            local wantVol = finalVolumes[channel]
            if currentCVarVol ~= wantVol then
                SetCVar(channel, wantVol)
            end

            -- Handle mute override (only if explicitly configured)
            local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
            if muteCvar and finalMutes[channel] then
                if not VS.session.originalMutes[channel] then
                    VS.session.originalMutes[channel] = GetCVar(muteCvar)
                end
                SetCVar(muteCvar, 0)
            end
        else
            -- No active preset is overriding this channel. Restore if it was overridden previously.
            if VS.session.originalVolumes[channel] then
                local restoreVol = VS.session.originalVolumes[channel]
                local currentCVarVol = tonumber(GetCVar(channel)) or 1
                if currentCVarVol ~= restoreVol then
                    SetCVar(channel, restoreVol)
                end
                -- Clear original since we restored it
                VS.session.originalVolumes[channel] = nil
            end
            -- Restore mute state if it was overridden
            local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
            if muteCvar and VS.session.originalMutes[channel] then
                SetCVar(muteCvar, VS.session.originalMutes[channel])
                VS.session.originalMutes[channel] = nil
            end
        end
    end

    RefreshUI()
end

--- Applies a single preset immediately (called from automation or direct apply).
-- Does NOT modify originalVolumes (so it's permanent until changed again).
-- Supports per-channel mute overrides when preset.mutes[channel] = true.
-- @param preset table The preset object to apply.
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
            -- Apply mute override only if explicitly configured
            local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
            if muteCvar and preset.mutes and preset.mutes[channel] then
                SetCVar(muteCvar, 0)
                changed = true
            end
        end
    end

    -- Update UI if anything changed
    if changed then
        RefreshUI()
    end
end

--- Toggles a preset on or off (manual application from dropdown or hotkey).
-- First call: snapshots current values and applies the preset.
-- Second call (if channels unchanged): restores the snapshot.
-- Second call (if channels changed): re-snapshots and re-applies.
-- @param preset table The preset object.
-- @param presetIndex number The 1-based index in db.automation.presets.
-- @return boolean True if the preset is now active, false if un-toggled.
function VS.Presets:TogglePreset(preset, presetIndex)
    if not preset or type(preset.volumes) ~= "table" then return false end

    local db = VolumeSlidersMMDB
    local snapshot = db.automation.manualToggleState[presetIndex]

    if snapshot then
        -- Preset is currently "active" — check if channels still match
        local allMatch = true
        for channel, _ in pairs(snapshot.volumes) do
            if not preset.ignored or not preset.ignored[channel] then
                local currentVol = tonumber(GetCVar(channel)) or 1
                local presetVol = preset.volumes[channel]
                if presetVol and currentVol ~= presetVol then
                    allMatch = false
                    break
                end
            end
        end

        -- Also check mute states for channels with explicit mute config
        if allMatch and snapshot.mutes then
            for channel, _ in pairs(snapshot.mutes) do
                local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
                if muteCvar then
                    local currentMute = GetCVar(muteCvar)
                    -- Preset mutes = channel should be muted ("0")
                    if currentMute ~= "0" then
                        allMatch = false
                        break
                    end
                end
            end
        end

        if allMatch then
            -- UN-TOGGLE: restore snapshot values
            for channel, origVol in pairs(snapshot.volumes) do
                SetCVar(channel, origVol)
            end
            -- Restore mute states for channels that had explicit mute config
            if snapshot.mutes then
                for channel, origMuteVal in pairs(snapshot.mutes) do
                    local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
                    if muteCvar then
                        SetCVar(muteCvar, origMuteVal)
                    end
                end
            end
            db.automation.manualToggleState[presetIndex] = nil
            RefreshUI()
            return false
        else
            -- RE-APPLY: channels were modified, take fresh snapshot
            db.automation.manualToggleState[presetIndex] = nil
            -- Fall through to the "apply" path below
        end
    end

    -- APPLY: take snapshot and apply
    local volSnapshot = {}
    local muteSnapshot = {}
    local hasMuteSnapshot = false

    for channel, vol in pairs(preset.volumes) do
        if not preset.ignored or not preset.ignored[channel] then
            -- Snapshot current volume
            volSnapshot[channel] = tonumber(GetCVar(channel)) or 1
            -- Apply preset volume
            SetCVar(channel, vol)
            -- Handle mute (only if explicitly configured)
            local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
            if muteCvar and preset.mutes and preset.mutes[channel] then
                muteSnapshot[channel] = GetCVar(muteCvar)
                SetCVar(muteCvar, 0)
                hasMuteSnapshot = true
            end
        end
    end

    db.automation.manualToggleState[presetIndex] = {
        volumes = volSnapshot,
        mutes = hasMuteSnapshot and muteSnapshot or nil
    }

    RefreshUI()
    return true
end

--- Event handler for all registered zone/login events.
-- Also called manually by RefreshEventState/SetStateActive when automation triggers.
-- Matches current location and active states to a list of presets.
local function OnPresetEvent()
    local db = VolumeSlidersMMDB
    if not db.automation.presets or #db.automation.presets == 0 then return end

    local matchedPresets = {}
    local matchedPresetIndices = {} -- deduplication map

    -- 1. Helper to safely add matched presets by index
    local function AddMatchedPresetByIndex(id)
        -- id is the 1-based index in db.automation.presets as selected by the user in Settings.
        if id and db.automation.presets[id] and not matchedPresetIndices[id] then
            matchedPresetIndices[id] = true
            table.insert(matchedPresets, db.automation.presets[id])
        end
    end

    -- 2. Check Area/Zone Triggers
    if db.automation.enableTriggers then
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
    if db.automation.enableFishingVolume and activeStates["fishing"] then
        AddMatchedPresetByIndex(db.automation.fishingPresetIndex)
    end

    -- 4. Check LFG Automation
    if db.automation.enableLfgVolume and activeStates["lfg"] then
        AddMatchedPresetByIndex(db.automation.lfgPresetIndex)
    end

    ApplyAutomationPresets(matchedPresets)
end

presetFrame:SetScript("OnEvent", OnPresetEvent)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Returns a comma-separated string of currently active presets.
function VS.Presets:GetActiveTriggersString()
    local db = VolumeSlidersMMDB
    if not db.automation.presets or #db.automation.presets == 0 then return "None" end

    local matchedNames = {}
    local matchedPresetIndices = {}

    local function AddMatchedPresetByIndex(id)
        if id and db.automation.presets[id] and not matchedPresetIndices[id] then
            matchedPresetIndices[id] = true
            table.insert(matchedNames, db.automation.presets[id].name or "Unnamed Preset")
        end
    end

    if db.automation.enableTriggers then
        local realZone = GetRealZoneText() and string_lower(GetRealZoneText()) or ""
        local subZone = GetSubZoneText() and string_lower(GetSubZoneText()) or ""
        local miniZone = GetMinimapZoneText() and string_lower(GetMinimapZoneText()) or ""

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

    if db.automation.enableFishingVolume and activeStates["fishing"] then
        AddMatchedPresetByIndex(db.automation.fishingPresetIndex)
    end

    if db.automation.enableLfgVolume and activeStates["lfg"] then
        AddMatchedPresetByIndex(db.automation.lfgPresetIndex)
    end

    -- 4. Manual Presets (applied via TogglePreset or Minimap Action)
    if db.automation.manualToggleState then
        for presetIndex, _ in pairs(db.automation.manualToggleState) do
            AddMatchedPresetByIndex(presetIndex)
        end
    end

    if #matchedNames > 0 then
        return table.concat(matchedNames, ", ")
    end
    return "None"
end

--- Toggles an automation state (like "fishing" or "lfg") on or off.
-- Triggers a re-evaluation of all presets.
-- @param stateName string The internal key for the state (e.g. "fishing").
-- @param isActive boolean Whether the state is now engaged.
function VS.Presets:SetStateActive(stateName, isActive)
    activeStates[stateName] = isActive
    self:RefreshEventState()
end

--- Rebuilds the O(1) zone lookup table and registers/unregisters events based
-- on load-on-demand principles to guarantee zero CPU drag when idle.
function VS.Presets:RefreshEventState()
    local db = VolumeSlidersMMDB

    -- Ensure required tables exist
    VS.session.originalVolumes = VS.session.originalVolumes or {}
    db.automation.presets = db.automation.presets or {}

    -- Wipe lookup
    for k in pairs(activeZones) do activeZones[k] = nil end

    -- Check if automation is enabled AND if there are any presets that ACTUALLY have zones defined
    local hasZonePresets = false
    if db.automation.presets and #db.automation.presets > 0 then
        for _, preset in ipairs(db.automation.presets) do
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

    if not anyActiveStates and (not db.automation.enableTriggers or not hasZonePresets) then
        -- Complete shutdown of zone events
        presetFrame:UnregisterAllEvents()

        -- Evaluate one last time to restore volumes if necessary
        OnPresetEvent()

        return
    end

    -- If zone triggers are enabled, build map for presets with zones
    if db.automation.enableTriggers then
        for i, preset in ipairs(db.automation.presets) do
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
