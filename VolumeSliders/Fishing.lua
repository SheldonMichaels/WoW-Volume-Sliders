-------------------------------------------------------------------------------
-- Fishing.lua
--
-- Logic for the fishing volume override feature. Detects when the player
-- channels a fishing cast and temporarily boosts the SFX volume channel,
-- safely restoring it when the cast ends or is interrupted. Includes
-- aggressive combat checks to ensure zero interference during combat.
--
-- Author: Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-- Expose a central table for fishing logic
VS.Fishing = {}

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local GetCVar = GetCVar
local SetCVar = SetCVar
local UnitAffectingCombat = UnitAffectingCombat
local tonumber = tonumber
---@diagnostic disable-next-line: undefined-global
local GetSpellInfo = GetSpellInfo
local C_Spell = C_Spell

-------------------------------------------------------------------------------
-- Module State
-------------------------------------------------------------------------------
local fishingFrame = CreateFrame("Frame")
fishingFrame:Hide()

-- The sound channel to boost during fishing
local OVERRIDE_CHANNEL = "Sound_SFXVolume"
-- Hardcoded target volume for a loud splash (1.0 = 100%)
local FISHING_TARGET_VOL = 1.0

-- Flag to track if we currently have an override active
local isVolumeOverridden = false

-- Hardcoded Spell IDs for Fishing
local FISHING_SPELL_IDS = {
    [131474] = true, -- Retail Generic Fishing
    [131476] = true, -- Fishing rank / cast ID
    [7620] = true,   -- Old rank 1
    -- The API often provides spell info on cast, so checking names/IDs is dynamic
}

local function GetSafeSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    elseif GetSpellInfo then
        return GetSpellInfo(spellID)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Logic Implementation
-------------------------------------------------------------------------------

local function RestoreVolume()
    if not isVolumeOverridden then return end
    
    local db = VolumeSlidersMMDB
    isVolumeOverridden = false
    
    -- If we have an original volume saved, restore it
    if db.originalVolumes[OVERRIDE_CHANNEL] then
        local restoreVol = db.originalVolumes[OVERRIDE_CHANNEL]
        local currentVol = tonumber(GetCVar(OVERRIDE_CHANNEL)) or 1
        
        -- Only set if it hasn't somehow already been changed back by something else,
        -- though usually we just enforce the restore.
        SetCVar(OVERRIDE_CHANNEL, restoreVol)
        
        -- Clear from saved states so Triggers module doesn't get confused
        db.originalVolumes[OVERRIDE_CHANNEL] = nil
        
        -- Sync the sliders UI
        if VS.sliders and VS.sliders[OVERRIDE_CHANNEL] and VS.sliders[OVERRIDE_CHANNEL].RefreshValue then
            VS.sliders[OVERRIDE_CHANNEL]:RefreshValue()
        end
    end
end

local function ApplyFishingVolume()
    if isVolumeOverridden then return end
    
    local db = VolumeSlidersMMDB
    local currentVol = tonumber(GetCVar(OVERRIDE_CHANNEL)) or 1
    
    -- Only override if the current volume is lower than our target
    if currentVol < FISHING_TARGET_VOL then
        isVolumeOverridden = true
        
        -- Store the user's original volume ONLY if it isn't already stored (e.g. by a zone trigger)
        if not db.originalVolumes[OVERRIDE_CHANNEL] then
            db.originalVolumes[OVERRIDE_CHANNEL] = currentVol
        end
        
        SetCVar(OVERRIDE_CHANNEL, FISHING_TARGET_VOL)
        
        -- Sync the sliders UI
        if VS.sliders and VS.sliders[OVERRIDE_CHANNEL] and VS.sliders[OVERRIDE_CHANNEL].RefreshValue then
            VS.sliders[OVERRIDE_CHANNEL]:RefreshValue()
        end
    end
end

local function OnEvent(self, event, ...)
    local db = VolumeSlidersMMDB
    if not db.enableFishingVolume then return end
    
    if event == "PLAYER_REGEN_DISABLED" then
        -- Combat started, aggressively cancel feature
        RestoreVolume()
        return
        
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        -- Only process if not in combat
        if UnitAffectingCombat("player") then return end
        
        local unitTarget, castGUID, spellID = ...
        if unitTarget == "player" then
            -- Verify if the spell being cast is Fishing
            -- In retail, the spell info is provided. If not in the hardcoded list, we could fallback
            -- to a localized string match, but IDs are safer.
            local spellInfo = C_Spell and C_Spell.GetSpellInfo(spellID)
            local spellName = spellInfo and spellInfo.name
            
            -- We check if it's explicitly the fishing spell ID OR if the localized name evaluates to "Fishing"
            -- (To support various language clients, using the ID is ideal, but name is a good fallback)
            -- Note: 131474 is the modern Retail fishing spell ID.
            if FISHING_SPELL_IDS[spellID] or (spellName and GetSafeSpellName(131474) == spellName) then
                ApplyFishingVolume()
            end
        end
        
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        -- Cast ended (caught fish, cancelled, or ran out of time)
        local unitTarget = ...
        if unitTarget == "player" then
            RestoreVolume()
        end
    end
end

fishingFrame:SetScript("OnEvent", OnEvent)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Initializes or tears down the Fishing module based on user settings
function VS.Fishing:Initialize()
    local db = VolumeSlidersMMDB
    
    -- Ensure tracked state exists
    db.originalVolumes = db.originalVolumes or {}
    
    if db.enableFishingVolume then
        fishingFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        fishingFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        fishingFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    else
        fishingFrame:UnregisterAllEvents()
        RestoreVolume()
    end
end
