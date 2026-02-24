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
-- Version: 1.3.4
-- License: All Rights Reserved (Non-commercial use permitted)
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
    sliderHeight = 150, -- Default vertical height
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
local SLIDER_HEIGHT = 160

-- Total number of volume channel sliders displayed.
local NUM_SLIDERS = 6

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



-- Lookup table mapping CVar name → slider widget.  Populated during
-- CreateOptionsFrame() and used to sync slider positions when CVars change
-- externally (e.g., via the Blizzard Sound settings panel).
VS.sliders = {}

local CVAR_TO_VAR = {
    ["Sound_MasterVolume"] = "showMaster",
    ["Sound_SFXVolume"] = "showSFX",
    ["Sound_MusicVolume"] = "showMusic",
    ["Sound_AmbienceVolume"] = "showAmbience",
    ["Sound_DialogVolume"] = "showDialog",
    ["Sound_EncounterWarningsVolume"] = "showWarnings",
}

local DEFAULT_CVAR_ORDER = {
    "Sound_MasterVolume",
    "Sound_SFXVolume",
    "Sound_MusicVolume",
    "Sound_AmbienceVolume",
    "Sound_DialogVolume",
    "Sound_EncounterWarningsVolume"
}

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
    slider:SetHeight(VolumeSlidersMMDB.sliderHeight or SLIDER_HEIGHT)
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
    slider.trackTop = trackTop

    -- Bottom endcap (originally the horizontal "Right" end piece).
    local trackBottom = slider:CreateTexture(nil, "BACKGROUND")
    SetAtlasRotated90CW(trackBottom, "Minimal_SliderBar_Right")
    trackBottom:SetPoint("BOTTOM", slider, "BOTTOM", 0, 0)
    slider.trackBottom = trackBottom

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
    slider.trackMiddle = trackMiddle

    -- Diamond-shaped thumb (uses the gold diamond from Boss Abilities).
    -- Future Options Reference:
    --   Old silver knob atlas: "Minimal_SliderBar_Button"
    local thumb = slider:CreateTexture(name .. "Thumb", "OVERLAY")
    thumb:SetAtlas("combattimeline-pip", true)
    slider.thumb = thumb
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
    slider.upTex = upTex
    upBtn:SetPoint("BOTTOM", slider, "TOP", 0, 4)
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
    slider.downTex = downTex
    downBtn:SetPoint("TOP", slider, "BOTTOM", 0, -4)
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
    slider.highLabel:SetPoint("BOTTOM", slider, "TOP", 0, 26)
    slider.highLabel:SetText("High")

    slider.lowLabel = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slider.lowLabel:SetPoint("TOP", slider, "BOTTOM", 0, -26)
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
-- Appearance & Settings Customization
-------------------------------------------------------------------------------

function VS:UpdateSliderLayout(slider)
    local db = VolumeSlidersMMDB

    -- Show/hide track textures
    if db.showSlider then
        slider:SetHeight(db.sliderHeight or 160)
        slider:EnableMouse(true)
        slider.trackTop:SetAlpha(1)
        slider.trackMiddle:SetAlpha(1)
        slider.trackBottom:SetAlpha(1)
        if slider.thumb then slider.thumb:SetAlpha(1) end
    else
        slider:SetHeight(0.001)
        slider:EnableMouse(false)
        slider.trackTop:SetAlpha(0)
        slider.trackMiddle:SetAlpha(0)
        slider.trackBottom:SetAlpha(0)
        if slider.thumb then slider.thumb:SetAlpha(0) end
    end

    -- Toggle visibility flags
    if slider.label then slider.label:SetShown(db.showTitle) end
    if slider.valueText then slider.valueText:SetShown(db.showValue) end
    if slider.highLabel then slider.highLabel:SetShown(db.showHigh) end
    if slider.upBtn then slider.upBtn:SetShown(db.showUpArrow) end
    
    if slider.downBtn then slider.downBtn:SetShown(db.showDownArrow) end
    if slider.lowLabel then slider.lowLabel:SetShown(db.showLow) end
    if slider.muteCheck then slider.muteCheck:SetShown(db.showMute) end
    if slider.muteCheck and slider.muteCheck.muteLabel then slider.muteCheck.muteLabel:SetShown(db.showMute) end

    -- Top Half Anchoring (Building Upwards)
    local prevTop = slider
    local prevTopPoint = "TOP"
    
    local function AnchorTop(element, pad, overrideTop)
        element:ClearAllPoints()
        element:SetPoint("BOTTOM", prevTop, prevTopPoint, 0, pad)
        prevTop = element
        prevTopPoint = overrideTop or "TOP"
    end

    if db.showUpArrow and slider.upBtn then
        AnchorTop(slider.upBtn, 4)
    end
    if db.showHigh and slider.highLabel then
        local pad = 4
        if not db.showUpArrow and db.showSlider then pad = 8 end
        AnchorTop(slider.highLabel, pad)
    end
    if db.showValue and slider.valueText then
        AnchorTop(slider.valueText, 10)
    end
    if db.showTitle and slider.label then
        AnchorTop(slider.label, 4)
    end

    -- Bottom Half Anchoring (Building Downwards)
    local prevBottom = slider
    local prevBottomPoint = "BOTTOM"

    local function AnchorBottom(element, pad, overrideBottom)
        element:ClearAllPoints()
        element:SetPoint("TOP", prevBottom, prevBottomPoint, 0, -pad)
        prevBottom = element
        prevBottomPoint = overrideBottom or "BOTTOM"
    end

    if db.showDownArrow and slider.downBtn then
        AnchorBottom(slider.downBtn, 4)
    end
    if db.showLow and slider.lowLabel then
        local pad = 4
        if not db.showDownArrow and db.showSlider then pad = 8 end
        AnchorBottom(slider.lowLabel, pad)
    end
    if db.showMute and slider.muteCheck then
        AnchorBottom(slider.muteCheck, 8)
        
        -- Re-link Mute text below the checkbox
        if slider.muteCheck.muteLabel then
            slider.muteCheck.muteLabel:ClearAllPoints()
            slider.muteCheck.muteLabel:SetPoint("TOP", slider.muteCheck, "BOTTOM", 0, -2)
        end
    end
