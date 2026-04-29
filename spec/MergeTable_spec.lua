-------------------------------------------------------------------------------
-- spec/MergeTable_spec.lua
-- Verifies array-aware merge behavior via the real Init.lua bootstrap path.
-------------------------------------------------------------------------------

local assert = require("luassert")
require("spec.setup")

describe("MergeTable bootstrap behavior", function()
    local VS
    local initFrameScript

    local function bootstrapWith(db)
        _G.VolumeSlidersMMDB = db
        initFrameScript = nil

        VS = {}
        loadfile("VolumeSliders/Core.lua")("VolumeSliders", VS)

        VS.LDBIcon = { Register = function() end, IsRegistered = function() return false end }
        VS.LDB = { NewDataObject = function() return {} end }
        VS.VolumeSlidersObject = {}
        VS.InitializeSettings = function() end
        VS.UpdateMiniMapButtonVisibility = function() end
        VS.HookBrokerScroll = function() end
        VS.HandlePTT_OnMouseDown = function() end
        VS.HandlePTT_OnMouseUp = function() end
        VS.UpdateMiniMapVolumeIcon = function() end
        VS.Presets = { RefreshEventState = function() end }
        VS.Fishing = { Initialize = function() end }
        VS.LFGQueue = { Initialize = function() end }

        local realCreateFrame = _G.CreateFrame
        _G.CreateFrame = function(frameType, name, parent, template)
            local f = realCreateFrame(frameType, name, parent, template)
            local oldSetScript = f.SetScript
            f.SetScript = function(self, evt, handler)
                if evt == "OnEvent" then initFrameScript = handler end
                if oldSetScript then oldSetScript(self, evt, handler) end
            end
            return f
        end

        loadfile("VolumeSliders/Init.lua")("VolumeSliders", VS)
        _G.CreateFrame = realCreateFrame

        assert.is_function(initFrameScript)
        initFrameScript({ UnregisterEvent = function() end }, "PLAYER_LOGIN")
    end

    it("does not append default items to an existing user array", function()
        bootstrapWith({
            schemaVersion = 7,
            appearance = { bgColor = { r = 0.1, g = 0.1, b = 0.1 } },
            layout = {
                sliderOrder = { "Sound_MasterVolume" },
                footerOrder = { "showOutput" },
                mouseActions = { sliders = {}, scrollWheel = {} },
            },
            toggles = {},
            channels = {},
            minimap = { minimalistMinimap = true, mouseActions = {}, minimapTooltipOrder = {} },
            hardware = {},
            automation = { persistedBaseline = {}, lastAppliedState = {}, presets = {}, activeManualPresets = {} },
            voice = {},
        })

        local sliderOrder = _G.VolumeSlidersMMDB.layout.sliderOrder
        assert.are.equal(1, #sliderOrder)
        assert.are.equal("Sound_MasterVolume", sliderOrder[1])
        assert.is_nil(sliderOrder[2])
    end)

    it("initializes missing arrays from defaults", function()
        bootstrapWith({
            schemaVersion = 7,
            appearance = { bgColor = { r = 0.1, g = 0.1, b = 0.1 } },
            layout = {
                sliderOrder = { "Sound_MasterVolume" },
                mouseActions = { sliders = {}, scrollWheel = {} },
            },
            toggles = {},
            channels = {},
            minimap = { minimalistMinimap = true, mouseActions = {}, minimapTooltipOrder = {} },
            hardware = {},
            automation = { persistedBaseline = {}, lastAppliedState = {}, presets = {}, activeManualPresets = {} },
            voice = {},
        })

        local footerOrder = _G.VolumeSlidersMMDB.layout.footerOrder
        assert.is_table(footerOrder)
        assert.is_true(#footerOrder > 0)
    end)

    it("deep-merges dictionaries without clobbering existing values", function()
        bootstrapWith({
            schemaVersion = 7,
            appearance = { bgColor = { r = 1, g = 1, b = 1 } }, -- missing alpha
            layout = {
                sliderOrder = { "Sound_MasterVolume" },
                footerOrder = { "showOutput" },
                mouseActions = { sliders = {}, scrollWheel = {} },
            },
            toggles = {},
            channels = {},
            minimap = { minimalistMinimap = true, mouseActions = {}, minimapTooltipOrder = {} },
            hardware = {},
            automation = { persistedBaseline = {}, lastAppliedState = {}, presets = {}, activeManualPresets = {} },
            voice = {},
        })

        local bg = _G.VolumeSlidersMMDB.appearance.bgColor
        assert.are.equal(1, bg.r)
        assert.are.equal(1, bg.g)
        assert.are.equal(1, bg.b)
        assert.are.equal(0.95, bg.a)
    end)

    it("repairs sparse schema-7 footerOrder so ipairs sees all canonical keys", function()
        bootstrapWith({
            schemaVersion = 7,
            appearance = { bgColor = { r = 0.1, g = 0.1, b = 0.1 } },
            layout = {
                sliderOrder = { "Sound_MasterVolume" },
                footerOrder = { [6] = "showEmoteSounds" },
                mouseActions = { sliders = {}, scrollWheel = {} },
            },
            toggles = {},
            channels = {},
            minimap = { minimalistMinimap = true, mouseActions = {}, minimapTooltipOrder = {} },
            hardware = {},
            automation = { persistedBaseline = {}, lastAppliedState = {}, presets = {}, activeManualPresets = {} },
            voice = {},
        })

        local fo = _G.VolumeSlidersMMDB.layout.footerOrder
        assert.are.equal(8, #fo)
        assert.are.equal("showZoneTriggers", fo[1])
        assert.are.equal("showEmoteSounds", fo[6])
        local n = 0
        for _ in ipairs(fo) do
            n = n + 1
        end
        assert.are.equal(8, n)
    end)
end)
