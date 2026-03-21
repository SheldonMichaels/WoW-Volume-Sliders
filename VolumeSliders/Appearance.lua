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
    local trackH = VS.currentTrackHeight or 160
    if db.showSlider then
        slider:SetHeight(trackH)
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
function VS:GetSliderHeightExtent(trackH)
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

    local hTrack = db.showSlider and (trackH or 160) or 0
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
-- Positions the footer controls side-by-side. Elements wrap dynamically
-- and flow based on the custom user ordering defined in db.footerOrder.
-------------------------------------------------------------------------------
function VS:UpdateFooterLayout()
    if not VS.container then return end

    local db = VolumeSlidersMMDB
    local p = VS.contentFrame

    -- Map keys to their widget objects
    local widgetMap = {
        ["showZoneTriggers"]  = { frame = VS.triggerCheck,           label = VS.triggerCheck and VS.triggerCheck.labelText },
        ["showFishingSplash"] = { frame = VS.fishingCheck,           label = VS.fishingCheck and VS.fishingCheck.labelText },
        ["showLfgPop"]        = { frame = VS.lfgCheck,               label = VS.lfgCheck and VS.lfgCheck.labelText },
        ["showCharacter"]     = { frame = VS.characterCheckbox,      label = VS.characterCheckbox and VS.characterCheckbox.labelText },
        ["showBackground"]    = { frame = VS.backgroundCheckbox,     label = VS.backgroundCheckbox and VS.backgroundCheckbox.labelText },
        ["showOutput"]        = { frame = VS.outputDropdown },
        ["showVoiceMode"]     = { frame = VS.voiceModeBtn },
    }

    -- Hide everything first to establish a clean state, and clear anchors
    for _, data in pairs(widgetMap) do
        if data.frame then
            data.frame:Hide()
            data.frame:ClearAllPoints()
        end
        if data.label then
            data.label:Hide()
            data.label:ClearAllPoints()
        end
    end

    local availableWidth = VS.container:GetWidth() - (VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT) - (VS.CONTENT_PADDING_X * 2)
    local footerOrder = db.footerOrder or VS.DEFAULT_FOOTER_ORDER

    local activeWidgets = {}

    for _, key in ipairs(footerOrder) do
        if db[key] then
            local data = widgetMap[key]
            if data and data.frame then
                data.frame:Show()
                if data.label then data.label:Show() end

                -- Calculate effective width
                local w = data.frame:GetWidth()
                if data.label then
                    w = w + 4 + data.label:GetStringWidth()
                end

                table.insert(activeWidgets, { key = key, data = data, width = w })
            end
        end
    end

    -- Flex wrap layout
    local rows = {}
    local currentRow = {}
    local currentWidth = 0
    local spacingX = 5

    local limitCols = db.limitFooterCols
    local maxCols = db.maxFooterCols or 3

    for _, item in ipairs(activeWidgets) do
        if #currentRow == 0 then
            table.insert(currentRow, item)
            currentWidth = item.width
        else
            local widthCondition = (currentWidth + spacingX + item.width <= availableWidth + 5)
            local countCondition = true
            if limitCols and #currentRow >= maxCols then
                countCondition = false
            end

            if widthCondition and countCondition then
                table.insert(currentRow, item)
                currentWidth = currentWidth + spacingX + item.width
            else
                table.insert(rows, { items = currentRow, width = currentWidth })
                currentRow = { item }
                currentWidth = item.width
            end
        end
    end
    if #currentRow > 0 then
        table.insert(rows, { items = currentRow, width = currentWidth })
    end

    -- Render rows bottom-up
    local currentY = VS.CONTENT_PADDING_BOTTOM + 8
    for i = #rows, 1, -1 do
        local row = rows[i]
        local numItems = #row.items
        local xPositions = {}

        if numItems == 1 then
            -- Center align
            table.insert(xPositions, (availableWidth - row.items[1].width) / 2)
        elseif numItems == 2 then
            -- Left align the first, Right align the second
            table.insert(xPositions, 0)
            table.insert(xPositions, availableWidth - row.items[2].width)
        else
            -- Evenly spaced (left aligned for all columns)
            local remainingSpace = availableWidth - row.width
            local spacing = spacingX + (remainingSpace / (numItems - 1))
            local currentX = 0
            for _, item in ipairs(row.items) do
                table.insert(xPositions, currentX)
                currentX = currentX + item.width + spacing
            end
        end

        for idx, item in ipairs(row.items) do
            local key = item.key
            local data = item.data
            local offsetX = xPositions[idx]
            local absoluteOffsetX = VS.CONTENT_PADDING_X + offsetX

            if data.label then
                -- Checkbox with right-aligned label
                data.frame:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", absoluteOffsetX, currentY)
                data.label:SetPoint("LEFT", data.frame, "RIGHT", 4, 0)
            else
                -- Standalone widget (dropdown/button with no external label)
                data.frame:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", absoluteOffsetX, currentY)
            end
        end
        -- Base widget height is ~24-26px plus margin
        currentY = currentY + 30
    end

    if #rows > 0 then
        -- The height needs to encompass `currentY` plus arbitrary padding so it doesn't overlap the slider mute/arrows above
        VS.footerCalculatedHeight = currentY + 10
    else
        VS.footerCalculatedHeight = 0
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

    -- Dynamically resize the main popup frame if it exists
    if VS.container and db.layoutDirty then

        local containerW = VS.container:GetWidth()
        local containerH = VS.container:GetHeight()

        -- Content area dimensions (inside the NineSlice border)
        local contentW = containerW - VS.TEMPLATE_CONTENT_OFFSET_LEFT - VS.TEMPLATE_CONTENT_OFFSET_RIGHT
        local contentH = containerH - VS.TEMPLATE_CONTENT_OFFSET_TOP - VS.TEMPLATE_CONTENT_OFFSET_BOTTOM

        -- Count visible sliders
        local numSliders = 0
        local cvarOrder = db.sliderOrder or VS.DEFAULT_CVAR_ORDER
        for _, cvar in ipairs(cvarOrder) do
            local var = VS.CVAR_TO_VAR[cvar]
            if var and db[var] then
                numSliders = numSliders + 1
            end
        end
        numSliders = math_max(1, numSliders) -- Avoid divide-by-zero

        -- Derive dynamic slider spacing from current width
        local usableW = contentW - (VS.SLIDER_PADDING_X * 2)
        local dynamicSpacing
        -- Pick the appropriate spacing floor based on title visibility
        local minSpacing = db.showTitle and VS.MIN_SLIDER_SPACING_TITLED or VS.MIN_SLIDER_SPACING_UNTITLED

        if numSliders > 1 then
            dynamicSpacing = (usableW - numSliders * VS.SLIDER_COLUMN_WIDTH) / (numSliders - 1)
            dynamicSpacing = math_max(minSpacing, dynamicSpacing)
        else
            dynamicSpacing = 0
        end

        -- Header height: instruction text + presets dropdown
        if VS.instructionText then
            VS.instructionText:SetShown(db.showHelpText ~= false)
        end
        local headerHeight = VS.CONTENT_PADDING_TOP
        if db.showHelpText ~= false and VS.instructionText then
            headerHeight = headerHeight + VS.instructionText:GetStringHeight() + 10
        else
            headerHeight = headerHeight + 5
        end

        if VS.presetDropdown then
            VS.presetDropdown:SetShown(db.showPresetsDropdown ~= false)
            VS.presetDropdown:ClearAllPoints()
            if db.showHelpText ~= false and VS.instructionText then
                VS.presetDropdown:SetPoint("TOP", VS.instructionText, "BOTTOM", 0, -10)
            else
                VS.presetDropdown:SetPoint("TOP", VS.contentFrame, "TOP", 0, -VS.CONTENT_PADDING_TOP)
            end
            if db.showPresetsDropdown ~= false then
                headerHeight = headerHeight + 35
            end
        end

        -- Footer layout first (to know its height)
        VS:UpdateFooterLayout()
        local footerHeight = VS.footerCalculatedHeight or 0

        -- Derive dynamic track height from remaining vertical space
        -- Use a temporary track height of 160 to compute extent sizes
        local hTop, hBottom, _ = VS:GetSliderHeightExtent(160)
        local availableVertical = contentH - headerHeight - hTop - hBottom - footerHeight
        local dynamicTrackHeight = math_max(VS.MIN_SLIDER_TRACK_HEIGHT, availableVertical)
        VS.currentTrackHeight = dynamicTrackHeight

        -- Compute minimum resize bounds
        local minW = (VS.SLIDER_PADDING_X * 2) + (numSliders * VS.SLIDER_COLUMN_WIDTH) + (math_max(0, numSliders - 1) * minSpacing)
        minW = minW + VS.TEMPLATE_CONTENT_OFFSET_LEFT + VS.TEMPLATE_CONTENT_OFFSET_RIGHT
        minW = math_max(200, minW)

        local hTopMin, hBottomMin, _ = VS:GetSliderHeightExtent(VS.MIN_SLIDER_TRACK_HEIGHT)
        local minH = headerHeight + hTopMin + VS.MIN_SLIDER_TRACK_HEIGHT + hBottomMin + footerHeight
        minH = minH + VS.TEMPLATE_CONTENT_OFFSET_TOP + VS.TEMPLATE_CONTENT_OFFSET_BOTTOM
        minH = math_max(200, minH)

        VS.container:SetResizeBounds(minW, minH)

        -- Force layout expansion if new sliders were added
        local currW = VS.container:GetWidth()
        local currH = VS.container:GetHeight()
        local needsResize = false

        if currW < minW then
            currW = minW
            needsResize = true
        end
        if currH < minH then
            currH = minH
            needsResize = true
        end

        if needsResize then
            VS.container:SetSize(currW, currH)
        end

        -- Anchor sliders with dynamic spacing and height
        local startY = -(headerHeight + hTop)
        local startX = VS.SLIDER_PADDING_X

        if VS.sliders then
            local k = 0
            for _, cvar in ipairs(cvarOrder) do
                local slider = VS.sliders[cvar]
                local var = VS.CVAR_TO_VAR[cvar]
                if slider and var then
                    if not db[var] then
                        slider:Hide()
                    else
                        slider:Show()
                        local offsetX = startX + (k * (VS.SLIDER_COLUMN_WIDTH + dynamicSpacing)) + (VS.SLIDER_COLUMN_WIDTH / 2) - 8
                        slider:ClearAllPoints()
                        slider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", offsetX, startY)
                        k = k + 1
                    end
                end
            end
        end
    end

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
            local hTop, hBottom, hTrack = VS:GetSliderHeightExtent(VS.currentTrackHeight or 160)
            local totalSliderHeight = hTop + hTrack + hBottom
            local backdropHeight = (totalSliderHeight * 0.9) + 60
            VS.previewBackdrop:SetHeight(math_max(150, backdropHeight))
        end
    end

    -- Only flag the layout as clean if we actually populated sliders this pass
    if VS.sliders and next(VS.sliders) ~= nil then
        VolumeSlidersMMDB.layoutDirty = false
    end
end

-------------------------------------------------------------------------------
function VS:FlagLayoutDirty()
    VolumeSlidersMMDB.layoutDirty = true
    if VS.container and VS.container:IsShown() then
        VS:UpdateAppearance()
    end
end

-------------------------------------------------------------------------------
-- ApplyWindowBackground
--
-- Updates the main popup window background color from saved variables.
-------------------------------------------------------------------------------
function VS:ApplyWindowBackground()
    if VS.windowBg then
        local db = VolumeSlidersMMDB
        VS.windowBg:SetColorTexture(db.bgColorR or 0.05, db.bgColorG or 0.05, db.bgColorB or 0.05, db.bgColorA or 0.95)
    end
end
