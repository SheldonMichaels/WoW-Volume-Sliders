-------------------------------------------------------------------------------
-- LFGQueue.lua
--
-- Logic for the LFG Queue volume override feature. Detects when the player
-- gets a queue pop (LFG_PROPOSAL_SHOW) and applies user-defined Master/SFX
-- volume targets. Safely restores the volumes when the proposal concludes.
-- Listens to LFG_UPDATE to intelligently unregister proposal events when not queued.
--
-- Author: Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

VS.LFGQueue = {}

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local GetCVar = GetCVar
local SetCVar = SetCVar
local tonumber = tonumber
local GetLFGQueueStats = GetLFGQueueStats
local GetLFGProposal = GetLFGProposal
local NUM_LE_LFG_CATEGORYS = _G.NUM_LE_LFG_CATEGORYS or 5

-------------------------------------------------------------------------------
-- Module State
-------------------------------------------------------------------------------
local lfgFrame = CreateFrame("Frame")
lfgFrame:Hide()

-- The sound channels we boost
local MASTER_CHANNEL = "Sound_MasterVolume"
local SFX_CHANNEL = "Sound_SFXVolume"

-- Flag to track if we currently have an override active
local isVolumeOverridden = false

-------------------------------------------------------------------------------
-- Logic Implementation
-------------------------------------------------------------------------------

local function IsPlayerQueued()
    -- Check if a proposal is active (popping)
    if GetLFGProposal and GetLFGProposal() then
        return true
    end

    -- Check all LFG categories to see if the player is queued for anything
    -- Categories usually range from 1 to 5 (Dungeon, Raid, PvP, Scenario, etc.)
    for i = 1, NUM_LE_LFG_CATEGORYS do
        local hasData = GetLFGQueueStats(i)
        if hasData then
            return true
        end
    end
    return false
end

local function RestoreVolumes()
    if not isVolumeOverridden then return end
    
    local db = VolumeSlidersMMDB
    isVolumeOverridden = false
    
    local changed = false

    -- Restore Master Volume
    if db.originalVolumes[MASTER_CHANNEL] and db.originalVolumes[MASTER_CHANNEL] ~= "LFG_IGNORE" then
        SetCVar(MASTER_CHANNEL, db.originalVolumes[MASTER_CHANNEL])
        changed = true
    end
    db.originalVolumes[MASTER_CHANNEL] = nil

    -- Restore SFX Volume
    if db.originalVolumes[SFX_CHANNEL] and db.originalVolumes[SFX_CHANNEL] ~= "LFG_IGNORE" then
        SetCVar(SFX_CHANNEL, db.originalVolumes[SFX_CHANNEL])
        changed = true
    end
    db.originalVolumes[SFX_CHANNEL] = nil

    if changed then
        -- Sync the sliders UI
        if VS.sliders and VS.sliders[MASTER_CHANNEL] and VS.sliders[MASTER_CHANNEL].RefreshValue then
            VS.sliders[MASTER_CHANNEL]:RefreshValue()
        end
        if VS.sliders and VS.sliders[SFX_CHANNEL] and VS.sliders[SFX_CHANNEL].RefreshValue then
            VS.sliders[SFX_CHANNEL]:RefreshValue()
        end
    end
end

