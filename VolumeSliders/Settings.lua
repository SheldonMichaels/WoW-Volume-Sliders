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
    -- Main Category (Volume Sliders)
    local categoryFrame = CreateFrame("Frame", "VolumeSlidersOptionsFrame", UIParent)
    local category, layout = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Volume Sliders")

    VS:CreateSettingsContents(categoryFrame)

    Settings.RegisterAddOnCategory(category)
    VS.settingsCategory = category
    
    -- Subcategory 1: Sliders
    local slidersFrame = CreateFrame("Frame", "VolumeSlidersSlidersOptionsFrame", UIParent)
    local slidersCategory, slidersLayout = Settings.RegisterCanvasLayoutSubcategory(category, slidersFrame, "Sliders")
    Settings.RegisterAddOnCategory(slidersCategory)
    
    VS:CreateSlidersSettingsContents(slidersFrame)
    
    -- Subcategory 2: Window
    local windowFrame = CreateFrame("Frame", "VolumeSlidersWindowOptionsFrame", UIParent)
    local windowCategory, windowLayout = Settings.RegisterCanvasLayoutSubcategory(category, windowFrame, "Window")
    Settings.RegisterAddOnCategory(windowCategory)
    
    VS:CreateWindowSettingsContents(windowFrame)

    -- Subcategory 3: Automation (formerly Zone Triggers)
    local triggerFrame = CreateFrame("Frame", "VolumeSlidersTriggerOptionsFrame", UIParent)
    local triggerCategory, triggerLayout = Settings.RegisterCanvasLayoutSubcategory(category, triggerFrame, "Automation")
    Settings.RegisterAddOnCategory(triggerCategory)
    
    VS:CreateAutomationSettingsContents(triggerFrame)

    -- Subcategory 4: Mouse Actions
    local mouseActionsFrame = CreateFrame("Frame", "VolumeSlidersMouseActionsOptionsFrame", UIParent)
    local mouseActionsCategory, mouseActionsLayout = Settings.RegisterCanvasLayoutSubcategory(category, mouseActionsFrame, "Mouse Actions")
    Settings.RegisterAddOnCategory(mouseActionsCategory)
    
    VS:CreateMouseActionsSettingsContents(mouseActionsFrame)

    triggerFrame:SetScript("OnShow", function(self)
        if VS.RefreshTriggerSettings then
            VS:RefreshTriggerSettings()
        end
        if VS.RefreshAutomationTextInputs then
            VS:RefreshAutomationTextInputs()
        end
    end)
    
    mouseActionsFrame:SetScript("OnShow", function(self)
        if VS.RefreshMouseActionsUI then
            VS:RefreshMouseActionsUI()
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
    
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local categoryFrame = CreateFrame("Frame", "VolumeSlidersSettingsContentFrame", scrollFrame)
    categoryFrame:SetSize(600, 250) 
    scrollFrame:SetScrollChild(categoryFrame)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    local versionStr = C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version") or GetAddOnMetadata(addonName, "Version") or ""
    if versionStr ~= "" and not versionStr:match("^[vV]") then versionStr = "v" .. versionStr end
    title:SetText("Volume Sliders Settings" .. (versionStr ~= "" and (" " .. versionStr) or ""))

    local urlText = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    urlText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    urlText:SetText("curseforge.com/wow/addons/volume-sliders")

    local divider = categoryFrame:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", urlText, "BOTTOMLEFT", 0, -10)
    divider:SetWidth(560)
    divider:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Minimap Icon Settings
    ---------------------------------------------------------------------------
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

    local customIconLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customIconLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 10, -20)
    customIconLabel:SetText("Minimap Icon")

    local customIconCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    customIconCheck:SetPoint("TOPLEFT", customIconLabel, "BOTTOMLEFT", -5, -15)
    customIconCheck.text:SetText("Use Minimalist Speaker Icon")
    customIconCheck:SetChecked(db.minimalistMinimap)

    local resetBtn = CreateFrame("Button", nil, categoryFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(115, 22)
    resetBtn:SetPoint("LEFT", customIconLabel, "RIGHT", 15, 0)
    resetBtn:SetText("Reset Position")
    
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
    UpdateBindMinimapState()

    customIconCheck:SetScript("OnClick", function(self)
        db.minimalistMinimap = self:GetChecked()
        UpdateBindMinimapState()
        if VS.UpdateMiniMapButtonVisibility then
            VS:UpdateMiniMapButtonVisibility()
        end
    end)
    AddTooltip(customIconCheck, "Show a minimalist speaker near the zoom controls instead of the standard ringed minimap button.\n\n|cffff0000Note:|r Disabling this after it has been enabled requires a UI reload to fully remove the Minimap hooks.")
    
    bindMinimapCheck:SetScript("OnClick", function(self)
        db.bindToMinimap = self:GetChecked()
        if VS.UpdateMiniMapButtonVisibility then
            VS:UpdateMiniMapButtonVisibility()
        end
    end)
    AddTooltip(bindMinimapCheck, "If checked, the custom icon fades in when hovering the Minimap and scales with it.\nIf unchecked, it remains permanently visible and uses standard UI scaling.\n\n|cffff0000Note:|r Disabling this requires a UI reload to fully remove the Minimap hooks.")

    resetBtn:SetScript("OnClick", function()
        VolumeSlidersMMDB.minimalistOffsetX = -35
        VolumeSlidersMMDB.minimalistOffsetY = -5
        if VS.minimalistButton then
            VS.minimalistButton:ClearAllPoints()
            VS.minimalistButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -35, -5)
        end
    end)
    AddTooltip(resetBtn, "Reset the custom minimap icon position to its default location.")

    local showTooltipCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    showTooltipCheck:SetPoint("TOPLEFT", bindMinimapCheck, "BOTTOMLEFT", 0, 5)
    showTooltipCheck.text:SetText("Show Tooltip")
    showTooltipCheck:SetChecked(db.showMinimapTooltip ~= false)  -- default true
    showTooltipCheck:SetScript("OnClick", function(self)
        db.showMinimapTooltip = self:GetChecked()
    end)
    AddTooltip(showTooltipCheck, "Show or hide the tooltip when hovering over the minimap icon.")

    ---------------------------------------------------------------------------
    -- Persistent Window Toggle
    ---------------------------------------------------------------------------
    local windowDivider = categoryFrame:CreateTexture(nil, "ARTWORK")
    windowDivider:SetHeight(1)
    windowDivider:SetPoint("TOPLEFT", showTooltipCheck, "BOTTOMLEFT", 5, -10)
    windowDivider:SetWidth(560)
    windowDivider:SetColorTexture(1, 1, 1, 0.2)

    local windowBehaviorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    windowBehaviorLabel:SetPoint("TOPLEFT", windowDivider, "BOTTOMLEFT", 0, -15)
    windowBehaviorLabel:SetText("Window Behavior")

    local persistentCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    persistentCheck:SetPoint("TOPLEFT", windowBehaviorLabel, "BOTTOMLEFT", -5, -5)
    persistentCheck.text:SetText("Persistent Window")
    persistentCheck:SetChecked(db.persistentWindow == true)
    persistentCheck:SetScript("OnClick", function(self)
        db.persistentWindow = self:GetChecked()
    end)
    AddTooltip(persistentCheck, "When enabled, the slider window stays open when clicking outside.\nUse Escape or the X button to close.")
