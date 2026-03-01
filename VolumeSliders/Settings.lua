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
local addonName, VS = ...
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
-- The actual UI elements are created synchronously during login so that the
-- Blizzard layout engine can properly calculate bounding boxes on the first view.
-------------------------------------------------------------------------------
function VS:InitializeSettings()
    local categoryFrame = CreateFrame("Frame", "VolumeSlidersOptionsFrame", UIParent)
    local category, layout = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Volume Sliders")

    VS:CreateSettingsContents(categoryFrame)

    categoryFrame:SetScript("OnShow", function(self)
        -- Ensure height settings are refreshed on show
        if VS.RefreshTextInputs then
            VS:RefreshTextInputs()
        end
    end)

    Settings.RegisterAddOnCategory(category)
    VS.settingsCategory = category
    
    -- Subcategory: Zone Triggers
    local triggerFrame = CreateFrame("Frame", "VolumeSlidersTriggerOptionsFrame", UIParent)
    local triggerCategory, triggerLayout = Settings.RegisterCanvasLayoutSubcategory(category, triggerFrame, "Zone Triggers")
    Settings.RegisterAddOnCategory(triggerCategory)
    
    VS:CreateTriggerSettingsContents(triggerFrame)

    triggerFrame:SetScript("OnShow", function(self)
        if VS.RefreshTriggerSettings then
            VS:RefreshTriggerSettings()
        end
    end)
end

-------------------------------------------------------------------------------
-- CreateSettingsContents
--
-- Internal function to build the actual UI elements of the settings panel.
-- This is called the first time the settings category is shown.
-------------------------------------------------------------------------------
function VS:CreateSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB

    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    -- Add a dark backdrop to improve contrast for settings elements
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local categoryFrame = CreateFrame("Frame", "VolumeSlidersSettingsContentFrame", scrollFrame)
    -- We'll set a tall height for the content, and dynamically match the scrollFrame's width
    categoryFrame:SetSize(600, 750) 
    scrollFrame:SetScrollChild(categoryFrame)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    local versionStr = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or GetAddOnMetadata(addonName, "Version") or ""
    title:SetText("Volume Sliders Settings " .. (versionStr ~= "" and ("v" .. versionStr) or ""))

    local desc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Customization options for the Volume Sliders minimap popup.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Dropdown Menus
    ---------------------------------------------------------------------------
    local dropdownWidth = 160
    local dropdownSpacingOffset = -15 -- Reduced spacing between dropdowns

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

    -- Custom Icon Toggle (Moved to top of Col 1)
    local customIconLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customIconLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 10, -35)
    customIconLabel:SetText("Minimap Icon")

    local customIconCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    customIconCheck:SetPoint("TOPLEFT", customIconLabel, "BOTTOMLEFT", -5, -5)
    customIconCheck.text:SetText("Custom")
    customIconCheck:SetChecked(db.minimalistMinimap)

    local resetBtn = CreateFrame("Button", nil, categoryFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(70, 22)
    resetBtn:SetPoint("LEFT", customIconCheck.text, "RIGHT", 10, 0)
    resetBtn:SetText("Reset")
    
    local bindMinimapCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    bindMinimapCheck:SetPoint("TOPLEFT", customIconCheck, "BOTTOMLEFT", 0, 5)
    bindMinimapCheck.text:SetText("Bind to Minimap")
    
    local function UpdateBindMinimapState()
        if db.minimalistMinimap then
            bindMinimapCheck:Enable()
            bindMinimapCheck.text:SetFontObject("GameFontNormalSmall")
            bindMinimapCheck:SetChecked(db.bindToMinimap)
        else
            bindMinimapCheck:Disable()
            bindMinimapCheck.text:SetFontObject("GameFontDisableSmall")
            bindMinimapCheck:SetChecked(true)
        end
    end
    -- Set initial state
    UpdateBindMinimapState()

    customIconCheck:SetScript("OnClick", function(self)
        db.minimalistMinimap = self:GetChecked()
        UpdateBindMinimapState()
        if VS.UpdateMiniMapButtonVisibility then
            VS:UpdateMiniMapButtonVisibility()
        end
    end)
    AddTooltip(customIconCheck, "Show a minimalist speaker near the zoom controls instead of the standard ringed minimap button.")
    
    bindMinimapCheck:SetScript("OnClick", function(self)
        db.bindToMinimap = self:GetChecked()
        if VS.UpdateMiniMapButtonVisibility then
            VS:UpdateMiniMapButtonVisibility()
        end
    end)
    AddTooltip(bindMinimapCheck, "If checked, the custom icon fades in when hovering the Minimap and scales with it.\nIf unchecked, it remains permanently visible and uses standard UI scaling.")

    resetBtn:SetScript("OnClick", function()
        VolumeSlidersMMDB.minimalistOffsetX = -35
        VolumeSlidersMMDB.minimalistOffsetY = -5
        if VS.minimalistButton then
            VS.minimalistButton:ClearAllPoints()
            VS.minimalistButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -35, -5)
        end
    end)
    AddTooltip(resetBtn, "Reset the custom minimap icon position to its default location.")

    -- Title Color Label & Dropdown
    local titleColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleColorLabel:SetPoint("TOPLEFT", bindMinimapCheck, "BOTTOMLEFT", 0, dropdownSpacingOffset)
    titleColorLabel:SetText("Title Text Color")

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
    visibilityLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 310, -35)
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
        { name = "-Separator-", isSeparator = true },
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
            checkbox:SetChecked(db[data.var] == true)

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
    scrollBox:SetSize(145, 360)
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
        frame.checkbox:SetChecked(db[data.var] == true)
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
    spacingSlider:SetMinMaxValues(0, 40)
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
            if num and num >= 0 and num <= 40 then
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

