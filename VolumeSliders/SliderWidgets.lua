-------------------------------------------------------------------------------
-- SliderWidgets.lua
--
-- Slider creation factories and the generic checkbox helper.
--
-- Uses a shared CreateSliderBase() factory (Optimization 1) that builds the
-- common frame structure (track, thumb, arrows, labels, mouse wheel) used by
-- both CVar-based and Voice Chat API-based sliders.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local math_floor = math.floor
local math_ceil  = math.ceil
local math_max   = math.max
local math_min   = math.min
local tonumber   = tonumber
local GetCVar    = GetCVar
local SetCVar    = SetCVar

-------------------------------------------------------------------------------
-- CreateSliderBase  (Optimization 1 — Shared Factory)
--
-- Builds the common vertical slider frame structure shared by both
-- CVar-based and Voice Chat sliders:
--   • Slider frame with vertical orientation and hit rect expansion
--   • Three-piece track (top cap, middle fill, bottom cap) using rotated atlases
--   • Diamond thumb texture
--   • Stepper arrow buttons (▲ / ▼) with 5% snap behavior
--   • Labels: title, percentage, High, Low
--   • Mouse wheel handler (1% per tick)
--
-- The caller is responsible for wiring up:
--   • OnValueChanged behavior (CVar-based or getter/setter-based)
--   • Mute checkbox (CVar toggle or manual save/restore)
--   • RefreshValue / RefreshMute methods
--   • Tooltip (for voice sliders)
--
-- @param parent    Frame    Parent frame to attach child elements to.
-- @param name      string   Global frame name for the slider.
-- @param label     string   Display text above the slider (e.g., "Master").
-- @param tooltipText string   Optional tooltip text for the slider title.
-- @return Slider            The created slider widget (with sub-elements attached).
-------------------------------------------------------------------------------
local function CreateSliderBase(parent, name, label, tooltipText)
    local db = VolumeSlidersMMDB

    local slider = CreateFrame("Slider", name, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetHeight(db.sliderHeight or VS.SLIDER_HEIGHT)
    slider:SetWidth(20)

    -- Expand the clickable area so the user doesn't have to hit the narrow
    -- 20px track exactly.  Negative insets grow the hit rect outward.
    slider:SetHitRectInsets(-15, -15, 0, 0)

    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(0.01)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(true)

    ---------------------------------------------------------------------------
    -- Track Construction
    --
    -- The track is composed of three atlas pieces (top cap, middle fill,
    -- bottom cap) which are the horizontal MinimalSlider assets rotated 90°
    -- clockwise.  The middle piece stretches vertically between the caps.
    ---------------------------------------------------------------------------

    -- Top endcap (originally the horizontal "Left" end piece).
    local trackTop = slider:CreateTexture(nil, "BACKGROUND")
    VS:SetAtlasRotated90CW(trackTop, "Minimal_SliderBar_Left")
    trackTop:SetPoint("TOP", slider, "TOP", 0, 0)
    slider.trackTop = trackTop

    -- Bottom endcap (originally the horizontal "Right" end piece).
    local trackBottom = slider:CreateTexture(nil, "BACKGROUND")
    VS:SetAtlasRotated90CW(trackBottom, "Minimal_SliderBar_Right")
    trackBottom:SetPoint("BOTTOM", slider, "BOTTOM", 0, 0)
    slider.trackBottom = trackBottom

    -- Middle fill (stretches between cap anchors).
    local trackMiddle = slider:CreateTexture(nil, "BACKGROUND")
    local midInfo = C_Texture.GetAtlasInfo("_Minimal_SliderBar_Middle")
    if midInfo then
        trackMiddle:SetTexture(midInfo.file)
        local L, R = midInfo.leftTexCoord, midInfo.rightTexCoord
        local T, B = midInfo.topTexCoord, midInfo.bottomTexCoord
        trackMiddle:SetTexCoord(L, B, R, B, L, T, R, T)
        trackMiddle:SetWidth(midInfo.height) -- Swapped for 90° rotation
    end
    trackMiddle:SetPoint("TOP", trackTop, "BOTTOM", 0, 0)
    trackMiddle:SetPoint("BOTTOM", trackBottom, "TOP", 0, 0)
    slider.trackMiddle = trackMiddle

    -- Diamond-shaped thumb (uses the gold diamond from Boss Abilities).
    local thumb = slider:CreateTexture(name .. "Thumb", "OVERLAY")
    thumb:SetAtlas("combattimeline-pip", true)
    slider.thumb = thumb
    slider:SetThumbTexture(thumb)

    -- Force the thumb to be visible after a brief delay.  On initial frame
    -- creation the thumb texture can be hidden by the engine until the first
    -- user interaction; this timer ensures it renders immediately.
    C_Timer.After(0.05, function()
        local t = slider:GetThumbTexture()
        if t and not t:IsShown() then
            t:Show()
        end
    end)

    ---------------------------------------------------------------------------
    -- Stepper Arrow Buttons (▲ / ▼)
    --
    -- Each click snaps the volume to the nearest 5% boundary in the
    -- corresponding direction.  The 0.5 offset in the math prevents the
    -- value from "sticking" when already on a boundary.
    ---------------------------------------------------------------------------
    local STEP_PERCENT = 5

    -- Up arrow (increase volume)
    local upBtn = CreateFrame("Button", name .. "StepUp", slider)
    upBtn:SetSize(20, 20)
    local upTex = upBtn:CreateTexture(nil, "BACKGROUND")
    upTex:SetAtlas("ui-hud-minimap-zoom-in")
    upTex:SetSize(20, 20)
    upTex:SetPoint("CENTER", upBtn, "CENTER", 0, 0)
    slider.upTex = upTex
    upBtn:SetPoint("BOTTOM", slider, "TOP", 0, 4)
    upBtn:SetScript("OnClick", function()
        -- Convert from inverted slider value to real volume percentage.
        local currentPct = (1 - slider:GetValue()) * 100
        -- Snap up: ceiling to next 5% boundary (0.5 prevents sticking).
        local newPct = math_ceil((currentPct + 0.5) / STEP_PERCENT) * STEP_PERCENT
        newPct = math_min(100, math_max(0, newPct))
        -- Convert back to inverted slider value.
        slider:SetValue(1 - (newPct / 100))
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    upBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Increase Volume 5%", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    upBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Down arrow (decrease volume)
    local downBtn = CreateFrame("Button", name .. "StepDown", slider)
    downBtn:SetSize(20, 20)
    local downTex = downBtn:CreateTexture(nil, "BACKGROUND")
    downTex:SetAtlas("ui-hud-minimap-zoom-out")
    downTex:SetSize(20, 20)
    downTex:SetPoint("CENTER", downBtn, "CENTER", 0, 0)
    slider.downTex = downTex
    downBtn:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    downBtn:SetScript("OnClick", function()
        local currentPct = (1 - slider:GetValue()) * 100
        -- Snap down: floor to previous 5% boundary (0.5 prevents sticking).
        local newPct = math_floor((currentPct - 0.5) / STEP_PERCENT) * STEP_PERCENT
        newPct = math_min(100, math_max(0, newPct))
        slider:SetValue(1 - (newPct / 100))
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    downBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Decrease Volume 5%", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    downBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Store references for external repositioning if needed.
    slider.upBtn = upBtn
    slider.downBtn = downBtn

    ---------------------------------------------------------------------------
    -- Labels & Value Text
    ---------------------------------------------------------------------------

    -- "High" / "Low" endpoint labels above and below the stepper arrows.
    slider.highLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.highLabel:SetPoint("BOTTOM", slider, "TOP", 0, 26)
    slider.highLabel:SetText("High")

    slider.lowLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.lowLabel:SetPoint("TOP", slider, "BOTTOM", 0, -26)
    slider.lowLabel:SetText("Low")

    -- Numeric percentage readout above the "High" text.
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slider.valueText:SetPoint("BOTTOM", slider.highLabel, "TOP", 0, 10)
    slider.valueText:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

    -- Title label (centered above the percentage).
    slider.label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slider.label:SetPoint("BOTTOM", slider.valueText, "TOP", 0, 4)
    slider.label:SetText(label)
    slider.label:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

    if tooltipText then
        slider.label:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tooltipText, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        slider.label:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slider.label:EnableMouse(true)
    end

    ---------------------------------------------------------------------------
    -- Mouse Wheel
    --
    -- Adjusts volume in 1% increments.  Delta is inverted because slider
    -- value direction is inverted.
    ---------------------------------------------------------------------------
    slider:SetScript("OnMouseWheel", function(self, delta)
        local val = self:GetValue()
        if delta > 0 then
            self:SetValue(val - 0.01) -- Scroll up → decrease slider value → increase volume
        else
            self:SetValue(val + 0.01) -- Scroll down → increase slider value → decrease volume
        end
    end)

    return slider
end

-------------------------------------------------------------------------------
-- CreateVerticalSlider
--
-- Builds a CVar-based vertical volume slider using the shared base factory.
-- Adds CVar-specific value binding, mute checkbox, and refresh methods.
--
-- The slider uses INVERTED values: the Slider widget's value range is
-- [0, 1] where 0 corresponds to 100% volume (thumb at top) and 1
-- corresponds to 0% volume (thumb at bottom).  This is because WoW's
-- vertical Slider widget places value 0 at the top and max at the bottom,
-- but users expect "up = louder".
--
-- @param parent    Frame    Parent frame to attach child elements to.
-- @param name      string   Global frame name for the slider.
-- @param label     string   Display text (e.g., "Master").
-- @param cvar      string   Sound CVar to bind (e.g., "Sound_MasterVolume").
-- @param muteCvar  string   Enable/disable CVar for muting (e.g., "Sound_EnableAllSound").
-- @param minVal      number   Minimum slider value (typically 0).
-- @param maxVal      number   Maximum slider value (typically 1).
-- @param step        number   Slider step increment (typically 0.01 = 1%).
-- @param tooltipText string   Optional text for hovering over the volume title
-- @return Slider            The created slider widget (with extra fields attached).
-------------------------------------------------------------------------------
function VS:CreateVerticalSlider(parent, name, label, cvar, muteCvar, minVal, maxVal, step, tooltipText)
    local slider = CreateSliderBase(parent, name, label, tooltipText)

    -- Override min/max/step if the caller provides non-default values.
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)

    ---------------------------------------------------------------------------
    -- Initial Value & OnValueChanged
    --
    -- Reminder: slider value is INVERTED.  CVar 1.0 (max vol) maps to
    -- slider value 0.0; CVar 0.0 (muted) maps to slider value 1.0.
    ---------------------------------------------------------------------------
    local currentVolume = tonumber(GetCVar(cvar)) or 1
    slider:SetValue(1 - currentVolume)
    slider.valueText:SetText(math_floor(currentVolume * 100 + 0.5) .. "%")

    slider:SetScript("OnValueChanged", function(self, value)
        if self.isRefreshing then return end

        -- Un-invert the slider value to get the actual volume level.
        local invertedValue = 1 - value
        invertedValue = math_max(0, math_min(1, invertedValue))
        -- Round to two decimal places to avoid floating-point noise in CVars.
        local val = math_floor(invertedValue * 100 + 0.5) / 100

        SetCVar(cvar, val)
        self.valueText:SetText(math_floor(val * 100 + 0.5) .. "%")

        -- Keep the broker text in sync when the Master slider moves.
        if cvar == "Sound_MasterVolume" then
             if VS.VolumeSlidersObject then
                VS.VolumeSlidersObject.text = VS:GetVolumeText()
            end
        end
    end)

    ---------------------------------------------------------------------------
    -- Mute Checkbox
    --
    -- Uses SettingsCheckboxTemplate for consistent Blizzard styling.
    -- Checked = muted (CVar is 0), Unchecked = enabled (CVar is 1).
    -- This inversion matches the "mute" semantic: ticking the box silences
    -- the channel.
    ---------------------------------------------------------------------------
    local muteCheck = CreateFrame("CheckButton", name .. "Mute", slider, "SettingsCheckboxTemplate")
    muteCheck:SetSize(26, 26)
    muteCheck:SetPoint("TOP", slider, "BOTTOM", 0, -42)
    VS:DisableCheckboxHoverBackground(muteCheck)

    -- "Mute" label below the checkbox.
    local muteLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    muteLabel:SetPoint("TOP", muteCheck, "BOTTOM", 0, -2)
    muteLabel:SetText("Mute")
    muteCheck.muteLabel = muteLabel

    -- Initialize checkbox state: checked when the channel is DISABLED.
    local isEnabled = GetCVar(muteCvar) == "1"
    muteCheck:SetChecked(not isEnabled)

    muteCheck:SetScript("OnClick", function(self)
        local isMuted = self:GetChecked()
        if isMuted then
            SetCVar(muteCvar, 0) -- Disable (mute) the sound channel
        else
            SetCVar(muteCvar, 1) -- Enable (unmute) the sound channel
        end

        -- The Master channel mute also drives the minimap icon state.
        if muteCvar == "Sound_EnableAllSound" then
            VS:UpdateMiniMapVolumeIcon()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- Attach mute references to the slider for external sync access.
    slider.muteCheck = muteCheck
    slider.muteCvar = muteCvar

    slider.RefreshValue = function(self)
        local currentVol = tonumber(GetCVar(cvar)) or 1
        self.isRefreshing = true
        self:SetValue(1 - currentVol)
        self.valueText:SetText(math_floor(currentVol * 100 + 0.5) .. "%")
        self.isRefreshing = false
    end

    slider.RefreshMute = function(self)
        if self.muteCheck and self.muteCvar then
            local enabled = GetCVar(self.muteCvar) == "1"
            self.muteCheck:SetChecked(not enabled)
        end
    end

    return slider
end

-------------------------------------------------------------------------------
-- CreateVoiceSlider
--
-- Builds a Voice Chat API-based vertical slider using the shared base factory.
-- Uses custom getter/setter functions and a 0–100 scale, with optional manual
-- mute save/restore behavior.
--
-- @param parent           Frame     Parent frame.
-- @param name             string    Global frame name.
-- @param label            string    Display text (e.g., "Voice").
-- @param getterFunc       function  Returns current value (0–100 scale).
-- @param setterFunc       function  Sets value (0–100 scale).
-- @param displayInverted  boolean   If true, displayed percentage is inverted.
-- @param tooltipText      string    Optional tooltip shown on the title label.
-- @param muteKey          string    Optional key for manual mute save/restore in SavedVariables.
-- @return Slider
-------------------------------------------------------------------------------
function VS:CreateVoiceSlider(parent, name, label, getterFunc, setterFunc, displayInverted, tooltipText, muteKey)
    local slider = CreateSliderBase(parent, name, label, tooltipText)
    local db = VolumeSlidersMMDB

    ---------------------------------------------------------------------------
    -- Mute Checkbox (optional — only if muteKey is provided)
    ---------------------------------------------------------------------------
    if muteKey then
        local muteCheck = CreateFrame("CheckButton", name .. "Mute", slider, "SettingsCheckboxTemplate")
        muteCheck:SetSize(26, 26)
        muteCheck:SetPoint("TOP", slider, "BOTTOM", 0, -42)
        VS:DisableCheckboxHoverBackground(muteCheck)

        local muteLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        muteLabel:SetPoint("TOP", muteCheck, "BOTTOM", 0, -2)
        muteLabel:SetText("Mute")
        muteCheck.muteLabel = muteLabel

        slider.muteCheck = muteCheck

        slider.RefreshMute = function(self)
            muteCheck:SetChecked(db["MuteState_"..muteKey] == true)
        end

        muteCheck:SetScript("OnClick", function(self)
            local isMuted = self:GetChecked()
            db["MuteState_"..muteKey] = isMuted

            if isMuted then
                local currentRaw = getterFunc() or 100
                if currentRaw > 0 then
                   db["SavedVol_"..muteKey] = currentRaw
                end
                setterFunc(0)
            else
                local savedRaw = db["SavedVol_"..muteKey] or 100
                setterFunc(savedRaw)
            end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
    end

    ---------------------------------------------------------------------------
    -- Refresh & OnValueChanged
    ---------------------------------------------------------------------------
    slider.RefreshValue = function(self)
        local currentRaw
        if muteKey and db["MuteState_"..muteKey] then
            currentRaw = db["SavedVol_"..muteKey] or 100
        else
            currentRaw = getterFunc() or 100
        end

        local currentVol = currentRaw / 100
        if displayInverted then
            currentVol = 1.0 - currentVol
        end

        self.isRefreshing = true
        self:SetValue(1 - currentVol)
        self.valueText:SetText(math_floor(currentVol * 100 + 0.5) .. "%")
        self.isRefreshing = false
    end

    slider:SetScript("OnValueChanged", function(self, invertedValue)
        local val = 1 - invertedValue
        val = math_max(0, math_min(1, val))

        self.valueText:SetText(math_floor(val * 100 + 0.5) .. "%")

        if self.isRefreshing then return end

        local rawValue = val
        if displayInverted then
            rawValue = 1.0 - rawValue
        end

        if muteKey and slider.muteCheck and slider.muteCheck:GetChecked() then
             slider.muteCheck:SetChecked(false)
             db["MuteState_"..muteKey] = false
        end

        setterFunc(rawValue * 100)

        if muteKey then
            db["SavedVol_"..muteKey] = rawValue * 100
        end
    end)

    -- Initial value setup
    slider.isRefreshing = true
    if slider.RefreshMute then slider:RefreshMute() end
    slider:RefreshValue()
    slider.isRefreshing = false

    return slider
end

-------------------------------------------------------------------------------
-- CreateCheckbox
--
-- Generic helper to create a labeled checkbox using SettingsCheckboxTemplate.
--
-- @param parent            Frame     Parent frame.
-- @param name              string    Global frame name.
-- @param label             string    Text label displayed next to the checkbox.
-- @param onClick           function  Callback receiving (checked: boolean).
-- @param initialValueFunc  function  Returns boolean for the initial checked state.
-- @return CheckButton
-------------------------------------------------------------------------------
function VS:CreateCheckbox(parent, name, label, onClick, initialValueFunc)
    local check = CreateFrame("CheckButton", name, parent, "SettingsCheckboxTemplate")
    check:SetSize(26, 26)
    VS:DisableCheckboxHoverBackground(check)

    -- Label to the right of the checkbox.
    local checkLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 4, 0)
    checkLabel:SetText(label)
    check.labelText = checkLabel

    check:SetChecked(initialValueFunc())

    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    return check
end