end

--- Calculates the vertical pixels required above and below a slider track
--- based on the currently visible components.
function VS:GetSliderHeightExtent()
    local db = VolumeSlidersMMDB
    local hTop = 0
    local hBottom = 0

    if db.showUpArrow then hTop = hTop + 20 + 4 end
    if db.showHigh then
        local pad = db.showUpArrow and 4 or (db.showSlider and 8 or 0)
        hTop = hTop + 15 + pad
    end
    if db.showValue then hTop = hTop + 15 + 10 end
    if db.showTitle then hTop = hTop + 15 + 4 end

    if db.showDownArrow then hBottom = hBottom + 20 + 4 end
    if db.showLow then
        local pad = db.showDownArrow and 4 or (db.showSlider and 8 or 0)
        hBottom = hBottom + 15 + pad
    end
    if db.showMute then hBottom = hBottom + 26 + 8 + 15 + 2 end -- Check (26) + Pad (8) + Label (15) + Gap (2)

    local hTrack = db.showSlider and (db.sliderHeight or 160) or 0
    return hTop, hBottom, hTrack
end

--- Retrieves stored options state and updates the appearances of all
--- active slider UI elements in bulk.
function VS:UpdateAppearance()
    local knobSelected = VolumeSlidersMMDB.knobStyle or 1
    local arrowSelected = VolumeSlidersMMDB.arrowStyle or 1
    local titleSelected = VolumeSlidersMMDB.titleColor or 1
    local valueSelected = VolumeSlidersMMDB.valueColor or 1
    local highSelected = VolumeSlidersMMDB.highColor or 2
    local lowSelected = VolumeSlidersMMDB.lowColor or 2

    -- Update main panel sliders visibility and layout
    if VS.sliders then
        for _, slider in pairs(VS.sliders) do
            VS:ApplySliderAppearance(slider, knobSelected, arrowSelected, titleSelected, valueSelected, highSelected, lowSelected)
        end
    end

    -- Update the preview slider if it exists
    if VS.previewSlider then
        VS:ApplySliderAppearance(VS.previewSlider, knobSelected, arrowSelected, titleSelected, valueSelected, highSelected, lowSelected)

        -- Update preview backdrop height if it exists
        if VS.previewBackdrop then
            local hTop, hBottom, hTrack = VS:GetSliderHeightExtent()
            local totalSliderHeight = hTop + hTrack + hBottom
            -- Add some padding (e.g. 60 pixels total for top/bottom margins)
            -- and account for the 0.9 scale
            local backdropHeight = (totalSliderHeight * 0.9) + 60
            VS.previewBackdrop:SetHeight(math.max(150, backdropHeight))
        end
    end

    -- Dynamically resize the main popup frame if it exists
    if VS.container then
        local hTop, hBottom, hTrack = VS:GetSliderHeightExtent()

        -- Header: Padding (15) + Instruction (15) + Gap (10)
        local headerHeight = 40
        -- Footer height calculation based on visibility
        local footerHeight = 0
        local db = VolumeSlidersMMDB
        if db.showCharacter or db.showBackground or db.showOutput then
            footerHeight = 15 -- Initial top gap
            if db.showCharacter and db.showBackground then
                footerHeight = footerHeight + 55 -- Stacked checkboxes height
            else
                footerHeight = footerHeight + 36 -- Single row height (checkbox or dropdown)
            end
            footerHeight = footerHeight + 15 -- Bottom padding
        end

        local contentHeight = headerHeight + hTop + hTrack + hBottom + footerHeight
        local frameHeight = contentHeight + TEMPLATE_CONTENT_OFFSET_TOP + TEMPLATE_CONTENT_OFFSET_BOTTOM

        VS.container:SetHeight(frameHeight)

        -- Adjust startY so the sliders are pushed up when labels are hidden
        local startY = -(headerHeight + hTop)

        -- Re-anchor all active sliders to the new dynamic startY
        if VS.sliders then
            local startX = CONTENT_PADDING_X
            local i = 0

            local cvarOrder = VolumeSlidersMMDB.sliderOrder or DEFAULT_CVAR_ORDER

            for _, cvar in ipairs(cvarOrder) do
                local slider = VS.sliders[cvar]
                local var = CVAR_TO_VAR[cvar]
                if slider and var then
                    if not VolumeSlidersMMDB[var] then
                        slider:Hide()
                    else
                        slider:Show()
                        local offsetX = startX + (i * (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING)) + (SLIDER_COLUMN_WIDTH / 2) - 8
                        slider:ClearAllPoints()
                        slider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", offsetX, startY)
                        i = i + 1
                    end
                end
            end
            
            -- Dynamically adjust frame width based on visible sliders
            local visibleWidth = (CONTENT_PADDING_X * 2)
                + (i * SLIDER_COLUMN_WIDTH)
                + ((i - 1) * SLIDER_COLUMN_SPACING)
            local frameWidth = visibleWidth + TEMPLATE_CONTENT_OFFSET_LEFT + TEMPLATE_CONTENT_OFFSET_RIGHT
            VS.container:SetWidth(frameWidth)
        end
        
        -- Update footer elements visibility and layout
        VS:UpdateFooterLayout()
    end
