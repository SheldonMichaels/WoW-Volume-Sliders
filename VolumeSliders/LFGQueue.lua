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
    isVolumeOverridden = false
    -- Signal the Preset logic to deactivate the LFG state.
    VS.Presets:SetStateActive("lfg", false)
end

local function ApplyLFGVolumes()
    if isVolumeOverridden then return end
    isVolumeOverridden = true
    -- Signal the Preset logic to apply the user's selected LFG preset.
    VS.Presets:SetStateActive("lfg", true)
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
    -- Guard against "secret" values introduced in Midnight (13.x).
    -- Attempting to compare a secret value directly triggers a taint error.
    if VS:IsSecret(soundID) then return end

    local isLfgPop = false
    -- Use pcall for the comparison as a secondary safety measure.
    pcall(function()
        if soundID == SOUNDKIT.READY_CHECK then
            isLfgPop = true
        end
    end)

    if VolumeSlidersMMDB.enableLfgVolume and isLfgPop then
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
            if isVolumeOverridden then
                RestoreVolumes()
            end
        end
    else
        lfgFrame:UnregisterAllEvents()
        if isVolumeOverridden then
            RestoreVolumes()
        end
    end
end
