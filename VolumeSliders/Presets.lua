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
local math_max = math.max
local math_min = math.min

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

-- Tracks manually toggled presets for the current session.
-- Registry Structure: VS.session.activeRegistry[type][id] = presetObject
-- Priority: Manual (Layer 2) > Automation (Layer 1) > Baseline (Layer 0)

-------------------------------------------------------------------------------
-- Logic Implementation
-------------------------------------------------------------------------------

--- Sort function for presets based on priority. Higher priority overwrites lower.
local function SortPresetsByPriority(a, b)
    local pA = a.priority or 0
    local pB = b.priority or 0
    return pA < pB
end

--- Get current volume for a channel (Standard CVar or Voice API).
local function GetCurrentVolume(channel)
    if channel == "Voice_ChatVolume" then
        return (C_VoiceChat.GetOutputVolume() or 100) / 100
    elseif channel == "Voice_ChatDucking" then
        return C_VoiceChat.GetMasterVolumeScale() or 1
    elseif channel == "Voice_MicVolume" then
        return (C_VoiceChat.GetInputVolume() or 100) / 100
    elseif channel == "Voice_MicSensitivity" then
        return C_VoiceChat.GetVADSensitivity() or 0
    end
    return tonumber(GetCVar(channel)) or 1
end

--- Set volume for a channel (Standard CVar or Voice API).
local function SetCurrentVolume(channel, volume)
    if channel == "Voice_ChatVolume" then
        C_VoiceChat.SetOutputVolume(volume * 100)
    elseif channel == "Voice_ChatDucking" then
        C_VoiceChat.SetMasterVolumeScale(volume)
    elseif channel == "Voice_MicVolume" then
        C_VoiceChat.SetInputVolume(volume * 100)
    elseif channel == "Voice_MicSensitivity" then
        C_VoiceChat.SetVADSensitivity(volume)
    else
        SetCVar(channel, volume)
    end
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

--- Registers an active preset in the session stack and triggers evaluation.
-- @param registryType string The category of preset ("zone", "lfg", "fishing", "manual").
-- @param id string|number Unique identifier for the instance (e.g. preset index).
-- @param presetObj table|nil The preset data, or nil to unregister.
function VS.Presets:RegisterActivePreset(registryType, id, presetObj)
    local sess = VS.session
    sess.activeRegistry[registryType] = sess.activeRegistry[registryType] or {}
    sess.activeRegistry[registryType][id] = presetObj
    
    self:EvaluateAllPresets()
end

