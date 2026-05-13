-------------------------------------------------------------------------------
-- Settings_Minimap.lua
--
-- Builds the "Minimap Icon" subcategory UI.
--
-- Author:  Sheldon Michaels
-- License: All Rights Reserved (Non-commercial use permitted)
-------------------------------------------------------------------------------

local addonName, VS = ...

-------------------------------------------------------------------------------
-- Localized Globals
-------------------------------------------------------------------------------
local _G = _G
local ipairs     = ipairs
local table_insert = table.insert
local table_remove = table.remove
local wipe       = wipe
local math_max   = math.max

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
    bg:SetColorTexture(0, 0, 0, 1)

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
    -- Tooltip wiring for this section uses the shared VS:AddTooltip helper.

    local resetBtn = CreateFrame("Button", "VolumeSlidersMinimapResetPositionButton", categoryFrame, "UIPanelButtonTemplate")
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
    VS:AddTooltip(lockIconCheck, "When checked, the minimap icon cannot be dragged. Uncheck to reposition the icon freely.")

    local customIconCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    customIconCheck:SetPoint("TOPLEFT", lockIconCheck, "BOTTOMLEFT", 0, 5)
    customIconCheck.text:SetText("Use Minimalist Speaker Icon")
    customIconCheck:SetChecked(db.minimap.minimalistMinimap)

    local bindMinimapCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    bindMinimapCheck:SetPoint("TOPLEFT", customIconCheck, "BOTTOMLEFT", 0, 5)
    bindMinimapCheck.text:SetText("Bind to Minimap")

    local advFrame -- Forward declaration

    local function UpdateBindMinimapState()
        if db.minimap.minimalistMinimap then
            bindMinimapCheck:Enable()
            bindMinimapCheck.text:SetFontObject("GameFontNormalSmall")
            bindMinimapCheck:SetChecked(db.minimap.bindToMinimap)
            if advFrame then advFrame:SetAlpha(1.0) end
        else
            bindMinimapCheck:Disable()
            bindMinimapCheck.text:SetFontObject("GameFontDisableSmall")
            bindMinimapCheck:SetChecked(true)
            if advFrame then advFrame:SetAlpha(0.5) end
        end
    end
    UpdateBindMinimapState()

    customIconCheck:SetScript("OnClick", function(self)
        db.minimap.minimalistMinimap = self:GetChecked()
        UpdateBindMinimapState()
        if VS.UpdateMiniMapButtonVisibility then VS:UpdateMiniMapButtonVisibility() end
    end)
    VS:AddTooltip(customIconCheck, "Show a minimalist speaker near the zoom controls instead of the standard ringed minimap button.\n\n|cffff0000Note:|r Disabling this requires a UI reload to fully remove hooks.")

    bindMinimapCheck:SetScript("OnClick", function(self)
        db.minimap.bindToMinimap = self:GetChecked()
        if VS.UpdateMiniMapButtonVisibility then VS:UpdateMiniMapButtonVisibility() end
    end)
    VS:AddTooltip(bindMinimapCheck, "If checked, the custom icon fades in when hovering the Minimap.\nIf unchecked, it remains permanently visible.")

    resetBtn:SetScript("OnClick", function()
        VolumeSlidersMMDB.minimap.minimalistOffsetX = -35
        VolumeSlidersMMDB.minimap.minimalistOffsetY = -5
        VolumeSlidersMMDB.minimap.minimalistAngle = 225
        VolumeSlidersMMDB.minimap.minimalistRadius = 10
        VolumeSlidersMMDB.minimap.iconScale = 1.0
        VolumeSlidersMMDB.minimap.iconColor = { r = 1, g = 1, b = 1, a = 1 }
        if VS.RefreshMinimapSettingsUI then VS.RefreshMinimapSettingsUI() end
        if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
    end)
    VS:AddTooltip(resetBtn, "Reset the custom minimap icon position to its default location.")

    -- Advanced Minimalist Settings
    advFrame = CreateFrame("Frame", nil, categoryFrame)
    advFrame:SetSize(400, 180)
    advFrame:SetPoint("TOPLEFT", bindMinimapCheck, "BOTTOMLEFT", 0, -10)
    
    local scaleLabel = advFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 5, 0)
    scaleLabel:SetText("Icon Scale")
    
    local scaleSlider = CreateFrame("Slider", "VSMinimapScaleSlider", advFrame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -10)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetValue(db.minimap.iconScale)
    _G[scaleSlider:GetName() .. "Low"]:SetText("0.5")
    _G[scaleSlider:GetName() .. "High"]:SetText("2.0")
    _G[scaleSlider:GetName() .. "Text"]:SetText(string.format("%.2f", db.minimap.iconScale))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        db.minimap.iconScale = value
        _G[self:GetName() .. "Text"]:SetText(string.format("%.2f", value))
        if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
    end)
    
    local fadeLabel = advFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fadeLabel:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -15)
    fadeLabel:SetText("Fade Speed (sec)")
    
    local fadeSlider = CreateFrame("Slider", "VSMinimapFadeSlider", advFrame, "OptionsSliderTemplate")
    fadeSlider:SetPoint("TOPLEFT", fadeLabel, "BOTTOMLEFT", 0, -10)
    fadeSlider:SetMinMaxValues(0.0, 2.0)
    fadeSlider:SetValueStep(0.1)
    fadeSlider:SetObeyStepOnDrag(true)
    fadeSlider:SetValue(db.minimap.fadeSpeed)
    _G[fadeSlider:GetName() .. "Low"]:SetText("0s")
    _G[fadeSlider:GetName() .. "High"]:SetText("2s")
    _G[fadeSlider:GetName() .. "Text"]:SetText(string.format("%.1fs", db.minimap.fadeSpeed))
    fadeSlider:SetScript("OnValueChanged", function(self, value)
        db.minimap.fadeSpeed = value
        _G[self:GetName() .. "Text"]:SetText(string.format("%.1fs", value))
    end)
    
    local colorBtn = CreateFrame("Button", nil, advFrame)
    colorBtn:SetSize(20, 20)
    colorBtn:SetPoint("LEFT", scaleSlider, "RIGHT", 30, 0)
    local colorTex = colorBtn:CreateTexture(nil, "BACKGROUND")
    colorTex:SetAllPoints()
    colorTex:SetColorTexture(db.minimap.iconColor.r, db.minimap.iconColor.g, db.minimap.iconColor.b, db.minimap.iconColor.a)
    colorBtn.tex = colorTex
    local colorBtnLabel = advFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorBtnLabel:SetPoint("LEFT", colorBtn, "RIGHT", 5, 0)
    colorBtnLabel:SetText("Icon Tint")
    colorBtn:SetScript("OnClick", function()
        local function colorCallback(restore)
            local newR, newG, newB, newA
            if restore then newR, newG, newB, newA = unpack(restore)
            else newA, newR, newG, newB = _G.OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB() end
            db.minimap.iconColor.r, db.minimap.iconColor.g, db.minimap.iconColor.b, db.minimap.iconColor.a = newR, newG, newB, newA
            colorBtn.tex:SetColorTexture(newR, newG, newB, newA)
            if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
        end
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = colorCallback, colorCallback, colorCallback
        ColorPickerFrame:SetColorRGB(db.minimap.iconColor.r, db.minimap.iconColor.g, db.minimap.iconColor.b)
        ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = true, db.minimap.iconColor.a
        ColorPickerFrame.previousValues = {db.minimap.iconColor.r, db.minimap.iconColor.g, db.minimap.iconColor.b, db.minimap.iconColor.a}
        ColorPickerFrame:Show()
    end)
    
    local modeLabel = advFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", colorBtn, "BOTTOMLEFT", 0, -20)
    modeLabel:SetText("Positioning Mode")
    
    local modeDropdown = CreateFrame("DropdownButton", nil, advFrame, "WowStyle1DropdownTemplate")
    modeDropdown:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", 0, -5)
    modeDropdown:SetWidth(150)
    
    local freeXYGroup, freeXFrame, freeXEdit, freeYFrame, freeYEdit
    local clampGroup, clampAngleFrame, clampAngleEdit, clampRadiusFrame, clampRadiusEdit
    
    local function RefreshPositionEditors()
        if db.minimap.minimalistClampMode then
            freeXYGroup:Hide()
            clampGroup:Show()
            if clampAngleEdit then clampAngleEdit:SetText(tostring(db.minimap.minimalistAngle or 225)) end
            if clampRadiusEdit then clampRadiusEdit:SetText(tostring(db.minimap.minimalistRadius or 10)) end
        else
            clampGroup:Hide()
            freeXYGroup:Show()
            if freeXEdit then freeXEdit:SetText(tostring(db.minimap.minimalistOffsetX or -35)) end
            if freeYEdit then freeYEdit:SetText(tostring(db.minimap.minimalistOffsetY or -5)) end
        end
    end
    
    modeDropdown:SetupMenu(function(dropdown, rootDescription)
        local function IsSelected(value) return db.minimap.minimalistClampMode == value end
        local function SetSelected(value)
            db.minimap.minimalistClampMode = value
            RefreshPositionEditors()
            if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
        end
        rootDescription:CreateRadio("Free Floating (X/Y)", IsSelected, SetSelected, false)
        rootDescription:CreateRadio("Clamped Radially", IsSelected, SetSelected, true)
    end)
    
    local function CreateNudgeGroup(parent, labelText, dbKey, isAngle)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetSize(80, 40)
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 0, 0)
        label:SetText(labelText)

        local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        editBox:SetSize(40, 20)
        editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 5, -5)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(false)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            local val = tonumber(self:GetText())
            if val then
                db.minimap[dbKey] = val
                if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
            end
        end)

        local function GetStepAmount()
            if IsAltKeyDown() then return 10
            elseif IsControlKeyDown() then return 5
            elseif IsShiftKeyDown() then return 2
            else return 1 end
        end

        local upBtn = CreateFrame("Button", nil, frame)
        upBtn:SetSize(16, 16)
        upBtn:SetPoint("LEFT", editBox, "RIGHT", 2, 5)
        upBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
        upBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
        upBtn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
        upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        upBtn:SetScript("OnClick", function()
            local s = GetStepAmount()
            db.minimap[dbKey] = (db.minimap[dbKey] or 0) + s
            if isAngle and db.minimap[dbKey] >= 360 then db.minimap[dbKey] = db.minimap[dbKey] - 360 end
            editBox:SetText(tostring(db.minimap[dbKey]))
            if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
        end)
        VS:AddTooltip(upBtn, "Increase value.\nHold Shift for 2, Ctrl for 5, Alt for 10.")

        local downBtn = CreateFrame("Button", nil, frame)
        downBtn:SetSize(16, 16)
        downBtn:SetPoint("TOP", upBtn, "BOTTOM", 0, 4)
        downBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        downBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        downBtn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        downBtn:SetScript("OnClick", function()
            local s = GetStepAmount()
            db.minimap[dbKey] = (db.minimap[dbKey] or 0) - s
            if isAngle and db.minimap[dbKey] < 0 then db.minimap[dbKey] = db.minimap[dbKey] + 360 end
            editBox:SetText(tostring(db.minimap[dbKey]))
            if VS.UpdateMinimapVisuals then VS:UpdateMinimapVisuals() end
        end)
        VS:AddTooltip(downBtn, "Decrease value.\nHold Shift for 2, Ctrl for 5, Alt for 10.")

        return frame, editBox
    end
    
    freeXYGroup = CreateFrame("Frame", nil, advFrame)
    freeXYGroup:SetSize(200, 40)
    freeXYGroup:SetPoint("TOPLEFT", modeDropdown, "BOTTOMLEFT", 0, -10)
    freeXFrame, freeXEdit = CreateNudgeGroup(freeXYGroup, "X Offset", "minimalistOffsetX", false)
    freeXFrame:SetPoint("TOPLEFT", 0, 0)
    freeYFrame, freeYEdit = CreateNudgeGroup(freeXYGroup, "Y Offset", "minimalistOffsetY", false)
    freeYFrame:SetPoint("TOPLEFT", freeXFrame, "TOPRIGHT", 10, 0)
    
    clampGroup = CreateFrame("Frame", nil, advFrame)
    clampGroup:SetSize(200, 40)
    clampGroup:SetPoint("TOPLEFT", modeDropdown, "BOTTOMLEFT", 0, -10)
    clampAngleFrame, clampAngleEdit = CreateNudgeGroup(clampGroup, "Angle (Deg)", "minimalistAngle", true)
    clampAngleFrame:SetPoint("TOPLEFT", 0, 0)
    clampRadiusFrame, clampRadiusEdit = CreateNudgeGroup(clampGroup, "Radius Offset", "minimalistRadius", false)
    clampRadiusFrame:SetPoint("TOPLEFT", clampAngleFrame, "TOPRIGHT", 10, 0)
    
    RefreshPositionEditors()
    UpdateBindMinimapState()

    local showTooltipCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    showTooltipCheck:SetPoint("TOPLEFT", advFrame, "BOTTOMLEFT", 0, -5)
    showTooltipCheck.text:SetText("Show Tooltip")
    showTooltipCheck:SetChecked(db.toggles.showMinimapTooltip ~= false)
    showTooltipCheck:SetScript("OnClick", function(self)
        db.toggles.showMinimapTooltip = self:GetChecked()
    end)
    VS:AddTooltip(showTooltipCheck, "Show or hide the tooltip when hovering over the minimap icon.")

    -- Play Sample Sound Checkbox
    local playSoundCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    playSoundCheck:SetPoint("TOPLEFT", showTooltipCheck, "BOTTOMLEFT", 0, -10)
    playSoundCheck.text:SetText("Play Sample Sound")
    playSoundCheck.text:SetFontObject("GameFontNormal")
    playSoundCheck:SetChecked(db.toggles.playSampleSoundMinimap == true)
    playSoundCheck:SetScript("OnClick", function(self)
        db.toggles.playSampleSoundMinimap = self:GetChecked()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    VS:AddTooltip(playSoundCheck, "Play a chime when scrolling the minimap icon to adjust volume.")

    local knownSounds = {
        [856] = true,
        [850] = true,
        [880] = true,
        [73275] = true,
        [8959] = true
    }

    local function IsSoundSelected(value)
        if value == "Custom" then
            return not knownSounds[db.appearance.sampleSoundMinimap]
        end
        return db.appearance.sampleSoundMinimap == value
    end

    local function SetSoundSelected(value)
        if value == "Custom" then
            -- Fallback if no EditBox is available on this page
            db.appearance.sampleSoundMinimap = 856
        else
            db.appearance.sampleSoundMinimap = value
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    local soundDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    soundDropdown:SetPoint("TOPLEFT", playSoundCheck, "BOTTOMLEFT", 10, 0)
    soundDropdown:SetWidth(180)
    soundDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateRadio("Standard Click", IsSoundSelected, SetSoundSelected, 856)
        rootDescription:CreateRadio("Main Menu Open", IsSoundSelected, SetSoundSelected, 850)
        rootDescription:CreateRadio("Player Invite", IsSoundSelected, SetSoundSelected, 880)
        rootDescription:CreateRadio("LFG Application", IsSoundSelected, SetSoundSelected, 73275)
        rootDescription:CreateRadio("Raid Warning", IsSoundSelected, SetSoundSelected, 8959)
    end)
    soundDropdown:GenerateMenu()

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
                    table_remove(db.minimap.minimapTooltipOrder, i)
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
            local newHeight = math_max(50, (#db.minimap.minimapTooltipOrder * 36) + 10)
            scrollBox:SetHeight(newHeight)
        end
    end
    RefreshTooltipDataProvider()


    dragBehavior:SetDropPredicate(function(sourceElementData, intersectData)
        if intersectData.area == DragIntersectionArea.Inside then
            local cursorParent = FrameUtil.GetRootParent(scrollBox)
            local _, cy = _G.GetCursorPosition()
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
            table_insert(db.minimap.minimapTooltipOrder, item)
        end
    end)
    
    addBtn:SetupMenu(function(dropdown, rootDescription)
        local function AddType(typ, channel)
            db.minimap.minimapTooltipOrder = db.minimap.minimapTooltipOrder or {}
            table_insert(db.minimap.minimapTooltipOrder, { type = typ, channel = channel })
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
