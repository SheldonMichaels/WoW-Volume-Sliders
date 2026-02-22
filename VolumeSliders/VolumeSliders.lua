-------------------------------------------------------------------------------
-- VolumeSliders.lua
--
-- A World of Warcraft addon that provides quick-access vertical volume sliders
-- for all five sound channels (Master, Effects, Music, Ambience, Dialog),
-- along with per-channel mute toggles, a sound output device selector, and
-- minimap / LDB / Addon Compartment integration.
--
-- Architecture Overview:
--   • Uses LibDataBroker and LibDBIcon for minimap/broker integration.
--   • A single popup frame hosts five vertical sliders using Blizzard templates.
--   • Toggled via minimap button, broker frame, or Addon Compartment.
--   • Mouse-wheel on the icon adjusts master volume directly.
--
-- Author: Sheldon Michaels
-- Version: 1.0
-- License: All Rights Reserved
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Addon Bootstrapping
-------------------------------------------------------------------------------

-- The vararg (...) passed to every addon file is the addon folder name.
local _addonName = ...

-- Core addon table (plain Lua table — no framework dependency).
local VS = {}

-- Retrieve broker libraries used for minimap icon and data-broker display.
local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

-------------------------------------------------------------------------------
-- Saved Variables
-------------------------------------------------------------------------------

-- VolumeSlidersMMDB is declared as a SavedVariable in the TOC file.
-- LibDBIcon stores the minimap button's angular position and visibility flag
-- inside this table.  We initialize it here so it exists on first load.
VolumeSlidersMMDB = VolumeSlidersMMDB or {
    minimapPos = 180,   -- Degrees around the minimap (0 = top, 180 = bottom)
    hide = false,       -- Whether the minimap button is hidden
}

-------------------------------------------------------------------------------
-- Module-Level State
-------------------------------------------------------------------------------

