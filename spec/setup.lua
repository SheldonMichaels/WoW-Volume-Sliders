-------------------------------------------------------------------------------
-- spec/setup.lua
-- Busted mock environment for WoW UI testing.
-------------------------------------------------------------------------------

_G = _G or {}

-- Basic Engine Types
_G.UIParent = {
    GetFrameLevel = function() return 1 end,
    GetHeight = function() return 1080 end,
    GetWidth = function() return 1920 end,
    GetCenter = function() return 960, 540 end,
    GetLeft = function() return 0 end,
    GetBottom = function() return 0 end,
}

_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
}

_G.Minimap = {
    IsMouseOver = function() return false end,
    GetScript = function() end,
    HasScript = function() return false end,
    GetFrameLevel = function() return 10 end,
    GetEffectiveScale = function() return 1.0 end,
    GetRight = function() return 100 end,
    GetBottom = function() return 100 end,
    ZoomIn = { IsMouseOver = function() return false end },
    ZoomOut = { IsMouseOver = function() return false end },
}

-- Basic Frame Creation Mock
local function createMockFrame(frameType, name, parent, template)
    local f = {
        name = name,
        parent = parent,
        frameType = frameType,
        template = template,
        shown = true,
        width = 0,
        height = 0,
        level = 1,
        scripts = {},
        points = {},
        
        Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        IsShown = function(self) return self.shown end,
        GetName = function(self) return self.name end,
        SetParent = function(self, p) self.parent = p end,
        GetParent = function(self) return self.parent end,
        
        SetSize = function(self, w, h) self.width = w; self.height = h end,
        SetWidth = function(self, w) self.width = w end,
        SetHeight = function(self, h) self.height = h end,
        GetWidth = function(self) return self.width end,
        GetHeight = function(self) return self.height end,
        
        SetPoint = function(self, point, relFrame, relPoint, x, y)
            table.insert(self.points, {point=point, relFrame=relFrame, relPoint=relPoint, x=x, y=y})
        end,
        ClearAllPoints = function(self) self.points = {} end,
        GetCenter = function(self) return 0, 0 end,
        GetLeft = function(self) return 0 end,
        GetBottom = function(self) return 0 end,
        
        SetScript = function(self, event, handler) self.scripts[event] = handler end,
        HookScript = function(self, event, handler) 
            local old = self.scripts[event]
            self.scripts[event] = function(...) if old then old(...) end handler(...) end
        end,
        GetScript = function(self, event) return self.scripts[event] end,
        HasScript = function(self, event) return self.scripts[event] ~= nil end,
        
        SetFrameLevel = function(self, lvl) self.level = lvl end,
        GetFrameLevel = function(self) return self.level end,
        SetFrameStrata = function(self, strata) end,
        SetClampedToScreen = function(self, clamped) end,
        EnableMouse = function(self, enable) end,
        RegisterForDrag = function(self, btn) end,
        SetMovable = function(self, movable) end,
        StartMoving = function(self) end,
        StopMovingOrSizing = function(self) end,
        RegisterEvent = function(self, ev) end,
        UnregisterEvent = function(self, ev) end,
        UnregisterAllEvents = function(self) end,
        
        -- Special elements
        CreateTexture = function() return createMockFrame("Texture") end,
        CreateFontString = function() return {
            SetPoint = function() end,
            SetText = function() end,
            GetText = function() return "" end,
            SetTextColor = function() end,
            SetFontObject = function() end,
            SetWidth = function() end,
            SetHeight = function() end,
            SetJustifyH = function() end,
            SetJustifyV = function() end,
            SetWordWrap = function() end,
            SetMaxLines = function() end,
            SetSpacing = function() end,
            GetStringWidth = function() return 100 end,
            Show = function() end,
            Hide = function() end,
        } end,
        GetFontString = function() return nil end,
        SetNormalFontObject = function() end,
        SetHighlightFontObject = function() end,
        
        -- Textures
        SetAtlas = function() end,
        SetColorTexture = function() end,
        SetTexture = function() end,
        SetTexCoord = function() end,
        SetDesaturated = function() end,
        SetVertexColor = function() end,
        SetAlpha = function() end,
        SetAllPoints = function() end,
        
        -- Sliders/Checkboxes
        SetValue = function() end,
        GetValue = function() return 0 end,
        SetMinMaxValues = function() end,
        SetValueStep = function() end,
        SetObeyStepOnDrag = function() end,
        SetChecked = function(self, state) self.checked = state end,
        GetChecked = function(self) return self.checked end,
        SetText = function() end,
        SetScale = function() end,
        SetAutoFocus = function() end,
        SetNumeric = function() end,
        SetMaxLetters = function() end,
        SetCursorPosition = function() end,
        ClearFocus = function() end,
        SetupMenu = function() end,
        GenerateMenu = function() end,
        Enable = function() end,
        Disable = function() end,
        IsEnabled = function() return true end,
        IsMouseOver = function() return false end,
        EnableMouseWheel = function() end,
        SetBackdrop = function() end,
        SetBackdropColor = function() end,
        SetBackdropBorderColor = function() end,
        SetOrientation = function() end,
        SetThumbTexture = function() end,
        GetThumbTexture = function(self) return self.thumb end,
        SetHitRectInsets = function() end,
        
        -- Mocking children for templates
        NineSlice = { Text = { SetText = function() end } },
        ClosePanelButton = { SetScript = function() end },
        Bg = { Hide = function() end },
        thumb = { SetDesaturated = function() end, SetAlpha = function() end },
        trackTop = { SetAlpha = function() end },
        trackMiddle = { SetAlpha = function() end },
        trackBottom = { SetAlpha = function() end },
        upTex = { SetDesaturated = function() end, SetAlpha = function() end },
        downTex = { SetDesaturated = function() end, SetAlpha = function() end },
        valueText = { SetText = function() end, SetTextColor = function() end },
        label = { SetTextColor = function() end },
        muteCheck = { SetScript = function() end, EnableMouse = function() end, Show = function() end, muteLabel = { Show=function() end} },
        upBtn = { SetScript = function() end, EnableMouse = function() end },
        downBtn = { SetScript = function() end, EnableMouse = function() end },
        text = { SetText=function() end, SetTextColor=function() end, SetFontObject=function() end }
    }
    
    -- Specific methods for ScrollBox
    if template == "WowScrollBoxList" then
        f.Init = function() end
        f.SetDataProvider = function() end
    end
    
    return f
