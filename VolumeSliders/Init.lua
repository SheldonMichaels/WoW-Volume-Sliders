-------------------------------------------------------------------------------
-- Init.lua
--
-- Addon initialization (PLAYER_LOGIN) and Addon Compartment integration.
--
-- Fires once after the player enters the world, enforces saved-variable
-- defaults, registers the minimap icon, and wires the addon compartment
-- click handler.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local ipairs    = ipairs
local tonumber  = tonumber
local GetCVar   = GetCVar

-----------------------------------------
-- Addon Initialization (PLAYER_LOGIN)
--
-- Fires once, after the player has entered the world and all addons are loaded.
-----------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")

-------------------------------------------------------------------------------
-- Structural Merge
--
-- Deep-merges missing keys from the VS.DEFAULT_DB blueprint into the active db.
-- Because V2 introduces layered namespaces, this is recursive to ensure
-- tables like `db.layout` or `db.appearance` exist even if new keys are added.
--
-- @param target table The active user database (VolumeSlidersMMDB).
-- @param source table The template defaults (VS.DEFAULT_DB).
-------------------------------------------------------------------------------
local function MergeTable(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            -- If the source value is an array, we treat it as an atomic list.
            -- We do not deep-merge arrays to prevent re-inserting deleted items 
            -- or re-shuffling user-defined orders.
            if v[1] ~= nil then
                if target[k] == nil then
                    target[k] = v -- Copy the entire default array
                end
            else
                -- Source is a dictionary (namespaces like 'layout' or 'appearance')
                if type(target[k]) ~= "table" then
                    target[k] = {}
                end
                MergeTable(target[k], v)
            end
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

-------------------------------------------------------------------------------
-- V1 -> V2 Schema Migration Engine
--
-- Safely routes legacy flat-hierarchy DB keys (from v1.x-v2.16) into their
-- precise V2 namespaced tables (`db.appearance`, `db.channels`, etc.).
-- Operates strictly backwards-compatibly, deleting legacy keys only after routing.
--
-- @param db table The VolumeSlidersMMDB global table.
-------------------------------------------------------------------------------
local function Migrate_V1_to_V2(db)
    if db.schemaVersion and db.schemaVersion >= 2 then return end

    db.appearance = db.appearance or {}
    db.layout = db.layout or {}
    db.toggles = db.toggles or {}
    db.channels = db.channels or {}
    db.minimap = db.minimap or {}
    db.hardware = db.hardware or {}
    db.automation = db.automation or {}
    db.voice = db.voice or {}

    -- 1. Channels
    local cvarMap = {
        showMaster = "Sound_MasterVolume",
        showSFX = "Sound_SFXVolume",
        showMusic = "Sound_MusicVolume",
        showAmbience = "Sound_AmbienceVolume",
        showDialog = "Sound_DialogVolume",
        showGameplay = "Sound_GameplaySFX",
        showPings = "Sound_PingVolume",
        showWarnings = "Sound_EncounterWarningsVolume",
        showVoiceChat = "Voice_ChatVolume",
        showVoiceDucking = "Voice_ChatDucking",
        showMicVolume = "Voice_MicVolume",
        showMicSensitivity = "Voice_MicSensitivity"
    }
    for oldKey, newKey in pairs(cvarMap) do
        if db[oldKey] ~= nil then
            db.channels[newKey] = db[oldKey]
            db[oldKey] = nil
        end
    end

    -- 2. Toggles
    local tNames = { "showTitle", "showValue", "showHigh", "showUpArrow", "showSlider", "showDownArrow", "showLow", "showMute", "showBackground", "showCharacter", "showOutput", "showPresetsDropdown", "showLfgPop", "showZoneTriggers", "showFishingSplash", "showHelpText", "showMinimapTooltip", "showVoiceMode", "persistentWindow", "isLocked" }
    for _, key in ipairs(tNames) do
        if db[key] ~= nil then
            db.toggles[key] = db[key]
            db[key] = nil
        end
    end

    -- 3. Appearance
    if db.bgColorR ~= nil then
        db.appearance.bgColor = { r = db.bgColorR or 0.05, g = db.bgColorG or 0.05, b = db.bgColorB or 0.05, a = db.bgColorA or 0.95 }
        db.bgColorR, db.bgColorG, db.bgColorB, db.bgColorA = nil, nil, nil, nil
    end
    local aNames = { "knobStyle", "arrowStyle", "titleColor", "valueColor", "highColor", "lowColor", "windowWidth", "windowHeight" }
    for _, key in ipairs(aNames) do
        if db[key] ~= nil then
            db.appearance[key] = db[key]
            db[key] = nil
        end
    end

    -- 4. Layout
    if db.sliderOrder then db.layout.sliderOrder = db.sliderOrder; db.sliderOrder = nil end
    if db.maxFooterCols ~= nil then db.layout.maxFooterCols = db.maxFooterCols; db.layout.maxFooterCols = nil end
    if db.limitFooterCols ~= nil then db.layout.limitFooterCols = db.limitFooterCols; db.limitFooterCols = nil end
    if db.customX ~= nil then db.layout.customX = db.customX; db.customX = nil end
    if db.customY ~= nil then db.layout.customY = db.customY; db.customY = nil end

    -- 5. Minimap
    local mNames = { "minimapPos", "hide", "minimalistMinimap", "bindToMinimap", "minimalistOffsetX", "minimalistOffsetY", "minimapIconLocked", "minimapTooltipOrder" }
    for _, key in ipairs(mNames) do
        if db[key] ~= nil then
            db.minimap[key] = db[key]
            db[key] = nil
        end
    end

    -- 6. Hardware
    if db.deviceVolumes then
        db.hardware.deviceVolumes = db.deviceVolumes
        db.deviceVolumes = nil
    end

    -- 7. Automation
    local autoMap = {
        enableTriggers = "enableTriggers",
        enableFishingVolume = "enableFishingVolume",
        enableLfgVolume = "enableLfgVolume",
        fishingPresetIndex = "fishingPresetIndex",
        lfgPresetIndex = "lfgPresetIndex"
    }
    for old, new in pairs(autoMap) do
        if db[old] ~= nil then db.automation[new] = db[old]; db[old] = nil end
    end

    -- Migrate legacy presets logic cleanly
    if db.enableFishingMaster ~= nil or db.enableFishingSFX ~= nil or db.fishingTargetMaster ~= nil or db.fishingTargetSFX ~= nil then
        db.enableFishingMaster, db.enableFishingSFX = nil, nil
        db.fishingTargetMaster, db.fishingTargetSFX = nil, nil
    end
    if db.enableLfgMaster ~= nil or db.enableLfgSFX ~= nil or db.lfgTargetMaster ~= nil or db.lfgTargetSFX ~= nil then
        db.enableLfgMaster, db.enableLfgSFX = nil, nil
        db.lfgTargetMaster, db.lfgTargetSFX = nil, nil
    end
    if db.triggers then db.triggers = nil end
    if db.mouseActions and db.mouseActions.preset then db.mouseActions.preset = nil end

    -- 8. Voice Mute States
    for k, v in pairs(db) do
        if type(k) == "string" and string.sub(k, 1, 16) == "MuteState_Voice_" then
            db.voice[k] = v
        elseif type(k) == "string" and string.sub(k, 1, 15) == "SavedVol_Voice_" then
            db.voice[k] = v
        end
    end
    
    local keysToDelete = {}
    for k, _ in pairs(db) do
        if type(k) == "string" and (string.sub(k, 1, 10) == "MuteState_" or string.sub(k, 1, 9) == "SavedVol_") then
            table.insert(keysToDelete, k)
        end
    end
    for _, k in ipairs(keysToDelete) do
        db[k] = nil
    end

    -- 9. Purge transient session caches
    db.originalVolumes = nil
    db.originalMutes = nil
    db.layoutDirty = nil

    -- 10. Split mouseActions across valid namespaces
    if db.mouseActions then
        if db.mouseActions.sliders or db.mouseActions.scrollWheel then
            db.layout.mouseActions = {
                sliders = db.mouseActions.sliders or {},
                scrollWheel = db.mouseActions.scrollWheel or {}
            }
        end
        if db.mouseActions.minimap then
            db.minimap.mouseActions = db.mouseActions.minimap or {}
        end
        db.mouseActions = nil
    end

    -- 11. Migrate minimap scroll bindings into unified mouse actions
    if db.minimapScrollBindings or db.minimap.minimapScrollBindings then
        local oldBinds = db.minimap.minimapScrollBindings or db.minimapScrollBindings
        db.minimap.mouseActions = db.minimap.mouseActions or {}
        for mod, chan in pairs(oldBinds) do
            if chan and chan ~= "Disabled" then
                local trig = mod == "None" and "Scroll" or mod .. "+Scroll"
                local exists = false
                for _, a in ipairs(db.minimap.mouseActions) do
                    if a.trigger == trig then exists = true; break end
                end
                if not exists then
                    table.insert(db.minimap.mouseActions, {
                        trigger = trig,
                        effect = "SCROLL_VOLUME",
                        stringTarget = chan,
                        numStep = 0.05
                    })
                end
            end
        end
        db.minimapScrollBindings = nil
        db.minimap.minimapScrollBindings = nil
    end

    if db.minimap.mouseActions then
        for _, action in ipairs(db.minimap.mouseActions) do
            if type(action.effect) == "string" and string.match(action.effect, "^PRESET_") then
                local pIdx = string.match(action.effect, "%d+")
                action.effect = "TOGGLE_PRESET"
                action.stringTarget = tostring(pIdx)
            end
        end
    end

    -- 12. Purge legacy hardcoded deadweight
    db.sliderSpacing = nil
    db.sliderHeight = nil

    -- 13. Update legacy preset ignored channels
    local presetsToUpdate = db.automation.presets or db.presets
    if presetsToUpdate then
        for _, preset in ipairs(presetsToUpdate) do
            preset.ignored = preset.ignored or {}
            if type(preset.ignored) == "table" then
                preset.ignored["Sound_GameplaySFX"] = true
                preset.ignored["Sound_PingVolume"] = true
                preset.ignored["Sound_EncounterWarningsVolume"] = true
            end
        end
    end

    -- 14. Nest presets into automation namespace
    if db.presets then
        db.automation.presets = db.presets
        db.presets = nil
    end

    -- 15. Stamp Schema
    db.schemaVersion = 2
end

-------------------------------------------------------------------------------
-- V2 -> V3 Schema Migration Engine
--
-- Initializes the mathematical 'modes' dictionary for presets introduced in 
-- the v3.1.0 "Limiters" update.
--
-- @param db table The VolumeSlidersMMDB global table.
-------------------------------------------------------------------------------
local function Migrate_V2_to_V3(db)
    if db.schemaVersion and db.schemaVersion >= 3 then return end

    local presets = db.automation and db.automation.presets
    if presets then
        for _, preset in ipairs(presets) do
            preset.modes = preset.modes or {}
        end
    end

    db.schemaVersion = 3
end

-------------------------------------------------------------------------------
-- Main Event Handler (PLAYER_LOGIN)
--
-- Orchestrates the addon bootstrap sequence:
-- 1. Schema Migration: Routes legacy keys to V2 structures.
-- 2. Default Restoration: Fills in missing keys from the DEFAULT_DB template.
-- 3. Preset Initialization: Injects a default preset if none exist.
-- 4. Icon Registration: Registers the LibDBIcon minimap button.
-- 5. Sub-Module Init: Triggers initialization for Fishing, LFG, and Presets.
-------------------------------------------------------------------------------
initFrame:SetScript("OnEvent", function(self, event)
    local db = VolumeSlidersMMDB

    -- Apply namespaced structural migration if upgrading from V1
    Migrate_V1_to_V2(db)
    Migrate_V2_to_V3(db)
    
    -- Smart Auto-Detection for Minimalist Minimap Icon
    -- We do this BEFORE MergeTable to ensure detection sets the "Smart Default"
    -- before the template fills in the gaps.
    if db.minimap.minimalistMinimap == nil then
        local useStandardIcon = false
        local mapAddOns = {"SexyMap", "ElvUI", "Leatrix_Plus", "BasicMinimap", "HidingBar", "MBB"}
        for _, addonName in ipairs(mapAddOns) do
            if C_AddOns.IsAddOnLoaded(addonName) then
                useStandardIcon = true
                break
            end
        end
        db.minimap.minimalistMinimap = not useStandardIcon
    end

    -- Merge structural defaults safely
    MergeTable(db, VS.DEFAULT_DB)

    -- Initialize Unified State Stack Baseline
    -- We capture the user's current volume levels as the "baseline" upon which
    -- presets will be layered. This is done early to ensure subsequent 
    -- RefreshEventState calls have a valid baseline to work with.
    for _, channel in ipairs(VS.DEFAULT_CVAR_ORDER) do
        local vol = 1
        if channel == "Voice_ChatVolume" then
            vol = (C_VoiceChat.GetOutputVolume() or 100) / 100
        elseif channel == "Voice_ChatDucking" then
            vol = C_VoiceChat.GetMasterVolumeScale() or 1
        elseif channel == "Voice_MicVolume" then
            vol = (C_VoiceChat.GetInputVolume() or 100) / 100
        elseif channel == "Voice_MicSensitivity" then
            vol = C_VoiceChat.GetVADSensitivity() or 0
        else
            vol = tonumber(GetCVar(channel)) or 1
        end
        VS.session.baselineVolumes[channel] = vol

        -- Initialize baseline mutes
        local muteCvar = VS.CHANNEL_MUTE_CVAR[channel]
        if muteCvar then
            VS.session.baselineMutes[channel] = GetCVar(muteCvar)
        end
    end

    -- Preset Default (must be done post-merge if presets array is empty)
    db.automation.presets = db.automation.presets or {}
    if #db.automation.presets == 0 then
        db.automation.presets = {
            {
                name = "Sunwell Silencer",
                priority = 5,
                zones = {"Isle of Quel'Danas"},
                volumes = { ["Sound_AmbienceVolume"] = 0 },
                ignored = {
                    ["Sound_MasterVolume"] = true,
                    ["Sound_SFXVolume"] = true,
                    ["Sound_MusicVolume"] = true,
                    ["Sound_DialogVolume"] = true,
                    ["Sound_GameplaySFX"] = true,
                    ["Sound_PingVolume"] = true,
                    ["Sound_EncounterWarningsVolume"] = true,
                    ["Voice_ChatVolume"] = true,
                    ["Voice_ChatDucking"] = true,
                    ["Voice_MicVolume"] = true,
                    ["Voice_MicSensitivity"] = true
                },
                mutes = {},
                modes = {},
                showInDropdown = true
            }
        }
    end

    -- Register the minimap icon via LibDBIcon.
    -- V2 SCHEMA REF: We strictly pass db.minimap rather than the global db table.
    -- This securely restricts LibDBIcon from independently polluting our database root.
    VS.LDBIcon:Register("Volume Sliders", VS.VolumeSlidersObject, db.minimap)

    -- LibDBIcon names the minimap button "LibDBIcon10_<name>".
    local minimapButton = _G["LibDBIcon10_Volume Sliders"]
    if minimapButton then
        minimapButton:EnableMouseWheel(true)
        minimapButton:EnableMouse(true)
        minimapButton:RegisterForClicks("AnyUp")

        -- Scroll on the minimap icon to adjust volume.
        VS:HookBrokerScroll(minimapButton)

        -- LibDBIcon intercepts OnClick. To enforce our toggle logic we pre-hook it or handle it in OnMouseUp
        -- After any click on the minimap button, refresh the icon texture
        -- in case the mute state changed.
        minimapButton:HookScript("OnMouseUp", function(self, button)
            VS:HandlePTT_OnMouseUp(button)
            VS:UpdateMiniMapVolumeIcon()
        end)

        minimapButton:HookScript("OnMouseDown", function(self, button)
            VS:HandlePTT_OnMouseDown(button)
        end)

        -- We handle the visual closing in GLOBAL_MOUSE_DOWN instead now.
    end
    VS.minimapButton = minimapButton

    -- Update the minimap icon to the correct mute state and pre-create the
    -- options frame so it's ready for instant display.
    VS:InitializeSettings()

    if VS.Presets and VS.Presets.RefreshEventState then
        VS.Presets:RefreshEventState()
    end

    if VS.Fishing and VS.Fishing.Initialize then
        VS.Fishing:Initialize()
    end

    if VS.LFGQueue and VS.LFGQueue.Initialize then
        VS.LFGQueue:Initialize()
    end

    VS:UpdateMiniMapButtonVisibility()

    -- This event only needs to fire once.
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-----------------------------------------
-- Addon Compartment Integration
--
-- The Addon Compartment is the built-in dropdown accessible from the minimap
-- button cluster (added in Dragonflight).  The global function name is
-- declared in the TOC via ## AddonCompartmentFunc.
-----------------------------------------

--- Global click handler for the Addon Compartment entry.
--- Toggles the slider panel visibility.
--- @param _addonName string Ignored.
--- @param menuButtonFrame Frame The frame that was clicked in the compartment.
function VolumeSliders_OnAddonCompartmentClick(_addonName, menuButtonFrame)
    VolumeSliders_ToggleWindow()
end

--- Global handlers for Bindings.xml
--- Global toggler for the main slider window.
-- Pre-creates the frame if it does not exist yet.
function VolumeSliders_ToggleWindow()
    if not VS.container then
        VS:CreateOptionsFrame()
    end
    if VS.container:IsShown() then
        VS.container:Hide()
    else
        VS.container:Show()
        if VS.Reposition then VS:Reposition() end
    end
end

function VolumeSliders_ToggleMuteMaster()
    if VS.VolumeSliders_ToggleMute then
        VS:VolumeSliders_ToggleMute()
    end
end