end

-------------------------------------------------------------------------------
-- CreateAutomationSettingsContents
--
-- Internal function to build the actual UI elements of the trigger settings
-- panel. Called lazily open first show.
-------------------------------------------------------------------------------
function VS:CreateAutomationSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB
    db.presets = db.presets or {}

    local scrollFrame = CreateFrame("ScrollFrame", "VSAutomationSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local contentFrame = CreateFrame("Frame", "VSAutomationSettingsContentFrame", scrollFrame)
    contentFrame:SetSize(600, 800) 
    scrollFrame:SetScrollChild(contentFrame)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        contentFrame:SetWidth(width)
    end)

    local title = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Automation")

    local desc = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(560)
    desc:SetText("Configure presets and apply them manually, or assign zones for them to trigger automatically.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Master Toggle
    ---------------------------------------------------------------------------
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

    local enableCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 10, -15)
    enableCheck.text:SetFontObject("GameFontNormal")
    enableCheck.text:SetText("Zone Triggers")
    enableCheck:SetChecked(db.enableTriggers == true)

    enableCheck:SetScript("OnClick", function(self)
        db.enableTriggers = self:GetChecked()
        if VS.Presets and VS.Presets.RefreshEventState then
            VS.Presets:RefreshEventState()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    AddTooltip(enableCheck, "Automatically adjust volume levels when entering zones designated in your presets. Original volumes are restored when leaving the area.")

    local fishingCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    fishingCheck:SetPoint("TOPLEFT", enableCheck, "TOPRIGHT", 100, 0)
    fishingCheck.text:SetFontObject("GameFontNormal")
    fishingCheck.text:SetText("Fishing Splash Boost")
    fishingCheck:SetChecked(db.enableFishingVolume == true)

    fishingCheck:SetScript("OnClick", function(self)
        db.enableFishingVolume = self:GetChecked()
        if VS.Fishing and VS.Fishing.Initialize then
            VS.Fishing:Initialize()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    AddTooltip(fishingCheck, "Temporarily overrides volumes while fishing so you can clearly hear the bobber splash. Disabled during combat.")

    local lfgCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    lfgCheck:SetPoint("TOPLEFT", fishingCheck, "TOPRIGHT", 130, 0)
    lfgCheck.text:SetFontObject("GameFontNormal")
    lfgCheck.text:SetText("LFG Queue Pop Boost")
    lfgCheck:SetChecked(db.enableLfgVolume == true)

    lfgCheck:SetScript("OnClick", function(self)
        db.enableLfgVolume = self:GetChecked()
        if VS.LFGQueue and VS.LFGQueue.Initialize then
            VS.LFGQueue:Initialize()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    AddTooltip(lfgCheck, "Temporarily overrides volumes when the Dungeon Ready prompt appears.")

    local separator1 = contentFrame:CreateTexture(nil, "ARTWORK")
    separator1:SetHeight(1)
    separator1:SetPoint("LEFT", enableCheck, "LEFT", -10, 0)
    separator1:SetPoint("TOP", enableCheck, "BOTTOM", 0, -10)
    separator1:SetWidth(540)
    separator1:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Volume Slider Helpers
    ---------------------------------------------------------------------------
    local function CreateVolSlider(label, dbKey, dbToggleKey, anchorFrame, xOff, yOff, tooltip)
        local toggleCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
        toggleCheck:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOff, yOff)
        toggleCheck.text:SetFontObject("GameFontNormal")
        toggleCheck.text:SetText(label)
        toggleCheck:SetChecked(db[dbToggleKey] ~= false) -- Default true if nil

        toggleCheck:SetScript("OnClick", function(self)
            db[dbToggleKey] = self:GetChecked()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        AddTooltip(toggleCheck, "Toggle volume override for this specific channel.")

        local input = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
        input:SetSize(45, 20)
        input:SetPoint("LEFT", toggleCheck.text, "RIGHT", 10, 0)
        input:SetAutoFocus(false)
        input:SetNumeric(true)
        input:SetMaxLetters(3)
        input:SetText(tostring(math.floor((db[dbKey] or 1.0) * 100)))
        input:SetCursorPosition(0)

        local slider = CreateFrame("Slider", nil, contentFrame, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", toggleCheck, "BOTTOMLEFT", 0, -5)
        slider:SetWidth(150)
        slider:SetMinMaxValues(0, 100)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(math.floor((db[dbKey] or 1.0) * 100))
        
        local tooltipText = tooltip .. " (0-100)"
        AddTooltip(slider, tooltipText)
        AddTooltip(input, tooltipText)
        
        -- Hide default UI elements on the template
        for _, region in ipairs({slider:GetRegions()}) do
            if region:GetObjectType() == "FontString" then region:Hide() end
        end

        input:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                local num = tonumber(self:GetText())
                if num and num >= 0 and num <= 100 then
                    slider:SetValue(num)
                end
            end
        end)
        input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        input:SetScript("OnEscapePressed", function(self)
            self:SetText(tostring(math.floor((db[dbKey] or 1.0) * 100)))
            self:SetCursorPosition(0)
            self:ClearFocus()
        end)

        slider:SetScript("OnValueChanged", function(self, value)
            local num = math.floor(value + 0.5)
            self:SetValue(num)
            input:SetText(tostring(num))
            input:SetCursorPosition(0)
            db[dbKey] = num / 100.0
        end)
        
        -- Initialize value AFTER registering scripts so the data cascades correctly
        local initialVal = math.floor((db[dbKey] or 1.0) * 100)
        slider:SetValue(initialVal)
        input:SetText(tostring(initialVal))

        return slider, input, toggleCheck, toggleCheck.text
    end

    ---------------------------------------------------------------------------
    -- Fishing Settings
    ---------------------------------------------------------------------------
    local fishingLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fishingLabel:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 0, -15)
    fishingLabel:SetText("Fishing Splash Levels")

    local fMasterSlider, fMasterInput, fMasterToggle, fMasterLabel = CreateVolSlider("Master Volume %", "fishingTargetMaster", "enableFishingMaster", fishingLabel, 0, -15, "Target Master Volume while fishing.")
    local fSFXSlider, fSFXInput, fSFXToggle, fSFXLabel = CreateVolSlider("SFX Volume %", "fishingTargetSFX", "enableFishingSFX", fishingLabel, 240, -15, "Target SFX Volume while fishing.")

    VS.fishingMasterSlider = fMasterSlider
    VS.fishingMasterInput = fMasterInput
    VS.fishingSFXSlider = fSFXSlider
    VS.fishingSFXInput = fSFXInput

    local separator2 = contentFrame:CreateTexture(nil, "ARTWORK")
    separator2:SetHeight(1)
    separator2:SetPoint("LEFT", separator1, "LEFT", 0, 0)
    separator2:SetPoint("TOP", fMasterSlider, "BOTTOM", 0, -20)
    separator2:SetWidth(540)
    separator2:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- LFG Queue Settings
    ---------------------------------------------------------------------------
    local lfgQueueLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lfgQueueLabel:SetPoint("TOPLEFT", separator2, "BOTTOMLEFT", 0, -15)
    lfgQueueLabel:SetText("LFG Queue Levels")

    local lMasterSlider, lMasterInput, lMasterToggle, lMasterLabel = CreateVolSlider("Master Volume %", "lfgTargetMaster", "enableLfgMaster", lfgQueueLabel, 0, -15, "Target Master Volume when LFG queue pops.")
    local lSFXSlider, lSFXInput, lSFXToggle, lSFXLabel = CreateVolSlider("SFX Volume %", "lfgTargetSFX", "enableLfgSFX", lfgQueueLabel, 240, -15, "Target SFX Volume when LFG queue pops.")

    VS.lfgMasterSlider = lMasterSlider
    VS.lfgMasterInput = lMasterInput
    VS.lfgSFXSlider = lSFXSlider
    VS.lfgSFXInput = lSFXInput
    
    local separatorTop = contentFrame:CreateTexture(nil, "ARTWORK")
    separatorTop:SetHeight(2)
    separatorTop:SetPoint("LEFT", separator1, "LEFT", 0, 0)
    separatorTop:SetPoint("TOP", lMasterSlider, "BOTTOM", 0, -20)
    separatorTop:SetWidth(540)
    separatorTop:SetColorTexture(1, 1, 1, 0.2)
    
    function VS:RefreshAutomationTextInputs()
        if VS.fishingMasterSlider then 
            local val = math.floor((db.fishingTargetMaster or 1.0) * 100)
            VS.fishingMasterSlider:SetValue(val)
            VS.fishingMasterInput:SetText(tostring(val))
            VS.fishingMasterInput:SetCursorPosition(0)
        end
        if VS.fishingSFXSlider then 
            local val = math.floor((db.fishingTargetSFX or 1.0) * 100)
            VS.fishingSFXSlider:SetValue(val) 
            VS.fishingSFXInput:SetText(tostring(val))
            VS.fishingSFXInput:SetCursorPosition(0)
        end
        if VS.lfgMasterSlider then 
            local val = math.floor((db.lfgTargetMaster or 1.0) * 100)
            VS.lfgMasterSlider:SetValue(val) 
            VS.lfgMasterInput:SetText(tostring(val))
            VS.lfgMasterInput:SetCursorPosition(0)
        end
        if VS.lfgSFXSlider then 
            local val = math.floor((db.lfgTargetSFX or 1.0) * 100)
            VS.lfgSFXSlider:SetValue(val) 
            VS.lfgSFXInput:SetText(tostring(val))
            VS.lfgSFXInput:SetCursorPosition(0)
        end
    end
    
    -- Initialize values on creation
    VS:RefreshAutomationTextInputs()

    ---------------------------------------------------------------------------
    -- State & Management
    ---------------------------------------------------------------------------
    -- We need a working state for the currently selected/edited preset
    VS.PresetWorkingState = {
        name = "New Preset",
        priority = 10,
        zones = {},
        volumes = {},
        ignored = {},
        showInDropdown = true,
        index = nil -- The index in db.presets if it already exists
    }

    local currentSelectedIndex = nil
    local presetSliders = {}

    local presetDropdown = CreateFrame("DropdownButton", nil, contentFrame, "WowStyle1DropdownTemplate")
    presetDropdown:SetPoint("TOPLEFT", separatorTop, "BOTTOMLEFT", 10, -35)

    local priorityLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityLabel:SetPoint("BOTTOMLEFT", presetDropdown, "TOPLEFT", 0, 5)
    priorityLabel:SetText("Select Preset Profile")

    local btnDelete = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnDelete:SetSize(80, 22)
    btnDelete:SetPoint("TOPRIGHT", separatorTop, "BOTTOMRIGHT", -15, -35)
    btnDelete:SetText("Delete")

    local btnCopy = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnCopy:SetSize(80, 22)
    btnCopy:SetPoint("RIGHT", btnDelete, "LEFT", -5, 0)
    btnCopy:SetText("Copy")

    local btnSave = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnSave:SetSize(80, 22)
    btnSave:SetPoint("RIGHT", btnCopy, "LEFT", -5, 0)
    btnSave:SetText("Save")

    presetDropdown:SetPoint("RIGHT", btnSave, "LEFT", -15, 0)

    local btnMoveUp = CreateFrame("Button", nil, contentFrame)
    btnMoveUp:SetSize(22, 22)
    btnMoveUp:SetPoint("LEFT", btnDelete, "RIGHT", 5, 0)
    btnMoveUp:SetNormalAtlas("glues-characterselect-icon-arrowup")
    btnMoveUp:SetPushedAtlas("glues-characterselect-icon-arrowup-pressed")
    btnMoveUp:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    AddTooltip(btnMoveUp, "Move Preset Up")

    local btnMoveDown = CreateFrame("Button", nil, contentFrame)
    btnMoveDown:SetSize(22, 22)
    btnMoveDown:SetPoint("LEFT", btnMoveUp, "RIGHT", 5, 0)
    btnMoveDown:SetNormalAtlas("glues-characterSelect-icon-arrowDown")
    btnMoveDown:SetPushedAtlas("glues-characterSelect-icon-arrowDown-pressed")
    btnMoveDown:SetDisabledAtlas("glues-characterSelect-icon-arrowDown-disabled")
    btnMoveDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    AddTooltip(btnMoveDown, "Move Preset Down")

    ---------------------------------------------------------------------------
    -- Zone List & Priority Edit
    ---------------------------------------------------------------------------
    local nameLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", presetDropdown, "BOTTOMLEFT", 0, -30)
    nameLabel:SetText("Preset Name")

    local priorityEditLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityEditLabel:SetPoint("LEFT", nameLabel, "LEFT", 490, 0)
    priorityEditLabel:SetText("Priority")

    -- Add Tooltip for Priority
    priorityEditLabel:EnableMouse(true)
    priorityEditLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Priority Level", 1, 1, 1)
        GameTooltip:AddLine("Determines which preset wins if multiple zones overlap at the same time.", nil, nil, nil, true)
        GameTooltip:AddLine("Lower numbers have higher priority (e.g., Priority 1 will override Priority 10).", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    priorityEditLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local inputPriority = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    inputPriority:SetSize(40, 20)
    inputPriority:SetPoint("TOPLEFT", priorityEditLabel, "BOTTOMLEFT", 5, -5)
    inputPriority:SetNumeric(true)
    inputPriority:SetAutoFocus(false)

    local listOrderLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listOrderLabel:SetPoint("LEFT", nameLabel, "LEFT", 410, 0)
    listOrderLabel:SetText("List Order")

    -- Add Tooltip for List Order
    listOrderLabel:EnableMouse(true)
    listOrderLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("List Order", 1, 1, 1)
        GameTooltip:AddLine("Changes the order this preset appears in the quick apply dropdown.", nil, nil, nil, true)
        GameTooltip:AddLine("Lower numbers appear higher in the list.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    listOrderLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local inputListOrder = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    inputListOrder:SetSize(40, 20)
    inputListOrder:SetPoint("TOP", listOrderLabel, "BOTTOM", 0, -5)
    inputListOrder:SetNumeric(true)
    inputListOrder:SetAutoFocus(false)

    -- Split the list order arrows to surround the input field with reduced padding
    btnMoveUp:ClearAllPoints()
    btnMoveUp:SetPoint("TOPRIGHT", inputListOrder, "TOPLEFT", -3, 1)
    
    btnMoveDown:ClearAllPoints()
    btnMoveDown:SetPoint("TOPLEFT", inputListOrder, "TOPRIGHT", -1, 1)

    local inputName = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    inputName:SetHeight(20)
    inputName:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 5, -5)
    inputName:SetPoint("RIGHT", btnMoveUp, "LEFT", -10, 0)
    inputName:SetAutoFocus(false)

    local showDropdownCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    showDropdownCheck:SetPoint("TOPLEFT", inputName, "BOTTOMLEFT", -5, -15)
    showDropdownCheck.text:SetFontObject("GameFontNormal")
    showDropdownCheck.text:SetText("Show in main window presets list")
    showDropdownCheck:SetChecked(true)

    local zonesLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    zonesLabel:SetPoint("TOPLEFT", showDropdownCheck, "BOTTOMLEFT", 5, -15)
    zonesLabel:SetText("Monitored Zones (Optional, semicolon separated)")

    -- Add Tooltip for Zones
    zonesLabel:EnableMouse(true)
    zonesLabel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Monitored Zones", 1, 1, 1)
        GameTooltip:AddLine("Type zone names or subzones here in a semicolon-separated list.", nil, nil, nil, true)
        GameTooltip:AddLine("When the 'Zone Triggers' toggle is enabled above, these volume settings will automatically apply while your character is in these zones.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    zonesLabel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local btnAddCurrent = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnAddCurrent:SetSize(140, 22)
    btnAddCurrent:SetPoint("LEFT", zonesLabel, "LEFT", 320, 0)
    btnAddCurrent:SetText("Add Current Zone")

    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersZoneScrollFrame", contentFrame, "UIPanelScrollFrameTemplate")
    local INPUT_WIDTH = 500
    scrollFrame:SetSize(INPUT_WIDTH, 70) 
    scrollFrame:SetPoint("TOPLEFT", zonesLabel, "BOTTOMLEFT", 0, -10)
    
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
        local slider = VS:CreateTriggerSlider(slidersContainer, "VSPresetSlider"..chan.label, chan.label, chan.key, VS.PresetWorkingState, 0, 1, 0.01)
        
        -- Start hidden
        slider:Hide()
        slider:SetPoint("TOPLEFT", slidersContainer, "TOPLEFT", startX + (i-1) * (sliderWidth + sliderSpacing), -130)
        table.insert(presetSliders, slider)
    end

    ---------------------------------------------------------------------------
    -- Interaction Logic
    ---------------------------------------------------------------------------

    local function RefreshSliderUI()
        for _, slider in ipairs(presetSliders) do
            slider:Show()
            if slider.RefreshValue then
                slider:RefreshValue()
            end
        end
    end

    local function UpdateFormFromWorkingState()
        inputName:SetText(VS.PresetWorkingState.name)
        inputPriority:SetText(tostring(VS.PresetWorkingState.priority))
        inputListOrder:SetText(tostring(VS.PresetWorkingState.index or (#db.presets + 1)))
        showDropdownCheck:SetChecked(VS.PresetWorkingState.showInDropdown)
        
        local zStr = ""
        zStr = table.concat(VS.PresetWorkingState.zones, "; ")
        inputZones:SetText(zStr)

        RefreshSliderUI()
        
        if currentSelectedIndex then
            btnSave:Enable()
            btnCopy:Enable()
            btnDelete:Enable()
            if currentSelectedIndex > 1 then btnMoveUp:Enable() else btnMoveUp:Disable() end
            if currentSelectedIndex < #db.presets then btnMoveDown:Enable() else btnMoveDown:Disable() end
        else
            btnSave:Enable()
            btnCopy:Disable()
            btnDelete:Disable()
            btnMoveUp:Disable()
            btnMoveDown:Disable()
        end
    end

    local function LoadWorkingState(preset, index)
        VS.PresetWorkingState.name = preset and preset.name or "New Preset"
        VS.PresetWorkingState.priority = preset and (preset.priority or 10) or 10
        VS.PresetWorkingState.showInDropdown = preset and (preset.showInDropdown ~= false) or (preset == nil)
        VS.PresetWorkingState.index = index
        
        VS.PresetWorkingState.zones = {}
        VS.PresetWorkingState.volumes = {}
        VS.PresetWorkingState.ignored = {}

        if preset then
            for _, z in ipairs(preset.zones or {}) do table.insert(VS.PresetWorkingState.zones, z) end
            for k,v in pairs(preset.volumes or {}) do VS.PresetWorkingState.volumes[k] = v end
            for k,v in pairs(preset.ignored or {}) do VS.PresetWorkingState.ignored[k] = v end
        end
        
        -- Fill in any missing channels with the current CVar values so the sliders don't default to 100% incorrectly
        for channelKey, _ in pairs(VS.CVAR_TO_VAR) do
            if VS.PresetWorkingState.volumes[channelKey] == nil then
                VS.PresetWorkingState.volumes[channelKey] = tonumber(GetCVar(channelKey)) or 1
            end
        end
    end

    local function SelectNewProfile()
        currentSelectedIndex = nil
        LoadWorkingState(nil, nil)
        presetDropdown:SetDefaultText("Create New Preset")
        UpdateFormFromWorkingState()
    end

    local function GenerateDropdownMenu(dropdown, rootDescription)
        rootDescription:CreateButton("Create New Preset", function()
            SelectNewProfile()
            -- Force text update after dropdown closes
            dropdown:SetDefaultText("Create New Preset") 
        end)
        
        for i, preset in ipairs(db.presets) do
            rootDescription:CreateButton(preset.name .. " (Priority: " .. (preset.priority or 0) .. ")", function()
                currentSelectedIndex = i
                -- Deep copy preset so edits aren't live until saved
                LoadWorkingState(preset, i)
                
                presetDropdown:SetDefaultText(preset.name)
                UpdateFormFromWorkingState()
            end)
        end
    end

    local function RefreshDropdown()
        presetDropdown:SetupMenu(GenerateDropdownMenu)
        presetDropdown:GenerateMenu()
        
        if currentSelectedIndex and db.presets[currentSelectedIndex] then
            presetDropdown:SetDefaultText(db.presets[currentSelectedIndex].name)
        else
            -- Ensure New Profile is selected if none is active or list is empty
            SelectNewProfile()
        end
    end

    VS.RefreshPresetSettings = function()
        RefreshDropdown()
        
        -- If we have an active profile selected, ensure the working state matches it so the UI populates
        if currentSelectedIndex and db.presets[currentSelectedIndex] then
            LoadWorkingState(db.presets[currentSelectedIndex], currentSelectedIndex)
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
        VS.PresetWorkingState.name = inputName:GetText()
        if VS.PresetWorkingState.name == "" then VS.PresetWorkingState.name = "Unnamed Preset" end
        VS.PresetWorkingState.priority = tonumber(inputPriority:GetText()) or 10
        VS.PresetWorkingState.zones = ParseZones(inputZones:GetText())
        VS.PresetWorkingState.showInDropdown = showDropdownCheck:GetChecked()
        
        local desiredIndex = tonumber(inputListOrder:GetText()) or (#db.presets + 1)
        
        -- Serialize to DB
        local newObj = {
            name = VS.PresetWorkingState.name,
            priority = VS.PresetWorkingState.priority,
            zones = VS.PresetWorkingState.zones,
            volumes = {},
            ignored = {},
            showInDropdown = VS.PresetWorkingState.showInDropdown
        }
        for k,v in pairs(VS.PresetWorkingState.volumes) do newObj.volumes[k] = v end
        for k,v in pairs(VS.PresetWorkingState.ignored) do newObj.ignored[k] = v end

        if currentSelectedIndex then
            table.remove(db.presets, currentSelectedIndex)
        end
        
        -- Insert into array at the new desired position and shift boundaries
        desiredIndex = math.max(1, math.min(desiredIndex, #db.presets + 1))
        table.insert(db.presets, desiredIndex, newObj)
        currentSelectedIndex = desiredIndex
        VS.PresetWorkingState.index = currentSelectedIndex

        RefreshDropdown()
        if VS.Presets and VS.Presets.RefreshEventState then
            VS.Presets:RefreshEventState()
        end
        if VS.RefreshPopupDropdown then VS.RefreshPopupDropdown() end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    btnCopy:SetScript("OnClick", function()
        if currentSelectedIndex and db.presets[currentSelectedIndex] then
            VS.PresetWorkingState.name = VS.PresetWorkingState.name .. " (Copy)"
            currentSelectedIndex = nil
            VS.PresetWorkingState.index = nil
            presetDropdown:SetText(VS.PresetWorkingState.name)
            UpdateFormFromWorkingState()
        end
    end)

    StaticPopupDialogs["VolumeSlidersDeletePresetConfirm"] = {
        text = "Are you sure you want to delete this preset?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if currentSelectedIndex and db.presets[currentSelectedIndex] then
                table.remove(db.presets, currentSelectedIndex)
                currentSelectedIndex = nil
                LoadWorkingState(nil, nil)
                RefreshDropdown()
                UpdateFormFromWorkingState()
                
                if VS.Presets and VS.Presets.RefreshEventState then
                     VS.Presets:RefreshEventState()
                end
                if VS.RefreshPopupDropdown then VS.RefreshPopupDropdown() end
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,  -- Avoid UI taint
    }

    btnDelete:SetScript("OnClick", function()
        if currentSelectedIndex and db.presets[currentSelectedIndex] then
            StaticPopup_Show("VolumeSlidersDeletePresetConfirm")
        end
    end)
    
    local function SwapPresets(idxA, idxB)
        local temp = db.presets[idxA]
        db.presets[idxA] = db.presets[idxB]
        db.presets[idxB] = temp
        RefreshDropdown()
        
        if VS.Presets and VS.Presets.RefreshEventState then VS.Presets:RefreshEventState() end
        if VS.RefreshPopupDropdown then VS.RefreshPopupDropdown() end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    btnMoveUp:SetScript("OnClick", function()
        if currentSelectedIndex and currentSelectedIndex > 1 then
            SwapPresets(currentSelectedIndex, currentSelectedIndex - 1)
            currentSelectedIndex = currentSelectedIndex - 1
            VS.PresetWorkingState.index = currentSelectedIndex
            UpdateFormFromWorkingState()
        end
    end)

    btnMoveDown:SetScript("OnClick", function()
        if currentSelectedIndex and currentSelectedIndex < #db.presets then
            SwapPresets(currentSelectedIndex, currentSelectedIndex + 1)
            currentSelectedIndex = currentSelectedIndex + 1
            VS.PresetWorkingState.index = currentSelectedIndex
            UpdateFormFromWorkingState()
        end
    end)

    -- Initialize View
    btnSave:Disable()
    btnCopy:Disable()
    btnDelete:Disable()
    
    RefreshDropdown()
end


-------------------------------------------------------------------------------
-- CreateSlidersSettingsContents
-------------------------------------------------------------------------------
function VS:CreateSlidersSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB

    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersSlidersSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local categoryFrame = CreateFrame("Frame", "VolumeSlidersSlidersSettingsContentFrame", scrollFrame)
    categoryFrame:SetSize(600, 450) 
    scrollFrame:SetScrollChild(categoryFrame)

    -- Initial dummy resize, overwritten at end of function for dynamic columns
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Sliders Profile")

    local desc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Customize the color and style of the volume sliders.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Dropdown Menus
    ---------------------------------------------------------------------------
    local dropdownWidth = 160
    local dropdownSpacingOffset = -15 

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

    -- Title Color Label & Dropdown
    local titleColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleColorLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 35, -35)
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
    previewLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 220, -35)
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
    VS.previewSlider:Show()
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
    -- Visibility Checkboxes (3rd Column)
    ---------------------------------------------------------------------------
    local visibilityLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    visibilityLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 370, -35)
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
    }

    local previousCheckbox = nil
    for i, data in ipairs(checkboxes) do
        local checkbox = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
        if previousCheckbox then
            checkbox:SetPoint("TOPLEFT", previousCheckbox, "BOTTOMLEFT", 0, 8)
        else
            checkbox:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", -5, -10)
        end

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

    -- Sync preview appearance to current settings.
    VS:UpdateAppearance()

    -- Dynamic Column Layout
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
        local usableWidth = width - 40
        if usableWidth < 400 then usableWidth = 400 end
        
        local col1X = 10
        local col2X = col1X + (usableWidth * 0.42)
        local col3X = col2X + (usableWidth * 0.26)
        
        titleColorLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", col1X, -35)
        previewLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", col2X, -35)
        visibilityLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", col3X, -35)
    end)
    if scrollFrame:GetWidth() > 0 then
        scrollFrame:GetScript("OnSizeChanged")(scrollFrame, scrollFrame:GetWidth(), scrollFrame:GetHeight())
    end
end

-------------------------------------------------------------------------------
-- CreateWindowSettingsContents
-------------------------------------------------------------------------------
function VS:CreateWindowSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB

    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersWindowSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

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
    -- Window Background Color
    ---------------------------------------------------------------------------
    local function AddTooltipLoc(frame, text)
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end

    local bgColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bgColorLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 15, -30)
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
    swatchInner:SetColorTexture(db.bgColorR or 0.05, db.bgColorG or 0.05, db.bgColorB or 0.05, 1)

    local colorText = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    colorText:SetPoint("LEFT", colorSwatch, "RIGHT", 8, 0)
    colorText:SetText("Click to change")

    ---@diagnostic disable: undefined-global
    colorSwatch:SetScript("OnClick", function()
        local info = {}
        info.r = db.bgColorR or 0.05
        info.g = db.bgColorG or 0.05
        info.b = db.bgColorB or 0.05
        info.opacity = 1 - (db.bgColorA or 0.95) -- ColorPickerFrame uses inverted opacity
        info.hasOpacity = true
        info.swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            db.bgColorR = r
            db.bgColorG = g
            db.bgColorB = b
            swatchInner:SetColorTexture(r, g, b, 1)
            VS:ApplyWindowBackground()
        end
        info.opacityFunc = function()
            local a = 1 - ColorPickerFrame:GetColorAlpha()
            db.bgColorA = a
            VS:ApplyWindowBackground()
        end
        info.cancelFunc = function(previousValues)
            db.bgColorR = previousValues.r
            db.bgColorG = previousValues.g
            db.bgColorB = previousValues.b
            db.bgColorA = 1 - (previousValues.a or 0.05)
            swatchInner:SetColorTexture(db.bgColorR, db.bgColorG, db.bgColorB, 1)
            VS:ApplyWindowBackground()
        end
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    AddTooltipLoc(colorSwatch, "Click to choose a background color for the slider window.")
    ---@diagnostic enable: undefined-global

    -- Opacity Slider
    local opacityLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityLabel:SetPoint("TOPLEFT", colorSwatch, "BOTTOMLEFT", 0, -12)
    opacityLabel:SetText("Opacity")

    local opacitySlider = CreateFrame("Slider", "VolumeSlidersOpacitySlider", categoryFrame, "OptionsSliderTemplate")
    opacitySlider:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, -8)
    opacitySlider:SetWidth(150)
    opacitySlider:SetMinMaxValues(0, 100)
    opacitySlider:SetValueStep(1)
    opacitySlider:SetObeyStepOnDrag(true)
    opacitySlider:SetValue(math.floor((db.bgColorA or 0.95) * 100 + 0.5))
    if _G["VolumeSlidersOpacitySliderLow"] then _G["VolumeSlidersOpacitySliderLow"]:Hide() end
    if _G["VolumeSlidersOpacitySliderHigh"] then _G["VolumeSlidersOpacitySliderHigh"]:Hide() end
    if _G["VolumeSlidersOpacitySliderText"] then _G["VolumeSlidersOpacitySliderText"]:Hide() end

    local opacityValueText = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityValueText:SetPoint("LEFT", opacityLabel, "RIGHT", 8, 0)
    opacityValueText:SetText(tostring(math.floor((db.bgColorA or 0.95) * 100 + 0.5)) .. "%")

    opacitySlider:SetScript("OnValueChanged", function(self, value)
        local num = math.floor(value + 0.5)
        self:SetValue(num)
        db.bgColorA = num / 100
        opacityValueText:SetText(tostring(num) .. "%")
        VS:ApplyWindowBackground()
    end)
    AddTooltipLoc(opacitySlider, "Adjust the background opacity of the slider window.\n0% = fully transparent, 100% = fully opaque")

    ---------------------------------------------------------------------------
    -- Vertical Divider
    ---------------------------------------------------------------------------
    local dividerV = categoryFrame:CreateTexture(nil, "ARTWORK")
    dividerV:SetWidth(1)
    dividerV:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 220, -10)
    dividerV:SetPoint("BOTTOMLEFT", categoryFrame, "TOPLEFT", 220, -500)
    dividerV:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Visibility Checkboxes (Window Header Elements)
    ---------------------------------------------------------------------------
    local headerElementsLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    headerElementsLabel:SetPoint("TOPLEFT", dividerV, "TOPRIGHT", 25, -20)
    headerElementsLabel:SetText("Header Elements")

    local helpTextCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    helpTextCheck:SetPoint("TOPLEFT", headerElementsLabel, "BOTTOMLEFT", -5, -5)
    helpTextCheck.text:SetText("Help Text")
    helpTextCheck:SetChecked(db.showHelpText ~= false)
    helpTextCheck:SetScript("OnClick", function(self)
        db.showHelpText = self:GetChecked()
        VS:UpdateAppearance()
    end)
    AddTooltipLoc(helpTextCheck, "Show or hide the help instructions at the top.")

    local presetCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    presetCheck:SetPoint("LEFT", helpTextCheck.text, "RIGHT", 40, 0)
    presetCheck.text:SetText("Presets Dropdown")
    presetCheck:SetChecked(db.showPresetsDropdown ~= false)
    presetCheck:SetScript("OnClick", function(self)
        db.showPresetsDropdown = self:GetChecked()
        VS:UpdateAppearance()
    end)
    AddTooltipLoc(presetCheck, "Show or hide the quick-apply presets dropdown at the top.")

    local dividerH = categoryFrame:CreateTexture(nil, "ARTWORK")
    dividerH:SetHeight(1)
    dividerH:SetPoint("TOPLEFT", headerElementsLabel, "BOTTOMLEFT", -25, -45)
    dividerH:SetWidth(400)
    dividerH:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Channel Visibility
    ---------------------------------------------------------------------------
    local channelLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", opacitySlider, "BOTTOMLEFT", 0, -30)
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
    -- Footer Elements Drag Box
    ---------------------------------------------------------------------------
    if db.limitFooterCols == nil then db.limitFooterCols = false end
    if db.maxFooterCols == nil then db.maxFooterCols = 3 end

    local limitFooterCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    limitFooterCheck:SetPoint("TOPLEFT", dividerH, "BOTTOMLEFT", 25, -15)
    limitFooterCheck.text:SetText("Limit Footer Columns")
    limitFooterCheck:SetChecked(db.limitFooterCols)
    limitFooterCheck:SetScript("OnClick", function(self)
        db.limitFooterCols = self:GetChecked()
        VS:UpdateAppearance()
    end)
    AddTooltipLoc(limitFooterCheck, "Restrict the maximum number of items allowed per row in the footer.")

    local maxFooterInput = CreateFrame("EditBox", nil, categoryFrame, "InputBoxTemplate")
    maxFooterInput:SetSize(30, 20)
    maxFooterInput:SetPoint("LEFT", limitFooterCheck.text, "RIGHT", 15, 0)
    maxFooterInput:SetAutoFocus(false)
    maxFooterInput:SetNumeric(true)
    maxFooterInput:SetMaxLetters(2)
    maxFooterInput:SetFontObject("GameFontHighlight")
    maxFooterInput:SetText(tostring(db.maxFooterCols))
    maxFooterInput:SetCursorPosition(0)
    
    maxFooterInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local num = tonumber(self:GetText())
            if num and num > 0 and num <= 20 then
                db.maxFooterCols = num
                VS:FlagLayoutDirty()
            end
        end
    end)
    maxFooterInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    maxFooterInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(db.maxFooterCols or 3))
        self:SetCursorPosition(0)
        self:ClearFocus()
    end)
    AddTooltipLoc(maxFooterInput, "Maximum items per row (1-20).")

    local footerLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    footerLabel:SetPoint("TOPLEFT", limitFooterCheck, "BOTTOMLEFT", 0, -15)
    footerLabel:SetText("Footer Elements")

    local footerSubLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footerSubLabel:SetPoint("TOP", footerLabel, "BOTTOM", 0, -2)
    footerSubLabel:SetText("(Drag to Reorder)")
    footerSubLabel:SetAlpha(0.6)

    local footerMap = {
        ["showZoneTriggers"] = { name = "Zone Triggers", tooltip = "Show or hide the Zone Triggers toggle." },
        ["showFishingSplash"] = { name = "Fishing Boost", tooltip = "Show or hide the Fishing Splash Boost toggle." },
        ["showLfgPop"] = { name = "LFG Pop Boost", tooltip = "Show or hide the LFG Pop Boost toggle." },
        ["showBackground"] = { name = "SBG Checkbox", tooltip = "Show or hide the 'Sound in Background' toggle." },
        ["showCharacter"] = { name = "Char Checkbox", tooltip = "Show or hide the 'Sound at Character' toggle." },
        ["showOutput"] = { name = "Output Selector", tooltip = "Show or hide the 'Output:' dropdown." },
        ["showVoiceMode"] = { name = "Voice Mode", tooltip = "Show or hide the Voice Chat Mode toggle." },
    }

    local footerBox = CreateFrame("Frame", nil, categoryFrame, "WowScrollBoxList")
    footerBox:SetSize(145, 230)
    footerBox:SetPoint("TOPLEFT", footerSubLabel, "BOTTOMLEFT", -5, -8)

    local footerDragBehavior 

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
        frame.checkbox:SetChecked(db[elementData] == true)
        frame.checkbox:SetScript("OnClick", function(self)
            db[elementData] = self:GetChecked()
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
        db.footerOrder = db.footerOrder or {}
        wipe(db.footerOrder)
        for _, key in dp:EnumerateEntireRange() do
            table.insert(db.footerOrder, key)
        end
        VS:UpdateAppearance()
    end)

    local function RefreshFooterDataProvider()
        local dataProvider = CreateDataProvider()
        local footerOrder = db.footerOrder or VS.DEFAULT_FOOTER_ORDER
        for _, key in ipairs(footerOrder) do
            dataProvider:Insert(key)
        end
        footerBox:SetDataProvider(dataProvider)
    end

    RefreshFooterDataProvider()

    RefreshFooterDataProvider()

    -- Column Layout cleanup since it is not fully dynamic columns anymore
    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)
    if scrollFrame:GetWidth() > 0 then
        scrollFrame:GetScript("OnSizeChanged")(scrollFrame, scrollFrame:GetWidth(), scrollFrame:GetHeight())
    end
