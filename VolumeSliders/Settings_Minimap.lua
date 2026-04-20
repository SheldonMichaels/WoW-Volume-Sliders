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
    -- Deduped: Now using shared VS:AddTooltip(frame, text)

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
    VS:AddTooltip(lockIconCheck, "When checked, the minimap icon cannot be dragged. Uncheck to reposition the icon freely.")

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
    VS:AddTooltip(customIconCheck, "Show a minimalist speaker near the zoom controls instead of the standard ringed minimap button.\n\n|cffff0000Note:|r Disabling this requires a UI reload to fully remove hooks.")

    bindMinimapCheck:SetScript("OnClick", function(self)
        db.minimap.bindToMinimap = self:GetChecked()
        if VS.UpdateMiniMapButtonVisibility then VS:UpdateMiniMapButtonVisibility() end
    end)
    VS:AddTooltip(bindMinimapCheck, "If checked, the custom icon fades in when hovering the Minimap.\nIf unchecked, it remains permanently visible.")

    resetBtn:SetScript("OnClick", function()
        VolumeSlidersMMDB.minimap.minimalistOffsetX = -35
        VolumeSlidersMMDB.minimap.minimalistOffsetY = -5
        if VS.minimalistButton then
            VS.minimalistButton:ClearAllPoints()
            VS.minimalistButton:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -35, -5)
        end
    end)
    VS:AddTooltip(resetBtn, "Reset the custom minimap icon position to its default location.")

    local showTooltipCheck = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
    showTooltipCheck:SetPoint("TOPLEFT", bindMinimapCheck, "BOTTOMLEFT", 0, 5)
    showTooltipCheck.text:SetText("Show Tooltip")
    showTooltipCheck:SetChecked(db.toggles.showMinimapTooltip ~= false)
    showTooltipCheck:SetScript("OnClick", function(self)
        db.toggles.showMinimapTooltip = self:GetChecked()
    end)
    VS:AddTooltip(showTooltipCheck, "Show or hide the tooltip when hovering over the minimap icon.")

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