end

function VS:UpdateFooterLayout()
    if not VS.container then return end
    
    local charCheck = VS.characterCheckbox
    local bgCheck = VS.backgroundCheckbox
    local outputLabel = VS.outputLabel
    local dropdown = VS.outputDropdown

    if charCheck and charCheck.labelText and bgCheck and outputLabel and dropdown then
        local db = VolumeSlidersMMDB
        
        -- Update visibility
        charCheck:SetShown(db.showCharacter)
        charCheck.labelText:SetShown(db.showCharacter)
        bgCheck:SetShown(db.showBackground)
        bgCheck.labelText:SetShown(db.showBackground)
        outputLabel:SetShown(db.showOutput)
        dropdown:SetShown(db.showOutput)
        
        local charWidth = 0
        if db.showCharacter then
            charWidth = charCheck:GetWidth() + 4 + charCheck.labelText:GetStringWidth()
        end
        
        local bgWidth = 0
        if db.showBackground then
            bgWidth = bgCheck:GetWidth() + 4 + bgCheck.labelText:GetStringWidth()
        end
        
        local stackWidth = math.max(charWidth, bgWidth)
        
        local outputWidth = 0
        if db.showOutput then
            outputWidth = outputLabel:GetStringWidth() + 5 + dropdown:GetWidth()
        end

        local totalRowWidth
        local offsetX
        local sideBySide = false
        
        -- Gap between stacked column and output selector
        local gap = (stackWidth > 0 and outputWidth > 0) and 25 or 0

        -- Check if we should switch to side-by-side for the two toggles when output is hidden
        if not db.showOutput and db.showCharacter and db.showBackground then
            local combinedWidth = charWidth + 15 + bgWidth -- 15px gap between them
            local availableWidth = VS.container:GetWidth() - (TEMPLATE_CONTENT_OFFSET_LEFT + TEMPLATE_CONTENT_OFFSET_RIGHT) - (CONTENT_PADDING_X * 2)
            if combinedWidth <= availableWidth then
                sideBySide = true
                totalRowWidth = combinedWidth
            else
                totalRowWidth = stackWidth
            end
        else
            totalRowWidth = stackWidth + gap + outputWidth
        end

        offsetX = (VS.container:GetWidth() - (TEMPLATE_CONTENT_OFFSET_LEFT + TEMPLATE_CONTENT_OFFSET_RIGHT) - totalRowWidth) / 2

        -- Positioning logic
        charCheck:ClearAllPoints()
        bgCheck:ClearAllPoints()
        outputLabel:ClearAllPoints()
        dropdown:ClearAllPoints()

        if sideBySide then
            -- Position horizontally side-by-side
            charCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, CONTENT_PADDING_BOTTOM + 15)
            bgCheck:SetPoint("LEFT", charCheck.labelText, "RIGHT", 15, 0)
        elseif db.showCharacter and db.showBackground then
            -- Stacked vertically
            charCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, CONTENT_PADDING_BOTTOM + 30)
            bgCheck:SetPoint("TOPLEFT", charCheck, "BOTTOMLEFT", 0, -2)
            
            if db.showOutput then
                outputLabel:SetPoint("LEFT", VS.contentFrame, "BOTTOMLEFT", offsetX + stackWidth + gap, CONTENT_PADDING_BOTTOM + 30)
            end
        elseif db.showCharacter then
            charCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, CONTENT_PADDING_BOTTOM + 15)
            if db.showOutput then
                outputLabel:SetPoint("LEFT", VS.contentFrame, "BOTTOMLEFT", offsetX + stackWidth + gap, CONTENT_PADDING_BOTTOM + 15)
            end
        elseif db.showBackground then
            bgCheck:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, CONTENT_PADDING_BOTTOM + 15)
            if db.showOutput then
                outputLabel:SetPoint("LEFT", VS.contentFrame, "BOTTOMLEFT", offsetX + stackWidth + gap, CONTENT_PADDING_BOTTOM + 15)
            end
        elseif db.showOutput then
            outputLabel:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", offsetX, CONTENT_PADDING_BOTTOM + 15)
        end
        
        if db.showOutput then
            dropdown:SetPoint("LEFT", outputLabel, "RIGHT", 5, 0)
        end
    end
end

