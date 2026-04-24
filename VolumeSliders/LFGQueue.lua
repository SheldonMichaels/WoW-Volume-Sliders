-------------------------------------------------------------------------------
-- LFGQueue.lua
--
-- Logic for the LFG Queue volume override feature. Detects when the player
-- gets a queue pop (LFG_PROPOSAL_SHOW) and toggles the "lfg" automation state.
--
-- DESIGN:
-- This module uses a hybrid approach:
-- 1. Event Listeners: Tracks the LFG proposal lifecycle (Show, Done, Failed).
-- 2. Secure Hooks: Hooks PlaySound(SOUNDKIT.READY_CHECK) and combines it with
--    GetLFGProposal() so boosts only occur for active LFG proposal pops.
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

--- Determines if the player is currently queued for any LFG activity.
-- @return boolean True if queued or if a proposal is actively popping.
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

--- Signals the Preset engine to deactivate the LFG automation state.
local function RestoreVolumes()
    if not isVolumeOverridden then return end
    isVolumeOverridden = false
    VS.Presets:SetStateActive("lfg", false)
end

--- Signals the Preset engine to activate the LFG automation state.
local function ApplyLFGVolumes()
    if isVolumeOverridden then return end
    isVolumeOverridden = true
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
    if not db.automation.enableLfgVolume then return end

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

-- Hook PlaySound so we can react at the same moment READY_CHECK is requested.
-- We then gate with GetLFGProposal() to avoid boosting non-LFG ready checks.
hooksecurefunc("PlaySound", function(soundID)
    -- Guard against secret values in Midnight (13.x)
    -- Comparing secret values directly during secure execution paths (like combat)
    -- will cause taint errors, so we explicitly filter them out first.
    if VS:IsSecret(soundID) then return end

    -- Wrapping the comparison in pcall provides a secondary safety layer against
    -- opaque data types causing unpredictable comparative behavior in different game sub-regions.
    local ok, isLfgPop = pcall(function() return soundID == SOUNDKIT.READY_CHECK end)
    if not ok or not isLfgPop then return end

    if VolumeSlidersMMDB.automation.enableLfgVolume then
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

--- Initializes or tears down the LFGQueue module based on user settings.
-- Registers for LFG updates and proposals when enabled.
function VS.LFGQueue:Initialize()
    local db = VolumeSlidersMMDB

    -- Ensure tracked state exists
    VS.session = VS.session or {}

    if db.automation.enableLfgVolume then
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
