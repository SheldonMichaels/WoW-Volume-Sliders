local assert = require("luassert")
local spy = require("luassert.spy")

require("spec.setup")

describe("PopupFrame behavioral tests", function()
    local VS

    before_each(function()
        _G.VolumeSlidersMMDB = {
            schemaVersion = 5,
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

        local presetsChunk = loadfile("VolumeSliders/Presets.lua")
        presetsChunk(addonName, addonTable)

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

    it("should update preset dropdown label on selection", function()
        -- 1. Setup a mock preset
        _G.VolumeSlidersMMDB.automation.presets = {
            { name = "Test Preset", volumes = { ["Sound_MasterVolume"] = 0.5 } }
        }
        VS.session.activeRegistry.manual = {}
        
        -- 2. Mock GetActivePresetsButtonText
        local originalGetText = VS.Presets.GetActivePresetsButtonText
        VS.Presets.GetActivePresetsButtonText = function()
            if VS.session.activeRegistry.manual and VS.session.activeRegistry.manual[1] then
                return "Test Preset"
            end
            return "Presets"
        end
        
        -- 3. Spy on the FontString:SetText
        local setTextSpy = spy.on(VS.presetDropdown.Text, "SetText")
        
        -- 4. Trigger refresh (imitates window opening)
        VS.RefreshPopupDropdown()
        assert.spy(setTextSpy).was_called_with(VS.presetDropdown.Text, "Presets")

        -- 5. Select the preset (simulated)
        VS.session.activeRegistry.manual[1] = _G.VolumeSlidersMMDB.automation.presets[1]
        VS.RefreshPopupDropdown()
        
        assert.spy(setTextSpy).was_called_with(VS.presetDropdown.Text, "Test Preset")
        
        -- Cleanup
        VS.Presets.GetActivePresetsButtonText = originalGetText
        setTextSpy:revert()
    end)

    it("recalculates the preset label on window resize (OnSizeChanged)", function()
        -- 1. Setup mocks
        local preset = { name = "Resizing", volumes = {} }
        _G.VolumeSlidersMMDB.automation.presets = { preset }
        VS.Presets:RegisterActivePreset("manual", 1, preset)
        
        local setTextSpy = spy.on(VS.presetDropdown, "SetText")
        
        -- 2. Simulate OnSizeChanged
        local onSizeChanged = VS.container:GetScript("OnSizeChanged")
        assert.is_not_nil(onSizeChanged)
        
        onSizeChanged(VS.container, 300, 200)
        
        -- 3. Verify SetText was called (it should have picked up our preset name)
        assert.spy(setTextSpy).was_called_with(VS.presetDropdown, "Resizing")
        
        setTextSpy:revert()
    end)
end)
