-------------------------------------------------------------------------------
-- MinimapBroker.lua
--
-- LibDataBroker data object, minimap icon texture helpers, scroll-to-adjust
-- volume, and external CVar change listener.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local math_floor = math.floor
local tonumber   = tonumber
local pairs      = pairs
local GetCVar    = GetCVar
local SetCVar    = SetCVar

-----------------------------------------
-- LibDataBroker (LDB) Data Object
--
-- This is the core integration point for minimap icons and data-broker
-- display addons (e.g., Titan Panel, ChocolateBar).  It defines what
-- icon to show, what text to display, and how to respond to clicks.
-----------------------------------------
VS.VolumeSlidersObject = VS.LDB:NewDataObject("Volume Sliders", {
    type = "launcher",
    text = VS:GetVolumeText(),
    icon = "Interface\\AddOns\\VolumeSliders\\Media\\speaker_on.png",
    iconCoords = {0, 1, 0, 1},
    iconR = 1, iconG = 1, iconB = 1,

    --- Left-click: toggle the slider panel. If it's already open, hide it regardless of whether it was opened from this button.
    --- Right-click: toggle master mute.
    OnClick = function(clickedFrame, button)
        if button == "LeftButton" then
             if not VS.container then
                 VS:CreateOptionsFrame()
             end

             if VS.container:IsShown() then
                 VS.container:Hide()
             else
                 VS.container:Show()
                 VS.brokerFrame = clickedFrame
                 VS:Reposition()
             end

            VS:SetScroll()

        elseif button == "RightButton" then
            VS:VolumeSliders_ToggleMute()
        end
    end,

    --- Tooltip: brief usage instructions with green action text.
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Volume Sliders", 1, 1, 1)
        tooltip:AddLine("|cff00ff00Left click|r to open slider panel")
        tooltip:AddLine("|cff00ff00Right click|r to mute/unmute all audio")
    end,
})

--- Attach a mouse-wheel handler to the broker frame so the user can scroll
--- to adjust master volume directly from the icon.  Only hooks once per frame.
function VS:SetScroll()
    if VS.brokerScrollSet then return end
    if VS.brokerFrame then
        VS.brokerFrame:SetScript("OnMouseWheel", function(self, delta)
            VS:AdjustVolume(delta)
        end)
        VS.brokerScrollSet = true
    end
end

-----------------------------------------
-- Minimap Icon Texture Helpers
-----------------------------------------

--- Update a texture to reflect the current mute state.
--- Muted:   speaker_off icon, desaturated, tinted red.
--- Unmuted: speaker_on icon, normal colors.
function VS:UpdateVolumeTexture(texture)
    if GetCVar("Sound_EnableAllSound") == "0" then
        VS.VolumeSlidersObject.icon = "Interface\\AddOns\\VolumeSliders\\Media\\speaker_off.png"
        texture:SetTexture("Interface\\AddOns\\VolumeSliders\\Media\\speaker_off.png")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetDesaturated(true)
        texture:SetVertexColor(1, 0, 0)
    else
        VS.VolumeSlidersObject.icon = "Interface\\AddOns\\VolumeSliders\\Media\\speaker_on.png"
        texture:SetTexture("Interface\\AddOns\\VolumeSliders\\Media\\speaker_on.png")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1)
    end
end

--- Locate the minimap button created by LibDBIcon and update its icon
--- texture to reflect the current mute state.
function VS:UpdateMiniMapVolumeIcon()
    local minimapButton = VS.minimapButton
    if minimapButton then
        local texture = minimapButton.icon
        if texture then
            VS:UpdateVolumeTexture(texture)
        end
    end
end

-----------------------------------------
-- External CVar Change Listener
--
-- When another addon or the Blizzard Sound settings panel changes the
-- master volume, this event fires so we can keep our broker text and
-- slider position in sync.
-----------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, cvarName, value)
    if cvarName == "Sound_MasterVolume" then
        -- Update the broker display text.
        VS.VolumeSlidersObject.text = VS:GetVolumeText()

        -- Sync the Master slider if the panel is open.
        if VS.sliders and VS.sliders["Sound_MasterVolume"] then
             local val = tonumber(value) or 0
             VS.sliders["Sound_MasterVolume"]:SetValue(1 - val)
             VS.sliders["Sound_MasterVolume"].valueText:SetText(math_floor(val * 100) .. "%")
        end
    end
end)
