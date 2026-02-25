-------------------------------------------------------------------------------
-- Appearance.lua
--
-- Slider appearance, layout management, and visual styling functions.
--
-- Handles dynamic element anchoring, frame resizing, footer layout,
-- and knob/arrow/color style application.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local _, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local math_floor = math.floor
local math_max   = math.max
local pairs      = pairs
local ipairs     = ipairs

-------------------------------------------------------------------------------
-- UpdateSliderLayout
--
-- Dynamically re-anchors a slider's sub-elements (labels, arrows, mute
-- checkbox) based on the current visibility settings.  Each element is
-- stacked upward (above the track) or downward (below the track) with
-- conditional padding.
-------------------------------------------------------------------------------
function VS:UpdateSliderLayout(slider)
    local db = VolumeSlidersMMDB

    -- Show/hide track textures
    if db.showSlider then
        slider:SetHeight(db.sliderHeight or 160)
        slider:EnableMouse(true)
        slider.trackTop:SetAlpha(1)
        slider.trackMiddle:SetAlpha(1)
        slider.trackBottom:SetAlpha(1)
        if slider.thumb then slider.thumb:SetAlpha(1) end
    else
        slider:SetHeight(0.001)
        slider:EnableMouse(false)
        slider.trackTop:SetAlpha(0)
        slider.trackMiddle:SetAlpha(0)
        slider.trackBottom:SetAlpha(0)
        if slider.thumb then slider.thumb:SetAlpha(0) end
    end

    -- Toggle visibility flags
    if slider.label then slider.label:SetShown(db.showTitle) end
    if slider.valueText then slider.valueText:SetShown(db.showValue) end
    if slider.highLabel then slider.highLabel:SetShown(db.showHigh) end
    if slider.upBtn then slider.upBtn:SetShown(db.showUpArrow) end

    if slider.downBtn then slider.downBtn:SetShown(db.showDownArrow) end
    if slider.lowLabel then slider.lowLabel:SetShown(db.showLow) end
    if slider.muteCheck then slider.muteCheck:SetShown(db.showMute) end
    if slider.muteCheck and slider.muteCheck.muteLabel then slider.muteCheck.muteLabel:SetShown(db.showMute) end

    -- Top Half Anchoring (Building Upwards)
    local prevTop = slider
    local prevTopPoint = "TOP"

    local function AnchorTop(element, pad, overrideTop)
        element:ClearAllPoints()
        element:SetPoint("BOTTOM", prevTop, prevTopPoint, 0, pad)
        prevTop = element
        prevTopPoint = overrideTop or "TOP"
    end

    if db.showUpArrow and slider.upBtn then
        AnchorTop(slider.upBtn, 4)
    end
    if db.showHigh and slider.highLabel then
        local pad = 4
        if not db.showUpArrow and db.showSlider then pad = 8 end
        AnchorTop(slider.highLabel, pad)
    end
    if db.showValue and slider.valueText then
        AnchorTop(slider.valueText, 10)
    end
    if db.showTitle and slider.label then
        AnchorTop(slider.label, 4)
    end

    -- Bottom Half Anchoring (Building Downwards)
    local prevBottom = slider
    local prevBottomPoint = "BOTTOM"

    local function AnchorBottom(element, pad, overrideBottom)
        element:ClearAllPoints()
        element:SetPoint("TOP", prevBottom, prevBottomPoint, 0, -pad)
        prevBottom = element
        prevBottomPoint = overrideBottom or "BOTTOM"
    end

    if db.showDownArrow and slider.downBtn then
        AnchorBottom(slider.downBtn, 4)
    end
    if db.showLow and slider.lowLabel then
        local pad = 4
        if not db.showDownArrow and db.showSlider then pad = 8 end
        AnchorBottom(slider.lowLabel, pad)
    end
    if db.showMute and slider.muteCheck then
        AnchorBottom(slider.muteCheck, 8)

        -- Re-link Mute text below the checkbox
        if slider.muteCheck.muteLabel then
            slider.muteCheck.muteLabel:ClearAllPoints()
            slider.muteCheck.muteLabel:SetPoint("TOP", slider.muteCheck, "BOTTOM", 0, -2)
        end
    end
end