--- Central engine that calculates the target volume state and applies it to CVars.
function VS.Presets:EvaluateAllPresets()
    if VS.session.isSettingInternal then return end
    VS.session.isSettingInternal = true

    local sess = VS.session
    local db = VolumeSlidersMMDB
    
    -- Check if registry is empty -> Wipe Manual Overrides (The Kill-Switch)
    local anyActive = false
    for _, typeTable in pairs(sess.activeRegistry) do
        for _, obj in pairs(typeTable) do
            if obj then anyActive = true; break end
        end
        if anyActive then break end
    end

    if not anyActive then
        for k in pairs(sess.manualOverrides) do sess.manualOverrides[k] = nil end
    end

    -- 1. Initialize target state from Baseline (User's last intended setting)
    local targetState = {}
    local targetMutes = {}
    for _, channel in ipairs(VS.DEFAULT_CVAR_ORDER) do
        targetState[channel] = sess.baselineVolumes[channel] or 1
        targetMutes[channel] = sess.baselineMutes[channel] or "1"
    end

    -- 2. Flatten and Sort active presets
    local presetsToApply = {}
    
    -- Layer 1: Automation (Zones, Fishing, LFG)
    local automationTypes = { "zone", "fishing", "lfg" }
    for _, t in ipairs(automationTypes) do
        if sess.activeRegistry[t] then
            for idx, preset in pairs(sess.activeRegistry[t]) do
                table.insert(presetsToApply, { preset = preset, type = t, idx = idx })
            end
        end
    end
    table_sort(presetsToApply, function(a, b)
        return SortPresetsByPriority(a.preset, b.preset)
    end)

    -- Layer 2: Manual Toggles (Always Highest Priority)
    local manualWrappers = {}
    if sess.activeRegistry["manual"] then
        for idx, preset in pairs(sess.activeRegistry["manual"]) do
            table.insert(manualWrappers, { preset = preset, type = "manual", idx = idx })
        end
    end
    -- Sorting manual toggles relative to each other (Rule 5: Newest Wins)
    table_sort(manualWrappers, function(a, b)
        local timeA = sess.manualActivationTimes[a.idx] or 0
        local timeB = sess.manualActivationTimes[b.idx] or 0
        return timeA < timeB
    end)
    for _, wrapper in ipairs(manualWrappers) do
        table.insert(presetsToApply, wrapper)
    end

    -- 3. Layer volumes over baseline (Respecting Manual Overrides)
    local activeMutes = {} -- channel => true
    for _, wrapper in ipairs(presetsToApply) do
        local preset = wrapper.preset
        local isTransient = (wrapper.type == "fishing" or wrapper.type == "lfg")
        for channel, presetVal in pairs(preset.volumes) do
            -- A preset applies ONLY if the user hasn't moved that slider manually during this session.
            -- Rule 4 Transient Punch-Through: fishing and lfg bypass manualOverrides.
            if not sess.manualOverrides[channel] or isTransient then
                if not preset.ignored or not preset.ignored[channel] then
                    local mode = preset.modes and preset.modes[channel] or "absolute"
                    local currentVal = targetState[channel]

                    if mode == "floor" then
                        targetState[channel] = math_max(currentVal, presetVal)
                    elseif mode == "ceiling" then
                        targetState[channel] = math_min(currentVal, presetVal)
                    else
                        -- Default: absolute overwrite
                        targetState[channel] = presetVal
                    end

                    if preset.mutes and preset.mutes[channel] then
                        activeMutes[channel] = true
                    end
                end
            end
        end
    end

    -- 4. Apply calculated state to the Game Environment
    for _, channel in ipairs(VS.DEFAULT_CVAR_ORDER) do
        local finalVol = targetState[channel]
        local current = GetCurrentVolume(channel)

        -- Handle Muting (CVars only, Voice is handled via Soft-Mute in UI/DB)
        local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
        if muteCvar then
            local shouldMute = activeMutes[channel]
            local targetMuteValue = shouldMute and "0" or targetMutes[channel]
            local currentMute = GetCVar(muteCvar)
            
            if currentMute ~= targetMuteValue then
                SetCVar(muteCvar, targetMuteValue)
            end
        end
        
        -- Special Handling for Voice Channels: Integrate with Soft-Mute logic.
        if channel:find("^Voice_") then
            -- If user has soft-muted this channel in the UI, we overwrite the preset volume with 0
            if db.voice and db.voice["MuteState_"..channel] then
                finalVol = 0
            end
        end

        if current ~= finalVol then
            SetCurrentVolume(channel, finalVol)
        end
        
        db.automation.lastAppliedState = db.automation.lastAppliedState or {}
        db.automation.lastAppliedState[channel] = finalVol
        local muteCvar2 = VS.CHANNEL_MUTE_CVAR[channel]
        if muteCvar2 then
            db.automation.lastAppliedState[channel .. "_Mute"] = GetCVar(muteCvar2)
        end
    end

    VS.session.isSettingInternal = false
    RefreshUI()
end

--- Toggles a preset on or off (refactored for Unified State Stack).
-- @param preset table The preset object.
-- @param presetIndex number The index in db.automation.presets.
-- @return boolean True if triggered on, false if off.
function VS.Presets:TogglePreset(preset, presetIndex)
    if not preset then return false end
    
    local sess = VS.session
    local db = VolumeSlidersMMDB
    local isActive = sess.activeRegistry["manual"] and sess.activeRegistry["manual"][presetIndex]
    
    if isActive then
        -- Toggle OFF
        self:RegisterActivePreset("manual", presetIndex, nil)
        sess.manualActivationTimes[presetIndex] = nil
        if db.automation.activeManualPresets then
            db.automation.activeManualPresets[presetIndex] = nil
        end
        return false
    else
        -- Toggle ON (Rule 1: Iron Fist)
        for channel, _ in pairs(preset.volumes) do
            if not preset.ignored or not preset.ignored[channel] then
                sess.manualOverrides[channel] = nil
                
                -- Decoupled Mutes: Unmute if it's not explicitly muted by the preset
                local shouldMute = preset.mutes and preset.mutes[channel]
                if not shouldMute then
                    local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
                    if muteCvar then
                        sess.baselineMutes[channel] = "1"
                        db.automation = db.automation or {}
                        db.automation.persistedBaseline = db.automation.persistedBaseline or {}
                        db.automation.persistedBaseline[channel .. "_Mute"] = "1"
                        SetCVar(muteCvar, 1)
                    end
                    if channel:find("^Voice_") then
                        db.voice = db.voice or {}
                        db.voice["MuteState_"..channel] = nil
                    end
                end
            end
        end

        local now = GetTime()
        sess.manualActivationTimes[presetIndex] = now
        db.automation.activeManualPresets = db.automation.activeManualPresets or {}
        db.automation.activeManualPresets[presetIndex] = now

        self:RegisterActivePreset("manual", presetIndex, preset)
        return true
    end
end

--- Event handler for all registered zone/login events.
-- Matches current location and active states to the registry.
local function OnPresetEvent()
    local db = VolumeSlidersMMDB
    if not db.automation.presets or #db.automation.presets == 0 then return end
    
    -- Clear current zone/auto registration in session to recalculate
    local sess = VS.session
    local oldZoneRegistry = {}
    if sess.activeRegistry["zone"] then
        for idx, obj in pairs(sess.activeRegistry["zone"]) do
            oldZoneRegistry[idx] = obj
        end
    end

    sess.activeRegistry["zone"] = {}
    sess.activeRegistry["fishing"] = {}
    sess.activeRegistry["lfg"] = {}

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
                        if db.automation.presets[id] then
                            sess.activeRegistry["zone"][id] = db.automation.presets[id]
                        end
                    end
                end
            end
            AddZoneMatches(realZone)
            AddZoneMatches(subZone)
            AddZoneMatches(miniZone)
        end
        
        -- Rule 2 (Zone Bleed): Clear overrides if a zone preset newly activates
        for idx, preset in pairs(sess.activeRegistry["zone"]) do
            if not oldZoneRegistry[idx] then
                for channel, _ in pairs(preset.volumes) do
                    if not preset.ignored or not preset.ignored[channel] then
                        sess.manualOverrides[channel] = nil
                    end
                end
            end
        end
    end

    -- 3. Check Fishing Automation
    if db.automation.enableFishingVolume and activeStates["fishing"] then
        local fIdx = db.automation.fishingPresetIndex
        if db.automation.presets[fIdx] then
            sess.activeRegistry["fishing"][fIdx] = db.automation.presets[fIdx]
        end
    end

    -- 4. Check LFG Automation
    if db.automation.enableLfgVolume and activeStates["lfg"] then
        local lIdx = db.automation.lfgPresetIndex
        if db.automation.presets[lIdx] then
            sess.activeRegistry["lfg"][lIdx] = db.automation.presets[lIdx]
        end
    end

    VS.Presets:EvaluateAllPresets()
end

presetFrame:SetScript("OnEvent", function(self, event, name, value)
    if event == "CVAR_UPDATE" then
        if not VS.session.isSettingInternal then
            VS:SyncBaseline(name, tonumber(value) or 1)
        end
    else
        OnPresetEvent()
    end
end)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Returns a comma-separated string of currently active presets.
function VS.Presets:GetActiveTriggersString()
    local sess = VS.session
    local matchedNames = {}
    
    for _, presets in pairs(sess.activeRegistry) do
        for _, preset in pairs(presets) do
            if preset and preset.name then
                table.insert(matchedNames, preset.name)
            end
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

        -- Register events
        presetFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        presetFrame:RegisterEvent("ZONE_CHANGED")
        presetFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        presetFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        presetFrame:RegisterEvent("CVAR_UPDATE")
    else
        -- Zone triggers disabled, unregister non-critical events
        presetFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        presetFrame:UnregisterEvent("ZONE_CHANGED")
        presetFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        presetFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
        -- We ALWAYS keep CVAR_UPDATE if we want baseline sync from Blizzard UI
        presetFrame:RegisterEvent("CVAR_UPDATE")
    end

    -- Evaluate immediately
    OnPresetEvent()
end
