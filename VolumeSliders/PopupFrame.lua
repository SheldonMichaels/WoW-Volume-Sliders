-------------------------------------------------------------------------------
-- PopupFrame.lua
--
-- Main popup panel containing all volume sliders, bottom-row controls
-- (Character checkbox, Background checkbox, Output dropdown, Voice Mode),
-- and open/close behavior.
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
local tonumber   = tonumber
local tostring   = tostring
local pairs      = pairs
local ipairs     = ipairs
local select     = select
local tinsert    = tinsert
local GetCVar    = GetCVar
local SetCVar    = SetCVar

-------------------------------------------------------------------------------
-- CreateOptionsFrame
--
-- Lazily creates the main popup panel containing all sliders, the
-- bottom-row controls, and handles open/close behavior.
--
-- Uses Blizzard's SettingsFrameTemplate for the outer chrome.
-------------------------------------------------------------------------------
function VS:CreateOptionsFrame()
    if VS.container then return VS.container end

    -- Create the popup using the modern settings frame template.
    VS.container = CreateFrame("Frame", "VolumeSlidersFrame", UIParent, "SettingsFrameTemplate")
    VS.container:SetSize(300, VS.FRAME_HEIGHT)
    VS.container:SetPoint("CENTER")
    VS.container:SetFrameStrata("DIALOG")
    VS.container:SetFrameLevel(100)
    VS.container:SetClampedToScreen(true)
    VS.container:EnableMouse(true)

    -- Set the title bar text via the NineSlice's built-in Text font string.
    if VS.container.NineSlice and VS.container.NineSlice.Text then
        VS.container.NineSlice.Text:SetText("Volume Sliders")
    else
        -- Fallback: create our own title if the template layout differs.
        local titleText = VS.container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        titleText:SetText("Volume Sliders")
        titleText:SetPoint("TOP", VS.container, "TOP", 0, -5)
    end

    -- Wire the close button (provided by SettingsFrameTemplate).
    if VS.container.ClosePanelButton then
        VS.container.ClosePanelButton:SetScript("OnClick", function() VS.container:Hide() end)
    else
        -- Fallback close button if template doesn't include one.
        local closeButton = CreateFrame("Button", "VolumeSlidersFrameCloseButton", VS.container, "UIPanelCloseButtonDefaultAnchors")
        closeButton:SetScript("OnClick", function() VS.container:Hide() end)
    end

    -- Lock Toggle Button
    local lockBtn = CreateFrame("Button", "VolumeSlidersFrameLockButton", VS.container, "UIPanelButtonTemplate")
    lockBtn:SetSize(85, 22)

    local btnText = lockBtn:GetFontString()
    if btnText then
        btnText:SetFontObject("GameFontNormal")
    else
        lockBtn:SetNormalFontObject("GameFontNormal")
        lockBtn:SetHighlightFontObject("GameFontHighlight")
    end

    if VS.container.ClosePanelButton then
        lockBtn:SetPoint("RIGHT", VS.container.ClosePanelButton, "LEFT", -4, 0)
    else
        lockBtn:SetPoint("TOPRIGHT", VS.container, "TOPRIGHT", -30, -5)
    end

    local function UpdateLockIcon()
        if VolumeSlidersMMDB.isLocked then
            lockBtn:SetText("Locked")
        else
            lockBtn:SetText("Unlocked")
        end
    end

    lockBtn:SetScript("OnClick", function()
        VolumeSlidersMMDB.isLocked = not VolumeSlidersMMDB.isLocked
        UpdateLockIcon()
        if VolumeSlidersMMDB.isLocked then
            VS:Reposition()
        else
            VolumeSlidersMMDB.customX = VS.container:GetLeft()
            VolumeSlidersMMDB.customY = VS.container:GetBottom()
            VS:Reposition()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    lockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if VolumeSlidersMMDB.isLocked then
            GameTooltip:SetText("Window Locked\n\nClick to unlock and move freely.", nil, nil, nil, nil, true)
        else
            GameTooltip:SetText("Window Unlocked\n\nClick to lock to minimap button.", nil, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UpdateLockIcon()

    -- Settings Button
    local settingsBtn = CreateFrame("Button", "VolumeSlidersFrameSettingsButton", VS.container, "UIPanelButtonTemplate")
    settingsBtn:SetSize(85, 22)
    settingsBtn:SetText("Settings")

    local settingsBtnText = settingsBtn:GetFontString()
    if settingsBtnText then
        settingsBtnText:SetFontObject("GameFontNormal")
    else
        settingsBtn:SetNormalFontObject("GameFontNormal")
        settingsBtn:SetHighlightFontObject("GameFontHighlight")
    end

    settingsBtn:SetPoint("TOPLEFT", VS.container, "TOPLEFT", 6, -1)

    settingsBtn:SetScript("OnClick", function()
        if VS.settingsCategory and VS.settingsCategory.ID then
            Settings.OpenToCategory(VS.settingsCategory.ID)
        else
            Settings.OpenToCategory("Volume Sliders") -- Fallback for older API versions
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    settingsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings\n\nClick to open the Volume Sliders configuration page.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Drag functionality for the top bar
    VS.container:SetMovable(true)
    local dragFrame = CreateFrame("Frame", nil, VS.container)
    dragFrame:SetPoint("TOPLEFT", VS.container, "TOPLEFT", 0, 0)
    dragFrame:SetPoint("BOTTOMRIGHT", VS.container, "TOPRIGHT", 0, -40)
    dragFrame:EnableMouse(true)
    dragFrame:RegisterForDrag("LeftButton")

    dragFrame:SetScript("OnDragStart", function()
        if not VolumeSlidersMMDB.isLocked then
            VS.container:StartMoving()
        end
    end)
    dragFrame:SetScript("OnDragStop", function()
        VS.container:StopMovingOrSizing()
        if not VolumeSlidersMMDB.isLocked then
            VolumeSlidersMMDB.customX = VS.container:GetLeft()
            VolumeSlidersMMDB.customY = VS.container:GetBottom()
        end
    end)

    -- Replace the template's default light background with a darker one
    -- for better contrast against the volume controls.
    if VS.container.Bg then VS.container.Bg:Hide() end
    local newBg = VS.container:CreateTexture(nil, "BACKGROUND", nil, -1)
    newBg:SetPoint("TOPLEFT", VS.container, "TOPLEFT", VS.TEMPLATE_CONTENT_OFFSET_LEFT, -VS.TEMPLATE_CONTENT_OFFSET_TOP)
    newBg:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", -VS.TEMPLATE_CONTENT_OFFSET_RIGHT, VS.TEMPLATE_CONTENT_OFFSET_BOTTOM)
    newBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Register for Escape-key closing via the Blizzard UISpecialFrames list.
    tinsert(UISpecialFrames, VS.container:GetName())

    ---------------------------------------------------------------------------
    -- Event Handlers: Close on outside click / combat lockdown
    ---------------------------------------------------------------------------
    VS.container:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Auto-hide when entering combat to avoid taint issues.
            self:Hide()
        elseif event == "GLOBAL_MOUSE_DOWN" then
            -- Close the panel when the user clicks anywhere outside it.
            if self:IsShown() and not self:IsMouseOver() then
                -- Check if the mouse is currently hovering the expanded output list.
                -- Since the list extends below the main panel bounds, IsMouseOver()
                -- on the parent frame returns false.
                local ddList = VolumeSlidersOutputDropdown and VolumeSlidersOutputDropdown.list
                if ddList and ddList:IsShown() and ddList:IsMouseOver() then
                    return -- Don't hide the panel; the click is inside the list.
                end

                -- Also check if the click was on the minimap button itself.
                -- If it was, let the minimap button's OnClick handle the toggling
                -- instead of instantly hiding it here (which makes OnClick think it's closed and re-open it).
                if VS.minimapButton and VS.minimapButton:IsMouseOver() then
                    return
                end

                self:Hide()
            end
        end
    end)

    VS.container:SetScript("OnShow", function(self)
        -- Start listening for outside clicks when the panel opens.
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")

        -- Refresh all slider positions from current CVar values in case
        -- they were changed externally (e.g., via Blizzard Sound settings).
        if VS.sliders then
            for _, slider in pairs(VS.sliders) do
                 if slider.RefreshValue then slider:RefreshValue() end
            end
        end

        -- Refresh the "Sound at Character" checkbox.
        if VS.characterCheckbox then
             VS.characterCheckbox:SetChecked(GetCVar("Sound_ListenerAtCharacter") == "1")
        end

        -- Refresh the "Sound in Background" checkbox.
        if VS.backgroundCheckbox then
             VS.backgroundCheckbox:SetChecked(GetCVar("Sound_EnableSoundWhenGameIsInBG") == "1")
        end

        -- Refresh all mute checkboxes.
        if VS.sliders then
            for _, slider in pairs(VS.sliders) do
                 if slider.RefreshMute then slider:RefreshMute() end
            end
        end
    end)

    VS.container:SetScript("OnHide", function(self)
        -- Stop listening for outside clicks when the panel is closed.
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end)

    ---------------------------------------------------------------------------
    -- Content Frame (inside the NineSlice border insets)
    ---------------------------------------------------------------------------
    VS.contentFrame = CreateFrame("Frame", "VolumeSlidersContentFrame", VS.container)
    VS.contentFrame:SetPoint("TOPLEFT", VS.container, "TOPLEFT", VS.TEMPLATE_CONTENT_OFFSET_LEFT, -VS.TEMPLATE_CONTENT_OFFSET_TOP)
    VS.contentFrame:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", -VS.TEMPLATE_CONTENT_OFFSET_RIGHT, VS.TEMPLATE_CONTENT_OFFSET_BOTTOM)

    -- Instruction text displayed at the top of the panel.
    local instruction = VS.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instruction:SetPoint("TOP", VS.contentFrame, "TOP", 0, -VS.CONTENT_PADDING_TOP)
    instruction:SetText("Right-click on the icon to toggle master mute.")
    instruction:SetTextColor(1, 1, 1)

    ---------------------------------------------------------------------------
    -- Volume Sliders
    --
    -- Sliders are laid out in a horizontal row.  Each column is
    -- SLIDER_COLUMN_WIDTH wide with a dynamic spacing between them.
    ---------------------------------------------------------------------------
    local startX = VS.CONTENT_PADDING_X
    local startY = -(VS.CONTENT_PADDING_TOP + 95)
    local spacing = VolumeSlidersMMDB and VolumeSlidersMMDB.sliderSpacing or 10

    -- Master Volume
    local masterSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderMaster", "Master", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01)
    masterSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MasterVolume"] = masterSlider

    -- Effects Volume
    local sfxSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderSFX", "Effects", "Sound_SFXVolume", "Sound_EnableSFX", 0, 1, 0.01)
    sfxSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_SFXVolume"] = sfxSlider

    -- Music Volume
    local musicSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderMusic", "Music", "Sound_MusicVolume", "Sound_EnableMusic", 0, 1, 0.01)
    musicSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 2 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MusicVolume"] = musicSlider

    -- Ambience Volume
    local ambienceSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderAmbience", "Ambience", "Sound_AmbienceVolume", "Sound_EnableAmbience", 0, 1, 0.01)
    ambienceSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 3 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_AmbienceVolume"] = ambienceSlider

    -- Dialog Volume
    local dialogSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderDialogue", "Dialog", "Sound_DialogVolume", "Sound_EnableDialog", 0, 1, 0.01)
    dialogSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 4 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_DialogVolume"] = dialogSlider

    -- Warnings Volume (Gameplay Sound Effects)
    local warningsSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderWarnings", "Warnings", "Sound_EncounterWarningsVolume", "Sound_EnableEncounterWarningsSounds", 0, 1, 0.01)
    warningsSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 5 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_EncounterWarningsVolume"] = warningsSlider

    -- Voice Chat Volume
    local voiceChatSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderVoiceChat", "Voice", C_VoiceChat.GetOutputVolume, C_VoiceChat.SetOutputVolume, false, "Voice Chat Output Volume", "Voice_ChatVolume")
    voiceChatSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 6 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_ChatVolume"] = voiceChatSlider

    -- Voice Chat Ducking (Inverted: Game value is ducking 0-1 scale. UI value is 'ducking strength%')
    local duckingSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderVoiceDucking", "Voice BG", function() return C_VoiceChat.GetMasterVolumeScale() * 100 end, function(val) C_VoiceChat.SetMasterVolumeScale(val / 100) end, true, "Voice Chat Ducking\nLow = Game sound mutes entirely when players speak.\nHigh = Game sound ignores speaking players.", nil)
    duckingSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 7 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_ChatDucking"] = duckingSlider

    -- Microphone Volume
    local micVolSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderMicVolume", "Mic Vol", C_VoiceChat.GetInputVolume, C_VoiceChat.SetInputVolume, false, "Microphone Input Volume", "Voice_MicVolume")
    micVolSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 8 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_MicVolume"] = micVolSlider

    -- Microphone Sensitivity (Inverted)
    local micSensSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderMicSensitivity", "Mic Sens", C_VoiceChat.GetVADSensitivity, C_VoiceChat.SetVADSensitivity, true, "Microphone Activation Sensitivity", nil)
    micSensSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 9 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_MicSensitivity"] = micSensSlider

    ---------------------------------------------------------------------------
    -- Bottom Row Controls
    ---------------------------------------------------------------------------

    -- "Sound at Character" checkbox — toggles whether the listener position
    -- is at the player's character or at the camera.
    VS.characterCheckbox = VS:CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckChar", "Sound at Character", function(checked)
        if checked then
            SetCVar("Sound_ListenerAtCharacter", 1)
        else
            SetCVar("Sound_ListenerAtCharacter", 0)
        end
    end, function()
        return GetCVar("Sound_ListenerAtCharacter") == "1"
    end)
    VS.characterCheckbox:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", VS.CONTENT_PADDING_X, VS.CONTENT_PADDING_BOTTOM + 10)

    VS.backgroundCheckbox = VS:CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckBG", "Sound in Background", function(checked)
        if checked then
            SetCVar("Sound_EnableSoundWhenGameIsInBG", 1)
        else
            SetCVar("Sound_EnableSoundWhenGameIsInBG", 0)
        end
    end, function()
        return GetCVar("Sound_EnableSoundWhenGameIsInBG") == "1"
    end)
    -- Initial anchor, will be refined in the C_Timer block
    VS.backgroundCheckbox:SetPoint("TOPLEFT", VS.characterCheckbox, "BOTTOMLEFT", 0, -2)

    ---------------------------------------------------------------------------
    -- Sound Output Device Dropdown
    --
    -- Custom dropdown mimicking the WowStyle2DropdownTemplate visual style.
    -- Uses Blizzard atlas assets for all background/hover/pressed states:
    --   Background: common-dropdown-c-button, -hover-1, -pressed-1, -open, -disabled
    --   Arrow:      common-dropdown-c-button-hover-arrow (shown on hover only)
    --   List BG:    common-dropdown-c-bg
    ---------------------------------------------------------------------------

    -- "Output:" label
    VS.outputLabel = VS.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    VS.outputLabel:SetPoint("LEFT", VS.characterCheckbox.labelText, "RIGHT", 20, 0)
    VS.outputLabel:SetText("Output:")
    VS.outputLabel:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    VS.outputLabel:SetWidth(85)
    VS.outputLabel:SetJustifyH("RIGHT")

    -- Dropdown button
    VS.outputDropdown = CreateFrame("Button", "VolumeSlidersOutputDropdown", VS.contentFrame)
    VS.outputDropdown:SetSize(140, 26)
    VS.outputDropdown:SetPoint("LEFT", VS.outputLabel, "RIGHT", 5, 0)

    local dropdown = VS.outputDropdown
    local outputLabel = VS.outputLabel

    -- Background texture (Blizzard atlas, extends slightly beyond frame bounds
    -- to match the original template's visual padding).
    local ddBg = dropdown:CreateTexture(nil, "BACKGROUND")
    ddBg:SetAtlas("common-dropdown-c-button")
    ddBg:SetPoint("TOPLEFT", -7, 7)
    ddBg:SetPoint("BOTTOMRIGHT", 7, -7)
    dropdown.Background = ddBg

    -- Hover arrow indicator (only visible when the mouse is over the dropdown).
    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("common-dropdown-c-button-hover-arrow", true)
    arrow:SetPoint("BOTTOM", 0, -5)
    arrow:Hide()
    dropdown.Arrow = arrow

    -- Currently selected device name (allows wrapping to 2 lines).
    local ddText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ddText:SetPoint("LEFT", dropdown, "LEFT", 13, 0)
    ddText:SetPoint("RIGHT", dropdown, "RIGHT", -13, 0)
    ddText:SetJustifyH("CENTER")
    ddText:SetJustifyV("MIDDLE")
    ddText:SetWordWrap(false)
    ddText:SetMaxLines(1)
    ddText:SetSpacing(2)
    ddText:SetText("System Default")
    dropdown.text = ddText

    -- Dropdown visual state machine: swaps the background atlas based on
    -- whether the menu is open, the mouse is hovering, or the button is
    -- disabled.  The arrow is only shown on hover.
    local isMenuOpen = false

    local function UpdateDropdownState(isOver)
        if not dropdown:IsEnabled() then
            ddBg:SetAtlas("common-dropdown-c-button-disabled", true)
            arrow:Hide()
            return
        end
        if isMenuOpen then
            ddBg:SetAtlas("common-dropdown-c-button-open", true)
            arrow:SetShown(isOver)
        elseif isOver then
            ddBg:SetAtlas("common-dropdown-c-button-hover-1", true)
            arrow:Show()
        else
            ddBg:SetAtlas("common-dropdown-c-button", true)
            arrow:Hide()
        end
    end

    dropdown:SetScript("OnEnter", function(self) UpdateDropdownState(true) end)
    dropdown:SetScript("OnLeave", function(self) UpdateDropdownState(false) end)

    -- Dropdown list frame (appears below the button when clicked).
    local list = CreateFrame("Frame", nil, dropdown)
    list:SetPoint("TOP", dropdown, "BOTTOM", 0, 5)
    list:SetFrameStrata("TOOLTIP")
    list:SetFrameLevel(VS.container:GetFrameLevel() + 10)
    list:Hide()
    dropdown.list = list

    -- List background (Blizzard atlas, extends beyond the frame for the
    -- decorative shadow/glow effect).
    local listBg = list:CreateTexture(nil, "BACKGROUND")
    listBg:SetAtlas("common-dropdown-c-bg")
    listBg:SetPoint("TOPLEFT", -17, 12)
    listBg:SetPoint("BOTTOMRIGHT", 17, -22)

    --- Refresh the dropdown button text to reflect the currently active
    --- output device from the Sound_OutputDriverIndex CVar.
    local function RefreshDropdownText()
        local currentIndex = tonumber(GetCVar("Sound_OutputDriverIndex")) or 0
        local currentName = Sound_GameSystem_GetOutputDriverNameByIndex(currentIndex) or "System Default"
        dropdown.text:SetText(currentName)
    end
    dropdown.RefreshText = RefreshDropdownText

    -- OnClick: toggle the dropdown list and populate it with available
    -- output devices from the sound system.
    dropdown:SetScript("OnClick", function(self)
        if list:IsShown() then
            -- Close the list.
            list:Hide()
            isMenuOpen = false
            UpdateDropdownState(self:IsMouseOver())
        else
            -- Open the list and populate with sound output devices.
            list:Show()
            isMenuOpen = true
            UpdateDropdownState(self:IsMouseOver())

            local numDevices = Sound_GameSystem_GetNumOutputDrivers()
            local buttonHeight = 22

            -- Reusable font string for measuring text width to auto-size the list.
            if not list.measureFS then
                list.measureFS = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                list.measureFS:Hide()
            end
            local maxTextWidth = 0

            -- Button pool: reuse existing buttons, create new ones as needed.
            if not list.buttons then list.buttons = {} end

            -- Hide all existing buttons before re-populating.
            for _, btn in ipairs(list.buttons) do btn:Hide() end

            for i = 0, numDevices - 1 do
                local name = Sound_GameSystem_GetOutputDriverNameByIndex(i)

                -- Measure this device name to determine the minimum list width.
                list.measureFS:SetText(name)
                local w = list.measureFS:GetStringWidth()
                if w > maxTextWidth then maxTextWidth = w end

                local btnIndex = i + 1

                local btn = list.buttons[btnIndex]
                if not btn then
                    -- Create a new list item button.
                    btn = CreateFrame("Button", nil, list)
                    btn:SetHeight(buttonHeight)

                    local t = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                    t:SetPoint("LEFT", btn, "LEFT", 14, 0)
                    t:SetJustifyH("LEFT")
                    btn.text = t

                    -- Subtle highlight on hover.
                    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                    highlight:SetAllPoints(true)
                    highlight:SetColorTexture(1, 1, 1, 0.15)

                    btn:SetScript("OnEnter", function(b)
                        b.text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
                    end)
                    btn:SetScript("OnLeave", function(b)
                        if VERY_LIGHT_GRAY_COLOR then
                            b.text:SetTextColor(VERY_LIGHT_GRAY_COLOR:GetRGB())
                        else
                            -- Fallback for clients where VERY_LIGHT_GRAY_COLOR
                            -- is not defined.
                            b.text:SetTextColor(0.9, 0.9, 0.9)
                        end
                    end)

                    table.insert(list.buttons, btn)
                end

                -- Position and size the button within the list.
                btn:SetPoint("TOP", list, "TOP", 0, -6 - (btnIndex-1)*buttonHeight)
                btn:SetPoint("LEFT", list, "LEFT", 3, 0)
                btn:SetPoint("RIGHT", list, "RIGHT", -3, 0)

                -- Highlight the currently active device in gold.
                local currentIndex = tonumber(GetCVar("Sound_OutputDriverIndex")) or 0
                if i == currentIndex then
                    btn.text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
                else
                    if VERY_LIGHT_GRAY_COLOR then
                        btn.text:SetTextColor(VERY_LIGHT_GRAY_COLOR:GetRGB())
                    else
                        btn.text:SetTextColor(0.9, 0.9, 0.9)
                    end
                end

                btn.text:SetText(name)
                btn:SetScript("OnClick", function()
                    local db = VolumeSlidersMMDB
                    db.deviceVolumes = db.deviceVolumes or {}

                    -- Save the current master volume under the active device's name before swapping.
                    -- Ensure numeric storage for consistent retrieval later.
                    local oldIndex = tonumber(GetCVar("Sound_OutputDriverIndex")) or 0
                    local oldName = Sound_GameSystem_GetOutputDriverNameByIndex(oldIndex) or "System Default"
                    local currentMaster = tonumber(GetCVar("Sound_MasterVolume")) or 1
                    db.deviceVolumes[oldName] = currentMaster

                    -- Apply the selected output device and restart the sound system
                    SetCVar("Sound_OutputDriverIndex", i)
                    Sound_GameSystem_RestartSoundSystem()

                    -- Decide the target volume for the newly selected device.
                    local targetVol = tonumber(db.deviceVolumes[name]) or currentMaster

                    ---------------------------------------------------------
                    -- Visual Disable: dim the Master slider during recovery
                    ---------------------------------------------------------
                    local masterSlider = VS.sliders and VS.sliders["Sound_MasterVolume"]

                    local function DisableMasterSlider()
                        if not masterSlider then return end
                        masterSlider.isSwitching = true
                        masterSlider:EnableMouse(false)
                        masterSlider.upBtn:EnableMouse(false)
                        masterSlider.downBtn:EnableMouse(false)
                        -- Dim the visual elements
                        masterSlider.thumb:SetDesaturated(true)
                        masterSlider.thumb:SetAlpha(0.4)
                        masterSlider.trackTop:SetAlpha(0.3)
                        masterSlider.trackMiddle:SetAlpha(0.3)
                        masterSlider.trackBottom:SetAlpha(0.3)
                        masterSlider.upTex:SetDesaturated(true)
                        masterSlider.upTex:SetAlpha(0.4)
                        masterSlider.downTex:SetDesaturated(true)
                        masterSlider.downTex:SetAlpha(0.4)
                        -- Show switching indicator
                        masterSlider.valueText:SetText("|cff888888Switching...|r")
                    end

                    local function EnableMasterSlider()
                        if not masterSlider then return end
                        masterSlider.isSwitching = false
                        masterSlider:EnableMouse(true)
                        masterSlider.upBtn:EnableMouse(true)
                        masterSlider.downBtn:EnableMouse(true)
                        -- Restore visuals (UpdateAppearance will fix styles)
                        masterSlider.thumb:SetDesaturated(false)
                        masterSlider.thumb:SetAlpha(1)
                        masterSlider.trackTop:SetAlpha(1)
                        masterSlider.trackMiddle:SetAlpha(1)
                        masterSlider.trackBottom:SetAlpha(1)
                        masterSlider.upTex:SetDesaturated(false)
                        masterSlider.upTex:SetAlpha(1)
                        masterSlider.downTex:SetDesaturated(false)
                        masterSlider.downTex:SetAlpha(1)
                        -- Apply the correct appearance style (knob/arrow style)
                        VS:UpdateAppearance()
                    end

                    DisableMasterSlider()

                    -- Helper: apply the saved volume and sync the UI.
                    local function ApplyTargetVolume()
                        SetCVar("Sound_MasterVolume", targetVol)

                        if masterSlider then
                             masterSlider.isRefreshing = true
                             masterSlider:SetValue(1 - targetVol)
                             if not masterSlider.isSwitching then
                                 masterSlider.valueText:SetText(math_floor(targetVol * 100) .. "%")
                             end
                             masterSlider.isRefreshing = false
                        end
                        if VS.VolumeSlidersObject then
                            VS.VolumeSlidersObject.text = (math_floor(targetVol * 100)) .. "%"
                        end
                    end

                    -- Shared cleanup: re-enable the slider and tear down listeners.
                    local recoveryComplete = false
                    local function FinishRecovery()
                        if recoveryComplete then return end
                        recoveryComplete = true

                        ApplyTargetVolume()
                        EnableMasterSlider()

                        if dropdown.restartListener then
                            dropdown.restartListener.isRestartingAudio = false
                            dropdown.restartListener:UnregisterEvent("CVAR_UPDATE")
                        end
                        if dropdown.retryTicker then dropdown.retryTicker:Cancel() end
                        if dropdown.fallbackTimer then dropdown.fallbackTimer:Cancel() end
                    end

                    -- Cancel any prior restart recovery state
                    if dropdown.restartListener then
                        dropdown.restartListener:UnregisterAllEvents()
                    else
                        dropdown.restartListener = CreateFrame("Frame")
                    end
                    if dropdown.fallbackTimer then dropdown.fallbackTimer:Cancel() end
                    if dropdown.retryTicker then dropdown.retryTicker:Cancel() end

                    -- Event listener: catch the engine's forced CVar reset.
                    -- When caught, apply the volume immediately but keep the
                    -- slider visually disabled until the timer expires.
                    dropdown.restartListener.isRestartingAudio = true
                    dropdown.restartListener:RegisterEvent("CVAR_UPDATE")
                    dropdown.restartListener:SetScript("OnEvent", function(self, event, cvarName, value)
                        if self.isRestartingAudio and cvarName == "Sound_MasterVolume" then
                            -- The engine just reset the volume. Slam our saved volume back.
                            ApplyTargetVolume()

                            -- Don't fully clean up yet — keep the visual disable
                            -- active until the timer expires for a smooth experience.
                            self.isRestartingAudio = false
                            self:UnregisterEvent("CVAR_UPDATE")
                        end
                    end)

                    -- Repeating timer: re-apply the volume over 2 seconds and
                    -- then re-enable the Master slider on the final tick.
                    local retryCount = 0
                    dropdown.retryTicker = C_Timer.NewTicker(0.5, function(ticker)
                        retryCount = retryCount + 1
                        ApplyTargetVolume()
                        if retryCount >= 4 then
                            ticker:Cancel()
                            FinishRecovery()
                        end
                    end)

                    -- Safety net: clean up everything after 5 seconds
                    dropdown.fallbackTimer = C_Timer.NewTimer(5.0, function()
                        FinishRecovery()
                    end)

                    dropdown.text:SetText(name)
                    list:Hide()
                    isMenuOpen = false
                    UpdateDropdownState(dropdown:IsMouseOver())
                end)
                btn:Show()
            end

            -- Auto-size the list width to fit the longest device name.
            local requiredWidth = maxTextWidth + 40
            local minWidth = dropdown:GetWidth()
            list:SetWidth(math_max(requiredWidth, minWidth))
            list:SetHeight(numDevices * buttonHeight + 14)
        end
    end)

    -- Ensure the list is hidden when the dropdown or parent frame hides.
    dropdown:HookScript("OnHide", function()
        list:Hide()
        isMenuOpen = false
    end)
    -- Refresh selected device text whenever the dropdown becomes visible.
    dropdown:HookScript("OnShow", RefreshDropdownText)

    ---------------------------------------------------------------------------
    -- Voice Chat Mode Toggle
    ---------------------------------------------------------------------------

    VS.voiceModeLabel = VS.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    VS.voiceModeLabel:SetText("Voice Mode:")
    VS.voiceModeLabel:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    VS.voiceModeLabel:SetWidth(85)
    VS.voiceModeLabel:SetJustifyH("RIGHT")

    VS.voiceModeBtn = CreateFrame("Button", "VolumeSlidersVoiceModeButton", VS.contentFrame)
    VS.voiceModeBtn:SetSize(140, 26)

    -- Use the same standard dropdown/button styling as the output selector
    local vmBg = VS.voiceModeBtn:CreateTexture(nil, "BACKGROUND")
    vmBg:SetAtlas("common-dropdown-c-button")
    vmBg:SetPoint("TOPLEFT", -7, 7)
    vmBg:SetPoint("BOTTOMRIGHT", 7, -7)
    VS.voiceModeBtn.Background = vmBg

    local vmText = VS.voiceModeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vmText:SetPoint("CENTER", VS.voiceModeBtn, "CENTER", 0, 0)
    VS.voiceModeBtn.text = vmText

    local function RefreshVoiceModeText()
        if C_VoiceChat then
            local mode = C_VoiceChat.GetCommunicationMode()
            if mode == Enum.CommunicationMode.PushToTalk then
                vmText:SetText("Push to Talk")
            elseif mode == Enum.CommunicationMode.OpenMic then
                vmText:SetText("Open Mic")
            else
                vmText:SetText("Unknown")
            end
        end
    end
    VS.voiceModeBtn.RefreshText = RefreshVoiceModeText

    VS.voiceModeBtn:SetScript("OnEnter", function(self)
        vmBg:SetAtlas("common-dropdown-c-button-hover-1", true)
    end)
    VS.voiceModeBtn:SetScript("OnLeave", function(self)
        vmBg:SetAtlas("common-dropdown-c-button", true)
    end)

    VS.voiceModeBtn:SetScript("OnClick", function(self)
        if C_VoiceChat then
            local currentMode = C_VoiceChat.GetCommunicationMode()
            if currentMode == Enum.CommunicationMode.PushToTalk then
                C_VoiceChat.SetCommunicationMode(Enum.CommunicationMode.OpenMic)
            else
                C_VoiceChat.SetCommunicationMode(Enum.CommunicationMode.PushToTalk)
            end
            RefreshVoiceModeText()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)

    VS.voiceModeBtn:HookScript("OnShow", RefreshVoiceModeText)


    ---------------------------------------------------------------------------
    -- Bottom Row Centering
    ---------------------------------------------------------------------------
    -- Defer layout calculation slightly to ensure font strings have initialized
    -- their widths, then re-anchor the character checkbox to dynamically center
    -- the entire bottom row within the content width.
    -- Initial layout of the footer.
    C_Timer.After(0.01, function() VS:UpdateFooterLayout() end)

    -- Register combat lockdown event and start hidden.
    VS.container:RegisterEvent("PLAYER_REGEN_DISABLED")
    VS.container:Hide()

    -- Apply current visual settings immediately after construction
    VS:UpdateAppearance()

    return VS.container
end

-------------------------------------------------------------------------------
-- Reposition
--
-- Anchors the popup panel relative to the broker/minimap frame that was
-- clicked.  If the icon is in the top half of the screen, the panel opens
-- below it; if in the bottom half, it opens above.
-------------------------------------------------------------------------------
function VS:Reposition()
    if not VS.container then return end
    VS.container:ClearAllPoints()

    if not VolumeSlidersMMDB.isLocked and VolumeSlidersMMDB.customX and VolumeSlidersMMDB.customY then
        VS.container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", VolumeSlidersMMDB.customX, VolumeSlidersMMDB.customY)
        return
    end

    local frame = VS.brokerFrame
    if not frame then return end

    local showBelow = select(2, frame:GetCenter()) > UIParent:GetHeight()/2

    if showBelow then
        VS.container:SetPoint("TOP", frame, "BOTTOM", 0, 0)
    else
        VS.container:SetPoint("BOTTOM", frame, "TOP", 0, 0)
    end
end