-------------------------------------------------------------------------------
-- CreateTriggerSettingsContents
--
-- Internal function to build the actual UI elements of the trigger settings
-- panel. Called lazily open first show.
-------------------------------------------------------------------------------
function VS:CreateTriggerSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB
    db.triggers = db.triggers or {}

    local scrollFrame = CreateFrame("ScrollFrame", "VSTriggerSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local contentFrame = CreateFrame("Frame", "VSTriggerSettingsContentFrame", scrollFrame)
    contentFrame:SetSize(600, 800) 
    scrollFrame:SetScrollChild(contentFrame)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        contentFrame:SetWidth(width)
    end)

    local title = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Zone Specific Triggers")

    local desc = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(560)
    desc:SetText("Configure volume settings to apply automatically when entering specific zones. Your original volume levels will be seamlessly restored when you leave the area.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Master Toggle
    ---------------------------------------------------------------------------
    local enableCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 10, -15)
    enableCheck.text:SetFontObject("GameFontNormalLarge")
    enableCheck.text:SetText("Enable Zone Triggers")
    enableCheck:SetChecked(db.enableTriggers == true)

    enableCheck:SetScript("OnClick", function(self)
        db.enableTriggers = self:GetChecked()
        if VS.Triggers and VS.Triggers.RefreshEventState then
            VS.Triggers:RefreshEventState()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    local separatorTop = contentFrame:CreateTexture(nil, "ARTWORK")
    separatorTop:SetHeight(2)
    separatorTop:SetPoint("LEFT", enableCheck, "LEFT", -10, 0)
    separatorTop:SetPoint("TOP", enableCheck, "BOTTOM", 0, -10)
    separatorTop:SetWidth(540)
    separatorTop:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- State & Management
    ---------------------------------------------------------------------------
    -- We need a working state for the currently selected/edited trigger
    VS.TriggerWorkingState = {
        name = "New Trigger",
        priority = 10,
        zones = {},
        volumes = {},
        ignored = {},
        index = nil -- The index in db.triggers if it already exists
    }

    local currentSelectedIndex = nil
    local triggerSliders = {}

    local triggerDropdown = CreateFrame("DropdownButton", nil, contentFrame, "WowStyle1DropdownTemplate")
    triggerDropdown:SetPoint("TOPLEFT", separatorTop, "BOTTOMLEFT", 10, -35)
    triggerDropdown:SetWidth(200)

    local priorityLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityLabel:SetPoint("BOTTOMLEFT", triggerDropdown, "TOPLEFT", 0, 5)
    priorityLabel:SetText("Select Trigger Profile")

    local btnSave = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnSave:SetSize(90, 22)
    btnSave:SetPoint("LEFT", triggerDropdown, "RIGHT", 15, 0)
    btnSave:SetText("Save")

    local btnCopy = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnCopy:SetSize(90, 22)
    btnCopy:SetPoint("LEFT", btnSave, "RIGHT", 10, 0)
    btnCopy:SetText("Copy")

    local btnDelete = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnDelete:SetSize(90, 22)
    btnDelete:SetPoint("LEFT", btnCopy, "RIGHT", 10, 0)
    btnDelete:SetText("Delete")

    ---------------------------------------------------------------------------
    -- Zone List & Priority Edit
    ---------------------------------------------------------------------------
    local nameLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", triggerDropdown, "BOTTOMLEFT", 0, -20)
    nameLabel:SetText("Trigger Name")

    local inputName = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    inputName:SetSize(380, 20)
    inputName:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 5, -5)
    inputName:SetAutoFocus(false)

    local priorityEditLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityEditLabel:SetPoint("BOTTOMLEFT", nameLabel, "BOTTOMRIGHT", 310, 0)
    priorityEditLabel:SetText("Priority")

    -- Add Tooltip for Priority
    priorityEditLabel:EnableMouse(true)
    priorityEditLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Priority Level", 1, 1, 1)
        GameTooltip:AddLine("Determines which trigger wins if multiple zones overlap at the same time.", nil, nil, nil, true)
        GameTooltip:AddLine("Lower numbers have higher priority (e.g., Priority 1 will override Priority 10).", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    priorityEditLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local inputPriority = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    inputPriority:SetSize(40, 20)
    inputPriority:SetPoint("TOPLEFT", priorityEditLabel, "BOTTOMLEFT", 5, -5)
    inputPriority:SetNumeric(true)
    inputPriority:SetAutoFocus(false)

    local zonesLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    zonesLabel:SetPoint("TOPLEFT", inputName, "BOTTOMLEFT", -5, -20)
    zonesLabel:SetText("Monitored Zones (semicolon separated)")

    local btnAddCurrent = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnAddCurrent:SetSize(140, 22)
    btnAddCurrent:SetPoint("LEFT", zonesLabel, "RIGHT", 15, 0)
    btnAddCurrent:SetText("Add Current Zone")

    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersZoneScrollFrame", contentFrame, "UIPanelScrollFrameTemplate")
    local INPUT_WIDTH = 500
    scrollFrame:SetSize(INPUT_WIDTH, 70) 
    scrollFrame:SetPoint("TOPLEFT", zonesLabel, "BOTTOMLEFT", 10, -20)
    
    -- Add a visual backing frame so it looks like an input box
    local scrollBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    scrollBg:SetPoint("TOPLEFT", -7, 7)
    scrollBg:SetPoint("BOTTOMRIGHT", 30, -7)
    scrollBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    scrollBg:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    scrollBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    scrollBg:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)
    
    local inputZones = CreateFrame("EditBox", nil, scrollFrame)
    inputZones:SetMultiLine(true)
    inputZones:SetFontObject("ChatFontNormal")
    inputZones:SetWidth(INPUT_WIDTH)
    inputZones:SetAutoFocus(false)
    scrollFrame:SetScrollChild(inputZones)

    -- Hook cursor movement to standard scrolling logic
    inputZones:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    inputZones:SetScript("OnUpdate", function(self, elapsed)
        ScrollingEdit_OnUpdate(self, elapsed, self:GetParent())
    end)
    inputZones:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    btnAddCurrent:SetScript("OnClick", function()
        local zone = GetRealZoneText()
        if zone and zone ~= "" then
            local t = inputZones:GetText()
            if t == "" then
                inputZones:SetText(zone)
            else
                inputZones:SetText(t .. "; " .. zone)
            end
        end
    end)

    local separatorMid = contentFrame:CreateTexture(nil, "ARTWORK")
    separatorMid:SetHeight(1)
    separatorMid:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", -15, -35)
    separatorMid:SetWidth(540)
    separatorMid:SetColorTexture(1, 1, 1, 0.2)
    
    ---------------------------------------------------------------------------
    -- Faux Sliders Display Area
    ---------------------------------------------------------------------------
    local slidersContainer = CreateFrame("Frame", nil, contentFrame)
    slidersContainer:SetPoint("TOPLEFT", separatorMid, "BOTTOMLEFT", 0, -10)
    slidersContainer:SetSize(540, 380)

    -- Define the channels we want faux sliders for
    local channels = {
        { key="Sound_MasterVolume", label="Master"},
        { key="Sound_SFXVolume", label="SFX"},
        { key="Sound_MusicVolume", label="Music"},
        { key="Sound_AmbienceVolume", label="Ambience"},
        { key="Sound_DialogVolume", label="Dialog"}
    }
    
    local sliderWidth = VS.SLIDER_COLUMN_WIDTH or 60
    local sliderSpacing = 20
    local totalWidth = (#channels * sliderWidth) + ((#channels - 1) * sliderSpacing)
    local startX = (540 - totalWidth) / 2
    
    for i, chan in ipairs(channels) do
        local slider = VS:CreateTriggerSlider(slidersContainer, "VSTriggerSlider"..chan.label, chan.label, chan.key, VS.TriggerWorkingState, 0, 1, 0.01)
        
        -- Start hidden
        slider:Hide()
        slider:SetPoint("TOPLEFT", slidersContainer, "TOPLEFT", startX + (i-1) * (sliderWidth + sliderSpacing), -130)
        table.insert(triggerSliders, slider)
    end

    ---------------------------------------------------------------------------
    -- Interaction Logic
    ---------------------------------------------------------------------------

    local function RefreshSliderUI()
        for _, slider in ipairs(triggerSliders) do
            slider:Show()
            if slider.RefreshValue then
                slider:RefreshValue()
            end
        end
    end

    local function UpdateFormFromWorkingState()
        inputName:SetText(VS.TriggerWorkingState.name)
        inputPriority:SetText(tostring(VS.TriggerWorkingState.priority))
        
        local zStr = ""
            zStr = table.concat(VS.TriggerWorkingState.zones, "; ")
        inputZones:SetText(zStr)

        RefreshSliderUI()
        
        if currentSelectedIndex then
            btnSave:Enable()
            btnCopy:Enable()
            btnDelete:Enable()
        else
            btnSave:Enable()
            btnCopy:Disable()
            btnDelete:Disable()
        end
    end

    local function LoadWorkingState(trigger, index)
        VS.TriggerWorkingState.name = trigger and trigger.name or "New Profile"
        VS.TriggerWorkingState.priority = trigger and (trigger.priority or 10) or 10
        VS.TriggerWorkingState.index = index
        
        VS.TriggerWorkingState.zones = {}
        VS.TriggerWorkingState.volumes = {}
        VS.TriggerWorkingState.ignored = {}

        if trigger then
            for _, z in ipairs(trigger.zones or {}) do table.insert(VS.TriggerWorkingState.zones, z) end
            for k,v in pairs(trigger.volumes or {}) do VS.TriggerWorkingState.volumes[k] = v end
            for k,v in pairs(trigger.ignored or {}) do VS.TriggerWorkingState.ignored[k] = v end
        end
        
        -- Fill in any missing channels with the current CVar values so the sliders don't default to 100% incorrectly
        for channelKey, _ in pairs(VS.CVAR_TO_VAR) do
            if VS.TriggerWorkingState.volumes[channelKey] == nil then
                VS.TriggerWorkingState.volumes[channelKey] = tonumber(GetCVar(channelKey)) or 1
            end
        end
    end

    local function SelectNewProfile()
        currentSelectedIndex = nil
        LoadWorkingState(nil, nil)
        triggerDropdown:SetText("Create New Trigger")
        UpdateFormFromWorkingState()
    end

    local function GenerateDropdownMenu(dropdown, rootDescription)
        rootDescription:CreateButton("Create New Trigger", function()
            SelectNewProfile()
            -- Force text update after dropdown closes
            dropdown:SetText("Create New Trigger") 
        end)
        
        for i, trigger in ipairs(db.triggers) do
            rootDescription:CreateButton(trigger.name .. " (Priority: " .. (trigger.priority or 0) .. ")", function()
                currentSelectedIndex = i
                -- Deep copy trigger so edits aren't live until saved
                LoadWorkingState(trigger, i)
                
                triggerDropdown:SetText(trigger.name)
                UpdateFormFromWorkingState()
            end)
        end
    end

    local function RefreshDropdown()
        triggerDropdown:SetupMenu(GenerateDropdownMenu)
        triggerDropdown:GenerateMenu()
        
        if currentSelectedIndex and db.triggers[currentSelectedIndex] then
            triggerDropdown:SetText(db.triggers[currentSelectedIndex].name)
        else
            -- Ensure New Profile is selected if none is active or list is empty
            SelectNewProfile()
        end
    end

    VS.RefreshTriggerSettings = function()
        RefreshDropdown()
        
        -- If we have an active profile selected, ensure the working state matches it so the UI populates
        if currentSelectedIndex and db.triggers[currentSelectedIndex] then
            LoadWorkingState(db.triggers[currentSelectedIndex], currentSelectedIndex)
        end
        
        UpdateFormFromWorkingState()
    end

    -- Split string by semicolon and trim whitespace
    local function ParseZones(str)
        local rawParts = {strsplit(";", str)}
        local result = {}
        local seen = {}
        for _, part in ipairs(rawParts) do
            local clean = part:match("^%s*(.-)%s*$")
            if clean and clean ~= "" and not seen[clean] then
                seen[clean] = true
                table.insert(result, clean)
            end
        end
        return result
    end

    btnSave:SetScript("OnClick", function()
        VS.TriggerWorkingState.name = inputName:GetText()
        if VS.TriggerWorkingState.name == "" then VS.TriggerWorkingState.name = "Unnamed Trigger" end
        VS.TriggerWorkingState.priority = tonumber(inputPriority:GetText()) or 10
        VS.TriggerWorkingState.zones = ParseZones(inputZones:GetText())
        
        -- Serialize to DB
        local newObj = {
            name = VS.TriggerWorkingState.name,
            priority = VS.TriggerWorkingState.priority,
            zones = VS.TriggerWorkingState.zones,
            volumes = {},
            ignored = {}
        }
        for k,v in pairs(VS.TriggerWorkingState.volumes) do newObj.volumes[k] = v end
        for k,v in pairs(VS.TriggerWorkingState.ignored) do newObj.ignored[k] = v end

        if currentSelectedIndex then
            db.triggers[currentSelectedIndex] = newObj
        else
            table.insert(db.triggers, newObj)
            currentSelectedIndex = #db.triggers
            VS.TriggerWorkingState.index = currentSelectedIndex
        end

        RefreshDropdown()
        if VS.Triggers and VS.Triggers.RefreshEventState then
            VS.Triggers:RefreshEventState()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    btnCopy:SetScript("OnClick", function()
        if currentSelectedIndex and db.triggers[currentSelectedIndex] then
            VS.TriggerWorkingState.name = VS.TriggerWorkingState.name .. " (Copy)"
            currentSelectedIndex = nil
            VS.TriggerWorkingState.index = nil
            triggerDropdown:SetText(VS.TriggerWorkingState.name)
            UpdateFormFromWorkingState()
        end
    end)

    StaticPopupDialogs["VolumeSlidersDeleteTriggerConfirm"] = {
        text = "Are you sure you want to delete this zone trigger?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if currentSelectedIndex and db.triggers[currentSelectedIndex] then
                table.remove(db.triggers, currentSelectedIndex)
                currentSelectedIndex = nil
                LoadWorkingState(nil, nil)
                RefreshDropdown()
                UpdateFormFromWorkingState()
                
                if VS.Triggers and VS.Triggers.RefreshEventState then
                     VS.Triggers:RefreshEventState()
                end
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,  -- Avoid UI taint
    }

    btnDelete:SetScript("OnClick", function()
        if currentSelectedIndex and db.triggers[currentSelectedIndex] then
            StaticPopup_Show("VolumeSlidersDeleteTriggerConfirm")
        end
    end)

    -- Initialize View
    btnSave:Disable()
    btnCopy:Disable()
    btnDelete:Disable()
    
    RefreshDropdown()
end

