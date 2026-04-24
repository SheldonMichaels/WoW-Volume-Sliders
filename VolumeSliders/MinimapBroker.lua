-------------------------------------------------------------------------------
-- MinimapBroker.lua
--
-- LibDataBroker data object, minimap icon texture helpers, scroll-to-adjust
-- volume, and external CVar change listener.
--
-- Handles the main integration with the minimap, including the standard
-- LibDBIcon button and the custom "Minimalist" speaker icon.
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
-- Voice Chat Push-to-Talk Helpers
--
-- These handlers temporarily flip Push-to-Talk to Open Mic while the minimap
-- icon is actively pressed to avoid the click sound side effect.
-----------------------------------------

local PTT_ACTIVE = false

--- Temporarily switches Voice Chat to Open Mic during button presses.
-- This prevents the "Push-to-Talk" sound from firing when clicking the
-- minimap icon, which can be jarring.
-- @param button string The mouse button clicked.
function VS:HandlePTT_OnMouseDown(button)
    if button == "LeftButton" and not (IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
        if C_VoiceChat and C_VoiceChat.GetCommunicationMode then
            local mode = C_VoiceChat.GetCommunicationMode()
            if mode == 0 then -- Enum.CommunicationMode.PushToTalk
                PTT_ACTIVE = true
                C_VoiceChat.SetCommunicationMode(1) -- Enum.CommunicationMode.OpenMic
            end
        end
    end
end

--- Restores Voice Chat to Push-to-Talk after the button is released.
-- @param button string The mouse button released.
function VS:HandlePTT_OnMouseUp(button)
    if PTT_ACTIVE then
        if C_VoiceChat and C_VoiceChat.SetCommunicationMode then
            C_VoiceChat.SetCommunicationMode(0) -- Enum.CommunicationMode.PushToTalk
        end
        PTT_ACTIVE = false
    end
end

-----------------------------------------
-- HookBrokerScroll
--
-- Third-party LDB display addons (ElvUI data texts, Titan Panel, etc.)
-- create their own frames. We selectively hook OnMouseWheel on each display
-- frame the moment the user hovers it (via OnTooltipShow) so that scroll-to-
-- adjust-volume works immediately, without requiring a click first.
--
-- @param frame Frame The display frame to hook.
-----------------------------------------
function VS:HookBrokerScroll(frame)
    if not frame or frame.vsMouseWheelHooked then return end
    frame:EnableMouseWheel(true)
    frame:HookScript("OnMouseWheel", function(self, delta)
        local triggerStr = VS:GetActiveTriggerString(nil, delta)
        VS:ProcessMinimapAction(triggerStr, self, delta)
    end)
    frame.vsMouseWheelHooked = true
end

-----------------------------------------
-- LibDataBroker (LDB) Data Object
--
-- This is the core integration point for minimap icons and data-broker
-- display addons (e.g., Titan Panel, ChocolateBar).  It defines what
-- icon to show, what text to display, and how to respond to clicks.
--
-- V2 SCHEMA REF: `Init.lua` strictly passes `db.minimap` into LibDBIcon
-- so the library cannot pollute the global database root with its own settings.
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
        local triggerStr = VS:GetActiveTriggerString(button)
        if triggerStr and VS:ProcessMinimapAction(triggerStr, clickedFrame, nil) then
            return
        end

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

        elseif button == "RightButton" then
            VS:VolumeSliders_ToggleMute()
        end

        VS:RefreshMinimapTooltip()
    end,

    --- Tooltip: dynamic instructions based on configured Mouse Actions.
    OnTooltipShow = function(tooltip)
        -- Siphon the display frame reference on hover so scroll-to-adjust
        -- works immediately, even before the user has clicked anything.
        local frame = tooltip:GetOwner()
        if frame then VS:HookBrokerScroll(frame) end

        local db = VolumeSlidersMMDB
        if db and db.toggles.showMinimapTooltip == false then return end
        
        tooltip:AddLine("Volume Sliders", 1, 1, 1)

        if not db.minimap.minimapTooltipOrder then return end
        
        for _, item in ipairs(db.minimap.minimapTooltipOrder) do
            if item.type == "MouseActions" then
                VS:AppendActionTooltipLines(tooltip, "minimap", {
                    { trigger = "LeftButton", effectName = "Toggle Slider Window" },
                    { trigger = "RightButton", effectName = "Toggle Master Mute" }
                })
            elseif item.type == "OutputDevice" then
                if Sound_GameSystem_GetNumOutputDrivers and Sound_GameSystem_GetOutputDriverNameByIndex then
                    local index = tonumber(GetCVar("Sound_OutputDriverIndex")) or 0
                    local name = Sound_GameSystem_GetOutputDriverNameByIndex(index)
                    if name then
                        tooltip:AddLine("Output Device: |cffffffff" .. name .. "|r", 1, 0.82, 0)
                    end
                end
            elseif item.type == "ActivePresets" then
                if VS.Presets and VS.Presets.GetActiveTriggersString then
                    local activeStrs = VS.Presets:GetActiveTriggersString()
                    if activeStrs and activeStrs ~= "" then
                        tooltip:AddLine("Active Presets: |cffffffff" .. activeStrs .. "|r", 1, 0.82, 0)
                    end
                end
            elseif item.type == "ChannelVolume" and item.channel then
                local valStr = GetCVar(item.channel) or "0"
                local val = math_floor((tonumber(valStr) or 0) * 100 + 0.5)
                local niceNames = {
                    ["Sound_MasterVolume"] = "Master",
                    ["Sound_SFXVolume"] = "SFX",
                    ["Sound_MusicVolume"] = "Music",
                    ["Sound_AmbienceVolume"] = "Ambience",
                    ["Sound_DialogVolume"] = "Dialog",
                    ["Sound_GameplaySFX"] = "Gameplay",
                    ["Sound_PingVolume"] = "Pings",
                    ["Sound_EncounterWarningsVolume"] = "Warnings",
                    ["Voice_ChatVolume"] = "Voice Chat",
                    ["Voice_ChatDucking"] = "Voice Ducking",
                    ["Voice_MicVolume"] = "Mic Volume",
                    ["Voice_MicSensitivity"] = "Mic Sensitivity",
                }
                local pretty = niceNames[item.channel] or item.channel
                tooltip:AddLine(string.format("%s: |cffffffff%d%%|r", pretty, val), 1, 0.82, 0)
            end
        end
    end,
})



