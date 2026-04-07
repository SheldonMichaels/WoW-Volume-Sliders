local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("Dynamic Layout tests", function()
    local VS

    before_each(function()
        _G.VolumeSlidersMMDB = {
            schemaVersion = 5,
            toggles = {
                showTitle = true,
                showSlider = true,
                showMaster = true,
                showSFX = true,
            },
            channels = {
                ["Sound_MasterVolume"] = true,
                ["Sound_SFXVolume"] = true,
            },
            layout = {
                sliderOrder = {"Sound_MasterVolume", "Sound_SFXVolume"},
            },
            voice = {},
            automation = {},
            minimap = {},
            appearance = {},
            hardware = {},
        }
        -- layoutDirty is now part of VS.session, which gets initialized by Core.lua
        
        local addonName = "VolumeSliders"
        local addonTable = {}
        
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        
        local widgetsChunk = loadfile("VolumeSliders/SliderWidgets.lua")
        widgetsChunk(addonName, addonTable)
        
        local appearanceChunk = loadfile("VolumeSliders/Appearance.lua")
        appearanceChunk(addonName, addonTable)
        
        -- Mocking shared dependencies for PopupFrame.lua
        addonTable.LDB = { RegisterCallback = function() end }
        addonTable.LDBIcon = { Register = function() end }
        assert(loadfile("VolumeSliders/PopupFrame.lua"))(addonName, addonTable)

        VS = addonTable
        
        -- Initialize container/content for layout
        VS:CreateOptionsFrame()
        VS.container:SetSize(400, 400)
        
        -- Create dummy sliders for testing
        VS.sliders = {
            ["Sound_MasterVolume"] = _G.CreateFrame("Frame", "TestSlider1"),
            ["Sound_SFXVolume"] = _G.CreateFrame("Frame", "TestSlider2"),
        }
    end)

    it("should calculate dynamic spacing correctly with titles shown", function()
        _G.VolumeSlidersMMDB.toggles.showTitle = true
        VS.session.layoutDirty = true
        VS:UpdateAppearance()
        
        -- Logic: 
        -- contentW = 400 - 7 - 3 = 390
        -- usableW = 390 - (10 * 2) = 370
        -- numSliders = 2, columnWidth = 60
        -- dynamicSpacing = (370 - 2 * 60) / (2 - 1) = 250
        -- Clamped to minSpacing (-5) -> 250
        
        -- startX = 10 (SLIDER_PADDING_X)
        -- slider 1: offsetX = 10 + (0 * (60 + 250)) + (60/2) - 8 = 32
        -- slider 2: offsetX = 10 + (1 * (60 + 250)) + (60/2) - 8 = 342
        
        local s1 = VS.sliders["Sound_MasterVolume"]
        local s2 = VS.sliders["Sound_SFXVolume"]
        
        assert.are.equal(32, s1.points[1].x)
        assert.are.equal(342, s2.points[1].x)
    end)

    it("should use -20px spacing floor when titles are hidden", function()
        _G.VolumeSlidersMMDB.toggles.showTitle = false
        VS.session.layoutDirty = true
        -- Make window extremely narrow to trigger the floor
        VS.container:SetWidth(100)
        VS:UpdateAppearance()
        
        -- usableW = (100 - 10) - (10 * 2) = 70
        -- dynamicSpacing = (70 - 120) / 1 = -50
        -- Clamped to -20
        
        -- startX = 10
        -- slider 1: 10 + 0 + 30 - 8 = 32
        -- slider 2: 10 + (1 * (60 - 20)) + 30 - 8 = 72
        
        local s2 = VS.sliders["Sound_SFXVolume"]
        assert.are.equal(72, s2.points[1].x)
    end)
    
    it("should set correct resize bounds based on slider count", function()
        VS.session.layoutDirty = true
        VS:UpdateAppearance()
        -- minW = (10 * 2) + (2 * 60) + (1 * -5) = 135
        -- + border (7+3) = 145
        -- clamped to 200 -> 200
        assert.are.equal(200, VS.container.minW)
    end)

    it("should skip layout if dirty flag is false", function()
        VS.session.layoutDirty = false
        local s1 = VS.sliders["Sound_MasterVolume"]
        s1:ClearAllPoints()
        
        VS:UpdateAppearance()
        
        assert.are.equal(0, #s1.points)
    end)
end)