-------------------------------------------------------------------------------
-- GetSliderHeightExtent
--
-- Calculates the vertical pixels required above and below a slider track
-- based on the currently visible components.
-------------------------------------------------------------------------------
function VS:GetSliderHeightExtent()
    local db = VolumeSlidersMMDB
    local hTop = 0
    local hBottom = 0

    if db.showUpArrow then hTop = hTop + 20 + 4 end
    if db.showHigh then
        local pad = db.showUpArrow and 4 or (db.showSlider and 8 or 0)
        hTop = hTop + 15 + pad
    end
    if db.showValue then hTop = hTop + 15 + 10 end
    if db.showTitle then hTop = hTop + 15 + 4 end

    if db.showDownArrow then hBottom = hBottom + 20 + 4 end
    if db.showLow then
        local pad = db.showDownArrow and 4 or (db.showSlider and 8 or 0)
        hBottom = hBottom + 15 + pad
    end
    if db.showMute then hBottom = hBottom + 26 + 8 + 15 + 2 end -- Check (26) + Pad (8) + Label (15) + Gap (2)

    local hTrack = db.showSlider and (db.sliderHeight or 160) or 0
    return hTop, hBottom, hTrack
end

-------------------------------------------------------------------------------
-- ApplySliderAppearance
--
-- Applies the selected knob, arrow, and text color styles to an individual
-- slider widget, then updates its dynamic anchoring layout.
-------------------------------------------------------------------------------
function VS:ApplySliderAppearance(slider, knobSelected, arrowSelected, titleSelected, valueSelected, highSelected, lowSelected)
    -- Update Knob
    if knobSelected == 1 then
        slider.thumb:SetAtlas("combattimeline-pip", true)
    elseif knobSelected == 2 then
        slider.thumb:SetAtlas("Minimal_SliderBar_Button", true)
    end

    -- Update Arrows
    -- Clear standard texture paths and specific anchors before reapplying.
    slider.upTex:SetTexture(nil)
    slider.upTex:SetTexCoord(0, 1, 0, 1) -- Reset any previous rotation
    slider.upTex:SetDesaturated(false)    -- Reset any previous color filtering
    slider.upTex:ClearAllPoints()
    slider.upTex:SetPoint("CENTER", slider.upBtn, "CENTER", 0, 0)

    slider.downTex:SetTexture(nil)
    slider.downTex:SetTexCoord(0, 1, 0, 1) -- Reset any previous rotation
    slider.downTex:SetDesaturated(false)    -- Reset any previous color filtering
    slider.downTex:ClearAllPoints()
    slider.downTex:SetPoint("CENTER", slider.downBtn, "CENTER", 0, 0)

    if arrowSelected == 1 then
        -- Zoom arrows (Plus/Minus)
        slider.upTex:SetAtlas("ui-hud-minimap-zoom-in")
        slider.upBtn:SetSize(20, 20)
        slider.upTex:SetSize(20, 20)

        slider.downTex:SetAtlas("ui-hud-minimap-zoom-out")
        slider.downBtn:SetSize(20, 20)
        slider.downTex:SetSize(20, 20)
    elseif arrowSelected == 2 then
        -- Gold arrows
        slider.upTex:SetAtlas("ui-hud-actionbar-pageuparrow-up")
        slider.upBtn:SetSize(17, 14)
        slider.upTex:SetSize(17, 14)

        slider.downTex:SetAtlas("ui-hud-actionbar-pagedownarrow-up")
        slider.downBtn:SetSize(17, 14)
        slider.downTex:SetSize(17, 14)
    elseif arrowSelected == 3 then
        -- Silver arrows
        slider.upBtn:SetSize(19, 11)
        VS:SetAtlasRotated90CW(slider.upTex, "Minimal_SliderBar_Button_Left")

        slider.upTex:ClearAllPoints()
        slider.upTex:SetPoint("CENTER", slider.upBtn, "CENTER", 1, -1) -- Shift right to center visually

        slider.downBtn:SetSize(19, 11)
        VS:SetAtlasRotated90CW(slider.downTex, "Minimal_SliderBar_Button_Right")

        slider.downTex:ClearAllPoints()
        slider.downTex:SetPoint("CENTER", slider.downBtn, "CENTER", -1, -3) -- Shift left, and shift down to stop overlapping track
    elseif arrowSelected == 4 then
        -- Silver Plus/Minus (zoom icons using desaturation)
        slider.upTex:SetAtlas("ui-hud-minimap-zoom-in")
        slider.upTex:SetDesaturated(true)
        slider.upBtn:SetSize(20, 20)
        slider.upTex:SetSize(20, 20)

        slider.downTex:SetAtlas("ui-hud-minimap-zoom-out")
        slider.downTex:SetDesaturated(true)
        slider.downBtn:SetSize(20, 20)
        slider.downTex:SetSize(20, 20)
    end

    -- Update Text Colors
    local function ApplyColor(fontString, colorType)
        if fontString then
            if colorType == 1 then
                fontString:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
            else
                fontString:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            end
        end
    end

    ApplyColor(slider.label, titleSelected)
    ApplyColor(slider.valueText, valueSelected)
    ApplyColor(slider.highLabel, highSelected)
    ApplyColor(slider.lowLabel, lowSelected)

    -- Finally, update dynamic anchoring layout
    VS:UpdateSliderLayout(slider)
