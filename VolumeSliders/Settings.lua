-------------------------------------------------------------------------------
-- Settings.lua
--
-- Blizzard Settings page integration. Registers native canvas layout categories
-- and builds the multi-tabbed configuration UI (Presets, Sliders, Window,
-- Minimap, and Mouse Actions).
--
-- Handles lazy UI construction, preset CRUD (Create, Read, Update, Delete),
-- and dynamic drag-to-reorder for sliders and footer elements.
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
--
-- DESIGN: Modular Categories
-- To keep the settings panel manageable, it is divided into a main category
-- and five subcategories. Each subcategory is a discrete frame that uses
-- a ScrollFrame to handle overflow.
-------------------------------------------------------------------------------
function VS:InitializeSettings()
    -- Main Category (Volume Sliders)
    local categoryFrame = CreateFrame("Frame", "VolumeSlidersOptionsFrame", UIParent)
    local category, layout = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Volume Sliders")

    VS:CreateSettingsContents(categoryFrame)

    Settings.RegisterAddOnCategory(category)
    VS.settingsCategory = category

    -- Subcategory 1: Sliders
    local minimapFrame = CreateFrame("Frame", "VolumeSlidersMinimapOptionsFrame", UIParent)
    local minimapCategory, minimapLayout = Settings.RegisterCanvasLayoutSubcategory(category, minimapFrame, "Minimap Icon")
    Settings.RegisterAddOnCategory(minimapCategory)
    VS:CreateMinimapSettingsContents(minimapFrame)

    local slidersFrame = CreateFrame("Frame", "VolumeSlidersSlidersOptionsFrame", UIParent)
    local slidersCategory, slidersLayout = Settings.RegisterCanvasLayoutSubcategory(category, slidersFrame, "Slider Customization")
    Settings.RegisterAddOnCategory(slidersCategory)

    VS:CreateSlidersSettingsContents(slidersFrame)

    -- Subcategory 2: Window
    local windowFrame = CreateFrame("Frame", "VolumeSlidersWindowOptionsFrame", UIParent)
    local windowCategory, windowLayout = Settings.RegisterCanvasLayoutSubcategory(category, windowFrame, "Window Customization")
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
        if VS.RefreshAutomationProfiles then
            VS:RefreshAutomationProfiles()
        end
    end)

    mouseActionsFrame:SetScript("OnShow", function(self)
        if VS.RefreshMouseActionsUI then
            VS:RefreshMouseActionsUI()
        end
    end)

    minimapFrame:SetScript("OnShow", function(self)
        if VS.RefreshMinimapSettingsUI then
            VS:RefreshMinimapSettingsUI()
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

    -- No content; Persistent Window has been moved explicitly.
end

-------------------------------------------------------------------------------
-- CreateAutomationSettingsContents
--
-- Builds the "Automation" subcategory UI. This is the most complex settings
-- page, handling both simple master toggles and the full Preset CRUD system.
--
-- COMPONENT PARTS:
-- 1. Master Toggles: Zone Triggers, Fishing Boost, LFG Pop Boost.
-- 2. Preset Selectors: Maps specific automation events to profiles.
-- 3. Preset Editor: A state-managed form for creating/editing profiles.
--
-- @param parentFrame Frame The canvas frame provided by Blizzard Settings API.
-------------------------------------------------------------------------------
function VS:CreateAutomationSettingsContents(parentFrame)
    --- @type VolumeSlidersDB
    local db = VolumeSlidersMMDB
    db.automation.presets = db.automation.presets or {}

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
    enableCheck:SetChecked(db.automation.enableTriggers == true)

    enableCheck:SetScript("OnClick", function(self)
        db.automation.enableTriggers = self:GetChecked()
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
    fishingCheck:SetChecked(db.automation.enableFishingVolume == true)

    fishingCheck:SetScript("OnClick", function(self)
        db.automation.enableFishingVolume = self:GetChecked()
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
    lfgCheck:SetChecked(db.automation.enableLfgVolume == true)

    lfgCheck:SetScript("OnClick", function(self)
        db.automation.enableLfgVolume = self:GetChecked()
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
    -- Automation Preset Selectors
    ---------------------------------------------------------------------------
    --- Helper to create a dropdown for selecting a preset profile.
    -- @param label string The text to display above the dropdown.
    -- @param dbKey string The key in the database where the index is stored.
    -- @param anchorFrame Frame The frame to anchor the label to.
    -- @param xOff number Horizontal offset.
    -- @param yOff number Vertical offset.
    -- @param tooltip string Descriptive text shown on hover.
    -- @param anchorPoint string The relative point on the anchorFrame (defaults to BOTTOMLEFT).
    local function CreatePresetSelector(label, dbKey, anchorFrame, xOff, yOff, tooltip, anchorPoint)
        local fontString = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fontString:SetPoint("TOPLEFT", anchorFrame, anchorPoint or "BOTTOMLEFT", xOff, yOff)
        fontString:SetText(label)

        local dropdown = CreateFrame("DropdownButton", nil, contentFrame, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("TOPLEFT", fontString, "BOTTOMLEFT", -5, -5)
        dropdown:SetWidth(150)
        AddTooltip(dropdown, tooltip)

        return dropdown, fontString
    end

    local fishingDropdown, fishingLabel = CreatePresetSelector("Fishing Profile", "fishingPresetIndex", fishingCheck, 0, -15, "Select a preset profile to apply while fishing.")
    local lfgDropdown, lfgLabel = CreatePresetSelector("LFG Profile", "lfgPresetIndex", lfgCheck, 0, -15, "Select a preset profile to apply when a group queue pops.")

    --- Populates the dropdown menu with "None" and all user-defined presets.
    --- @param dropdown any The dropdown frame
    --- @param rootDescription any The root menu description
    --- @param dbKey "fishingPresetIndex"|"lfgPresetIndex" The automation pointer to update
    local function PopulateAutomationDropdown(dropdown, rootDescription, dbKey)
        rootDescription:CreateButton("None", function()
            db.automation[dbKey] = nil
            dropdown:SetDefaultText("None")
            VS.Presets:RefreshEventState()
        end)

        for i, preset in ipairs(db.automation.presets) do
            rootDescription:CreateButton(preset.name, function()
                db.automation[dbKey] = i
                dropdown:SetDefaultText(preset.name)
                VS.Presets:RefreshEventState()
            end)
        end
    end

    function VS:RefreshAutomationProfiles()
        fishingDropdown:SetupMenu(function(dropdown, rootDescription)
            PopulateAutomationDropdown(dropdown, rootDescription, "fishingPresetIndex")
        end)

        lfgDropdown:SetupMenu(function(dropdown, rootDescription)
            PopulateAutomationDropdown(dropdown, rootDescription, "lfgPresetIndex")
        end)

        local fishingPreset = db.automation.fishingPresetIndex and db.automation.presets[db.automation.fishingPresetIndex]
        fishingDropdown:SetDefaultText(fishingPreset and fishingPreset.name or "None")

        local lfgPreset = db.automation.lfgPresetIndex and db.automation.presets[db.automation.lfgPresetIndex]
        lfgDropdown:SetDefaultText(lfgPreset and lfgPreset.name or "None")
    end

    VS.fishingDropdown = fishingDropdown
    VS.lfgDropdown = lfgDropdown

    local separatorTop = contentFrame:CreateTexture(nil, "ARTWORK")
    separatorTop:SetHeight(2)
    separatorTop:SetPoint("LEFT", enableCheck, "LEFT", -10, 0)
    separatorTop:SetPoint("TOP", lfgDropdown, "BOTTOM", 0, -20)
    separatorTop:SetWidth(540)
    separatorTop:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Preset Configuration Info Text
    ---------------------------------------------------------------------------
    local presetInfoHeader = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    presetInfoHeader:SetPoint("TOPLEFT", separatorTop, "BOTTOMLEFT", 10, -15)
    presetInfoHeader:SetText("How Presets Work")
    presetInfoHeader:SetTextColor(1, 0.82, 0)

    local presetInfoBody = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    presetInfoBody:SetPoint("TOPLEFT", presetInfoHeader, "BOTTOMLEFT", 0, -5)
    presetInfoBody:SetWidth(540)
    presetInfoBody:SetJustifyH("LEFT")
    presetInfoBody:SetWordWrap(true)
    presetInfoBody:SetText("Presets set volume levels and can optionally mute specific channels. Zone automations apply and restore presets automatically as you move. Manual presets (from the main window dropdown or minimap hotkeys) work as toggles: the first activation applies the preset, and a second activation restores your previous values if nothing has changed in between.")

    ---------------------------------------------------------------------------
    -- Preset Management State & CRUD
    --
    -- To prevent accidental data loss, edits made in the settings UI are
    -- stored in `VS.PresetWorkingState` and only committed to the database
    -- when the "Save" button is clicked.
    ---------------------------------------------------------------------------
    VS.PresetWorkingState = {
        name = "New Preset",
        priority = 10,
        zones = {},
        volumes = {},
        ignored = {},
        mutes = {},
        modes = {},
        showInDropdown = true,
        index = nil -- The index in db.automation.presets if it already exists
    }

    local currentSelectedIndex = nil
    local presetSliders = {}

    local presetDropdown = CreateFrame("DropdownButton", nil, contentFrame, "WowStyle1DropdownTemplate")
    presetDropdown:SetPoint("TOPLEFT", presetInfoBody, "BOTTOMLEFT", 0, -25)

    local priorityLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityLabel:SetPoint("BOTTOMLEFT", presetDropdown, "TOPLEFT", 0, 5)
    priorityLabel:SetText("Select Preset Profile")

    local btnDelete = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnDelete:SetSize(80, 22)
    btnDelete:SetPoint("TOPRIGHT", presetInfoBody, "BOTTOMRIGHT", -15, -25)
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

    local zoneScrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersZoneScrollFrame", contentFrame, "UIPanelScrollFrameTemplate")
    local INPUT_WIDTH = 500
    zoneScrollFrame:SetSize(INPUT_WIDTH, 70)
    zoneScrollFrame:SetPoint("TOPLEFT", zonesLabel, "BOTTOMLEFT", 0, -10)

    -- Add a visual backing frame so it looks like an input box
    local scrollBg = CreateFrame("Frame", nil, zoneScrollFrame, "BackdropTemplate")
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
    scrollBg:SetFrameLevel(zoneScrollFrame:GetFrameLevel() - 1)

    local inputZones = CreateFrame("EditBox", nil, zoneScrollFrame)
    inputZones:SetMultiLine(true)
    inputZones:SetFontObject("ChatFontNormal")
    inputZones:SetWidth(INPUT_WIDTH)
    inputZones:SetAutoFocus(false)
    zoneScrollFrame:SetScrollChild(inputZones)

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
    separatorMid:SetPoint("TOPLEFT", zoneScrollFrame, "BOTTOMLEFT", -15, -35)
    separatorMid:SetWidth(540)
    separatorMid:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Faux Sliders Display Area
    ---------------------------------------------------------------------------
    local slidersContainer = CreateFrame("Frame", nil, contentFrame)
    slidersContainer:SetHeight(420)
    -- Vertical: below the separator. Horizontal: stretch to contentFrame edges.
    slidersContainer:SetPoint("TOP", separatorMid, "BOTTOM", 0, -10)
    slidersContainer:SetPoint("LEFT", contentFrame, "LEFT", 0, 0)
    slidersContainer:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)

    -- Define the channels we want faux sliders for (all CVar-based channels)
    local channels = {
        { key="Sound_MasterVolume", label="Master"},
        { key="Sound_SFXVolume", label="SFX"},
        { key="Sound_MusicVolume", label="Music"},
        { key="Sound_AmbienceVolume", label="Ambience"},
        { key="Sound_DialogVolume", label="Dialog"},
        { key="Sound_EncounterWarningsVolume", label="Warnings"},
        { key="Sound_GameplaySFX", label="Gameplay"},
        { key="Sound_PingVolume", label="Pings"}
    }

    local sliderWidth = VS.SLIDER_COLUMN_WIDTH or 60
    local sliderSpacing = 8  -- tight spacing to fit all 8 channels within 540px
    local totalWidth = (#channels * sliderWidth) + ((#channels - 1) * sliderSpacing)

    -- Position sliders centered within the container using an OnSizeChanged hook
    -- so they re-center if the settings panel is resized.
    local function RepositionSliders()
        local containerWidth = slidersContainer:GetWidth()
        if containerWidth <= 0 then containerWidth = 540 end
        local startX = (containerWidth - totalWidth) / 2
        for idx, slider in ipairs(presetSliders) do
            slider:ClearAllPoints()
            slider:SetPoint("TOPLEFT", slidersContainer, "TOPLEFT", startX + (idx-1) * (sliderWidth + sliderSpacing), -160)
        end
    end

    for _, chan in ipairs(channels) do
        local slider = VS:CreateTriggerSlider(slidersContainer, "VSPresetSlider"..chan.label, chan.label, chan.key, VS.PresetWorkingState, 0, 1, 0.01)

        -- Start hidden
        slider:Hide()
        table.insert(presetSliders, slider)
    end

    slidersContainer:SetScript("OnSizeChanged", function() RepositionSliders() end)
    C_Timer.After(0, RepositionSliders)  -- initial positioning after layout settles

    ---------------------------------------------------------------------------
    -- Automation Pointer Synchronization
    ---------------------------------------------------------------------------

    --- Synchronizes automation pointers (fishing/lfg) when the presets array is mutated.
    --- @param deletedIndex number The index being removed or moved FROM.
    --- @param insertedIndex number|nil Optional. The index being moved TO (for reordering).
    local function ShiftAutomationIndexes(deletedIndex, insertedIndex)
        --- @type VolumeSlidersDB
        local db = VolumeSlidersMMDB
        local keys = {"fishingPresetIndex", "lfgPresetIndex"}
        for _, key in ipairs(keys) do
            local idx = db.automation[key]
                    if idx then
                        if idx == deletedIndex then
                            -- The assigned preset is the one being moved or deleted
                            if insertedIndex then
                                ---@cast insertedIndex integer
                                db.automation[key --[[@as string]]] = insertedIndex
                            else
                                db.automation[key --[[@as string]]] = nil
                            end
                        elseif not insertedIndex then
                            -- Pure deletion: Shift down all items above the deleted hole
                            if idx > deletedIndex then
                                db.automation[key --[[@as string]]] = idx - 1
                            end
                        else
                            -- Reordering: A preset was moved from deletedIndex to insertedIndex.
                            -- Everyone in between shifts relative to the direction of travel.
                            if deletedIndex < insertedIndex then
                                -- Moved from top to bottom. Elements in (deletedIndex, insertedIndex] move UP
                                if idx > deletedIndex and idx <= insertedIndex then
                                    db.automation[key --[[@as string]]] = idx - 1
                                end
                            elseif deletedIndex > insertedIndex then
                                -- Moved from bottom to top. Elements in [insertedIndex, deletedIndex) move DOWN
                                if idx >= insertedIndex and idx < deletedIndex then
                                    db.automation[key --[[@as string]]] = idx + 1
                                end
                            end
                        end
                    end
        end

        if db.minimap and db.minimap.mouseActions then
            for _, action in ipairs(db.minimap.mouseActions) do
                if action.effect == "TOGGLE_PRESET" and action.stringTarget then
                    local idx = tonumber(action.stringTarget)
                    if idx then
                        if idx == deletedIndex then
                            if insertedIndex then
                                action.stringTarget = tostring(insertedIndex)
                            else
                                action.stringTarget = nil
                            end
                        elseif not insertedIndex then
                            if idx > deletedIndex then
                                action.stringTarget = tostring(idx - 1)
                            end
                        else
                            if deletedIndex < insertedIndex then
                                if idx > deletedIndex and idx <= insertedIndex then
                                    action.stringTarget = tostring(idx - 1)
                                end
                            elseif deletedIndex > insertedIndex then
                                if idx >= insertedIndex and idx < deletedIndex then
                                    action.stringTarget = tostring(idx + 1)
                                end
                            end
                        end
                    end
                end
            end
        end

        local function ShiftMap(map)
            if not map then return end
            if not insertedIndex then
                map[deletedIndex] = nil
                local newMap = {}
                for k, v in pairs(map) do
                    if k > deletedIndex then
                        newMap[k - 1] = v
                    elseif k < deletedIndex then
                        newMap[k] = v
                    end
                end
                wipe(map)
                for k, v in pairs(newMap) do map[k] = v end
            else
                local movedItem = map[deletedIndex]
                map[deletedIndex] = nil
                local newMap = {}
                for k, v in pairs(map) do
                    if deletedIndex < insertedIndex then
                        if k > deletedIndex and k <= insertedIndex then
                            newMap[k - 1] = v
                        else
                            newMap[k] = v
                        end
                    elseif deletedIndex > insertedIndex then
                        if k >= insertedIndex and k < deletedIndex then
                            newMap[k + 1] = v
                        else
                            newMap[k] = v
                        end
                    end
                end
                if movedItem ~= nil then
                    newMap[insertedIndex] = movedItem
                end
                wipe(map)
                for k, v in pairs(newMap) do map[k] = v end
            end
        end

        local sess = VS.session
        if sess then
            if sess.activeRegistry then
                ShiftMap(sess.activeRegistry["manual"])
            end
            ShiftMap(sess.manualActivationTimes)
        end
        if db.automation then
            ShiftMap(db.automation.activeManualPresets)
        end
    end

    ---------------------------------------------------------------------------
    -- Interaction Logic
    ---------------------------------------------------------------------------

    --- Updates the slider widgets (Master, SFX, etc.) to match the working state.
    local function RefreshSliderUI()
        for _, slider in ipairs(presetSliders) do
            slider:Show()
            if slider.RefreshValue then
                slider:RefreshValue()
            end
        end
    end

    --- Synchronizes all UI form elements (name, priority, zones) with the working state.
    local function UpdateFormFromWorkingState()
        if not inputName:HasFocus() then
            inputName:SetText(VS.PresetWorkingState.name)
            inputName:SetCursorPosition(0)
        end
        if not inputPriority:HasFocus() then
            inputPriority:SetText(tostring(VS.PresetWorkingState.priority))
            inputPriority:SetCursorPosition(0)
        end
        if not inputListOrder:HasFocus() then
            inputListOrder:SetText(tostring(VS.PresetWorkingState.index or (#db.automation.presets + 1)))
            inputListOrder:SetCursorPosition(0)
        end
        showDropdownCheck:SetChecked(VS.PresetWorkingState.showInDropdown)

        if not inputZones:HasFocus() then
            local zStr = table.concat(VS.PresetWorkingState.zones, "; ")
            inputZones:SetText(zStr)
        end

        RefreshSliderUI()

        if currentSelectedIndex then
            btnSave:Enable()
            btnCopy:Enable()
            btnDelete:Enable()
            if currentSelectedIndex > 1 then btnMoveUp:Enable() else btnMoveUp:Disable() end
            if currentSelectedIndex < #db.automation.presets then btnMoveDown:Enable() else btnMoveDown:Disable() end
        else
            btnSave:Enable()
            btnCopy:Disable()
            btnDelete:Disable()
            btnMoveUp:Disable()
            btnMoveDown:Disable()
        end
    end

    --- Deep-copies a DB preset into the working state for editing.
    -- @param preset table? The source preset (nil for a new preset).
    -- @param index number? The DB index (nil for a new preset).
    local function LoadWorkingState(preset, index)
        VS.PresetWorkingState.name = preset and preset.name or "New Preset"
        VS.PresetWorkingState.priority = preset and (preset.priority or 10) or 10
        VS.PresetWorkingState.showInDropdown = preset and (preset.showInDropdown ~= false) or (preset == nil)
        VS.PresetWorkingState.index = index

        VS.PresetWorkingState.zones = {}
        VS.PresetWorkingState.volumes = {}
        VS.PresetWorkingState.ignored = {}
        VS.PresetWorkingState.mutes = {}
        VS.PresetWorkingState.modes = {}

        if preset then
            for _, z in ipairs(preset.zones or {}) do table.insert(VS.PresetWorkingState.zones, z) end
            for k,v in pairs(preset.volumes or {}) do VS.PresetWorkingState.volumes[k] = v end
            for k,v in pairs(preset.ignored or {}) do VS.PresetWorkingState.ignored[k] = v end
            for k,v in pairs(preset.mutes or {}) do VS.PresetWorkingState.mutes[k] = v end
            for k,v in pairs(preset.modes or {}) do VS.PresetWorkingState.modes[k] = v end
        end

        -- Fill in any missing channels with the current CVar values so the sliders don't default to 100% incorrectly
        for channelKey, _ in pairs(VolumeSlidersMMDB.channels) do
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

        for i, preset in ipairs(db.automation.presets) do
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
        if currentSelectedIndex and db.automation.presets[currentSelectedIndex] then
            presetDropdown:SetDefaultText(db.automation.presets[currentSelectedIndex].name)
        else
            -- Ensure New Profile is selected if none is active or list is empty
            SelectNewProfile()
        end

        presetDropdown:SetupMenu(GenerateDropdownMenu)
        presetDropdown:GenerateMenu()

        if VS.RefreshAutomationProfiles then
            VS:RefreshAutomationProfiles()
        end
    end

    VS.RefreshPresetSettings = function()
        RefreshDropdown()

        -- If we have an active profile selected, ensure the working state matches it so the UI populates
        if currentSelectedIndex and db.automation.presets[currentSelectedIndex] then
            LoadWorkingState(db.automation.presets[currentSelectedIndex], currentSelectedIndex)
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

    --- COMMITS the current working state to the saved variables database.
    btnSave:SetScript("OnClick", function()
        VS.PresetWorkingState.name = inputName:GetText()
        if VS.PresetWorkingState.name == "" then VS.PresetWorkingState.name = "Unnamed Preset" end
        VS.PresetWorkingState.priority = tonumber(inputPriority:GetText()) or 10
        VS.PresetWorkingState.zones = ParseZones(inputZones:GetText())
        VS.PresetWorkingState.showInDropdown = showDropdownCheck:GetChecked()

        local desiredIndex = tonumber(inputListOrder:GetText()) or (#db.automation.presets + 1)

        -- Serialize to DB
        local newObj = {
            name = VS.PresetWorkingState.name,
            priority = VS.PresetWorkingState.priority,
            zones = VS.PresetWorkingState.zones,
            volumes = {},
            ignored = {},
            mutes = {},
            modes = {},
            showInDropdown = VS.PresetWorkingState.showInDropdown
        }
        for k,v in pairs(VS.PresetWorkingState.volumes) do newObj.volumes[k] = v end
        for k,v in pairs(VS.PresetWorkingState.ignored) do newObj.ignored[k] = v end
        for k,v in pairs(VS.PresetWorkingState.mutes or {}) do newObj.mutes[k] = v end
        for k,v in pairs(VS.PresetWorkingState.modes or {}) do newObj.modes[k] = v end

        if currentSelectedIndex then
            ShiftAutomationIndexes(currentSelectedIndex, desiredIndex)
            table.remove(db.automation.presets, currentSelectedIndex)
        end

        -- Insert into array at the new desired position and shift boundaries
        desiredIndex = math.max(1, math.min(desiredIndex, #db.automation.presets + 1))
        table.insert(db.automation.presets, desiredIndex, newObj)
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
        if currentSelectedIndex and db.automation.presets[currentSelectedIndex] then
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
            if currentSelectedIndex and db.automation.presets[currentSelectedIndex] then
                ShiftAutomationIndexes(currentSelectedIndex, nil)
                table.remove(db.automation.presets, currentSelectedIndex)
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
        if currentSelectedIndex and db.automation.presets[currentSelectedIndex] then
            StaticPopup_Show("VolumeSlidersDeletePresetConfirm")
        end
    end)

    local function SwapPresets(idxA, idxB)
        -- Swap pointers for automation
        local keys = {"fishingPresetIndex", "lfgPresetIndex"}
        for _, key in ipairs(keys) do
            if db.automation[key] == idxA then
                db.automation[key] = idxB
            elseif db.automation[key] == idxB then
                db.automation[key] = idxA
            end
        end

        local function SwapMap(map)
            if not map then return end
            local tempVal = map[idxA]
            map[idxA] = map[idxB]
            map[idxB] = tempVal
        end
        
        local sess = VS.session
        if sess then
            if sess.activeRegistry then SwapMap(sess.activeRegistry["manual"]) end
            SwapMap(sess.manualActivationTimes)
        end
        if db.automation then SwapMap(db.automation.activeManualPresets) end

        local temp = db.automation.presets[idxA]
        db.automation.presets[idxA] = db.automation.presets[idxB]
        db.automation.presets[idxB] = temp

        if db.minimap and db.minimap.mouseActions then
            for _, action in ipairs(db.minimap.mouseActions) do
                if action.effect == "TOGGLE_PRESET" and action.stringTarget then
                    local idx = tonumber(action.stringTarget)
                    if idx == idxA then
                        action.stringTarget = tostring(idxB)
                    elseif idx == idxB then
                        action.stringTarget = tostring(idxA)
                    end
                end
            end
        end

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
        if currentSelectedIndex and currentSelectedIndex < #db.automation.presets then
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
--
-- Builds the "Slider Customization" subcategory UI.
--
-- COMPONENT PARTS:
-- 1. Style Dropdowns: Knob, Arrow, and Font colors.
-- 2. Live Preview: A non-interactive slider that reflects changes in real-time.
-- 3. Visibility Grid: Checkboxes to toggle specific sub-elements globally.
--
-- @param parentFrame Frame The canvas frame provided by Blizzard Settings API.
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
        return db.appearance.titleColor == value
    end
    local function SetTitleSelected(value)
        db.appearance.titleColor = value
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
        return db.appearance.valueColor == value
    end
    local function SetValueSelected(value)
        db.appearance.valueColor = value
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
        return db.appearance.highColor == value
    end
    local function SetHighSelected(value)
        db.appearance.highColor = value
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
        return db.appearance.arrowStyle == value
    end
    local function SetArrowSelected(value)
        db.appearance.arrowStyle = value
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
        return db.appearance.knobStyle == value
    end
    local function SetKnobSelected(value)
        db.appearance.knobStyle = value
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
        return db.appearance.lowColor == value
    end
    local function SetLowSelected(value)
        db.appearance.lowColor = value
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
        { name = "Title", var = "showTitle", namespace = "toggles", tooltip = "Show or hide the channel name (e.g., 'Master') above each slider." },
        { name = "Value (%)", var = "showValue", namespace = "toggles", tooltip = "Show or hide the volume percentage text above each slider." },
        { name = "High Label", var = "showHigh", namespace = "toggles", tooltip = "Show or hide the '100%' label at the top of the slider track." },
        { name = "Up Arrow", var = "showUpArrow", namespace = "toggles", tooltip = "Show or hide the button for fine-tuning volume increments." },
        { name = "Slider Track", var = "showSlider", namespace = "toggles", tooltip = "Show or hide the main vertical slider bar and knob." },
        { name = "Down Arrow", var = "showDownArrow", namespace = "toggles", tooltip = "Show or hide the button for fine-tuning volume decrements." },
        { name = "Low Label", var = "showLow", namespace = "toggles", tooltip = "Show or hide the '0%' label at the bottom of the slider track." },
        { name = "Mute Button", var = "showMute", namespace = "toggles", tooltip = "Show or hide the mute checkbox and label below each slider." },
    }

    local previousCheckbox = nil
    for _, data in ipairs(checkboxes) do
        local checkbox = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
        if previousCheckbox then
            checkbox:SetPoint("TOPLEFT", previousCheckbox, "BOTTOMLEFT", 0, 8)
        else
            checkbox:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", -5, -10)
        end

        checkbox.text:SetText(data.name)
        checkbox:SetChecked(db[data.namespace][data.var] == true)

        checkbox:SetScript("OnClick", function(self)
            db[data.namespace][data.var] = self:GetChecked()
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
    -- Persistent Window
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
    AddTooltipLoc(persistentCheck, "When enabled, the slider window stays open when clicking outside.\nUse Escape or the X button to close.")

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
    AddTooltipLoc(colorSwatch, "Click to choose a background color for the slider window.")
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
    opacitySlider:SetValue(math.floor((db.appearance.bgColor.a or 0.95) * 100 + 0.5))
    if _G["VolumeSlidersOpacitySliderLow"] then _G["VolumeSlidersOpacitySliderLow"]:Hide() end
    if _G["VolumeSlidersOpacitySliderHigh"] then _G["VolumeSlidersOpacitySliderHigh"]:Hide() end
    if _G["VolumeSlidersOpacitySliderText"] then _G["VolumeSlidersOpacitySliderText"]:Hide() end

    local opacityValueText = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    opacityValueText:SetPoint("LEFT", opacitySlider, "RIGHT", 8, 0)
    opacityValueText:SetText(tostring(math.floor((db.appearance.bgColor.a or 0.95) * 100 + 0.5)) .. "%")

    opacitySlider:SetScript("OnValueChanged", function(self, value)
        local num = math.floor(value + 0.5)
        self:SetValue(num)
        db.appearance.bgColor.a = num / 100
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
    AddTooltipLoc(helpTextCheck, "Show or hide the help instructions at the top.")

    local presetCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    presetCheck:SetPoint("LEFT", helpTextCheck.text, "RIGHT", 40, 0)
    presetCheck.text:SetText("Presets Dropdown")
    presetCheck:SetChecked(db.toggles.showPresetsDropdown ~= false)
    presetCheck:SetScript("OnClick", function(self)
        db.toggles.showPresetsDropdown = self:GetChecked()
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
            table.insert(db.layout.sliderOrder, cvar)
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
    AddTooltipLoc(limitFooterCheck, "Restrict the maximum number of items allowed per row in the footer.")

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
    AddTooltipLoc(maxFooterInput, "Maximum items per row (1-20).")

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
            table.insert(db.layout.footerOrder, key)
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

-------------------------------------------------------------------------------
-- CreateMouseActionsSettingsContents
--
-- Builds the "Mouse Actions" subcategory UI.
--
-- COMPONENT PARTS:
-- 1. Slider Buttons Grid: Mappings for static buttons (Left, Right, etc.).
-- 2. Slider Scroll Wheel Grid: Mappings for modifiers (Shift, Ctrl) + Scroll.
-- 3. Minimap List: A dynamic list of custom hotkey bindings for the minimap icon.
--
-- @param parentFrame Frame The canvas frame provided by Blizzard Settings API.
-------------------------------------------------------------------------------
function VS:CreateMouseActionsSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB
    if not db.layout.mouseActions then
        db.layout.mouseActions = { sliders = {}, scrollWheel = {} }
    end
    if not db.minimap.mouseActions then
        db.minimap.mouseActions = {}
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
            { id = "TOGGLE_TRIGGERS", name = "Toggle Zone Triggers" },
            { id = "TOGGLE_PRESET", name = "Toggle Preset" },
            { id = "SCROLL_VOLUME", name = "Scroll Volume" }
        }
        return list
    end

    local sliderEffects = {
        { id = "ADJUST_1", name = "Change by 1%" },
        { id = "ADJUST_5", name = "Change by 5%" },
        { id = "ADJUST_10", name = "Change by 10%" },
        { id = "ADJUST_15", name = "Change by 15%" },
        { id = "ADJUST_20", name = "Change by 20%" },
        { id = "ADJUST_25", name = "Change by 25%" }
    }

    local scrollWheelEffects = {
        { id = "ADJUST_1", name = "Change by 1%" },
        { id = "ADJUST_5", name = "Change by 5%" },
        { id = "ADJUST_10", name = "Change by 10%" },
        { id = "ADJUST_15", name = "Change by 15%" },
        { id = "ADJUST_20", name = "Change by 20%" },
        { id = "ADJUST_25", name = "Change by 25%" }
    }

    local function GetEffectName(id, list)
        for _, eff in ipairs(list) do
            if eff.id == id then return eff.name end
        end
        return "Select Effect..."
    end

    local function IsDuplicateTrigger(colKey, triggerStr, currentEffectId)
        local actions = (colKey == "minimap") and db.minimap.mouseActions or db.layout.mouseActions[colKey]
        for _, action in ipairs(actions) do
            if action.effect ~= currentEffectId and action.trigger == triggerStr then
                return true
            end
        end
        return false
    end

    local TOTAL_WIDTH = 560
    local sections = {}

    local MODIFIER_OPTIONS = {
        { id = "None", name = "No Modifier" },
        { id = "Shift", name = "Shift" },
        { id = "Ctrl", name = "Ctrl" },
        { id = "Alt", name = "Alt" },
        { id = "Shift+Ctrl", name = "Shift+Ctrl" },
        { id = "Shift+Alt", name = "Shift+Alt" },
        { id = "Ctrl+Alt", name = "Ctrl+Alt" },
        { id = "Shift+Ctrl+Alt", name = "Shift+Ctrl+Alt" }
    }

    local SCROLL_MODIFIER_OPTIONS = {
        { id = "Disabled", name = "Disabled" },
        { id = "None", name = "No Modifier" },
        { id = "Shift", name = "Shift" },
        { id = "Ctrl", name = "Ctrl" },
        { id = "Alt", name = "Alt" },
        { id = "Shift+Ctrl", name = "Shift+Ctrl" },
        { id = "Shift+Alt", name = "Shift+Alt" },
        { id = "Ctrl+Alt", name = "Ctrl+Alt" },
        { id = "Shift+Ctrl+Alt", name = "Shift+Ctrl+Alt" }
    }

    local BUTTON_OPTIONS = {
        { id = "None", name = "None" },
        { id = "LeftButton", name = "Left Click" },
        { id = "RightButton", name = "Right Click" },
        { id = "MiddleButton", name = "Middle Click" },
        { id = "Button4", name = "Mouse Button 4" },
        { id = "Button5", name = "Mouse Button 5" }
    }

    --- Parses a trigger string (e.g. "Shift+LeftButton") into its component parts.
    -- @param triggerStr string The source trigger string.
    -- @return string modStr The modifier part (e.g. "Shift" or "None").
    -- @return string btnStr The button part (e.g. "LeftButton" or "None").
    local function ParseTriggerParts(triggerStr)
        if not triggerStr or triggerStr == "" then return "None", "None" end
        local mods = {}
        if string.find(triggerStr, "Shift") then table.insert(mods, "Shift") end
        if string.find(triggerStr, "Ctrl") then table.insert(mods, "Ctrl") end
        if string.find(triggerStr, "Alt") then table.insert(mods, "Alt") end

        local modStr = #mods > 0 and table.concat(mods, "+") or "None"

        local lastPlus = string.reverse(triggerStr):find("%+")
        local btnStr = lastPlus and string.sub(triggerStr, #triggerStr - lastPlus + 2) or triggerStr
        if btnStr == "None" or btnStr == "" or string.find(btnStr, "Shift") or string.find(btnStr, "Ctrl") or string.find(btnStr, "Alt") then
            btnStr = "None"
        end

        return modStr, btnStr
    end

    local function GetIntrinsicDefault(colKey, effectId)
        if colKey == "sliders" then
            return effectId == "ADJUST_5" and "LeftButton" or "None"
        elseif colKey == "scrollWheel" then
            return effectId == "ADJUST_1" and "None" or "Disabled"
        end
        return "None"
    end

    --- Saves a grid-based mouse action to the database.
    -- @param colKey string "sliders" or "scrollWheel".
    -- @param effectId string The mapped effect (e.g. "ADJUST_5").
    -- @param newTrigger string? The new trigger string (nil to reset to default).
    local function SaveGridAction(colKey, effectId, newTrigger)
        local defaultTrigger = GetIntrinsicDefault(colKey, effectId)
        if newTrigger == defaultTrigger then
            newTrigger = nil
        end

        local actions = (colKey == "minimap") and db.minimap.mouseActions or db.layout.mouseActions[colKey]

        -- Remove exact duplicate triggers within the same section to prevent overlap
        if newTrigger and newTrigger ~= "Disabled" then
            for i = #actions, 1, -1 do
                if actions[i].trigger == newTrigger and actions[i].effect ~= effectId then
                    table.remove(actions, i)
                end
            end
        end

        local found = false
        for _, action in ipairs(actions) do
            if action.effect == effectId then
                action.trigger = newTrigger
                found = true
                break
            end
        end

        if not found and newTrigger then
            table.insert(actions, { trigger = newTrigger, effect = effectId })
        end

        -- Clean up empty actions
        for i = #actions, 1, -1 do
            local a = actions[i]
            if not a.trigger or a.trigger == "" then
                table.remove(actions, i)
            end
        end

        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        VS.RefreshMouseActionsUI()
    end

    -- Function to create a fixed grid section for sliders/scrollWheel
    local function CreateGridSection(key, titleText, effectsList, yOffset, helpText)
        local section = CreateFrame("Frame", nil, contentFrame)
        local isDual = (key == "sliders")
        local rowHeight = isDual and 95 or 60

        local header = section:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", section, "TOPLEFT", 10, 0)
        header:SetText(titleText)

        local divider = section:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(1, 1, 1, 0.3)
        divider:SetSize(TOTAL_WIDTH - 20, 1)
        divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)

        local rowStartY = -10
        local textPadding = 0
        if helpText then
            local infoText = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            infoText:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
            infoText:SetWidth(TOTAL_WIDTH - 40)
            infoText:SetJustifyH("LEFT")
            infoText:SetWordWrap(true)
            infoText:SetTextColor(1, 1, 1)
            infoText:SetText(helpText)
            
            local stringHeight = infoText:GetStringHeight()
            textPadding = stringHeight + 10
            rowStartY = -10 - textPadding
        end

        local sectionHeight = 40 + textPadding + (2 * rowHeight)
        section:SetSize(TOTAL_WIDTH, sectionHeight)
        section:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, yOffset)

        section.cells = {}

        local colWidth = (TOTAL_WIDTH - 20) / 3
        local dropWidth = colWidth - 15

        for i, eff in ipairs(effectsList) do
            local cell = CreateFrame("Frame", nil, section)
            cell:SetSize(colWidth, rowHeight)

            local row = math.floor((i - 1) / 3)
            local col = (i - 1) % 3
            cell:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", col * colWidth, rowStartY - (row * rowHeight))

            local label = cell:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, 0)
            label:SetText(eff.name)

            local resetBtn = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
            resetBtn:SetSize(55, 20)
            resetBtn:SetPoint("LEFT", label, "RIGHT", 10, 0)
            resetBtn:SetText("Reset")

            local modDrop = CreateFrame("DropdownButton", nil, cell, "WowStyle1DropdownTemplate")
            modDrop:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8) -- slightly more padding
            modDrop:SetWidth(dropWidth)

            local btnDrop = nil
            if isDual then
                btnDrop = CreateFrame("DropdownButton", nil, cell, "WowStyle1DropdownTemplate")
                btnDrop:SetPoint("TOPLEFT", modDrop, "BOTTOMLEFT", 0, -5)
                btnDrop:SetWidth(dropWidth)
            end

            cell.modDrop = modDrop
            cell.btnDrop = btnDrop
            cell.resetBtn = resetBtn
            cell.effId = eff.id
            cell.isDual = isDual
            cell.key = key

            resetBtn:SetScript("OnClick", function()
                SaveGridAction(key, eff.id, nil)
                if modDrop.SetSelectionText then modDrop:SetSelectionText(nil) end
                if btnDrop and btnDrop.SetSelectionText then btnDrop:SetSelectionText(nil) end
            end)

            table.insert(section.cells, cell)
        end

        sections[key] = section
        return section, -(sectionHeight + 10)
    end

    -- Function to create the dynamic list section for Minimap
    local function CreateListSection(key, titleText, getEffectsFunc, yOffset)
        local section = CreateFrame("Frame", nil, contentFrame)
        section:SetSize(TOTAL_WIDTH, 400) -- Will adjust dynamically
        section:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, yOffset)

        local header = section:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", section, "TOPLEFT", 10, 0)
        header:SetText(titleText)

        local divider = section:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(1, 1, 1, 0.3)
        divider:SetSize(TOTAL_WIDTH - 20, 1)
        divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)

        local infoText = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        infoText:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
        infoText:SetWidth(TOTAL_WIDTH - 40)
        infoText:SetJustifyH("LEFT")
        infoText:SetWordWrap(true)
        infoText:SetTextColor(1, 1, 1)
        infoText:SetText("Preset hotkeys work as toggles. The first press applies, the second restores your previous values if channels haven't changed. If they have, it re-applies with a fresh snapshot.")
        section.infoText = infoText

        local addBtn = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
        addBtn:SetSize(150, 22)
        addBtn:SetText("Add Action")
        addBtn:SetScript("OnClick", function()
            table.insert(db.minimap.mouseActions, { trigger = nil, effect = nil })
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            VS.RefreshMouseActionsUI()
        end)

        section.addBtn = addBtn
        section.rows = {}
        section.getEffectsFunc = getEffectsFunc
        sections[key] = section
        return section
    end

    local yOff = -30
    local _, sectionHeight = CreateGridSection("sliders", "Slider Buttons", sliderEffects, yOff)
    yOff = yOff + sectionHeight
    local scrollHelp = "These settings apply ONLY to the scroll wheel while hovering over the sliders in the slider window."
    local scrollWheelSec, swSectionHeight = CreateGridSection("scrollWheel", "Slider Scroll Wheel", scrollWheelEffects, yOff, scrollHelp)
    
    yOff = yOff + swSectionHeight
    CreateListSection("minimap", "Minimap Icon", GetMinimapEffects, yOff)

    VS.RefreshMouseActionsUI = function()
        -- Refresh Grid Sections
        for _, key in ipairs({"sliders", "scrollWheel"}) do
            local sec = sections[key]
            for _, cell in ipairs(sec.cells) do
                local triggerStr = nil
                for _, action in ipairs(db.layout.mouseActions[key]) do
                    if action.effect == cell.effId then
                        triggerStr = action.trigger
                        break
                    end
                end

                local intrinsicDefault = GetIntrinsicDefault(key, cell.effId)

                if not triggerStr then
                    if key == "sliders" and intrinsicDefault == "LeftButton" then
                        -- Is LeftButton used by *any* custom action?
                        local leftUsed = false
                        for _, action in ipairs(db.layout.mouseActions.sliders) do
                            if string.match(action.trigger or "", "LeftButton") and action.trigger == "LeftButton" then
                                leftUsed = true
                                break
                            end
                        end
                        triggerStr = leftUsed and "None" or "LeftButton"
                    elseif key == "scrollWheel" and intrinsicDefault == "None" then
                        -- Is None used by *any* custom action?
                        local noneUsed = false
                        for _, action in ipairs(db.layout.mouseActions.scrollWheel) do
                            if action.trigger == "None" then
                                noneUsed = true
                                break
                            end
                        end
                        triggerStr = noneUsed and "Disabled" or "None"
                    else
                        triggerStr = intrinsicDefault
                    end
                end

                local isDefault = (triggerStr == intrinsicDefault)

                local activeMod, activeBtn = ParseTriggerParts(triggerStr)
                if key == "scrollWheel" then activeMod = triggerStr end -- Pure modifier string
                if activeMod == "" then activeMod = "None" end

                local activeModOpts = cell.isDual and MODIFIER_OPTIONS or SCROLL_MODIFIER_OPTIONS
                cell.modDrop:SetupMenu(function(dropdown, rootDescription)
                    for _, modOpt in ipairs(activeModOpts) do
                        rootDescription:CreateButton(modOpt.name, function()
                            local newMod = modOpt.id
                            local newTrigger
                            if cell.isDual then
                                if newMod == "None" and activeBtn == "None" then
                                    newTrigger = nil
                                elseif newMod == "None" then
                                    newTrigger = activeBtn
                                elseif activeBtn == "None" then
                                    -- Assigning a modifier without a button means we need a button. Default to LeftButton if they just clicked the modifier dropdown.
                                    newTrigger = newMod .. "+LeftButton"
                                else
                                    newTrigger = newMod .. "+" .. activeBtn
                                end
                            else
                                newTrigger = newMod
                            end
                            SaveGridAction(cell.key, cell.effId, newTrigger)
                        end)
                    end
                end)

                if cell.isDual then
                    cell.btnDrop:SetupMenu(function(dropdown, rootDescription)
                        for _, btnOpt in ipairs(BUTTON_OPTIONS) do
                            rootDescription:CreateButton(btnOpt.name, function()
                                local newBtn = btnOpt.id
                                local newTrigger
                                if newBtn == "None" then
                                    newTrigger = nil
                                elseif activeMod == "None" then
                                    newTrigger = newBtn
                                else
                                    newTrigger = activeMod .. "+" .. newBtn
                                end
                                SaveGridAction(cell.key, cell.effId, newTrigger)
                            end)
                        end
                    end)
                end

                -- Set Dropdown Selected Text
                local searchOpts = cell.isDual and MODIFIER_OPTIONS or SCROLL_MODIFIER_OPTIONS
                local displayModName = activeMod
                for _, m in ipairs(searchOpts) do if m.id == activeMod then displayModName = m.name; break end end
                local modText = isDefault and string.format("%s (Default)", displayModName) or displayModName
                cell.modDrop:SetDefaultText(modText)
                cell.modDrop:SetText(modText)
                if cell.modDrop.selectionText ~= nil then cell.modDrop.selectionText = nil end

                if cell.isDual then
                    local displayBtnName = "None"
                    for _, b in ipairs(BUTTON_OPTIONS) do if b.id == activeBtn then displayBtnName = b.name; break end end
                    local btnText = isDefault and string.format("%s (Default)", displayBtnName) or displayBtnName
                    cell.btnDrop:SetDefaultText(btnText)
                    cell.btnDrop:SetText(btnText)
                    if cell.btnDrop.selectionText ~= nil then cell.btnDrop.selectionText = nil end
                end

                -- Toggle Reset button
                local hasCustomBinding = false
                if db.layout.mouseActions[key] then
                    for _, action in ipairs(db.layout.mouseActions[key]) do
                        if action.effect == cell.effId and action.trigger then
                            hasCustomBinding = true
                            break
                        end
                    end
                end

                if not hasCustomBinding then
                    cell.resetBtn:Hide()
                else
                    cell.resetBtn:Show()
                end
            end
        end

        -- Refresh List Section (Minimap)
        local minSec = sections["minimap"]
        local actions = db.minimap.mouseActions or {}
        local rowYOffset = -65  -- Offset accounts for info text below the header

        for _, row in ipairs(minSec.rows) do row:Hide() end

        for i, action in ipairs(actions) do
            local row = minSec.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, minSec)
                local rowWidth = TOTAL_WIDTH - 20
                row:SetSize(rowWidth, 30)

                local delBtnWidth = 32
                local padding = 20 -- 10px between drops
                local remainingWidth = rowWidth - delBtnWidth - padding
                local captureBtnWidth = math.floor(remainingWidth * 0.30)
                local effectDropWidth = math.floor(remainingWidth * 0.25)
                local param1DropWidth = math.floor(remainingWidth * 0.25)
                local param2DropWidth = remainingWidth - captureBtnWidth - effectDropWidth - param1DropWidth

                row.captureBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.captureBtn:SetSize(captureBtnWidth, 22)
                row.captureBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.captureBtn:RegisterForClicks("AnyUp")
                row.captureBtn:EnableMouseWheel(true)

                row.effectDrop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
                row.effectDrop:SetPoint("LEFT", row.captureBtn, "RIGHT", 10, 0)
                
                row.param1Drop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
                row.param1Drop:SetPoint("LEFT", row.effectDrop, "RIGHT", 5, 0)
                
                row.param2Drop = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
                row.param2Drop:SetPoint("LEFT", row.param1Drop, "RIGHT", 5, 0)

                row.delBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
                row.delBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

                table.insert(minSec.rows, row)
            end

            row:Show()
            row:SetPoint("TOPLEFT", minSec, "TOPLEFT", 10, rowYOffset)
            rowYOffset = rowYOffset - 35

            row.captureBtn:SetText(action.trigger or "Record Input...")

            row.captureBtn:SetScript("OnClick", function(self, btn)
                if self.isCapturing then
                    local mods = ""
                    if IsShiftKeyDown() then mods = mods .. "Shift+" end
                    if IsControlKeyDown() then mods = mods .. "Ctrl+" end
                    if IsAltKeyDown() then mods = mods .. "Alt+" end
                    local triggerStr = mods .. btn

                    if IsDuplicateTrigger("minimap", triggerStr, nil) and triggerStr ~= action.trigger then
                        self:SetText("|cffffffffAlready Assigned|r")
                        C_Timer.After(1, function()
                            VS.RefreshMouseActionsUI()
                        end)
                        return
                    end

                    action.trigger = triggerStr
                    self.isCapturing = false
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    VS.RefreshMouseActionsUI()
                else
                    self:SetText("Press Bind Now...")
                    self.isCapturing = true
                end
            end)

            row.captureBtn:SetScript("OnMouseWheel", function(self, delta)
                if self.isCapturing then
                    local mods = ""
                    if IsShiftKeyDown() then mods = mods .. "Shift+" end
                    if IsControlKeyDown() then mods = mods .. "Ctrl+" end
                    if IsAltKeyDown() then mods = mods .. "Alt+" end
                    local triggerStr = mods .. "Scroll"

                    if IsDuplicateTrigger("minimap", triggerStr, action.effect) and triggerStr ~= action.trigger then
                        self:SetText("|cffffffffAlready Assigned|r")
                        C_Timer.After(1, function()
                            VS.RefreshMouseActionsUI()
                        end)
                        return
                    end

                    action.trigger = triggerStr
                    self.isCapturing = false
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    VS.RefreshMouseActionsUI()
                end
            end)

            row.effectDrop:SetupMenu(function(dropdown, rootDescription)
                local effects = type(minSec.getEffectsFunc) == "function" and minSec.getEffectsFunc() or minSec.getEffectsFunc
                for _, eff in ipairs(effects) do
                    rootDescription:CreateButton(eff.name, function()
                        action.effect = eff.id
                        action.stringTarget = nil
                        action.numStep = nil
                        dropdown:SetDefaultText(eff.name)
                        VS.RefreshMouseActionsUI()
                    end)
                end
            end)

            local currentEffects = type(minSec.getEffectsFunc) == "function" and minSec.getEffectsFunc() or minSec.getEffectsFunc
            local effectName = GetEffectName(action.effect, currentEffects)
            row.effectDrop:SetDefaultText(effectName)
            if row.effectDrop.selectionText ~= nil then row.effectDrop.selectionText = nil end
            row.effectDrop:SetText(effectName)

            -- Dynamic widths based on action type
            local rowWidth = TOTAL_WIDTH - 20
            local delBtnWidth = 32
            local padding = 20
            local remainingWidth = rowWidth - delBtnWidth - padding
            local captureBtnWidth = math.floor(remainingWidth * 0.30)
            local effectDropWidth = math.floor(remainingWidth * 0.25)
            local param1DropWidth = math.floor(remainingWidth * 0.25)
            local param2DropWidth = remainingWidth - captureBtnWidth - effectDropWidth - param1DropWidth

            row.param1Drop:Hide()
            row.param2Drop:Hide()
            row.effectDrop:SetWidth(math.floor(remainingWidth * 0.70))

            if action.effect == "TOGGLE_PRESET" then
                row.effectDrop:SetWidth(effectDropWidth)
                row.param1Drop:Show()
                row.param1Drop:SetWidth(param1DropWidth + param2DropWidth + 5)
                
                row.param1Drop:SetupMenu(function(dropdown, rootDescription)
                    if db.automation.presets then
                        for presetIdx, p in ipairs(db.automation.presets) do
                            rootDescription:CreateButton(p.name, function()
                                action.stringTarget = tostring(presetIdx)
                                dropdown:SetDefaultText(p.name)
                            end)
                        end
                    end
                end)
                
                local pName = "Select Preset..."
                if action.stringTarget and tonumber(action.stringTarget) and db.automation.presets[tonumber(action.stringTarget)] then
                    pName = db.automation.presets[tonumber(action.stringTarget)].name
                end
                row.param1Drop:SetDefaultText(pName)
                if row.param1Drop.selectionText ~= nil then row.param1Drop.selectionText = nil end
                row.param1Drop:SetText(pName)

            elseif action.effect == "SCROLL_VOLUME" then
                row.effectDrop:SetWidth(effectDropWidth + 10)
                row.param1Drop:Show()
                row.param1Drop:SetWidth(param1DropWidth + 15)
                row.param2Drop:Show()
                row.param2Drop:SetWidth(param2DropWidth - 25)
                
                local channels = {
                    {text="Master", val="Sound_MasterVolume"},
                    {text="SFX", val="Sound_SFXVolume"},
                    {text="Music", val="Sound_MusicVolume"},
                    {text="Ambience", val="Sound_AmbienceVolume"},
                    {text="Dialog", val="Sound_DialogVolume"},
                    {text="Voice", val="Voice_ChatVolume"},
                    {text="Mic", val="Voice_MicVolume"},
                    {text="Gameplay", val="Sound_GameplaySFX"},
                    {text="Pings", val="Sound_PingVolume"},
                    {text="Warnings", val="Sound_EncounterWarningsVolume"}
                }
                row.param1Drop:SetupMenu(function(dropdown, rootDescription)
                    for _, opt in ipairs(channels) do
                        rootDescription:CreateButton(opt.text, function()
                            action.stringTarget = opt.val
                            dropdown:SetDefaultText(opt.text)
                        end)
                    end
                end)
                local cName = "Select..."
                if action.stringTarget then
                    for _, opt in ipairs(channels) do
                        if opt.val == action.stringTarget then cName = opt.text; break end
                    end
                end
                row.param1Drop:SetDefaultText(cName)
                if row.param1Drop.selectionText ~= nil then row.param1Drop.selectionText = nil end
                row.param1Drop:SetText(cName)

                local steps = {
                    {text="1%", val=0.01},
                    {text="5%", val=0.05},
                    {text="10%", val=0.10},
                    {text="15%", val=0.15},
                    {text="20%", val=0.20},
                    {text="25%", val=0.25}
                }
                row.param2Drop:SetupMenu(function(dropdown, rootDescription)
                    for _, opt in ipairs(steps) do
                        rootDescription:CreateButton(opt.text, function()
                            action.numStep = opt.val
                            dropdown:SetDefaultText(opt.text)
                        end)
                    end
                end)
                local sName = "Step"
                if action.numStep then
                    for _, opt in ipairs(steps) do
                        if opt.val == action.numStep then sName = opt.text; break end
                    end
                end
                row.param2Drop:SetDefaultText(sName)
                if row.param2Drop.selectionText ~= nil then row.param2Drop.selectionText = nil end
                row.param2Drop:SetText(sName)
            end

            row.delBtn:SetScript("OnClick", function()
                table.remove(db.minimap.mouseActions, i)
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                VS.RefreshMouseActionsUI()
            end)
        end

        minSec.addBtn:SetPoint("TOPLEFT", minSec, "TOPLEFT", 10, rowYOffset)
    end

    VS.RefreshMouseActionsUI()
end

-------------------------------------------------------------------------------
-- CreateMinimapSettingsContents
--
-- Builds the "Minimap Icon" subcategory UI.
--
-- COMPONENT PARTS:
-- 1. Visuals: Toggle between standard and minimalist icon styles.
-- 2. Behavior: Reset position, Lock, and Bind-to-Minimap settings.
-- 3. Tooltip: A Drag-and-Drop system to customize the minimap tooltip contents.
--
-- @param parentFrame Frame The canvas frame provided by Blizzard Settings API.
-------------------------------------------------------------------------------
function VS:CreateMinimapSettingsContents(parentFrame)
    local db = VolumeSlidersMMDB

    local scrollFrame = CreateFrame("ScrollFrame", "VSMinimapSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.5)

    local categoryFrame = CreateFrame("Frame", "VSMinimapSettingsContentFrame", scrollFrame)
    categoryFrame:SetSize(600, 700)
    scrollFrame:SetScrollChild(categoryFrame)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Minimap Icon Customization")

    local desc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Configure the minimap icon appearance, scroll-wheel shortcuts, and custom tooltip.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Minimap Icon Settings
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

    local resetBtn = CreateFrame("Button", nil, categoryFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(115, 22)
    resetBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 10, -15)
    resetBtn:SetText("Reset Position")

    local lockIconCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    lockIconCheck:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", -10, -5)
    lockIconCheck.text:SetText("Lock Icon Position")
    lockIconCheck:SetChecked(db.minimap.minimapIconLocked ~= false)
    lockIconCheck:SetScript("OnClick", function(self)
        db.minimap.minimapIconLocked = self:GetChecked()
    end)
    AddTooltipLoc(lockIconCheck, "When checked, the minimap icon cannot be dragged. Uncheck to reposition the icon freely.")

    local customIconCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    customIconCheck:SetPoint("TOPLEFT", lockIconCheck, "BOTTOMLEFT", 0, 5)
    customIconCheck.text:SetText("Use Minimalist Speaker Icon")
    customIconCheck:SetChecked(db.minimap.minimalistMinimap)

    local bindMinimapCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    bindMinimapCheck:SetPoint("TOPLEFT", customIconCheck, "BOTTOMLEFT", 0, 5)
    bindMinimapCheck.text:SetText("Bind to Minimap")

    local function UpdateBindMinimapState()
        if db.minimap.minimalistMinimap then
            bindMinimapCheck:Enable()
            bindMinimapCheck.text:SetFontObject("GameFontNormalSmall")
            bindMinimapCheck:SetChecked(db.minimap.bindToMinimap)
        else
            bindMinimapCheck:Disable()
            bindMinimapCheck.text:SetFontObject("GameFontDisableSmall")
            bindMinimapCheck:SetChecked(true)
        end
    end
    UpdateBindMinimapState()

    customIconCheck:SetScript("OnClick", function(self)
        db.minimap.minimalistMinimap = self:GetChecked()
        UpdateBindMinimapState()
        if VS.UpdateMiniMapButtonVisibility then VS:UpdateMiniMapButtonVisibility() end
    end)
    AddTooltipLoc(customIconCheck, "Show a minimalist speaker near the zoom controls instead of the standard ringed minimap button.\n\n|cffff0000Note:|r Disabling this requires a UI reload to fully remove hooks.")

    bindMinimapCheck:SetScript("OnClick", function(self)
        db.minimap.bindToMinimap = self:GetChecked()
        if VS.UpdateMiniMapButtonVisibility then VS:UpdateMiniMapButtonVisibility() end
    end)
    AddTooltipLoc(bindMinimapCheck, "If checked, the custom icon fades in when hovering the Minimap.\nIf unchecked, it remains permanently visible.")

    resetBtn:SetScript("OnClick", function()
        VolumeSlidersMMDB.minimap.minimalistOffsetX = -35
        VolumeSlidersMMDB.minimap.minimalistOffsetY = -5
        if VS.minimalistButton then
            VS.minimalistButton:ClearAllPoints()
            VS.minimalistButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -35, -5)
        end
    end)
    AddTooltipLoc(resetBtn, "Reset the custom minimap icon position to its default location.")

    local showTooltipCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    showTooltipCheck:SetPoint("TOPLEFT", bindMinimapCheck, "BOTTOMLEFT", 0, 5)
    showTooltipCheck.text:SetText("Show Tooltip")
    showTooltipCheck:SetChecked(db.toggles.showMinimapTooltip ~= false)
    showTooltipCheck:SetScript("OnClick", function(self)
        db.toggles.showMinimapTooltip = self:GetChecked()
    end)
    AddTooltipLoc(showTooltipCheck, "Show or hide the tooltip when hovering over the minimap icon.")

    local dividerMid = categoryFrame:CreateTexture(nil, "ARTWORK")
    dividerMid:SetWidth(1)
    dividerMid:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 285, -15)
    dividerMid:SetPoint("BOTTOMLEFT", categoryFrame, "BOTTOMLEFT", 300, 20)
    dividerMid:SetColorTexture(1, 1, 1, 0.2)

    ---------------------------------------------------------------------------
    -- Tooltip Drag-and-Drop List
    ---------------------------------------------------------------------------
    local tooltipLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    tooltipLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 300, -15)
    tooltipLabel:SetText("Tooltip Elements")
    
    local tooltipDesc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tooltipDesc:SetPoint("TOPLEFT", tooltipLabel, "BOTTOMLEFT", 0, -5)
    tooltipDesc:SetWidth(280)
    tooltipDesc:SetJustifyH("LEFT")
    tooltipDesc:SetText("Customize what is displayed when hovering the minimap icon.")
    
    ---------------------------------------------------------------------------
    -- Add Item Dropdown
    ---------------------------------------------------------------------------
    local addBtn = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    addBtn:SetPoint("TOPLEFT", tooltipDesc, "BOTTOMLEFT", 0, -15)
    addBtn:SetWidth(280)
    addBtn:SetDefaultText("Add Tooltip Item...")

    local scrollBox = CreateFrame("Frame", nil, categoryFrame, "WowScrollBoxList")
    scrollBox:SetSize(280, 200)
    scrollBox:SetPoint("TOPLEFT", addBtn, "BOTTOMLEFT", 0, -20)
    
    local dragBehavior
    
    local function RowInitializer(frame, elementData)
        if not elementData then return end

        if not frame.initialized then
            frame:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = true, tileSize = 16, edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            frame:SetBackdropColor(0, 0, 0, 0.4)
            frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)

            local txt = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            txt:SetPoint("LEFT", 10, 0)
            frame.text = txt
            
            local delBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
            delBtn:SetPoint("RIGHT", -25, -1)
            frame.delBtn = delBtn

            local drag = frame:CreateTexture(nil, "ARTWORK")
            drag:SetAtlas("ReagentWizards-ReagentRow-Grabber")
            drag:SetSize(12, 18)
            drag:SetPoint("RIGHT", -6, 0)
            drag:SetAlpha(0.5)
            frame.drag = drag

            frame.initialized = true
        end

        local name = "Unknown"
        if elementData.type == "MouseActions" then
            name = "Mouse Action Bindings"
        elseif elementData.type == "OutputDevice" then
            name = "Current Audio Output Device"
        elseif elementData.type == "ActivePresets" then
            name = "Active Presets"
        elseif elementData.type == "ChannelVolume" then
            name = "Volume: " .. (elementData.channel or "")
        end
        frame.text:SetText(name)

        frame.delBtn:SetScript("OnClick", function()
            for i, item in ipairs(db.minimap.minimapTooltipOrder) do
                if item == elementData then
                    table.remove(db.minimap.minimapTooltipOrder, i)
                    break
                end
            end
            if VS.RefreshMinimapSettingsUI then VS.RefreshMinimapSettingsUI() end
        end)

        frame:SetScript("OnEnter", function(self)
            if dragBehavior and dragBehavior:GetDragging() then return end
            self:SetBackdropBorderColor(1, 0.8, 0, 0.5)
        end)
        frame:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)
        end)
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("VolumeSlidersTooltipRowTemplate", RowInitializer)
    view:SetPadding(5, 5, 0, 0, 4)
    scrollBox:Init(view)

    dragBehavior = ScrollUtil.AddLinearDragBehavior(scrollBox)
    dragBehavior:SetReorderable(true)
    dragBehavior:SetDragRelativeToCursor(true)

    dragBehavior:SetCursorFactory(function(elementData)
        return "VolumeSlidersTooltipRowTemplate", function(frame)
            RowInitializer(frame, elementData)
            frame:SetAlpha(0.6)
            frame:SetBackdropBorderColor(1, 0.8, 0, 0.8)
        end
    end)
    
    local dataProvider = CreateDataProvider()
    scrollBox:SetDataProvider(dataProvider)
    
    local function RefreshTooltipDataProvider()
        dataProvider:Flush()
        if db.minimap.minimapTooltipOrder then
            for _, item in ipairs(db.minimap.minimapTooltipOrder) do
                dataProvider:Insert(item)
            end
            local newHeight = math.max(50, (#db.minimap.minimapTooltipOrder * 36) + 10)
            scrollBox:SetHeight(newHeight)
        end
    end
    RefreshTooltipDataProvider()


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
        frame:SetSize(280, 3)
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
        db.minimap.minimapTooltipOrder = db.minimap.minimapTooltipOrder or {}
        wipe(db.minimap.minimapTooltipOrder)
        for _, item in dp:EnumerateEntireRange() do
            table.insert(db.minimap.minimapTooltipOrder, item)
        end
    end)
    
    addBtn:SetupMenu(function(dropdown, rootDescription)
        local function AddType(typ, channel)
            db.minimap.minimapTooltipOrder = db.minimap.minimapTooltipOrder or {}
            table.insert(db.minimap.minimapTooltipOrder, { type = typ, channel = channel })
            if VS.RefreshMinimapSettingsUI then VS.RefreshMinimapSettingsUI() end
        end
        
        rootDescription:CreateButton("Mouse Action Bindings", function() AddType("MouseActions") end)
        rootDescription:CreateButton("Active Presets", function() AddType("ActivePresets") end)
        rootDescription:CreateButton("Audio Output Device", function() AddType("OutputDevice") end)
        
        local channelsMenu = rootDescription:CreateButton("Channel Volume...")
        local channels = { "Sound_MasterVolume", "Sound_SFXVolume", "Sound_MusicVolume", "Sound_AmbienceVolume", "Sound_DialogVolume", "Voice_ChatVolume", "Voice_MicVolume" }
        for _, c in ipairs(channels) do
             channelsMenu:CreateButton(c, function() AddType("ChannelVolume", c) end)
        end
    end)

    VS.RefreshMinimapSettingsUI = function()
        UpdateBindMinimapState()
        RefreshTooltipDataProvider()
    end
end


