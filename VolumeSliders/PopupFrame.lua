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

    local db = VolumeSlidersMMDB

    -- Create the popup using the modern settings frame template.
    VS.container = CreateFrame("Frame", "VolumeSlidersFrame", UIParent, "SettingsFrameTemplate")
    local initW = db.windowWidth or VS.DEFAULT_WINDOW_WIDTH
    local initH = db.windowHeight or VS.DEFAULT_WINDOW_HEIGHT
    VS.container:SetSize(initW, initH)
    VS.container:SetPoint("CENTER")
    VS.container:SetFrameStrata("DIALOG")
    VS.container:SetFrameLevel(100)
    VS.container:SetClampedToScreen(true)
    VS.container:EnableMouse(true)

    -- Enable resizing
    VS.container:SetResizable(true)

    -- Set the title bar text via the NineSlice's built-in Text font string.
    if VS.container.NineSlice and VS.container.NineSlice.Text then
        VS.container.NineSlice.Text:SetText("Volume Sliders")
        VS.container.NineSlice.Text:ClearAllPoints()
        VS.container.NineSlice.Text:SetPoint("TOPLEFT", VS.container, "TOPLEFT", 12, -8)
    else
        -- Fallback: create our own title if the template layout differs.
        local titleText = VS.container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        titleText:SetText("Volume Sliders")
        titleText:SetPoint("TOPLEFT", VS.container, "TOPLEFT", 12, -8)
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
    local settingsBtn = CreateFrame("Button", "VolumeSlidersFrameSettingsButton", VS.container)
    settingsBtn:SetSize(17, 17)
    settingsBtn:SetNormalAtlas("mechagon-projects")
    settingsBtn:SetPushedAtlas("mechagon-projects")
    settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    settingsBtn:SetPoint("RIGHT", lockBtn, "LEFT", -4, 0)

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

    -- Resize Edges and Corners
    local function CreateResizeFrame(name, parent, width, height, anchorPoint, anchorRel, x, y, sizingPoint, gradients)
        local f = CreateFrame("Frame", name, parent)
        if width then f:SetWidth(width) end
        if height then f:SetHeight(height) end
        f:SetPoint(anchorPoint, parent, anchorRel, x, y)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function()
            if not VolumeSlidersMMDB.isLocked then
                parent:StartSizing(sizingPoint)
            end
        end)
        f:SetScript("OnDragStop", function()
            parent:StopMovingOrSizing()
            if not VolumeSlidersMMDB.isLocked then
                VolumeSlidersMMDB.windowWidth = parent:GetWidth()
                VolumeSlidersMMDB.windowHeight = parent:GetHeight()
            end
        end)

        -- Generate multi-layered golden highlights to form soft edge/corner glows
        f.highlightTextures = {}
        if gradients then
            for _, grad in ipairs(gradients) do
                local highlight = f:CreateTexture(nil, "OVERLAY")
                highlight:SetAllPoints(f)
                highlight:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                highlight:SetBlendMode("ADD")

                if grad.orientation then
                    highlight:SetGradient(grad.orientation, CreateColor(1, 0.82, 0, grad.minAlpha), CreateColor(1, 0.82, 0, grad.maxAlpha))
                else
                    highlight:SetColorTexture(1, 0.82, 0, grad.minAlpha)
                end

                highlight:Hide()
                table.insert(f.highlightTextures, highlight)
            end
        end

        f:SetScript("OnEnter", function()
            for _, tex in ipairs(f.highlightTextures) do tex:Show() end
        end)
        f:SetScript("OnLeave", function()
            for _, tex in ipairs(f.highlightTextures) do tex:Hide() end
        end)
        return f
    end

    -- Edge thickness and corner size
    local eT = 8
    local cS = 18
    local lInset = 4 -- SettingsFrameTemplate has an asymmetrical left shadow/inset

    -- Create edges (omitting top edge/corners per user request)
    -- Right Edge: gradient fades out to the left (0 alpha left, 0.4 alpha right)
    local rEdge = CreateResizeFrame("VolumeSlidersResizeRight", VS.container, eT, nil, "RIGHT", "RIGHT", 0, 0, "RIGHT", {
        {orientation="HORIZONTAL", minAlpha=0, maxAlpha=0.4}
    })
    rEdge:SetPoint("TOP", VS.container, "TOP", 0, -40) -- Avoid title bar
    rEdge:SetPoint("BOTTOM", VS.container, "BOTTOM", 0, cS)

    -- Left Edge: gradient fades out to the right (0.4 alpha left, 0 alpha right)
    local lEdge = CreateResizeFrame("VolumeSlidersResizeLeft", VS.container, eT, nil, "LEFT", "LEFT", lInset, 0, "LEFT", {
        {orientation="HORIZONTAL", minAlpha=0.4, maxAlpha=0}
    })
    lEdge:SetPoint("TOP", VS.container, "TOP", lInset, -40) -- Avoid title bar
    lEdge:SetPoint("BOTTOM", VS.container, "BOTTOM", lInset, cS)

    -- Bottom Edge: gradient fades out upwards (0.4 alpha bottom, 0 alpha top)
    local bEdge = CreateResizeFrame("VolumeSlidersResizeBottom", VS.container, nil, eT, "BOTTOM", "BOTTOM", 0, 0, "BOTTOM", {
        {orientation="VERTICAL", minAlpha=0.4, maxAlpha=0}
    })
    bEdge:SetPoint("LEFT", VS.container, "LEFT", cS + lInset, 0)
    bEdge:SetPoint("RIGHT", VS.container, "RIGHT", -cS, 0)

    -- Create corners: Cross-hatch dual gradients to synthesize a 2D corner blur
    local brCorner = CreateResizeFrame("VolumeSlidersResizeBottomRight", VS.container, cS, cS, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, "BOTTOMRIGHT", {
        {orientation="HORIZONTAL", minAlpha=0, maxAlpha=0.4},
        {orientation="VERTICAL", minAlpha=0.4, maxAlpha=0}
    })
    local blCorner = CreateResizeFrame("VolumeSlidersResizeBottomLeft", VS.container, cS, cS, "BOTTOMLEFT", "BOTTOMLEFT", lInset, 0, "BOTTOMLEFT", {
        {orientation="HORIZONTAL", minAlpha=0.4, maxAlpha=0},
        {orientation="VERTICAL", minAlpha=0.4, maxAlpha=0}
    })

    -- Replace the template's default light background with a darker one
    -- for better contrast against the volume controls.
    if VS.container.Bg then VS.container.Bg:Hide() end
    VS.windowBg = VS.container:CreateTexture(nil, "BACKGROUND", nil, -1)
    VS.windowBg:SetPoint("TOPLEFT", VS.container, "TOPLEFT", VS.TEMPLATE_CONTENT_OFFSET_LEFT, -VS.TEMPLATE_CONTENT_OFFSET_TOP)
    VS.windowBg:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", -VS.TEMPLATE_CONTENT_OFFSET_RIGHT, VS.TEMPLATE_CONTENT_OFFSET_BOTTOM)
    VS.windowBg:SetColorTexture(db.bgColorR or 0.05, db.bgColorG or 0.05, db.bgColorB or 0.05, db.bgColorA or 0.95)

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
            -- Persistent window mode: don't close on outside click.
            if VolumeSlidersMMDB.persistentWindow then return end

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

        if VolumeSlidersMMDB.layoutDirty then
            VS:UpdateAppearance()
        end

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
    VS.instructionText = VS.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    VS.instructionText:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", 0, -VS.CONTENT_PADDING_TOP)
    VS.instructionText:SetPoint("TOPRIGHT", VS.contentFrame, "TOPRIGHT", 0, -VS.CONTENT_PADDING_TOP)
    VS.instructionText:SetText("Right-click on the icon to toggle master mute.")
    VS.instructionText:SetTextColor(1, 1, 1)
    VS.instructionText:SetWordWrap(true)
    VS.instructionText:SetJustifyH("CENTER")

    ---------------------------------------------------------------------------
    -- Presets Quick-Apply Dropdown
    ---------------------------------------------------------------------------
    VS.presetDropdown = CreateFrame("DropdownButton", "VolumeSlidersPresetDropdown", VS.contentFrame)
    VS.presetDropdown:SetPoint("TOP", VS.instructionText, "BOTTOM", 0, -10)
    VS.presetDropdown:SetSize(140, 26)

    local pDropdown = VS.presetDropdown

    -- Background texture
    local pDdBg = pDropdown:CreateTexture(nil, "BACKGROUND")
    pDdBg:SetAtlas("common-dropdown-c-button")
    pDdBg:SetPoint("TOPLEFT", -7, 7)
    pDdBg:SetPoint("BOTTOMRIGHT", 7, -7)
    pDropdown.Background = pDdBg

    -- Hover arrow indicator
    local pArrow = pDropdown:CreateTexture(nil, "OVERLAY")
    pArrow:SetAtlas("common-dropdown-c-button-hover-arrow", true)
    pArrow:SetPoint("BOTTOM", 0, -5)
    pArrow:Hide()
    pDropdown.Arrow = pArrow

    -- Display Text
    local pText = pDropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pText:SetPoint("CENTER", 0, 0)
    pText:SetWidth(120)
    pText:SetJustifyH("CENTER")
    pText:SetWordWrap(false)
    pDropdown.Text = pText

    -- Provide SetText API for the rootDescription generator menu to use
    pDropdown.SetText = function(self, text)
        self.Text:SetText(text)
    end

    -- Event handlers for hover states
    pDropdown:SetScript("OnEnter", function(self)
        if not self.GenerateMenu then return end
        self.Background:SetAtlas("common-dropdown-c-button-hover-1")
        self.Arrow:Show()
    end)

    pDropdown:SetScript("OnLeave", function(self)
        if not self.GenerateMenu then return end
        self.Arrow:Hide()
        -- Reset background to normal if the menu isn't open
        if self.list and self.list:IsShown() then
            self.Background:SetAtlas("common-dropdown-c-button-pressed-1")
        else
            self.Background:SetAtlas("common-dropdown-c-button")
        end
    end)

    -- Hook into the frame's OnMouseDown/Up events for the pressed state
    pDropdown:HookScript("OnMouseDown", function(self, button)
        if not self.GenerateMenu then return end
        self.Background:SetAtlas("common-dropdown-c-button-pressed-1")
    end)

    pDropdown:HookScript("OnMouseUp", function(self, button)
        if not self.GenerateMenu then return end
        self.Background:SetAtlas(self:IsMouseOver() and "common-dropdown-c-button-hover-1" or "common-dropdown-c-button")
    end)

    local function SelectPreset(preset)
        if VS.Presets and VS.Presets.ApplyPreset then
            VS.Presets:ApplyPreset(preset)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            -- Optionally update slider visuals to reflect new volumes
            if VS.sliders then
                for _, slider in pairs(VS.sliders) do
                    if slider.RefreshValue then slider:RefreshValue() end
                end
            end
        end
    end

    local function GeneratePresetMenu(dropdown, rootDescription)
        rootDescription:CreateTitle("Quick Apply Preset")
        local db = VolumeSlidersMMDB
        if db.presets and #db.presets > 0 then
            local hasPresets = false
            for _, preset in ipairs(db.presets) do
                if preset.showInDropdown ~= false then -- default true
                    hasPresets = true
                    rootDescription:CreateButton(preset.name, function()
                        SelectPreset(preset)
                        dropdown:SetText("Presets")
                    end)
                end
            end
            if not hasPresets then
                rootDescription:CreateTitle("No presets set to show")
            end
        else
            rootDescription:CreateTitle("No presets available")
        end
    end

    VS.presetDropdown:SetupMenu(GeneratePresetMenu)
    VS.presetDropdown:SetText("Presets")

    -- Expose refresh function to be called after settings are updated
    VS.RefreshPopupDropdown = function()
        if VS.presetDropdown then
            VS.presetDropdown:GenerateMenu()
            VS.presetDropdown:SetText("Presets")
        end
    end

    ---------------------------------------------------------------------------
    -- Volume Sliders
    --
    -- Sliders are laid out in a horizontal row.  Each column is
    -- SLIDER_COLUMN_WIDTH wide with a dynamic spacing between them.
    ---------------------------------------------------------------------------
    local startX = VS.CONTENT_PADDING_X
    local startY = -(VS.CONTENT_PADDING_TOP + 95)
    local spacing = 10 -- Initial spacing; dynamically overridden by UpdateAppearance()

    -- Master Volume
    local masterSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderMaster", "Master", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01, "Master Volume")
    masterSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MasterVolume"] = masterSlider

    -- Effects Volume
    local sfxSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderSFX", "Effects", "Sound_SFXVolume", "Sound_EnableSFX", 0, 1, 0.01, "Sound Effects Volume")
    sfxSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_SFXVolume"] = sfxSlider

    -- Music Volume
    local musicSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderMusic", "Music", "Sound_MusicVolume", "Sound_EnableMusic", 0, 1, 0.01, "Music Volume")
    musicSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 2 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MusicVolume"] = musicSlider

    -- Ambience Volume
    local ambienceSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderAmbience", "Ambience", "Sound_AmbienceVolume", "Sound_EnableAmbience", 0, 1, 0.01, "Ambience Volume")
    ambienceSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 3 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_AmbienceVolume"] = ambienceSlider

    -- Dialog Volume
    local dialogSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderDialogue", "Dialog", "Sound_DialogVolume", "Sound_EnableDialog", 0, 1, 0.01, "Dialog Volume")
    dialogSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 4 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_DialogVolume"] = dialogSlider

    -- Warnings Volume
    local warningsSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderWarnings", "Warnings", "Sound_EncounterWarningsVolume", "Sound_EnableEncounterWarningsSounds", 0, 1, 0.01, "Encounter Warnings Volume")
    warningsSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 5 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_EncounterWarningsVolume"] = warningsSlider

    -- Gameplay Volume
    local gameplaySlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderGameplay", "Gameplay", "Sound_GameplaySFX", "Sound_EnableGameplaySFX", 0, 1, 0.01, "Gameplay Sound Effects Volume")
    gameplaySlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 6 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_GameplaySFX"] = gameplaySlider

    -- Pings Volume
    local pingsSlider = VS:CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderPings", "Pings", "Sound_PingVolume", "Sound_EnablePingSounds", 0, 1, 0.01, "Ping System Volume")
    pingsSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 7 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_PingVolume"] = pingsSlider

    -- Voice Chat Volume
    local voiceChatSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderVoiceChat", "Voice", C_VoiceChat.GetOutputVolume, C_VoiceChat.SetOutputVolume, false, "Voice Chat Output Volume", "Voice_ChatVolume")
    voiceChatSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 8 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_ChatVolume"] = voiceChatSlider

    -- Voice Chat Ducking (Inverted: Game value is ducking 0-1 scale. UI value is 'ducking strength%')
    local duckingSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderVoiceDucking", "Voice BG", function() return C_VoiceChat.GetMasterVolumeScale() * 100 end, function(val) C_VoiceChat.SetMasterVolumeScale(val / 100) end, true, "Voice Chat Ducking\nLow = Game sound mutes entirely when players speak.\nHigh = Game sound ignores speaking players.", nil)
    duckingSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 9 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_ChatDucking"] = duckingSlider

    -- Microphone Volume
    local micVolSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderMicVolume", "Mic Vol", C_VoiceChat.GetInputVolume, C_VoiceChat.SetInputVolume, false, "Microphone Input Volume", "Voice_MicVolume")
    micVolSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 10 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_MicVolume"] = micVolSlider

    -- Microphone Sensitivity (Inverted)
    local micSensSlider = VS:CreateVoiceSlider(VS.contentFrame, "VolumeSlidersSliderMicSensitivity", "Mic Sens", C_VoiceChat.GetVADSensitivity, C_VoiceChat.SetVADSensitivity, true, "Microphone Activation Sensitivity", nil)
    micSensSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (VS.SLIDER_COLUMN_WIDTH + spacing) * 11 + (VS.SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Voice_MicSensitivity"] = micSensSlider

    ---------------------------------------------------------------------------
    -- Bottom Row Controls
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

    VS.triggerCheck = VS:CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckTrigger", "Zone Triggers", function(checked)
        VolumeSlidersMMDB.enableTriggers = checked
        if VS.Presets and VS.Presets.RefreshEventState then
            VS.Presets:RefreshEventState()
        end
    end, function()
        return VolumeSlidersMMDB.enableTriggers == true
    end)
    AddTooltip(VS.triggerCheck, "Automatically adjust volume levels when entering zones designated in your presets.")

    VS.fishingCheck = VS:CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckFishing", "Fishing Boost", function(checked)
        VolumeSlidersMMDB.enableFishingVolume = checked
        if VS.Fishing and VS.Fishing.Initialize then
            VS.Fishing:Initialize()
        end
    end, function()
        return VolumeSlidersMMDB.enableFishingVolume == true
    end)
    AddTooltip(VS.fishingCheck, "Temporarily overrides volumes while fishing so you can hear the splash.")

    VS.lfgCheck = VS:CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckLFG", "LFG Pop Boost", function(checked)
        VolumeSlidersMMDB.enableLfgVolume = checked
        if VS.LFGQueue and VS.LFGQueue.Initialize then
            VS.LFGQueue:Initialize()
        end
    end, function()
        return VolumeSlidersMMDB.enableLfgVolume == true
    end)
    AddTooltip(VS.lfgCheck, "Temporarily overrides volumes when the Dungeon Ready prompt appears.")

    -- "Sound at Character" checkbox â€” toggles whether the listener position
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

    AddTooltip(VS.characterCheckbox, "Toggle whether 3D sound is positioned at your character or at the camera.")

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
    AddTooltip(VS.backgroundCheckbox, "Continue playing audio even when the game is minimized or not the active window.")

    ---------------------------------------------------------------------------
    -- Sound Output Device Dropdown
    --
    -- Custom dropdown mimicking the WowStyle2DropdownTemplate visual style.
    -- Uses Blizzard atlas assets for all background/hover/pressed states:
    --   Background: common-dropdown-c-button, -hover-1, -pressed-1, -open, -disabled
    --   Arrow:      common-dropdown-c-button-hover-arrow (shown on hover only)
    --   List BG:    common-dropdown-c-bg
    ---------------------------------------------------------------------------

    -- Sound Output Device Dropdown (label context is now in tooltip only)
    -- Dropdown button
    VS.outputDropdown = CreateFrame("Button", "VolumeSlidersOutputDropdown", VS.contentFrame)
    VS.outputDropdown:SetSize(140, 26)

    local dropdown = VS.outputDropdown

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

    dropdown:SetScript("OnEnter", function(self)
        UpdateDropdownState(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sound Output Device\n\nSelect the audio playback device.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    dropdown:SetScript("OnLeave", function(self)
        UpdateDropdownState(false)
        GameTooltip:Hide()
    end)

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
                    highlight:SetAllPoints()
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
                                 masterSlider.valueText:SetText(math_floor(targetVol * 100 + 0.5) .. "%")
                             end
                             masterSlider.isRefreshing = false
                        end
                        if VS.VolumeSlidersObject then
                            VS.VolumeSlidersObject.text = (math_floor(targetVol * 100 + 0.5)) .. "%"
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

                            -- Don't fully clean up yet â€” keep the visual disable
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
    -- Voice Chat Mode Toggle (label context is now in tooltip only)
    ---------------------------------------------------------------------------

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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Voice Chat Mode\n\nSwitch between Push to Talk and Open Mic.", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    VS.voiceModeBtn:SetScript("OnLeave", function(self)
        vmBg:SetAtlas("common-dropdown-c-button", true)
        GameTooltip:Hide()
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

    ---------------------------------------------------------------------------
    -- Resize Handles
    --
    -- 8 invisible frames along the edges and corners drive StartSizing().
    -- The handles save window dimensions to the database on drag stop.
    ---------------------------------------------------------------------------
    local function CreateResizeHandle(point, x1, y1, x2, y2, w, h, cursor)
        local handle = CreateFrame("Frame", nil, VS.container)
        handle:SetPoint("TOPLEFT", VS.container, "TOPLEFT", x1, y1)
        handle:SetPoint("BOTTOMRIGHT", VS.container, "TOPLEFT", x2, y2)
        if w then handle:SetSize(w, h) end
        handle:EnableMouse(true)
        handle:SetScript("OnMouseDown", function()
            VS.container:StartSizing(point)
        end)
        handle:SetScript("OnMouseUp", function()
            VS.container:StopMovingOrSizing()
            local dbL = VolumeSlidersMMDB
            dbL.windowWidth = VS.container:GetWidth()
            dbL.windowHeight = VS.container:GetHeight()
        end)
        return handle
    end

    local t = VS.RESIZE_HANDLE_THICKNESS
    local cw = VS.container:GetWidth()
    local ch = VS.container:GetHeight()

    -- Edge handles â€” anchored using two-point anchoring to stretch along edges
    -- LEFT edge
    local leftHandle = CreateFrame("Frame", nil, VS.container)
    leftHandle:SetPoint("TOPLEFT", VS.container, "TOPLEFT", 0, -t)
    leftHandle:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMLEFT", t, t)
    leftHandle:EnableMouse(true)
    leftHandle:SetScript("OnMouseDown", function() VS.container:StartSizing("LEFT") end)
    leftHandle:SetScript("OnMouseUp", function()
        VS.container:StopMovingOrSizing()
        VolumeSlidersMMDB.windowWidth = VS.container:GetWidth()
        VolumeSlidersMMDB.windowHeight = VS.container:GetHeight()
    end)

    -- RIGHT edge
    local rightHandle = CreateFrame("Frame", nil, VS.container)
    rightHandle:SetPoint("TOPLEFT", VS.container, "TOPRIGHT", -t, -t)
    rightHandle:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", 0, t)
    rightHandle:EnableMouse(true)
    rightHandle:SetScript("OnMouseDown", function() VS.container:StartSizing("RIGHT") end)
    rightHandle:SetScript("OnMouseUp", function()
        VS.container:StopMovingOrSizing()
        VolumeSlidersMMDB.windowWidth = VS.container:GetWidth()
        VolumeSlidersMMDB.windowHeight = VS.container:GetHeight()
    end)

    -- TOP edge
    local topHandle = CreateFrame("Frame", nil, VS.container)
    topHandle:SetPoint("TOPLEFT", VS.container, "TOPLEFT", t, 0)
    topHandle:SetPoint("BOTTOMRIGHT", VS.container, "TOPRIGHT", -t, -t)
    topHandle:EnableMouse(true)
    topHandle:SetScript("OnMouseDown", function() VS.container:StartSizing("TOP") end)
    topHandle:SetScript("OnMouseUp", function()
        VS.container:StopMovingOrSizing()
        VolumeSlidersMMDB.windowWidth = VS.container:GetWidth()
        VolumeSlidersMMDB.windowHeight = VS.container:GetHeight()
    end)

    -- BOTTOM edge
    local bottomHandle = CreateFrame("Frame", nil, VS.container)
    bottomHandle:SetPoint("TOPLEFT", VS.container, "BOTTOMLEFT", t, t)
    bottomHandle:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", -t, 0)
    bottomHandle:EnableMouse(true)
    bottomHandle:SetScript("OnMouseDown", function() VS.container:StartSizing("BOTTOM") end)
    bottomHandle:SetScript("OnMouseUp", function()
        VS.container:StopMovingOrSizing()
        VolumeSlidersMMDB.windowWidth = VS.container:GetWidth()
        VolumeSlidersMMDB.windowHeight = VS.container:GetHeight()
    end)

    -- Corner handles â€” small fixed-size squares at each corner
    local corners = {
        { point = "TOPLEFT",     a1 = "TOPLEFT",     x = 0, y = 0 },
        { point = "TOPRIGHT",    a1 = "TOPRIGHT",    x = -t*2, y = 0 },
        { point = "BOTTOMLEFT",  a1 = "BOTTOMLEFT",  x = 0, y = t*2 },
        { point = "BOTTOMRIGHT", a1 = "BOTTOMRIGHT", x = -t*2, y = t*2 },
    }
    for _, c in ipairs(corners) do
        local corner = CreateFrame("Frame", nil, VS.container)
        corner:SetSize(t * 2, t * 2)
        corner:SetPoint(c.a1, VS.container, c.a1, c.x, c.y)
        corner:EnableMouse(true)
        corner:SetScript("OnMouseDown", function() VS.container:StartSizing(c.point) end)
        corner:SetScript("OnMouseUp", function()
            VS.container:StopMovingOrSizing()
            VolumeSlidersMMDB.windowWidth = VS.container:GetWidth()
            VolumeSlidersMMDB.windowHeight = VS.container:GetHeight()
        end)
    end

    ---------------------------------------------------------------------------
    -- OnSizeChanged: Reflow layout dynamically during resize
    ---------------------------------------------------------------------------
    VS.container:SetScript("OnSizeChanged", function(self, width, height)
        VS:FlagLayoutDirty()
    end)

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
