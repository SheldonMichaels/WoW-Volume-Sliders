-------------------------------------------------------------------------------
-- spec/Settings_Sliders_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Settings Sliders Module", function()
    local VS

    before_each(function()
        VS = {
            AddTooltip = function() end,
            UpdateAppearance = spy.new(function() end),
        }
        _G.VolumeSlidersMMDB = {
            appearance = {
                titleColor = 1,
                valueColor = 1,
                highColor = 1,
                lowColor = 1,
                arrowStyle = 1,
                knobStyle = 1
            },
            toggles = {
                showTitle = true,
                showValue = true,
                showHigh = true,
                showUpArrow = true,
                showSlider = true,
                showDownArrow = true,
                showLow = true,
                showMute = true
            }
        }

        -- Load dependencies
        local fCore = assert(loadfile("VolumeSliders/Core.lua"))
        fCore("VolumeSliders", VS)

        local fWidgets = assert(loadfile("VolumeSliders/SliderWidgets.lua"))
        fWidgets("VolumeSliders", VS)

        local fSliders = assert(loadfile("VolumeSliders/Settings_Sliders.lua"))
        fSliders("VolumeSliders", VS)
    end)

    it("CreateSlidersSettingsContents should initialize UI components", function()
        local parent = CreateFrame("Frame")
        VS:CreateSlidersSettingsContents(parent)

        assert.is_not_nil(_G.VolumeSlidersSlidersSettingsScrollFrame)
        assert.is_not_nil(_G.VolumeSlidersSlidersSettingsContentFrame)
        assert.is_not_nil(_G.VolumeSlidersPreviewSlider)
    end)

    it("builds a non-interactive preview slider and refreshes appearance", function()
        local parent = CreateFrame("Frame")
        VS:CreateSlidersSettingsContents(parent)

        assert.spy(VS.UpdateAppearance).was_called()
        assert.is_nil(_G.VolumeSlidersPreviewSlider.upBtn:GetScript("OnClick"))
        assert.is_nil(_G.VolumeSlidersPreviewSlider.downBtn:GetScript("OnClick"))
        assert.is_nil(_G.VolumeSlidersPreviewSlider.muteCheck:GetScript("OnClick"))
    end)
end)