end

_G.CreateFrame = createMockFrame

-- Config & Variables
_G.VolumeSlidersMMDB = {
    isLocked = false,
    sliderSpacing = 10,
    sliderHeight = 150,
    minimalistMinimap = true,
    bindToMinimap = true,
    sliderOrder = {},
    showTitle = true,
    showValue = true,
    showMute = true,
    showUpArrow = true,
    showDownArrow = true,
    showHigh = true,
    showLow = true,
    showSlider = true,
    showOutput = true,
    showBackground = true,
    showCharacter = true,
    showVoiceMode = true,
    showMaster = true,
    showSFX = true,
    showMusic = true,
    showAmbience = true,
    showDialog = true,
    showWarnings = true,
    showVoiceChat = true,
    showVoiceDucking = true,
    showMicVolume = true,
    showMicSensitivity = true,
}

_G.VolumeSlidersDB = {}

-- CVar Simulation
local cvars = {
    Sound_OutputDriverIndex = "0",
    Sound_ListenerAtCharacter = "1",
    Sound_EnableSoundWhenGameIsInBG = "1",
    Sound_MasterVolume = "1",
    Sound_SFXVolume = "1",
    Sound_MusicVolume = "1",
    Sound_AmbienceVolume = "1",
    Sound_DialogVolume = "1",
    Sound_EncounterWarningsVolume = "1",
    Sound_EnableAllSound = "1",
    Sound_EnableSFX = "1",
    Sound_EnableMusic = "1",
    Sound_EnableAmbience = "1",
    Sound_EnableDialog = "1",
    Sound_EnableEncounterWarningsSounds = "1",
}

_G.GetCVar = function(name) return cvars[name] end
_G.GetCVarDefault = function(name) return "1" end
_G.SetCVar = function(name, val) cvars[name] = tostring(val) end