-----------------------------------------
-- Minimap Icon Texture Helpers
-----------------------------------------

--- Update a texture to reflect the current mute state.
-- Muted:   speaker_off icon, desaturated, tinted red.
-- Unmuted: speaker_on icon, normal colors.
-- @param texture Texture The texture object to update.
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

--- Locate the minimap button created by LibDBIcon and the custom minimalist button
-- and update their icon textures to reflect the current mute state.
function VS:UpdateMiniMapVolumeIcon()
    local minimapButton = VS.minimapButton
    if minimapButton and minimapButton.icon then
        VS:UpdateVolumeTexture(minimapButton.icon)
    end

    if VS.minimalistButton and VS.minimalistButton.minimalistIcon then
        if GetCVar("Sound_EnableAllSound") == "0" then
            VS.minimalistButton.minimalistIcon:SetAtlas("voicechat-icon-speaker-mute")
        else
            VS.minimalistButton.minimalistIcon:SetAtlas("voicechat-icon-speaker")
        end
    end
end

-------------------------------------------------------------------------------
-- Tooltip Refresh Helper
--
-- Rebuilds the active minimap tooltip if it's currently showing, allowing
-- real-time updates of volume percentages and preset states after actions.
-------------------------------------------------------------------------------
function VS:RefreshMinimapTooltip()
    -- Case 1: Minimalist button using standard GameTooltip
    if VS.minimalistButton and GameTooltip:IsShown() and GameTooltip:GetOwner() == VS.minimalistButton then
        GameTooltip:ClearLines()
        VS.VolumeSlidersObject.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
        return
    end

    -- Case 2: Standard LibDBIcon button using its private LibDBIconTooltip frame
    if _G.LibDBIconTooltip and _G.LibDBIconTooltip:IsShown() then
        local owner = _G.LibDBIconTooltip:GetOwner()
        if owner and owner.dataObject == VS.VolumeSlidersObject then
            _G.LibDBIconTooltip:ClearLines()
            VS.VolumeSlidersObject.OnTooltipShow(_G.LibDBIconTooltip)
            _G.LibDBIconTooltip:Show()
        end
    end
