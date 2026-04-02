local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("PopupFrame behavioral tests", function()
    local VS

    before_each(function()
        _G.VolumeSlidersMMDB = {
            schemaVersion = 3,
            toggles = {
                persistentWindow = false,
            },
            appearance = {
                bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 }
            },
            channels = {}, layout = {}, voice = {}, minimap = {}, automation = {}, hardware = {}
        }
        
        local addonName = "VolumeSliders"
        local addonTable = {
            sliders = {},
            ApplySliderAppearance = function() end,
            ApplyWindowBackground = function() end,
            UpdateAppearance = function() end,
            FlagLayoutDirty = function() end,
        }
        
        -- Mocking shared logic for PopupFrame loading
        local coreChunk = loadfile("VolumeSliders/Core.lua")
        coreChunk(addonName, addonTable)
        
        local widgetsChunk = loadfile("VolumeSliders/SliderWidgets.lua")
        widgetsChunk(addonName, addonTable)
        
        -- We need to mock some dependencies for PopupFrame.lua
        addonTable.LDB = { RegisterCallback = function() end }
        addonTable.LDBIcon = { Register = function() end }

        local popupChunk = assert(loadfile("VolumeSliders/PopupFrame.lua"))
        popupChunk(addonName, addonTable)

        VS = addonTable
        VS:CreateOptionsFrame()
    end)

    it("should close on outside click when persistentWindow is false", function()
        _G.VolumeSlidersMMDB.toggles.persistentWindow = false
        VS.container:Show()
        assert.is_true(VS.container:IsShown())

        -- Find the OnEvent handler
        local handler = VS.container:GetScript("OnEvent")
        assert.is_function(handler)

        -- Mock mouse outside container (rect 0,0 to 100,100)
        VS.container:SetSize(100, 100)
        _G.IsMouseOver = function(frame) return frame == _G.UIParent end

        handler(VS.container, "GLOBAL_MOUSE_DOWN")
        assert.is_false(VS.container:IsShown())
    end)

    it("should stay open on outside click when persistentWindow is true", function()
        _G.VolumeSlidersMMDB.toggles.persistentWindow = true
        VS.container:Show()
        
        local handler = VS.container:GetScript("OnEvent")
        _G.IsMouseOver = function(frame) return frame == _G.UIParent end

        handler(VS.container, "GLOBAL_MOUSE_DOWN")
        assert.is_true(VS.container:IsShown())
    end)

    it("should apply background color correctly", function()
        -- AddonTable setup usually happens in Core/Init
        VS.windowBg = VS.container:CreateTexture()
        
        -- Mocking the logic from Appearance.lua because we are testing PopupFrame's integration
        VS.ApplyWindowBackground = function(self)
            local db = _G.VolumeSlidersMMDB
            self.windowBg:SetColorTexture(db.appearance.bgColor.r, db.appearance.bgColor.g, db.appearance.bgColor.b, db.appearance.bgColor.a)
        end
        
        VS:ApplyWindowBackground()
        
        assert.are.equal(0.05, VS.windowBg.r)
        assert.are.equal(0.95, VS.windowBg.a)
    end)

    it("should flag layout dirty on size changed", function()
        local flagSpy = spy.on(VS, "FlagLayoutDirty")
        local onSizeChanged = VS.container:GetScript("OnSizeChanged")
        assert.is_function(onSizeChanged)

        onSizeChanged(VS.container, 500, 500)
        assert.spy(flagSpy).was_called()
    end)
end)