end

-------------------------------------------------------------------------------
-- CreateMouseActionsSettingsContents
--
-- Builds the 3-column UI for mapping Hotkeys & Modifiers to UI element actions.
-------------------------------------------------------------------------------
function VS:CreateMouseActionsSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB
    if not db.mouseActions then
        db.mouseActions = { minimap = {}, sliders = {}, scrollWheel = {} }
    end

    local scrollFrame = CreateFrame("ScrollFrame", "VSMouseActionsSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local contentFrame = CreateFrame("Frame", "VSMouseActionsSettingsContentFrame", scrollFrame)
    contentFrame:SetSize(600, 800)
    scrollFrame:SetScrollChild(contentFrame)

    local title = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Mouse Actions")

    local desc = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetWidth(560)
    desc:SetText("Configure custom actions for clicking the Minimap Icon, Slider Buttons, or modifiers for the Slider Scroll Wheel. Click 'Record Input' then press a modifier (Shift/Ctrl/Alt) + Mouse Button or Scroll Wheel combination.")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    
    local function GetMinimapEffects()
        local list = {
            { id = "TOGGLE_WINDOW", name = "Toggle Slider Window" },
            { id = "MUTE_MASTER", name = "Toggle Master Mute" },
            { id = "OPEN_SETTINGS", name = "Open Settings Panel" },
            { id = "RESET_POSITION", name = "Reset Window Position" },
            { id = "TOGGLE_TRIGGERS", name = "Toggle Zone Triggers" }
        }
        if db.presets then
            for i, p in ipairs(db.presets) do
                table.insert(list, { id = "PRESET_" .. i, name = "Apply Preset: " .. p.name })
            end
        end
        return list
    end
    
    local sliderEffects = {
        { id = "ADJUST_1", name = "Change by 1%" },
        { id = "ADJUST_5", name = "Change by 5%" },
        { id = "ADJUST_10", name = "Change by 10%" },
        { id = "ADJUST_25", name = "Change by 25%" }
    }
    
    local scrollWheelEffects = {
        { id = "ADJUST_1", name = "Change by 1%" },
        { id = "ADJUST_5", name = "Change by 5%" },
        { id = "ADJUST_10", name = "Change by 10%" },
        { id = "ADJUST_25", name = "Change by 25%" }
    }
    
    local function GetEffectName(id, list)
        for _, eff in ipairs(list) do
            if eff.id == id then return eff.name end
        end
        return "Select Effect..."
    end

    local columns = {}
    local NUM_COLUMNS = 3
    local COLUMN_GAP = 40           -- space between columns (includes divider)
    local COLUMN_PADDING = 10       -- inner padding for elements inside each column
    local TOTAL_WIDTH = 560         -- usable content width
    local COL_WIDTH = math.floor((TOTAL_WIDTH - (COLUMN_GAP * (NUM_COLUMNS - 1))) / NUM_COLUMNS)
    local ELEMENT_WIDTH = COL_WIDTH - (COLUMN_PADDING * 2)
    local DELETE_BTN_SIZE = 20      -- approximate width of close button
    local CAPTURE_WIDTH = ELEMENT_WIDTH - DELETE_BTN_SIZE + 2  -- captureBtn sits next to delBtn
    
    -- Check if a trigger already exists in the given column's action list
    local function IsDuplicateTrigger(colKey, triggerStr, currentAction)
        local actions = db.mouseActions[colKey] or {}
        for _, action in ipairs(actions) do
            if action ~= currentAction and action.trigger == triggerStr then
                return true
            end
        end
        return false
    end
    
    local function RefreshColumn(colKey)
        local col = columns[colKey]
        if not col then return end
        
        -- Hide old rows
        for _, row in ipairs(col.rows) do
            row:Hide()
        end
        
        local yOffset = -30
        local actions = db.mouseActions[colKey] or {}
        local getEffectsFunc = col.getEffectsFunc
        
        for i, action in ipairs(actions) do
            local row = col.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, col.frame)
                row:SetSize(COL_WIDTH, 65)
                
                -- Capture Input Button
                row.captureBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.captureBtn:SetSize(CAPTURE_WIDTH, 22)
                row.captureBtn:SetPoint("TOPLEFT", row, "TOPLEFT", COLUMN_PADDING, 0)
                row.captureBtn:RegisterForClicks("AnyUp")
                row.captureBtn:EnableMouseWheel(true)
                
                -- Capture Input Tooltips
                row.captureBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    local txt = self:GetText()
                    if txt then
                        GameTooltip:SetText(txt, nil, nil, nil, nil, true)
                        GameTooltip:Show()
                    end
                end)
                row.captureBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                -- Effect Dropdown
                row.effectDrop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
                row.effectDrop:SetPoint("TOPLEFT", row.captureBtn, "BOTTOMLEFT", 0, -10)
                row.effectDrop:SetWidth(ELEMENT_WIDTH)
                
                -- Delete Button
                row.delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
                row.delBtn:SetPoint("LEFT", row.captureBtn, "RIGHT", -2, 0)
                
                -- Subtle bottom divider
                row.divider = row:CreateTexture(nil, "ARTWORK")
                row.divider:SetColorTexture(1, 1, 1, 0.15)
                row.divider:SetSize(ELEMENT_WIDTH, 1)
                row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", COLUMN_PADDING, 0)
                
                table.insert(col.rows, row)
            end
            
            row:Show()
            row:SetPoint("TOPLEFT", col.frame, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - 80
            
            row.captureBtn:SetText(action.trigger or (colKey == "scrollWheel" and "Record Modifier..." or "Record Input..."))
            
            row.captureBtn:SetScript("OnClick", function(self, btn)
                if self.isCapturing then
                    local mods = ""
                    if IsShiftKeyDown() then mods = mods .. "Shift+" end
                    if IsControlKeyDown() then mods = mods .. "Ctrl+" end
                    if IsAltKeyDown() then mods = mods .. "Alt+" end
                    
                    if colKey == "scrollWheel" then
                        -- Only capture modifier keys, ignore the mouse button
                        if mods == "" then
                            self:SetText("|cffffffffModifier Required|r")
                            C_Timer.After(1, function()
                                self:SetText(action.trigger or "Record Modifier...")
                                self.isCapturing = false
                            end)
                            return
                        end
                        -- Trim trailing '+' to produce clean trigger like "Shift" or "Ctrl+Alt"
                        local triggerStr = string.sub(mods, 1, -2)
                        
                        -- Prevent duplicate triggers within the same column
                        if IsDuplicateTrigger(colKey, triggerStr, action) then
                            self:SetText("|cffffffffAlready Assigned|r")
                            C_Timer.After(1, function()
                                self:SetText(action.trigger or "Record Modifier...")
                                self.isCapturing = false
                            end)
                            return
                        end
                        
                        action.trigger = triggerStr
                        self:SetText(triggerStr)
                        self.isCapturing = false
                    else
                        local triggerStr = mods .. btn
                        
                        -- Prevent duplicate triggers within the same column
                        if IsDuplicateTrigger(colKey, triggerStr, action) then
                            self:SetText("|cffffffffAlready Assigned|r")
                            C_Timer.After(1, function()
                                self:SetText(action.trigger or "Record Input...")
                                self.isCapturing = false
                            end)
                            return
                        end
                        
                        action.trigger = triggerStr
                        self:SetText(triggerStr)
                        self.isCapturing = false
                    end
                else
                    self:SetText(colKey == "scrollWheel" and "Hold Modifier + Click..." or "Press Bind Now...")
                    self.isCapturing = true
                end
            end)
            
            row.captureBtn:SetScript("OnMouseWheel", function(self, delta)
                if self.isCapturing then
                    -- Scroll Wheel column only captures modifier keys, not scroll input
                    if colKey == "scrollWheel" then return end
                    
                    local mods = ""
                    if IsShiftKeyDown() then mods = mods .. "Shift+" end
                    if IsControlKeyDown() then mods = mods .. "Ctrl+" end
                    if IsAltKeyDown() then mods = mods .. "Alt+" end
                    local triggerStr = mods .. (delta > 0 and "WheelUp" or "WheelDown")
                    
                    -- Prevent duplicate triggers within the same column
                    if IsDuplicateTrigger(colKey, triggerStr, action) then
                        self:SetText("|cffffffffAlready Assigned|r")
                        C_Timer.After(1, function()
                            self:SetText(action.trigger or "Record Input...")
                            self.isCapturing = false
                        end)
                        return
                    end
                    
                    action.trigger = triggerStr
                    self:SetText(triggerStr)
                    self.isCapturing = false
                end
            end)
            
            row.effectDrop:SetupMenu(function(dropdown, rootDescription)
                local effects = type(getEffectsFunc) == "function" and getEffectsFunc() or getEffectsFunc
                for _, eff in ipairs(effects) do
                    rootDescription:CreateButton(eff.name, function()
                        action.effect = eff.id
                        dropdown:SetDefaultText(eff.name)
                    end)
                end
            end)
            
            local currentEffects = type(getEffectsFunc) == "function" and getEffectsFunc() or getEffectsFunc
            row.effectDrop:SetDefaultText(GetEffectName(action.effect, currentEffects))
            
            row.delBtn:SetScript("OnClick", function()
                table.remove(db.mouseActions[colKey], i)
                RefreshColumn(colKey)
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end)
        end
        
        col.addBtn:SetPoint("TOPLEFT", col.frame, "TOPLEFT", COLUMN_PADDING, yOffset)
    end
    
    local function CreateColumn(key, titleText, colIndex, getEffectsFunc)
        local xOffset = (colIndex - 1) * (COL_WIDTH + COLUMN_GAP)
        
        local frame = CreateFrame("Frame", nil, contentFrame)
        frame:SetSize(COL_WIDTH, 600)
        frame:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", xOffset, -20)
        
        if colIndex > 1 then
            local divider = contentFrame:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(1, 1, 1, 0.3)
            divider:SetSize(1, 550)
            divider:SetPoint("TOPLEFT", frame, "TOPLEFT", -(COLUMN_GAP / 2), 10)
        end
        
        local header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetPoint("TOP", frame, "TOP", 0, 0)
        header:SetText(titleText)
        header:SetJustifyH("CENTER")
        
        local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        addBtn:SetSize(ELEMENT_WIDTH, 22)
        addBtn:SetText("Add Action")
        addBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", COLUMN_PADDING, -30)
        addBtn:SetScript("OnClick", function()
            table.insert(db.mouseActions[key], { trigger = nil, effect = nil })
            RefreshColumn(key)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end)
        
        columns[key] = {
            frame = frame,
            addBtn = addBtn,
            rows = {},
            getEffectsFunc = getEffectsFunc
        }
        
        RefreshColumn(key)
    end
    
    CreateColumn("minimap", "Minimap Icon", 1, GetMinimapEffects)
    CreateColumn("sliders", "Slider Buttons", 2, sliderEffects)
    CreateColumn("scrollWheel", "Slider Scroll Wheel", 3, scrollWheelEffects)
    
    VS.RefreshMouseActionsUI = function()
        RefreshColumn("minimap")
        RefreshColumn("sliders")
        RefreshColumn("scrollWheel")
    end
end