end

-------------------------------------------------------------------------------
-- Hover Evaluation Helper
--
-- Handles the "Bind to Minimap" feature where the icon only appears when
-- hovering near the minimap.
-------------------------------------------------------------------------------
local hoverTimer = 0
local checkInterval = 0.15

local function HoverPolling_OnUpdate(self, elapsed)
    hoverTimer = hoverTimer + elapsed
    if hoverTimer > checkInterval then
        hoverTimer = 0
        local isOver = VS:CheckMinimapHover()
        -- Dynamic Throttling: If we are actively hovering, check frequently (0.15s) for snappy response.
        -- If we aren't, back off the polling rate to 0.5s to save CPU cycles.
        if isOver then
            checkInterval = 0.15
        else
            checkInterval = 0.5
        end
    end
end

--- Starts the polling sequence to check if the mouse is near the minimap.
function VS:StartHoverPolling()
    if not VolumeSlidersMMDB.minimap.minimalistMinimap or not VS.minimalistButton or not VolumeSlidersMMDB.minimap.bindToMinimap then return end

    VS.minimalistButton:SetAlpha(1)
    if VS.minimalistButton:GetScript("OnUpdate") ~= HoverPolling_OnUpdate then
        hoverTimer = 0
        checkInterval = 0.15 -- Reset to fast polling when newly entering
        VS.minimalistButton:SetScript("OnUpdate", HoverPolling_OnUpdate)
    end
end

--- Checks if the mouse is currently over the Minimap or any of its zoom controls.
-- @return boolean isOver True if the mouse is within the interactive zone.
function VS:CheckMinimapHover()
    if not VolumeSlidersMMDB.minimap.minimalistMinimap or not VS.minimalistButton or not VolumeSlidersMMDB.minimap.bindToMinimap then
        if VS.minimalistButton then VS.minimalistButton:SetScript("OnUpdate", nil) end
        return false
    end

    local isOver = Minimap:IsMouseOver() or VS.minimalistButton:IsMouseOver()
    if Minimap.ZoomIn and Minimap.ZoomIn:IsMouseOver() then isOver = true end
    if Minimap.ZoomOut and Minimap.ZoomOut:IsMouseOver() then isOver = true end
    if MinimapZoomIn and MinimapZoomIn:IsMouseOver() then isOver = true end
    if MinimapZoomOut and MinimapZoomOut:IsMouseOver() then isOver = true end

    if isOver then
        VS.minimalistButton:SetAlpha(1)
    else
        VS.minimalistButton:SetAlpha(0)
        VS.minimalistButton:SetScript("OnUpdate", nil)

        -- Force the native Minimap to clean up its zoom buttons since the cursor
        -- has explicitly left our custom interactive area and into free space.
        if Minimap and Minimap:HasScript("OnLeave") then
            local onLeave = Minimap:GetScript("OnLeave")
            if onLeave then onLeave(Minimap) end
        end
    end

    return isOver
end