function VS:ApplySliderAppearance(slider, knobSelected, arrowSelected, titleSelected, valueSelected, highSelected, lowSelected)
    -- Update Knob
    if knobSelected == 1 then
        slider.thumb:SetAtlas("combattimeline-pip", true)
    elseif knobSelected == 2 then
        slider.thumb:SetAtlas("Minimal_SliderBar_Button", true)
    end

    -- Update Arrows
    -- Clear standard texture paths and specific anchors before reapplying.
    slider.upTex:SetTexture(nil)
    slider.upTex:SetTexCoord(0, 1, 0, 1) -- Reset any previous rotation
    slider.upTex:SetDesaturated(false) -- Reset any previous color filtering
    slider.upTex:ClearAllPoints()
    slider.upTex:SetPoint("CENTER", slider.upBtn, "CENTER", 0, 0)
    
    slider.downTex:SetTexture(nil)
    slider.downTex:SetTexCoord(0, 1, 0, 1) -- Reset any previous rotation
    slider.downTex:SetDesaturated(false) -- Reset any previous color filtering
    slider.downTex:ClearAllPoints()
    slider.downTex:SetPoint("CENTER", slider.downBtn, "CENTER", 0, 0)

    if arrowSelected == 1 then
        -- Zoom arrows (Plus/Minus)
        slider.upTex:SetAtlas("ui-hud-minimap-zoom-in")
        slider.upBtn:SetSize(20, 20)
        slider.upTex:SetSize(20, 20)
        
        slider.downTex:SetAtlas("ui-hud-minimap-zoom-out")
        slider.downBtn:SetSize(20, 20)
        slider.downTex:SetSize(20, 20)
    elseif arrowSelected == 2 then
        -- Gold arrows
        slider.upTex:SetAtlas("ui-hud-actionbar-pageuparrow-up")
        slider.upBtn:SetSize(17, 14)
        slider.upTex:SetSize(17, 14)

        slider.downTex:SetAtlas("ui-hud-actionbar-pagedownarrow-up")
        slider.downBtn:SetSize(17, 14)
        slider.downTex:SetSize(17, 14)
    elseif arrowSelected == 3 then
        -- Silver arrows
        slider.upBtn:SetSize(19, 11)
        SetAtlasRotated90CW(slider.upTex, "Minimal_SliderBar_Button_Left")
        
        slider.upTex:ClearAllPoints()
        slider.upTex:SetPoint("CENTER", slider.upBtn, "CENTER", 1, -1) -- Shift right to center visually

        slider.downBtn:SetSize(19, 11)
        SetAtlasRotated90CW(slider.downTex, "Minimal_SliderBar_Button_Right")
        
        slider.downTex:ClearAllPoints()
        slider.downTex:SetPoint("CENTER", slider.downBtn, "CENTER", -1, -3) -- Shift left, and shift down to stop overlapping track
    elseif arrowSelected == 4 then
        -- Silver Plus/Minus (zoom icons using desaturation)
        slider.upTex:SetAtlas("ui-hud-minimap-zoom-in")
        slider.upTex:SetDesaturated(true)
        slider.upBtn:SetSize(20, 20)
        slider.upTex:SetSize(20, 20)

        slider.downTex:SetAtlas("ui-hud-minimap-zoom-out")
        slider.downTex:SetDesaturated(true)
        slider.downBtn:SetSize(20, 20)
        slider.downTex:SetSize(20, 20)
    end

    -- Update Text Colors
    local function ApplyColor(fontString, colorType)
        if fontString then
            if colorType == 1 then
                fontString:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
            else
                fontString:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            end
        end
    end

    ApplyColor(slider.label, titleSelected)
    ApplyColor(slider.valueText, valueSelected)
    ApplyColor(slider.highLabel, highSelected)
    ApplyColor(slider.lowLabel, lowSelected)

    -- Finally, update dynamic anchoring layout
    VS:UpdateSliderLayout(slider)
end

--- Registers the native WoW Options Settings page using a Canvas Layout.
function VS:InitializeSettings()
    local categoryFrame = CreateFrame("Frame", "VolumeSlidersOptionsFrame", UIParent)
    local category, layout = Settings.RegisterCanvasLayoutCategory(categoryFrame, "Volume Sliders")

    categoryFrame:SetScript("OnShow", function(self)
        if not VS.settingsCreated then
            VS:CreateSettingsContents(self)
            VS.settingsCreated = true
        end

        -- Ensure height settings are refreshed on show
        if VS.RefreshHeightSettings then
            VS:RefreshHeightSettings()
        end
    end)

    Settings.RegisterAddOnCategory(category)
end

