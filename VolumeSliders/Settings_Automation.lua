-------------------------------------------------------------------------------
-- Settings_Automation.lua
--
-- Builds the "Automation" subcategory UI. This handles both simple master
-- toggles (Zone Triggers, Fishing, LFG) and the full Preset CRUD system.
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
local math_max   = math.max
local math_min   = math.min
local tonumber   = tonumber
local tostring   = tostring
local ipairs     = ipairs
local pairs      = pairs
local table_insert = table.insert
local table_remove = table.remove

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
    local triggerCheck = VS:CreateCheckbox(contentFrame, "VSAutomationCheckTrigger", "Enable Zone Triggers", function(checked)
        db.automation.enableTriggers = checked
        if VS.Presets and VS.Presets.RefreshEventState then
            VS.Presets:RefreshEventState()
        end
        if VS.triggerCheck then VS.triggerCheck:SetChecked(checked) end
    end, function()
        return db.automation.enableTriggers == true
    end)
    triggerCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    VS:AddTooltip(triggerCheck, "Automatically adjust volume levels when entering zones designated in your presets.")

    local fishingCheck = VS:CreateCheckbox(contentFrame, "VSAutomationCheckFishing", "Enable Fishing Boost", function(checked)
        db.automation.enableFishingVolume = checked
        if VS.Fishing and VS.Fishing.Initialize then
            VS.Fishing:Initialize()
        end
        if VS.fishingCheck then VS.fishingCheck:SetChecked(checked) end
    end, function()
        return db.automation.enableFishingVolume == true
    end)
    fishingCheck:SetPoint("TOPLEFT", triggerCheck, "BOTTOMLEFT", 0, -8)
    VS:AddTooltip(fishingCheck, "Temporarily overrides volumes while fishing so you can hear the splash.")

    local lfgCheck = VS:CreateCheckbox(contentFrame, "VSAutomationCheckLFG", "Enable LFG Pop Boost", function(checked)
        db.automation.enableLfgVolume = checked
        if VS.LFGQueue and VS.LFGQueue.Initialize then
            VS.LFGQueue:Initialize()
        end
        if VS.lfgCheck then VS.lfgCheck:SetChecked(checked) end
    end, function()
        return db.automation.enableLfgVolume == true
    end)
    lfgCheck:SetPoint("TOPLEFT", fishingCheck, "BOTTOMLEFT", 0, -8)
    VS:AddTooltip(lfgCheck, "Temporarily overrides volumes when the Dungeon Ready prompt appears.")

    VS.RefreshTriggerSettings = function()
        triggerCheck:SetChecked(db.automation.enableTriggers == true)
        fishingCheck:SetChecked(db.automation.enableFishingVolume == true)
        lfgCheck:SetChecked(db.automation.enableLfgVolume == true)
    end

    ---------------------------------------------------------------------------
    -- Preset System
    ---------------------------------------------------------------------------
    local presetTitle = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    presetTitle:SetPoint("TOPLEFT", lfgCheck, "BOTTOMLEFT", 0, -30)
    presetTitle:SetText("Preset Profiles")

    local presetDesc = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    presetDesc:SetPoint("TOPLEFT", presetTitle, "BOTTOMLEFT", 0, -5)
    presetDesc:SetWidth(560)
    presetDesc:SetText("Create profiles with specific volume levels and math modes. Profiles can be assigned to zones or applied manually via the minimap button popout.")
    presetDesc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Profile Selection Dropdown
    ---------------------------------------------------------------------------
    local presetDropdown = CreateFrame("DropdownButton", "VSAutomationPresetDropdown", contentFrame)
    presetDropdown:SetPoint("TOPLEFT", presetDesc, "BOTTOMLEFT", 4, -20)
    presetDropdown:SetSize(180, 26)

    local ddBg = presetDropdown:CreateTexture(nil, "BACKGROUND")
    ddBg:SetAtlas("common-dropdown-c-button")
    ddBg:SetPoint("TOPLEFT", -7, 7)
    ddBg:SetPoint("BOTTOMRIGHT", 7, -7)
    presetDropdown.Background = ddBg

    local arrow = presetDropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetAtlas("common-dropdown-c-button-hover-arrow", true)
    arrow:SetPoint("BOTTOM", 0, -5)
    arrow:Hide()
    presetDropdown.Arrow = arrow

    local ddText = presetDropdown:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ddText:SetPoint("CENTER", 0, 0)
    ddText:SetWidth(160)
    ddText:SetJustifyH("CENTER")
    presetDropdown.Text = ddText

    presetDropdown.SetText = function(self, text)
        self.Text:SetText(text)
    end

    local currentSelectedIndex = nil

    ---------------------------------------------------------------------------
    -- Form Elements (Sliders & Name)
    ---------------------------------------------------------------------------
    local nameEditBox = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
    nameEditBox:SetSize(180, 26)
    nameEditBox:SetPoint("LEFT", presetDropdown, "RIGHT", 40, 0)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetMaxLetters(32)

    local nameLabel = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameLabel:SetPoint("BOTTOMLEFT", nameEditBox, "TOPLEFT", 0, 4)
    nameLabel:SetText("Internal Name")

    -- Working state table: acts as a buffer between the UI and the DB.
    -- Changes are only written to db.automation.presets[index] when the user 
    -- clicks "Save".
    VS.PresetWorkingState = {
        name = "",
        volumes = {},
        ignored = {},
        modes = {},
        mutes = {},
        showInDropdown = true,
        index = nil
    }

    local sliders = {}
    local channels = VS.DEFAULT_CVAR_ORDER

    local startX = 40
    local startY = -480
    local columnWidth = 85

    for i, channel in ipairs(channels) do
        local label = channel:gsub("Sound_", ""):gsub("Voice_", ""):gsub("Volume", ""):gsub("Chat", ""):gsub("SFX", "Effects")
        if label == "EncounterWarnings" then label = "Warn" end
        if label == "Gameplay" then label = "Game" end
        if label == "Mic" then label = "M Mic" end
        if label == "MicSensitivity" then label = "M Sens" end

        local slider = VS:CreateTriggerSlider(contentFrame, "VSAutomationSlider" .. channel, label, channel, VS.PresetWorkingState, 0, 1, 0.01)
        slider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", startX + (i-1) * columnWidth, startY)
        sliders[channel] = slider
    end

    local showCheck = VS:CreateCheckbox(contentFrame, "VSAutomationCheckShow", "Show in Popout Dropdown", function(checked)
        VS.PresetWorkingState.showInDropdown = checked
    end, function()
        return VS.PresetWorkingState.showInDropdown == true
    end)
    showCheck:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 20, -780)

    ---------------------------------------------------------------------------
    -- State Management & Lifecycle
    ---------------------------------------------------------------------------
    local function UpdateFormFromWorkingState()
        nameEditBox:SetText(VS.PresetWorkingState.name or "")
        showCheck:SetChecked(VS.PresetWorkingState.showInDropdown ~= false)
        for _, slider in pairs(sliders) do
            slider:RefreshValue()
        end
    end

    local function LoadWorkingState(preset, index)
        if preset then
            VS.PresetWorkingState.name = preset.name
            VS.PresetWorkingState.showInDropdown = (preset.showInDropdown ~= false)
            VS.PresetWorkingState.index = index
            for _, channel in ipairs(channels) do
                VS.PresetWorkingState.volumes[channel] = preset.volumes[channel]
                VS.PresetWorkingState.ignored[channel] = preset.ignored and preset.ignored[channel] or nil
                VS.PresetWorkingState.modes[channel] = preset.modes and preset.modes[channel] or "absolute"
                VS.PresetWorkingState.mutes[channel] = preset.mutes and preset.mutes[channel] or nil
            end
        else
            VS.PresetWorkingState.name = "New Preset"
            VS.PresetWorkingState.showInDropdown = true
            VS.PresetWorkingState.index = nil
            for _, channel in ipairs(channels) do
                VS.PresetWorkingState.volumes[channel] = tonumber(GetCVar(channel)) or 1
                VS.PresetWorkingState.ignored[channel] = nil
                VS.PresetWorkingState.modes[channel] = "absolute"
                VS.PresetWorkingState.mutes[channel] = nil
            end
        end
    end

    local function RefreshDropdown()
        presetDropdown:GenerateMenu()
    end

    VS.RefreshAutomationProfiles = function()
        RefreshDropdown()
        if currentSelectedIndex then
            local preset = db.automation.presets[currentSelectedIndex]
            if preset then
                presetDropdown:SetText(preset.name)
            else
                currentSelectedIndex = nil
                presetDropdown:SetText("Select Profile...")
            end
        else
            presetDropdown:SetText("Select Profile...")
        end
    end

    ---------------------------------------------------------------------------
    -- ShiftAutomationIndexes
    --
    -- When a preset is deleted or moved, all references to its index in the
    -- mouse actions or zones table must be shifted or cleared.
    ---------------------------------------------------------------------------
    local function ShiftAutomationIndexes(oldIndex, newIndex)
        local shiftType = (newIndex == nil) and "DELETE" or "MOVE"

        -- 1. Minimap Mouse Actions
        if db.minimap and db.minimap.mouseActions then
            for _, action in ipairs(db.minimap.mouseActions) do
                if action.effect == "TOGGLE_PRESET" and action.stringTarget then
                    local target = tonumber(action.stringTarget)
                    if target then
                        if shiftType == "DELETE" then
                            if target == oldIndex then
                                action.stringTarget = nil
                                action.effect = nil -- Clear the action if its target is gone
                            elseif target > oldIndex then
                                action.stringTarget = tostring(target - 1)
                            end
                        end
                    end
                end
            end
        end

        -- 2. Trigger Zones, Fishing, LFG
        if db.automation then
            if shiftType == "DELETE" then
                if db.automation.fishingPresetIndex == oldIndex then
                    db.automation.fishingPresetIndex = nil
                elseif db.automation.fishingPresetIndex and db.automation.fishingPresetIndex > oldIndex then
                    db.automation.fishingPresetIndex = db.automation.fishingPresetIndex - 1
                end

                if db.automation.lfgPresetIndex == oldIndex then
                    db.automation.lfgPresetIndex = nil
                elseif db.automation.lfgPresetIndex and db.automation.lfgPresetIndex > oldIndex then
                    db.automation.lfgPresetIndex = db.automation.lfgPresetIndex - 1
                end

                if db.automation.triggers then
                    for zone, presetIndex in pairs(db.automation.triggers) do
                        if presetIndex == oldIndex then
                            db.automation.triggers[zone] = nil
                        elseif presetIndex > oldIndex then
                            db.automation.triggers[zone] = presetIndex - 1
                        end
                    end
                end
            end
        end

        -- 3. Session manual states
        if VS.session then
            local active = VS.session.activeManualPresets
            if active then
                if shiftType == "DELETE" then
                    active[oldIndex] = nil
                    -- Shift up all subsequent indexes
                    for i = oldIndex + 1, #db.automation.presets + 1 do
                        active[i-1] = active[i]
                        active[i] = nil
                    end
                end
            end
        end
    end

    presetDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateTitle("Choose Profile")
        
        rootDescription:CreateButton(" + Create New Profile", function()
            currentSelectedIndex = nil
            LoadWorkingState(nil, nil)
            UpdateFormFromWorkingState()
            presetDropdown:SetText("New Preset")
        end)

        if db.automation.presets and #db.automation.presets > 0 then
            rootDescription:CreateDivider()
            for i, preset in ipairs(db.automation.presets) do
                rootDescription:CreateButton((tostring(i)..": "..(preset.name or "Unnamed")), function()
                    currentSelectedIndex = i
                    LoadWorkingState(preset, i)
                    UpdateFormFromWorkingState()
                    presetDropdown:SetText(preset.name)
                end)
            end
        end
    end)

    ---------------------------------------------------------------------------
    -- Buttons (Save, Copy, Delete, Move)
    ---------------------------------------------------------------------------
    local btnSave = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnSave:SetSize(80, 22)
    btnSave:SetPoint("TOPLEFT", showCheck, "BOTTOMLEFT", 0, -20)
    btnSave:SetText("Save")

    local btnCopy = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnCopy:SetSize(80, 22)
    btnCopy:SetPoint("LEFT", btnSave, "RIGHT", 5, 0)
    btnCopy:SetText("Copy")

    local btnDelete = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnDelete:SetSize(80, 22)
    btnDelete:SetPoint("LEFT", btnCopy, "RIGHT", 5, 0)
    btnDelete:SetText("Delete")

    local btnMoveUp = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnMoveUp:SetSize(40, 22)
    btnMoveUp:SetPoint("LEFT", btnDelete, "RIGHT", 20, 0)
    btnMoveUp:SetText("ʌ")

    local btnMoveDown = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    btnMoveDown:SetSize(40, 22)
    btnMoveDown:SetPoint("LEFT", btnMoveUp, "RIGHT", 5, 0)
    btnMoveDown:SetText("v")

    nameEditBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            VS.PresetWorkingState.name = self:GetText()
            btnSave:Enable()
        end
    end)

    btnSave:SetScript("OnClick", function()
        -- No preset selected, hide the editor and return early.
        if VS.PresetWorkingState.name == "" then return end

        local newObj = {
            name = VS.PresetWorkingState.name,
            showInDropdown = VS.PresetWorkingState.showInDropdown,
            volumes = {},
            ignored = {},
            modes = {},
            mutes = {}
        }
        for _, channel in ipairs(channels) do
            newObj.volumes[channel] = VS.PresetWorkingState.volumes[channel] or 1
            if VS.PresetWorkingState.ignored[channel] then
                newObj.ignored[channel] = true
            end
            newObj.modes[channel] = VS.PresetWorkingState.modes[channel] or "absolute"
            if VS.PresetWorkingState.mutes[channel] then
                newObj.mutes[channel] = true
            end
        end

        local desiredIndex = currentSelectedIndex or (#db.automation.presets + 1)
        
        -- If updating an existing preset, we need to handle reference shifting
        if currentSelectedIndex then
            ShiftAutomationIndexes(currentSelectedIndex, desiredIndex)
            table_remove(db.automation.presets, currentSelectedIndex)
        end

        -- Insert into array at the new desired position and shift boundaries
        desiredIndex = math_max(1, math_min(desiredIndex, #db.automation.presets + 1))
        table_insert(db.automation.presets, desiredIndex, newObj)
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
                table_remove(db.automation.presets, currentSelectedIndex)
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
        preferredIndex = 3
    }

    btnDelete:SetScript("OnClick", function()
        if currentSelectedIndex then
            StaticPopup_Show("VolumeSlidersDeletePresetConfirm")
        end
    end)

    local function SwapPresets(idxA, idxB)
        if not db.automation.presets[idxA] or not db.automation.presets[idxB] then return end

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
