-------------------------------------------------------------------------------
-- spec/Settings_Window_spec.lua
-------------------------------------------------------------------------------

describe("VolumeSliders Settings Window Module", function()
    local VS

    before_each(function()
        VS = {
            AddTooltip = function() end,
            ApplyWindowBackground = spy.new(function() end),
            UpdateAppearance = spy.new(function() end),
            FlagLayoutDirty = spy.new(function() end),
            DEFAULT_FOOTER_ORDER = {"showOutput"},
        }
        _G.VolumeSlidersMMDB = {
            toggles = {
                persistentWindow = false,
                showHelpText = true,
                showPresetsDropdown = true,
                showOutput = true
            },
            appearance = {
                bgColor = { r = 0, g = 0, b = 0, a = 0.5 }
            },
            layout = {
                sliderOrder = {"Sound_MasterVolume"},
                footerOrder = {"showOutput"}
            },
            channels = { ["Sound_MasterVolume"] = true }
        }

        -- Load dependencies
        local fCore = assert(loadfile("VolumeSliders/Core.lua"))
        fCore("VolumeSliders", VS)

        local fWindow = assert(loadfile("VolumeSliders/Settings_Window.lua"))
        fWindow("VolumeSliders", VS)
    end)

    it("CreateWindowSettingsContents should initialize UI components", function()
        local parent = CreateFrame("Frame")
        VS:CreateWindowSettingsContents(parent)

        assert.is_not_nil(_G.VolumeSlidersWindowSettingsScrollFrame)
        assert.is_not_nil(_G.VolumeSlidersWindowSettingsContentFrame)
    end)

    it("Opacity slider should update DB and trigger background apply", function()
        local parent = CreateFrame("Frame")
        VS:CreateWindowSettingsContents(parent)

        local slider = _G.VolumeSlidersOpacitySlider
        assert.is_not_nil(slider)

        slider:GetScript("OnValueChanged")(slider, 75)

        assert.equal(0.75, _G.VolumeSlidersMMDB.appearance.bgColor.a)
        assert.spy(VS.ApplyWindowBackground).was_called()
    end)

    it("footer column controls update DB and flag layout refresh", function()
        local parent = CreateFrame("Frame")
        VS:CreateWindowSettingsContents(parent)

        local limitCheck = _G.VolumeSlidersLimitFooterColsCheck
        local maxInput = _G.VolumeSlidersMaxFooterColsInput

        assert.is_not_nil(limitCheck)
        assert.is_not_nil(maxInput)

        limitCheck:SetChecked(true)
        limitCheck:GetScript("OnClick")(limitCheck)
        assert.is_true(_G.VolumeSlidersMMDB.layout.limitFooterCols)

        maxInput:SetText("5")
        maxInput:GetScript("OnTextChanged")(maxInput, true)
        assert.are.equal(5, _G.VolumeSlidersMMDB.layout.maxFooterCols)
        assert.spy(VS.FlagLayoutDirty).was_called()
    end)
end)
