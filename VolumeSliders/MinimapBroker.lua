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

--- Locate the minimap button created by LibDBIcon and the custom minimalist button
--- and update their icon textures to reflect the current mute state.
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

-----------------------------------------
-- Hover Evaluation Helper
-----------------------------------------
local hoverTimer = 0
local function HoverPolling_OnUpdate(self, elapsed)
    hoverTimer = hoverTimer + elapsed
    if hoverTimer > 0.15 then
        hoverTimer = 0
        VS:CheckMinimapHover()
    end
end

function VS:StartHoverPolling()
    if not VolumeSlidersMMDB.minimalistMinimap or not VS.minimalistButton or not VolumeSlidersMMDB.bindToMinimap then return end
    
    VS.minimalistButton:SetAlpha(1)
    if VS.minimalistButton:GetScript("OnUpdate") ~= HoverPolling_OnUpdate then
        hoverTimer = 0
        VS.minimalistButton:SetScript("OnUpdate", HoverPolling_OnUpdate)
    end
end

function VS:CheckMinimapHover()
    if not VolumeSlidersMMDB.minimalistMinimap or not VS.minimalistButton or not VolumeSlidersMMDB.bindToMinimap then 
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

-----------------------------------------
-- Minimalist Minimap Icon implementation
-----------------------------------------
function VS:CreateMinimalistButton()
    if VS.minimalistButton then return end
    
    -- We use a plain Frame instead of a Button! This completely blinds third-party Minimap
    -- skinning addons (SexyMap, ElvUI, etc.) which aggressively scan for "Button" objects and ruin their textures.
    local btn = CreateFrame("Frame", "VS_MinimalistSpeakerBtn", Minimap)
    btn:SetSize(17, 17)
    
    -- Hidden by default until mouseover (if bound)
    if VolumeSlidersMMDB.bindToMinimap then
        btn:SetParent(Minimap)
        btn:SetAlpha(0)
    else
        btn:SetParent(UIParent)
        btn:SetAlpha(1)
    end
    
    local xOffset = VolumeSlidersMMDB.minimalistOffsetX or -35
    local yOffset = VolumeSlidersMMDB.minimalistOffsetY or -5
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
    end)
    btn:SetScript("OnMouseUp", function(self, button)
        self.minimalistIcon:SetPoint("CENTER", self, "CENTER", 0, 0)
        self.shadow:SetPoint("CENTER", self, "CENTER", 1, -1)
        
        -- We handle clicks here now since Frames don't have OnClick
        if not self.isMoving and self:IsMouseOver() then
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
        end
    end)
    
    -- Ensure the interactive hit rect maintains its intended 17x17 size
    btn:SetSize(17, 17)
    
    btn:EnableMouse(true)
    btn:EnableMouseWheel(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    
    btn:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
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
            
            VolumeSlidersMMDB.minimalistOffsetX = rawX
            VolumeSlidersMMDB.minimalistOffsetY = rawY
            
            -- Re-lock the anchor formally so resizing the screen doesn't skew it
            self:ClearAllPoints()
            self:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", rawX, rawY)
        end
    end)
    
    btn:SetScript("OnMouseWheel", function(self, delta)
        VS:AdjustVolume(delta)
    end)
    
    btn:SetScript("OnEnter", function(self)
        VS:StartHoverPolling()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Volume Sliders", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Left click|r to open slider panel")
        GameTooltip:AddLine("|cff00ff00Right click|r to mute/unmute all audio")
        GameTooltip:AddLine("|cff00ff00Shift+Drag|r to move icon")
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    local function HookHover(frame)
        if not frame then return end
        frame:HookScript("OnEnter", function() VS:StartHoverPolling() end)
    end

    HookHover(Minimap)
    HookHover(Minimap.ZoomIn)
    HookHover(Minimap.ZoomOut)
    HookHover(MinimapZoomIn)
    HookHover(MinimapZoomOut)
    
    VS.minimalistButton = btn
end

--- Toggle visibility between the Standard LibDBIcon minimap button
--- and the custom Minimalist minimap button.
function VS:UpdateMiniMapButtonVisibility()
    if not VS.minimalistButton then
        VS:CreateMinimalistButton()
    end
    
    local isMinimalist = VolumeSlidersMMDB.minimalistMinimap
    
    if isMinimalist then
        if VS.LDBIcon:IsRegistered("Volume Sliders") then
            VS.LDBIcon:Hide("Volume Sliders")
        end
        
        -- Store coordinates before parenting reparent scrub
        local xOffset = VolumeSlidersMMDB.minimalistOffsetX or -35
        local yOffset = VolumeSlidersMMDB.minimalistOffsetY or -5
        
        if VolumeSlidersMMDB.bindToMinimap then
            VS.minimalistButton:SetParent(Minimap)
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
            if not VolumeSlidersMMDB.hide then
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
    if cvarName == "Sound_MasterVolume" then
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