-- Reference to the broker frame that was most recently clicked (used to
-- anchor the popup relative to the broker icon's position on screen).
VS.brokerFrame = nil

-- Flag: has the mouse-wheel script already been attached to the broker frame?
-- Prevents re-hooking the same frame multiple times.
VS.brokerScrollSet = false

-----------------------------------------
-- Layout Constants
--
-- These values define the dimensions and spacing of the popup frame and its
-- child elements.  They are used to compute the overall frame size so that
-- changes to slider count or spacing automatically propagate.
-----------------------------------------

-- Insets of the SettingsFrameTemplate's NineSlice border.  Content is placed
-- inside these margins to avoid overlapping the frame's decorative edges.
local TEMPLATE_CONTENT_OFFSET_LEFT = 7
local TEMPLATE_CONTENT_OFFSET_RIGHT = 3
local TEMPLATE_CONTENT_OFFSET_TOP = 18
local TEMPLATE_CONTENT_OFFSET_BOTTOM = 3

-- Each slider occupies a column of this width, with this spacing between them.
local SLIDER_COLUMN_WIDTH = 60
local SLIDER_COLUMN_SPACING = 15

-- Fixed height of the slider track itself (excludes labels and buttons).
local SLIDER_HEIGHT = 120

-- Total number of volume channel sliders displayed.
local NUM_SLIDERS = 5

-- Padding around the content area inside the NineSlice border.
local CONTENT_PADDING_X = 20
local CONTENT_PADDING_TOP = 15
local CONTENT_PADDING_BOTTOM = 15

-- Derived dimensions — automatically adjust if the constants above change.
local CONTENT_WIDTH = (CONTENT_PADDING_X * 2)
    + (NUM_SLIDERS * SLIDER_COLUMN_WIDTH)
    + ((NUM_SLIDERS - 1) * SLIDER_COLUMN_SPACING)

-- Content height breakdown:
--   CONTENT_PADDING_TOP + 95 (instruction text + slider titles + percentages) +
--   SLIDER_HEIGHT + 100 (mute checkboxes shifted down) + 35 (bottom row) +
--   CONTENT_PADDING_BOTTOM
local CONTENT_HEIGHT = CONTENT_PADDING_TOP + 95 + SLIDER_HEIGHT + 100 + 35 + CONTENT_PADDING_BOTTOM

-- Full frame size including NineSlice border insets.
local FRAME_WIDTH = CONTENT_WIDTH + TEMPLATE_CONTENT_OFFSET_LEFT + TEMPLATE_CONTENT_OFFSET_RIGHT
local FRAME_HEIGHT = CONTENT_HEIGHT + TEMPLATE_CONTENT_OFFSET_TOP + TEMPLATE_CONTENT_OFFSET_BOTTOM

-----------------------------------------
-- Helper Functions
-----------------------------------------

--- Read the current master volume from the CVar and return it as a number
--- in the range [0, 1].  Falls back to 1 (full volume) if the CVar is
--- missing or unparseable.
local function GetMasterVolume()
    local volStr = GetCVar("Sound_MasterVolume") or "1"
    return tonumber(volStr) or 1
end

--- Adjust the master volume by one increment in the given direction.
--- @param delta  number  Positive = volume up, negative = volume down.
---
--- The default step is 5% (0.05).  When the volume is below 20%, the step
--- shrinks to 1% for finer control at low levels.  Holding Ctrl also forces
--- the 1% step regardless of current level.
function VS:AdjustVolume(delta)
    local increment = 0.05
    local current = GetMasterVolume()

    -- Use a finer step at low volumes or when Ctrl is held.
    if current < 0.2 then
        increment = 0.01
    end
    if IsControlKeyDown() then
        increment = 0.01
    end

    -- Apply the delta direction.
    if delta > 0 then
        current = current + increment
    else
        current = current - increment
    end

    -- Clamp to the valid [0, 1] range and persist.
    current = math.max(0, math.min(1, current))
    SetCVar("Sound_MasterVolume", current)

    -- Update the broker text (the percentage shown on the LDB display).
    if VS.VolumeSlidersObject then
        VS.VolumeSlidersObject.text = VS:GetVolumeText()
    end

    -- If the slider panel is open, sync the Master slider to the new value.
    -- Note: sliders use *inverted* values (0 at top = max volume, 1 at
    -- bottom = min volume) so we set `1 - current`.
    if VS.sliders and VS.sliders["Sound_MasterVolume"] then
         local sliderVal = 1 - current
         VS.sliders["Sound_MasterVolume"]:SetValue(sliderVal)
         VS.sliders["Sound_MasterVolume"].valueText:SetText(math.floor(current * 100) .. "%")
    end
end

--- Toggle the master mute state by flipping the Sound_EnableAllSound CVar.
--- Also updates the minimap icon texture and the Master slider's mute
--- checkbox if the panel is open.
function VS:VolumeSliders_ToggleMute()
    local soundEnabled = GetCVar("Sound_EnableAllSound")
    if soundEnabled == "1" then
        SetCVar("Sound_EnableAllSound", 0)
    else
        SetCVar("Sound_EnableAllSound", 1)
    end
    VS:UpdateMiniMapVolumeIcon()

    -- Sync the Master slider's mute checkbox if the panel is visible.
    if VS.sliders and VS.sliders["Sound_MasterVolume"] and VS.sliders["Sound_MasterVolume"].muteCheck then
        local isEnabled = GetCVar("Sound_EnableAllSound") == "1"
        VS.sliders["Sound_MasterVolume"].muteCheck:SetChecked(not isEnabled)
    end
end

--- Return a human-readable percentage string for the current master volume.
--- Example: "75%"
function VS:GetVolumeText()
    local vol = GetMasterVolume()
    vol = vol * 100
    return tostring(math.floor(vol)) .. "%"
end

-----------------------------------------
-- UI Construction
-----------------------------------------

-- Forward reference for the popup container frame (created lazily).
local vsContainer

-- Lookup table mapping CVar name → slider widget.  Populated during
-- CreateOptionsFrame() and used to sync slider positions when CVars change
-- externally (e.g., via the Blizzard Sound settings panel).
VS.sliders = {}

--- Disable the HoverBackgroundTemplate that ships with SettingsCheckboxTemplate.
---
--- The template anchors a white overlay texture to $parent.$parent (the
--- grandparent frame), which causes the entire popup background to flash
--- white when the cursor enters any checkbox.  We hide that overlay and
--- clear the enter/leave scripts that toggle it.
---
--- @param check  CheckButton  The checkbox frame to patch.
local function DisableCheckboxHoverBackground(check)
    if check.HoverBackground then
        check.HoverBackground:Hide()
        check.HoverBackground:SetParent(nil)
    end
    check:SetScript("OnEnter", nil)
    check:SetScript("OnLeave", nil)
end

--- Set a texture to display a Blizzard atlas rotated 90° clockwise.
---
--- Blizzard's slider atlas assets are designed for horizontal use.  This
--- addon repurposes them for vertical sliders by rotating the texture
--- coordinates.  The function:
---   1. Looks up the atlas sub-region (left/right/top/bottom tex coords).
---   2. Remaps the four corners via the 8-argument SetTexCoord overload
---      to achieve a 90° CW rotation.
---   3. Swaps width and height so the visual dimensions match.
---
--- @param tex        Texture   The texture object to modify.
--- @param atlasName  string    Blizzard atlas identifier (e.g., "Minimal_SliderBar_Left").
--- @return boolean   true on success, false if the atlas was not found.
local function SetAtlasRotated90CW(tex, atlasName)
    local info = C_Texture.GetAtlasInfo(atlasName)
    if not info then return false end

    -- Atlas sub-region corners in normalized texture-space.
    local L, R = info.leftTexCoord, info.rightTexCoord
    local T, B = info.topTexCoord, info.bottomTexCoord

    -- Point the texture at the underlying texture file (the atlas sheet).
    tex:SetTexture(info.file)

    -- 90° CW rotation via corner remapping:
    --   Original:  UL=(L,T)  LL=(L,B)  UR=(R,T)  LR=(R,B)
    --   Rotated:   UL=(L,B)  LL=(R,B)  UR=(L,T)  LR=(R,T)
    -- SetTexCoord signature: (ULx,ULy, LLx,LLy, URx,URy, LRx,LRy)
    tex:SetTexCoord(L, B, R, B, L, T, R, T)

    -- After rotation the visual width becomes the original height and
    -- vice versa, so swap the dimensions.
    tex:SetSize(info.height, info.width)
    return true
end

-------------------------------------------------------------------------------
-- CreateVerticalSlider
--
-- Builds a single vertical volume slider column consisting of:
--   • A track using rotated MinimalSlider atlas pieces.
--   • A diamond-shaped thumb.
--   • Stepper arrow buttons (▲ above, ▼ below) with snap-to-5% logic.
--   • A title label, High/Low labels, and a percentage readout.
--   • A mute checkbox below the slider.
--
-- The slider uses INVERTED values: the Slider widget's value range is
-- [0, 1] where 0 corresponds to 100% volume (thumb at top) and 1
-- corresponds to 0% volume (thumb at bottom).  This is because WoW's
-- vertical Slider widget places value 0 at the top and max at the bottom,
-- but users expect "up = louder".
--
-- @param parent    Frame    Parent frame to attach child elements to.
-- @param name      string   Global frame name prefix.
-- @param label     string   Display label (e.g., "Master", "Effects").
-- @param cvar      string   CVar controlling volume (e.g., "Sound_MasterVolume").
-- @param muteCvar  string   CVar controlling channel enable (e.g., "Sound_EnableAllSound").
-- @param minVal    number   Slider minimum (typically 0).
-- @param maxVal    number   Slider maximum (typically 1).
-- @param step      number   Slider step increment (typically 0.01 = 1%).
-- @return Slider           The created slider widget (with extra fields attached).
-------------------------------------------------------------------------------
local function CreateVerticalSlider(parent, name, label, cvar, muteCvar, minVal, maxVal, step)
    local slider = CreateFrame("Slider", name, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetHeight(SLIDER_HEIGHT)
    slider:SetWidth(20)

    -- Expand the clickable area so the user doesn't have to hit the narrow
    -- 20px track exactly.  Negative insets grow the hit rect outward.
    slider:SetHitRectInsets(-15, -15, 0, 0)

    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouseWheel(true)

    ---------------------------------------------------------------------------
    -- Track Construction
    --
    -- The track is composed of three atlas pieces (top cap, middle fill,
    -- bottom cap) which are the horizontal MinimalSlider assets rotated 90°
    -- clockwise.  The middle piece stretches vertically between the caps.
    ---------------------------------------------------------------------------

    -- Top endcap (originally the horizontal "Left" end piece).
    local trackTop = slider:CreateTexture(nil, "BACKGROUND")
    SetAtlasRotated90CW(trackTop, "Minimal_SliderBar_Left")
    trackTop:SetPoint("TOP", slider, "TOP", 0, 0)

    -- Bottom endcap (originally the horizontal "Right" end piece).
    local trackBottom = slider:CreateTexture(nil, "BACKGROUND")
    SetAtlasRotated90CW(trackBottom, "Minimal_SliderBar_Right")
    trackBottom:SetPoint("BOTTOM", slider, "BOTTOM", 0, 0)

    -- Middle fill (stretches between cap anchors).
    local trackMiddle = slider:CreateTexture(nil, "BACKGROUND")
    local midInfo = C_Texture.GetAtlasInfo("_Minimal_SliderBar_Middle")
    if midInfo then
        trackMiddle:SetTexture(midInfo.file)
        local L, R = midInfo.leftTexCoord, midInfo.rightTexCoord
        local T, B = midInfo.topTexCoord, midInfo.bottomTexCoord
        trackMiddle:SetTexCoord(L, B, R, B, L, T, R, T)
        trackMiddle:SetWidth(midInfo.height) -- Swapped for 90° rotation
    end
    trackMiddle:SetPoint("TOP", trackTop, "BOTTOM", 0, 0)
    trackMiddle:SetPoint("BOTTOM", trackBottom, "TOP", 0, 0)

    -- Diamond-shaped thumb (uses the gold diamond from Boss Abilities).
    -- Future Options Reference:
    --   Old silver knob atlas: "Minimal_SliderBar_Button"
    local thumb = slider:CreateTexture(name .. "Thumb", "OVERLAY")
    thumb:SetAtlas("combattimeline-pip", true)
    slider:SetThumbTexture(thumb)

    -- Force the thumb to be visible after a brief delay.  On initial frame
    -- creation the thumb texture can be hidden by the engine until the first
    -- user interaction; this timer ensures it renders immediately.
    C_Timer.After(0.05, function()
        local t = slider:GetThumbTexture()
        if t and not t:IsShown() then
            t:Show()
        end
    end)

    ---------------------------------------------------------------------------
    -- Stepper Arrow Buttons (▲ / ▼)
    --
    -- Each click snaps the volume to the nearest 5% boundary in the
    -- corresponding direction.  The 0.5 offset in the math prevents the
    -- value from "sticking" when already on a boundary.
    ---------------------------------------------------------------------------
    local STEP_PERCENT = 5

    -- Up arrow (increase volume)
    -- Future Options Reference:
    --   Old silver up arrow layout:
    --   upBtn:SetSize(19, 11)
    --   SetAtlasRotated90CW(upTex, "Minimal_SliderBar_Button_Left")
    --   Old gold up arrow layout:
    --   upTex:SetAtlas("ui-hud-actionbar-pageuparrow-up")
    local upBtn = CreateFrame("Button", name .. "StepUp", parent)
    upBtn:SetSize(20, 20) -- Explicitly size the button hit-box so it doesn't collapse to 0x0
    local upTex = upBtn:CreateTexture(nil, "BACKGROUND")
    upTex:SetAtlas("ui-hud-minimap-zoom-in")
    upTex:SetSize(20, 20)
    upTex:SetPoint("CENTER", upBtn, "CENTER", 0, 0)
    upBtn:SetPoint("BOTTOM", slider, "TOP", 0, 3)
    upBtn:SetScript("OnClick", function()
        -- Convert from inverted slider value to real volume percentage.
        local currentVol = 1 - slider:GetValue()
        local currentPct = currentVol * 100
        -- Snap up: ceiling to next 5% boundary (0.5 prevents sticking).
        local newPct = math.ceil((currentPct + 0.5) / STEP_PERCENT) * STEP_PERCENT
        newPct = math.min(100, math.max(0, newPct))
        -- Convert back to inverted slider value.
        slider:SetValue(1 - (newPct / 100))
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- Down arrow (decrease volume)
    -- Future Options Reference:
    --   Old silver down arrow layout:
    --   downBtn:SetSize(19, 11)
    --   SetAtlasRotated90CW(downTex, "Minimal_SliderBar_Button_Right")
    --   Old gold down arrow layout:
    --   downTex:SetAtlas("ui-hud-actionbar-pagedownarrow-up")
    local downBtn = CreateFrame("Button", name .. "StepDown", parent)
    downBtn:SetSize(20, 20) -- Explicitly size the button hit-box
    local downTex = downBtn:CreateTexture(nil, "BACKGROUND")
    downTex:SetAtlas("ui-hud-minimap-zoom-out")
    downTex:SetSize(20, 20)
    downTex:SetPoint("CENTER", downBtn, "CENTER", 0, 0) -- No offset
    downBtn:SetPoint("TOP", slider, "BOTTOM", 0, -3)
    downBtn:SetScript("OnClick", function()
        local currentVol = 1 - slider:GetValue()
        local currentPct = currentVol * 100
        -- Snap down: floor to previous 5% boundary (0.5 prevents sticking).
        local newPct = math.floor((currentPct - 0.5) / STEP_PERCENT) * STEP_PERCENT
        newPct = math.min(100, math.max(0, newPct))
        slider:SetValue(1 - (newPct / 100))
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- Store references for external repositioning if needed.
    slider.upBtn = upBtn
    slider.downBtn = downBtn

    ---------------------------------------------------------------------------
    -- Labels & Value Text
    ---------------------------------------------------------------------------

    -- "High" / "Low" endpoint labels above and below the stepper arrows.
    slider.highLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.highLabel:SetPoint("BOTTOM", upBtn, "TOP", 0, 5)
    slider.highLabel:SetText("High")

    slider.lowLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.lowLabel:SetPoint("TOP", downBtn, "BOTTOM", 0, -1)
    slider.lowLabel:SetText("Low")

    -- Numeric percentage readout above the "High" text.
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slider.valueText:SetPoint("BOTTOM", slider.highLabel, "TOP", 0, 10)
    slider.valueText:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

    -- Title label (centered above the percentage).
    slider.label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slider.label:SetPoint("BOTTOM", slider.valueText, "TOP", 0, 4)
    slider.label:SetText(label)
    slider.label:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

    ---------------------------------------------------------------------------
    -- Initial Value & OnValueChanged
    --
    -- Reminder: slider value is INVERTED.  CVar 1.0 (max vol) maps to
    -- slider value 0.0; CVar 0.0 (muted) maps to slider value 1.0.
    ---------------------------------------------------------------------------
    local currentVolume = tonumber(GetCVar(cvar)) or 1
    slider:SetValue(1 - currentVolume)
    slider.valueText:SetText(math.floor(currentVolume * 100) .. "%")

    slider:SetScript("OnValueChanged", function(self, value)
        -- Un-invert the slider value to get the actual volume level.
        local invertedValue = 1 - value
        invertedValue = math.max(0, math.min(1, invertedValue))
        -- Round to two decimal places to avoid floating-point noise in CVars.
        local val = math.floor(invertedValue * 100) / 100

        SetCVar(cvar, val)
        self.valueText:SetText(math.floor(val * 100) .. "%")

        -- Keep the broker text in sync when the Master slider moves.
        if cvar == "Sound_MasterVolume" then
             if VS.VolumeSlidersObject then
                VS.VolumeSlidersObject.text = VS:GetVolumeText()
            end
        end
    end)

    -- Mouse wheel on the slider itself adjusts volume in 1% increments.
    -- Delta is inverted because slider value direction is inverted.
    slider:SetScript("OnMouseWheel", function(self, delta)
        local val = self:GetValue()
        if delta > 0 then
            self:SetValue(val - step) -- Scroll up → decrease slider value → increase volume
        else
            self:SetValue(val + step) -- Scroll down → increase slider value → decrease volume
        end
    end)

    ---------------------------------------------------------------------------
    -- Mute Checkbox
    --
    -- Uses SettingsCheckboxTemplate for consistent Blizzard styling.
    -- Checked = muted (CVar is 0), Unchecked = enabled (CVar is 1).
    -- This inversion matches the "mute" semantic: ticking the box silences
    -- the channel.
    ---------------------------------------------------------------------------
    local muteCheck = CreateFrame("CheckButton", name .. "Mute", parent, "SettingsCheckboxTemplate")
    muteCheck:SetSize(26, 26)
    muteCheck:SetPoint("TOP", slider, "BOTTOM", 0, -42)
    DisableCheckboxHoverBackground(muteCheck)

    -- "Mute" label below the checkbox.
    local muteLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    muteLabel:SetPoint("TOP", muteCheck, "BOTTOM", 0, -2)
    muteLabel:SetText("Mute")
    muteCheck.muteLabel = muteLabel

    -- Initialize checkbox state: checked when the channel is DISABLED.
    local isEnabled = GetCVar(muteCvar) == "1"
    muteCheck:SetChecked(not isEnabled)

    muteCheck:SetScript("OnClick", function(self)
        local isMuted = self:GetChecked()
        if isMuted then
            SetCVar(muteCvar, 0) -- Disable (mute) the sound channel
        else
            SetCVar(muteCvar, 1) -- Enable (unmute) the sound channel
        end

        -- The Master channel mute also drives the minimap icon state.
        if muteCvar == "Sound_EnableAllSound" then
            VS:UpdateMiniMapVolumeIcon()
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- Attach mute references to the slider for external sync access.
    slider.muteCheck = muteCheck
    slider.muteCvar = muteCvar

    return slider
end

-------------------------------------------------------------------------------
-- CreateCheckbox
--
-- Generic helper to create a labeled checkbox using SettingsCheckboxTemplate.
--
-- @param parent            Frame     Parent frame.
-- @param name              string    Global frame name.
-- @param label             string    Text label displayed next to the checkbox.
-- @param onClick           function  Callback receiving (checked: boolean).
-- @param initialValueFunc  function  Returns boolean for the initial checked state.
-- @return CheckButton
-------------------------------------------------------------------------------
local function CreateCheckbox(parent, name, label, onClick, initialValueFunc)
    local check = CreateFrame("CheckButton", name, parent, "SettingsCheckboxTemplate")
    check:SetSize(26, 26)
    DisableCheckboxHoverBackground(check)

    -- Label to the right of the checkbox.
    local checkLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkLabel:SetPoint("LEFT", check, "RIGHT", 4, 0)
    checkLabel:SetText(label)
    check.labelText = checkLabel

    check:SetChecked(initialValueFunc())

    check:SetScript("OnClick", function(self)
        onClick(self:GetChecked())
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)
    return check
end

-------------------------------------------------------------------------------
-- CreateOptionsFrame
--
-- Lazily creates the main popup panel containing all five sliders, the
-- bottom-row controls, and handles open/close behavior.
--
-- Uses Blizzard's SettingsFrameTemplate for the outer chrome.
-------------------------------------------------------------------------------
function VS:CreateOptionsFrame()
    if vsContainer then return vsContainer end

    -- Create the popup using the modern settings frame template.
    vsContainer = CreateFrame("Frame", "VolumeSlidersFrame", UIParent, "SettingsFrameTemplate")
    vsContainer:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    vsContainer:SetPoint("CENTER")
    vsContainer:SetFrameStrata("DIALOG")
    vsContainer:SetFrameLevel(100)
    vsContainer:SetClampedToScreen(true)
    vsContainer:EnableMouse(true)

    -- Set the title bar text via the NineSlice's built-in Text font string.
    if vsContainer.NineSlice and vsContainer.NineSlice.Text then
        vsContainer.NineSlice.Text:SetText("Volume Sliders")
    else
        -- Fallback: create our own title if the template layout differs.
        local titleText = vsContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        titleText:SetText("Volume Sliders")
        titleText:SetPoint("TOP", vsContainer, "TOP", 0, -5)
    end

    -- Wire the close button (provided by SettingsFrameTemplate).
    if vsContainer.ClosePanelButton then
        vsContainer.ClosePanelButton:SetScript("OnClick", function() vsContainer:Hide() end)
    else
        -- Fallback close button if template doesn't include one.
        local closeButton = CreateFrame("Button", "VolumeSlidersFrameCloseButton", vsContainer, "UIPanelCloseButtonDefaultAnchors")
        closeButton:SetScript("OnClick", function() vsContainer:Hide() end)
    end

    -- Replace the template's default light background with a darker one
    -- for better contrast against the volume controls.
    if vsContainer.Bg then vsContainer.Bg:Hide() end
    local newBg = vsContainer:CreateTexture(nil, "BACKGROUND", nil, -1)
    newBg:SetPoint("TOPLEFT", vsContainer, "TOPLEFT", TEMPLATE_CONTENT_OFFSET_LEFT, -TEMPLATE_CONTENT_OFFSET_TOP)
    newBg:SetPoint("BOTTOMRIGHT", vsContainer, "BOTTOMRIGHT", -TEMPLATE_CONTENT_OFFSET_RIGHT, TEMPLATE_CONTENT_OFFSET_BOTTOM)
    newBg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    -- Register for Escape-key closing via the Blizzard UISpecialFrames list.
    tinsert(UISpecialFrames, vsContainer:GetName())

    ---------------------------------------------------------------------------
    -- Event Handlers: Close on outside click / combat lockdown
    ---------------------------------------------------------------------------
    vsContainer:SetScript("OnEvent", function(self, event, ...)
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
                
                self:Hide()
            end
        end
    end)

    vsContainer:SetScript("OnShow", function(self)
        -- Start listening for outside clicks when the panel opens.
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")

        -- Refresh all slider positions from current CVar values in case
        -- they were changed externally (e.g., via Blizzard Sound settings).
        if VS.sliders then
            for cvar, slider in pairs(VS.sliders) do
                 local currentVolume = tonumber(GetCVar(cvar)) or 1
                 slider:SetValue(1 - currentVolume)
                 slider.valueText:SetText(math.floor(currentVolume * 100) .. "%")
            end
        end

        -- Refresh the "Sound at Character" checkbox.
        if VS.characterCheckbox then
             VS.characterCheckbox:SetChecked(GetCVar("Sound_ListenerAtCharacter") == "1")
        end

        -- Refresh all mute checkboxes.
        if VS.sliders then
            for _, slider in pairs(VS.sliders) do
                 if slider.muteCheck and slider.muteCvar then
                     local isEnabled = GetCVar(slider.muteCvar) == "1"
                     slider.muteCheck:SetChecked(not isEnabled)
                 end
            end
        end
    end)

    vsContainer:SetScript("OnHide", function(self)
        -- Stop listening for outside clicks when the panel is closed.
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end)

    ---------------------------------------------------------------------------
    -- Content Frame (inside the NineSlice border insets)
    ---------------------------------------------------------------------------
    local contentFrame = CreateFrame("Frame", "VolumeSlidersContentFrame", vsContainer)
    contentFrame:SetPoint("TOPLEFT", vsContainer, "TOPLEFT", TEMPLATE_CONTENT_OFFSET_LEFT, -TEMPLATE_CONTENT_OFFSET_TOP)
    contentFrame:SetPoint("BOTTOMRIGHT", vsContainer, "BOTTOMRIGHT", -TEMPLATE_CONTENT_OFFSET_RIGHT, TEMPLATE_CONTENT_OFFSET_BOTTOM)

    -- Instruction text displayed at the top of the panel.
    local instruction = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instruction:SetPoint("TOP", contentFrame, "TOP", 0, -CONTENT_PADDING_TOP)
    instruction:SetText("Right-click on the icon to toggle master mute.")
    instruction:SetTextColor(1, 1, 1)

    ---------------------------------------------------------------------------
    -- Volume Sliders
    --
    -- Five sliders are laid out in a horizontal row.  Each column is
    -- SLIDER_COLUMN_WIDTH wide with SLIDER_COLUMN_SPACING between them.
    ---------------------------------------------------------------------------
    local startX = CONTENT_PADDING_X
    local startY = -(CONTENT_PADDING_TOP + 95)

    -- Master Volume
    local masterSlider = CreateVerticalSlider(contentFrame, "VolumeSlidersSliderMaster", "Master", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01)
    masterSlider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MasterVolume"] = masterSlider

    -- Effects Volume
    local sfxSlider = CreateVerticalSlider(contentFrame, "VolumeSlidersSliderSFX", "Effects", "Sound_SFXVolume", "Sound_EnableSFX", 0, 1, 0.01)
    sfxSlider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_SFXVolume"] = sfxSlider

    -- Music Volume
    local musicSlider = CreateVerticalSlider(contentFrame, "VolumeSlidersSliderMusic", "Music", "Sound_MusicVolume", "Sound_EnableMusic", 0, 1, 0.01)
    musicSlider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 2 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MusicVolume"] = musicSlider

    -- Ambience Volume
    local ambienceSlider = CreateVerticalSlider(contentFrame, "VolumeSlidersSliderAmbience", "Ambience", "Sound_AmbienceVolume", "Sound_EnableAmbience", 0, 1, 0.01)
    ambienceSlider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 3 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_AmbienceVolume"] = ambienceSlider

    -- Dialog Volume
    local dialogSlider = CreateVerticalSlider(contentFrame, "VolumeSlidersSliderDialogue", "Dialog", "Sound_DialogVolume", "Sound_EnableDialog", 0, 1, 0.01)
    dialogSlider:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 4 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_DialogVolume"] = dialogSlider

    ---------------------------------------------------------------------------
    -- Bottom Row Controls
    ---------------------------------------------------------------------------

    -- "Sound at Character" checkbox — toggles whether the listener position
    -- is at the player's character or at the camera.
    VS.characterCheckbox = CreateCheckbox(contentFrame, "VolumeSlidersCheckChar", "Sound at Character", function(checked)
        if checked then
            SetCVar("Sound_ListenerAtCharacter", 1)
        else
            SetCVar("Sound_ListenerAtCharacter", 0)
        end
    end, function()
        return GetCVar("Sound_ListenerAtCharacter") == "1"
    end)
    VS.characterCheckbox:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", CONTENT_PADDING_X, CONTENT_PADDING_BOTTOM + 10)

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
    local outputLabel = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    outputLabel:SetPoint("LEFT", VS.characterCheckbox.labelText, "RIGHT", 20, 0)
    outputLabel:SetText("Output:")
    outputLabel:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

    -- Dropdown button
    local dropdown = CreateFrame("Button", "VolumeSlidersOutputDropdown", contentFrame)
    dropdown:SetSize(140, 36)
    dropdown:SetPoint("LEFT", outputLabel, "RIGHT", 5, 0)

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
    ddText:SetWordWrap(true)
    ddText:SetMaxLines(2)
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
    list:SetFrameLevel(vsContainer:GetFrameLevel() + 10)
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
                    VolumeSlidersMMDB.deviceVolumes = VolumeSlidersMMDB.deviceVolumes or {}
                    
                    -- Save the current master volume under the active device's name before swapping
                    local oldIndex = tonumber(GetCVar("Sound_OutputDriverIndex")) or 0
                    local oldName = Sound_GameSystem_GetOutputDriverNameByIndex(oldIndex) or "System Default"
                    local currentMaster = GetCVar("Sound_MasterVolume")
                    VolumeSlidersMMDB.deviceVolumes[oldName] = currentMaster

                    -- Apply the selected output device and restart the sound system
                    SetCVar("Sound_OutputDriverIndex", i)
                    Sound_GameSystem_RestartSoundSystem()
                    
                    -- Decide the target volume for the newly selected device
                    local targetVol = VolumeSlidersMMDB.deviceVolumes[name] or currentMaster
                    
                    -- WoW's sound system restart takes an unpredictable amount of time and will
                    -- forcefully reset the CVar to 1.0 when it finishes.
                    -- Use a ticker to forcefully apply the volume continuously for 3 seconds to guarantee it overrides the engine reset.
                    local enforceCount = 0
                    if dropdown.volTicker then dropdown.volTicker:Cancel() end
                    dropdown.volTicker = C_Timer.NewTicker(0.5, function()
                        SetCVar("Sound_MasterVolume", targetVol)
                        enforceCount = enforceCount + 1
                        if enforceCount >= 6 then
                            dropdown.volTicker:Cancel()
                        end
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
            list:SetWidth(math.max(requiredWidth, minWidth))
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
    -- Bottom Row Centering
    ---------------------------------------------------------------------------
    -- Defer layout calculation slightly to ensure font strings have initialized
    -- their widths, then re-anchor the character checkbox to dynamically center
    -- the entire bottom row within the content width.
    C_Timer.After(0.01, function()
        if VS.characterCheckbox and VS.characterCheckbox.labelText and outputLabel and dropdown then
            local checkWidth = VS.characterCheckbox:GetWidth()
            local checkLabelWidth = VS.characterCheckbox.labelText:GetStringWidth()
            local outputLabelWidth = outputLabel:GetStringWidth()
            local dropWidth = dropdown:GetWidth()

            -- Sum of all elements and manual horizontal spacing gaps
            local totalRowWidth = checkWidth + 4 + checkLabelWidth + 20 + outputLabelWidth + 5 + dropWidth
            local offsetX = (CONTENT_WIDTH - totalRowWidth) / 2

            -- Shifted down 7 pixels to accommodate the taller multi-line dropdown button so it doesn't crowd the sliders
            VS.characterCheckbox:SetPoint("BOTTOMLEFT", contentFrame, "BOTTOMLEFT", offsetX, CONTENT_PADDING_BOTTOM + 3)
        end
    end)

    -- Register combat lockdown event and start hidden.
    vsContainer:RegisterEvent("PLAYER_REGEN_DISABLED")
    vsContainer:Hide()

    return vsContainer
end

-------------------------------------------------------------------------------
-- Reposition
--
-- Anchors the popup panel relative to the broker/minimap frame that was
-- clicked.  If the icon is in the top half of the screen, the panel opens
-- below it; if in the bottom half, it opens above.
-------------------------------------------------------------------------------
function VS:Reposition()
    local frame = VS.brokerFrame
    if not frame then return end

    vsContainer:ClearAllPoints()
    local showBelow = select(2, frame:GetCenter()) > UIParent:GetHeight()/2

    if showBelow then
        vsContainer:SetPoint("TOP", frame, "BOTTOM", 0, 0)
    else
        vsContainer:SetPoint("BOTTOM", frame, "TOP", 0, 0)
    end
end

-----------------------------------------
-- LibDataBroker (LDB) Data Object
--
-- This is the core integration point for minimap icons and data-broker
-- display addons (e.g., Titan Panel, ChocolateBar).  It defines what
-- icon to show, what text to display, and how to respond to clicks.
-----------------------------------------
VS.VolumeSlidersObject = LDB:NewDataObject("Volume Sliders", {
    type = "launcher",
    text = VS:GetVolumeText(),
    icon = "Interface\\AddOns\\VolumeSliders\\Media\\speaker_on.png",
    iconCoords = {0, 1, 0, 1},
    iconR = 1, iconG = 1, iconB = 1,

    --- Left-click: toggle the slider panel.
    --- Right-click: toggle master mute.
    OnClick = function(clickedFrame, button)
        if button == "LeftButton" then
             if not vsContainer then
                 VS:CreateOptionsFrame()
             end

             if vsContainer:IsShown() then
                 vsContainer:Hide()
             else
                 vsContainer:Show()
                 VS.brokerFrame = clickedFrame
                 VS:Reposition()
             end

            VS:SetScroll()

        elseif button == "RightButton" then
            VS:VolumeSliders_ToggleMute()
        end
    end,

    --- Tooltip: brief usage instructions with green action text.
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Volume Sliders", 1, 1, 1)
        tooltip:AddLine("|cff00ff00Left click|r to open slider panel")
        tooltip:AddLine("|cff00ff00Right click|r to mute/unmute all audio")
    end,
})

--- Attach a mouse-wheel handler to the broker frame so the user can scroll
--- to adjust master volume directly from the icon.  Only hooks once per frame.
function VS:SetScroll()
    if VS.brokerScrollSet then return end
    if VS.brokerFrame then
        VS.brokerFrame:SetScript("OnMouseWheel", function(self, delta)
            VS:AdjustVolume(delta)
        end)
        VS.brokerScrollSet = true
    end
end

-----------------------------------------
-- Minimap Icon Texture Helpers
-----------------------------------------

--- Update a texture to reflect the current mute state.
--- Muted:   speaker_off icon, desaturated, tinted red.
--- Unmuted: speaker_on icon, normal colors.
function VS:UpdateVolumeTexture(texture)
    if GetCVar("Sound_EnableAllSound") == "0" then
        VS.VolumeSlidersObject.icon = "Interface\\AddOns\\VolumeSliders\\Media\\speaker_off.png"
        texture:SetTexture("Interface\\AddOns\\VolumeSliders\\Media\\speaker_off.png")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetDesaturated(true)
        texture:SetVertexColor(1, 0, 0)
    else
        VS.VolumeSlidersObject.icon = "Interface\\AddOns\\VolumeSliders\\Media\\speaker_on.png"
        texture:SetTexture("Interface\\AddOns\\VolumeSliders\\Media\\speaker_on.png")
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1)
    end
end

--- Locate the minimap button created by LibDBIcon and update its icon
--- texture to reflect the current mute state.
function VS:UpdateMiniMapVolumeIcon()
    local minimapButton = VS.minimapButton
    if minimapButton then
        local texture = minimapButton.icon
        if texture then
            VS:UpdateVolumeTexture(texture)
        end
    end
end

-----------------------------------------
-- External CVar Change Listener
--
-- When another addon or the Blizzard Sound settings panel changes the
-- master volume, this event fires so we can keep our broker text and
-- slider position in sync.
-----------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, cvarName, value)
    if cvarName == "Sound_MasterVolume" then
        -- Update the broker display text.
        VS.VolumeSlidersObject.text = VS:GetVolumeText()

        -- Sync the Master slider if the panel is open.
        if VS.sliders and VS.sliders["Sound_MasterVolume"] then
             local val = tonumber(value) or 0
             VS.sliders["Sound_MasterVolume"]:SetValue(1 - val)
             VS.sliders["Sound_MasterVolume"].valueText:SetText(math.floor(val * 100) .. "%")
        end
    end
end)

-----------------------------------------
-- Addon Initialization (PLAYER_LOGIN)
--
-- Fires once, after the player has entered the world and all addons are loaded.
-----------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    -- Register the minimap icon via LibDBIcon.
    LDBIcon:Register("Volume Sliders", VS.VolumeSlidersObject, VolumeSlidersMMDB)

    -- LibDBIcon names the minimap button "LibDBIcon10_<name>".
    local minimapButton = _G["LibDBIcon10_Volume Sliders"]
    if minimapButton then
        minimapButton:EnableMouseWheel(true)
        minimapButton:EnableMouse(true)
        minimapButton:RegisterForClicks("AnyUp")

        -- Scroll on the minimap icon to adjust master volume.
        minimapButton:SetScript("OnMouseWheel", function(self, delta)
            VS:AdjustVolume(delta)
        end)

        -- After any click on the minimap button, refresh the icon texture
        -- in case the mute state changed.
        minimapButton:HookScript("OnMouseUp", function(self)
            VS:UpdateMiniMapVolumeIcon()
        end)
    end
    VS.minimapButton = minimapButton

    -- Update the minimap icon to the correct mute state and pre-create the
    -- options frame so it's ready for instant display.
    VS:UpdateMiniMapVolumeIcon()
    VS:CreateOptionsFrame()

    -- This event only needs to fire once.
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-----------------------------------------
-- Addon Compartment Integration
--
-- The Addon Compartment is the built-in dropdown accessible from the minimap
-- button cluster (added in Dragonflight).  The global function name is
-- declared in the TOC via ## AddonCompartmentFunc.
-----------------------------------------

--- Global click handler for the Addon Compartment entry.
--- Toggles the slider panel visibility.
function VolumeSliders_OnAddonCompartmentClick(_addonName, menuButtonFrame)
    if not vsContainer then
        VS:CreateOptionsFrame()
    end

    if vsContainer:IsShown() then
        vsContainer:Hide()
    else
        vsContainer:Show()
    end
end
