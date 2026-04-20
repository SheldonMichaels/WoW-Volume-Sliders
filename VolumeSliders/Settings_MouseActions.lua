-------------------------------------------------------------------------------
-- Settings_MouseActions.lua
--
-- Builds the "Mouse Actions" subcategory UI.
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
local table_insert = table.insert
local table_concat = table.concat
local table_remove = table.remove
local string_find    = string.find
local string_reverse = string.reverse
local string_match   = string.match
local string_sub     = string.sub

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
    bg:SetColorTexture(0, 0, 0, 1)

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
        if string_find(triggerStr, "Shift") then table_insert(mods, "Shift") end
        if string_find(triggerStr, "Ctrl") then table_insert(mods, "Ctrl") end
        if string_find(triggerStr, "Alt") then table_insert(mods, "Alt") end

        local modStr = #mods > 0 and table_concat(mods, "+") or "None"

        local lastPlus = string_reverse(triggerStr):find("%%+")
        local btnStr = lastPlus and string_sub(triggerStr, #triggerStr - lastPlus + 2) or triggerStr
        if btnStr == "None" or btnStr == "" or string_find(btnStr, "Shift") or string_find(btnStr, "Ctrl") or string_find(btnStr, "Alt") then
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
                    table_remove(actions, i)
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
            table_insert(actions, { trigger = newTrigger, effect = effectId })
        end

        -- Clean up empty actions
        for i = #actions, 1, -1 do
            local a = actions[i]
            if not a.trigger or a.trigger == "" then
                table_remove(actions, i)
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

            local row = math_floor((i - 1) / 3)
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

            table_insert(section.cells, cell)
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
            table_insert(db.minimap.mouseActions, { trigger = nil, effect = nil })
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
    local _, swSectionHeight = CreateGridSection("scrollWheel", "Slider Scroll Wheel", scrollWheelEffects, yOff, scrollHelp)
    
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
                            if string_match(action.trigger or "", "LeftButton") and action.trigger == "LeftButton" then
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
                local captureBtnWidth = math_floor(remainingWidth * 0.30)
                local effectDropWidth = math_floor(remainingWidth * 0.25)
                local param1DropWidth = math_floor(remainingWidth * 0.25)
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

                table_insert(minSec.rows, row)
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
            local captureBtnWidth = math_floor(remainingWidth * 0.30)
            local effectDropWidth = math_floor(remainingWidth * 0.25)
            local param1DropWidth = math_floor(remainingWidth * 0.25)
            local param2DropWidth = remainingWidth - captureBtnWidth - effectDropWidth - param1DropWidth

            row.param1Drop:Hide()
            row.param2Drop:Hide()
            row.effectDrop:SetWidth(math_floor(remainingWidth * 0.70))

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
                table_remove(db.minimap.mouseActions, i)
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                VS.RefreshMouseActionsUI()
            end)
        end

        minSec.addBtn:SetPoint("TOPLEFT", minSec, "TOPLEFT", 10, rowYOffset)
    end

    VS.RefreshMouseActionsUI()
end