end

-------------------------------------------------------------------------------
-- UpdateFooterLayout
--
-- Positions the footer controls (Character checkbox, Background checkbox,
-- Output dropdown, Voice Mode toggle) within the popup frame.  Uses a
-- side-by-side layout when width permits, otherwise stacks vertically.
-------------------------------------------------------------------------------
function VS:UpdateFooterLayout()
    if not VS.container then return end

    local charCheck = VS.characterCheckbox
    local bgCheck = VS.backgroundCheckbox
    local outputLabel = VS.outputLabel
    local dropdown = VS.outputDropdown

    if charCheck and charCheck.labelText and bgCheck and outputLabel and dropdown then
        local db = VolumeSlidersMMDB

        -- Update visibility
        charCheck:SetShown(db.showCharacter)
        charCheck.labelText:SetShown(db.showCharacter)
        bgCheck:SetShown(db.showBackground)
        bgCheck.labelText:SetShown(db.showBackground)
        outputLabel:SetShown(db.showOutput)
        dropdown:SetShown(db.showOutput)
        if VS.voiceModeLabel then VS.voiceModeLabel:SetShown(db.showVoiceMode) end
        if VS.voiceModeBtn then VS.voiceModeBtn:SetShown(db.showVoiceMode) end

        -- Measure content widths
        local charWidth = (db.showCharacter and charCheck.labelText) and (charCheck:GetWidth() + 4 + charCheck.labelText:GetStringWidth()) or 0
        local bgWidth = (db.showBackground and bgCheck.labelText) and (bgCheck:GetWidth() + 4 + bgCheck.labelText:GetStringWidth()) or 0
        local outputWidth = (db.showOutput and outputLabel and dropdown) and (outputLabel:GetStringWidth() + 5 + dropdown:GetWidth()) or 0
        local voiceModeWidth = (db.showVoiceMode and VS.voiceModeLabel and VS.voiceModeBtn) and (VS.voiceModeLabel:GetStringWidth() + 5 + VS.voiceModeBtn:GetWidth()) or 0

        local leftWidth = math_max(charWidth, bgWidth)
        local rightWidth = math_max(outputWidth, voiceModeWidth)
        local hasLeft = db.showCharacter or db.showBackground
        local hasRight = db.showOutput or db.showVoiceMode

        local stackedWidth
        if hasLeft and hasRight then stackedWidth = leftWidth + 25 + rightWidth
        elseif hasLeft then stackedWidth = leftWidth
        else stackedWidth = rightWidth end

        local availableWidth = VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - (VS.CONTENT_PADDING_X * 2)

        -- Clear all existing anchors before re-laying-out
        charCheck:ClearAllPoints()
        bgCheck:ClearAllPoints()
        outputLabel:ClearAllPoints()
        dropdown:ClearAllPoints()
        if VS.voiceModeLabel then
            VS.voiceModeLabel:ClearAllPoints()
            VS.voiceModeBtn:ClearAllPoints()
        end

        if hasLeft and hasRight and stackedWidth <= availableWidth then
            -- Partial: Side-by-side blocks
            local offsetX = (VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - stackedWidth) / 2

            local rightY = VS.CONTENT_PADDING_BOTTOM + 25
            if db.showVoiceMode and VS.voiceModeLabel then
                VS.voiceModeLabel:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX + leftWidth + 25, rightY)
                rightY = rightY + 26
            end
            if db.showOutput then
                outputLabel:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX + leftWidth + 25, rightY)
            end

            local leftY = VS.CONTENT_PADDING_BOTTOM + 15
            if db.showCharacter then
                charCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, leftY)
                leftY = leftY + 26
            end
            if db.showBackground then
                bgCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, leftY)
            end
        else
            -- Stacked: blocks are vertically stacked building upward
            local currentY = VS.CONTENT_PADDING_BOTTOM + 15

            if db.showCharacter then
                local offsetX = (VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - charWidth) / 2
                charCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, currentY)
                currentY = currentY + 26
            end
            if db.showBackground then
                local offsetX = (VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - bgWidth) / 2
                bgCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, currentY)
                currentY = currentY + 26
            end
            if hasLeft and hasRight then
                currentY = currentY + 10 -- gap between blocks
            end
            if db.showVoiceMode and VS.voiceModeLabel then
                local offsetX = (VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - voiceModeWidth) / 2
                VS.voiceModeLabel:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, currentY)
                currentY = currentY + 26
            end
            if db.showOutput then
                local offsetX = (VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - outputWidth) / 2
                outputLabel:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, currentY)
            end
        end

        if db.showOutput then
            dropdown:SetPoint("LEFT", outputLabel, "RIGHT", 5, 0)
        end
        if db.showVoiceMode and VS.voiceModeBtn then
            VS.voiceModeBtn:SetPoint("LEFT", VS.voiceModeLabel, "RIGHT", 5, 0)
        end
    end