-------------------------------------------------------------------------------
-- CreateMinimalistButton
--
-- Implementation of the custom "Ghost Frame" speaker icon.
--
-- TECHNICAL DESIGN:
-- We use a plain Frame instead of a Button to hide from third-party minimap
-- managers (SexyMap, ElvUI) which often strip textures from "Button" children
-- of the Minimap. We simulate button behavior via OnMouseDown/Up.
-------------------------------------------------------------------------------
function VS:CreateMinimalistButton()
    if VS.minimalistButton then return end

    -- We use a plain Frame instead of a Button! This completely blinds third-party Minimap
    -- skinning addons (SexyMap, ElvUI, etc.) which aggressively scan for "Button" objects and ruin their textures.
    local btn = CreateFrame("Frame", "VS_MinimalistSpeakerBtn", Minimap)
    btn:SetSize(17, 17)

    -- Hidden by default until mouseover (if bound)
    if VolumeSlidersMMDB.minimap.bindToMinimap then
        btn:SetParent(Minimap)
        btn:SetAlpha(0)
    else
        btn:SetParent(UIParent)
        btn:SetAlpha(1)
    end

    local xOffset = VolumeSlidersMMDB.minimap.minimalistOffsetX or -35
    local yOffset = VolumeSlidersMMDB.minimap.minimalistOffsetY or -5
    btn:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", xOffset, yOffset)

    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 10)

    -- Simulated Drop Shadow
    -- Placed on ARTWORK to avoid Minimap Skinning addons auto-detecting BACKGROUND textures
    local shadow = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    shadow:SetSize(17, 17)
    shadow:SetPoint("CENTER", btn, "CENTER", 1, -1)
    shadow:SetAtlas("voicechat-icon-speaker")
    shadow:SetVertexColor(0, 0, 0, 0.7)
    btn.shadow = shadow

    -- Instead of SetNormalAtlas (which can get hijacked by button border templates),
    -- we use a dedicated child texture layer to guarantee it renders exactly as the Atlas intends.
    local icon = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetSize(17, 17)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    icon:SetAtlas("voicechat-icon-speaker")
    btn.minimalistIcon = icon

    -- Visual feedback for clicks and hovers
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(17, 17)
    highlight:SetPoint("CENTER", btn, "CENTER", 0, 0)
    highlight:SetAtlas("voicechat-icon-speaker")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.2)

    btn:SetScript("OnMouseDown", function(self, button)
        self.minimalistIcon:SetPoint("CENTER", self, "CENTER", 1, -1)
        self.shadow:SetPoint("CENTER", self, "CENTER", 2, -2)
        VS:HandlePTT_OnMouseDown(button)
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        self.minimalistIcon:SetPoint("CENTER", self, "CENTER", 0, 0)
        self.shadow:SetPoint("CENTER", self, "CENTER", 1, -1)
        VS:HandlePTT_OnMouseUp(button)

        -- We handle clicks here now since Frames don't have OnClick
        if not self.isMoving and self:IsMouseOver() then
            local triggerStr = VS:GetActiveTriggerString(button)
            if triggerStr and VS:ProcessMinimapAction(triggerStr, self, nil) then
                return
            end

            if button == "LeftButton" then
                 if not VS.container then
                     VS:CreateOptionsFrame()
                 end

                 if VS.container:IsShown() then
                     VS.container:Hide()
                 else
                     VS.container:Show()
                     VS.brokerFrame = self
                     VS:Reposition()
                 end
            elseif button == "RightButton" then
                VS:VolumeSliders_ToggleMute()
            end

            VS:RefreshMinimapTooltip()
        end
    end)

    -- Ensure the interactive hit rect maintains its intended 17x17 size
    btn:SetSize(17, 17)

    btn:EnableMouse(true)
    btn:EnableMouseWheel(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnDragStart", function(self)
        local db = VolumeSlidersMMDB
        if not db.minimap.minimapIconLocked then
            self.isMoving = true
            self:StartMoving()
        end
    end)

    btn:SetScript("OnDragStop", function(self)
        if self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false

            -- Because StopMovingOrSizing changes the anchor and parent coordinates,
            -- we explicitly recalculate our offset from the Minimap's BOTTOMRIGHT.
            local mmScale = Minimap:GetEffectiveScale()
            local btnScale = self:GetEffectiveScale()
            -- Find the absolute screen difference between their bottom rights:
            local mmRight = Minimap:GetRight() * mmScale
            local mmBottom = Minimap:GetBottom() * mmScale
            local btnRight = self:GetRight() * btnScale
            local btnBottom = self:GetBottom() * btnScale

            -- Convert absolute difference back into the button's local scale
            local rawX = (btnRight - mmRight) / btnScale
            local rawY = (btnBottom - mmBottom) / btnScale

            VolumeSlidersMMDB.minimap.minimalistOffsetX = rawX
            VolumeSlidersMMDB.minimap.minimalistOffsetY = rawY

            -- Re-lock the anchor formally so resizing the screen doesn't skew it
            self:ClearAllPoints()
            self:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", rawX, rawY)
        end
    end)

    VS:HookBrokerScroll(btn)

    btn:SetScript("OnEnter", function(self)
        VS:StartHoverPolling()
        if VolumeSlidersMMDB and VolumeSlidersMMDB.toggles.showMinimapTooltip == false then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        VS.VolumeSlidersObject.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        VS:HandlePTT_OnMouseUp("LeftButton")
    end)

    VS.minimalistButton = btn