local function ApplyLFGVolumes()
    if isVolumeOverridden then return end
    
    local db = VolumeSlidersMMDB
    local currentMaster = tonumber(GetCVar(MASTER_CHANNEL)) or 1
    local currentSFX = tonumber(GetCVar(SFX_CHANNEL)) or 1
    
    local targetMaster = db.lfgTargetMaster or 1.0
    local targetSFX = db.lfgTargetSFX or 1.0

    local changed = false
    
    db.originalVolumes = db.originalVolumes or {}

    -- Master Volume Logic
    if db.enableLfgMaster and currentMaster < targetMaster then
        if db.originalVolumes[MASTER_CHANNEL] == nil then
            db.originalVolumes[MASTER_CHANNEL] = currentMaster
        end
        SetCVar(MASTER_CHANNEL, targetMaster)
        changed = true
    else
        -- Mark as ignored so we don't restore it if it wasn't adjusted
        if db.originalVolumes[MASTER_CHANNEL] == nil then
            db.originalVolumes[MASTER_CHANNEL] = "LFG_IGNORE"
        end
    end

    -- SFX Volume Logic
    if db.enableLfgSFX and currentSFX < targetSFX then
        if db.originalVolumes[SFX_CHANNEL] == nil then
            db.originalVolumes[SFX_CHANNEL] = currentSFX
        end
        SetCVar(SFX_CHANNEL, targetSFX)
        changed = true
    else
        -- Mark as ignored so we don't restore it if it wasn't adjusted
        if db.originalVolumes[SFX_CHANNEL] == nil then
            db.originalVolumes[SFX_CHANNEL] = "LFG_IGNORE"
        end
    end

    -- We always set this to true so RestoreVolumes cleans up the IGNORE flags
    isVolumeOverridden = true
    
    if changed then
        -- Sync the sliders UI
        if VS.sliders and VS.sliders[MASTER_CHANNEL] and VS.sliders[MASTER_CHANNEL].RefreshValue then
            VS.sliders[MASTER_CHANNEL]:RefreshValue()
        end
        if VS.sliders and VS.sliders[SFX_CHANNEL] and VS.sliders[SFX_CHANNEL].RefreshValue then
            VS.sliders[SFX_CHANNEL]:RefreshValue()
        end
    end
end

local function RegisterProposalEvents()
    lfgFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
    lfgFrame:RegisterEvent("LFG_PROPOSAL_DONE")
    lfgFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
    lfgFrame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
end

local function UnregisterProposalEvents()
    lfgFrame:UnregisterEvent("LFG_PROPOSAL_SHOW")
    lfgFrame:UnregisterEvent("LFG_PROPOSAL_DONE")
    lfgFrame:UnregisterEvent("LFG_PROPOSAL_FAILED")
    lfgFrame:UnregisterEvent("LFG_PROPOSAL_SUCCEEDED")
end

local function OnEvent(self, event, ...)
    local db = VolumeSlidersMMDB
    if not db.enableLfgVolume then return end
    
    if event == "LFG_UPDATE" then
        if IsPlayerQueued() then
            RegisterProposalEvents()
        else
            UnregisterProposalEvents()
            RestoreVolumes()
        end
    elseif event == "LFG_PROPOSAL_SHOW" then
        -- The volume will be applied by the PlaySound hook
        -- but we still register this explicitly in case the sound was disabled
        ApplyLFGVolumes()
    elseif event == "LFG_PROPOSAL_DONE" or event == "LFG_PROPOSAL_FAILED" or event == "LFG_PROPOSAL_SUCCEEDED" then
        RestoreVolumes()
    end
end

-- Hook PlaySound so we can guarantee the volume is boosted exactly when 
-- the Dungeon Ready sound is requested by the UI, distinguishing it from party /readycheck.
hooksecurefunc("PlaySound", function(soundID)
    if VolumeSlidersMMDB.enableLfgVolume and soundID == SOUNDKIT.READY_CHECK then
        -- Only boost if we have an active queue proposal specifically popping.
        -- Do not use IsPlayerQueued() here, as that returns true while merely waiting 
        -- in the queue, which would accidentally boost party /readycheck sounds.
        if GetLFGProposal and GetLFGProposal() then
            -- Make sure we apply volumes IMMEDIATELY before the sound system processes the request 
            ApplyLFGVolumes()
            
            -- Automatically restore the volume after the sound finishes playing (approx 4.5 seconds).
            -- This prevents the volume from staying boosted indefinitely while the proposal sits open.
            -- If the user clicks accept/decline early, the existing event hooks will safely 
            -- pre-empt this and the RestoreVolumes flag check will just swallow the redundant timer execution.
            C_Timer.After(4.5, RestoreVolumes)
        end
    end
end)

lfgFrame:SetScript("OnEvent", OnEvent)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Initializes or tears down the LFGQueue module based on user settings
function VS.LFGQueue:Initialize()
    local db = VolumeSlidersMMDB
    
    -- Ensure tracked state exists
    db.originalVolumes = db.originalVolumes or {}
    
    if db.enableLfgVolume then
        lfgFrame:RegisterEvent("LFG_UPDATE")
        
        -- Check initial state in case they enable it while already queued
        if IsPlayerQueued() then
            RegisterProposalEvents()
        else
            UnregisterProposalEvents()
            RestoreVolumes()
        end
    else
        lfgFrame:UnregisterAllEvents()
        RestoreVolumes()
    end
end
