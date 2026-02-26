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
initFrame:SetScript("OnEvent", function(self, event)
    local db = VolumeSlidersMMDB

    -- Enforce saved variable defaults here, as top-level declarations
    -- are overwritten by the disk database during ADDON_LOADED.
    db.minimapPos = db.minimapPos or 180
    if db.hide == nil then db.hide = false end
    if db.isLocked == nil then db.isLocked = true end
    db.knobStyle = db.knobStyle or 1
    db.arrowStyle = db.arrowStyle or 1
    db.titleColor = db.titleColor or 1
    db.valueColor = db.valueColor or 1
    db.highColor = db.highColor or 2
    db.lowColor = db.lowColor or 2
    
    if db.bindToMinimap == nil then db.bindToMinimap = true end
    if db.minimalistOffsetX == nil then db.minimalistOffsetX = -35 end
    if db.minimalistOffsetY == nil then db.minimalistOffsetY = -5 end
    if db.showTitle == nil then db.showTitle = true end
    if db.showValue == nil then db.showValue = true end
    if db.showHigh == nil then db.showHigh = false end
    if db.showUpArrow == nil then db.showUpArrow = true end
    if db.showSlider == nil then db.showSlider = true end
    if db.showDownArrow == nil then db.showDownArrow = true end
    if db.showLow == nil then db.showLow = false end
    if db.showMute == nil then db.showMute = true end
    if db.showWarnings == nil then db.showWarnings = true end
    if db.showBackground == nil then db.showBackground = true end
    if db.showCharacter == nil then db.showCharacter = true end
    if db.showOutput == nil then db.showOutput = true end

    -- Channel Visibility Defaults
    if db.showMaster == nil then db.showMaster = true end
    if db.showSFX == nil then db.showSFX = true end
    if db.showMusic == nil then db.showMusic = true end
    if db.showAmbience == nil then db.showAmbience = false end
    if db.showDialog == nil then db.showDialog = true end
    if db.showVoiceChat == nil then db.showVoiceChat = true end
    if db.showVoiceDucking == nil then db.showVoiceDucking = false end
    if db.showMicVolume == nil then db.showMicVolume = false end
    if db.showMicSensitivity == nil then db.showMicSensitivity = false end
    if db.showVoiceMode == nil then db.showVoiceMode = true end

    -- Layout Defaults
    db.sliderHeight = db.sliderHeight or 150
    db.sliderSpacing = db.sliderSpacing or 10

    -- Slider Order Defaults
    if not db.sliderOrder then
        db.sliderOrder = {}
        for _, v in ipairs(VS.DEFAULT_CVAR_ORDER) do
            table.insert(db.sliderOrder, v)
        end
    else
        -- Ensure dynamically added CVARs to DEFAULT_CVAR_ORDER don't get orphaned from existing databases
        for _, defaultCvar in ipairs(VS.DEFAULT_CVAR_ORDER) do
            local found = false
            for _, existingCvar in ipairs(db.sliderOrder) do
                if existingCvar == defaultCvar then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(db.sliderOrder, defaultCvar)
            end
        end
    end

    -- Register the minimap icon via LibDBIcon.
    VS.LDBIcon:Register("Volume Sliders", VS.VolumeSlidersObject, db)

    -- LibDBIcon names the minimap button "LibDBIcon10_<name>".
    local minimapButton = _G["LibDBIcon10_Volume Sliders"]
    if minimapButton then
        minimapButton:EnableMouseWheel(true)
        minimapButton:EnableMouse(true)
        minimapButton:RegisterForClicks("AnyUp")

        -- Scroll on the minimap icon to adjust master volume.
        minimapButton:SetScript("OnMouseWheel", function(self, delta)
            VS:AdjustVolume(delta)
        end)

        -- LibDBIcon intercepts OnClick. To enforce our toggle logic we pre-hook it or handle it in OnMouseUp
        -- After any click on the minimap button, refresh the icon texture
        -- in case the mute state changed.
        minimapButton:HookScript("OnMouseUp", function(self, button)
            VS:UpdateMiniMapVolumeIcon()
        end)

        -- We handle the visual closing in GLOBAL_MOUSE_DOWN instead now.
    end
    VS.minimapButton = minimapButton

    -- Update the minimap icon to the correct mute state and pre-create the
    -- options frame so it's ready for instant display.
    VS:InitializeSettings()
    
    -- Smart Auto-Detection for Minimalist Minimap Icon
    if db.minimalistMinimap == nil then
        local useStandardIcon = false
        local mapAddOns = {"SexyMap", "ElvUI", "Leatrix_Plus", "BasicMinimap", "HidingBar", "MBB"}
        for _, addonName in ipairs(mapAddOns) do
            if C_AddOns.IsAddOnLoaded(addonName) then
                useStandardIcon = true
                break
            end
        end
        
        -- If a minimap manager is found, default to standard ringed icon.
        -- Otherwise default to the new Minimalist aesthetic.
        db.minimalistMinimap = not useStandardIcon
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
function VolumeSliders_OnAddonCompartmentClick(_addonName, menuButtonFrame)
    if not VS.container then
        VS:CreateOptionsFrame()
    end

    if VS.container:IsShown() then
        VS.container:Hide()
    else
        VS.container:Show()
    end
end
