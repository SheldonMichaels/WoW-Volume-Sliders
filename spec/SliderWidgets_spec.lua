-------------------------------------------------------------------------------
-- spec/SliderWidgets_spec.lua
-------------------------------------------------------------------------------

describe("SliderWidgets Factory Module", function()
    local VS

    before_each(function()
        VS = {}
        local f1 = assert(loadfile("VolumeSliders/Core.lua"))
        f1("VolumeSliders", VS)
        local f2 = assert(loadfile("VolumeSliders/SliderWidgets.lua"))
        f2("VolumeSliders", VS)
        
        -- Create a dummy parent
        _G.UIParent = _G.CreateFrame("Frame")
    end)

    it("should provide factory methods", function()
        assert.is_function(VS.CreateVerticalSlider)
        assert.is_function(VS.CreateVoiceSlider)
        assert.is_function(VS.CreateCheckbox)
    end)

    it("should instantiate a vertical slider frame with sub-components", function()
        local slider = VS:CreateVerticalSlider(_G.UIParent, "TestSlider", "Test", "Sound_MasterVolume", "Sound_EnableAllSound", 0, 1, 0.01)
        assert.is_table(slider)
        assert.is_table(slider.upBtn)
        assert.is_table(slider.downBtn)
        assert.is_table(slider.muteCheck)
    end)
    
    it("should hook slider OnMouseWheel for volume stepping", function()
        local slider = VS:CreateVerticalSlider(_G.UIParent, "WheelSlider", "Wheel", "TestCVar", "TestMute", 0, 1, 0.05)
        local onWheel = slider:GetScript("OnMouseWheel")
        assert.is_function(onWheel)
    end)
end)