end

-------------------------------------------------------------------------------
-- UpdateAppearance
--
-- Retrieves stored options state and updates the appearances of all
-- active slider UI elements in bulk.  Also dynamically resizes the main
-- popup frame based on visible slider count and layout configuration.
-------------------------------------------------------------------------------
function VS:UpdateAppearance()
    local db = VolumeSlidersMMDB
    local knobSelected  = db.knobStyle or 1
    local arrowSelected = db.arrowStyle or 1
    local titleSelected = db.titleColor or 1
    local valueSelected = db.valueColor or 1
    local highSelected  = db.highColor or 2
    local lowSelected   = db.lowColor or 2

    -- Update main panel sliders visibility and layout
    if VS.sliders then
        for _, slider in pairs(VS.sliders) do
            VS:ApplySliderAppearance(slider, knobSelected, arrowSelected, titleSelected, valueSelected, highSelected, lowSelected)
        end
    end

    -- Update the preview slider if it exists
    if VS.previewSlider then
        VS:ApplySliderAppearance(VS.previewSlider, knobSelected, arrowSelected, titleSelected, valueSelected, highSelected, lowSelected)

        -- Update preview backdrop height if it exists
        if VS.previewBackdrop then
            local hTop, hBottom, hTrack = VS:GetSliderHeightExtent()
            local totalSliderHeight = hTop + hTrack + hBottom
            local backdropHeight = (totalSliderHeight * 0.9) + 60
            VS.previewBackdrop:SetHeight(math_max(150, backdropHeight))
        end
    end

    -- Dynamically resize the main popup frame if it exists
    if VS.container then
        local hTop, hBottom, hTrack = VS:GetSliderHeightExtent()

        -- Header: Padding (15) + Instruction (15) + Gap (10)
        local headerHeight = 40
        -- Footer height calculation based on visibility and layout stacking
        local footerHeight = 0
        if db.showCharacter or db.showBackground or db.showOutput or db.showVoiceMode then
            footerHeight = 15 -- Initial top gap
            local charCheck = VS.characterCheckbox
            local bgCheck = VS.backgroundCheckbox
            local outputLabel = VS.outputLabel
            local dropdown = VS.outputDropdown

            local charWidth = (db.showCharacter and charCheck and charCheck.labelText) and (charCheck:GetWidth() + 4 + charCheck.labelText:GetStringWidth()) or 0
            local bgWidth = (db.showBackground and bgCheck and bgCheck.labelText) and (bgCheck:GetWidth() + 4 + bgCheck.labelText:GetStringWidth()) or 0
            local outputWidth = (db.showOutput and outputLabel and dropdown) and (outputLabel:GetStringWidth() + 5 + dropdown:GetWidth()) or 0
            local voiceModeWidth = (db.showVoiceMode and VS.voiceModeLabel and VS.voiceModeBtn) and (VS.voiceModeLabel:GetStringWidth() + 5 + VS.voiceModeBtn:GetWidth()) or 0

            local leftWidth = math_max(charWidth, bgWidth)
            local rightWidth = math_max(outputWidth, voiceModeWidth)
            local hasLeft = db.showCharacter or db.showBackground
            local hasRight = db.showOutput or db.showVoiceMode

            local leftHeight = 0
            if db.showCharacter and db.showBackground then leftHeight = 55
            elseif db.showCharacter or db.showBackground then leftHeight = 25 end

            local rightHeight = 0
            if db.showOutput and db.showVoiceMode then rightHeight = 72
            elseif db.showOutput or db.showVoiceMode then rightHeight = 36 end

            -- Estimate layout state before applying it
            local spacing = db.sliderSpacing or 10
            local i = 0

            local cvarOrder = db.sliderOrder or VS.DEFAULT_CVAR_ORDER

            for _, cvar in ipairs(cvarOrder) do
                local var = VS.CVAR_TO_VAR[cvar]
                if var and db[var] then
                    i = i + 1
                end
            end

            local visibleWidth = (VS.CONTENT_PADDING_X * 2) + (i * VS.SLIDER_COLUMN_WIDTH) + (math_max(0, i - 1) * spacing)
            local availableWidth = visibleWidth - (VS.CONTENT_PADDING_X * 2)

            local stackedWidth
            if hasLeft and hasRight then stackedWidth = leftWidth + 25 + rightWidth
            elseif hasLeft then stackedWidth = leftWidth
            else stackedWidth = rightWidth end

            if hasLeft and hasRight and stackedWidth <= availableWidth then
                -- Partial (blocks side-by-side)
                footerHeight = footerHeight + math_max(leftHeight, rightHeight)
            else
                -- Fully stacked vertically OR single column
                footerHeight = footerHeight + leftHeight + rightHeight
                if hasLeft and hasRight then
                    footerHeight = footerHeight + 10 -- gap between blocks
                end
            end

            footerHeight = footerHeight + 15 -- Bottom padding
        end

        local contentHeight = headerHeight + hTop + hTrack + hBottom + footerHeight
        local frameHeight = contentHeight + VS.TEMPLATE_CONTENT_OFFSET_TOP + VS.TEMPLATE_CONTENT_OFFSET_BOTTOM

        VS.container:SetHeight(frameHeight)

        -- Adjust startY so the sliders are pushed up when labels are hidden
        local startY = -(headerHeight + hTop)

        -- Re-anchor all active sliders to the new dynamic startY
        if VS.sliders then
            local startX = VS.CONTENT_PADDING_X
            local i = 0
            local spacing = db.sliderSpacing or 10

            local cvarOrder = db.sliderOrder or VS.DEFAULT_CVAR_ORDER

            for _, cvar in ipairs(cvarOrder) do
                local slider = VS.sliders[cvar]
                local var = VS.CVAR_TO_VAR[cvar]
                if slider and var then
                    if not db[var] then
                        slider:Hide()
                    else
                        slider:Show()
                        local offsetX = startX + (i * (VS.SLIDER_COLUMN_WIDTH + spacing)) + (VS.SLIDER_COLUMN_WIDTH / 2) - 8
                        slider:ClearAllPoints()
                        slider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", offsetX, startY)
                        i = i + 1
                    end
                end
            end

            -- Dynamically adjust frame width based on visible sliders
            local visibleWidth = (VS.CONTENT_PADDING_X * 2)
                + (i * VS.SLIDER_COLUMN_WIDTH)
                + (math_max(0, i - 1) * spacing)
            -- A minimum width to guarantee elements like the footer don't clip drastically
            local frameWidth = math_max(300, visibleWidth + VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT)
            VS.container:SetWidth(frameWidth)
        end

        -- Update footer elements visibility and layout
        VS:UpdateFooterLayout()
    end
end

-------------------------------------------------------------------------------
-- RefreshTextInputs
--
-- Syncs the height and spacing text input boxes to the current saved values.
-- Called when the settings panel is shown to ensure the displayed values
-- match the actual state.
-------------------------------------------------------------------------------
function VS:RefreshTextInputs()
    local db = VolumeSlidersMMDB
    local heightInput = _G["VolumeSlidersHeightInput"]
    local spacingInput = _G["VolumeSlidersSpacingInput"]

    if heightInput then
        heightInput:SetText(tostring(db.sliderHeight or 150))
        heightInput:SetCursorPosition(0)
    end
    if spacingInput then
        spacingInput:SetText(tostring(db.sliderSpacing or 10))
        spacingInput:SetCursorPosition(0)
    end
end