--- Internal function to build the actual UI elements of the settings panel.
--- This is called the first time the settings category is shown.
function VS:CreateSettingsContents(categoryFrame)

    local title = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Volume Sliders Settings")

    local desc = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Customization options for the Volume Sliders minimap popup.")
    desc:SetJustifyH("LEFT")

    ---------------------------------------------------------------------------
    -- Dropdown Menus
    ---------------------------------------------------------------------------
    local dropdownWidth = 160
    local dropdownSpacingOffset = -15 -- Reduced spacing between dropdowns

    -- Title Color Label & Dropdown
    local titleColorLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleColorLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 10, -35)
    titleColorLabel:SetText("Title Text Color")

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

    local function IsTitleSelected(value)
        return VolumeSlidersMMDB.titleColor == value
    end
    local function SetTitleSelected(value)
        VolumeSlidersMMDB.titleColor = value
        VS:UpdateAppearance()
    end

    local titleDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    titleDropdown:SetPoint("TOPLEFT", titleColorLabel, "BOTTOMLEFT", -15, -8) -- Reduced label-dropdown space
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
        return VolumeSlidersMMDB.valueColor == value
    end
    local function SetValueSelected(value)
        VolumeSlidersMMDB.valueColor = value
        VS:UpdateAppearance()
    end

    local valueDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    valueDropdown:SetPoint("TOPLEFT", valueColorLabel, "BOTTOMLEFT", -15, -8) -- Reduced label-dropdown space
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
        return VolumeSlidersMMDB.highColor == value
    end
    local function SetHighSelected(value)
        VolumeSlidersMMDB.highColor = value
        VS:UpdateAppearance()
    end

    local highDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    highDropdown:SetPoint("TOPLEFT", highColorLabel, "BOTTOMLEFT", -15, -8) -- Reduced label-dropdown space
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
        return VolumeSlidersMMDB.arrowStyle == value
    end
    local function SetArrowSelected(value)
        VolumeSlidersMMDB.arrowStyle = value
        VS:UpdateAppearance()
    end

    local arrowDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    arrowDropdown:SetPoint("TOPLEFT", arrowLabel, "BOTTOMLEFT", -15, -8) -- Reduced label-dropdown space
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
        return VolumeSlidersMMDB.knobStyle == value
    end
    local function SetKnobSelected(value)
        VolumeSlidersMMDB.knobStyle = value
        VS:UpdateAppearance()
    end

    local knobDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    knobDropdown:SetPoint("TOPLEFT", knobLabel, "BOTTOMLEFT", -15, -8) -- Reduced label-dropdown space
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
        return VolumeSlidersMMDB.lowColor == value
    end
    local function SetLowSelected(value)
        VolumeSlidersMMDB.lowColor = value
        VS:UpdateAppearance()
    end

    local lowDropdown = CreateFrame("DropdownButton", nil, categoryFrame, "WowStyle1DropdownTemplate")
    lowDropdown:SetPoint("TOPLEFT", lowColorLabel, "BOTTOMLEFT", -15, -8) -- Reduced label-dropdown space
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
    previewLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 185, -35)
    previewLabel:SetText("Live Preview:")

    -- Place the preview container in the 2nd column
    VS.previewBackdrop = CreateFrame("Frame", nil, categoryFrame, "BackdropTemplate")
    VS.previewBackdrop:SetPoint("TOP", previewLabel, "BOTTOM", 0, -10)
    VS.previewBackdrop:SetSize(120, 360)
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
    VS.previewSlider = CreateVerticalSlider(categoryFrame, "VolumeSlidersPreviewSlider", "Master", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01)
    VS.previewSlider:SetParent(previewBackdrop)
    VS.previewSlider:ClearAllPoints()
    VS.previewSlider:SetPoint("CENTER", previewBackdrop, "CENTER", 0, 0)
    VS.previewSlider:SetScale(0.9)
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
    -- 3rd Column: Visibility Checkboxes
    ---------------------------------------------------------------------------
    local visibilityLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visibilityLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 325, -35)
    visibilityLabel:SetText("Element Visibility")

    local checkboxes = {
        { name = "Title", var = "showTitle", tooltip = "Show or hide the channel name (e.g., 'Master') above each slider." },
        { name = "Value (%)", var = "showValue", tooltip = "Show or hide the volume percentage text above each slider." },
        { name = "High Label", var = "showHigh", tooltip = "Show or hide the '100%' label at the top of the slider track." },
        { name = "Up Arrow", var = "showUpArrow", tooltip = "Show or hide the button for fine-tuning volume increments." },
        { name = "Slider Track", var = "showSlider", tooltip = "Show or hide the main vertical slider bar and knob." },
        { name = "Down Arrow", var = "showDownArrow", tooltip = "Show or hide the button for fine-tuning volume decrements." },
        { name = "Low Label", var = "showLow", tooltip = "Show or hide the '0%' label at the bottom of the slider track." },
        { name = "Mute Button", var = "showMute", tooltip = "Show or hide the mute checkbox and label below each slider." },
        { name = "---Separator---", isSeparator = true },
        { name = "SBG Checkbox", var = "showBackground", tooltip = "Show or hide the 'Sound in Background' toggle in the window footer." },
        { name = "Char Checkbox", var = "showCharacter", tooltip = "Show or hide the 'Sound at Character' toggle in the window footer." },
        { name = "Output Selector", var = "showOutput", tooltip = "Show or hide the 'Output:' device selection dropdown in the window footer." },
    }

    local previousCheckbox = nil
    local checkboxOffset = 5

    for _, data in ipairs(checkboxes) do
        if data.isSeparator then
            local separator = categoryFrame:CreateTexture(nil, "ARTWORK")
            separator:SetHeight(2) -- More pronounced
            separator:SetPoint("LEFT", visibilityLabel, "LEFT", -15, 0)
            separator:SetPoint("TOP", previousCheckbox, "BOTTOM", 0, -8)
            separator:SetWidth(140) -- Constrained width
            separator:SetColorTexture(1, 1, 1, 0.4) -- Brighter
            
            -- Fix dummy anchor to align icons with items above
            local anchor = CreateFrame("Frame", nil, categoryFrame)
            anchor:SetSize(1, 1)
            anchor:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 10, -5)
            
            previousCheckbox = anchor
            checkboxOffset = -10
        else
            local checkbox = CreateFrame("CheckButton", nil, categoryFrame, "UICheckButtonTemplate")
            if previousCheckbox then
                checkbox:SetPoint("TOPLEFT", previousCheckbox, "BOTTOMLEFT", 0, checkboxOffset or 5)
            else
                checkbox:SetPoint("TOPLEFT", visibilityLabel, "BOTTOMLEFT", -5, -5)
            end
            checkboxOffset = 5
            
            checkbox.text:SetText(data.name)
            checkbox:SetChecked(VolumeSlidersMMDB[data.var])
            
            checkbox:SetScript("OnClick", function(self)
                VolumeSlidersMMDB[data.var] = self:GetChecked()
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
    end

    ---------------------------------------------------------------------------
    -- 4th Column: Channel Visibility
    ---------------------------------------------------------------------------
    local channelLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 475, -35)
    channelLabel:SetText("Channel Visibility")

    local channelSubLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    channelSubLabel:SetPoint("TOP", channelLabel, "BOTTOM", 0, -2)
    channelSubLabel:SetText("(Drag to Reorder)")
    channelSubLabel:SetAlpha(0.6)

    local channelMap = {
        ["Sound_MasterVolume"] = { name = "Master Slider", var = "showMaster", tooltip = "Show or hide the Master volume slider." },
        ["Sound_SFXVolume"] = { name = "SFX Slider", var = "showSFX", tooltip = "Show or hide the Sound Effects volume slider." },
        ["Sound_MusicVolume"] = { name = "Music Slider", var = "showMusic", tooltip = "Show or hide the Music volume slider." },
        ["Sound_AmbienceVolume"] = { name = "Ambience Slider", var = "showAmbience", tooltip = "Show or hide the Ambience volume slider." },
        ["Sound_DialogVolume"] = { name = "Dialog Slider", var = "showDialog", tooltip = "Show or hide the Dialog volume slider." },
        ["Sound_EncounterWarningsVolume"] = { name = "Warnings Slider", var = "showWarnings", tooltip = "Show or hide the dedicated slider for Encounter Warnings (combat alerts)." },
    }

    local scrollBox = CreateFrame("Frame", nil, categoryFrame, "WowScrollBoxList")
    scrollBox:SetSize(170, 230)
    scrollBox:SetPoint("TOPLEFT", channelSubLabel, "BOTTOMLEFT", -5, -8) -- Anchor to the new sublabel

    local dragBehavior -- Forward declare for access in RowInitializer

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

            local drag = frame:CreateTexture(nil, "ARTWORK")
            drag:SetAtlas("ReagentWizards-ReagentRow-Grabber")
            drag:SetSize(12, 18)
            drag:SetPoint("LEFT", 6, 0)
            frame.drag = drag

            local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            checkbox:SetPoint("LEFT", drag, "RIGHT", 4, 0)
            checkbox:SetSize(24, 24)
            frame.checkbox = checkbox

            frame.initialized = true
        end

        frame.checkbox.text:SetText(data.name)
        frame.checkbox:SetChecked(VolumeSlidersMMDB[data.var])
        frame.checkbox:SetScript("OnClick", function(self)
            VolumeSlidersMMDB[data.var] = self:GetChecked()
            VS:UpdateAppearance()
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
        wipe(VolumeSlidersMMDB.sliderOrder)
        for _, cvar in dp:EnumerateEntireRange() do
            table.insert(VolumeSlidersMMDB.sliderOrder, cvar)
        end
        VS:UpdateAppearance()
    end)

    local function RefreshDataProvider()
        local dataProvider = CreateDataProvider()
        for _, cvar in ipairs(VolumeSlidersMMDB.sliderOrder) do
            dataProvider:Insert(cvar)
        end
        scrollBox:SetDataProvider(dataProvider)
    end

    RefreshDataProvider()

    ---------------------------------------------------------------------------
    -- Slider Height Setting (Text Entry)
    ---------------------------------------------------------------------------
    if VolumeSlidersMMDB.sliderHeight == nil then
        VolumeSlidersMMDB.sliderHeight = 150
    end

    local heightLabel = categoryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", lowDropdown, "BOTTOMLEFT", 15, -25)
    heightLabel:SetText("Slider Height (100-250)")

    local heightInput = CreateFrame("EditBox", "VolumeSlidersHeightInput", categoryFrame, "InputBoxTemplate")
    heightInput:SetSize(60, 20)
    heightInput:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 10, -10)
    heightInput:SetAutoFocus(false)
    heightInput:SetNumeric(true)
    heightInput:SetMaxLetters(3)
    heightInput:SetFontObject("GameFontHighlight")
    heightInput:SetText(tostring(VolumeSlidersMMDB.sliderHeight or 150))

    local function UpdateHeight(value)
        local num = tonumber(value)
        if num and num >= 100 and num <= 250 then
            VolumeSlidersMMDB.sliderHeight = num
            VS:UpdateAppearance()
        end
    end

    heightInput:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            UpdateHeight(self:GetText())
        end
    end)
    heightInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    heightInput:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(VolumeSlidersMMDB.sliderHeight or 150))
        self:ClearFocus()
    end)

    -- Ensure the text field is always populated with the current value when the settings page is opened.
    -- We use a significant delay (0.2s) because Blizzard's settings menu layout
    -- can be extremely aggressive in clearing fields during initial construction.
    function VS:RefreshHeightSettings()
        if heightInput then
            local val = VolumeSlidersMMDB and VolumeSlidersMMDB.sliderHeight or 150
            heightInput:SetText(tostring(val))
            heightInput:SetCursorPosition(0)
            -- print("|cff00ff00Volume Sliders:|r Height settings refreshed to " .. tostring(val))
        end
    end

    categoryFrame:HookScript("OnShow", function()
        C_Timer.After(0.1, function() VS:RefreshHeightSettings() end)
    end)

    -- Pre-warm the EditBox immediately after creation
    VS:RefreshHeightSettings()

    AddTooltip(heightInput, "Enter a vertical height for the sliders in pixels. Minimum 100, Maximum 250. Changes apply in real-time.")

    -- Sync preview appearance to current settings.
    VS:UpdateAppearance()
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
    if VS.container then return VS.container end

    -- Create the popup using the modern settings frame template.
    VS.container = CreateFrame("Frame", "VolumeSlidersFrame", UIParent, "SettingsFrameTemplate")
    VS.container:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
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

    -- Replace the template's default light background with a darker one
    -- for better contrast against the volume controls.
    if VS.container.Bg then VS.container.Bg:Hide() end
    local newBg = VS.container:CreateTexture(nil, "BACKGROUND", nil, -1)
    newBg:SetPoint("TOPLEFT", VS.container, "TOPLEFT", TEMPLATE_CONTENT_OFFSET_LEFT, -TEMPLATE_CONTENT_OFFSET_TOP)
    newBg:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", -TEMPLATE_CONTENT_OFFSET_RIGHT, TEMPLATE_CONTENT_OFFSET_BOTTOM)
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

        -- Refresh the "Sound in Background" checkbox.
        if VS.backgroundCheckbox then
             VS.backgroundCheckbox:SetChecked(GetCVar("Sound_EnableSoundWhenGameIsInBG") == "1")
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

    VS.container:SetScript("OnHide", function(self)
        -- Stop listening for outside clicks when the panel is closed.
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end)

    ---------------------------------------------------------------------------
    -- Content Frame (inside the NineSlice border insets)
    ---------------------------------------------------------------------------
    VS.contentFrame = CreateFrame("Frame", "VolumeSlidersContentFrame", VS.container)
    VS.contentFrame:SetPoint("TOPLEFT", VS.container, "TOPLEFT", TEMPLATE_CONTENT_OFFSET_LEFT, -TEMPLATE_CONTENT_OFFSET_TOP)
    VS.contentFrame:SetPoint("BOTTOMRIGHT", VS.container, "BOTTOMRIGHT", -TEMPLATE_CONTENT_OFFSET_RIGHT, TEMPLATE_CONTENT_OFFSET_BOTTOM)

    -- Instruction text displayed at the top of the panel.
    local instruction = VS.contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instruction:SetPoint("TOP", VS.contentFrame, "TOP", 0, -CONTENT_PADDING_TOP)
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
    local masterSlider = CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderMaster", "Master", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01)
    masterSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MasterVolume"] = masterSlider

    -- Effects Volume
    local sfxSlider = CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderSFX", "Effects", "Sound_SFXVolume", "Sound_EnableSFX", 0, 1, 0.01)
    sfxSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_SFXVolume"] = sfxSlider

    -- Music Volume
    local musicSlider = CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderMusic", "Music", "Sound_MusicVolume", "Sound_EnableMusic", 0, 1, 0.01)
    musicSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 2 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_MusicVolume"] = musicSlider

    -- Ambience Volume
    local ambienceSlider = CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderAmbience", "Ambience", "Sound_AmbienceVolume", "Sound_EnableAmbience", 0, 1, 0.01)
    ambienceSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 3 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_AmbienceVolume"] = ambienceSlider

    -- Dialog Volume
    local dialogSlider = CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderDialogue", "Dialog", "Sound_DialogVolume", "Sound_EnableDialog", 0, 1, 0.01)
    dialogSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 4 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_DialogVolume"] = dialogSlider

    -- Warnings Volume (Gameplay Sound Effects)
    local warningsSlider = CreateVerticalSlider(VS.contentFrame, "VolumeSlidersSliderWarnings", "Warnings", "Sound_EncounterWarningsVolume", "Sound_EnableEncounterWarningsSounds", 0, 1, 0.01)
    warningsSlider:SetPoint("TOPLEFT", VS.contentFrame, "TOPLEFT", startX + (SLIDER_COLUMN_WIDTH + SLIDER_COLUMN_SPACING) * 5 + (SLIDER_COLUMN_WIDTH / 2) - 8, startY)
    VS.sliders["Sound_EncounterWarningsVolume"] = warningsSlider

    ---------------------------------------------------------------------------
    -- Bottom Row Controls
    ---------------------------------------------------------------------------

    -- "Sound at Character" checkbox — toggles whether the listener position
    -- is at the player's character or at the camera.
    VS.characterCheckbox = CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckChar", "Sound at Character", function(checked)
        if checked then
            SetCVar("Sound_ListenerAtCharacter", 1)
        else
            SetCVar("Sound_ListenerAtCharacter", 0)
        end
    end, function()
        return GetCVar("Sound_ListenerAtCharacter") == "1"
    end)
    VS.characterCheckbox:SetPoint("BOTTOMLEFT", VS.contentFrame, "BOTTOMLEFT", CONTENT_PADDING_X, CONTENT_PADDING_BOTTOM + 10)

    VS.backgroundCheckbox = CreateCheckbox(VS.contentFrame, "VolumeSlidersCheckBG", "Sound in Background", function(checked)
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

    -- Dropdown button
    VS.outputDropdown = CreateFrame("Button", "VolumeSlidersOutputDropdown", VS.contentFrame)
    VS.outputDropdown:SetSize(140, 36)
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
                    -- Create a dedicated listener to catch the engine in the act.
                    if dropdown.restartListener then
                        dropdown.restartListener:UnregisterAllEvents()
                    else
                        dropdown.restartListener = CreateFrame("Frame")
                    end
                    
                    dropdown.restartListener.isRestartingAudio = true
                    dropdown.restartListener:RegisterEvent("CVAR_UPDATE")
                    dropdown.restartListener:SetScript("OnEvent", function(self, event, cvarName, value)
                        if self.isRestartingAudio and cvarName == "Sound_MasterVolume" then
                            -- The engine just reset the volume. Slam our saved volume back in.
                            SetCVar("Sound_MasterVolume", targetVol)
                            
                            -- Keep the UI in sync
                            local slider = VS.sliders and VS.sliders["Sound_MasterVolume"]
                            if slider then
                                 slider:SetValue(1 - targetVol)
                                 slider.valueText:SetText(math.floor(targetVol * 100) .. "%")
                            end
                            if VS.VolumeSlidersObject then
                                VS.VolumeSlidersObject.text = (math.floor(targetVol * 100)) .. "%"
                            end
                            
                            -- Clean up
                            self.isRestartingAudio = false
                            self:UnregisterEvent("CVAR_UPDATE")
                            if dropdown.fallbackTimer then dropdown.fallbackTimer:Cancel() end
                        end
                    end)
                    
                    -- Safety Net: If the engine behaves unexpectedly and the event never fires,
                    -- unregister after 5 seconds to avoid permanently intercepting CVAR updates.
                    if dropdown.fallbackTimer then dropdown.fallbackTimer:Cancel() end
                    dropdown.fallbackTimer = C_Timer.NewTimer(5.0, function()
                        if dropdown.restartListener and dropdown.restartListener.isRestartingAudio then
                            dropdown.restartListener.isRestartingAudio = false
                            dropdown.restartListener:UnregisterEvent("CVAR_UPDATE")
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
    local frame = VS.brokerFrame
    if not frame then return end

    if not VS.container then return end
    VS.container:ClearAllPoints()
    local showBelow = select(2, frame:GetCenter()) > UIParent:GetHeight()/2

    if showBelow then
        VS.container:SetPoint("TOP", frame, "BOTTOM", 0, 0)
    else
        VS.container:SetPoint("BOTTOM", frame, "TOP", 0, 0)
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
             if not VS.container then
                 VS:CreateOptionsFrame()
             end

             if VS.container:IsShown() then
                 VS.container:Hide()
             else
                 VS.container:Show()
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
    -- Enforce saved variable defaults here, as top-level declarations
    -- are overwritten by the disk database during ADDON_LOADED.
    VolumeSlidersMMDB.minimapPos = VolumeSlidersMMDB.minimapPos or 180
    if VolumeSlidersMMDB.hide == nil then VolumeSlidersMMDB.hide = false end
    VolumeSlidersMMDB.knobStyle = VolumeSlidersMMDB.knobStyle or 1
    VolumeSlidersMMDB.arrowStyle = VolumeSlidersMMDB.arrowStyle or 1
    VolumeSlidersMMDB.titleColor = VolumeSlidersMMDB.titleColor or 1
    VolumeSlidersMMDB.valueColor = VolumeSlidersMMDB.valueColor or 1
    VolumeSlidersMMDB.highColor = VolumeSlidersMMDB.highColor or 2
    VolumeSlidersMMDB.lowColor = VolumeSlidersMMDB.lowColor or 2
    if VolumeSlidersMMDB.showTitle == nil then VolumeSlidersMMDB.showTitle = true end
    if VolumeSlidersMMDB.showValue == nil then VolumeSlidersMMDB.showValue = true end
    if VolumeSlidersMMDB.showHigh == nil then VolumeSlidersMMDB.showHigh = true end
    if VolumeSlidersMMDB.showUpArrow == nil then VolumeSlidersMMDB.showUpArrow = true end
    if VolumeSlidersMMDB.showSlider == nil then VolumeSlidersMMDB.showSlider = true end
    if VolumeSlidersMMDB.showDownArrow == nil then VolumeSlidersMMDB.showDownArrow = true end
    if VolumeSlidersMMDB.showLow == nil then VolumeSlidersMMDB.showLow = true end
    if VolumeSlidersMMDB.showMute == nil then VolumeSlidersMMDB.showMute = true end
    if VolumeSlidersMMDB.showWarnings == nil then VolumeSlidersMMDB.showWarnings = true end
    if VolumeSlidersMMDB.showBackground == nil then VolumeSlidersMMDB.showBackground = true end
    if VolumeSlidersMMDB.showCharacter == nil then VolumeSlidersMMDB.showCharacter = true end
    if VolumeSlidersMMDB.showOutput == nil then VolumeSlidersMMDB.showOutput = true end
    
    -- Channel Visibility Defaults
    if VolumeSlidersMMDB.showMaster == nil then VolumeSlidersMMDB.showMaster = true end
    if VolumeSlidersMMDB.showSFX == nil then VolumeSlidersMMDB.showSFX = true end
    if VolumeSlidersMMDB.showMusic == nil then VolumeSlidersMMDB.showMusic = true end
    if VolumeSlidersMMDB.showAmbience == nil then VolumeSlidersMMDB.showAmbience = true end
    if VolumeSlidersMMDB.showDialog == nil then VolumeSlidersMMDB.showDialog = true end

    -- Layout Defaults
    VolumeSlidersMMDB.sliderHeight = VolumeSlidersMMDB.sliderHeight or 150
    
    -- Slider Order Defaults
    if not VolumeSlidersMMDB.sliderOrder then
        VolumeSlidersMMDB.sliderOrder = {}
        for _, v in ipairs(DEFAULT_CVAR_ORDER) do
            table.insert(VolumeSlidersMMDB.sliderOrder, v)
        end
    end

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
    VS:InitializeSettings()
    VS:UpdateMiniMapVolumeIcon()
    
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
    if not VS.container then
        VS:CreateOptionsFrame()
    end

    if VS.container:IsShown() then
        VS.container:Hide()
    else
        VS.container:Show()
    end
end
