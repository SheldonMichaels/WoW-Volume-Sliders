-------------------------------------------------------------------------------
-- spec/Resize_spec.lua
-- Tests window dimension persistence in PopupFrame.lua
-------------------------------------------------------------------------------

describe("Window Resize Persistence", function()
    local VS
    local mockContainer

    before_each(function()
        _G.VolumeSlidersMMDB = {
            appearance = {
                windowWidth = 500,
                windowHeight = 600
            },
            layout = {
                customX = 100,
                customY = 100
            },
            toggles = { isLocked = false, persistentWindow = false },
            automation = { presets = {} },
            channels = {}
        }

        local dragStopScripts = {}
        
        -- Create a resilient mock generator
        local function CreateMockFrame(name)
            local f
            f = {
                width = 500,
                height = 600,
                SetSize = function(self, w, h) self.width = w; self.height = h end,
                SetWidth = function(self, w) self.width = w end,
                SetHeight = function(self, h) self.height = h end,
                GetWidth = function(self) return self.width or 500 end,
                GetHeight = function(self) return self.height or 600 end,
                GetLeft = function() return 100 end,
                GetBottom = function() return 100 end,
                GetName = function() return name or "MOCKED_FRAME" end,
                IsShown = function() return true end,
                IsMouseOver = function() return false end,
                GetFrameLevel = function() return 1 end,
                SetScript = function(self, script, func)
                    if script == "OnDragStop" or script == "OnMouseUp" then
                        table.insert(dragStopScripts, func)
                    end
                end,
                -- Must return NEW objects to avoid circular references (stack overflow)
                CreateTexture = function() return CreateMockFrame("Texture") end,
                CreateFontString = function() return CreateMockFrame("FontString") end,
            }
            
            setmetatable(f, {
                __index = function(t, k)
                    -- Return a dummy function for any missing method
                    return function() return t end
                end
            })
            return f
        end

        _G.CreateFrame = function(type, name, parent, template)
            local f = CreateMockFrame(name)
            if template == "SettingsFrameTemplate" then
                f.NineSlice = CreateMockFrame("NineSlice")
                f.NineSlice.Text = CreateMockFrame("TitleText")
                f.ClosePanelButton = CreateMockFrame("CloseButton")
                f.Bg = CreateMockFrame("Bg")
                mockContainer = f
            end
            return f
        end

        _G.UIParent = { GetHeight = function() return 1000 end }
        _G.UISpecialFrames = {}
        _G.Settings = { OpenToCategory = function() end }
        _G.PlaySound = function() end
        _G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1 }
        _G.C_VoiceChat = { 
            GetOutputVolume = function() return 100 end,
            SetOutputVolume = function() end,
            GetMasterVolumeScale = function() return 1 end,
            SetMasterVolumeScale = function() end,
            GetInputVolume = function() return 100 end,
            SetInputVolume = function() end,
            GetVADSensitivity = function() return 100 end,
            SetVADSensitivity = function() end
        }
        _G.Sound_GameSystem_GetNumOutputDrivers = function() return 1 end
        _G.Sound_GameSystem_GetOutputDriverNameByIndex = function() return "Default" end

        local addonName = "VolumeSliders"
        local addonTable = {
            DEFAULT_WINDOW_WIDTH = 375,
            DEFAULT_WINDOW_HEIGHT = 440,
            TEMPLATE_CONTENT_OFFSET_LEFT = 0,
            TEMPLATE_CONTENT_OFFSET_RIGHT = 0,
            TEMPLATE_CONTENT_OFFSET_TOP = 0,
            TEMPLATE_CONTENT_OFFSET_BOTTOM = 0,
            CONTENT_PADDING_X = 0,
            CONTENT_PADDING_TOP = 0,
            CONTENT_PADDING_BOTTOM = 0,
            SLIDER_COLUMN_WIDTH = 0,
            SLIDER_PADDING_X = 0,
            RESIZE_HANDLE_THICKNESS = 6,
            sliders = {},
            session = { layoutDirty = false }
        }
        
        -- Mock sub-functions called by CreateOptionsFrame
        addonTable.UpdateAppearance = function() end
        addonTable.CreateVerticalSlider = function() return CreateMockFrame("Slider") end
        addonTable.CreateVoiceSlider = function() return CreateMockFrame("VoiceSlider") end
        addonTable.CreateCheckbox = function() return CreateMockFrame("Checkbox") end
        addonTable.UpdateMiniMapVolumeIcon = function() end
        addonTable.HandlePTT_OnMouseUp = function() end
        addonTable.HandlePTT_OnMouseDown = function() end
        addonTable.InitializeSettings = function() end

        local chunk = loadfile("VolumeSliders/PopupFrame.lua")
        chunk(addonName, addonTable)
        VS = addonTable
        VS.dragStopScripts = dragStopScripts
    end)

    it("initializes window size from appearance namespace", function()
        VS:CreateOptionsFrame()
        assert.are.equal(500, mockContainer:GetWidth())
        assert.are.equal(600, mockContainer:GetHeight())
    end)

    it("saves updated size back to appearance namespace on resize handle stop", function()
        VS:CreateOptionsFrame()
        
        -- Simulate a resize
        mockContainer.width = 800
        mockContainer.height = 900
        
        -- Trigger one of the resize handles' OnMouseUp or OnDragStop
        -- In our mock, they all get pushed to VS.dragStopScripts
        if #VS.dragStopScripts > 0 then
            -- We just need to find one that writes to the DB.
            -- Edge handles are at the end of CreateOptionsFrame.
            VS.dragStopScripts[#VS.dragStopScripts]()
        end
        
        assert.are.equal(800, _G.VolumeSlidersMMDB.appearance.windowWidth)
        assert.are.equal(900, _G.VolumeSlidersMMDB.appearance.windowHeight)
    end)
end)