-- Utilities & Constants
_G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
_G.PlaySound = function(id) end
_G.GetCursorPosition = function() return 0, 0 end
_G.IsControlKeyDown = function() return false end
_G.IsShiftKeyDown = function() return false end
_G.hooksecurefunc = function(name, func) end

_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.Mixin = function(t, ...) 
    for _, mixin in ipairs({...}) do
        for k, v in pairs(mixin) do t[k] = v end
    end
    return t
end

-- Print
_G.print = function(...) end

-- Colors
_G.NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82, 0 end }
_G.HIGHLIGHT_FONT_COLOR = { GetRGB = function() return 1, 1, 1 end }
_G.VERY_LIGHT_GRAY_COLOR = { GetRGB = function() return 0.9, 0.9, 0.9 end }

-- Global API Tables
_G.C_Sound = {
    GetOutputDevices = function() return {} end,
}
_G.Sound_GameSystem_GetNumOutputDrivers = function() return 1 end
_G.Sound_GameSystem_GetOutputDriverNameByIndex = function(index) return "System Default" end
_G.Sound_GameSystem_RestartSoundSystem = function() end

_G.C_Timer = {
    After = function(t, cb) cb() end,
    NewTicker = function(t, cb) return { Cancel = function() end } end,
    NewTimer = function(t, cb) return { Cancel = function() end } end,
}

_G.C_AddOns = {
    IsAddOnLoaded = function(name) return false end,
}

_G.C_Texture = {
    GetAtlasInfo = function(name) return { file = "mock", height = 16, width = 16 } end,
}

_G.Enum = {
    CommunicationMode = {
        PushToTalk = 1,
        OpenMic = 2
    }
}

_G.C_VoiceChat = {
    GetCommunicationMode = function() return _G.Enum.CommunicationMode.PushToTalk end,
    SetCommunicationMode = function(mode) end,
    GetOutputVolume = function() return 1 end,
    SetOutputVolume = function(val) end,
    GetInputVolume = function() return 1 end,
    SetInputVolume = function(val) end,
    GetMasterVolumeScale = function() return 1 end,
    SetMasterVolumeScale = function(val) end,
    GetVADSensitivity = function() return 1 end,
    SetVADSensitivity = function(val) end,
}

_G.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) return {}, {} end,
    RegisterAddOnCategory = function(category) end,
    OpenToCategory = function(categoryID) end,
}

_G.ScrollUtil = {
    AddLinearDragBehavior = function(scrollBox) 
        return {
            SetReorderable = function() end,
            SetDragRelativeToCursor = function() end,
            SetCursorFactory = function() end,
            SetDropPredicate = function() end,
            SetDropEnter = function() end,
            SetPostDrop = function() end,
        }
    end,
}

_G.CreateDataProvider = function() return { Insert = function() end, EnumerateEntireRange = function() return {} end } end
_G.CreateScrollBoxListLinearView = function() return { SetElementInitializer = function() end, SetPadding = function() end } end

_G.DragIntersectionArea = { Inside = 1, Above = 2, Below = 3 }
_G.FrameUtil = { GetRootParent = function() return _G.UIParent end }
_G.InputUtil = { GetCursorPosition = function() return 0, 0 end }

-- LibStub Mock
_G.LibStub = setmetatable({
    NewLibrary = function() return {RegisterCallback=function() end, New=function() return {} end}, nil end,
    GetLibrary = function() return {RegisterCallback=function() end, New=function() return {} end}, nil end
}, {
    __call = function(self, name)
        return {
            New = function() return {} end,
            Register = function() end,
            NewDataObject = function(self, name, data)
                -- Merge basic table fields to simulate object creation
                local obj = {}
                for k,v in pairs(data or {}) do obj[k] = v end
                return obj
            end,
            Hide = function() end,
            Show = function() end,
            IsRegistered = function() return false end,
        }
    end
})

-- Setup mock `...` args for the addon entrypoint loading style
-- e.g. local addonName, addonTable = ...
function CreateAddonContext()
    local addonTable = {
        sliders = {},
        RefreshTextInputs = function() end,
        UpdateAppearance = function() end,
        Reposition = function() end,
        UpdateMiniMapButtonVisibility = function() end,
    }
    return "VolumeSliders", addonTable
end
