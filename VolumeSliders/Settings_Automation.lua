local addonName, VS = ...

function VS:CreateAutomationSettingsContents(parentFrame)
    --- @type VolumeSlidersDB
    local db = VolumeSlidersMMDB
    db.automation.presets = db.automation.presets or {}

    local scrollFrame = CreateFrame("ScrollFrame", "VSAutomationSettingsScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)

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
    VS:AddTooltip(enableCheck, "Automatically adjust volume levels when entering zones designated in your presets.\n\nPresets can override any audio channel.")

    local fishingCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    fishingCheck:SetPoint("TOPLEFT", enableCheck, "TOPRIGHT", 180, 0)
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
    VS:AddTooltip(fishingCheck, "Temporarily overrides volumes while fishing so you can hear the splash.\n\nThe bobber splash plays through Sound Effects (SFX).")

    local lfgCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    lfgCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -5)
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
    VS:AddTooltip(lfgCheck, "Temporarily overrides volumes when the Dungeon Ready prompt appears.\n\nThe queue pop plays through Sound Effects (SFX).")

    local deviceVolumesCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    deviceVolumesCheck:SetPoint("TOPLEFT", fishingCheck, "BOTTOMLEFT", 0, -5)
    deviceVolumesCheck.text:SetFontObject("GameFontNormal")
    deviceVolumesCheck.text:SetText("Per-Device Volumes")
    deviceVolumesCheck:SetChecked(db.automation.enableDeviceVolumes == true)

    deviceVolumesCheck:SetScript("OnClick", function(self)
        db.automation.enableDeviceVolumes = self:GetChecked()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    VS:AddTooltip(deviceVolumesCheck, "Track and restore master volume levels independently for each hardware output device.")

    local separator1 = contentFrame:CreateTexture(nil, "ARTWORK")
    separator1:SetHeight(1)
    separator1:SetPoint("LEFT", enableCheck, "LEFT", -10, 0)
    separator1:SetPoint("TOP", lfgCheck, "BOTTOM", 0, -10)
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
        VS:AddTooltip(dropdown, tooltip)

        return dropdown, fontString
    end

    local fishingDropdown, fishingLabel = CreatePresetSelector("Fishing Profile", "fishingPresetIndex", separator1, 10, -30, "Select a preset profile to apply while fishing.")
    local lfgDropdown, lfgLabel = CreatePresetSelector("LFG Profile", "lfgPresetIndex", separator1, 190, -30, "Select a preset profile to apply when a group queue pops.")

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
    VS:AddTooltip(btnMoveUp, "Move Preset Up")

    local btnMoveDown = CreateFrame("Button", nil, contentFrame)
    btnMoveDown:SetSize(22, 22)
    btnMoveDown:SetPoint("LEFT", btnMoveUp, "RIGHT", 5, 0)
    btnMoveDown:SetNormalAtlas("glues-characterSelect-icon-arrowDown")
    btnMoveDown:SetPushedAtlas("glues-characterSelect-icon-arrowDown-pressed")
    btnMoveDown:SetDisabledAtlas("glues-characterSelect-icon-arrowDown-disabled")
    btnMoveDown:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    VS:AddTooltip(btnMoveDown, "Move Preset Down")

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
    --- This isolates live changes from the database until the user confirms them.
    --- @param preset table? The source preset (nil for a new preset).
    --- @param index number? The DB index (nil for a new preset).
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

    --- Switches the working state to a completely fresh profile.
    local function SelectNewProfile()
        currentSelectedIndex = nil
        LoadWorkingState(nil, nil)
        presetDropdown:SetDefaultText("Create New Preset")
        UpdateFormFromWorkingState()
    end

    --- Populates the active preset dropdown menu and adds a 'Create New Preset' option.
    --- @param dropdown any The dropdown frame logic
    --- @param rootDescription any The root menu description object
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

    --- Triggers a full UI refresh of the dropdown component, resolving the selected
    --- profile and pushing the selected item to the display text.
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

    --- Utility: Parses a semicolon-delimited string of zone names, removing duplicate values and whitespace.
    --- @param str string The raw zone input text.
    --- @return table An array of trimmed zone name strings.
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