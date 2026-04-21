-------------------------------------------------------------------------------
-- Settings_Main.lua
--
-- Blizzard Settings page integration. Registers native canvas layout categories
-- and builds the multi-tabbed configuration UI.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local addonName, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local _G = _G
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local C_AddOns = _G.C_AddOns
local GetAddOnMetadata = _G.GetAddOnMetadata or (C_AddOns and C_AddOns.GetAddOnMetadata)

-------------------------------------------------------------------------------
-- Static Popups
-------------------------------------------------------------------------------
StaticPopupDialogs["VOLUME_SLIDERS_COPY_URL"] = {
    text = "Use Ctrl+C to copy the GitHub URL below:",
    button1 = _G.CLOSE,
    hasEditBox = 1,
    editBoxWidth = 260,
    maxLetters = 128,
    OnShow = function(self, url)
        -- Fix preserved: Using GetEditBox() for reliable access
        local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
        if editBox then
            editBox:SetText(url)
            editBox:HighlightText()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

-------------------------------------------------------------------------------
-- InitializeSettings
--
-- Registers the native WoW Options Settings page using a Canvas Layout.
-- This function orchestrates the modular settings subcategories.
-------------------------------------------------------------------------------
function VS:InitializeSettings()
    -- Main Category (Volume Sliders)
    local categoryFrame = CreateFrame("Frame", "VolumeSlidersOptionsFrame", _G.UIParent)
    local category, _ = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Volume Sliders")

    VS:CreateSettingsContents(categoryFrame)

    Settings.RegisterAddOnCategory(category)
    VS.settingsCategory = category

    -- Subcategory 1: Minimap Icon
    local minimapFrame = CreateFrame("Frame", "VolumeSlidersMinimapOptionsFrame", _G.UIParent)
    local minimapCategory, _ = Settings.RegisterCanvasLayoutSubcategory(category, minimapFrame, "Minimap Icon")
    Settings.RegisterAddOnCategory(minimapCategory)
    VS:CreateMinimapSettingsContents(minimapFrame)

    -- Subcategory 2: Sliders
    local slidersFrame = CreateFrame("Frame", "VolumeSlidersSlidersOptionsFrame", _G.UIParent)
    local slidersCategory, _ = Settings.RegisterCanvasLayoutSubcategory(category, slidersFrame, "Slider Customization")
    Settings.RegisterAddOnCategory(slidersCategory)
    VS:CreateSlidersSettingsContents(slidersFrame)

    -- Subcategory 3: Window
    local windowFrame = CreateFrame("Frame", "VolumeSlidersWindowOptionsFrame", _G.UIParent)
    local windowCategory, _ = Settings.RegisterCanvasLayoutSubcategory(category, windowFrame, "Window Customization")
    Settings.RegisterAddOnCategory(windowCategory)
    VS:CreateWindowSettingsContents(windowFrame)

    -- Subcategory 4: Automation
    local triggerFrame = CreateFrame("Frame", "VolumeSlidersTriggerOptionsFrame", _G.UIParent)
    local triggerCategory, _ = Settings.RegisterCanvasLayoutSubcategory(category, triggerFrame, "Automation")
    Settings.RegisterAddOnCategory(triggerCategory)
    VS:CreateAutomationSettingsContents(triggerFrame)

    -- Subcategory 5: Mouse Actions
    local mouseActionsFrame = CreateFrame("Frame", "VolumeSlidersMouseActionsOptionsFrame", _G.UIParent)
    local mouseActionsCategory, _ = Settings.RegisterCanvasLayoutSubcategory(category, mouseActionsFrame, "Mouse Actions")
    Settings.RegisterAddOnCategory(mouseActionsCategory)
    VS:CreateMouseActionsSettingsContents(mouseActionsFrame)

    -- Event Hooks for Lazy UI Updates
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
-- Internal function to build the main settings page (Landing Page).
-- @param parentFrame Frame The canvas frame provided by Blizzard Settings API.
-------------------------------------------------------------------------------
function VS:CreateSettingsContents(parentFrame)
    local scrollFrame = CreateFrame("ScrollFrame", "VolumeSlidersSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

    local categoryFrame = CreateFrame("Frame", "VolumeSlidersSettingsContentFrame", scrollFrame)
    categoryFrame:SetSize(600, 250)
    scrollFrame:SetScrollChild(categoryFrame)

    scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        categoryFrame:SetWidth(width)
    end)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    
    local versionStr = GetAddOnMetadata(addonName, "Version") or ""
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
    -- GitHub Feedback Section
    ---------------------------------------------------------------------------
    local feedbackHeader = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    feedbackHeader:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -20)
    feedbackHeader:SetText("Found a bug or have an idea?")
    feedbackHeader:SetTextColor(1, 0.82, 0) -- Gold

    local feedbackBody = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    feedbackBody:SetPoint("TOPLEFT", feedbackHeader, "BOTTOMLEFT", 0, -5)
    feedbackBody:SetWidth(540)
    feedbackBody:SetJustifyH("LEFT")
    feedbackBody:SetWordWrap(true)
    feedbackBody:SetText("Open an issue on GitHub — it's the fastest way to get help or request a feature.")

    local copyButton = CreateFrame("Button", nil, categoryFrame, "UIPanelButtonTemplate")
    copyButton:SetPoint("TOPLEFT", feedbackBody, "BOTTOMLEFT", 0, -10)
    copyButton:SetText("Copy GitHub Link")
    copyButton:SetWidth(140)
    copyButton:SetHeight(22)
    copyButton:SetScript("OnClick", function()
        StaticPopup_Show("VOLUME_SLIDERS_COPY_URL", nil, nil, "https://github.com/SheldonMichaels/WoW-Volume-Sliders/issues")
    end)
end
