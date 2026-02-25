-------------------------------------------------------------------------------
-- Settings.lua
--
-- Blizzard Settings page integration.  Registers a canvas layout category
-- and lazily creates the full settings UI (style dropdowns, preview slider,
-- element visibility checkboxes, channel drag-to-reorder, height/spacing).
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
local tostring   = tostring
local ipairs     = ipairs
local pairs      = pairs

-------------------------------------------------------------------------------
-- InitializeSettings
--
-- Registers the native WoW Options Settings page using a Canvas Layout.
-- The actual UI elements are created lazily on first show.
-------------------------------------------------------------------------------
function VS:InitializeSettings()
    local categoryFrame = CreateFrame("Frame", "VolumeSlidersOptionsFrame", UIParent)
    local category, layout = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Volume Sliders")

    categoryFrame:SetScript("OnShow", function(self)
        if not VS.settingsCreated then
            VS:CreateSettingsContents(self)
            VS.settingsCreated = true
        end

        -- Ensure height settings are refreshed on show
        if VS.RefreshTextInputs then
            VS:RefreshTextInputs()
        end
    end)

    Settings.RegisterAddOnCategory(category)
    VS.settingsCategory = category
end

-------------------------------------------------------------------------------
-- CreateSettingsContents
--
-- Internal function to build the actual UI elements of the settings panel.
-- This is called the first time the settings category is shown.
-------------------------------------------------------------------------------
function VS:CreateSettingsContents(categoryFrame)
    local db = VolumeSlidersMMDB

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Volume Sliders Settings")

    local desc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Customization options for the Volume Sliders minimap popup.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Dropdown Menus
    ---------------------------------------------------------------------------
    local dropdownWidth = 160
    local dropdownSpacingOffset = -15 -- Reduced spacing between dropdowns

    -- Title Color Label & Dropdown
    local titleColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleColorLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 10, -35)
    titleColorLabel:SetText("Title Text Color")

    local function AddTooltip(frame, text)
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    local function IsTitleSelected(value)
        return db.titleColor == value
    end
    local function SetTitleSelected(value)
        db.titleColor = value
        VS:UpdateAppearance()
    end

    local titleDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    titleDropdown:SetPoint("TOPLEFT", titleColorLabel, "BOTTOMLEFT", -15, -8)
    titleDropdown:SetWidth(dropdownWidth)
    titleDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Gold", IsTitleSelected, SetTitleSelected, 1)
        rootDescription:CreateRadio("White", IsTitleSelected, SetTitleSelected, 2)
    end)
    titleDropdown:GenerateMenu()

    -- Value Color Label & Dropdown
    local valueColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    valueColorLabel:SetPoint("TOPLEFT", titleDropdown, "BOTTOMLEFT", 15, dropdownSpacingOffset)
    valueColorLabel:SetText("Value Text Color")

    local function IsValueSelected(value)
        return db.valueColor == value
    end
    local function SetValueSelected(value)
        db.valueColor = value
        VS:UpdateAppearance()
    end

    local valueDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    valueDropdown:SetPoint("TOPLEFT", valueColorLabel, "BOTTOMLEFT", -15, -8)
    valueDropdown:SetWidth(dropdownWidth)
    valueDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Gold", IsValueSelected, SetValueSelected, 1)
        rootDescription:CreateRadio("White", IsValueSelected, SetValueSelected, 2)
    end)
    valueDropdown:GenerateMenu()

    -- High Color Label & Dropdown
    local highColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    highColorLabel:SetPoint("TOPLEFT", valueDropdown, "BOTTOMLEFT", 15, dropdownSpacingOffset)
    highColorLabel:SetText("High Text Color")

    local function IsHighSelected(value)
        return db.highColor == value
    end
    local function SetHighSelected(value)
        db.highColor = value
        VS:UpdateAppearance()
    end

    local highDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    highDropdown:SetPoint("TOPLEFT", highColorLabel, "BOTTOMLEFT", -15, -8)
    highDropdown:SetWidth(dropdownWidth)
    highDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Gold", IsHighSelected, SetHighSelected, 1)
        rootDescription:CreateRadio("White", IsHighSelected, SetHighSelected, 2)
    end)
    highDropdown:GenerateMenu()

    -- Arrow Style Label & Dropdown
    local arrowLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    arrowLabel:SetPoint("TOPLEFT", highDropdown, "BOTTOMLEFT", 15, dropdownSpacingOffset)
    arrowLabel:SetText("Stepper Arrow Style")

    local function IsArrowSelected(value)
        return db.arrowStyle == value
    end
    local function SetArrowSelected(value)
        db.arrowStyle = value
        VS:UpdateAppearance()
    end

    local arrowDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    arrowDropdown:SetPoint("TOPLEFT", arrowLabel, "BOTTOMLEFT", -15, -8)
    arrowDropdown:SetWidth(dropdownWidth)
    arrowDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Gold Plus / Minus", IsArrowSelected, SetArrowSelected, 1)
        rootDescription:CreateRadio("Silver Plus / Minus", IsArrowSelected, SetArrowSelected, 4)
        rootDescription:CreateRadio("Gold Arrows", IsArrowSelected, SetArrowSelected, 2)
        rootDescription:CreateRadio("Silver Arrows", IsArrowSelected, SetArrowSelected, 3)
    end)
    arrowDropdown:GenerateMenu()

    -- Knob Style Label & Dropdown
    local knobLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    knobLabel:SetPoint("TOPLEFT", arrowDropdown, "BOTTOMLEFT", 15, dropdownSpacingOffset)
    knobLabel:SetText("Slider Knob Style")

    local function IsKnobSelected(value)
        return db.knobStyle == value
    end
    local function SetKnobSelected(value)
        db.knobStyle = value
        VS:UpdateAppearance()
    end

    local knobDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    knobDropdown:SetPoint("TOPLEFT", knobLabel, "BOTTOMLEFT", -15, -8)
    knobDropdown:SetWidth(dropdownWidth)
    knobDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Gold Diamond", IsKnobSelected, SetKnobSelected, 1)
        rootDescription:CreateRadio("Silver Knob", IsKnobSelected, SetKnobSelected, 2)
    end)
    knobDropdown:GenerateMenu()

    -- Low Color Label & Dropdown
    local lowColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lowColorLabel:SetPoint("TOPLEFT", knobDropdown, "BOTTOMLEFT", 15, dropdownSpacingOffset)
    lowColorLabel:SetText("Low Text Color")

    local function IsLowSelected(value)
        return db.lowColor == value
    end
    local function SetLowSelected(value)
        db.lowColor = value
        VS:UpdateAppearance()
    end

    local lowDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    lowDropdown:SetPoint("TOPLEFT", lowColorLabel, "BOTTOMLEFT", -15, -8)
    lowDropdown:SetWidth(dropdownWidth)
    lowDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Gold", IsLowSelected, SetLowSelected, 1)
        rootDescription:CreateRadio("White", IsLowSelected, SetLowSelected, 2)
    end)
    lowDropdown:GenerateMenu()

    -- Apply tooltips to dropdown labels
    AddTooltip(titleDropdown, "Change the color of the channel titles (e.g. 'Master') to Gold or White.")
    AddTooltip(valueDropdown, "Change the color of the volume percentage numbers to Gold or White.")
    AddTooltip(highDropdown, "Change the color of the '100%' marker to Gold or White.")
    AddTooltip(lowDropdown, "Change the color of the '0%' marker to Gold or White.")
    AddTooltip(arrowDropdown, "Select the visual style for the volume increment/decrement buttons.")
    AddTooltip(knobDropdown, "Select the visual style for the slider handle (knob).")

    ---------------------------------------------------------------------------
    -- Live Preview Column
    ---------------------------------------------------------------------------
    local previewLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    previewLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 210, -35)
    previewLabel:SetText("Preview")

    -- Place the preview container in the 2nd column
    VS.previewBackdrop = CreateFrame("Frame", nil, categoryFrame, "BackdropTemplate")
    VS.previewBackdrop:SetPoint("TOP", previewLabel, "BOTTOM", 0, -10)
    VS.previewBackdrop:SetSize(90, 360)
    local previewBackdrop = VS.previewBackdrop
    previewBackdrop:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    previewBackdrop:SetBackdropColor(0, 0, 0, 0.4)
    previewBackdrop:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    -- Generate a disabled preview slider centered within the backdrop
    VS.previewSlider = VS:CreateVerticalSlider(categoryFrame, "VolumeSlidersPreviewSlider", "Master", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01)
    VS.previewSlider:SetParent(previewBackdrop)
    VS.previewSlider:ClearAllPoints()
    VS.previewSlider:SetPoint("CENTER", previewBackdrop, "CENTER", 0, 0)
    VS.previewSlider:SetScale(0.9)
    VS.previewSlider:EnableMouse(false)

    -- Ensure the slider is drawn in front of the backdrop
    VS.previewSlider:SetFrameLevel(previewBackdrop:GetFrameLevel() + 5)

    -- Disable functional updates for the preview slider
    VS.previewSlider:SetScript("OnValueChanged", nil)
    VS.previewSlider:SetScript("OnMouseWheel", nil)
    VS.previewSlider.upBtn:SetScript("OnClick", nil)
    VS.previewSlider.downBtn:SetScript("OnClick", nil)
    VS.previewSlider.muteCheck:SetScript("OnClick", nil)

    VS.previewSlider.upBtn:EnableMouse(false)
    VS.previewSlider.downBtn:EnableMouse(false)
    VS.previewSlider.muteCheck:EnableMouse(false)

    -- Mute Button is hidden by default if not strictly passed state, toggle explicit
    VS.previewSlider.muteCheck:Show()
    if VS.previewSlider.muteCheck.muteLabel then
        VS.previewSlider.muteCheck.muteLabel:Show()
    end

    ---------------------------------------------------------------------------
    -- 3rd Column: Visibility Checkboxes
    ---------------------------------------------------------------------------
    local visibilityLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibilityLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 325, -35)
    visibilityLabel:SetText("Element Visibility")

    local checkboxes = {
        { name = "Title", var = "showTitle", tooltip = "Show or hide the channel name (e.g., 'Master') above each slider." },
        { name = "Value (%)", var = "showValue", tooltip = "Show or hide the volume percentage text above each slider." },
        { name = "High Label", var = "showHigh", tooltip = "Show or hide the '100%' label at the top of the slider track." },
        { name = "Up Arrow", var = "showUpArrow", tooltip = "Show or hide the button for fine-tuning volume increments." },
        { name = "Slider Track", var = "showSlider", tooltip = "Show or hide the main vertical slider bar and knob." },
        { name = "Down Arrow", var = "showDownArrow", tooltip = "Show or hide the button for fine-tuning volume decrements." },
        { name = "Low Label", var = "showLow", tooltip = "Show or hide the '0%' label at the bottom of the slider track." },
        { name = "Mute Button", var = "showMute", tooltip = "Show or hide the mute checkbox and label below each slider." },
        { name = "---Separator---", isSeparator = true },
        { name = "SBG Checkbox", var = "showBackground", tooltip = "Show or hide the 'Sound in Background' toggle in the window footer." },
        { name = "Char Checkbox", var = "showCharacter", tooltip = "Show or hide the 'Sound at Character' toggle in the window footer." },
        { name = "Output Selector", var = "showOutput", tooltip = "Show or hide the 'Output:' device selection dropdown in the window footer." },
        { name = "Voice Mode Toggle", var = "showVoiceMode", tooltip = "Show or hide the Voice Chat Mode (Push to Talk / Open Mic) toggle in the window footer." },
    }

    local previousCheckbox = nil
    local checkboxOffset = 5

    for _, data in ipairs(checkboxes) do
        if data.isSeparator then
            local separator = categoryFrame:CreateTexture(nil, "ARTWORK")
            separator:SetHeight(2)
            separator:SetPoint("LEFT", visibilityLabel, "LEFT", -15, 0)
            separator:SetPoint("TOP", previousCheckbox, "BOTTOM", 0, -8)
            separator:SetWidth(140)
            separator:SetColorTexture(1, 1, 1, 0.4)

            -- Fix dummy anchor to align icons with items above
            local anchor = CreateFrame("Frame", nil, categoryFrame)
            anchor:SetSize(1, 1)
            anchor:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 10, -5)

            previousCheckbox = anchor
            checkboxOffset = -10
        else
            local checkbox = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
            if previousCheckbox then
                checkbox:SetPoint("TOPLEFT", previousCheckbox, "BOTTOMLEFT", 0, checkboxOffset or 5)
            else
                checkbox:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", -5, -5)
            end
            checkboxOffset = 5

            checkbox.text:SetText(data.name)
            checkbox:SetChecked(db[data.var])

            checkbox:SetScript("OnClick", function(self)
                db[data.var] = self:GetChecked()
                VS:UpdateAppearance()
            end)

            -- Add tooltip support
            checkbox:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(data.tooltip, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            checkbox:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            previousCheckbox = checkbox
        end
    end

    ---------------------------------------------------------------------------
    -- 4th Column: Channel Visibility
    ---------------------------------------------------------------------------
    local channelLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 450, -35)
    channelLabel:SetText("Channel Visibility")

    local channelSubLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelSubLabel:SetPoint("TOP", channelLabel, "BOTTOM", 0, -2)
    channelSubLabel:SetText("(Drag to Reorder)")
    channelSubLabel:SetAlpha(0.6)

    local channelMap = {
        ["Sound_MasterVolume"] = { name = "Master Slider", var = "showMaster", tooltip = "Show or hide the Master volume slider." },
        ["Sound_SFXVolume"] = { name = "SFX Slider", var = "showSFX", tooltip = "Show or hide the Sound Effects volume slider." },
        ["Sound_MusicVolume"] = { name = "Music Slider", var = "showMusic", tooltip = "Show or hide the Music volume slider." },
        ["Sound_AmbienceVolume"] = { name = "Ambience Slider", var = "showAmbience", tooltip = "Show or hide the Ambience volume slider." },
        ["Sound_DialogVolume"] = { name = "Dialog Slider", var = "showDialog", tooltip = "Show or hide the Dialog volume slider." },
        ["Sound_EncounterWarningsVolume"] = { name = "Warnings Slider", var = "showWarnings", tooltip = "Show or hide the dedicated slider for Encounter Warnings (combat alerts)." },
        ["Voice_ChatVolume"] = { name = "Voice Volume Slider", var = "showVoiceChat", tooltip = "Show or hide the Voice Chat Volume slider." },
        ["Voice_ChatDucking"] = { name = "Voice Ducking Slider", var = "showVoiceDucking", tooltip = "Show or hide the Voice Chat Ducking slider." },
        ["Voice_MicVolume"] = { name = "Mic Volume Slider", var = "showMicVolume", tooltip = "Show or hide the Microphone Volume slider." },
        ["Voice_MicSensitivity"] = { name = "Mic Sensitivity Slider", var = "showMicSensitivity", tooltip = "Show or hide the Microphone Sensitivity slider." },
    }

    local scrollBox = CreateFrame("Frame", nil, categoryFrame, "WowScrollBoxList")
    scrollBox:SetSize(170, 360)
    scrollBox:SetPoint("TOPLEFT", channelSubLabel, "BOTTOMLEFT", -5, -8)

    local dragBehavior -- Forward declare for access in RowInitializer

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

            local drag = frame:CreateTexture(nil, "ARTWORK")
            drag:SetAtlas("ReagentWizards-ReagentRow-Grabber")
            drag:SetSize(12, 18)
            drag:SetPoint("LEFT", 6, 0)
            frame.drag = drag

            local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            checkbox:SetPoint("LEFT", drag, "RIGHT", 4, 0)
            checkbox:SetSize(24, 24)
            frame.checkbox = checkbox

            frame.initialized = true
        end

        frame.checkbox.text:SetText(data.name)
        frame.checkbox:SetChecked(db[data.var])
        frame.checkbox:SetScript("OnClick", function(self)
            db[data.var] = self:GetChecked()
            VS:UpdateAppearance()
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
        wipe(db.sliderOrder)
        for _, cvar in dp:EnumerateEntireRange() do
            table.insert(db.sliderOrder, cvar)
        end
        VS:UpdateAppearance()
    end)

    local function RefreshDataProvider()
        local dataProvider = CreateDataProvider()
        for _, cvar in ipairs(db.sliderOrder) do
            dataProvider:Insert(cvar)
        end
        scrollBox:SetDataProvider(dataProvider)
    end

    RefreshDataProvider()

    ---------------------------------------------------------------------------
    -- Slider Height & Spacing Settings (Sliders)
    ---------------------------------------------------------------------------
    if db.sliderHeight == nil then
        db.sliderHeight = 150
    end
    if db.sliderSpacing == nil then
        db.sliderSpacing = 10
    end

    -- Height Slider
    local heightLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", lowDropdown, "BOTTOMLEFT", 15, -25)
    heightLabel:SetText("Slider Height")

    local heightInput = CreateFrame("EditBox", "VolumeSlidersHeightInput", categoryFrame, "InputBoxTemplate")
    heightInput:SetSize(40, 20)
    heightInput:SetPoint("LEFT", heightLabel, "RIGHT", 10, 0)
    heightInput:SetAutoFocus(false)
    heightInput:SetNumeric(true)
    heightInput:SetMaxLetters(3)
    heightInput:SetFontObject("GameFontHighlight")
    heightInput:SetText(tostring(db.sliderHeight or 150))

    local heightSlider = CreateFrame("Slider", "VolumeSlidersHeightSlider", categoryFrame, "OptionsSliderTemplate")
    heightSlider:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, -15)
    heightSlider:SetWidth(150)
    heightSlider:SetMinMaxValues(100, 250)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetValue(db.sliderHeight or 150)
    if _G["VolumeSlidersHeightSliderLow"] then _G["VolumeSlidersHeightSliderLow"]:Hide() end
    if _G["VolumeSlidersHeightSliderHigh"] then _G["VolumeSlidersHeightSliderHigh"]:Hide() end
    if _G["VolumeSlidersHeightSliderText"] then _G["VolumeSlidersHeightSliderText"]:Hide() end

    -- Sync Input -> Slider
    heightInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local num = tonumber(self:GetText())
            if num and num >= 100 and num <= 250 then
                heightSlider:SetValue(num)
            end
        end
    end)
    heightInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    heightInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.sliderHeight or 150))
        self:ClearFocus()
    end)

    -- Sync Slider -> Input & Apply Settings
    heightSlider:SetScript("OnValueChanged", function(self, value)
        local num = math_floor(value + 0.5)
        self:SetValue(num) -- snap to integer
        heightInput:SetText(tostring(num))
        if db.sliderHeight ~= num then
            db.sliderHeight = num
            VS:UpdateAppearance()
        end
    end)

    -- Spacing Slider
    local spacingLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -25)
    spacingLabel:SetText("Slider Spacing")

    local spacingInput = CreateFrame("EditBox", "VolumeSlidersSpacingInput", categoryFrame, "InputBoxTemplate")
    spacingInput:SetSize(40, 20)
    spacingInput:SetPoint("LEFT", spacingLabel, "RIGHT", 10, 0)
    spacingInput:SetAutoFocus(false)
    spacingInput:SetNumeric(true)
    spacingInput:SetMaxLetters(2)
    spacingInput:SetFontObject("GameFontHighlight")
    spacingInput:SetText(tostring(db.sliderSpacing or 10))

    local spacingSlider = CreateFrame("Slider", "VolumeSlidersSpacingSlider", categoryFrame, "OptionsSliderTemplate")
    spacingSlider:SetPoint("TOPLEFT", spacingLabel, "BOTTOMLEFT", 0, -15)
    spacingSlider:SetWidth(150)
    spacingSlider:SetMinMaxValues(5, 40)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    spacingSlider:SetValue(db.sliderSpacing or 10)
    if _G["VolumeSlidersSpacingSliderLow"] then _G["VolumeSlidersSpacingSliderLow"]:Hide() end
    if _G["VolumeSlidersSpacingSliderHigh"] then _G["VolumeSlidersSpacingSliderHigh"]:Hide() end
    if _G["VolumeSlidersSpacingSliderText"] then _G["VolumeSlidersSpacingSliderText"]:Hide() end

    -- Sync Input -> Slider
    spacingInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local num = tonumber(self:GetText())
            if num and num >= 5 and num <= 40 then
                spacingSlider:SetValue(num)
            end
        end
    end)
    spacingInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    spacingInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.sliderSpacing or 10))
        self:ClearFocus()
    end)

    -- Sync Slider -> Input & Apply Settings
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        local num = math_floor(value + 0.5)
        self:SetValue(num) -- snap to integer
        spacingInput:SetText(tostring(num))
        if db.sliderSpacing ~= num then
            db.sliderSpacing = num
            VS:UpdateAppearance()
        end
    end)

    -- Override RefreshTextInputs with slider-aware version
    function VS:RefreshTextInputs()
        if heightSlider and heightInput then
            local val = VolumeSlidersMMDB and VolumeSlidersMMDB.sliderHeight or 150
            heightSlider:SetValue(val)
            heightInput:SetText(tostring(val))
            heightInput:SetCursorPosition(0)
        end
        if spacingSlider and spacingInput then
            local val = VolumeSlidersMMDB and VolumeSlidersMMDB.sliderSpacing or 10
            spacingSlider:SetValue(val)
            spacingInput:SetText(tostring(val))
            spacingInput:SetCursorPosition(0)
        end
    end

    categoryFrame:HookScript("OnShow", function()
        C_Timer.After(0.1, function() VS:RefreshTextInputs() end)
    end)

    -- Pre-warm the UI elements immediately after creation
    VS:RefreshTextInputs()

    AddTooltip(heightSlider, "Adjust the vertical height for the sliders in pixels. Changes apply in real-time.")
    AddTooltip(spacingSlider, "Adjust the horizontal spacing between the slider columns in pixels. Changes apply in real-time.")

    -- Sync preview appearance to current settings.
    VS:UpdateAppearance()
end
