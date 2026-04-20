-------------------------------------------------------------------------------
-- Settings_Window.lua
--
-- Builds the "Window Settings" subcategory UI.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local addonName, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local _G = _G
local math_floor = math.floor
local tonumber   = tonumber
local tostring   = tostring
local ipairs     = ipairs
local wipe       = wipe
local table_insert = table.insert

-------------------------------------------------------------------------------
-- CreateWindowSettingsContents
--
-- Builds the "Window Settings" subcategory UI.
--
-- COMPONENT PARTS:
-- 1. Behavior: Persistent window toggle.
-- 2. Visuals: Background color swatch and opacity slider.
-- 3. Header: Visibility toggles for help text and presets list.
-- 4. Channel List: A Drag-and-Drop ScrollBox for reordering sound channels.
-- 5. Footer List: A Drag-and-Drop ScrollBox for reordering footer controls.
--
-- @param parentFrame Frame The canvas frame provided by Blizzard Settings API.
-------------------------------------------------------------------------------
function VS:CreateWindowSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB

    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersWindowSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

    local categoryFrame = CreateFrame("Frame", "VolumeSlidersWindowSettingsContentFrame", scrollFrame)
    categoryFrame:SetSize(600, 650)
    scrollFrame:SetScrollChild(categoryFrame)

    -- Initial dummy resize, overwritten at end of function for dynamic columns
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Window Settings")

    local desc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Customize the elements and structure of the main slider window.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Persistent Window
    ---------------------------------------------------------------------------
    -- Deduped: Now using shared VS:AddTooltip(frame, text)

    local windowBehaviorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    windowBehaviorLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 245, -20)
    windowBehaviorLabel:SetText("Window Behavior")

    local persistentCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    persistentCheck:SetPoint("TOPLEFT", windowBehaviorLabel, "BOTTOMLEFT", -5, -5)
    persistentCheck.text:SetText("Persistent Window")
    persistentCheck:SetChecked(db.toggles.persistentWindow == true)
    persistentCheck:SetScript("OnClick", function(self)
        db.toggles.persistentWindow = self:GetChecked()
    end)
    VS:AddTooltip(persistentCheck, "When enabled, the slider window stays open when clicking outside.\nUse Escape or the X button to close.")

    local persistentDivider = categoryFrame:CreateTexture(nil, "ARTWORK")
    persistentDivider:SetHeight(1)
    persistentDivider:SetPoint("TOPLEFT", persistentCheck, "BOTTOMLEFT", -20, -15)
    persistentDivider:SetWidth(400)
    persistentDivider:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Window Background Color
    ---------------------------------------------------------------------------
    local bgColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bgColorLabel:SetPoint("TOPLEFT", persistentDivider, "BOTTOMLEFT", 25, -20)
    bgColorLabel:SetText("Window Background")

    -- Color Swatch Button
    local colorSwatch = CreateFrame("Button", nil, categoryFrame)
    colorSwatch:SetSize(20, 20)
    colorSwatch:SetPoint("TOPLEFT", bgColorLabel, "BOTTOMLEFT", 0, -8)

    local swatchBorder = colorSwatch:CreateTexture(nil, "BORDER")
    swatchBorder:SetAllPoints()
    swatchBorder:SetColorTexture(1, 1, 1, 0.8)

    local swatchInner = colorSwatch:CreateTexture(nil, "ARTWORK")
    swatchInner:SetPoint("TOPLEFT", 1, -1)
    swatchInner:SetPoint("BOTTOMRIGHT", -1, 1)
    swatchInner:SetColorTexture(db.appearance.bgColor.r or 0.05, db.appearance.bgColor.g or 0.05, db.appearance.bgColor.b or 0.05, 1)

    local colorText = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colorText:SetPoint("LEFT", colorSwatch, "RIGHT", 8, 0)
    colorText:SetText("Click to change")

    ---@diagnostic disable: undefined-global
    colorSwatch:SetScript("OnClick", function()
        local info = {}
        info.r = db.appearance.bgColor.r or 0.05
        info.g = db.appearance.bgColor.g or 0.05
        info.b = db.appearance.bgColor.b or 0.05
        info.opacity = 1 - (db.appearance.bgColor.a or 0.95) -- ColorPickerFrame uses inverted opacity
        info.hasOpacity = true
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            db.appearance.bgColor.r = r
            db.appearance.bgColor.g = g
            db.appearance.bgColor.b = b
            swatchInner:SetColorTexture(r, g, b, 1)
            VS:ApplyWindowBackground()
        end
        info.opacityFunc = function()
            local a = 1 - ColorPickerFrame:GetColorAlpha()
            db.appearance.bgColor.a = a
            VS:ApplyWindowBackground()
        end
        info.cancelFunc = function(previousValues)
            db.appearance.bgColor.r = previousValues.r
            db.appearance.bgColor.g = previousValues.g
            db.appearance.bgColor.b = previousValues.b
            db.appearance.bgColor.a = 1 - (previousValues.a or 0.05)
            swatchInner:SetColorTexture(db.appearance.bgColor.r, db.appearance.bgColor.g, db.appearance.bgColor.b, 1)
            VS:ApplyWindowBackground()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    VS:AddTooltip(colorSwatch, "Click to choose a background color for the slider window.")
    ---@diagnostic enable: undefined-global

    -- Opacity Slider
    local opacityLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityLabel:SetPoint("LEFT", colorText, "RIGHT", 30, 0)
    opacityLabel:SetText("Opacity")

    local opacitySlider = CreateFrame("Slider", "VolumeSlidersOpacitySlider", categoryFrame, "OptionsSliderTemplate")
    opacitySlider:SetPoint("LEFT", opacityLabel, "RIGHT", 15, 0)
    opacitySlider:SetWidth(120)
    opacitySlider:SetMinMaxValues(0, 100)
    opacitySlider:SetValueStep(1)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider:SetValue(math_floor((db.appearance.bgColor.a or 0.95) * 100 + 0.5))
    if _G["VolumeSlidersOpacitySliderLow"] then _G["VolumeSlidersOpacitySliderLow"]:Hide() end
    if _G["VolumeSlidersOpacitySliderHigh"] then _G["VolumeSlidersOpacitySliderHigh"]:Hide() end
    if _G["VolumeSlidersOpacitySliderText"] then _G["VolumeSlidersOpacitySliderText"]:Hide() end

    local opacityValueText = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityValueText:SetPoint("LEFT", opacitySlider, "RIGHT", 8, 0)
    opacityValueText:SetText(tostring(math_floor((db.appearance.bgColor.a or 0.95) * 100 + 0.5)) .. "%")

    opacitySlider:SetScript("OnValueChanged", function(self, value)
        local num = math_floor(value + 0.5)
        self:SetValue(num)
        db.appearance.bgColor.a = num / 100
        opacityValueText:SetText(tostring(num) .. "%")
        VS:ApplyWindowBackground()
    end)
    VS:AddTooltip(opacitySlider, "Adjust the background opacity of the slider window.\n0% = fully transparent, 100% = fully opaque")

    ---------------------------------------------------------------------------
    -- Vertical Divider
    ---------------------------------------------------------------------------
    local dividerV = categoryFrame:CreateTexture(nil, "ARTWORK")
    dividerV:SetWidth(1)
    dividerV:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 220, -10)
    dividerV:SetPoint("BOTTOMLEFT", categoryFrame, "TOPLEFT", 220, -600)
    dividerV:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Visibility Checkboxes (Window Header Elements)
    ---------------------------------------------------------------------------
    local dividerBgH = categoryFrame:CreateTexture(nil, "ARTWORK")
    dividerBgH:SetHeight(1)
    dividerBgH:SetPoint("TOPLEFT", bgColorLabel, "BOTTOMLEFT", -25, -45)
    dividerBgH:SetWidth(400)
    dividerBgH:SetColorTexture(1, 1, 1, 0.2)

    local headerElementsLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerElementsLabel:SetPoint("TOPLEFT", dividerBgH, "BOTTOMLEFT", 25, -20)
    headerElementsLabel:SetText("Header Elements")

    local helpTextCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    helpTextCheck:SetPoint("TOPLEFT", headerElementsLabel, "BOTTOMLEFT", -5, -5)
    helpTextCheck.text:SetText("Help Text")
    helpTextCheck:SetChecked(db.toggles.showHelpText ~= false)
    helpTextCheck:SetScript("OnClick", function(self)
        db.toggles.showHelpText = self:GetChecked()
        VS:UpdateAppearance()
    end)
    VS:AddTooltip(helpTextCheck, "Show or hide the help instructions at the top.")

    local presetCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    presetCheck:SetPoint("LEFT", helpTextCheck.text, "RIGHT", 40, 0)
    presetCheck.text:SetText("Presets Dropdown")
    presetCheck:SetChecked(db.toggles.showPresetsDropdown ~= false)
    presetCheck:SetScript("OnClick", function(self)
        db.toggles.showPresetsDropdown = self:GetChecked()
        VS:UpdateAppearance()
    end)
    VS:AddTooltip(presetCheck, "Show or hide the quick-apply presets dropdown at the top.")

    local dividerH = categoryFrame:CreateTexture(nil, "ARTWORK")
    dividerH:SetHeight(1)
    dividerH:SetPoint("TOPLEFT", headerElementsLabel, "BOTTOMLEFT", -25, -45)
    dividerH:SetWidth(400)
    dividerH:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Channel Visibility
    ---------------------------------------------------------------------------
    local channelLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 15, -20)
    channelLabel:SetText("Channel Visibility")

    local channelSubLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelSubLabel:SetPoint("TOP", channelLabel, "BOTTOM", 0, -2)
    channelSubLabel:SetText("(Drag to Reorder)")
    channelSubLabel:SetAlpha(0.6)

    local channelMap = {
        ["Sound_MasterVolume"] = { name = "Master Slider", var = "Sound_MasterVolume", namespace = "channels", tooltip = "Show or hide the Master volume slider." },
        ["Sound_SFXVolume"] = { name = "SFX Slider", var = "Sound_SFXVolume", namespace = "channels", tooltip = "Show or hide the Sound Effects volume slider." },
        ["Sound_MusicVolume"] = { name = "Music Slider", var = "Sound_MusicVolume", namespace = "channels", tooltip = "Show or hide the Music volume slider." },
        ["Sound_AmbienceVolume"] = { name = "Ambience Slider", var = "Sound_AmbienceVolume", namespace = "channels", tooltip = "Show or hide the Ambience volume slider." },
        ["Sound_DialogVolume"] = { name = "Dialog Slider", var = "Sound_DialogVolume", namespace = "channels", tooltip = "Show or hide the Dialog volume slider." },
        ["Sound_GameplaySFX"] = { name = "Gameplay Slider", var = "Sound_GameplaySFX", namespace = "channels", tooltip = "Show or hide the Gameplay volume slider (combat rotational acoustics)." },
        ["Sound_PingVolume"] = { name = "Pings Slider", var = "Sound_PingVolume", namespace = "channels", tooltip = "Show or hide the Ping System volume slider." },
        ["Sound_EncounterWarningsVolume"] = { name = "Warnings Slider", var = "Sound_EncounterWarningsVolume", namespace = "channels", tooltip = "Show or hide the dedicated slider for Encounter Warnings (combat alerts)." },
        ["Voice_ChatVolume"] = { name = "Voice Volume Slider", var = "Voice_ChatVolume", namespace = "channels", tooltip = "Show or hide the Voice Chat Volume slider." },
        ["Voice_ChatDucking"] = { name = "Voice Ducking Slider", var = "Voice_ChatDucking", namespace = "channels", tooltip = "Show or hide the Voice Chat Ducking slider." },
        ["Voice_MicVolume"] = { name = "Mic Volume Slider", var = "Voice_MicVolume", namespace = "channels", tooltip = "Show or hide the Microphone Volume slider." },
        ["Voice_MicSensitivity"] = { name = "Mic Sensitivity Slider", var = "Voice_MicSensitivity", namespace = "channels", tooltip = "Show or hide the Microphone Sensitivity slider." },
    }

    local scrollBox = CreateFrame("Frame", nil, categoryFrame, "WowScrollBoxList")
    scrollBox:SetSize(145, 480)
    scrollBox:SetPoint("TOPLEFT", channelSubLabel, "BOTTOMLEFT", -5, -8)

    local dragBehavior -- Forward declare for access in RowInitializer
    
    --- Initializes a single row within the Channel Visibility list.
    -- @param frame Frame The row template frame.
    -- @param elementData string The CVar key (e.g., "Sound_MasterVolume").
    local function RowInitializer(frame, elementData)
        local data = channelMap[elementData]
        if not data then return end

        if not frame.initialized then
            frame:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            frame:SetBackdropColor(0, 0, 0, 0.4)
            frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)

            local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            checkbox:SetPoint("LEFT", 0, 0)
            checkbox:SetSize(24, 24)
            frame.checkbox = checkbox

            local drag = frame:CreateTexture(nil, "ARTWORK")
            drag:SetAtlas("ReagentWizards-ReagentRow-Grabber")
            drag:SetSize(12, 18)
            drag:SetPoint("RIGHT", -6, 0)
            drag:SetAlpha(0.5)
            frame.drag = drag

            frame.initialized = true
        end

        frame.checkbox.text:SetText(data.name)
        frame.checkbox:SetChecked(db[data.namespace][data.var] == true)
        frame.checkbox:SetScript("OnClick", function(self)
            db[data.namespace][data.var] = self:GetChecked()
            VS:FlagLayoutDirty()
        end)

        frame:SetScript("OnEnter", function(self)
            if dragBehavior and dragBehavior:GetDragging() then return end
            self:SetBackdropBorderColor(1, 0.8, 0, 0.5)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(data.tooltip .. "\n\n|cff00ff00Drag to reorder|r", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)
            GameTooltip:Hide()
        end)
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("VolumeSlidersChannelRowTemplate", RowInitializer)
    view:SetPadding(0, 0, 0, 0, 4)

    scrollBox:Init(view)

    dragBehavior = ScrollUtil.AddLinearDragBehavior(scrollBox)
    dragBehavior:SetReorderable(true)
    dragBehavior:SetDragRelativeToCursor(true)

    dragBehavior:SetCursorFactory(function(elementData)
        return "VolumeSlidersChannelRowTemplate", function(frame)
            RowInitializer(frame, elementData)
            frame:SetAlpha(0.6)
            frame:SetBackdropBorderColor(1, 0.8, 0, 0.8)
        end
    end)

    dragBehavior:SetDropPredicate(function(sourceElementData, intersectData)
        if intersectData.area == DragIntersectionArea.Inside then
            local cursorParent = FrameUtil.GetRootParent(scrollBox)
            local _, cy = InputUtil.GetCursorPosition(cursorParent)
            local frame = intersectData.frame
            local centerY = frame:GetBottom() + (frame:GetHeight() / 2)
            if cy > centerY then
                intersectData.area = DragIntersectionArea.Above
            else
                intersectData.area = DragIntersectionArea.Below
            end
        end
        return true
    end)

    dragBehavior:SetDropEnter(function(factory, candidate)
        local frame = factory("VolumeSlidersDropIndicatorTemplate")
        frame:SetSize(150, 3)
        if candidate.area == DragIntersectionArea.Above then
            frame:SetPoint("BOTTOMLEFT", candidate.frame, "TOPLEFT", 0, 1)
            frame:SetPoint("BOTTOMRIGHT", candidate.frame, "TOPRIGHT", 0, 1)
        elseif candidate.area == DragIntersectionArea.Below then
            frame:SetPoint("TOPLEFT", candidate.frame, "BOTTOMLEFT", 0, -1)
            frame:SetPoint("TOPRIGHT", candidate.frame, "BOTTOMRIGHT", 0, -1)
        end
    end)

    dragBehavior:SetPostDrop(function(contextData)
        local dp = contextData.dataProvider
        db.layout.sliderOrder = db.layout.sliderOrder or {}
        wipe(db.layout.sliderOrder)
        for _, cvar in dp:EnumerateEntireRange() do
            table_insert(db.layout.sliderOrder, cvar)
        end
        VS:UpdateAppearance()
    end)

    local function RefreshDataProvider()
        local dataProvider = CreateDataProvider()
        for _, cvar in ipairs(db.layout.sliderOrder) do
            dataProvider:Insert(cvar)
        end
        scrollBox:SetDataProvider(dataProvider)
    end

    RefreshDataProvider()

    ---------------------------------------------------------------------------
    -- Footer Elements Drag Box
    ---------------------------------------------------------------------------
    if db.layout.limitFooterCols == nil then db.layout.limitFooterCols = false end
    if db.layout.maxFooterCols == nil then db.layout.maxFooterCols = 3 end

    local limitFooterCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    limitFooterCheck:SetPoint("TOPLEFT", dividerH, "BOTTOMLEFT", 25, -15)
    limitFooterCheck.text:SetText("Limit Footer Columns")
    limitFooterCheck:SetChecked(db.layout.limitFooterCols)
    limitFooterCheck:SetScript("OnClick", function(self)
        db.layout.limitFooterCols = self:GetChecked()
        VS:UpdateAppearance()
    end)
    VS:AddTooltip(limitFooterCheck, "Restrict the maximum number of items allowed per row in the footer.")

    local maxFooterInput = CreateFrame("EditBox", nil, categoryFrame, "InputBoxTemplate")
    maxFooterInput:SetSize(30, 20)
    maxFooterInput:SetPoint("LEFT", limitFooterCheck.text, "RIGHT", 15, 0)
    maxFooterInput:SetAutoFocus(false)
    maxFooterInput:SetNumeric(true)
    maxFooterInput:SetMaxLetters(2)
    maxFooterInput:SetFontObject("GameFontHighlight")
    maxFooterInput:SetText(tostring(db.layout.maxFooterCols))
    maxFooterInput:SetCursorPosition(0)

    maxFooterInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local num = tonumber(self:GetText())
            if num and num > 0 and num <= 20 then
                db.layout.maxFooterCols = num
                VS:FlagLayoutDirty()
            end
        end
    end)
    maxFooterInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    maxFooterInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.layout.maxFooterCols or 3))
        self:SetCursorPosition(0)
        self:ClearFocus()
    end)
    VS:AddTooltip(maxFooterInput, "Maximum items per row (1-20).")

    local footerLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    footerLabel:SetPoint("TOPLEFT", limitFooterCheck, "BOTTOMLEFT", 0, -15)
    footerLabel:SetText("Footer Elements")

    local footerSubLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footerSubLabel:SetPoint("TOP", footerLabel, "BOTTOM", 0, -2)
    footerSubLabel:SetText("(Drag to Reorder)")
    footerSubLabel:SetAlpha(0.6)

    local footerMap = {
        ["showZoneTriggers"] = { name = "Zone Triggers", namespace = "toggles", tooltip = "Show or hide the Zone Triggers toggle." },
        ["showFishingSplash"] = { name = "Fishing Boost", namespace = "toggles", tooltip = "Show or hide the Fishing Splash Boost toggle." },
        ["showLfgPop"] = { name = "LFG Pop Boost", namespace = "toggles", tooltip = "Show or hide the LFG Pop Boost toggle." },
        ["showBackground"] = { name = "SBG Checkbox", namespace = "toggles", tooltip = "Show or hide the 'Sound in Background' toggle." },
        ["showCharacter"] = { name = "Char Checkbox", namespace = "toggles", tooltip = "Show or hide the 'Sound at Character' toggle." },
        ["showEmoteSounds"] = { name = "Emote Sounds", namespace = "toggles", tooltip = "Show or hide the 'Emote Sounds' toggle." },
        ["showOutput"] = { name = "Output Selector", namespace = "toggles", tooltip = "Show or hide the 'Output:' dropdown." },
        ["showVoiceMode"] = { name = "Voice Mode", namespace = "toggles", tooltip = "Show or hide the Voice Chat Mode toggle." },
    }

    local footerBox = CreateFrame("Frame", nil, categoryFrame, "WowScrollBoxList")
    footerBox:SetSize(145, 230)
    footerBox:SetPoint("TOPLEFT", footerSubLabel, "BOTTOMLEFT", -5, -8)

    local footerDragBehavior
    
    --- Initializes a single row within the Footer Elements list.
    -- @param frame Frame The row template frame.
    -- @param elementData string The toggle key (e.g., "showOutput").
    local function FooterRowInitializer(frame, elementData)
        local data = footerMap[elementData]
        if not data then return end

        if not frame.initialized then
            frame:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            frame:SetBackdropColor(0, 0, 0, 0.4)
            frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)

            local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            checkbox:SetPoint("LEFT", 0, 0)
            checkbox:SetSize(24, 24)
            frame.checkbox = checkbox

            local drag = frame:CreateTexture(nil, "ARTWORK")
            drag:SetAtlas("ReagentWizards-ReagentRow-Grabber")
            drag:SetSize(12, 18)
            drag:SetPoint("RIGHT", -6, 0)
            drag:SetAlpha(0.5)
            frame.drag = drag

            frame.initialized = true
        end

        frame.checkbox.text:SetText(data.name)
        frame.checkbox:SetChecked(db.toggles[elementData] == true)
        frame.checkbox:SetScript("OnClick", function(self)
            db.toggles[elementData] = self:GetChecked()
            VS:FlagLayoutDirty()
        end)

        frame:SetScript("OnEnter", function(self)
            if footerDragBehavior and footerDragBehavior:GetDragging() then return end
            self:SetBackdropBorderColor(1, 0.8, 0, 0.5)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(data.tooltip .. "\n\n|cff00ff00Drag to reorder|r", nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)
            GameTooltip:Hide()
        end)
    end

    local footerView = CreateScrollBoxListLinearView()
    footerView:SetElementInitializer("VolumeSlidersFooterRowTemplate", FooterRowInitializer)
    footerView:SetPadding(0, 0, 0, 0, 4)

    footerBox:Init(footerView)

    footerDragBehavior = ScrollUtil.AddLinearDragBehavior(footerBox)
    footerDragBehavior:SetReorderable(true)
    footerDragBehavior:SetDragRelativeToCursor(true)

    footerDragBehavior:SetCursorFactory(function(elementData)
        return "VolumeSlidersFooterRowTemplate", function(frame)
            FooterRowInitializer(frame, elementData)
            frame:SetAlpha(0.6)
            frame:SetBackdropBorderColor(1, 0.8, 0, 0.8)
        end
    end)

    footerDragBehavior:SetDropPredicate(function(sourceElementData, intersectData)
        if intersectData.area == DragIntersectionArea.Inside then
            local cursorParent = FrameUtil.GetRootParent(footerBox)
            local _, cy = InputUtil.GetCursorPosition(cursorParent)
            local frame = intersectData.frame
            local centerY = frame:GetBottom() + (frame:GetHeight() / 2)
            if cy > centerY then
                intersectData.area = DragIntersectionArea.Above
            else
                intersectData.area = DragIntersectionArea.Below
            end
        end
        return true
    end)

    footerDragBehavior:SetDropEnter(function(factory, candidate)
        local frame = factory("VolumeSlidersDropIndicatorTemplate")
        frame:SetSize(150, 3)
        if candidate.area == DragIntersectionArea.Above then
            frame:SetPoint("BOTTOMLEFT", candidate.frame, "TOPLEFT", 0, 1)
            frame:SetPoint("BOTTOMRIGHT", candidate.frame, "TOPRIGHT", 0, 1)
        elseif candidate.area == DragIntersectionArea.Below then
            frame:SetPoint("TOPLEFT", candidate.frame, "BOTTOMLEFT", 0, -1)
            frame:SetPoint("TOPRIGHT", candidate.frame, "BOTTOMRIGHT", 0, -1)
        end
    end)

    footerDragBehavior:SetPostDrop(function(contextData)
        local dp = contextData.dataProvider
        db.layout.footerOrder = db.layout.footerOrder or {}
        wipe(db.layout.footerOrder)
        for _, key in dp:EnumerateEntireRange() do
            table_insert(db.layout.footerOrder, key)
        end
        VS:UpdateAppearance()
    end)

    local function RefreshFooterDataProvider()
        local dataProvider = CreateDataProvider()
        local footerOrder = db.layout.footerOrder or VS.DEFAULT_FOOTER_ORDER
        for _, key in ipairs(footerOrder) do
            dataProvider:Insert(key)
        end
        footerBox:SetDataProvider(dataProvider)
    end

    RefreshFooterDataProvider()

    -- Column Layout cleanup since it is not fully dynamic columns anymore
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)
    if scrollFrame:GetWidth() > 0 then
        scrollFrame:GetScript("OnSizeChanged")(scrollFrame, scrollFrame:GetWidth(), scrollFrame:GetHeight())
    end
end