end

--- Apply hooks to the native Minimap and zoom buttons to trigger the custom
-- hover polling logic. Only applied once per session.
function VS:ApplyMinimapHoverHooks()
    if VS.minimapHooksApplied then return end

    local function HookHover(frame)
        if not frame then return end
        frame:HookScript("OnEnter", function() VS:StartHoverPolling() end)
    end

    HookHover(Minimap)
    HookHover(Minimap.ZoomIn)
    HookHover(Minimap.ZoomOut)
    HookHover(MinimapZoomIn)
    HookHover(MinimapZoomOut)

    VS.minimapHooksApplied = true
end

--- Toggle visibility between the Standard LibDBIcon minimap button
-- and the custom Minimalist minimap button.
function VS:UpdateMiniMapButtonVisibility()
    if not VS.minimalistButton then
        VS:CreateMinimalistButton()
    end

    local isMinimalist = VolumeSlidersMMDB.minimap.minimalistMinimap

    if isMinimalist then
        if VS.LDBIcon:IsRegistered("Volume Sliders") then
            VS.LDBIcon:Hide("Volume Sliders")
        end

        -- Store coordinates before parenting reparent scrub
        local xOffset = VolumeSlidersMMDB.minimap.minimalistOffsetX or -35
        local yOffset = VolumeSlidersMMDB.minimap.minimalistOffsetY or -5

        if VolumeSlidersMMDB.minimap.bindToMinimap then
            VS.minimalistButton:SetParent(Minimap)
            VS:ApplyMinimapHoverHooks()
            if VS:CheckMinimapHover() then
                VS:StartHoverPolling()
            end
        else
            VS.minimalistButton:SetParent(UIParent)
            VS.minimalistButton:SetAlpha(1)
            VS.minimalistButton:SetScript("OnUpdate", nil)
        end

        -- Restore Point
        VS.minimalistButton:ClearAllPoints()
        VS.minimalistButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", xOffset, yOffset)

        VS.minimalistButton:SetFrameStrata("MEDIUM")
        VS.minimalistButton:SetFrameLevel(Minimap:GetFrameLevel() + 10)

        VS.minimalistButton:Show()
    else
        if VS.LDBIcon:IsRegistered("Volume Sliders") then
            -- We respect standard hide behavior if they have disabled the button via options.
            -- This addon historically uses `hide` for "hide completely".
            local ldbBtn = VS.LDBIcon:GetMinimapButton("Volume Sliders")
            if ldbBtn and not ldbBtn.vsPTTHooked then
                ldbBtn:HookScript("OnMouseDown", function(_, btn) VS:HandlePTT_OnMouseDown(btn) end)
                ldbBtn:HookScript("OnMouseUp", function(_, btn) VS:HandlePTT_OnMouseUp(btn) end)
                ldbBtn.vsPTTHooked = true
            end
            if not VolumeSlidersMMDB.minimap.hide then
                VS.LDBIcon:Show("Volume Sliders")
            end
        end
        VS.minimalistButton:Hide()
    end

    VS:UpdateMiniMapVolumeIcon()
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
    if not VS.session.isHardwareColdBoot and cvarName == "Sound_MasterVolume" then
        -- Update the broker display text.
        VS.VolumeSlidersObject.text = VS:GetVolumeText()

        -- Sync the Master slider if the panel is open.
        if VS.sliders and VS.sliders["Sound_MasterVolume"] then
             local val = tonumber(value) or 0
             VS.sliders["Sound_MasterVolume"]:SetValue(1 - val)
             VS.sliders["Sound_MasterVolume"].valueText:SetText(math_floor(val * 100 + 0.5) .. "%")
        end
    end
end)
